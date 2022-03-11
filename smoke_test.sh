#!/bin/bash

# Run basic tests on an encrypted filesystem. Note that this recreates the
# filesystem.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
. "$SCRIPT_DIR/common.sh"

status=0
assert_equal() {
	if [[ $1 != $2 ]]; then
		echo "assertion on line $BASH_LINENO failed: $1 != $2" >&2
		status=1
	fi
}

assert_match() {
	if [[ ! $1 =~ $2 ]]; then
		echo "assertion on line $BASH_LINENO failed: $1 does not match /$2/" >&2
		status=1
	fi
}

DIR="$MNT/encrypted"

mount_opts=(-o noatime)

trap 'if mountpoint -q "$MNT"; then umount "$MNT"; fi' EXIT

unmount() {
	umount "$MNT"
	# TODO: btrfs check doesn't support fscrypt yet
	# if ! output="$(btrfs check "$DEV" 2>&1)"; then
		# echo "$output"
		# status=1
	# fi
}

maybe_cycle_mount() {
	if [[ $should_cycle_mount != 0 ]]; then
		unmount
		"$SCRIPT_DIR/mount.sh"
	fi
}

run_test() {
	local need_cycle_mount="${2-1}"
	if [[ $need_cycle_mount -ne 0 && $need_cycle_mount -ne 1 ]]; then
		echo "invalid need_cycle_mount" >&2
		exit 1
	fi
	local should_cycle_mount
	for ((should_cycle_mount=0; should_cycle_mount <= need_cycle_mount; should_cycle_mount++)); do
		if [[ $should_cycle_mount -ne 0 ]]; then
			echo "Running $1 (with cycle mount)"
		else
			echo "Running $1"
		fi
		"$SCRIPT_DIR/recreate.sh"
		"$1"
		unmount
	done
}

umask 022

test_create() {
	# Note: we want to make sure that the inode is created correctly even if it
	# isn't modified after it's created, so don't use touch, which calls
	# utimensat() and would cause an inode update.
	> "$DIR/reg"
	mkdir "$DIR/dir"
	mknod "$DIR/chr" c 1 3
	mknod "$DIR/blk" b 2 0
	mkfifo "$DIR/fifo"  
	python3 -c 'import socket, sys

with socket.socket(socket.AF_UNIX) as sock:
    sock.bind(sys.argv[1])
' "$DIR/sock"
	ln -s reg "$DIR/lnk"
	btrfs -q subvol create "$DIR/vol"

	maybe_cycle_mount

	# Regular
	assert_equal "$(stat -c %A "$DIR/reg")" "-rw-r--r--"
	assert_equal "$(stat -c %h "$DIR/reg")" "1"
	assert_equal "$(stat -c %s "$DIR/reg")" "0"
	assert_equal "$(stat -c %b "$DIR/reg")" "0"

	# Directory
	assert_equal "$(stat -c %A "$DIR/dir")" "drwxr-xr-x"

	# Character
	assert_equal "$(stat -c %A "$DIR/chr")" "crw-r--r--"
	assert_equal "$(stat -c %t,%T "$DIR/chr")" "1,3"

	# Block
	assert_equal "$(stat -c %A "$DIR/blk")" "brw-r--r--"
	assert_equal "$(stat -c %t,%T "$DIR/blk")" "2,0"

	# FIFO
	assert_equal "$(stat -c %A "$DIR/fifo")" "prw-r--r--"

	# Socket
	assert_equal "$(stat -c %A "$DIR/sock")" "srwxr-xr-x"

	# Symlink
	assert_equal "$(stat -c %A "$DIR/lnk")" "lrwxrwxrwx"
	assert_equal "$(readlink "$DIR/lnk")" reg
	assert_equal "$(stat -L -c %A "$DIR/lnk")" "-rw-r--r--"

	# Subvolume
	assert_equal "$(stat -c %A "$DIR/vol")" "drwxr-xr-x"
	assert_equal "$(stat -c %i "$DIR/vol")" 256

	assert_equal "$(ls -1 "$DIR")" \
"blk
chr
dir
fifo
lnk
reg
sock
vol"
}

run_test test_create

test_data() {
	echo "Hello, world!" > "$DIR/small"
	seq 500000 > "$DIR/big"

	maybe_cycle_mount

	assert_equal "$(cat "$DIR/small")" "Hello, world!"
	assert_equal "$(seq 500000 | cmp --silent - "$DIR/big"; echo $?)" 0
}

run_test test_data

test_property() {
	mkdir "$DIR/property"
	btrfs property set "$DIR/property" compression zstd
	> "$DIR/property/file"
	mkdir "$DIR/property/dir"

	maybe_cycle_mount

	assert_match "$(lsattr "$DIR/property/file" | awk '{ print $1 }')" c
	assert_equal "$(getfattr --absolute-names --only-values -n btrfs.compression "$DIR/property/file")" "zstd"
	assert_equal "$(getfattr --absolute-names --only-values -n btrfs.compression "$DIR/property/dir")" "zstd"
}

run_test test_property

test_aclinherit() {
	mkdir "$DIR/aclinherit"
	setfacl -d -m user:daemon:rwx "$DIR/aclinherit"
	> "$DIR/aclinherit/reg"
	mkdir "$DIR/aclinherit/dir"

	maybe_cycle_mount

	assert_equal "$(getfacl -cpE "$DIR/aclinherit/reg")" \
"user::rw-
user:daemon:rwx
group::r-x
mask::rw-
other::r--"
	assert_equal "$(getfacl -cpE "$DIR/aclinherit/dir")" \
"user::rwx
user:daemon:rwx
group::r-x
mask::rwx
other::r-x
default:user::rwx
default:user:daemon:rwx
default:group::r-x
default:mask::rwx
default:other::r-x"
}

run_test test_aclinherit

test_aclmode() {
	mkdir "$DIR/aclmode"
	setfacl -d -m user::r-x "$DIR/aclmode"
	> "$DIR/aclmode/reg"
	mkdir "$DIR/aclmode/dir"

	maybe_cycle_mount

	assert_equal "$(stat -c %A "$DIR/aclmode/reg")" "-r--r--r--"
	assert_equal "$(stat -c %A "$DIR/aclmode/dir")" "dr-xr-xr-x"
	assert_equal "$(getfacl -cp "$DIR/aclmode/dir")" \
"user::r-x
group::r-x
other::r-x
default:user::r-x
default:group::r-x
default:other::r-x"
}

run_test test_aclmode

test_smack() {
	(
	echo ripcd > /proc/self/attr/current
	> "$DIR/smack"
	)

	maybe_cycle_mount

	assert_equal "$(getfattr --absolute-names --only-values -n security.SMACK64 "$DIR/smack")" "ripcd"
}

if [[ -e /sys/fs/smackfs ]]; then
	run_test test_smack
else
	echo "SMACK is not enabled; boot with lsm=smack" >&2
fi

test_unlink() {
	> "$DIR/tounlink"
	sync -f "$DIR/tounlink"
	rm "$DIR/tounlink"

	maybe_cycle_mount

	assert_equal "$( if [[ -e "$DIR/tounlink" ]]; then echo "Exists"; fi )" ""
}

run_test test_unlink

test_rename() {
	mkdir "$DIR/rename"
	echo torename > "$DIR/rename/torename"
	echo toexchange1 > "$DIR/rename/exchange1"
	echo toexchange2 > "$DIR/rename/exchange2"
	echo whiteout > "$DIR/rename/wht"
	python3 -c 'import ctypes, os, sys

_renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
_renameat2.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
_renameat2.restype = ctypes.c_int

AT_FDCWD = -100
RENAME_EXCHANGE = 1 << 1
RENAME_WHITEOUT = 1 << 2

def rename(src, dst, flags=0):
    ret = _renameat2(AT_FDCWD, os.fsencode(src), AT_FDCWD, os.fsencode(dst), flags)
    if ret < 0:
        err = ctypes.get_errno()
        raise OSError(err, os.strerror(err), src, None, dst)

rename(sys.argv[1] + "/torename", sys.argv[1] + "/renamed")
rename(sys.argv[1] + "/exchange1", sys.argv[1] + "/exchange2", RENAME_EXCHANGE)
rename(sys.argv[1] + "/wht", sys.argv[1] + "/whtdst", RENAME_WHITEOUT)
' "$DIR/rename"

	maybe_cycle_mount

	assert_equal "$(cat "$DIR/rename/renamed")" "torename"

	assert_equal "$(cat "$DIR/rename/exchange1")" "toexchange2"
	assert_equal "$(cat "$DIR/rename/exchange2")" "toexchange1"

	# Whiteout
	assert_equal "$(stat -c %A "$DIR/rename/wht")" "c---------"
	assert_equal "$(stat -c %t,%T "$DIR/rename/wht")" "0,0"
	assert_equal "$(cat "$DIR/rename/whtdst")" "whiteout"
}

run_test test_rename

test_tempfile() {
	if ! python3 -c 'import os, stat, subprocess, sys, tempfile

def assert_equal(actual, expected):
    if actual != expected:
        raise AssertionError(f"{actual} != {expected}")

with tempfile.TemporaryFile(dir=sys.argv[1]) as f:
    st = os.stat(f.fileno())
    assert stat.S_ISREG(st.st_mode)
    assert_equal(stat.S_IMODE(st.st_mode), 0o600)
    assert_equal(st.st_nlink, 0)
    assert_equal(st.st_size, 0)
    assert_equal(st.st_blocks, 0)

    os.sync()

    # proc = subprocess.run(
        # ["btrfs", "check", "--force", sys.argv[2]],
        # stdout=subprocess.PIPE,
        # stderr=subprocess.STDOUT,
    # )
# if proc.returncode:
    # sys.stdout.buffer.write(proc.stdout)
# sys.exit(proc.returncode)
' "$DIR" "$DEV"; then
		status=1
	fi
}

run_test test_tempfile 0

if [[ $status -eq 0 ]]; then
	echo "All tests passed :)"
else
	echo "Some tests failed :("
fi
exit "$status"
