#!/usr/bin/env bash

# Copyright (c) 2018-2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -u

module_name="${1#*/}"

if [ `ls -1 *.nimble 2>/dev/null | wc -l ` -gt 0 ]; then
  mkdir -p "${NIMBLE_DIR}/pkgs/${module_name}-#head"
  PKG_DIR="$(${PWD_CMD})"
  if [ -d src ]; then
    PKG_DIR="${PKG_DIR}/src"
  fi
  echo -e "${PKG_DIR}\n${PKG_DIR}" > "${NIMBLE_DIR}/pkgs/${module_name}-#head/${module_name}.nimble-link"
fi

