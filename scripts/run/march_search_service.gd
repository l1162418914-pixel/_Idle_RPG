class_name MarchSearchService
extends RefCounted
## T-MARCH-M1/M3 · 行军自动搜索（返程分池 + 稳定加权 + 盾破禁正面物资）

const _PATH_RUN_MATERIAL := "res://scripts/inventory/run_material.gd"
const DEFAULT_INTERVAL_M: float = 12.0
const DEFAULT_LOW_STABILITY_THRESHOLD: int = 50


static func tick(run, allowed: bool) -> Array:
	var out: Array = []
	if not allowed or run == null or not run.is_active:
		return out
	if run.chase_combat_in_progress:
		return out
	var cfg: Dictionary = run.map_data.get("march_search", {})
	if cfg.is_empty():
		return out
	var interval: float = float(cfg.get("interval_m", DEFAULT_INTERVAL_M))
	interval *= float(run.expedition_search_interval_mult)
	if interval <= 0.0:
		return out
	var pool_id: String = resolve_pool_id(cfg, run.is_retreating)
	var pool: Dictionary = _pool(pool_id)
	if pool.is_empty():
		return out
	var dist: float = run.distance_traveled
	while dist - run.march_search_last_anchor >= interval - 0.001:
		run.march_search_last_anchor += interval
		var payload: Dictionary = _resolve_hit(run, cfg, pool, pool_id)
		if not payload.is_empty():
			out.append(payload)
	return out


static func resolve_pool_id(cfg: Dictionary, retreating: bool) -> String:
	if retreating:
		var retreat_id: String = str(cfg.get("retreat_pool_id", ""))
		if retreat_id != "":
			return retreat_id
	return str(cfg.get("pool_id", "grassland_search"))


static func entry_weight(entry: Dictionary, pool: Dictionary, ctx: Dictionary, cfg: Dictionary = {}) -> float:
	if entry.is_empty():
		return 0.0
	var result_type: String = str(entry.get("result", "empty"))
	if bool(ctx.get("shields_depleted", false)) and _is_positive_result(result_type, entry):
		return 0.0
	var w: float = float(entry.get("weight", 0))
	if w <= 0.0:
		return 0.0
	var team_delta: int = int(entry.get("team_delta", 0))
	if bool(ctx.get("retreating", false)) and team_delta < 0:
		w *= float(pool.get("retreat_negative_mult", 1.0))
	var team_stability: int = int(ctx.get("team_stability", 100))
	var threshold: int = int(
		cfg.get("low_stability_threshold", pool.get("low_stability_threshold", DEFAULT_LOW_STABILITY_THRESHOLD))
	)
	if team_stability <= threshold:
		if team_delta < 0 or result_type == "empty":
			w *= float(pool.get("low_stability_negative_mult", 1.0))
		elif _is_positive_result(result_type, entry):
			w *= float(pool.get("low_stability_positive_mult", 1.0))
	return w


static func pool_negative_weight_share(pool: Dictionary, ctx: Dictionary, cfg: Dictionary = {}) -> float:
	var entries: Array = pool.get("entries", [])
	if entries.is_empty():
		return 0.0
	var neg: float = 0.0
	var total: float = 0.0
	for e in entries:
		if not e is Dictionary:
			continue
		var w: float = entry_weight(e, pool, ctx, cfg)
		total += w
		if _is_negative_entry(e):
			neg += w
	if total <= 0.0:
		return 0.0
	return neg / total


static func _resolve_hit(
	run, cfg: Dictionary, pool: Dictionary, pool_id: String
) -> Dictionary:
	if pool.is_empty():
		return {}
	var ctx: Dictionary = _search_context(run)
	var entry: Dictionary = _pick_entry(pool, ctx, cfg, run._rng)
	if entry.is_empty():
		return {}
	var result_type: String = str(entry.get("result", "empty"))
	var log: String = str(entry.get("log", "搜索检定。"))
	var data: Dictionary = {
		"pool_id": pool_id,
		"result": result_type,
		"log": log,
		"distance": run.distance_traveled,
		"retreating": run.is_retreating,
		"team_stability": int(ctx.get("team_stability", 100)),
		"shields_depleted": bool(ctx.get("shields_depleted", false)),
	}
	match result_type:
		"empty":
			pass
		"gold":
			var gmin: int = int(entry.get("gold_min", 1))
			var gmax: int = int(entry.get("gold_max", gmin))
			var gold: int = run._rng.randi_range(mini(gmin, gmax), maxi(gmin, gmax))
			run.total_gold_earned += gold
			data["gold"] = gold
		"material":
			var fake_enemy: Dictionary = {"level": 1}
			var mat = load(_PATH_RUN_MATERIAL).roll_for_map(run.map_data, fake_enemy)
			if mat != null:
				run._add_run_material(mat)
				data["material_name"] = mat.item_name
				data["material_value"] = mat.material_value
			else:
				data["result"] = "empty"
				data["log"] = "路旁无可用物资。"
		"stability":
			var delta: int = int(entry.get("team_delta", 0))
			if run.stability != null and delta != 0:
				run.stability.modify_team_stability(delta)
			data["team_delta"] = delta
		_:
			data["result"] = "empty"
	return {
		"event_name": "march_search_hit",
		"data": data,
	}


static func _search_context(run) -> Dictionary:
	var team_stability: int = 100
	if run.stability != null:
		team_stability = run.stability.team_stability
	return {
		"retreating": run.is_retreating,
		"team_stability": team_stability,
		"shields_depleted": _shields_depleted(run),
	}


static func _shields_depleted(run) -> bool:
	if not run.is_retreating:
		return false
	return (
		run.retreat_shield_current <= 0
		and run.equip_shield_current <= 0
		and run.material_shield_current <= 0
	)


static func _is_positive_result(result_type: String, entry: Dictionary) -> bool:
	match result_type:
		"gold", "material":
			return true
		"stability":
			return int(entry.get("team_delta", 0)) > 0
		_:
			return false


static func _is_negative_entry(entry: Dictionary) -> bool:
	var result_type: String = str(entry.get("result", "empty"))
	if result_type == "stability":
		return int(entry.get("team_delta", 0)) < 0
	if result_type == "empty":
		return true
	return false


static func _pick_entry(
	pool: Dictionary,
	ctx: Dictionary,
	cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var entries: Array = pool.get("entries", [])
	if entries.is_empty():
		return {}
	var total: float = 0.0
	for e in entries:
		if e is Dictionary:
			total += entry_weight(e, pool, ctx, cfg)
	if total <= 0.0:
		return {}
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for e in entries:
		if not e is Dictionary:
			continue
		var w: float = entry_weight(e, pool, ctx, cfg)
		acc += w
		if roll <= acc:
			return e
	return entries[entries.size() - 1]


static func _pool(pool_id: String) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var dl = tree.root.get_node_or_null("/root/DataLoader")
		if dl != null and dl.has_method("march_search_pool"):
			return dl.march_search_pool(pool_id)
	return {}


