class_name EquipmentSetRegistry
extends RefCounted
## 套装数据只读注册表；加成由 StatResolver 经 calc_set_bonus() 聚合


static var _sets: Dictionary = {}


static func load_from_data(data: Dictionary) -> void:
	_sets.clear()
	if not data.has("sets"):
		return
	for entry in data.get("sets", []):
		var sid: String = entry.get("set_id", "")
		if sid != "":
			_sets[sid] = entry


static func has_set(set_id: String) -> bool:
	return _sets.has(set_id)


static func get_set(set_id: String) -> Dictionary:
	return _sets.get(set_id, {})


static func get_set_name(set_id: String) -> String:
	var s: Dictionary = get_set(set_id)
	return s.get("name", set_id)


static func all_set_ids() -> Array:
	return _sets.keys()


static func count_equipped_pieces(merc, set_id: String) -> int:
	var def: Dictionary = get_set(set_id)
	if def.is_empty():
		return 0
	var piece_slots: Array = def.get("pieces", [])
	var count := 0
	for slot in piece_slots:
		var item = merc.equipment_slots.get(slot)
		if item != null and item.set_id == set_id:
			count += 1
	return count


static func get_set_piece_total(set_id: String) -> int:
	var def: Dictionary = get_set(set_id)
	return def.get("pieces", []).size()


## 已穿戴件数 > 0 的套装进度与已激活加成描述（UI 用）
static func get_active_bonus_lines(merc) -> Array[String]:
	var lines: Array[String] = []
	for sid in _sets:
		var n: int = count_equipped_pieces(merc, sid)
		if n <= 0:
			continue
		var def: Dictionary = _sets[sid]
		var total: int = maxi(1, get_set_piece_total(sid))
		var name: String = def.get("name", sid)
		var progress := "%s %d/%d" % [name, n, total]
		var active_desc: Array[String] = []
		for bonus in def.get("bonuses", []):
			if n >= int(bonus.get("pieces_required", 99)):
				var desc: String = bonus.get("description", "")
				if desc != "":
					active_desc.append(desc)
		if active_desc.is_empty():
			lines.append(progress)
		else:
			lines.append("%s ·%s" % [progress, ", ".join(active_desc)])
	return lines


## 当前已激活套装加成之和（供 StatResolver 调用，不写回 Mercenary）
static func calc_set_bonus(merc, stat: String) -> float:
	var total := 0.0
	for sid in _sets:
		var n: int = count_equipped_pieces(merc, sid)
		if n < 2:
			continue
		var def: Dictionary = _sets[sid]
		for bonus in def.get("bonuses", []):
			if n < int(bonus.get("pieces_required", 99)):
				continue
			var stats_dict: Dictionary = bonus.get("stats", {})
			if not stats_dict.has(stat):
				continue
			var raw = stats_dict[stat]
			match stat:
				"crit_chance", "dodge", "block_chance", "attack_range", "attack_speed":
					total += float(raw)
				_:
					total += float(int(raw))
	return total
