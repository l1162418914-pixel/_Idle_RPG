class_name MorgueService
extends RefCounted
## 停尸间（B-12b）：救援队运回尸体，待医疗复活


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("rescue", {})


static func is_rescue_unlocked(gm: GameManager) -> bool:
	if gm == null:
		return false
	return gm.get_building_level("rescue_station") >= 1


static func sync_rescue_unlock_meta(gm: GameManager) -> void:
	if gm == null:
		return
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	gm.account_meta["rescue_unlocked"] = is_rescue_unlocked(gm)


static func migrate_legacy_rescue_unlock(gm: GameManager) -> void:
	if gm == null:
		return
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	if not bool(gm.account_meta.get("rescue_unlocked", false)):
		return
	if is_rescue_unlocked(gm):
		return
	if not gm.buildings.has("rescue_station"):
		gm.buildings["rescue_station"] = {"level": 1, "building_id": "rescue_station"}
	else:
		gm.buildings["rescue_station"]["level"] = maxi(1, int(gm.buildings["rescue_station"].get("level", 0)))
	sync_rescue_unlock_meta(gm)


static func normalize_queue(gm: GameManager) -> Array:
	if gm == null:
		return []
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	if not gm.account_meta.has("morgue_queue"):
		gm.account_meta["morgue_queue"] = []
	return gm.account_meta["morgue_queue"]


static func admit_corpse(gm: GameManager, merc_id: String, map_id: String) -> void:
	if gm == null or merc_id == "":
		return
	var merc := gm.find_mercenary_by_id(merc_id)
	if merc == null:
		return
	merc.clear_mia_state()
	merc.enter_morgue_pending()
	gm._prune_frozen_exp_for_merc(merc_id)
	_clear_map_point_for_merc(gm, merc_id)
	var queue: Array = normalize_queue(gm)
	for raw in queue:
		if raw is Dictionary and str(raw.get("merc_id", "")) == merc_id:
			return
	queue.append({
		"merc_id": merc_id,
		"map_id": map_id,
		"arrived_at": Time.get_unix_time_from_system(),
	})
	gm.account_meta["morgue_queue"] = queue


static func _clear_map_point_for_merc(gm: GameManager, merc_id: String) -> void:
	var pools: Array = gm.account_meta.get("frozen_exp_pools", [])
	var kept: Array = []
	for raw in pools:
		if not raw is Dictionary:
			continue
		var p: Dictionary = MiaDeteriorationService.normalize_pool(raw.duplicate(true))
		var members: Array = p.get("member_ids", [])
		if members.size() > 0 and merc_id in members:
			members.erase(merc_id)
			if members.is_empty():
				continue
			p["member_ids"] = members
			p["mia_count"] = members.size()
			p["map_point_visible"] = false
			kept.append(p)
		else:
			kept.append(p)
	gm.account_meta["frozen_exp_pools"] = kept


static func remove_corpse(gm: GameManager, merc_id: String) -> void:
	var queue: Array = normalize_queue(gm)
	var kept: Array = []
	for raw in queue:
		if raw is Dictionary and str(raw.get("merc_id", "")) == merc_id:
			continue
		kept.append(raw)
	gm.account_meta["morgue_queue"] = kept


static func get_entries(gm: GameManager) -> Array:
	var out: Array = []
	if gm == null:
		return out
	for raw in normalize_queue(gm):
		if not raw is Dictionary:
			continue
		var mid: String = str(raw.get("merc_id", ""))
		var merc := gm.find_mercenary_by_id(mid)
		if merc == null or not merc.is_morgue_pending:
			continue
		var md: Dictionary = DataLoader.map_data(str(raw.get("map_id", "")))
		out.append({
			"merc": merc,
			"merc_id": mid,
			"map_id": str(raw.get("map_id", "")),
			"map_name": str(md.get("name", raw.get("map_id", ""))),
			"arrived_at": int(raw.get("arrived_at", 0)),
		})
	return out


static func medical_revive_cost(merc: Mercenary) -> int:
	var base: int = int(config().get("medical_revive_base_gold", 120))
	if merc == null:
		return base
	return base + merc.level * int(config().get("medical_revive_per_level", 8))


static func grant_rescue_progress(gm: GameManager, result: Dictionary) -> void:
	if gm == null:
		return
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	var rep_gain: int = int(config().get("reputation_per_success", 12))
	var exp_bonus: int = int(config().get("bonus_exp_per_member", 40))
	gm.account_meta["rescue_reputation"] = int(gm.account_meta.get("rescue_reputation", 0)) + rep_gain
	var rank: int = int(gm.account_meta.get("rescue_rank", 0))
	var rep: int = int(gm.account_meta.get("rescue_reputation", 0))
	var next_rank_rep: int = int(config().get("rank_rep_step", 50))
	while rep >= (rank + 1) * next_rank_rep:
		rank += 1
	gm.account_meta["rescue_rank"] = rank
	result["rescue_reputation_gain"] = rep_gain
	result["rescue_rank"] = rank
	result["rescue_bonus_exp"] = 0
	for mid in result.get("squad_member_ids", []):
		var merc := gm.find_mercenary_by_id(str(mid))
		if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		if exp_bonus > 0:
			merc.add_exp(exp_bonus)
			result["rescue_bonus_exp"] = int(result.get("rescue_bonus_exp", 0)) + exp_bonus


static func apply_failure_injury_cd(gm: GameManager, result: Dictionary) -> void:
	if gm == null:
		return
	var sec: int = int(config().get("injury_cd_sec", 180))
	for mid in result.get("squad_member_ids", []):
		var merc := gm.find_mercenary_by_id(str(mid))
		if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		if TestScenarioService.test_merc_blocks_casualties(merc):
			continue
		merc.apply_rescue_injury_cd(sec)
