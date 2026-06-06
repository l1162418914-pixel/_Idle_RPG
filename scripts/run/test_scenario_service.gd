class_name TestScenarioService
extends RefCounted
## 测试图：自带编队注入、进图横幅文案


static func is_test_map(map_data: Dictionary) -> bool:
	if map_data.is_empty():
		return false
	if TestRosterLoader.has_roster(str(map_data.get("map_id", ""))):
		return true
	var sid: String = str(map_data.get("test_scenario", ""))
	return sid != "" or str(map_data.get("map_id", "")).begins_with("test_")


static func should_lock_roster(map_data: Dictionary) -> bool:
	var map_id: String = str(map_data.get("map_id", ""))
	return TestRosterLoader.has_roster(map_id)


static func apply_on_prepare(gm: GameManager, map_id: String) -> void:
	if gm == null:
		return
	var md: Dictionary = DataLoader.map_data(map_id)
	if md.is_empty():
		return
	var roster: Dictionary = TestRosterLoader.roster_for_map(map_id)
	if not roster.is_empty():
		gm.apply_map_test_roster(roster)
		return
	match str(md.get("test_scenario", "")):
		"boss_chase", "awakening":
			gm.squad_formation["active_half"] = SquadFormationService.HALF_A
			SquadFormationService.rebalance_from_roster(gm)


static func get_run_start_banner(map_data: Dictionary) -> String:
	var map_id: String = str(map_data.get("map_id", ""))
	var roster: Dictionary = TestRosterLoader.roster_for_map(map_id)
	var desc: String = str(map_data.get("description", ""))
	if desc == "":
		return ""
	var lines: PackedStringArray = []
	var sid: String = str(map_data.get("test_scenario", ""))
	var tag := _scenario_tag(sid)
	if tag != "":
		lines.append("[测试·%s] %s" % [tag, desc])
	elif is_test_map(map_data):
		lines.append("[测试说明] %s" % desc)
	var roster_label: String = str(roster.get("display_name", ""))
	if roster_label != "":
		lines.append("[本图编队] %s" % roster_label)
		lines.append("[主角] 保留当前存档角色名与养成，仅槽位与测试佣兵由本图注入")
	var eta: String = str(map_data.get("test_target_duration", ""))
	if eta != "":
		lines.append("[目标用时] %s" % eta)
	return "\n".join(lines)


static func _scenario_tag(scenario_id: String) -> String:
	match scenario_id:
		"stability_retreat":
			return "稳定度返程"
		"boss_chase":
			return "Boss追击"
		"awakening":
			return "绝境觉醒"
		"solo_near_death":
			return "单人濒死"
		"duo_near_death":
			return "双人濒死"
		"extract_line":
			return "撤离物线"
		"auto_value":
			return "价值撤离"
		"loot_full":
			return "网格满撤"
		"long_chase_pressure":
			return "濒死追击灭团"
		_:
			return ""
