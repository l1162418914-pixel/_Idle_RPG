class_name ReturnScrollService
extends RefCounted
## B-7 回城卷轴 — 回收短 Run 失败发放；读条一键减价（绑批 MIA）


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("return_scroll", {})


static func normalize_meta(gm: GameManager) -> Array:
	if gm == null:
		return []
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	if not gm.account_meta.has("return_scrolls"):
		gm.account_meta["return_scrolls"] = []
	return gm.account_meta["return_scrolls"]


static func count_for_merc(gm: GameManager, merc_id: String) -> int:
	var n := 0
	for raw in normalize_meta(gm):
		if not raw is Dictionary:
			continue
		var members: Array = raw.get("member_ids", [])
		if merc_id in members:
			n += 1
	return n


static func has_scroll_for_merc(gm: GameManager, merc_id: String) -> bool:
	return count_for_merc(gm, merc_id) > 0


static func grant_for_recovery_fail(gm: GameManager, result: Dictionary) -> void:
	if gm == null:
		return
	if str(result.get("settlement_tier", "")) != "recovery_fail":
		return
	var targets: Array = []
	for raw_id in result.get("recovery_target_ids", []):
		var mid: String = str(raw_id)
		var merc := gm.find_mercenary_by_id(mid)
		if merc != null and merc.is_mia:
			targets.append(mid)
	if targets.is_empty():
		return
	var map_id: String = str(result.get("map_id", ""))
	var run_id: String = _pool_run_id_for_merc(gm, str(targets[0]))
	var scrolls: Array = normalize_meta(gm)
	scrolls.append({
		"scroll_id": "scroll_%d_%s" % [Time.get_unix_time_from_system(), str(targets[0])],
		"member_ids": targets.duplicate(),
		"run_id": run_id,
		"map_id": map_id,
		"granted_at": Time.get_unix_time_from_system(),
	})
	gm.account_meta["return_scrolls"] = scrolls
	result["return_scroll_granted"] = true
	result["return_scroll_targets"] = targets.duplicate()


static func consume_for_merc(gm: GameManager, merc_id: String) -> bool:
	if gm == null or merc_id == "":
		return false
	var scrolls: Array = normalize_meta(gm)
	for i in range(scrolls.size()):
		if not scrolls[i] is Dictionary:
			continue
		var members: Array = scrolls[i].get("member_ids", [])
		if merc_id in members:
			scrolls.remove_at(i)
			gm.account_meta["return_scrolls"] = scrolls
			return true
	return false


static func _pool_run_id_for_merc(gm: GameManager, merc_id: String) -> String:
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	for raw in gm.account_meta.get("frozen_exp_pools", []):
		if not raw is Dictionary:
			continue
		var members: Array = raw.get("member_ids", [])
		if members.size() > 0 and merc_id in members:
			return str(raw.get("run_id", ""))
	return ""
