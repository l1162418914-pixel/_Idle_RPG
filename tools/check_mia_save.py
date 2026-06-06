#!/usr/bin/env python3
"""Decrypt save_slot_1.json and verify T-MIA-0 fields."""
from __future__ import annotations

import base64
import json
import os
from datetime import datetime
from pathlib import Path

ENC_KEY = "TBH_Idle_RPG_Save_v1"
SAVE_PATH = (
    Path(os.environ.get("APPDATA", ""))
    / "Godot"
    / "app_userdata"
    / "TBH Idle RPG"
    / "save_slot_1.json"
)


def decrypt(raw: str) -> dict:
    key = ENC_KEY.encode("utf-8")
    try:
        data = base64.b64decode(raw.strip())
        plain = bytes(data[i] ^ key[i % len(key)] for i in range(len(data))).decode("utf-8")
        return json.loads(plain)
    except Exception:
        return json.loads(raw)


def main() -> int:
    if not SAVE_PATH.is_file():
        print(f"FAIL: save not found: {SAVE_PATH}")
        return 1

    obj = decrypt(SAVE_PATH.read_text(encoding="utf-8"))
    mtime = datetime.fromtimestamp(SAVE_PATH.stat().st_mtime)
    print(f"FILE: {SAVE_PATH}")
    print(f"MTIME: {mtime.isoformat(sep=' ', timespec='seconds')}")
    print(f"HAS account_meta: {'account_meta' in obj}")
    print(f"HAS rescue_squad: {'rescue_squad' in obj}")

    am = obj.get("account_meta")
    rs = obj.get("rescue_squad")
    if am is not None:
        print("account_meta:", json.dumps(am, ensure_ascii=False, indent=2))
    if rs is not None:
        print("rescue_squad:", json.dumps(rs, ensure_ascii=False, indent=2))

    checks = [
        ("account_meta present", am is not None),
        ("frozen_exp_pools is list", isinstance(am, dict) and isinstance(am.get("frozen_exp_pools"), list)),
        ("rescue_rank == 0", isinstance(am, dict) and am.get("rescue_rank") == 0),
        ("rescue_reputation == 0", isinstance(am, dict) and am.get("rescue_reputation") == 0),
        ("rescue_squad present", rs is not None),
        ("rescue_squad.active is list", isinstance(rs, dict) and isinstance(rs.get("active"), list)),
        ("rescue_squad.bench is list", isinstance(rs, dict) and isinstance(rs.get("bench"), list)),
    ]
    print("STRUCTURE_OK:", all(ok for _, ok in checks))
    for name, ok in checks:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}")

    return 0 if all(ok for _, ok in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
