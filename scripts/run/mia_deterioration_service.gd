class_name MiaDeteriorationService
extends RefCounted
## B-11 拖捞恶化：过补给点后未捞计趟；2 趟后地图回收点消失（主城大价值复活仍可用）


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("mia_deterioration", {})


static func max_skipped_runs() -> int:
	return int(config().get("max_skipped_runs", 2))


static func normalize_pool(pool: Dictionary) -> Dictionary:
	var p: Dictionary = pool.duplicate(true)
	if not p.has("skipped_runs"):
		p["skipped_runs"] = 0
	if not p.has("map_point_visible"):
		p["map_point_visible"] = true
	return p


static func enrich_new_pool(pool: Dictionary) -> Dictionary:
	var p: Dictionary = normalize_pool(pool)
	p["skipped_runs"] = 0
	p["map_point_visible"] = true
	return p


static func supply_distance_for_map(map_data: Dictionary) -> float:
	if map_data.has("supply_distance"):
		return float(map_data.supply_distance)
	if map_data.has("extract_distance"):
		return float(map_data.extract_distance) * 0.5
	var max_d: float = float(map_data.get("boss_distance", map_data.get("max_distance", 300.0)))
	return maxf(40.0, max_d * 0.35)


static func on_run_finished(
	gm: GameManager, result: Dictionary, pre_run_mia_ids: Array[String]
) -> void:
	if gm == null or pre_run_mia_ids.is_empty():
		return
	if not bool(result.get("supply_point_passed", false)):
		return
	var mode: int = int(result.get("run_mode", WorldRun.RunMode.NORMAL))
	if mode in [WorldRun.RunMode.RECOVERY, WorldRun.RunMode.RESCUE]:
		return
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	var pools: Array = gm.account_meta.get("frozen_exp_pools", [])
	var cap: int = max_skipped_runs()
	var changed := false
	for i in range(pools.size()):
		if not pools[i] is Dictionary:
			continue
		var p: Dictionary = normalize_pool(pools[i])
		var members: Array = p.get("member_ids", [])
		var waiting := false
		for raw_id in members:
			var mid: String = str(raw_id)
			if mid not in pre_run_mia_ids:
				continue
			var merc := gm.find_mercenary_by_id(mid)
			if merc != null and merc.is_mia:
				waiting = true
				break
		if not waiting:
			pools[i] = p
			continue
		p["skipped_runs"] = int(p.get("skipped_runs", 0)) + 1
		if int(p["skipped_runs"]) >= cap:
			p["map_point_visible"] = false
		pools[i] = p
		changed = true
	if changed:
		gm.account_meta["frozen_exp_pools"] = pools


static func get_skipped_runs_for_merc(gm: GameManager, merc_id: String) -> int:
	if gm == null or merc_id == "":
		return 0
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	var best := 0
	for raw in gm.account_meta.get("frozen_exp_pools", []):
		if not raw is Dictionary:
			continue
		var p: Dictionary = normalize_pool(raw)
		var members: Array = p.get("member_ids", [])
		if members.size() > 0 and merc_id not in members:
			continue
		best = maxi(best, int(p.get("skipped_runs", 0)))
	return best


static func is_map_recovery_available(gm: GameManager, merc_id: String) -> bool:
	if gm == null or merc_id == "":
		return false
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	for raw in gm.account_meta.get("frozen_exp_pools", []):
		if not raw is Dictionary:
			continue
		var p: Dictionary = normalize_pool(raw)
		var members: Array = p.get("member_ids", [])
		if members.size() > 0:
			if merc_id in members:
				return bool(p.get("map_point_visible", true))
		elif int(p.get("mia_count", 0)) > 0 and gm.find_mercenary_by_id(merc_id) != null:
			return bool(p.get("map_point_visible", true))
	return true


static func recovery_unfreeze_ratio(gm: GameManager, merc_id: String) -> float:
	var base: float = RecoveryRunService.UNFREEZE_RATIO
	var skips: int = get_skipped_runs_for_merc(gm, merc_id)
	var cfg: Dictionary = config()
	if skips <= 0:
		return base
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if skips == 1:
		var lo: float = float(cfg.get("tier1_ratio_min", 0.5))
		var hi: float = float(cfg.get("tier1_ratio_max", 0.7))
		return base * rng.randf_range(lo, hi)
	var lo2: float = float(cfg.get("tier2_ratio_min", 0.2))
	var hi2: float = float(cfg.get("tier2_ratio_max", 0.3))
	return base * rng.randf_range(lo2, hi2)
