# Development scripts and notes for Btrfs fscrypt

This repository contains some simple scripts that I've used for developing fscrypt for Btrfs.

## Setup

* Build the [fscryptctl Btrfs fork](https://github.com/osandov/fscryptctl/tree/btrfs).
* Create a `config.sh` file which defines:
    * `PATH` to include the fscryptctl build.
    * `DEV` as the block device to test on (which will be reformatted).
    * `MNT` as the mountpoint for the filesystem to test on.

For example:

```sh
export PATH="/home/vmuser/repos/fscryptctl:$PATH"
DEV=/dev/vdb
MNT=/mnt
```

## Scripts

- [`recreate.sh`](recreate.sh): Create a Btrfs filesystem with fscrypt enabled.
- [`mount.sh`](mount.sh): Mount the previously created filesystem and unlock the encrypted directory.
- [`lock.sh`](lock.sh): Lock the encrypted directory.
- [`unlock.sh`](unlock.sh): Unlock the encrypted directory.
- [`smoke_test.sh`](smoke_test.sh): Run basic tests on Btrfs with fscrypt.
- [`key.py`](key.py): Output the key used by the encrypted directory.
