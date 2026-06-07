class_name SaveSerializer
extends RefCounted
## 存档序列化 — to_save_dict / from_save_dict（从 GameManager 迁出，字段与 SAVE_FORMAT 一致）


static func default_account_meta() -> Dictionary:
	return {
		"frozen_exp_pools": [],
		"morgue_queue": [],
		"return_scrolls": [],
		"mutual_recovery_auto": true,
		"mia_last_deploy_half": "",
		"rescue_unlocked": false,
		"rescue_rank": 0,
		"rescue_reputation": 0,
	}


static func default_rescue_squad() -> Dictionary:
	return {
		"active": [],
		"bench": [],
	}


static func to_save_dict(gm: GameManager) -> Dictionary:
	return {
		"gold": gm.gold,
		"rebirth_count": gm.rebirth_count,
		"rebirth_bonus": gm.rebirth_bonus,
		"unlocked_maps": gm.unlocked_maps.duplicate(),
		"defeated_map_bosses": gm.defeated_map_bosses.duplicate(),
		"auto_run_preferred": gm.auto_run_preferred,
		"auto_retreat_value_enabled": gm.auto_retreat_value_enabled,
		"auto_retreat_safe_only": gm.auto_retreat_safe_only,
		"expedition_priority": gm.expedition_priority,
		"loot_auto_evict_low_value": gm.loot_auto_evict_low_value,
		"loot_discard_overflow": gm.loot_discard_overflow,
		"team_stability": gm.team_stability,
		"squad_stability": gm.team_stability,
		"buildings": gm.buildings.duplicate(),
		"player": serialize_merc(gm.player),
		"roster": {
			"elite": serialize_merc_array(gm.elite_roster),
			"normal": serialize_merc_array(gm.normal_roster),
		},
		"inventory": gm.inventory.to_dict_array(),
		"squad_formation": gm.squad_formation.duplicate(true),
		"last_deploy_half": gm.last_deploy_half,
		"last_run_squad_snapshot": gm.last_run_squad_snapshot.duplicate(),
		"selected_map_id": gm.selected_map_id,
		"account_meta": normalize_account_meta(gm.account_meta).duplicate(true),
		"rescue_squad": normalize_rescue_squad(gm.rescue_squad).duplicate(true),
		"cloud_reserved": {},
	}


static func from_save_dict(gm: GameManager, data: Dictionary) -> void:
	gm.gold = data.get("gold", 1000)
	gm.rebirth_count = data.get("rebirth_count", 0)
	gm.rebirth_bonus = data.get("rebirth_bonus", 0.0)
	gm.unlocked_maps.assign(data.get("unlocked_maps", ["grassland"]))
	gm.defeated_map_bosses.assign(data.get("defeated_map_bosses", []))
	gm.auto_run_preferred = data.get("auto_run_preferred", false)
	gm.auto_retreat_value_enabled = data.get("auto_retreat_value_enabled", true)
	gm.auto_retreat_safe_only = data.get("auto_retreat_safe_only", false)
	var pri: String = str(data.get("expedition_priority", GameManager.EXPEDITION_PRIORITY_MARCH))
	if pri in [
		GameManager.EXPEDITION_PRIORITY_PUSH,
		GameManager.EXPEDITION_PRIORITY_MARCH,
		GameManager.EXPEDITION_PRIORITY_LOOT,
	]:
		gm.expedition_priority = pri
	else:
		gm.expedition_priority = GameManager.EXPEDITION_PRIORITY_MARCH
	gm.loot_auto_evict_low_value = data.get("loot_auto_evict_low_value", true)
	gm.loot_discard_overflow = data.get("loot_discard_overflow", false)
	gm.auto_run_enabled = false
	var loaded_team: int = data.get("team_stability", data.get("squad_stability", StabilitySystem.MAX_STABILITY))
	gm.team_stability = clampi(loaded_team, 0, StabilitySystem.MAX_STABILITY)
	gm.sync_always_unlocked_maps()
	gm.refresh_map_unlocks()
	gm.buildings = data.get("buildings", {})

	var pdata = data.get("player", {})
	if not pdata.is_empty():
		gm.player = deserialize_player(pdata)

	var roster = data.get("roster", {})
	gm.elite_roster.clear()
	for edata in roster.get("elite", []):
		var m = deserialize_elite(edata)
		if m:
			gm.elite_roster.append(m)
	gm.normal_roster.clear()
	for ndata in roster.get("normal", []):
		var m = deserialize_normal(ndata)
		if m:
			gm.normal_roster.append(m)

	gm.inventory.from_dict_array(data.get("inventory", []))
	gm.squad_formation = data.get("squad_formation", {})
	gm.last_deploy_half = data.get("last_deploy_half", "A")
	gm.last_run_squad_snapshot.clear()
	for mid in data.get("last_run_squad_snapshot", []):
		gm.last_run_squad_snapshot.append(str(mid))
	gm.selected_map_id = str(data.get("selected_map_id", gm.selected_map_id))
	gm.account_meta = normalize_account_meta(data.get("account_meta", {}))
	gm.rescue_squad = normalize_rescue_squad(data.get("rescue_squad", {}))
	MorgueService.migrate_legacy_rescue_unlock(gm)
	MorgueService.sync_rescue_unlock_meta(gm)
	SquadFormationService.ensure_formation(gm)
	SquadFormationService.rebalance_from_roster(gm)

	gm.current_run = null
	gm.selected_squad.clear()
	gm._pending_run_result = {}
	gm._run_rewards_applied = false
	gm.state = GameManager.GameState.BASE
	gm.ensure_save_casualty_fixtures()


static func normalize_account_meta(raw: Variant) -> Dictionary:
	var meta: Dictionary = raw if raw is Dictionary else {}
	if not meta.has("frozen_exp_pools"):
		meta["frozen_exp_pools"] = []
	if not meta.has("morgue_queue"):
		meta["morgue_queue"] = []
	if not meta.has("return_scrolls"):
		meta["return_scrolls"] = []
	if not meta.has("mutual_recovery_auto"):
		meta["mutual_recovery_auto"] = true
	if not meta.has("mia_last_deploy_half"):
		meta["mia_last_deploy_half"] = ""
	if not meta.has("rescue_unlocked"):
		meta["rescue_unlocked"] = false
	if not meta.has("rescue_rank"):
		meta["rescue_rank"] = 0
	if not meta.has("rescue_reputation"):
		meta["rescue_reputation"] = 0
	return meta


static func normalize_rescue_squad(raw: Variant) -> Dictionary:
	var sq: Dictionary = raw if raw is Dictionary else {}
	if not sq.has("active"):
		sq["active"] = []
	if not sq.has("bench"):
		sq["bench"] = []
	return sq


static func serialize_merc(merc: Mercenary) -> Dictionary:
	if merc == null:
		return {}
	merc.refresh_base_stats()
	var out: Dictionary = {
		"merc_id": merc.merc_id,
		"merc_name": merc.merc_name,
		"merc_type": merc.merc_type,
		"merc_class": merc.merc_class,
		"level": merc.level,
		"exp": merc.exp,
		"max_level": merc.max_level,
		"current_hp": merc.current_hp,
		"is_alive": merc.is_alive,
		"is_mia": merc.is_mia,
		"is_morgue_pending": merc.is_morgue_pending,
		"rescue_injury_cd_until": merc.rescue_injury_cd_until,
		"is_near_death": merc.is_near_death,
		"scar_stacks": merc.scar_stacks,
		"is_retreated": merc.is_retreated,
		"is_personal_break": merc.is_personal_break,
		"personal_stability": merc.personal_stability,
		"attack_range": merc.attack_range,
		"attack_speed": merc.attack_speed,
		"equipment_slots": serialize_equipment_slots(merc.equipment_slots),
		"passive_skills": merc.passive_skills.duplicate(),
		"buffs": merc.buff_system.to_dict_array(),
		"active_skills": merc.active_skills.duplicate(),
		"growth_per_level": merc.growth_per_level.duplicate(),
		"template_id": merc.template_id,
		"player_extra": serialize_player_extra(merc),
	}
	if merc is EliteMercenary:
		out["is_dead_permanently"] = (merc as EliteMercenary).is_dead_permanently
	elif merc is NormalMercenary:
		out["is_dead_permanently"] = (merc as NormalMercenary).is_dead_permanently
	return out


static func serialize_player_extra(merc: Mercenary) -> Dictionary:
	if not (merc is Player):
		return {}
	var p = merc as Player
	return {
		"base_exp_multiplier": p.base_exp_multiplier,
		"squad_stability_influence": p.squad_stability_influence,
		"owned_elite_ids": extract_ids(p.owned_elite_roster),
		"owned_normal_ids": extract_ids(p.owned_normal_roster),
	}


static func extract_ids(list: Array) -> Array:
	var ids: Array = []
	for m in list:
		if m is Mercenary:
			ids.append(m.merc_id)
	return ids


static func serialize_equipment_slots(slots: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot in slots:
		var eq = slots[slot]
		if eq is Equipment:
			result[slot] = eq.to_dict()
		else:
			result[slot] = null
	return result


static func serialize_merc_array(list: Array) -> Array:
	var result: Array = []
	for m in list:
		if m is Mercenary:
			result.append(serialize_merc(m))
	return result


static func deserialize_player(data: Dictionary) -> Player:
	var p = Player.new()
	apply_merc_data(p, data)
	var extra = data.get("player_extra", {})
	if not extra.is_empty():
		p.base_exp_multiplier = extra.get("base_exp_multiplier", 0.25)
		p.squad_stability_influence = extra.get("squad_stability_influence", 0.0)
	return p


static func deserialize_elite(data: Dictionary) -> EliteMercenary:
	var m = EliteMercenary.new()
	apply_merc_data(m, data)
	m.is_dead_permanently = bool(data.get("is_dead_permanently", not m.is_alive))
	return m


static func deserialize_normal(data: Dictionary) -> NormalMercenary:
	var m = NormalMercenary.new()
	apply_merc_data(m, data)
	m.is_dead_permanently = bool(data.get("is_dead_permanently", not m.is_alive))
	return m


static func apply_merc_data(merc: Mercenary, data: Dictionary) -> void:
	merc.merc_id = data.get("merc_id", "")
	merc.merc_name = data.get("merc_name", "")
	merc.merc_type = data.get("merc_type", Mercenary.MercType.NORMAL)
	merc.merc_class = data.get("merc_class", "")
	merc.level = data.get("level", 1)
	merc.exp = data.get("exp", 0)
	merc.max_level = data.get("max_level", 60)
	merc.current_hp = data.get("current_hp", 100)
	merc.is_alive = data.get("is_alive", true)
	merc.is_mia = data.get("is_mia", false)
	merc.is_morgue_pending = data.get("is_morgue_pending", false)
	merc.rescue_injury_cd_until = int(data.get("rescue_injury_cd_until", 0))
	merc.is_near_death = data.get("is_near_death", false)
	merc.scar_stacks = maxi(0, int(data.get("scar_stacks", 0)))
	merc.is_retreated = data.get("is_retreated", false)
	merc.is_personal_break = data.get("is_personal_break", false)
	merc.personal_stability = clampi(
		data.get("personal_stability", StabilitySystem.MAX_STABILITY),
		0,
		StabilitySystem.MAX_STABILITY
	)
	merc.attack_range = data.get("attack_range", 50.0)
	merc.attack_speed = data.get("attack_speed", 1.0)
	merc.passive_skills = data.get("passive_skills", [])
	merc.active_skills = data.get("active_skills", [])
	merc.growth_per_level = data.get("growth_per_level", {})
	merc.template_id = data.get("template_id", "")

	var eq_data = data.get("equipment_slots", {})
	for slot in eq_data:
		if eq_data[slot] is Dictionary:
			merc.equipment_slots[slot] = Equipment.from_dict(eq_data[slot])
		else:
			merc.equipment_slots[slot] = null

	merc.buff_system.from_dict_array(data.get("buffs", []))
	sanitize_active_skills(merc)
	restore_active_skills_if_missing(merc)
	EquipmentSystem.apply_to(merc)
	if merc.is_mia:
		merc.current_hp = maxi(1, int(data.get("current_hp", 1)))
	elif not merc.is_alive:
		merc.current_hp = 0
	else:
		merc.clamp_hp_to_max()
		merc.try_clear_retreat_on_full_heal()
		merc.try_clear_near_death_for_deploy()
	merc.try_clear_personal_break()


static func sanitize_active_skills(merc: Mercenary) -> void:
	var cleaned: Array = []
	for skill_id in merc.active_skills:
		var sid := str(skill_id)
		if SkillSystem.is_active_skill(sid) or SkillSystem.get_skill_info(sid).size() > 0:
			cleaned.append(sid)
	merc.active_skills = cleaned


static func restore_active_skills_if_missing(merc: Mercenary) -> void:
	if not merc.active_skills.is_empty():
		return
	var tpl: Dictionary = DataLoader.merc_template(merc.template_id)
	if tpl.has("active_skills"):
		merc.active_skills = tpl.get("active_skills", []).duplicate()
		return
	if merc is Player:
		tpl = DataLoader.player_class(merc.merc_class)
		if tpl.has("active_skills"):
			merc.active_skills = tpl.get("active_skills", []).duplicate()
			return
	if merc.merc_class != "":
		var class_tpl: Dictionary = DataLoader.player_class(merc.merc_class)
		if class_tpl.has("active_skills"):
			merc.active_skills = class_tpl.get("active_skills", []).duplicate()
