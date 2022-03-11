#!/usr/bin/env python3

import argparse
import hashlib
import sys


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Output the key for testing")
    parser.add_argument("password", default="", nargs="?")
    parser.add_argument("size", type=int, default=64, nargs="?")
    args = parser.parse_args()
    sys.stdout.buffer.write(
        hashlib.pbkdf2_hmac(
            "sha256",
            args.password.encode(),
            salt=bytes(16),
            # This is just for testing, so make it fast.
            iterations=1,
            dklen=args.size,
        )
    )
