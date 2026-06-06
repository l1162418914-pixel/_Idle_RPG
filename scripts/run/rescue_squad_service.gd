class_name RescueSquadService
extends RefCounted
## 第三队 `rescue_squad` 编制（与 A/B 半组并列）


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("rescue", {})


static func max_active() -> int:
	return int(config().get("max_active", 3))


static func min_active() -> int:
	return int(config().get("min_active", 1))


static func can_assign(merc: Mercenary) -> bool:
	if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
		return false
	if merc.is_mia or merc.is_morgue_pending or not merc.is_alive:
		return false
	if merc.is_on_rescue_injury_cd():
		return false
	return merc.can_join_squad()


static func rebuild_from_roster(gm: GameManager) -> void:
	if gm == null:
		return
	gm.rescue_squad = SaveSerializer.normalize_rescue_squad(gm.rescue_squad)
	var kept: Array[String] = []
	for raw_id in gm.rescue_squad.get("active", []):
		var merc := gm.find_mercenary_by_id(str(raw_id))
		if merc != null and can_assign(merc):
			kept.append(merc.merc_id)
	if kept.size() >= min_active():
		gm.rescue_squad["active"] = kept
		return
	for merc in gm._all_roster_mercs():
		if merc == null or merc.merc_id in kept:
			continue
		if not can_assign(merc):
			continue
		kept.append(merc.merc_id)
		if kept.size() >= max_active():
			break
	gm.rescue_squad["active"] = kept


static func resolve_deploy_squad(gm: GameManager) -> Array[Mercenary]:
	var out: Array[Mercenary] = []
	if gm == null:
		return out
	rebuild_from_roster(gm)
	for raw_id in gm.rescue_squad.get("active", []):
		var merc := gm.find_mercenary_by_id(str(raw_id))
		if merc != null and can_assign(merc):
			out.append(merc)
	return out
