#!/usr/bin/env python3
"""Generate data/test_map_rosters.json and replace test maps in map_templates.json."""
from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
SLOTS = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]

TEST_MAP_IDS = [
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

OLD_TEST_IDS = {
    "retreat_drill",
    "test_extract",
    "test_auto_value",
    "test_loot_full",
    "test_boss_chase",
    "test_near_death_solo",
    "test_near_death_duo",
    "test_awakening",
}


def is_test_map_entry(m: dict) -> bool:
    mid = str(m.get("map_id", ""))
    if mid in OLD_TEST_IDS or mid in TEST_MAP_IDS:
        return True
    if mid.startswith("test_") or mid == "retreat_drill":
        return True
    if m.get("test_scenario") or m.get("test_priority") is not None:
        return True
    return False


def eq(slot: str, idx: int, quality: int = 2) -> dict:
    names = ["破损", "普通", "精良", "稀有", "史诗", "传说"]
    qn = names[quality]
    stats = {"patk": 10 + quality * 3, "hp": 28 + quality * 8}
    if slot in ("armor", "helmet"):
        stats = {"pdef": 8 + quality * 3, "hp": 36 + quality * 8}
    elif slot == "boots":
        stats = {"spd": 1 + quality, "hp": 24 + quality * 6}
    elif slot in ("ring", "amulet"):
        stats = {"patk": 6 + quality * 2, "hp": 20 + quality * 5}
    return {
        "item_id": "eq_%s_%03d" % (slot, idx),
        "item_name": "%s·%s" % (qn, slot),
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
    level: int = 16,
    equip_slots: list[str] | None = None,
    eq_base: int = 0,
    skills: list[str] | None = None,
    eq_quality: int = 2,
    hp_bonus: int = 0,
) -> dict:
    slots = {s: None for s in SLOTS}
    equip_slots = equip_slots or ["weapon", "armor"]
    for i, slot in enumerate(equip_slots):
        slots[slot] = eq(slot, eq_base + i, eq_quality)
    return {
        "merc_id": merc_id,
        "merc_name": name,
        "merc_type": merc_type,
        "merc_class": merc_class,
        "level": level,
        "exp": 0,
        "max_level": 60,
        "current_hp": 380 + level * 12 + hp_bonus,
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
        "active_skills": skills or [],
        "growth_per_level": {"hp": 10, "patk": 1.2, "pdef": 0.8},
        "template_id": template_id,
        "player_extra": {},
    }


def player(level: int = 16, name: str = "测试主角") -> dict:
    p = merc("player_01", name, 0, "warrior", "", level, ["weapon", "armor", "helmet"], 0, ["taunt"])
    p["passive_skills"] = ["toughness"]
    p["player_extra"] = {
        "base_exp_multiplier": 0.2,
        "squad_stability_influence": 0.1,
        "owned_elite_ids": [],
        "owned_normal_ids": [],
    }
    return p


def formation(active: list[str], bench: list[str] | None = None) -> dict:
    return {
        "active_half": "A",
        "A": {"active": active, "bench": bench or []},
        "B": {"active": [], "bench": []},
    }


def pool(level_lo: int = 16, level_hi: int = 18) -> list:
    return [
        {"template": "slime_striker", "weight": 55, "level_range": [level_lo, level_hi]},
        {"template": "wolf_striker", "weight": 45, "level_range": [level_lo, level_hi]},
    ]


def fast_striker_pool(level_lo: int = 17, level_hi: int = 19) -> list:
    """高攻速模板（spd→attack_speed）；用于追击/密战测试。"""
    return [
        {"template": "wolf_striker", "weight": 50, "level_range": [level_lo, level_hi]},
        {"template": "slime_striker", "weight": 35, "level_range": [level_lo, level_hi]},
        {"template": "goblin", "weight": 15, "level_range": [level_lo, level_hi]},
    ]


def base_map(
    map_id: str,
    name: str,
    description: str,
    scenario: str,
    priority: int,
    duration: str,
    **overrides,
) -> dict:
    m = {
        "map_id": map_id,
        "name": name,
        "description": description,
        "test_scenario": scenario,
        "test_priority": priority,
        "test_target_duration": duration,
        "always_unlocked": True,
        "unlock_base_level": 1,
        "unlock_after_boss_on_map": "",
        "background": "grassland_bg",
        "spawn_interval": 3.0,
        "drop_chance": 0.06,
        "mob_drop_mult": 1.0,
        "mob_drop_bonus": 0.0,
        "mob_max_quality": 1,
        "retreat_hit_drop_chance": 0.05,
        "retreat_shield_mult": 1.2,
        "retreat_shield_mult_manual": 0.85,
        "emergency_near_death_hp_ratio": 0.1,
        "drop_chance_boss": 0.0,
        "disable_boss_chase": True,
        "stability_decay_mult": 1.0,
        "stability_loss_mult": 0.9,
        "enemy_stat_mult": 1.05,
        "enemy_pool": pool(),
        "boss": "slime_king",
        "boss_distance": 500.0,
        "retreat_destination": 0,
        "retreat_speed_mult": 0.95,
        "advance_speed_mult": 0.82,
        "boss_zone_ratio": 0.99,
        "resource_yield": 0.0,
        "danger_level": 0,
        "loot_quality_shift": 0,
        "loot_level_bonus": 0,
        "loot_min_quality": 0,
        "set_drop_chance": 0.0,
        "featured_set_id": "iron_guard",
        "retreat_spawn_interval_mult": 0.7,
        "retreat_spawn_pack": 2,
        "retreat_start_ambush": 1,
    }
    m.update(overrides)
    return m


def build_rosters() -> dict:
    t01_tank = merc("t01_tank", "①·铁卫", 1, "warrior", "warrior_elite", 16, ["weapon", "armor"], 10)
    t01_mage = merc("t01_mage", "①·术士", 1, "mage", "mage_elite", 16, ["weapon", "armor"], 20)
    t01_ranger = merc("t01_ranger", "①·游侠", 1, "ranger", "ranger_elite", 16, ["weapon", "armor"], 30)
    t02_scout = merc("t02_scout", "②·斥候", 2, "ranger", "ranger_normal", 16, ["weapon"], 40)
    t03_guard = merc("t03_guard", "③·盾卫", 1, "warrior", "warrior_elite", 17, ["weapon", "armor", "helmet"], 50)
    t04_loot = merc("t04_pack", "④·拾荒", 2, "warrior", "warrior_normal", 16, ["weapon"], 60)
    t06_tank = merc("t06_tank", "⑥·前排铁卫", 1, "warrior", "warrior_elite", 17, ["weapon", "armor", "helmet"], 70, ["taunt"])
    t08_mage = merc("t08_mage", "⑧·奥术", 1, "mage", "mage_elite", 17, ["weapon", "armor"], 80)
    # ⑨ 专用：偏弱编队，Boss 线接战易濒死，便于测「濒死减速→追击灭团」
    t09_tank = merc(
        "t09_tank",
        "⑨·前排",
        1,
        "warrior",
        "warrior_elite",
        15,
        ["weapon", "armor"],
        90,
        ["taunt"],
        eq_quality=1,
    )
    t09_mage = merc(
        "t09_mage",
        "⑨·术士",
        1,
        "mage",
        "mage_elite",
        15,
        ["weapon"],
        100,
        eq_quality=1,
    )
    t09_ranger = merc(
        "t09_ranger",
        "⑨·游侠",
        1,
        "ranger",
        "ranger_elite",
        15,
        ["weapon"],
        110,
        eq_quality=1,
    )

    return {
        "test_01_stability_retreat": {
            "display_name": "① 稳定返程：①·铁卫+①·术士+①·游侠（主角留营，约5波后返程）",
            "formation": formation(["t01_tank", "t01_mage", "t01_ranger"]),
            "elite": [t01_tank, t01_mage, t01_ranger],
            "normal": [],
        },
        "test_02_extract_line": {
            "display_name": "② 撤离物线：②·斥候+①·铁卫（主角留营）",
            "formation": formation(["t02_scout", "t01_tank"]),
            "elite": [t01_tank],
            "normal": [t02_scout],
        },
        "test_03_boss_chase": {
            "display_name": "③ Boss追击：③·盾卫+①·术士+①·游侠（主角留营）",
            "formation": formation(["t03_guard", "t01_mage", "t01_ranger"]),
            "elite": [t03_guard, t01_mage, t01_ranger],
            "normal": [],
        },
        "test_04_auto_value": {
            "display_name": "④ 价值撤离：④·拾荒+①·铁卫（主角留营，长图低烈度捡装）",
            "formation": formation(["t04_loot", "t01_tank"]),
            "elite": [t01_tank],
            "normal": [t04_loot],
        },
        "test_05_loot_full": {
            "display_name": "④b 网格满撤：④·拾荒+①·铁卫（主角留营，长图低烈度）",
            "formation": formation(["t04_loot", "t01_tank"]),
            "elite": [t01_tank],
            "normal": [t04_loot],
        },
        "test_06_near_death_duo": {
            "display_name": "⑥ 双人濒死/T-02a：⑥·前排铁卫+①·术士（主角留营）",
            "formation": formation(["t06_tank", "t01_mage"]),
            "elite": [t06_tank, t01_mage],
            "normal": [],
        },
        "test_07_near_death_solo": {
            "display_name": "⑦ 单人濒死：⑥·前排铁卫（主角留营）",
            "formation": formation(["t06_tank"]),
            "elite": [t06_tank],
            "normal": [],
        },
        "test_08_awakening": {
            "display_name": "⑧ 绝境觉醒：⑧·奥术+①·铁卫（主角留营）",
            "formation": formation(["t08_mage", "t01_tank"]),
            "elite": [t08_mage, t01_tank],
            "normal": [],
        },
        "test_09_long_chase_pressure": {
            "display_name": "⑨ 濒死追击灭团：⑨·前排+⑨·术士+⑨·游侠（主角留营，L15普通装）",
            "formation": formation(["t09_tank", "t09_mage", "t09_ranger"]),
            "elite": [t09_tank, t09_mage, t09_ranger],
            "normal": [],
        },
    }


def build_maps() -> list:
    return [
        base_map(
            "test_01_stability_retreat",
            "测试①·稳定度返程",
            "【自带编队】约3~4波后稳定≤30强制返程；双池护盾；无Boss追击。",
            "stability_retreat",
            1,
            "3~4 分钟",
            stability_decay_mult=1.15,
            stability_loss_mult=0.95,
            boss_distance=520.0,
            drop_chance=0.08,
            resource_yield=0.5,
        ),
        base_map(
            "test_02_extract_line",
            "测试②·撤离物线",
            "【自带编队】高掉率撤离物；拾取引守卫；首段返程经55m撤离点。",
            "extract_line",
            2,
            "3~5 分钟",
            spawn_interval=2.5,
            drop_chance=0.14,
            enemy_stat_mult=1.0,
            extract_distance=55.0,
            extract_drop_chance=0.35,
            extract_guard="goblin_chief",
            extract_guard_stat_mult=0.95,
            auto_carry_value_threshold=200,
            boss_distance=420.0,
            advance_speed_mult=0.9,
            resource_yield=0.7,
        ),
        base_map(
            "test_03_boss_chase",
            "测试③·Boss追击",
            "【自带编队】约90m自动返程；追击条；反击/蓄力/深度≠通关，杀追击首领=通关。",
            "boss_chase",
            3,
            "4~5 分钟",
            spawn_interval=3.2,
            drop_chance=0.05,
            enemy_stat_mult=1.0,
            boss_distance=90.0,
            advance_speed_mult=2.2,
            auto_retreat_on_boss_spawn=True,
            disable_boss_chase=False,
            boss="goblin_chief",
            chase_boss_id="grassland_stalker",
            chase_drop_table="chase_grassland",
            chase_boss_stat_mult=0.6,
            chase_pressure_min=0.06,
            boss_chase_speed=50.0,
            boss_chase_start_offset=32.0,
            boss_chase_pushback=150.0,
            chase_spawn_interval_mult=0.55,
            chase_spawn_pack=2,
            resource_yield=0.0,
        ),
        base_map(
            "test_04_auto_value",
            "测试④·携带价值撤离",
            "【自带编队】长图、低烈度、高掉率；拾荒凑满价值≥140自动返程。",
            "auto_value",
            4,
            "4~6 分钟",
            spawn_interval=3.8,
            drop_chance=0.42,
            mob_drop_mult=1.45,
            mob_drop_bonus=0.12,
            enemy_stat_mult=0.68,
            enemy_pool=pool(14, 16),
            boss_distance=780.0,
            advance_speed_mult=0.72,
            stability_decay_mult=0.85,
            stability_loss_mult=0.75,
            auto_carry_value_threshold=140,
            exposed_grid_w=4,
            exposed_grid_h=3,
            resource_yield=0.85,
        ),
        base_map(
            "test_05_loot_full",
            "测试④b·网格满撤",
            "【自带编队】长图、低烈度、高掉率；填满网格触发自动规则返程。",
            "loot_full",
            4,
            "4~6 分钟",
            spawn_interval=3.6,
            drop_chance=0.4,
            mob_drop_mult=1.5,
            mob_drop_bonus=0.1,
            enemy_stat_mult=0.65,
            enemy_pool=pool(14, 16),
            boss_distance=760.0,
            advance_speed_mult=0.72,
            stability_decay_mult=0.85,
            stability_loss_mult=0.75,
            exposed_grid_w=3,
            exposed_grid_h=2,
            auto_carry_value_threshold=9999,
            resource_yield=0.8,
        ),
        base_map(
            "test_06_near_death_duo",
            "测试⑥·双人濒死",
            "【自带编队·T-02a】前排主角+铁卫；返程多波，便于濒死与后排站位验收。",
            "duo_near_death",
            6,
            "3~5 分钟",
            stability_decay_mult=1.0,
            stability_loss_mult=0.9,
            enemy_stat_mult=1.05,
            boss_distance=540.0,
            spawn_interval=3.0,
            resource_yield=0.0,
        ),
        base_map(
            "test_07_near_death_solo",
            "测试⑦·单人濒死",
            "【自带编队】仅主角；稳定骤降返程；HP0=濒死可紧急撤离。",
            "solo_near_death",
            5,
            "3~4 分钟",
            stability_decay_mult=1.2,
            stability_loss_mult=1.0,
            enemy_stat_mult=1.05,
            boss_distance=480.0,
            spawn_interval=2.8,
            resource_yield=0.0,
        ),
        base_map(
            "test_08_awakening",
            "测试⑧·绝境觉醒",
            "【自带编队】约50%濒死触发觉醒；无Boss追击。",
            "awakening",
            7,
            "4~5 分钟",
            awakening_chance=0.5,
            enemy_stat_mult=1.35,
            stability_decay_mult=1.1,
            stability_loss_mult=0.95,
            boss_distance=500.0,
            spawn_interval=2.6,
            resource_yield=0.0,
        ),
        base_map(
            "test_09_long_chase_pressure",
            "测试⑨·濒死追击灭团",
            "【偏弱编队·仅首领】推至Boss线接战→濒死紧急撤离→追击开启；濒死移速×0.5，追猎者追上灭团。",
            "long_chase_pressure",
            9,
            "2~4 分钟",
            boss_distance=260.0,
            spawn_interval=99.0,
            drop_chance=0.0,
            disable_mob_spawns=True,
            enemy_pool=[],
            enemy_stat_mult=1.0,
            boss_level_bonus=10,
            line_boss_stat_mult=3.2,
            advance_speed_mult=2.5,
            retreat_speed_mult=0.95,
            disable_boss_chase=False,
            auto_retreat_on_boss_spawn=False,
            chase_catch_executes_downed=True,
            awakening_chance=0.0,
            boss="goblin_chief",
            chase_boss_id="grassland_stalker",
            chase_drop_table="chase_grassland",
            chase_boss_stat_mult=2.85,
            chase_boss_move_speed=108.0,
            chase_pressure_min=0.03,
            boss_chase_speed=96.0,
            boss_chase_combat_mult=1.55,
            boss_chase_start_offset=88.0,
            boss_chase_pushback=120.0,
            chase_speed_pressure_mult=0.68,
            retreat_start_ambush=0,
            chase_start_ambush_extra=0,
            chase_spawn_pack=0,
            retreat_spawn_pack=0,
            stability_decay_mult=0.6,
            stability_loss_mult=0.75,
            resource_yield=0.0,
        ),
    ]


def patch_map_templates(test_maps: list) -> None:
    path = DATA / "map_templates.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    kept = [m for m in data["maps"] if not is_test_map_entry(m)]
    insert_at = 0
    for i, m in enumerate(kept):
        if m.get("map_id") == "grassland":
            insert_at = i + 1
            break
    new_maps = kept[:insert_at] + test_maps + kept[insert_at:]
    data["maps"] = new_maps
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Production maps kept:", [m.get("map_id") for m in kept])
    print("Total maps after patch:", len(new_maps))


def main() -> None:
    rosters = build_rosters()
    roster_path = DATA / "test_map_rosters.json"
    roster_path.write_text(
        json.dumps({"version": 1, "rosters": rosters}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    test_maps = build_maps()
    patch_map_templates(test_maps)
    print("Wrote", roster_path)
    print("Patched map_templates.json with", len(test_maps), "test maps")
    print("Map IDs:", ", ".join(TEST_MAP_IDS))


if __name__ == "__main__":
    main()
