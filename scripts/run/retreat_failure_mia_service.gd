class_name RetreatFailureMiaService
extends RefCounted
## 撤离失败 B-3a/b 比例 MIA（T-MIA-P3）— 未抵营收场，按濒死/压力档分流


const SURVIVOR_NEAR_DEATH_RATIO: float = 0.08


static func should_settle(_gm: GameManager, result: Dictionary) -> bool:
	if bool(result.get("manual_withdraw", false)):
		return false
	if bool(result.get("completed_retreat", false)):
		return false
	if bool(result.get("extract_clear", false)):
		return false
	if str(result.get("settlement_tier", "")) == "recovery":
		return false
	if int(result.get("run_mode", WorldRun.RunMode.NORMAL)) == WorldRun.RunMode.RECOVERY:
		return false
	if bool(result.get("retreat_failure", false)):
		return true
	var reason: String = str(result.get("retreat_reason", ""))
	if reason in ["forced", "emergency", "combat_fail", "pressure"]:
		return bool(result.get("is_retreating", false)) or bool(result.get("forced_withdraw", false))
	return false


static func is_distressed(merc: Mercenary) -> bool:
	if merc == null or not merc.is_alive or merc.is_mia:
		return false
	if merc.merc_type == Mercenary.MercType.PLAYER:
		return merc.is_near_death or merc.is_personal_break or not merc.is_personal_stability_ok()
	if merc.is_near_death:
		return true
	if merc.is_personal_break:
		return true
	if not merc.is_personal_stability_ok():
		return true
	return false


static func apply_settlement(gm: GameManager, result: Dictionary) -> void:
	if gm == null:
		return
	var field_mercs: Array[Mercenary] = _field_mercs(gm, result)
	if field_mercs.is_empty():
		return
	var distressed: Array[Mercenary] = []
	var intact: Array[Mercenary] = []
	for merc in field_mercs:
		if TestScenarioService.test_merc_blocks_casualties(merc):
			continue
		if is_distressed(merc):
			distressed.append(merc)
		else:
			intact.append(merc)
	var eligible: int = distressed.size() + intact.size()
	if eligible <= 0:
		return
	if distressed.is_empty():
		for merc in intact:
			merc.apply_near_death_state(SURVIVOR_NEAR_DEATH_RATIO)
		result["retreat_failure_mia"] = false
		result["retreat_failure_mode"] = "retreat-fail-survivors"
		result["near_death_penalty"] = true
		result["settlement_tier"] = "success"
		result["squad_wiped"] = false
		return
	var mode: String = "none"
	if distressed.size() >= eligible:
		mode = "B-3a"
		for merc in field_mercs:
			if not TestScenarioService.test_merc_blocks_casualties(merc):
				merc.enter_mia_state()
	elif distressed.size() > eligible / 2:
		mode = "B-3b"
		for merc in distressed:
			merc.enter_mia_state()
		for merc in intact:
			merc.apply_near_death_state(SURVIVOR_NEAR_DEATH_RATIO)
	else:
		mode = "B-3b-partial"
		for merc in distressed:
			merc.enter_mia_state()
		for merc in intact:
			merc.apply_near_death_state(SURVIVOR_NEAR_DEATH_RATIO)
	var mia_n: int = 0
	for merc in field_mercs:
		if merc.is_mia:
			mia_n += 1
	result["retreat_failure_mia"] = mia_n > 0
	result["retreat_failure_mode"] = mode
	result["mia_count"] = mia_n
	result["squad_wiped"] = false
	if mia_n > 0:
		result["settlement_tier"] = "mia"
		result["mia_wipe_recovery_hint"] = true


static func _field_mercs(gm: GameManager, result: Dictionary) -> Array[Mercenary]:
	var out: Array[Mercenary] = []
	for mid in result.get("squad_member_ids", []):
		var merc := gm.find_mercenary_by_id(str(mid))
		if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		out.append(merc)
	return out
