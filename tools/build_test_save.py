#!/usr/bin/env python3
"""测试存档：全图解锁 + 阵亡/战场遗留 fixture（写入槽位 1）。"""
from __future__ import annotations

import base64
import json
import os
import time
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


def merc_dict(
    *,
    merc_id: str,
    merc_name: str,
    merc_type: int,
    merc_class: str,
    template_id: str,
    level: int,
    is_alive: bool = True,
    is_mia: bool = False,
    is_dead_permanently: bool = False,
    current_hp: int | None = None,
    attack_range: float = 50.0,
    attack_speed: float = 1.2,
    growth: dict | None = None,
    passives: list | None = None,
    actives: list | None = None,
) -> dict:
    hp = current_hp
    if hp is None:
        if is_mia:
            hp = 1
        elif not is_alive:
            hp = 0
        else:
            hp = 100
    return {
        "merc_id": merc_id,
        "merc_name": merc_name,
        "merc_type": merc_type,
        "merc_class": merc_class,
        "level": level,
        "exp": 0,
        "max_level": 60 if merc_type == 1 else 30,
        "current_hp": hp,
        "is_alive": is_alive,
        "is_mia": is_mia,
        "is_near_death": False,
        "scar_stacks": 0,
        "is_retreated": False,
        "is_personal_break": False,
        "personal_stability": 100,
        "attack_range": attack_range,
        "attack_speed": attack_speed,
        "equipment_slots": {s: None for s in SLOTS},
        "passive_skills": passives or [],
        "buffs": [],
        "active_skills": actives or [],
        "growth_per_level": growth or {"hp": 8, "patk": 1.0},
        "template_id": template_id,
        "player_extra": {},
        "is_dead_permanently": is_dead_permanently,
    }


def build_save() -> dict:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    elites = [
        merc_dict(
            merc_id="elite_01",
            merc_name="钢铁守卫",
            merc_type=1,
            merc_class="warrior",
            template_id="warrior_elite",
            level=18,
            growth={"hp": 12, "patk": 1.5, "pdef": 1.0, "spd": 0.3},
            passives=["toughness", "iron_wall"],
            actives=["taunt"],
        ),
        merc_dict(
            merc_id="fixture_mia_elite",
            merc_name="fixture·奥术遗留",
            merc_type=1,
            merc_class="mage",
            template_id="mage_elite",
            level=12,
            is_mia=True,
            attack_range=120.0,
            attack_speed=1.5,
            growth={"hp": 7, "matk": 2.5, "mdef": 0.8, "spd": 0.4},
            passives=["arcane_affinity", "mana_shield"],
            actives=["fireball"],
        ),
        merc_dict(
            merc_id="fixture_dead_elite",
            merc_name="fixture·游侠阵亡",
            merc_type=1,
            merc_class="ranger",
            template_id="ranger_elite",
            level=15,
            is_alive=False,
            is_dead_permanently=True,
            attack_range=100.0,
            attack_speed=1.0,
            growth={"hp": 9, "patk": 1.8, "spd": 0.6},
            passives=["shadow_step", "keen_eye"],
            actives=["snipe"],
        ),
    ]
    normals = [
        merc_dict(
            merc_id="normal_01",
            merc_name="新兵",
            merc_type=2,
            merc_class="warrior",
            template_id="warrior_normal",
            level=15,
        ),
        merc_dict(
            merc_id="fixture_mia_normal",
            merc_name="fixture·新兵遗留",
            merc_type=2,
            merc_class="warrior",
            template_id="warrior_normal",
            level=10,
            is_mia=True,
        ),
        merc_dict(
            merc_id="fixture_dead_normal",
            merc_name="fixture·学徒阵亡",
            merc_type=2,
            merc_class="mage",
            template_id="mage_normal",
            level=8,
            is_alive=False,
            is_dead_permanently=True,
            attack_range=110.0,
            attack_speed=1.6,
            growth={"hp": 5, "matk": 1.5, "mdef": 0.5},
            actives=["fireball"],
        ),
    ]
    owned_elite = [e["merc_id"] for e in elites]
    owned_normal = [n["merc_id"] for n in normals]
    return {
        "header": {"version": 1, "timestamp": now, "play_time_seconds": 0},
        "gold": 500000,
        "player": {
            "merc_id": "player_01",
            "merc_name": "测试指挥官",
            "merc_type": 0,
            "merc_class": "warrior",
            "level": 20,
            "exp": 0,
            "max_level": 60,
            "current_hp": 200,
            "is_alive": True,
            "is_mia": False,
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
                "owned_elite_ids": owned_elite,
                "owned_normal_ids": owned_normal,
            },
        },
        "roster": {"elite": elites, "normal": normals},
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
            "A": {
                "active": ["player_01", "elite_01", "normal_01"],
                "bench": [],
            },
            "B": {"active": [], "bench": []},
        },
        "last_deploy_half": "A",
        "last_run_squad_snapshot": ["player_01", "elite_01", "normal_01"],
        "selected_map_id": "grassland",
        "auto_run_preferred": False,
        "rebirth_count": 0,
        "rebirth_bonus": 0.0,
        "account_meta": {
            "seed_casualty_fixtures": True,
            "frozen_exp_pools": [
                {
                    "run_id": "fixture_mia_pool_1",
                    "map_id": "grassland",
                    "total": 1200,
                    "mia_count": 2,
                    "field_count": 4,
                    "mia_ratio": 0.5,
                    "timestamp": int(time.time()),
                    "member_ids": ["fixture_mia_elite", "fixture_mia_normal"],
                }
            ],
            "rescue_rank": 0,
            "rescue_reputation": 0,
        },
        "rescue_squad": {"active": [], "bench": []},
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
    print("Seed plain:", plain_path)
    print(
        "Fixtures: MIA=%d dead=%d frozen=%d"
        % (
            sum(1 for e in save["roster"]["elite"] + save["roster"]["normal"] if e.get("is_mia")),
            sum(
                1
                for e in save["roster"]["elite"] + save["roster"]["normal"]
                if not e.get("is_alive")
            ),
            save["account_meta"]["frozen_exp_pools"][0]["total"],
        )
    )
    if GODOT_USER.parent.exists():
        GODOT_USER.mkdir(parents=True, exist_ok=True)
        (GODOT_USER / "save_slot_1.json").write_text(enc, encoding="utf-8")
        meta = {
            "last_slot": 1,
            "play_time": 0,
            "slots": {"1": {"timestamp": save["header"]["timestamp"], "version": 1, "play_time": 0}},
        }
        (GODOT_USER / "save_meta.json").write_text(json.dumps(meta, indent="\t"), encoding="utf-8")
        print("Installed:", GODOT_USER / "save_slot_1.json")


if __name__ == "__main__":
    main()
