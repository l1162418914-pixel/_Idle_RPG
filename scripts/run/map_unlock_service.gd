class_name MapUnlockService
extends RefCounted
## 地图解锁进度 — 从 GameManager 迁出


static func is_map_unlocked(gm: GameManager, map_id: String) -> bool:
	return map_id in gm.unlocked_maps


static func get_unlock_level(gm: GameManager) -> int:
	var total := 0
	for bid in gm.buildings:
		total += int(gm.buildings[bid].get("level", 1))
	return maxi(1, total)


static func get_map_lock_reason(gm: GameManager, map_id: String) -> String:
	var md: Dictionary = DataLoader.map_data(map_id)
	if is_map_unlocked(gm, map_id):
		return ""
	return MapProgression.get_lock_reason(md, get_unlock_level(gm), gm.defeated_map_bosses)


static func get_all_maps_sorted() -> Array:
	var list: Array = DataLoader.all_maps()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("danger_level", 0)) < int(b.get("danger_level", 0))
	)
	return list


static func get_available_maps(gm: GameManager) -> Array:
	refresh_map_unlocks(gm)
	var list: Array = []
	for m in get_all_maps_sorted():
		var mid: String = str(m.get("map_id", ""))
		if mid != "" and is_map_unlocked(gm, mid):
			list.append(m)
	return list


static func refresh_map_unlocks(gm: GameManager) -> Array[String]:
	sync_always_unlocked_maps(gm)
	gm.last_unlocked_maps.clear()
	var base_lv: int = get_unlock_level(gm)
	for m in DataLoader.all_maps():
		var mid: String = str(m.get("map_id", ""))
		if mid == "" or is_map_unlocked(gm, mid):
			continue
		var md: Dictionary = DataLoader.map_data(mid)
		if md.is_empty():
			md = m
		if MapProgression.can_unlock(md, base_lv, gm.defeated_map_bosses):
			gm.unlocked_maps.append(mid)
			gm.last_unlocked_maps.append(mid)
	return gm.last_unlocked_maps.duplicate()


static func sync_always_unlocked_maps(gm: GameManager) -> void:
	for m in DataLoader.all_maps():
		if not MapProgression.is_always_unlocked(m):
			continue
		var mid: String = str(m.get("map_id", ""))
		if mid != "" and mid not in gm.unlocked_maps:
			gm.unlocked_maps.append(mid)


static func record_boss_defeat(gm: GameManager, map_id: String) -> void:
	if map_id == "":
		return
	if map_id not in gm.defeated_map_bosses:
		gm.defeated_map_bosses.append(map_id)
