<!--
SPDX-FileCopyrightText: 2026 Stefan Grönke <stefan@gronke.net>
SPDX-License-Identifier: MIT
-->

# sealed-node

`node`, `npm` and `npx` from a digest-pinned container without network, on `PATH` for every later step.

## Usage

```yaml
- uses: actions/checkout@v7
- uses: gronke/ci/.github/actions/node/sealed-node@v3
  with:
    image: node:24-slim@sha256:3638d9a6fe4030bd716be989438248074489337ba3275657f93595428be4fc03
    npm-version: 12.1.0                       # optional: this npm runs instead of the image's
    npm-integrity: sha512-Fyhu62pNx70YCs/5+dEmJQTFVmSKwvo5CA0qvBkGDRpob42MJ6G2RQ2tdxeKM4nYnIZDqkYAxEgqtoejn9QGtQ==
    lockfile-dir: ci/sealed-node              # optional: package.json and package-lock.json
- run: npm pack --dry-run --json
- run: node -p "require('minimatch/package.json').version"
```

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `image` | required | The node image by digest (`name@sha256:...`); a tag alone is refused. |
| `npm-version` | `""` | An npm version fetched as its registry tarball; `npm` and `npx` run it. |
| `npm-integrity` | `""` | The tarball's `sha512-...`; required with `npm-version`. |
| `lockfile-dir` | `""` | A directory with `package.json` and `package-lock.json`, installed once with the network on by `npm ci --ignore-scripts --no-audit --no-fund`. |

## Outputs and environment

| Name | Value |
| --- | --- |
| `node-modules` output, `SEALED_NODE_MODULES` and `NODE_PATH` | The installed tree's `node_modules`; empty without `lockfile-dir`. |
| `npm-dir` output, `SEALED_NPM` | The extracted npm; empty without `npm-version`. |
| `NODE_IMAGE` | The image. |

## Cache

Everything the action fetches lives under `$RUNNER_TEMP/node-ci`; restore it before the action and it skips the downloads.
The tarball's hash is checked again, and the tree is reused only while its stamp names the same lockfile and image.

```yaml
- uses: actions/cache@v6
  with:
    path: ${{ runner.temp }}/node-ci
    key: node-ci-${{ hashFiles('ci/sealed-node/package-lock.json') }}-12.1.0-3638d9a6
- uses: gronke/ci/.github/actions/node/sealed-node@v3
  with: ...
```

## Notes

- Every shim run is sealed: `--network none`, the calling user, `--cap-drop ALL`, `no-new-privileges`, a read-only root, `/tmp` a tmpfs; the working directory is `/data`, read-only for `node`, writable for `npm` and `npx`.
- The image is pulled first, so a wrong digest fails before anything else runs.
- Linux runners with docker only.
- Locally: `export NODE_IMAGE=... SEALED_NPM=... SEALED_NODE_MODULES=... NODE_PATH=$SEALED_NODE_MODULES; PATH=/path/to/ci/.github/actions/node/sealed-node/bin:$PATH`.
