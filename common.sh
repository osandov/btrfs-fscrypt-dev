#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

if [[ ! -e "$SCRIPT_DIR/config.sh" ]]; then
	cat >&2 << EOF
Please create config.sh in $SCRIPT_DIR

It should define:

* PATH to include a build of https://github.com/osandov/fscryptctl/tree/btrfs.
* DEV as the block device to test on (which will be reformatted).
* MNT as the mountpoint for the filesystem to test on.

E.g.:

export PATH="/home/vmuser/repos/fscryptctl:\$PATH"
DEV=/dev/vdb
MNT=/mnt
EOF
	exit 1
fi

. "$SCRIPT_DIR/config.sh"

if [[ -z ${DEV+x} ]]; then
	echo "config.sh did not set DEV" >&2
	exit 1
fi
if [[ -z ${MNT+x} ]]; then
	echo "config.sh did not set MNT" >&2
	exit 1
fi
