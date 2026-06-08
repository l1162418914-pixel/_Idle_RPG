class_name AutoRetreatService
extends RefCounted


static func check(run: WorldRun) -> bool:
	if run == null or not run.is_active or run.is_retreating:
		return false
	if ExpeditionStrategyService.is_push(run):
		return false
	if ExpeditionStrategyService.check_periodic(run):
		return true
	if not ExpeditionStrategyService.allows_periodic_auto_retreat(run):
		return false
	if _blocked_until_boss(run):
		return false
	var reason := _check_rules(run)
	if reason == "":
		reason = _check_value_threshold(run)
	if reason == "":
		return false
	return ExpeditionStrategyService.trigger_retreat(
		run,
		reason,
		""
	)


static func get_value_threshold(run: WorldRun) -> int:
	if run == null:
		return 0
	if run.map_data.has("auto_carry_value_threshold"):
		return int(run.map_data.auto_carry_value_threshold)
	return int(DataLoader.auto_retreat_defaults().get("global_value_threshold", 400))


static func _check_value_threshold(run: WorldRun) -> String:
	if not _value_enabled(run):
		return ""
	var threshold: int = get_value_threshold(run)
	var carry: int = CarryValueService.compute(run, _safe_only(run))
	if carry >= threshold:
		return "auto_value"
	return ""


static func _check_rules(run: WorldRun) -> String:
	if not ExpeditionStrategyService.should_use_fill_rules(run):
		return ""
	for rule in DataLoader.auto_retreat_rules():
		if not bool(rule.get("enabled", true)):
			continue
		if _rule_matches(run, rule):
			return str(rule.get("reason", "auto_rule"))
	return ""


static func _rule_matches(run: WorldRun, rule: Dictionary) -> bool:
	var rtype: String = str(rule.get("type", ""))
	var threshold: float = float(rule.get("threshold", 1.0))
	match rtype:
		"safe_fill_ratio":
			if run.safe_loot == null:
				return false
			return run.safe_loot.get_fill_ratio() >= threshold
		"exposed_fill_ratio":
			if run.exposed_loot == null:
				return false
			return run.exposed_loot.get_fill_ratio() >= threshold
		"carry_value":
			return CarryValueService.compute(run, _safe_only(run)) >= int(threshold)
	return false


static func _blocked_until_boss(run: WorldRun) -> bool:
	if not bool(run.map_data.get("block_auto_retreat_until_boss", false)):
		return false
	if run.boss_defeated:
		return false
	if run.has_active_extract_line():
		return false
	return true


static func _value_enabled(run: WorldRun = null) -> bool:
	if run != null and ExpeditionStrategyService.is_loot(run):
		return true
	if run != null:
		return bool(run.auto_retreat_value_enabled)
	if GameManager:
		return GameManager.auto_retreat_value_enabled
	return bool(DataLoader.auto_retreat_defaults().get("value_enabled", true))


static func _safe_only(run: WorldRun = null) -> bool:
	if run != null and ExpeditionStrategyService.is_loot(run):
		return false
	if run != null:
		return bool(run.auto_retreat_safe_only)
	if GameManager:
		return GameManager.auto_retreat_safe_only
	return bool(DataLoader.auto_retreat_defaults().get("value_safe_only", false))
