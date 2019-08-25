#!/bin/bash

# Copyright (c) 2018-2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -e

CACHE_DIR="$1" # optional parameter pointing to a CI cache dir.
LIBP2P_COMMIT="v0.2.1" # tags work too
SUBREPO_DIR="vendor/go/src/github.com/libp2p/go-libp2p-daemon"
if [[ ! -e "$SUBREPO_DIR" ]]; then
	# we're probably in nim-libp2p's CI
	SUBREPO_DIR="go-libp2p-daemon"
	git clone https://github.com/libp2p/go-libp2p-daemon
	cd "$SUBREPO_DIR"
	git checkout $LIBP2P_COMMIT
	cd ..
fi

## env vars
# verbosity level
[[ -z "$V" ]] && V=0
[[ -z "$BUILD_MSG" ]] && BUILD_MSG="Building p2pd"

# Windows detection
if uname | grep -qiE "mingw|msys"; then
	EXE_SUFFIX=".exe"
else
	EXE_SUFFIX=""
fi

# macOS
if uname | grep -qi "darwin"; then
	STAT_FORMAT="-f %m"
else
	STAT_FORMAT="-c %Y"
fi

TARGET_DIR="${GOPATH}/bin"
TARGET_BINARY="${TARGET_DIR}/p2pd${EXE_SUFFIX}"

target_needs_rebuilding() {
	REBUILD=0
	NO_REBUILD=1

	if [[ -n "$CACHE_DIR" && -e "${CACHE_DIR}/p2pd${EXE_SUFFIX}" ]]; then
		mkdir -p "${TARGET_DIR}"
		cp -a "$CACHE_DIR"/* "${TARGET_DIR}/"
	fi

	# compare binary mtime to the date of the last commit (keep in mind that Git doesn't preserve file timestamps)
	if [[ -e "$TARGET_BINARY" && $(stat $STAT_FORMAT "$TARGET_BINARY") -gt $(cd "$SUBREPO_DIR"; git log --pretty=format:%cd -n 1 --date=unix) ]]; then
		return $NO_REBUILD
	else
		return $REBUILD
	fi
}

build_target() {
	echo -e "$BUILD_MSG"
	[[ "$V" == "0" ]] && exec &>/dev/null

	pushd "$SUBREPO_DIR"
	# Go module downloads can fail randomly in CI VMs, so retry them a few times
	MAX_RETRIES=5
	CURR=0
	while [[ $CURR -lt $MAX_RETRIES ]]; do
		FAILED=0
		go get ./... && break || FAILED=1
		CURR=$(( CURR + 1 ))
		echo "retry #${CURR}"
	done
	if [[ $FAILED == 1 ]]; then
		echo "Error: still fails after retrying ${MAX_RETRIES} times."
		exit 1
	fi
	go install ./...
	popd

	# update the CI cache
	if [[ -n "$CACHE_DIR" ]]; then
		rm -rf "$CACHE_DIR"
		mkdir "$CACHE_DIR"
		cp -a "$TARGET_DIR"/* "$CACHE_DIR"/
	fi
}

if target_needs_rebuilding; then
	build_target
fi

