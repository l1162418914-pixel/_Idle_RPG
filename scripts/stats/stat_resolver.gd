class_name StatResolver
extends RefCounted
## 最终属性 = base（Mercenary 模板+成长）+ 装备 + 被动 + Buff
## Mercenary 字段仅存 base；本类为唯一 final 计算入口

const _CombatStats = preload("res://scripts/stats/combat_stats.gd")
const _EquipmentSystem = preload("res://scripts/equipment/equipment_system.gd")
const _SkillSystem = preload("res://scripts/skill/skill_system.gd")


static func compute(merc) -> CombatStats:
	merc.refresh_base_stats()
	var stats: CombatStats = _CombatStats.new()
	stats.max_hp = get_max_hp(merc)
	stats.patk = get_patk(merc)
	stats.matk = get_matk(merc)
	stats.pdef = get_pdef(merc)
	stats.mdef = get_mdef(merc)
	stats.spd = get_spd(merc)
	stats.crit_chance = get_crit_chance(merc)
	stats.dodge = get_dodge(merc)
	stats.block_chance = get_block_chance(merc)
	stats.attack_range = get_attack_range(merc)
	stats.attack_speed = get_attack_speed(merc)
	return stats


static func get_attack_range(merc) -> float:
	return _base_float(merc, "attack_range") + float(_EquipmentSystem.calc_equipment_bonus(merc, "attack_range"))


static func get_attack_speed(merc) -> float:
	var base: float = _base_float(merc, "attack_speed")
	var bonus: float = float(_EquipmentSystem.calc_equipment_bonus(merc, "attack_speed"))
	return maxf(0.1, base + bonus)


static func get_max_hp(merc) -> int:
	var raw: int = (_base_int(merc, "hp")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "hp")
		+ int(_SkillSystem.get_passive_bonus(merc, "hp"))
		+ int(merc.buff_system.get_bonus("hp")))
	return maxi(1, int(float(raw) * merc.get_scar_hp_mult()))


static func get_patk(merc) -> int:
	var raw: int = (_base_int(merc, "patk")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "patk")
		+ int(_SkillSystem.get_passive_bonus(merc, "patk"))
		+ int(merc.buff_system.get_bonus("patk")))
	return maxi(1, int(float(raw) * merc.get_scar_atk_mult()))


static func get_matk(merc) -> int:
	var raw: int = (_base_int(merc, "matk")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "matk")
		+ int(_SkillSystem.get_passive_bonus(merc, "matk"))
		+ int(merc.buff_system.get_bonus("matk")))
	return maxi(1, int(float(raw) * merc.get_scar_atk_mult()))


static func get_pdef(merc) -> int:
	return (_base_int(merc, "pdef")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "pdef")
		+ int(_SkillSystem.get_passive_bonus(merc, "pdef"))
		+ int(merc.buff_system.get_bonus("pdef")))


static func get_mdef(merc) -> int:
	return (_base_int(merc, "mdef")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "mdef")
		+ int(_SkillSystem.get_passive_bonus(merc, "mdef"))
		+ int(merc.buff_system.get_bonus("mdef")))


static func get_spd(merc) -> int:
	return (_base_int(merc, "spd")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "spd")
		+ int(_SkillSystem.get_passive_bonus(merc, "spd"))
		+ int(merc.buff_system.get_bonus("spd")))


static func get_crit_chance(merc) -> float:
	return (_base_float(merc, "crit_chance")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "crit_chance")
		+ _SkillSystem.get_passive_bonus(merc, "crit_chance")
		+ merc.buff_system.get_bonus("crit_chance"))


static func get_dodge(merc) -> float:
	return (_base_float(merc, "dodge")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "dodge")
		+ _SkillSystem.get_passive_bonus(merc, "dodge")
		+ merc.buff_system.get_bonus("dodge"))


static func get_block_chance(merc) -> float:
	return (_base_float(merc, "block_chance")
		+ _EquipmentSystem.calc_equipment_bonus(merc, "block_chance")
		+ _SkillSystem.get_passive_bonus(merc, "block_chance")
		+ merc.buff_system.get_bonus("block_chance"))


static func _base_int(merc, stat: String) -> int:
	match stat:
		"hp": return merc.hp
		"patk": return merc.patk
		"matk": return merc.matk
		"pdef": return merc.pdef
		"mdef": return merc.mdef
		"spd": return merc.spd
	return 0


static func _base_float(merc, stat: String) -> float:
	match stat:
		"crit_chance": return merc.crit_chance
		"dodge": return merc.dodge
		"block_chance": return merc.block_chance
		"attack_range": return merc.attack_range
		"attack_speed": return merc.attack_speed
	return 0.0
