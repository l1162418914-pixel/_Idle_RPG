class_name TestScenarioService
extends RefCounted
## 测试图：出征前自动编队、进图横幅文案


static func is_test_map(map_data: Dictionary) -> bool:
	if map_data.is_empty():
		return false
	var sid: String = str(map_data.get("test_scenario", ""))
	if sid != "":
		return true
	var mid: String = str(map_data.get("map_id", ""))
	return mid.begins_with("test_") or mid == "retreat_drill"


## 固定编队测试图：准备界面不再 auto_fill 补满半组
static func should_lock_roster(map_data: Dictionary) -> bool:
	var sid: String = str(map_data.get("test_scenario", ""))
	return sid in [
		"solo_player_near_death_retreat",
		"duo_near_death_retreat",
	]


static func apply_on_prepare(gm: GameManager, map_id: String) -> void:
	if gm == null:
		return
	var md: Dictionary = DataLoader.map_data(map_id)
	if md.is_empty():
		return
	match str(md.get("test_scenario", "")):
		"solo_player_near_death_retreat":
			_apply_active_roster(gm, _solo_ids(gm))
		"duo_near_death_retreat":
			_apply_active_roster(gm, _duo_ids(gm))
		"boss_chase", "awakening":
			gm.squad_formation["active_half"] = SquadFormationService.HALF_A
			SquadFormationService.rebalance_from_roster(gm)


static func get_run_start_banner(map_data: Dictionary) -> String:
	var sid: String = str(map_data.get("test_scenario", ""))
	var desc: String = str(map_data.get("description", ""))
	if desc == "":
		return ""
	var tag := _scenario_tag(sid)
	if tag != "":
		return "[测试·%s] %s" % [tag, desc]
	if is_test_map(map_data):
		return "[测试说明] %s" % desc
	return ""


static func _scenario_tag(scenario_id: String) -> String:
	match scenario_id:
		"boss_chase":
			return "Boss追击"
		"awakening":
			return "绝境觉醒"
		"solo_player_near_death_retreat":
			return "单人濒死"
		"duo_near_death_retreat":
			return "双人濒死"
		"extract_line":
			return "撤离物线"
		"retreat_drill":
			return "返程演练"
		"auto_value":
			return "价值撤离"
		"loot_full":
			return "网格满撤"
		_:
			return ""


static func _solo_ids(gm: GameManager) -> Array[String]:
	var ids: Array[String] = []
	if gm.player and gm.player.is_alive:
		ids.append(gm.player.merc_id)
	return ids


static func _duo_ids(gm: GameManager) -> Array[String]:
	var ids: Array[String] = _solo_ids(gm)
	for e in gm.elite_roster:
		if e.is_alive and e.merc_id not in ids:
			ids.append(e.merc_id)
			break
	if ids.size() < 2:
		for n in gm.normal_roster:
			if n.is_alive and n.merc_id not in ids:
				ids.append(n.merc_id)
				break
	return ids


static func _apply_active_roster(gm: GameManager, roster_ids: Array[String]) -> void:
	SquadFormationService.ensure_formation(gm)
	gm.squad_formation[SquadFormationService.HALF_A] = {"active": [], "bench": []}
	gm.squad_formation[SquadFormationService.HALF_B] = {"active": [], "bench": []}
	gm.squad_formation["active_half"] = SquadFormationService.HALF_A
	var idx := 0
	for mid in roster_ids:
		if idx >= SquadFormationService.MAX_ACTIVE:
			break
		if SquadFormationService.assign_merc_to_slot(
			gm, mid, SquadFormationService.HALF_A, "active", idx
		) == 0:
			idx += 1
	gm.formation_changed.emit()
