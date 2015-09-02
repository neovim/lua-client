#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"

build_deps() {
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
  touch "${SUCCESS_MARKER}"
}

build_deps
run_tests

