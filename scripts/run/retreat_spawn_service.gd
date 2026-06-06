class_name RetreatSpawnService
extends RefCounted
## 返程刷怪档位：正常稀疏 vs 追击/守卫加压


const TIER_SPARSE := "sparse"
const TIER_CHASE := "chase"


static func is_intense_chase(run: WorldRun) -> bool:
	if run == null or not run.is_retreating:
		return false
	return run.boss_chase_active or run.guard_chase_active


static func get_spawn_profile(run: WorldRun) -> Dictionary:
	if run == null:
		return _profile_defaults(true)
	if run.chase_combat_in_progress:
		return {"tier": "chase_boss", "label": "首领接战", "interval_mult": 9999.0, "pack": 0}
	if bool(run.map_data.get("disable_mob_spawns", false)):
		return {"tier": "none", "label": "仅首领", "interval_mult": 9999.0, "pack": 0}
	if is_intense_chase(run):
		var p: float = run.chase_pressure if run.boss_chase_active else 0.35
		var interval: float = float(run.map_data.get("chase_spawn_interval_mult", 0.5))
		interval *= clampf(1.0 - p * 0.35, 0.55, 1.0)
		var pack: int = maxi(1, int(run.map_data.get("chase_spawn_pack", 3)))
		if run.boss_chase_active:
			pack += int(floorf(p * 1.5))
		return {
			"tier": TIER_CHASE,
			"label": "追击加压",
			"interval_mult": interval,
			"pack": pack,
		}
	return {
		"tier": TIER_SPARSE,
		"label": "稀疏",
		"interval_mult": float(run.map_data.get("retreat_spawn_interval_mult", 1.15)),
		"pack": maxi(1, int(run.map_data.get("retreat_spawn_pack", 1))),
	}


static func get_shield_damage_mult(run: WorldRun) -> float:
	if run == null or not is_intense_chase(run):
		return 1.0
	var mult: float = float(run.map_data.get("shield_damage_mult_chase", 1.3))
	if run.boss_chase_active:
		mult *= 1.0 + run.chase_pressure * 0.25
		var gap: float = run.get_boss_chase_gap()
		if gap <= run.CHASE_DANGER_GAP:
			mult *= 1.15
		if gap <= run.CHASE_CATCH_GAP:
			mult *= 1.1
	return mult


static func should_activate_guard_chase(run: WorldRun, reason: String) -> bool:
	if run == null or bool(run.map_data.get("disable_guard_chase", false)):
		return false
	if reason not in ["combat_fail", "emergency"]:
		return false
	return run.has_active_extract_line()


static func tick_spawns(run: WorldRun, delta: float) -> Array:
	var events: Array = []
	var profile: Dictionary = get_spawn_profile(run)
	run.retreat_spawn_tier = str(profile.get("tier", ""))
	var pack: int = int(profile.get("pack", 0))
	if pack <= 0:
		return events
	run.spawn_timer += delta
	var retreat_mult: float = float(profile.get("interval_mult", 1.15))
	var interval: float = run.spawn_interval * retreat_mult * run.get_spawn_jitter(0.75, 1.05)
	if run.spawn_timer < interval:
		return events
	run.spawn_timer = 0.0
	for _pack_i in range(pack):
		var enemy_data: Dictionary = run.spawn_random_enemy()
		var ev: Dictionary = run.emit_enemy_spawn_event(enemy_data)
		if ev.is_empty():
			break
		events.append(ev)
	return events


static func opening_ambush_count(run: WorldRun) -> int:
	if bool(run.map_data.get("disable_mob_spawns", false)):
		return 0
	var base: int = maxi(0, int(run.map_data.get("retreat_start_ambush", 1)))
	if is_intense_chase(run):
		return base + maxi(0, int(run.map_data.get("chase_start_ambush_extra", 1)))
	return base


static func _profile_defaults(sparse: bool) -> Dictionary:
	if sparse:
		return {"tier": TIER_SPARSE, "label": "稀疏", "interval_mult": 1.15, "pack": 1}
	return {"tier": TIER_CHASE, "label": "追击加压", "interval_mult": 0.5, "pack": 3}
