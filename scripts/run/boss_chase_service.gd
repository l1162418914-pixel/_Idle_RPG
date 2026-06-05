class_name BossChaseService
extends RefCounted
## Boss 追击：压力计算、速度/稳定缩放、击退与逃脱经验


static func compute_pressure(run: WorldRun) -> float:
	if run == null:
		return 0.0
	var md: Dictionary = run.map_data
	var dist_w: float = float(md.get("chase_w_dist", 0.45))
	var kill_w: float = float(md.get("chase_w_kill", 0.25))
	var zone_w: float = float(md.get("chase_w_boss_zone", 0.30))
	var kill_scale: float = maxf(1.0, float(md.get("chase_kill_scale", 12.0)))
	var dist_ratio: float = 0.0
	if run.max_distance > 0.01:
		dist_ratio = clampf(run.distance_traveled / run.max_distance, 0.0, 1.0)
	var kill_ratio: float = clampf(float(run.enemies_defeated) / kill_scale, 0.0, 1.0)
	var zone: float = 1.0 if run.boss_zone_reached or run.boss_spawned else 0.0
	var loot_w: float = float(md.get("chase_w_loot", 0.0))
	var loot_ratio: float = 0.0
	if loot_w > 0.001 and GameManager:
		var threshold: float = maxf(1.0, float(AutoRetreatService.get_value_threshold(run)))
		loot_ratio = clampf(float(CarryValueService.compute(run, false)) / threshold, 0.0, 1.0)
	var raw: float = dist_w * dist_ratio + kill_w * kill_ratio + zone_w * zone + loot_w * loot_ratio
	return clampf(raw, 0.0, 1.0)


static func should_start_chase(run: WorldRun) -> bool:
	if run == null or bool(run.map_data.get("disable_boss_chase", false)):
		return false
	if not run.boss_spawned and not run.boss_zone_reached:
		return false
	var pressure: float = compute_pressure(run)
	var min_p: float = float(run.map_data.get("chase_pressure_min", 0.18))
	return pressure >= min_p


static func get_chase_speed_mult(run: WorldRun) -> float:
	var p: float = run.chase_pressure if run else 0.5
	var base: float = float(run.map_data.get("chase_speed_pressure_mult", 0.55))
	return base + p * (1.0 - base) * 1.8


static func get_catch_cooldown_mult(run: WorldRun) -> float:
	var p: float = run.chase_pressure if run else 0.5
	return clampf(1.35 - p * 0.55, 0.65, 1.35)


static func get_stability_penalty_mult(run: WorldRun) -> float:
	var p: float = run.chase_pressure if run else 0.5
	return 0.7 + p * 0.6


static func grant_repelled_rewards(run: WorldRun) -> Dictionary:
	if run == null:
		return {"exp": 0, "gold": 0}
	var md: Dictionary = run.map_data
	var base_exp: int = int(md.get("chase_repelled_exp", 28))
	var base_gold: int = int(md.get("chase_repelled_gold", 12))
	var mult: float = 1.0 + run.chase_pressure * 0.85
	var exp_gain: int = int(float(base_exp) * mult)
	var gold_gain: int = int(float(base_gold) * mult)
	run.total_exp_earned += exp_gain
	run.total_gold_earned += gold_gain
	run.chase_boss_repelled_count += 1
	run.chase_evade_eligible = true
	return {"exp": exp_gain, "gold": gold_gain}


static func can_counter_strike(run: WorldRun) -> bool:
	if run == null or not run.boss_chase_active or not run.is_retreating:
		return false
	if run.chase_combat_in_progress or bool(run.map_data.get("disable_chase_counter", false)):
		return false
	var gap: float = run.get_boss_chase_gap()
	if gap <= run.CHASE_CATCH_GAP:
		return false
	var max_gap: float = float(run.map_data.get("chase_counter_max_gap", run.CHASE_WARN_GAP))
	if gap > max_gap:
		return false
	return run._chase_counter_cooldown <= 0.01


static func try_counter_strike(run: WorldRun) -> Dictionary:
	if run == null:
		return {"ok": false, "reason": "no_run"}
	if not can_counter_strike(run):
		if run.chase_combat_in_progress:
			return {"ok": false, "reason": "in_combat"}
		if run._chase_counter_cooldown > 0.01:
			return {"ok": false, "reason": "cooldown", "remaining": run._chase_counter_cooldown}
		var gap: float = run.get_boss_chase_gap()
		if gap <= run.CHASE_CATCH_GAP:
			return {"ok": false, "reason": "too_close"}
		return {"ok": false, "reason": "unavailable"}
	var md: Dictionary = run.map_data
	var st_cost: int = int(md.get("chase_counter_stability_cost", 8))
	st_cost = int(ceilf(float(st_cost) * (0.75 + run.chase_pressure * 0.35)))
	if run.stability != null and run.stability.team_stability < st_cost + 5:
		return {"ok": false, "reason": "low_stability", "cost": st_cost}
	if run.stability != null:
		run.stability.modify_team_stability(-st_cost)
	var push_mult: float = float(md.get("chase_counter_push_mult", 1.55))
	var rewards: Dictionary = run.on_chase_boss_repelled(push_mult)
	var cd: float = float(md.get("chase_counter_cooldown", 16.0))
	cd /= get_catch_cooldown_mult(run)
	run._chase_counter_cooldown = cd
	run.chase_counter_uses += 1
	return {
		"ok": true,
		"stability_cost": st_cost,
		"push_mult": push_mult,
		"exp": rewards.get("exp", 0),
		"gold": rewards.get("gold", 0),
		"gap": run.get_boss_chase_gap(),
	}


static func tick_counter_cooldown(run: WorldRun, delta: float) -> void:
	if run == null or run._chase_counter_cooldown <= 0.0:
		return
	run._chase_counter_cooldown = maxf(0.0, run._chase_counter_cooldown - delta)


static func can_deep_counter_strike(run: WorldRun) -> bool:
	if run == null or not run.chase_combat_in_progress:
		return false
	if bool(run.map_data.get("disable_chase_deep_counter", false)):
		return false
	if run._chase_deep_counter_cooldown > 0.01:
		return false
	var min_charge: float = float(run.map_data.get("chase_deep_counter_min_charge", 0.22))
	if run.chase_stagger_charge < min_charge:
		return false
	var st_cost: int = _deep_counter_stability_cost(run)
	return run.stability == null or run.stability.team_stability >= st_cost + 5


static func try_deep_counter_strike(run: WorldRun, combat: CombatController) -> Dictionary:
	if run == null or combat == null:
		return {"ok": false, "reason": "no_combat"}
	if not can_deep_counter_strike(run):
		if run._chase_deep_counter_cooldown > 0.01:
			return {"ok": false, "reason": "cooldown", "remaining": run._chase_deep_counter_cooldown}
		if run.chase_stagger_charge < float(run.map_data.get("chase_deep_counter_min_charge", 0.22)):
			return {"ok": false, "reason": "low_charge", "charge": run.chase_stagger_charge}
		return {"ok": false, "reason": "unavailable"}
	var boss: CombatEntity = _find_chase_boss_entity(run, combat)
	if boss == null:
		return {"ok": false, "reason": "no_boss"}
	var md: Dictionary = run.map_data
	var st_cost: int = _deep_counter_stability_cost(run)
	if run.stability != null:
		run.stability.modify_team_stability(-st_cost)
	var dmg_ratio: float = float(md.get("chase_deep_counter_damage_ratio", 0.22))
	dmg_ratio *= 1.0 + run.chase_pressure * 0.25
	var raw_dmg: int = maxi(1, int(float(boss.max_hp) * dmg_ratio))
	var floor_ratio: float = float(md.get("chase_deep_counter_hp_floor", 0.12))
	var min_hp: int = maxi(1, int(float(boss.max_hp) * floor_ratio))
	boss.current_hp = maxi(min_hp, boss.current_hp - raw_dmg)
	if boss.current_hp <= 0:
		boss.current_hp = min_hp
	if boss.action_state == CombatEntity.ActionState.DEAD:
		boss.action_state = CombatEntity.ActionState.IDLE
	var push_mult: float = float(md.get("chase_deep_counter_push_mult", 1.65))
	var cd: float = float(md.get("chase_deep_counter_cooldown", 22.0))
	cd /= get_catch_cooldown_mult(run)
	run._chase_deep_counter_cooldown = cd
	run.chase_deep_counter_uses += 1
	run.chase_stagger_charge = 0.0
	return {
		"ok": true,
		"damage": raw_dmg,
		"stability_cost": st_cost,
		"push_mult": push_mult,
	}


static func tick_deep_counter_cooldown(run: WorldRun, delta: float) -> void:
	if run == null or run._chase_deep_counter_cooldown <= 0.0:
		return
	run._chase_deep_counter_cooldown = maxf(0.0, run._chase_deep_counter_cooldown - delta)


static func _deep_counter_stability_cost(run: WorldRun) -> int:
	var md: Dictionary = run.map_data
	var base: int = int(md.get("chase_deep_counter_stability_cost", 14))
	return int(ceilf(float(base) * (0.8 + run.chase_pressure * 0.4)))


static func _find_chase_boss_entity(run: WorldRun, combat: CombatController = null) -> CombatEntity:
	if combat != null:
		for e in combat.enemies:
			if e.is_chase_encounter and not e.is_dead():
				return e
		for e in combat.enemies:
			if e.is_boss and not e.is_dead():
				return e
	return null


static func grant_evade_bonus(run: WorldRun) -> Dictionary:
	if run == null or not run.chase_evade_eligible or run.boss_defeated:
		return {"exp": 0}
	if run.chase_boss_repelled_count <= 0:
		return {"exp": 0}
	var base: int = int(run.map_data.get("chase_evade_exp", 40))
	var exp_gain: int = int(float(base) * (1.0 + run.chase_pressure * 0.5))
	run.total_exp_earned += exp_gain
	run.chase_evade_eligible = false
	return {"exp": exp_gain}
