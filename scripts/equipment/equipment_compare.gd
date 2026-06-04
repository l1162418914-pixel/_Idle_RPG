class_name EquipmentCompare
extends RefCounted
## 装备战力评分与对比（用于结算一键换装）


static func power_score(item: Equipment) -> int:
	if item == null:
		return 0
	var score := item.quality * 100
	for key in item.stats:
		var v = item.stats[key]
		match key:
			"patk", "matk", "pdef", "mdef", "hp", "spd":
				score += int(v) * 2
			"crit_chance", "dodge", "block_chance":
				score += int(float(v) * 100)
	return score


static func is_upgrade(new_item: Equipment, old_item: Equipment) -> bool:
	if new_item == null:
		return false
	if old_item == null:
		return true
	return power_score(new_item) > power_score(old_item)


static func format_stats_line(item: Equipment) -> String:
	if item == null or item.stats.is_empty():
		return ""
	var parts: Array[String] = []
	for key in item.stats:
		parts.append(_stat_label(key) + "+%s" % str(item.stats[key]))
	return " ".join(parts)


static func compare_label(new_item: Equipment, old_item: Equipment) -> String:
	if old_item == null:
		return "[新槽位 ↑]"
	if is_upgrade(new_item, old_item):
		return "[提升 ↑%d]" % (power_score(new_item) - power_score(old_item))
	return "[持平或更低]"


static func _stat_label(key: String) -> String:
	match key:
		"patk": return "物攻"
		"matk": return "魔攻"
		"pdef": return "物防"
		"mdef": return "魔防"
		"hp": return "生命"
		"spd": return "速度"
		"crit_chance": return "暴击"
		"dodge": return "闪避"
		"block_chance": return "格挡"
		_: return key
