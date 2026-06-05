extends RefCounted
class_name EquipmentSystem
## 装备槽位加成计算；最终属性统一由 StatResolver 聚合
## apply_to 仅刷新 Mercenary 基础属性（模板+成长）


static func apply_to(merc) -> void:
	merc.refresh_base_stats()


static func calc_equipment_bonus(merc, stat: String):
	return _calc_equipment_bonus(merc, stat)


static func _calc_equipment_bonus(merc, stat: String):
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
