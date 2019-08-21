#!/bin/sh

# Copyright (c) 2018-2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

#PWD_CMD="pwd"
## get native Windows paths on Mingw
#uname | grep -qi mingw && PWD_CMD="pwd -W"

export REL_PATH="$(dirname $0)"
export ABS_PATH="$(cd ${REL_PATH}; pwd)"
# do we still need this?
#ABS_PATH_NATIVE="$(cd ${REL_PATH}; ${PWD_CMD})"

export NIMBUS_ENV_DIR="${ABS_PATH}"

# used by libp2p/go-libp2p-daemon
export GOPATH="${ABS_PATH}/../../go"
export GO111MODULE=on

#- make it an absolute path, so we can call this script from other dirs
#- we can't use native Windows paths in here, because colons can't be escaped in PATH
export PATH="${ABS_PATH}/../../Nim/bin:${GOPATH}/bin:${PATH}"

# Nimble needs this to be an absolute path
export NIMBLE_DIR="${ABS_PATH}/../../.nimble"

# used by nim-beacon-chain/tests/simulation/start.sh
export BUILD_OUTPUTS_DIR="${ABS_PATH}/../../../build"

# change the prompt in shells that source this file
export PS1="${PS1%\\\$ } [Nimbus env]\\$ "

# functions, instead of aliases, to avoid typing long paths (aliases don't seem
# to be expanded by default for command line arguments)
nimble() {
	"${ABS_PATH}/nimble.sh" "$@"
}
export -f nimble

add_submodule() {
	"${ABS_PATH}/add_submodule.sh" "$@"
}
export -f add_submodule

# can't use "exec" here if we're getting function names as params
"$@"

