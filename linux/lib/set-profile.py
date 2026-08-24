#!/usr/bin/env python3
"""Set Balatro settings.jkr ["profile"]=N (raw deflate Lua table)."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys
import zlib


def decompress(data: bytes) -> str:
    # Raw deflate (same as .NET DeflateStream)
    try:
        return zlib.decompress(data, -zlib.MAX_WBITS).decode("utf-8")
    except zlib.error:
        # Fallback zlib wrapper
        return zlib.decompress(data).decode("utf-8")


def compress(text: str) -> bytes:
    co = zlib.compressobj(level=9, wbits=-zlib.MAX_WBITS)
    return co.compress(text.encode("utf-8")) + co.flush()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--settings", required=True, type=pathlib.Path)
    ap.add_argument("--profile", required=True, type=int)
    args = ap.parse_args()

    if args.profile < 1 or args.profile > 3:
        print(f"Invalid profile {args.profile}", file=sys.stderr)
        return 1
    if not args.settings.is_file():
        print(f"Missing settings.jkr: {args.settings}", file=sys.stderr)
        return 1

    raw = args.settings.read_bytes()
    text = decompress(raw)
    m = re.search(r'\["profile"\]=(\d+)', text)
    old = int(m.group(1)) if m else None
    if old == args.profile:
        print(f"Profile already {args.profile}")
        return 0

    assignment = f'["profile"]={args.profile}'
    if old is not None:
        new_text, n = re.subn(r'\["profile"\]=\d+', assignment, text, count=1)
        if n != 1:
            print("Failed to replace profile", file=sys.stderr)
            return 1
    else:
        new_text, n = re.subn(r"\}\s*$", "," + assignment + "}", text, count=1)
        if n != 1:
            print("Failed to insert profile", file=sys.stderr)
            return 1

    bak = args.settings.with_suffix(args.settings.suffix + ".bak-profile")
    bak.write_bytes(raw)
    out = compress(new_text)
    check = decompress(out)
    if f'["profile"]={args.profile}' not in check:
        print("Verification failed", file=sys.stderr)
        return 1
    args.settings.write_bytes(out)
    print(f"Profile slot: {old if old is not None else '?'} -> {args.profile}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
