class_name MutualRecoveryService
extends RefCounted
## B-10 双半组互捞 — 另一队出征时默认短程 RECOVERY 捞遗留（可跳过改打正常远征）


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("mutual_recovery", {})


static func is_auto_enabled(gm: GameManager) -> bool:
	if gm == null:
		return false
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	return bool(gm.account_meta.get("mutual_recovery_auto", true))


static func set_auto_enabled(gm: GameManager, enabled: bool) -> void:
	if gm == null:
		return
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	gm.account_meta["mutual_recovery_auto"] = enabled


static func on_mia_settlement(gm: GameManager, result: Dictionary) -> void:
	if gm == null:
		return
	var mia_n: int = int(result.get("mia_count", 0))
	if mia_n <= 0 and str(result.get("settlement_tier", "")) != "mia":
		return
	if mia_n <= 0:
		mia_n = _count_mia_in_result(gm, result)
	if mia_n <= 0:
		return
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	gm.account_meta["mia_last_deploy_half"] = str(gm.last_deploy_half)


static func list_recoverable_targets(gm: GameManager) -> Array[String]:
	var out: Array[String] = []
	if gm == null:
		return out
	for merc in gm._all_roster_mercs():
		if merc == null or not merc.is_mia or merc.is_morgue_pending:
			continue
		if merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		if not MiaDeteriorationService.is_map_recovery_available(gm, merc.merc_id):
			continue
		out.append(merc.merc_id)
	return out


static func pick_target(gm: GameManager, deploy_half: String) -> String:
	var candidates: Array[String] = list_recoverable_targets(gm)
	if candidates.is_empty():
		return ""
	var last_half: String = str(
		SaveSerializer.normalize_account_meta(gm.account_meta).get("mia_last_deploy_half", "")
	)
	if last_half != "" and deploy_half != last_half:
		return candidates[0]
	for mid in candidates:
		return mid
	return ""


static func describe_pending(gm: GameManager, deploy_half: String) -> String:
	var target_id: String = pick_target(gm, deploy_half)
	if target_id == "":
		return ""
	var merc := gm.find_mercenary_by_id(target_id)
	if merc == null:
		return ""
	var last_half: String = str(
		SaveSerializer.normalize_account_meta(gm.account_meta).get("mia_last_deploy_half", "")
	)
	if last_half != "" and deploy_half != last_half:
		return "互捞：%s 半组出征将默认回收 %s" % [deploy_half, merc.merc_name]
	return "将默认回收遗留 %s" % merc.merc_name


static func _count_mia_in_result(gm: GameManager, result: Dictionary) -> int:
	var n := 0
	for mid in result.get("squad_member_ids", []):
		var merc := gm.find_mercenary_by_id(str(mid))
		if merc != null and merc.is_mia:
			n += 1
	return n
