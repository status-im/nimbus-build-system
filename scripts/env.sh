#!/usr/bin/env bash

# Copyright (c) 2018-2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

#PWD_CMD="pwd"
## get native Windows paths on Mingw
#uname | grep -qi mingw && PWD_CMD="pwd -W"

# We use ${BASH_SOURCE[0]} instead of $0 to allow sourcing this file
# and we fall back to a Zsh-specific special var to also support Zsh.
export REL_PATH="$(dirname ${BASH_SOURCE[0]:-${(%):-%x}})"
export ABS_PATH="$(cd ${REL_PATH}; pwd)"
# do we still need this?
#ABS_PATH_NATIVE="$(cd ${REL_PATH}; ${PWD_CMD})"

export NIMBUS_ENV_DIR="${ABS_PATH}"

# looks like oh-my-zsh can't handle dots in PATH
export NIM_PATH=$(cd "${ABS_PATH}/../vendor/Nim/bin"; pwd)

# Nimble needs this to be an absolute path
export NIMBLE_DIR=$(cd "${ABS_PATH}/../../.nimble"; pwd)

# we don't use Nimble-installed binaries, but just in case
export PATH="${NIMBLE_DIR}/bin:${PATH}"

#- make it an absolute path, so we can call this script from other dirs
#- we can't use native Windows paths in here, because colons can't be escaped in PATH
if [[ "$USE_SYSTEM_NIM" != "1" ]]; then
	export PATH="${NIM_PATH}:${PATH}"
else
	echo "[using system Nim: $(which nim)]" 1>&2
fi

if [[ -n "${NIM_COMMIT}" && "${NIM_COMMIT}" != "nimbus" ]]; then
	echo "[using Nim version ${NIM_COMMIT}]" 1>&2
fi

# used by nim-beacon-chain/tests/simulation/start.sh
export BUILD_OUTPUTS_DIR="${ABS_PATH}/../../../build"

# change the prompt in shells that source this file
if [[ -n "$BASH_VERSION" ]]; then
	export PS1="${PS1%\\\$ } [Nimbus env]\\$ "
	EXPORT_FUNC="export -f"
fi
if [[ -n "$ZSH_VERSION" ]]; then
	export PS1="[Nimbus env] $PS1"
	EXPORT_FUNC="export" # doesn't actually work, because Zsh doesn't support exporting functions
fi

# functions, instead of aliases, to avoid typing long paths (aliases don't seem
# to be expanded by default for command line arguments)
nimble() {
	"${ABS_PATH}/nimble.sh" "$@"
}
$EXPORT_FUNC nimble

add_submodule() {
	"${ABS_PATH}/add_submodule.sh" "$@"
}
$EXPORT_FUNC add_submodule

export NIMBUS_BUILD_SYSTEM=yes

if [[ ! -n "$NBS_ONLY_LOAD_ENV_VARS" ]]; then
  if [[ $# == 1 && $1 == "bash" ]]; then
    # the only way to change PS1 in a child shell, apparently
    # (we're not getting the original PS1 value in here, so set a complete and nice prompt)
    export PS1="[Nimbus env] \[\033[0;31m\]\l \[\033[1;33m\]\d \[\033[1;36m\]\t \[\033[0;32m\]|\w|\[\033[0m\]\n\u\$ "
    exec "$1" --login --noprofile
  else
    # can't use "exec" here if we're getting function names as params
   "$@"
  fi
fi
