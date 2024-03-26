#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

cd "$TOP_LEVEL_DIR"

# We use a temp path to make this safe under concurrent builds.
# Once the paths file is fully generated, we will move it to its final
# destination. If were were directly writing to the final path instead,
# we risk that the contents produced from multiple `create_nbs_paths.sh`
# invocations may get interleaved.
temp_nbs_paths=$(mktemp nimbus-build-system.paths.XXXXXXXXXXXXXXX)

echo "--noNimblePath" > "${temp_nbs_paths}"
for file in $(ls -d "$PWD/vendor"/*)
do
  if uname | grep -qiE "mingw|msys"; then
    file=$(cygpath -m "${file}")
  fi
  if [ -d "$file/src" ]; then
    echo --path:"\"$file/src\""
  else
    echo --path:"\"$file\""
  fi
done >> "${temp_nbs_paths}"

mv "${temp_nbs_paths}" nimbus-build-system.paths
