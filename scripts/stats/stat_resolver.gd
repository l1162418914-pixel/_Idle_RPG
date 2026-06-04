class_name StatResolver
extends RefCounted
## 最终属性 = base（Mercenary 模板+成长）+ 装备 + 被动 + Buff
## Mercenary 字段仅存 base；本类为唯一 final 计算入口


static func compute(merc: Mercenary) -> CombatStats:
	merc.refresh_base_stats()
	var stats := CombatStats.new()
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


static func get_attack_range(merc: Mercenary) -> float:
	return _base_float(merc, "attack_range") + float(EquipmentSystem.calc_equipment_bonus(merc, "attack_range"))


static func get_attack_speed(merc: Mercenary) -> float:
	var base: float = _base_float(merc, "attack_speed")
	var bonus: float = float(EquipmentSystem.calc_equipment_bonus(merc, "attack_speed"))
	return maxf(0.1, base + bonus)


static func get_max_hp(merc: Mercenary) -> int:
	return (_base_int(merc, "hp")
		+ EquipmentSystem.calc_equipment_bonus(merc, "hp")
		+ int(SkillSystem.get_passive_bonus(merc, "hp"))
		+ int(merc.buff_system.get_bonus("hp")))


static func get_patk(merc: Mercenary) -> int:
	return (_base_int(merc, "patk")
		+ EquipmentSystem.calc_equipment_bonus(merc, "patk")
		+ int(SkillSystem.get_passive_bonus(merc, "patk"))
		+ int(merc.buff_system.get_bonus("patk")))


static func get_matk(merc: Mercenary) -> int:
	return (_base_int(merc, "matk")
		+ EquipmentSystem.calc_equipment_bonus(merc, "matk")
		+ int(SkillSystem.get_passive_bonus(merc, "matk"))
		+ int(merc.buff_system.get_bonus("matk")))


static func get_pdef(merc: Mercenary) -> int:
	return (_base_int(merc, "pdef")
		+ EquipmentSystem.calc_equipment_bonus(merc, "pdef")
		+ int(SkillSystem.get_passive_bonus(merc, "pdef"))
		+ int(merc.buff_system.get_bonus("pdef")))


static func get_mdef(merc: Mercenary) -> int:
	return (_base_int(merc, "mdef")
		+ EquipmentSystem.calc_equipment_bonus(merc, "mdef")
		+ int(SkillSystem.get_passive_bonus(merc, "mdef"))
		+ int(merc.buff_system.get_bonus("mdef")))


static func get_spd(merc: Mercenary) -> int:
	return (_base_int(merc, "spd")
		+ EquipmentSystem.calc_equipment_bonus(merc, "spd")
		+ int(SkillSystem.get_passive_bonus(merc, "spd"))
		+ int(merc.buff_system.get_bonus("spd")))


static func get_crit_chance(merc: Mercenary) -> float:
	return (_base_float(merc, "crit_chance")
		+ EquipmentSystem.calc_equipment_bonus(merc, "crit_chance")
		+ SkillSystem.get_passive_bonus(merc, "crit_chance")
		+ merc.buff_system.get_bonus("crit_chance"))


static func get_dodge(merc: Mercenary) -> float:
	return (_base_float(merc, "dodge")
		+ EquipmentSystem.calc_equipment_bonus(merc, "dodge")
		+ SkillSystem.get_passive_bonus(merc, "dodge")
		+ merc.buff_system.get_bonus("dodge"))


static func get_block_chance(merc: Mercenary) -> float:
	return (_base_float(merc, "block_chance")
		+ EquipmentSystem.calc_equipment_bonus(merc, "block_chance")
		+ SkillSystem.get_passive_bonus(merc, "block_chance")
		+ merc.buff_system.get_bonus("block_chance"))


static func _base_int(merc: Mercenary, stat: String) -> int:
	match stat:
		"hp": return merc.hp
		"patk": return merc.patk
		"matk": return merc.matk
		"pdef": return merc.pdef
		"mdef": return merc.mdef
		"spd": return merc.spd
	return 0


static func _base_float(merc: Mercenary, stat: String) -> float:
	match stat:
		"crit_chance": return merc.crit_chance
		"dodge": return merc.dodge
		"block_chance": return merc.block_chance
		"attack_range": return merc.attack_range
		"attack_speed": return merc.attack_speed
	return 0.0
