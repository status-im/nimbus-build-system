#!/usr/bin/env bash

set -e

if [[ -f .gitmodules ]]; then
  git config --file .gitmodules --get-regexp 'path|url' | while read TMP S_PATH && read TMP S_URL; do
    # we probably can't rely on that leading space always being there
    S_HASH=$(git submodule status --cached "${S_PATH}" | sed 's/^\s*\(\S\+\).*$/\1/')
    echo "${S_URL} ${S_HASH}"
  done
fi

