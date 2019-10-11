#!/usr/bin/env bash

set -e
set -o pipefail
#set -o xtrace

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_nvim() {
  mkdir "$NVIM_INSTALL_PREFIX"
  curl -L https://github.com/neovim/neovim/releases/download/nightly/nvim-linux64.tar.gz \
    | tar xzf - --strip-components=1 -C "$NVIM_INSTALL_PREFIX"
  "$NVIM_PROG" --version
}

get_or_build_deps() {
  rm -rf "${DEPS_INSTALL_PREFIX}"

  # Use cached dependencies if available (and not forced).
  if [[ -f "${CACHE_MARKER}" ]] && [[ "${BUILD_NVIM_DEPS}" != true ]]; then
    echo "Using cached dependencies (last updated: $(stat -c '%y' "${CACHE_MARKER}"))."

    mkdir -p "$(dirname "${DEPS_INSTALL_PREFIX}")"
    ln -Ts "${HOME}/.cache/nvim-deps" "${DEPS_INSTALL_PREFIX}"
    return
  fi

  ${MAKE_CMD} deps
  get_nvim
}

run_tests() {
  make test
  echo "${SUCCESS_MARKER}"
  touch "${SUCCESS_MARKER}"
}

get_or_build_deps

# Display info for logs.
"${DEPS_INSTALL_PREFIX}/bin/luarocks" list
${NVIM_PROG} --version

run_tests
