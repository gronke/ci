#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Stefan Grönke <stefan@gronke.net>
# SPDX-License-Identifier: MIT
# The action's one step: pull the image, fetch the pinned npm, install the lockfile tree, export
# the variables and put the shims on PATH. A restored cache under $RUNNER_TEMP/node-ci is reused:
# the npm tarball is hashed again, the tree is kept while its stamp names the same lockfile and
# image.
set -euo pipefail
: "${INPUT_IMAGE:?image is required}"
case "$INPUT_IMAGE" in
  *@sha256:*) ;;
  *) echo "::error::image must be pinned by digest (name@sha256:...): $INPUT_IMAGE"; exit 1 ;;
esac
work="${RUNNER_TEMP:?}/node-ci"
mkdir -p "$work"
docker pull -q "$INPUT_IMAGE" >/dev/null
echo "NODE_IMAGE=$INPUT_IMAGE" >> "$GITHUB_ENV"

npm_dir=""
if [ -n "${INPUT_NPM_VERSION:-}" ]; then
  : "${INPUT_NPM_INTEGRITY:?npm-integrity is required with npm-version}"
  tgz="$work/npm-$INPUT_NPM_VERSION.tgz"
  if [ ! -f "$tgz" ]; then
    curl -fsSL --retry 3 "https://registry.npmjs.org/npm/-/npm-$INPUT_NPM_VERSION.tgz" -o "$tgz"
  fi
  got="sha512-$(openssl dgst -sha512 -binary "$tgz" | base64 -w0)"
  if [ "$got" != "$INPUT_NPM_INTEGRITY" ]; then
    echo "::error::npm $INPUT_NPM_VERSION: integrity $got, expected $INPUT_NPM_INTEGRITY"
    exit 1
  fi
  npm_dir="$work/npm"
  rm -rf "$npm_dir" && mkdir -p "$npm_dir" && tar -xzf "$tgz" -C "$npm_dir" --strip-components=1
  echo "SEALED_NPM=$npm_dir" >> "$GITHUB_ENV"
fi

node_modules=""
if [ -n "${INPUT_LOCKFILE_DIR:-}" ]; then
  tree="$work/tree"
  stamp="$(sha256sum "$INPUT_LOCKFILE_DIR/package-lock.json" | cut -d' ' -f1) $INPUT_IMAGE"
  if [ ! -f "$tree/.node-ci" ] || [ "$(cat "$tree/.node-ci")" != "$stamp" ]; then
    rm -rf "$tree" && mkdir -p "$tree"
    cp "$INPUT_LOCKFILE_DIR/package.json" "$INPUT_LOCKFILE_DIR/package-lock.json" "$tree/"
    # The one container run with the network on; the lockfile's sha512 checks every tarball and
    # no script runs.
    docker run --rm --user "$(id -u):$(id -g)" --cap-drop ALL --security-opt no-new-privileges \
      --read-only --tmpfs /tmp:exec \
      -e HOME=/tmp -e npm_config_cache=/tmp/npm -e npm_config_update_notifier=false \
      -v "$tree:/data" -w /data --entrypoint npm "$INPUT_IMAGE" ci --ignore-scripts --no-audit --no-fund
    printf '%s' "$stamp" > "$tree/.node-ci"
  fi
  node_modules="$tree/node_modules"
  { echo "SEALED_NODE_MODULES=$node_modules"; echo "NODE_PATH=$node_modules"; } >> "$GITHUB_ENV"
fi

bin="$(cd "${ACTION_PATH:?}/bin" && pwd)"
echo "$bin" >> "$GITHUB_PATH"
{ echo "node-modules=$node_modules"; echo "npm-dir=$npm_dir"; } >> "$GITHUB_OUTPUT"
echo "sealed node: $INPUT_IMAGE${npm_dir:+, npm $INPUT_NPM_VERSION}${node_modules:+, tree from $INPUT_LOCKFILE_DIR}"
