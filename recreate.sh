#!/bin/bash

# Recreate the filesystem, mount it, and create an (unlocked) encrypted
# directory at the top level named "encrypted".

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
. "$SCRIPT_DIR/common.sh"

fstype="${1:-btrfs}"

if [ "$fstype" = "ext4" ]; then
	mkfs="mkfs.ext4 -O encrypt,inline_data -F"
else
	mkfs="mkfs.btrfs -f"
fi

$mkfs "$DEV" > /dev/null
mount "$DEV" "$MNT"

if [ "$fstype" = btrfs ]; then
	btrfs -q subvol create "$MNT/encrypted"
	extra_flags=--contents-explicit-iv
else
	mkdir "$MNT/encrypted"
	extra_flags=
fi
chmod 777 "$MNT" "$MNT/encrypted"

key_id=$("$SCRIPT_DIR/key.py" | fscryptctl add_key "$MNT")
fscryptctl set_policy $extra_flags "$key_id" "$MNT/encrypted"
