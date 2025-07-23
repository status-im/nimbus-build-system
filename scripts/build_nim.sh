#!/usr/bin/env bash
# Copyright (c) 2018-2024 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

set -eo pipefail

# NIM_COMMIT could be a (partial) commit hash, a tag, a branch name, etc. Empty by default.
NIM_COMMIT_HASH="" # full hash for NIM_COMMIT, retrieved in "nim_needs_rebuilding()"

# script arguments
[[ $# -ne 4 ]] && { echo "Usage: $0 nim_dir csources_dir nimble_dir ci_cache_dir"; exit 1; }
NIM_DIR="$1"
CSOURCES_DIR="$2" # can be relative to NIM_DIR; only used when `skipIntegrityCheck` unsupported
NIMBLE_DIR="$3" # can be relative to NIM_DIR; only used when `skipIntegrityCheck` unsupported
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
[[ -z "$QUICK_AND_DIRTY_NIMBLE" ]] && QUICK_AND_DIRTY_NIMBLE=0

# Windows detection
if uname | grep -qiE "mingw|msys"; then
	ON_WINDOWS=1
	EXE_SUFFIX=".exe"
else
	ON_WINDOWS=0
	EXE_SUFFIX=""
fi

NIM_BINARY="${NIM_DIR}/bin/nim${EXE_SUFFIX}"
MAX_NIM_BINARIES="10" # Old ones get deleted.

nim_needs_rebuilding() {
	REBUILD=0
	NO_REBUILD=1

	if [[ ! -e "$NIM_DIR" ]]; then
		# Shallow clone, optimised for the default NIM_COMMIT value.
		git clone -q --depth=1 https://github.com/nim-lang/Nim.git "$NIM_DIR"
	fi

	pushd "${NIM_DIR}" >/dev/null
	if [[ -n "${NIM_COMMIT}" ]]; then
		# support old Git versions, like the one from Ubuntu-18.04
		git restore . 2>/dev/null || git reset --hard
		if ! git checkout -q "${NIM_COMMIT}" 2>/dev/null; then
			# Pay the price for a non-default NIM_COMMIT here, by fetching everything.
			# The "upstream" remote (pointing at the same location as the "origin")
			# is kept for backward compatibility.
			if ! git remote | grep -q "^upstream$"; then
				git remote add upstream https://github.com/nim-lang/Nim
			fi
			# If the user has specified a custom repo, add it here as a remote as well.
			if [[ -n "${NIM_COMMIT_REPO}" ]]; then
				git remote remove extra 2>/dev/null || true
				git remote add extra "${NIM_COMMIT_REPO}"
			fi
			git fetch --all --tags --quiet
			git checkout -q "${NIM_COMMIT}" ||
			  { echo "Error: wrong NIM_COMMIT specified:'${NIM_COMMIT}'"; exit 1; }
		fi
		# In case the local branch diverged and a fast-forward merge is not possible.
		git fetch || true
		git reset -q --hard origin/"${NIM_COMMIT}" 2>/dev/null || true
		# In case NIM_COMMIT is a local branch that's behind the remote one it's tracking.
		git pull -q 2>/dev/null || true
		git checkout -q "${NIM_COMMIT}"
		# We can't use "rev-parse" here, because it would return the tag object's
		# hash instead of the commit hash, when NIM_COMMIT is a tag.
		NIM_COMMIT_HASH="$(git rev-list -n 1 "${NIM_COMMIT}")"
	else
		# NIM_COMMIT is empty, so assume the commit we need is already checked out
		NIM_COMMIT_HASH="$(git rev-list -n 1 HEAD)"
	fi
	popd >/dev/null

	if [[ -n "$CI_CACHE" && -d "$CI_CACHE" ]]; then
		cp -a "$CI_CACHE"/* "$NIM_DIR"/bin/ || true # let this one fail with an empty cache dir
	fi

	# Delete old Nim binaries, to put a limit on how much storage we use.
	for F in "$(ls -t "${NIM_DIR}"/bin/nim_commit_* 2>/dev/null | tail -n +$((MAX_NIM_BINARIES + 1)))"; do
		if [[ -e "${F}" ]]; then
			rm "${F}"
		fi
	done

	# Compare the last built commit to the one requested.
	# Handle the scenario where our symlink is manually deleted by the user.
	if [[ -e "${NIM_DIR}/bin/last_built_commit" && \
	-e "${NIM_DIR}/bin/nim${EXE_SUFFIX}" && \
	"$(cat "${NIM_DIR}/bin/last_built_commit")" == "${NIM_COMMIT_HASH}" ]]; then
		return $NO_REBUILD
	elif [[ -e "${NIM_DIR}/bin/nim_commit_${NIM_COMMIT_HASH}" ]]; then
		# we built the requested commit in the past, so we simply reuse it
		rm -f "${NIM_DIR}/bin/nim${EXE_SUFFIX}"
		ln -s "nim_commit_${NIM_COMMIT_HASH}" "${NIM_DIR}/bin/nim${EXE_SUFFIX}"
		echo "${NIM_COMMIT_HASH}" > "${NIM_DIR}/bin/last_built_commit"
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
	# Get absolute path for NIM_DIR for later use
	NIM_DIR_ABS="$(pwd)"

	# Otherwise, when updating from pre-v2.0.10 to v2.0.10 or later,
	# https://github.com/nim-lang/Nim/issues/24173 occurs. Simulates
	# https://github.com/nim-lang/Nim/pull/24189 as a workaround.
	#
	# When building Nimbus from a Nix derivation which adds this as part of
	# a preBuild phase, do not use this hack, because it's both unnecessary
	# and prevents Nim from building.
	NIX_BUILD_TOP="${NIX_BUILD_TOP:-}"
	if [[ "${NIX_BUILD_TOP}" != "/build" ]]; then
		rm -rf dist/checksums
	fi

	if ! grep -q skipIntegrityCheck koch.nim; then
		echo "Please update your Nim version to 1.6.14 or newer"
		exit 1
	else
		# Run Nim buildchain, with matching dependency versions
		# - CSOURCES_REPO from Nim/config/build_config.txt (nim_csourcesUrl)
		# - CSOURCES_COMMIT from Nim/config/build_config.txt (nim_csourcesHash)
		# - NIMBLE_REPO from Nim/koch.nim (bundleNimbleExe)
		# - NIMBLE_COMMIT from Nim/koch.nim (NimbleStableCommit)
		. ci/funs.sh
		NIMCORES=1 nimBuildCsourcesIfNeeded $UCPU
		bin/nim c --noNimblePath --skipUserCfg --skipParentCfg --warnings:off --hints:off koch
		./koch --skipIntegrityCheck boot -d:release --skipUserCfg --skipParentCfg --warnings:off --hints:off
		if [[ "${QUICK_AND_DIRTY_COMPILER}" == "0" ]]; then
			# We want tools
			./koch tools -d:release --skipUserCfg --skipParentCfg --warnings:off --hints:off
		elif [[ "${QUICK_AND_DIRTY_NIMBLE}" != "0" && -z "${NIMBLE_COMMIT}" ]]; then
			# We just want nimble (but only if not building custom NIMBLE_COMMIT later)
			./koch nimble -d:release --skipUserCfg --skipParentCfg --warnings:off --hints:off
		fi
	fi

	# Handle custom NIMBLE_COMMIT if specified
	if [[ -n "${NIMBLE_COMMIT}" ]]; then
		echo "Building custom Nimble commit: ${NIMBLE_COMMIT}"
		# Save current directory
		ORIGINAL_DIR=$(pwd)
		
		# Clone Nimble repository in a temporary location
		NIMBLE_BUILD_DIR="${NIM_DIR_ABS}/nimble_build_temp"
		rm -rf "${NIMBLE_BUILD_DIR}"
		git clone -q https://github.com/nim-lang/nimble.git "${NIMBLE_BUILD_DIR}"
		
		# Checkout the specified commit
		pushd "${NIMBLE_BUILD_DIR}" >/dev/null
		git checkout -q "${NIMBLE_COMMIT}" || { echo "Error: wrong NIMBLE_COMMIT specified:'${NIMBLE_COMMIT}'"; exit 1; }
		git submodule update --init --recursive
		
		# Build Nimble using the just-built Nim
		echo "Building Nimble..."
		"${NIM_DIR_ABS}/bin/nim" c -d:release --noNimblePath src/nimble
		
		# Replace the existing nimble binary
		if [[ -f "src/nimble${EXE_SUFFIX}" ]]; then
			echo "Replacing nimble binary..."
			rm -f "${NIM_DIR_ABS}/bin/nimble${EXE_SUFFIX}"
			cp "src/nimble${EXE_SUFFIX}" "${NIM_DIR_ABS}/bin/nimble${EXE_SUFFIX}"
		else
			echo "Error: Nimble build failed"
			exit 1
		fi
		
		popd >/dev/null
		# Clean up
		rm -rf "${NIMBLE_BUILD_DIR}"
	fi

	if [[ "$QUICK_AND_DIRTY_COMPILER" == "0" || "${QUICK_AND_DIRTY_NIMBLE}" != "0" || -n "${NIMBLE_COMMIT}" ]]; then
		# Nimble needs a CA cert
		rm -f bin/cacert.pem
		curl -LsS -o bin/cacert.pem https://curl.se/ca/cacert.pem || echo "Warning: 'curl' failed to download a CA cert needed by Nimble. Ignoring it."
	fi

	# record the built commit
	echo "${NIM_COMMIT_HASH}" > bin/last_built_commit

	# create the symlink
	mv bin/nim bin/nim_commit_"${NIM_COMMIT_HASH}"
	ln -s nim_commit_"${NIM_COMMIT_HASH}" bin/nim${EXE_SUFFIX}

	# update the CI cache
	popd # we were in $NIM_DIR
	if [[ -n "$CI_CACHE" ]]; then
		rm -rf "$CI_CACHE"
		mkdir "$CI_CACHE"
		cp "$NIM_DIR"/bin/* "$CI_CACHE"/
	fi
}

if nim_needs_rebuilding; then
	build_nim
fi
