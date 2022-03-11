#!/bin/bash

# Unlock the encrypted directory.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
. "$SCRIPT_DIR/common.sh"

"$SCRIPT_DIR/key.py" | fscryptctl add_key "$MNT" > /dev/null
