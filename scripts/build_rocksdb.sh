#!/usr/bin/env bash
# used in Travis CI scripts

# Copyright (c) 2018-2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -e

ROCKSDBVER="5.17.2"

# script arguments
[[ $# -ne 1 ]] && { echo "Usage: $0 ci_cache_dir"; exit 1; }
CI_CACHE="$1" # here we cache the installed files

# env vars

[[ -z "$NPROC" ]] && NPROC=2 # number of CPU cores available

# install from cache and exit, if the version we want is already there
if [[ -n "$CI_CACHE" ]] && ls "$CI_CACHE"/lib/librocksdb* 2>/dev/null | grep -q "$ROCKSDBVER"; then
	sudo cp -a "$CI_CACHE"/* /usr/local/
	exit 0
fi

# build it
echo "Building RocksDB"
curl -O -L -s -S https://github.com/facebook/rocksdb/archive/v${ROCKSDBVER}.tar.gz
tar xzf v${ROCKSDBVER}.tar.gz
cd rocksdb-${ROCKSDBVER}
make DISABLE_WARNING_AS_ERROR=1 -j${NPROC} shared_lib

# install it
if [[ -n "../$CI_CACHE" ]]; then
	rm -rf "../$CI_CACHE"
	mkdir "../$CI_CACHE"
	make INSTALL_PATH="../$CI_CACHE" install-shared
	sudo cp -a "../$CI_CACHE"/* /usr/local/
fi

