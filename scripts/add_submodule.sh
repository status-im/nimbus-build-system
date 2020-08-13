#!/usr/bin/env bash

# Copyright (c) 2018-2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

[ -z "$1" -o `echo "$1" | tr '/' '\n' | wc -l` != 2 ] && \
	{ echo "Usage: `basename $0` some/repo [destdir] # 'destdir' defaults to 'vendor/repo'"; exit 1; }
REPO="$1"

DEST="vendor/${REPO#*/}"
[ -n "$2" ] && DEST="$2"

git submodule add --force https://github.com/${REPO}.git "$DEST"
git config -f .gitmodules submodule.${DEST}.ignore dirty
git config -f .gitmodules submodule.${DEST}.branch master

