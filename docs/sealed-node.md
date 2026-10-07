<!--
SPDX-FileCopyrightText: 2026 Stefan Grönke <stefan@gronke.net>
SPDX-License-Identifier: MIT
-->

# The seal

What a `node`, `npm` or `npx` run through the shims has, and what it does not.

## Sealed

- The image by digest: a tag is refused, so the same bytes run everywhere until the pin moves.
- `--network none`: nothing is fetched or sent while the code runs.
- The calling user, `--cap-drop ALL`, `--security-opt no-new-privileges`: no root, no capabilities, no privilege gain.
- A read-only root with `/tmp` as a tmpfs: the container cannot change itself; `HOME` and the npm cache live in `/tmp`.
- The working directory as `/data`, read-only for `node`, writable for `npm` and `npx`; nothing else of the host is visible except the pinned npm at `/opt/npm` and the installed tree, both read-only.

## Not sealed

- The image pull, the npm tarball download and the `npm ci` of the lockfile tree use the network; the tarball is checked against the given sha512 and the tree against the lockfile's hashes, with no install script run.
- Code in the installed tree runs inside the seal later; the lockfile is the trust decision.
- Docker, the runner and the repository's workflow are trusted as they are.

## Pins

- The image digest and the npm version with its integrity belong in the consumer's workflow, next to the fixtures that depend on them.
- A lockfile tree is pinned by its `package-lock.json`; the stamp in `$RUNNER_TEMP/node-ci/tree/.node-ci` names the lockfile's sha256 and the image, so a cache restored under another pin is installed afresh.
