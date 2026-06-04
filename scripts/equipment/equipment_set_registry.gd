class_name EquipmentSetRegistry
extends RefCounted
## 套装数据只读注册表（加成计算预留，当前仅展示）


static var _sets: Dictionary = {}


static func load_from_data(data: Dictionary) -> void:
	_sets.clear()
	if not data.has("sets"):
		return
	for entry in data.sets:
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


static func count_equipped_pieces(merc: Mercenary, set_id: String) -> int:
	var def: Dictionary = get_set(set_id)
	if def.is_empty():
		return 0
	var piece_slots: Array = def.get("pieces", [])
	var count := 0
	for slot in piece_slots:
		var item = merc.equipment_slots.get(slot)
		if item is Equipment and item.set_id == set_id:
			count += 1
	return count


static func get_active_bonus_lines(merc: Mercenary) -> Array[String]:
	var lines: Array[String] = []
	for sid in _sets:
		var n: int = count_equipped_pieces(merc, sid)
		if n < 2:
			continue
		var def: Dictionary = _sets[sid]
		for bonus in def.get("bonuses", []):
			if n >= int(bonus.get("pieces_required", 99)):
				lines.append("[%s] %s" % [def.get("name", sid), bonus.get("description", "")])
	return lines
