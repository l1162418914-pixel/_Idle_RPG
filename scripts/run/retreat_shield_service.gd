class_name RetreatShieldService
extends RefCounted
## 返程双池护盾：装备层 → 物资层；装备 CD、濒死烧物资


static func init_shields(run: WorldRun, reason: String, is_refresh: bool = false) -> void:
	if run == null or run.squad == null:
		return
	if reason == "manual":
		_clear_shields(run)
		return
	if is_refresh:
		_apply_emergency_refresh(run, reason)
		return
	_clear_shields(run)
	run._shield_cd_equipment_ids.clear()
	var reason_mult: float = _reason_shield_mult(run, reason)
	var equip_base: int = _sum_equip_shield_max(run)
	var grid_cap: int = _shield_config_int("grid_material_cap", 400)
	var burn: int = _near_death_material_burn(run)
	var grid_mat: int = mini(_grid_material_value(run), grid_cap)
	var material_base: int = mini(grid_mat + burn, grid_cap + _shield_config_int("near_death_burn_cap", 250))
	var scaled_equip: int = maxi(0, int(float(equip_base) * reason_mult))
	var scaled_mat: int = maxi(0, int(float(material_base) * reason_mult))
	if run._pending_awakening_shield_bonus > 0:
		scaled_mat += run._pending_awakening_shield_bonus
		run._pending_awakening_shield_bonus = 0
	run.equip_shield_max = scaled_equip
	run.equip_shield_current = scaled_equip
	run.material_shield_max = scaled_mat
	run.material_shield_current = scaled_mat
	_track_equip_cd_sources(run)
	_sync_legacy_shield_fields(run)
	_emit_shield_started(run, reason)


static func apply_damage(run: WorldRun, damage: int) -> Dictionary:
	if run == null or damage <= 0:
		return {"absorbed": 0, "broken": false}
	var remaining: int = damage
	var equip_absorbed := 0
	if run.equip_shield_current > 0 and remaining > 0:
		equip_absorbed = mini(run.equip_shield_current, remaining)
		run.equip_shield_current -= equip_absorbed
		remaining -= equip_absorbed
	var mat_absorbed := 0
	if run.material_shield_current > 0 and remaining > 0:
		mat_absorbed = mini(run.material_shield_current, remaining)
		run.material_shield_current -= mat_absorbed
		remaining -= mat_absorbed
	var total_absorbed: int = equip_absorbed + mat_absorbed
	_sync_legacy_shield_fields(run)
	var broken: bool = (
		run.equip_shield_max + run.material_shield_max > 0
		and run.equip_shield_current + run.material_shield_current <= 0
	)
	if total_absorbed > 0 and run.stability != null and total_absorbed >= 12:
		var shake: int = 1 if total_absorbed < 40 else 2
		run.stability.modify_team_stability(-shake)
	return {"absorbed": total_absorbed, "broken": broken, "equip": equip_absorbed, "material": mat_absorbed}


static func is_active(run: WorldRun) -> bool:
	if run == null or not run.is_retreating:
		return false
	return run.equip_shield_current + run.material_shield_current > 0


static func apply_shield_cd_after_run(run: WorldRun, result: Dictionary) -> void:
	if run == null or result.get("manual_withdraw", false):
		return
	var reason: String = str(result.get("retreat_reason", ""))
	if reason == "" or reason == "manual":
		return
	if run._shield_cd_equipment_ids.is_empty():
		return
	var runs: int = _shield_config_int("equip_cd_runs", 2)
	_apply_cd_to_roster(run._shield_cd_equipment_ids, runs)
	result["shield_cd_applied"] = true


## 每场新出征开始前：全局装备护盾 CD 减 1
static func tick_shield_cd_on_run_start() -> void:
	if GameManager == null:
		return
	for eq in GameManager.get_all_equipped_items():
		if eq != null and eq.shield_cd_runs_left > 0:
			eq.shield_cd_runs_left = maxi(0, eq.shield_cd_runs_left - 1)


static func shield_contribution(item: Equipment) -> int:
	if item == null:
		return 0
	if item.shield_cd_runs_left > 0:
		return 0
	var pdef: int = int(item.stats.get("pdef", 0))
	var mdef: int = int(item.stats.get("mdef", 0))
	var hp: int = int(item.stats.get("hp", 0))
	var score: int = (pdef + mdef) * 2 + int(hp * 0.4) + item.quality * 10
	return maxi(1, score)


static func _apply_emergency_refresh(run: WorldRun, reason: String) -> void:
	if run._shield_emergency_refresh_used:
		return
	run._shield_emergency_refresh_used = true
	var ratio: float = float(_shield_config().get("emergency_refresh_ratio", 0.3))
	var equip_add: int = int(float(run.equip_shield_max - run.equip_shield_current) * ratio)
	var mat_add: int = int(float(run.material_shield_max - run.material_shield_current) * ratio)
	run.equip_shield_current = mini(run.equip_shield_max, run.equip_shield_current + equip_add)
	run.material_shield_current = mini(run.material_shield_max, run.material_shield_current + mat_add)
	_sync_legacy_shield_fields(run)
	_emit_shield_started(run, reason + "_refresh")


static func _clear_shields(run: WorldRun) -> void:
	run.equip_shield_max = 0
	run.equip_shield_current = 0
	run.material_shield_max = 0
	run.material_shield_current = 0
	run.retreat_shield_max = 0
	run.retreat_shield_current = 0


static func _sync_legacy_shield_fields(run: WorldRun) -> void:
	run.retreat_shield_current = run.equip_shield_current + run.material_shield_current
	run.retreat_shield_max = run.equip_shield_max + run.material_shield_max


static func _sum_equip_shield_max(run: WorldRun) -> int:
	var total := 0
	for m in run.squad.members:
		if m == null:
			continue
		for slot in m.equipment_slots:
			var eq: Equipment = m.equipment_slots[slot]
			if eq is Equipment:
				total += shield_contribution(eq)
	return total


static func _track_equip_cd_sources(run: WorldRun) -> void:
	for m in run.squad.members:
		if m == null:
			continue
		for slot in m.equipment_slots:
			var eq: Equipment = m.equipment_slots[slot]
			if eq is Equipment and shield_contribution(eq) > 0:
				if eq.item_id != "" and eq.item_id not in run._shield_cd_equipment_ids:
					run._shield_cd_equipment_ids.append(eq.item_id)


static func _grid_material_value(run: WorldRun) -> int:
	var total := 0
	if run.safe_loot:
		total += run.safe_loot.get_total_material_value()
	if run.exposed_loot:
		total += run.exposed_loot.get_total_material_value()
	return total


static func _near_death_material_burn(run: WorldRun) -> int:
	if run.squad == null or not run.squad.has_any_member_near_death():
		return 0
	var ratio: float = float(_shield_config().get("near_death_burn_ratio", 0.45))
	var cap: int = _shield_config_int("near_death_burn_cap", 250)
	var want: int = mini(cap, int(float(_grid_material_value(run)) * ratio))
	if want <= 0:
		return 0
	var ratio_shield: float = float(_shield_config().get("material_to_shield_ratio", 1.0))
	var consumed: int = 0
	if run.safe_loot:
		consumed += run.safe_loot.consume_material_value(want - consumed)
	if run.exposed_loot and consumed < want:
		consumed += run.exposed_loot.consume_material_value(want - consumed)
	return mini(cap, int(float(consumed) * ratio_shield))


static func _reason_shield_mult(run: WorldRun, reason: String) -> float:
	var base: float = float(run.map_data.get("retreat_shield_mult", 1.0))
	match reason:
		"combat_fail":
			return base * 1.12
		"emergency":
			return base * 1.05
		"forced":
			return base * 0.98
		"auto_value":
			return base * 0.92
		_:
			return base


static func _shield_config() -> Dictionary:
	return DataLoader.loot_material_shield_config()


static func _shield_config_int(key: String, default: int) -> int:
	return int(_shield_config().get(key, default))


static func _emit_shield_started(run: WorldRun, reason: String) -> void:
	run.emit_signal(
		"run_event",
		"retreat_shield_started",
		{
			"shield": run.retreat_shield_current,
			"shield_max": run.retreat_shield_max,
			"equip_shield": run.equip_shield_current,
			"equip_shield_max": run.equip_shield_max,
			"material_shield": run.material_shield_current,
			"material_shield_max": run.material_shield_max,
			"reason": reason,
		}
	)


static func _apply_cd_to_roster(item_ids: Array, runs: int) -> void:
	if GameManager == null:
		return
	for eq in GameManager.get_all_equipped_items():
		if eq != null and eq.item_id in item_ids:
			eq.shield_cd_runs_left = maxi(eq.shield_cd_runs_left, runs)
