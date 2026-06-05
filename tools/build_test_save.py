#!/usr/bin/env python3
"""Build encrypted test save for TBH Idle RPG slot 1."""
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
    "retreat_drill",
    "test_near_death_solo",
    "test_near_death_duo",
    "forest",
    "cave",
    "test_extract",
    "test_auto_value",
    "test_loot_full",
    "test_boss_chase",
    "test_awakening",
    "death_trial",
]

SLOTS = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]


def encrypt(plain: str) -> str:
    key = ENC_KEY.encode("utf-8")
    data = plain.encode("utf-8")
    out = bytes(data[i] ^ key[i % len(key)] for i in range(len(data)))
    return base64.b64encode(out).decode("ascii")


def empty_equipment_slots() -> dict:
    return {s: None for s in SLOTS}


def equipment(slot: str, idx: int, quality: int = 3) -> dict:
    names = ["破损", "普通", "精良", "稀有", "史诗", "传说"]
    qn = names[quality] if 0 <= quality < len(names) else "精良"
    stats = {"patk": 8 + quality * 4, "hp": 20 + quality * 10}
    if slot in ("armor", "helmet"):
        stats = {"pdef": 6 + quality * 3, "hp": 30 + quality * 8}
    return {
        "item_id": "eq_test_%s_%02d" % (slot, idx),
        "item_name": "%s·测试%s" % (qn, slot),
        "slot": slot,
        "quality": quality,
        "quality_name": qn,
        "prefix_name": "",
        "set_id": "",
        "grid_w": 1,
        "grid_h": 1,
        "shield_cd_runs_left": 0,
        "stats": stats,
    }


def merc(
    merc_id: str,
    name: str,
    merc_type: int,
    merc_class: str,
    template_id: str,
    level: int = 15,
    equip_count: int = 2,
    eq_offset: int = 0,
) -> dict:
    slots = empty_equipment_slots()
    for i in range(min(equip_count, len(SLOTS))):
        slots[SLOTS[i]] = equipment(SLOTS[i], eq_offset + i, 2 + (i % 3))
    return {
        "merc_id": merc_id,
        "merc_name": name,
        "merc_type": merc_type,
        "merc_class": merc_class,
        "level": level,
        "exp": 0,
        "max_level": 60,
        "current_hp": 400 + level * 10,
        "is_alive": True,
        "is_near_death": False,
        "scar_stacks": 0,
        "is_retreated": False,
        "is_personal_break": False,
        "personal_stability": 100,
        "attack_range": 50.0,
        "attack_speed": 1.2,
        "equipment_slots": slots,
        "passive_skills": [],
        "buffs": [],
        "active_skills": [],
        "growth_per_level": {"hp": 10, "patk": 1.2},
        "template_id": template_id,
        "player_extra": {},
    }


def build_save() -> dict:
    player = merc(
        "player_01",
        "测试指挥官",
        0,
        "warrior",
        "",
        level=20,
        equip_count=4,
        eq_offset=0,
    )
    player["passive_skills"] = ["toughness", "iron_wall"]
    player["active_skills"] = ["taunt"]
    player["growth_per_level"] = {"hp": 10, "patk": 1.2, "pdef": 0.8}
    player["player_extra"] = {
        "base_exp_multiplier": 0.2,
        "squad_stability_influence": 0.1,
        "owned_elite_ids": ["elite_01", "elite_02", "elite_03"],
        "owned_normal_ids": [
            "normal_01",
            "normal_02",
            "normal_03",
            "normal_04",
            "normal_05",
        ],
    }

    elites = [
        merc("elite_01", "钢铁守卫", 1, "warrior", "warrior_elite", 18, 2, 10),
        merc("elite_02", "奥术师", 1, "mage", "mage_elite", 18, 2, 20),
        merc("elite_03", "影刃游侠", 1, "ranger", "ranger_elite", 18, 2, 30),
    ]
    normals = [
        merc("normal_01", "新兵·甲", 2, "warrior", "warrior_normal", 15, 1, 40),
        merc("normal_02", "学徒·乙", 2, "mage", "mage_normal", 15, 1, 50),
        merc("normal_03", "斥候·丙", 2, "ranger", "ranger_normal", 15, 1, 60),
        merc("normal_04", "新兵·丁", 2, "warrior", "warrior_normal", 12, 1, 70),
        merc("normal_05", "学徒·戊", 2, "mage", "mage_normal", 12, 1, 80),
    ]

    inventory = []
    for i in range(24):
        slot = SLOTS[i % len(SLOTS)]
        inventory.append(equipment(slot, 100 + i, i % 6))

    buildings = {
        "barracks": {"building_id": "barracks", "level": 5},
        "forge": {"building_id": "forge", "level": 5},
        "infirmary": {"building_id": "infirmary", "level": 5},
        "research_lab": {"building_id": "research_lab", "level": 3},
        "warehouse": {"building_id": "warehouse", "level": 5},
    }

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    return {
        "header": {
            "version": 1,
            "timestamp": now,
            "play_time_seconds": 0,
        },
        "gold": 500000,
        "player": player,
        "roster": {"elite": elites, "normal": normals},
        "inventory": inventory,
        "buildings": buildings,
        "team_stability": 100,
        "unlocked_maps": MAP_IDS,
        "defeated_map_bosses": ["grassland", "forest", "cave"],
        "squad_formation": {
            "active_half": "A",
            "A": {
                "active": ["player_01", "elite_01", "elite_02", "elite_03"],
                "bench": ["normal_01", "normal_02"],
            },
            "B": {
                "active": ["normal_03", "normal_04"],
                "bench": ["normal_05"],
            },
        },
        "last_deploy_half": "A",
        "last_run_squad_snapshot": ["player_01", "elite_01", "elite_02", "elite_03"],
        "selected_map_id": "retreat_drill",
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
        slot_path = GODOT_USER / "save_slot_1.json"
        slot_path.write_text(enc, encoding="utf-8")
        meta = {
            "last_slot": 1,
            "play_time": 0,
            "slots": {
                "1": {
                    "timestamp": save["header"]["timestamp"],
                    "version": 1,
                    "play_time": 0,
                }
            },
        }
        (GODOT_USER / "save_meta.json").write_text(
            json.dumps(meta, indent="\t"), encoding="utf-8"
        )
        print("Installed:", slot_path)
    else:
        print("Godot user dir not found; copy manually from", SEED_DIR)

    print("Seed plain:", plain_path)
    print("Seed enc:  ", enc_path)
    print(
        "gold=%s elites=%s normals=%s inventory=%s maps=%s"
        % (
            save["gold"],
            len(save["roster"]["elite"]),
            len(save["roster"]["normal"]),
            len(save["inventory"]),
            len(save["unlocked_maps"]),
        )
    )


if __name__ == "__main__":
    main()
