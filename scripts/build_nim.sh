#!/usr/bin/env bash
# used in Travis CI and AppVeyor scripts

# Copyright (c) 2018-2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -e

# Git commits
CSOURCES_COMMIT="f72f471adb743bea4f8d8c59d19aa1cb885dcc59" # 0.20.0
NIMBLE_COMMIT="4007b2a778429a978e12307bf13a038029b4c4d9" # 0.11.0

# script arguments
[[ $# -ne 4 ]] && { echo "Usage: $0 nim_dir csources_dir nimble_dir ci_cache_dir"; exit 1; }
NIM_DIR="$1"
CSOURCES_DIR="$2" # can be relative to NIM_DIR
NIMBLE_DIR="$3" # can be relative to NIM_DIR
CI_CACHE="$4"

## env vars
# verbosity level
[[ -z "$V" ]] && V=0
[[ -z "$CC" ]] && CC="gcc"
# to build csources in parallel, set MAKE="make -jN"
[[ -z "$MAKE" ]] && MAKE="make"
# for 32-bit binaries on a 64-bit host
UCPU=""
[[ "$ARCH_OVERRIDE" == "x86" ]] && UCPU="ucpu=i686"
[[ -z "$NIM_BUILD_MSG" ]] && NIM_BUILD_MSG="Building the Nim compiler"
[[ -z "$QUICK_AND_DIRTY_COMPILER" ]] && QUICK_AND_DIRTY_COMPILER=0

# Windows detection
if uname | grep -qiE "mingw|msys"; then
	ON_WINDOWS=1
	EXE_SUFFIX=".exe"
	# otherwise it fails in AppVeyor due to https://github.com/git-for-windows/git/issues/2495
	GIT_TIMESTAMP_ARG="--date=unix" # available since Git 2.9.4
else
	ON_WINDOWS=0
	EXE_SUFFIX=""
	GIT_TIMESTAMP_ARG="--date=format-local:%s" # available since Git 2.7.0
fi

NIM_BINARY="${NIM_DIR}/bin/nim${EXE_SUFFIX}"

nim_needs_rebuilding() {
	REBUILD=0
	NO_REBUILD=1

	if [[ ! -e "$NIM_DIR" ]]; then
		git clone -q --depth=1 https://github.com/status-im/Nim.git "$NIM_DIR"
	fi

	if [[ -n "$CI_CACHE" && -d "$CI_CACHE" ]]; then
		cp -a "$CI_CACHE"/* "$NIM_DIR"/bin/ || true # let this one fail with an empty cache dir
	fi

	# compare the built commit's timestamp to the date of the last commit (keep in mind that Git doesn't preserve file timestamps)
	if [[ -e "${NIM_DIR}/bin/timestamp" && $(cat "${NIM_DIR}/bin/timestamp") -eq $(cd "$NIM_DIR"; git log --pretty=format:%cd -n 1 ${GIT_TIMESTAMP_ARG}) ]]; then
		return $NO_REBUILD
	else
		return $REBUILD
	fi
}

build_nim() {
	echo -e "$NIM_BUILD_MSG"
	[[ "$V" == "0" ]] && exec &>/dev/null

	# working directory
	pushd "$NIM_DIR"

	# Git repos for csources and Nimble
	if [[ ! -d "$CSOURCES_DIR" ]]; then
		mkdir -p "$CSOURCES_DIR"
		pushd "$CSOURCES_DIR"
		git clone https://github.com/nim-lang/csources.git .
		git checkout $CSOURCES_COMMIT
		popd
	fi
	if [[ "$CSOURCES_DIR" != "csources" ]]; then
		rm -rf csources
		ln -s "$CSOURCES_DIR" csources
	fi

	if [[ ! -d "$NIMBLE_DIR" ]]; then
		mkdir -p "$NIMBLE_DIR"
		pushd "$NIMBLE_DIR"
		git clone https://github.com/nim-lang/nimble.git .
		git checkout $NIMBLE_COMMIT
		# we have to delete .git or koch.nim will checkout a branch tip, overriding our target commit
		rm -rf .git
		popd
	fi
	if [[ "$NIMBLE_DIR" != "dist/nimble" ]]; then
		mkdir -p dist
		rm -rf dist/nimble
		ln -s ../"$NIMBLE_DIR" dist/nimble
	fi

	# bootstrap the Nim compiler and build the tools
	rm -rf bin/nim_csources
	pushd csources
	if [[ "$ON_WINDOWS" == "0" ]]; then
		$MAKE $UCPU clean
		$MAKE $UCPU LD=$CC
	else
		$MAKE myos=windows $UCPU clean
		$MAKE myos=windows $UCPU CC=gcc LD=gcc
	fi
	popd
	if [[ -e csources/bin ]]; then
		cp -a csources/bin/nim bin/nim
		cp -a csources/bin/nim bin/nim_csources
		rm -rf csources/bin
	else
		cp -a bin/nim bin/nim_csources
	fi
	if [[ "$QUICK_AND_DIRTY_COMPILER" == "0" ]]; then
		sed \
			-e 's/koch$/--warnings:off --hints:off koch/' \
			-e 's/koch boot/koch boot --warnings:off --hints:off/' \
			-e 's/koch tools/koch --stable tools --warnings:off --hints:off/' \
			build_all.sh > build_all_custom.sh
		sh build_all_custom.sh
		rm build_all_custom.sh
	else
		# Don't re-build it multiple times until we get identical
		# binaries, like "build_all.sh" does. Don't build any tools
		# either. This is all about build speed, not developer comfort.
		bin/nim_csources \
			c \
			--compileOnly \
			--nimcache:nimcache \
			-d:release \
			--skipUserCfg \
			--skipParentCfg \
			--warnings:off \
			--hints:off \
			compiler/nim.nim
		bin/nim_csources \
			jsonscript \
			--nimcache:nimcache \
			--skipUserCfg \
			--skipParentCfg \
			compiler/nim.nim
		cp -a compiler/nim bin/nim1
		# If we stop here, we risk ending up with a buggy compiler: https://github.com/status-im/nimbus-eth2/pull/2220
		bin/nim1 \
			c \
			--compileOnly \
			--nimcache:nimcache \
			-d:release \
			--skipUserCfg \
			--skipParentCfg \
			--warnings:off \
			--hints:off \
			compiler/nim.nim
		bin/nim1 \
			jsonscript \
			--nimcache:nimcache \
			--skipUserCfg \
			--skipParentCfg \
			compiler/nim.nim
		cp -a compiler/nim bin/nim
		rm bin/nim1
	fi

	# record the last commit's timestamp
	git log --pretty=format:%cd -n 1 ${GIT_TIMESTAMP_ARG} > bin/timestamp

	# update the CI cache
	popd # we were in $NIM_DIR
	if [[ -n "$CI_CACHE" ]]; then
		rm -rf "$CI_CACHE"
		mkdir "$CI_CACHE"
		cp -a "$NIM_DIR"/bin/* "$CI_CACHE"/
	fi
}

if nim_needs_rebuilding; then
	build_nim
fi
