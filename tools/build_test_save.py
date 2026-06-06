#!/usr/bin/env python3
"""Minimal test save: maps unlock + placeholder player; rosters come from test maps on select."""
from __future__ import annotations

import base64
import json
import os
from datetime import datetime, timezone
from pathlib import Path

ENC_KEY = "TBH_Idle_RPG_Save_v1"
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = PROJECT_ROOT / "tools" / "seed_saves"
GODOT_USER = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "TBH Idle RPG"

MAP_IDS = [
    "grassland",
    "forest",
    "cave",
    "death_trial",
    "test_01_stability_retreat",
    "test_02_extract_line",
    "test_03_boss_chase",
    "test_04_auto_value",
    "test_05_loot_full",
    "test_06_near_death_duo",
    "test_07_near_death_solo",
    "test_08_awakening",
    "test_09_long_chase_pressure",
]

SLOTS = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]


def encrypt(plain: str) -> str:
    key = ENC_KEY.encode("utf-8")
    data = plain.encode("utf-8")
    out = bytes(data[i] ^ key[i % len(key)] for i in range(len(data)))
    return base64.b64encode(out).decode("ascii")


def build_save() -> dict:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    return {
        "header": {"version": 1, "timestamp": now, "play_time_seconds": 0},
        "gold": 500000,
        "player": {
            "merc_id": "player_01",
            "merc_name": "测试主角",
            "merc_type": 0,
            "merc_class": "warrior",
            "level": 10,
            "exp": 0,
            "max_level": 60,
            "current_hp": 200,
            "is_alive": True,
            "is_near_death": False,
            "scar_stacks": 0,
            "is_retreated": False,
            "is_personal_break": False,
            "personal_stability": 100,
            "attack_range": 50.0,
            "attack_speed": 1.2,
            "equipment_slots": {s: None for s in SLOTS},
            "passive_skills": ["toughness"],
            "buffs": [],
            "active_skills": ["taunt"],
            "growth_per_level": {"hp": 10, "patk": 1.2, "pdef": 0.8},
            "template_id": "",
            "player_extra": {
                "base_exp_multiplier": 0.2,
                "squad_stability_influence": 0.1,
                "owned_elite_ids": [],
                "owned_normal_ids": [],
            },
        },
        "roster": {"elite": [], "normal": []},
        "inventory": [],
        "buildings": {
            "barracks": {"building_id": "barracks", "level": 5},
            "forge": {"building_id": "forge", "level": 5},
            "infirmary": {"building_id": "infirmary", "level": 5},
            "research_lab": {"building_id": "research_lab", "level": 3},
            "warehouse": {"building_id": "warehouse", "level": 5},
        },
        "team_stability": 100,
        "unlocked_maps": MAP_IDS,
        "defeated_map_bosses": ["grassland", "forest", "cave"],
        "squad_formation": {
            "active_half": "A",
            "A": {"active": [], "bench": []},
            "B": {"active": [], "bench": []},
        },
        "last_deploy_half": "A",
        "last_run_squad_snapshot": [],
        "selected_map_id": "test_06_near_death_duo",
        "auto_run_preferred": False,
        "rebirth_count": 0,
        "rebirth_bonus": 0.0,
        "cloud_reserved": {},
        "squad_stability": 100,
    }


def main() -> None:
    save = build_save()
    plain = json.dumps(save, ensure_ascii=False, indent="\t")
    enc = encrypt(plain)
    SEED_DIR.mkdir(parents=True, exist_ok=True)
    plain_path = SEED_DIR / "save_slot_1_test.plain.json"
    enc_path = SEED_DIR / "save_slot_1_test.enc.json"
    plain_path.write_text(plain, encoding="utf-8")
    enc_path.write_text(enc, encoding="utf-8")
    if GODOT_USER.parent.exists():
        GODOT_USER.mkdir(parents=True, exist_ok=True)
        (GODOT_USER / "save_slot_1.json").write_text(enc, encoding="utf-8")
        meta = {
            "last_slot": 1,
            "play_time": 0,
            "slots": {"1": {"timestamp": save["header"]["timestamp"], "version": 1, "play_time": 0}},
        }
        (GODOT_USER / "save_meta.json").write_text(json.dumps(meta, indent="\t"), encoding="utf-8")
        print("Installed Godot save_slot_1.json")
    print("Seed:", plain_path)


if __name__ == "__main__":
    main()
