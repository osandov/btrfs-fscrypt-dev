#!/bin/bash

# Lock the encrypted directory.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
. "$SCRIPT_DIR/common.sh"

key_id=$(fscryptctl get_policy "$MNT/encrypted" | sed -rn 's/^\s*Master key identifier:\s*(\S+)\s*/\1/p')
fscryptctl remove_key "$key_id" "$MNT"
