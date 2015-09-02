#!/usr/bin/env bash

set -e
set -o pipefail
set -o xtrace

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_or_build_deps() {
  rm -rf "${DEPS_INSTALL_PREFIX}"

  # Use cached dependencies if available (and not forced).
  if [[ -f "${CACHE_MARKER}" ]] && [[ "${BUILD_NVIM_DEPS}" != true ]]; then
    echo "Using third-party dependencies from Travis cache (last updated: $(stat -c '%y' "${CACHE_MARKER}"))."

    mkdir -p "$(dirname "${DEPS_INSTALL_PREFIX}")"
    ln -Ts "${HOME}/.cache/nvim-deps" "${DEPS_INSTALL_PREFIX}"
    return
  fi

  ${MAKE_CMD} deps
}

run_tests() {
  make test
  echo "${SUCCESS_MARKER}"
  touch "${SUCCESS_MARKER}"
}

# ${DEPS_INSTALL_PREFIX}/bin/luarocks remove nvim-client
get_or_build_deps

mkdir "$DEPS_INSTALL_PREFIX/nvim"
wget -q -O - https://github.com/neovim/neovim/releases/download/nightly/neovim-linux64.tar.gz \
  | tar xzf - --strip-components=1 -C "$DEPS_INSTALL_PREFIX/nvim"

run_tests

