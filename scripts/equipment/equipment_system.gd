extends RefCounted
class_name EquipmentSystem
## 战斗属性计算统一入口
## 聚合层：base + equipment + passive + buff
## 后续 Inventory / Skill / Buff 系统只需扩展对应的 _get_xxx 函数


# ═══════════════════════════════════════════════════════
#  对外：apply_to — sync merc 字段（向后兼容）
# ═══════════════════════════════════════════════════════

static func apply_to(merc: Mercenary) -> void:
	merc._recalc_stats_from_base()
	merc.patk         = get_attack(merc)
	merc.matk         = get_magic_attack(merc)
	merc.pdef         = get_defense(merc)
	merc.mdef         = get_magic_defense(merc)
	merc.max_hp       = get_max_hp(merc)
	merc.spd          = get_speed(merc)
	merc.crit_chance  = get_crit_chance(merc)
	merc.dodge        = get_dodge(merc)
	merc.block_chance = get_block_chance(merc)


# ═══════════════════════════════════════════════════════
#  统一战斗属性入口
# ═══════════════════════════════════════════════════════

static func get_attack(merc: Mercenary) -> int:
	return (_get_base(merc, "patk")
		+ _calc_equipment_bonus(merc, "patk")
		+ _get_passive_attack(merc)
		+ _get_buff_attack(merc))


static func get_magic_attack(merc: Mercenary) -> int:
	return (_get_base(merc, "matk")
		+ _calc_equipment_bonus(merc, "matk")
		+ _get_passive_magic_attack(merc)
		+ _get_buff_magic_attack(merc))


static func get_defense(merc: Mercenary) -> int:
	return (_get_base(merc, "pdef")
		+ _calc_equipment_bonus(merc, "pdef")
		+ _get_passive_defense(merc)
		+ _get_buff_defense(merc))


static func get_magic_defense(merc: Mercenary) -> int:
	return (_get_base(merc, "mdef")
		+ _calc_equipment_bonus(merc, "mdef")
		+ _get_passive_magic_defense(merc)
		+ _get_buff_magic_defense(merc))


## max_hp 的基础值取 merc.hp（体质），不是 merc.max_hp
## merc.hp 在 _recalc_stats_from_base 中已被 growth 增幅
static func get_max_hp(merc: Mercenary) -> int:
	return (_get_base(merc, "hp")
		+ _calc_equipment_bonus(merc, "hp")
		+ _get_passive_hp(merc)
		+ _get_buff_hp(merc))


static func get_speed(merc: Mercenary) -> int:
	return (_get_base(merc, "spd")
		+ _calc_equipment_bonus(merc, "spd")
		+ _get_passive_speed(merc)
		+ _get_buff_speed(merc))


static func get_crit_chance(merc: Mercenary) -> float:
	return (_get_base(merc, "crit_chance")
		+ _calc_equipment_bonus(merc, "crit_chance")
		+ _get_passive_crit(merc)
		+ _get_buff_crit(merc))


static func get_dodge(merc: Mercenary) -> float:
	return (_get_base(merc, "dodge")
		+ _calc_equipment_bonus(merc, "dodge")
		+ _get_passive_dodge(merc)
		+ _get_buff_dodge(merc))


static func get_block_chance(merc: Mercenary) -> float:
	return (_get_base(merc, "block_chance")
		+ _calc_equipment_bonus(merc, "block_chance")
		+ _get_passive_block(merc)
		+ _get_buff_block(merc))


# ═══════════════════════════════════════════════════════
#  内部：从 merc 读基础值
# ═══════════════════════════════════════════════════════

static func _get_base(merc: Mercenary, stat: String):
	match stat:
		"patk":         return merc.patk
		"matk":         return merc.matk
		"pdef":         return merc.pdef
		"mdef":         return merc.mdef
		"hp":           return merc.hp
		"spd":          return merc.spd
		"crit_chance":  return merc.crit_chance
		"dodge":        return merc.dodge
		"block_chance": return merc.block_chance
	return 0


# ═══════════════════════════════════════════════════════
#  内部：装备加成计算（纯函数，不改 merc）
# ═══════════════════════════════════════════════════════

static func _calc_equipment_bonus(merc: Mercenary, stat: String):
	var total := 0.0
	for slot in merc.equipment_slots:
		var item = merc.equipment_slots[slot]
		if item == null or not item.stats.has(stat):
			continue
		var raw = item.stats[stat]
		match stat:
			"crit_chance", "dodge", "block_chance":
				total += float(raw) / 100.0
			_:
				total += int(raw)
	return total


# ═══════════════════════════════════════════════════════
#  扩展点：被动技能加成
# ═══════════════════════════════════════════════════════

static func _get_passive_attack(merc: Mercenary) -> int:
	return int(SkillSystem.get_passive_bonus(merc, "patk"))

static func _get_passive_magic_attack(merc: Mercenary) -> int:
	return int(SkillSystem.get_passive_bonus(merc, "matk"))

static func _get_passive_defense(merc: Mercenary) -> int:
	return int(SkillSystem.get_passive_bonus(merc, "pdef"))

static func _get_passive_magic_defense(merc: Mercenary) -> int:
	return int(SkillSystem.get_passive_bonus(merc, "mdef"))

static func _get_passive_hp(merc: Mercenary) -> int:
	return int(SkillSystem.get_passive_bonus(merc, "hp"))

static func _get_passive_speed(merc: Mercenary) -> int:
	return int(SkillSystem.get_passive_bonus(merc, "spd"))

static func _get_passive_crit(merc: Mercenary) -> float:
	return SkillSystem.get_passive_bonus(merc, "crit_chance")

static func _get_passive_dodge(merc: Mercenary) -> float:
	return SkillSystem.get_passive_bonus(merc, "dodge")

static func _get_passive_block(merc: Mercenary) -> float:
	return SkillSystem.get_passive_bonus(merc, "block_chance")


# ═══════════════════════════════════════════════════════
#  扩展点：战斗 Buff 加成 → BuffSystem
# ═══════════════════════════════════════════════════════

static func _get_buff_attack(merc: Mercenary) -> int:
	return int(merc.buff_system.get_bonus("patk"))

static func _get_buff_magic_attack(merc: Mercenary) -> int:
	return int(merc.buff_system.get_bonus("matk"))

static func _get_buff_defense(merc: Mercenary) -> int:
	return int(merc.buff_system.get_bonus("pdef"))

static func _get_buff_magic_defense(merc: Mercenary) -> int:
	return int(merc.buff_system.get_bonus("mdef"))

static func _get_buff_hp(merc: Mercenary) -> int:
	return int(merc.buff_system.get_bonus("hp"))

static func _get_buff_speed(merc: Mercenary) -> int:
	return int(merc.buff_system.get_bonus("spd"))

static func _get_buff_crit(merc: Mercenary) -> float:
	return merc.buff_system.get_bonus("crit_chance")

static func _get_buff_dodge(merc: Mercenary) -> float:
	return merc.buff_system.get_bonus("dodge")

static func _get_buff_block(merc: Mercenary) -> float:
	return merc.buff_system.get_bonus("block_chance")


# ═══════════════════════════════════════════════════════
#  对外：装备总加成（纯查询用）
# ═══════════════════════════════════════════════════════

static func get_total_bonuses(equipment_slots: Dictionary) -> Dictionary:
	var total: Dictionary = {}
	for slot in equipment_slots:
		var item = equipment_slots[slot]
		if item == null:
			continue
		for key in item.stats:
			var bonus = item.stats[key]
			if key in ["crit_chance", "dodge", "block_chance"]:
				bonus = float(bonus) / 100.0
			total[key] = total.get(key, 0) + bonus
	return total