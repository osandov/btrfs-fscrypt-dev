#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

if [[ ! -e "$SCRIPT_DIR/config.sh" ]]; then
	echo "please create config.sh in $SCRIPT_DIR" >&2
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
