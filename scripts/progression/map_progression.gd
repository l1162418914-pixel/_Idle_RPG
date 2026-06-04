class_name MapProgression
extends RefCounted
## 地图解锁条件判定（基地等级 + 前置 Boss）


static func is_always_unlocked(map_data: Dictionary) -> bool:
	return bool(map_data.get("always_unlocked", false))


static func meets_base_level(map_data: Dictionary, base_level: int) -> bool:
	return base_level >= int(map_data.get("unlock_base_level", 99))


static func meets_boss_requirement(map_data: Dictionary, defeated_map_bosses: Array) -> bool:
	var req: String = str(map_data.get("unlock_after_boss_on_map", ""))
	if req == "":
		return true
	return req in defeated_map_bosses


static func can_unlock(map_data: Dictionary, base_level: int, defeated_map_bosses: Array) -> bool:
	if map_data.is_empty():
		return false
	if is_always_unlocked(map_data):
		return true
	if not meets_base_level(map_data, base_level):
		return false
	if not meets_boss_requirement(map_data, defeated_map_bosses):
		return false
	return true


static func get_lock_reason(map_data: Dictionary, base_level: int, defeated_map_bosses: Array) -> String:
	if map_data.is_empty():
		return "未知地图"
	if is_always_unlocked(map_data):
		return ""
	if not meets_base_level(map_data, base_level):
		return "需要基地建筑总等级 ≥ %d（当前 %d）" % [
			int(map_data.get("unlock_base_level", 1)), base_level
		]
	var req: String = str(map_data.get("unlock_after_boss_on_map", ""))
	if req != "" and req not in defeated_map_bosses:
		var prev: Dictionary = DataLoader.map_data(req)
		var prev_name: String = prev.get("name", req)
		return "需要击败 [%s] 的 Boss" % prev_name
	return "未解锁"
