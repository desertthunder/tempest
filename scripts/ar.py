#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "argon2-cffi>=23.1.0",
# ]
# ///
"""Generate a TEMPEST_ADMIN_TOKEN_HASH value.

Usage:
    scripts/ar.py
    scripts/ar.py 'my-long-admin-token'
    ADMIN_TOKEN='my-long-admin-token' scripts/ar.py --from-env

By default, the script generates a new random admin token and prints the token
once, along with the Argon2 hash to put in Railway or another secret manager.
"""

from __future__ import annotations

import argparse
import os
import secrets
import sys

from argon2 import PasswordHasher, Type


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Generate TEMPEST_ADMIN_TOKEN_HASH for Tempest admin auth.",
    )
    p.add_argument(
        "token",
        nargs="?",
        help="Admin token to hash. If omitted, a new token is generated.",
    )
    p.add_argument(
        "--from-env",
        action="store_true",
        help="Read the token from ADMIN_TOKEN instead of argv or generating one.",
    )
    p.add_argument(
        "--only-hash",
        action="store_true",
        help="Print only the Argon2 hash value.",
    )
    p.add_argument(
        "--allow-short",
        action="store_true",
        help="Allow tokens shorter than 32 characters.",
    )
    return p


def token_from_args(args: argparse.Namespace) -> tuple[str, bool]:
    if args.from_env:
        token = os.environ.get("ADMIN_TOKEN")
        if not token:
            raise SystemExit("ADMIN_TOKEN is empty or unset")
        return token, False

    if args.token:
        return args.token, False

    return secrets.token_urlsafe(48), True


def main() -> int:
    args = parser().parse_args()
    token, generated = token_from_args(args)

    if len(token) < 32 and not args.allow_short:
        raise SystemExit("admin token must be at least 32 characters; pass --allow-short to override")

    ph = PasswordHasher(type=Type.ID)
    token_hash = ph.hash(token)

    if args.only_hash:
        print(token_hash)
        return 0

    if generated:
        print("# Store this raw token in your password manager. It is shown once.")
        print(f"ADMIN_TOKEN={token}")
        print()

    print("# Store this value in Railway or your secret manager.")
    print(f"TEMPEST_ADMIN_TOKEN_HASH={token_hash}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
