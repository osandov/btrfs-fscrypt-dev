#!/bin/bash

# Mount the filesystem and unlock the encrypted directory.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
. "$SCRIPT_DIR/common.sh"

mount "$DEV" "$MNT"
"$SCRIPT_DIR/unlock.sh"
