#!/usr/bin/env bash

# Copyright (c) 2018-2021 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -u

module_name="${1#*/}"

if [[ $(ls -1 *.nimble 2>/dev/null | wc -l) -gt 0 ]]; then
  PKG_DIR="$(${PWD_CMD})"
  for EXCLUDED_REL_PATH in ${EXCLUDED_NIM_PACKAGES}; do
    if [[ "${PKG_DIR}" =~ ${EXCLUDED_REL_PATH} ]]; then
      # skip it
      exit
    fi
  done

  if [[ -d src ]]; then
    PKG_DIR="${PKG_DIR}/src"
  fi
  mkdir -p "${NIMBLE_DIR}/pkgs/${module_name}-#head"

  NIMBLE_LINK_PATH="${NIMBLE_DIR}/pkgs/${module_name}-#head/${module_name}.nimble-link"
  if [[ -e "${NIMBLE_LINK_PATH}" ]]; then
    echo -e "\nERROR: Nim package already present in '${NIMBLE_LINK_PATH}': '$(head -n1 "${NIMBLE_LINK_PATH}")'"
    echo -e "Will not replace it with '${PKG_DIR}'.\nPick one and put the other's relative path in EXCLUDED_NIM_PACKAGES.\nSee also: https://github.com/status-im/nimbus-build-system#excluded_nim_packages\n"
    rm -rf "${NIMBLE_DIR}"
    exit 1
  fi
  echo -e "${PKG_DIR}\n${PKG_DIR}" > "${NIMBLE_LINK_PATH}"
fi

