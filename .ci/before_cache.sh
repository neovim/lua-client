#!/usr/bin/env bash

set -e
set -o pipefail

# Don't cache pip's log and selfcheck.
rm -rf "${HOME}/.cache/pip/log"
rm -f "${HOME}/.cache/pip/selfcheck.json"

# Update the third-party dependency cache only if the build was successful.
if [[ -f "${SUCCESS_MARKER}" ]]; then
  if [[ ! -f "${CACHE_MARKER}" ]] || [[ "${BUILD_DEPS}" == true ]]; then
    echo "Updating dependencies cache."
    rm -rf "${HOME}/.cache/nvim-deps"
    mv -T "${DEPS_INSTALL_PREFIX}" "${HOME}/.cache/nvim-deps"
    touch "${CACHE_MARKER}"
  fi
fi

