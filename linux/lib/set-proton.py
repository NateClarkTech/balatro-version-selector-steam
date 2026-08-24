#!/usr/bin/env python3
"""
Set Steam CompatToolMapping for an appid (Proton / Steam Play tool name).

Edits ~/.steam/steam/config/config.vdf (or STEAM_ROOT/config/config.vdf).
Steam should preferably be closed; it may overwrite on exit if open.

Tool names examples:
  proton_experimental, proton_hotfix, proton_10, proton_9,
  or GE folder names under compatibilitytools.d (e.g. GE-Proton9-20)
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys


def find_config(steam_root: pathlib.Path) -> pathlib.Path:
    p = steam_root / "config" / "config.vdf"
    if not p.is_file():
        raise SystemExit(f"Steam config.vdf not found: {p}")
    return p


def set_mapping(content: str, app_id: str, tool_name: str | None) -> str:
    """
    tool_name=None -> remove mapping for app (use Steam default).
    """
    # Locate CompatToolMapping block at top level-ish
    m = re.search(r'"CompatToolMapping"\s*\{', content)
    if not m:
        raise SystemExit('Could not find "CompatToolMapping" in config.vdf')

    start = m.end()  # position after opening {
    # Find matching closing brace for CompatToolMapping
    depth = 1
    i = start
    while i < len(content) and depth > 0:
        if content[i] == "{":
            depth += 1
        elif content[i] == "}":
            depth -= 1
        i += 1
    end = i - 1  # index of closing }
    block = content[start:end]

    # Remove existing app entry if present
    # Matches: "2379780"\n\t\t\t\t{\n ... \n\t\t\t\t}
    entry_re = re.compile(
        rf'"{re.escape(app_id)}"\s*\{{(?:[^{{}}]|{{[^{{}}]*}})*\}}',
        re.MULTILINE,
    )
    block2, n = entry_re.subn("", block, count=1)

    if tool_name is None or tool_name == "" or tool_name.lower() in ("default", "none", "native"):
        return content[:start] + block2 + content[end:]

    entry = (
        f'\n\t\t\t\t\t"{app_id}"\n'
        f"\t\t\t\t\t{{\n"
        f'\t\t\t\t\t\t"name"\t\t"{tool_name}"\n'
        f'\t\t\t\t\t\t"config"\t\t""\n'
        f'\t\t\t\t\t\t"priority"\t\t"250"\n'
        f"\t\t\t\t\t}}"
    )
    block3 = block2.rstrip() + entry + "\n\t\t\t\t"
    return content[:start] + block3 + content[end:]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--steam-root", required=True, type=pathlib.Path)
    ap.add_argument("--appid", required=True)
    ap.add_argument("--tool", default="", help="Proton tool name, or empty/default to clear")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    cfg = find_config(args.steam_root)
    text = cfg.read_text(encoding="utf-8", errors="replace")
    tool = args.tool.strip() or None
    new_text = set_mapping(text, args.appid, tool)
    if new_text == text:
        print(f"CompatToolMapping unchanged for {args.appid} -> {tool or 'default'}")
        return 0

    bak = cfg.with_suffix(".vdf.bak-balatro-mode")
    if not args.dry_run:
        bak.write_text(text, encoding="utf-8")
        cfg.write_text(new_text, encoding="utf-8")
        print(f"Wrote {cfg} (backup {bak})")
    else:
        print("Dry-run OK (no write)")

    print(f"App {args.appid} compat tool -> {tool or 'Steam default'}")
    print("Note: restart Steam if it was open so the change sticks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
