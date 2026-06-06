class_name MarchSearchService
extends RefCounted
## T-MARCH-M1 · 行军自动搜索（背景检定，接战时由 RunDriver 暂停 tick）


const DEFAULT_INTERVAL_M: float = 12.0


static func tick(run: WorldRun, allowed: bool) -> Array:
	var out: Array = []
	if not allowed or run == null or not run.is_active:
		return out
	if run.chase_combat_in_progress:
		return out
	var cfg: Dictionary = run.map_data.get("march_search", {})
	if cfg.is_empty():
		return out
	var interval: float = float(cfg.get("interval_m", DEFAULT_INTERVAL_M))
	if interval <= 0.0:
		return out
	var pool_id: String = str(cfg.get("pool_id", "grassland_search"))
	var pool: Dictionary = _pool(pool_id)
	if pool.is_empty():
		return out
	var dist: float = run.distance_traveled
	while dist - run.march_search_last_anchor >= interval - 0.001:
		run.march_search_last_anchor += interval
		var payload: Dictionary = _resolve_hit(run, cfg, pool)
		if not payload.is_empty():
			out.append(payload)
	return out


static func _resolve_hit(run: WorldRun, cfg: Dictionary, pool: Dictionary) -> Dictionary:
	if pool.is_empty():
		return {}
	var pool_id: String = str(cfg.get("pool_id", "grassland_search"))
	var entry: Dictionary = _pick_entry(pool, run.is_retreating, run._rng)
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
			var mat: RunMaterial = RunMaterial.roll_for_map(run.map_data, fake_enemy)
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


static func _pool(pool_id: String) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var dl = tree.root.get_node_or_null("/root/DataLoader")
		if dl != null and dl.has_method("march_search_pool"):
			return dl.march_search_pool(pool_id)
	return {}


static func _pick_entry(pool: Dictionary, retreating: bool, rng: RandomNumberGenerator) -> Dictionary:
	var entries: Array = pool.get("entries", [])
	if entries.is_empty():
		return {}
	var negative_mult: float = 1.0
	if retreating:
		negative_mult = float(pool.get("retreat_negative_mult", 1.0))
	var total: float = 0.0
	for e in entries:
		if e is Dictionary:
			var w: float = float(e.get("weight", 0))
			if retreating and int(e.get("team_delta", 0)) < 0:
				w *= negative_mult
			total += w
	if total <= 0.0:
		return {}
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for e in entries:
		if e is not Dictionary:
			continue
		var w: float = float(e.get("weight", 0))
		if retreating and int(e.get("team_delta", 0)) < 0:
			w *= negative_mult
		acc += w
		if roll <= acc:
			return e
	return entries[entries.size() - 1]
