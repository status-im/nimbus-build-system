#!/usr/bin/env bash

# Copyright (c) 2018-2019 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

######################################################
# run *.nimble tasks using "nim" instead of "nimble" #
######################################################

# exit on command error
set -e

[ -z "$1" ] && { echo "usage: $0 task_name"; exit 1; }

F=""
for F in *.nimble; do
	# get the first one
	break
done
[ -z "$F" ] && { echo "No *.nimble file found."; exit 1; }

# "nim" seems to only run custom NimScript files if they have a "nims" extension
NIMS="${F%.nimble}.nims"
# delete the temporary symlink on script exit
cleanup() {
	rm -rf "$NIMS"
}
[ -e "$NIMS" ] || { ln -s "$F" "$NIMS"; trap cleanup EXIT; }

# can't have an "exec" here or the EXIT pseudo-signal won't be triggered
$(dirname $0)/env.sh nim "$@" "$NIMS"

