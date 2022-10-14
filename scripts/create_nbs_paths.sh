#!/usr/bin/env bash

cd "$TOP_LEVEL_DIR"

echo "--noNimblePath" > nimbus-build-system.paths
for file in $(ls -d $PWD/vendor/*)
do
  if uname | grep -qiE "mingw|msys"; then
    file=$(cygpath -m $file)
  fi
  if [ -d "$file/src" ]; then
    echo --path:"\"$file/src\""
  else
    echo --path:"\"$file\""
  fi
done >> nimbus-build-system.paths
