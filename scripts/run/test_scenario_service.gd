class_name TestScenarioService
extends RefCounted
## 测试图：自带编队注入、进图横幅文案


static func is_ephemeral_test_result(result: Dictionary) -> bool:
	return bool(result.get("test_run_ephemeral", false))


static func is_test_map(map_data: Dictionary) -> bool:
	if map_data.is_empty():
		return false
	if TestRosterLoader.has_roster(str(map_data.get("map_id", ""))):
		return true
	var sid: String = str(map_data.get("test_scenario", ""))
	return sid != "" or str(map_data.get("map_id", "")).begins_with("test_")


## 本图任务佣兵可模拟濒死/灭团（回城 ephemeral 仍重置，不入账）
static func allows_run_casualties(map_data: Dictionary) -> bool:
	match str(map_data.get("test_scenario", "")):
		"long_chase_pressure", "boss_chase", "solo_near_death", "duo_near_death", "awakening", "mia_wipe":
			return true
		_:
			return false


static func current_run_allows_casualties() -> bool:
	var run = GameManager.current_run
	if run == null:
		return false
	return allows_run_casualties(run.map_data)


## 任务佣兵是否仍锁定伤亡（非任务佣兵恒为 false）
static func test_merc_blocks_casualties(merc) -> bool:
	if merc == null or not merc.is_test_stand_in:
		return false
	if GameManager.current_run == null:
		return false
	return not current_run_allows_casualties()


static func should_lock_roster(map_data: Dictionary) -> bool:
	var map_id: String = str(map_data.get("map_id", ""))
	return TestRosterLoader.has_roster(map_id)


## 名册里已有正式佣兵（含 fixture / 遗留 / 阵亡）时不应被测试图注入覆盖
static func has_production_roster_units(gm: GameManager) -> bool:
	if gm == null:
		return false
	for m in gm.elite_roster:
		if m != null and not m.is_test_stand_in:
			return true
	for m in gm.normal_roster:
		if m != null and not m.is_test_stand_in:
			return true
	return false


static func should_skip_test_roster_inject(gm: GameManager) -> bool:
	return has_production_roster_units(gm)


static func apply_on_prepare(gm: GameManager, map_id: String) -> void:
	if gm == null:
		return
	var md: Dictionary = DataLoader.map_data(map_id)
	if md.is_empty():
		return
	var roster: Dictionary = TestRosterLoader.roster_for_map(map_id)
	if not roster.is_empty():
		if should_skip_test_roster_inject(gm):
			return
		if str(md.get("test_scenario", "")) == "mia_wipe" and has_test_mia_casualties(gm):
			_apply_mia_wipe_recovery_prepare(gm, roster)
		else:
			apply_test_roster(gm, roster)
		if str(md.get("test_scenario", "")) == "mia_wipe":
			_inject_mia_wipe_frozen_pool(gm, map_id, roster)
			pass  # 稳定起点见 map run_start_team_stability（WorldRun.start）
		return
	match str(md.get("test_scenario", "")):
		"boss_chase", "awakening":
			gm.squad_formation["active_half"] = SquadFormationService.HALF_A
			SquadFormationService.rebalance_from_roster(gm)


static func apply_test_roster(gm: GameManager, roster: Dictionary) -> void:
	if gm == null or roster.is_empty():
		return
	gm.elite_roster.clear()
	for e in roster.get("elite", []):
		if e is Dictionary:
			var merc: Mercenary = SaveSerializer.deserialize_elite(e)
			if merc != null:
				merc.is_test_stand_in = true
				merc.reset_to_full_hp()
				merc.is_mia = false
				merc.is_near_death = false
				gm.elite_roster.append(merc)
	gm.normal_roster.clear()
	for n in roster.get("normal", []):
		if n is Dictionary:
			var merc_n: Mercenary = SaveSerializer.deserialize_normal(n)
			if merc_n != null:
				merc_n.is_test_stand_in = true
				merc_n.reset_to_full_hp()
				merc_n.is_mia = false
				merc_n.is_near_death = false
				gm.normal_roster.append(merc_n)
	var form: Variant = roster.get("formation", {})
	if form is Dictionary:
		gm.squad_formation["active_half"] = str(form.get("active_half", SquadFormationService.HALF_A))
		for half in [SquadFormationService.HALF_A, SquadFormationService.HALF_B]:
			var part: Variant = form.get(half, {})
			if part is Dictionary:
				gm.squad_formation[half] = {
					"active": _copy_string_array(part.get("active", [])),
					"bench": _copy_string_array(part.get("bench", [])),
				}
	SquadFormationService.ensure_formation(gm)
	gm.formation_changed.emit()


static func _all_roster_mercs(gm: GameManager) -> Array[Mercenary]:
	var list: Array[Mercenary] = []
	if gm.player:
		list.append(gm.player)
	list.append_array(gm.elite_roster)
	list.append_array(gm.normal_roster)
	return list


static func _copy_string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		for v in raw:
			out.append(str(v))
	return out


static func get_run_start_banner(map_data: Dictionary) -> String:
	var map_id: String = str(map_data.get("map_id", ""))
	var roster: Dictionary = TestRosterLoader.roster_for_map(map_id)
	var desc: String = str(map_data.get("description", ""))
	if desc == "":
		return ""
	var lines: PackedStringArray = []
	var sid: String = str(map_data.get("test_scenario", ""))
	var tag := _scenario_tag(sid)
	if tag != "":
		lines.append("[测试·%s] %s" % [tag, desc])
	elif is_test_map(map_data):
		lines.append("[测试说明] %s" % desc)
	var roster_label: String = str(roster.get("display_name", ""))
	if roster_label != "":
		lines.append("[本图编队] %s" % roster_label)
		lines.append("[主角] 保留当前存档角色名与养成，仅槽位与测试佣兵由本图注入")
		if str(map_data.get("test_scenario", "")) == "mia_wipe":
			lines.append("[任务佣兵] Boss线濒死→追击灭团→MIA；回城保留遗留+冻结池，可测后勤回收（经验不入账）")
		elif allows_run_casualties(map_data):
			lines.append("[任务佣兵] 本图可模拟濒死/灭团，结算展示不入账，回城后重置")
		else:
			lines.append("[任务佣兵] 锁定状态：不受伤/濒死/MIA/永久死亡，回城后重置")
	var eta: String = str(map_data.get("test_target_duration", ""))
	if eta != "":
		lines.append("[目标用时] %s" % eta)
	return "\n".join(lines)


static func _scenario_tag(scenario_id: String) -> String:
	match scenario_id:
		"stability_retreat":
			return "稳定度返程"
		"boss_chase":
			return "Boss追击"
		"awakening":
			return "绝境觉醒"
		"solo_near_death":
			return "单人濒死"
		"duo_near_death":
			return "双人濒死"
		"extract_line":
			return "撤离物线"
		"auto_value":
			return "价值撤离"
		"loot_full":
			return "网格满撤"
		"long_chase_pressure":
			return "濒死追击灭团"
		"mia_wipe":
			return "死战灭团"
		_:
			return ""


static func is_roster_injected(gm: GameManager, map_id: String) -> bool:
	var roster: Dictionary = TestRosterLoader.roster_for_map(map_id)
	if roster.is_empty():
		return true
	for raw in roster.get("elite", []):
		if raw is Dictionary:
			var mid: String = str(raw.get("merc_id", ""))
			if mid != "" and gm.find_mercenary_by_id(mid) == null:
				return false
	for raw in roster.get("normal", []):
		if raw is Dictionary:
			var mid_n: String = str(raw.get("merc_id", ""))
			if mid_n != "" and gm.find_mercenary_by_id(mid_n) == null:
				return false
	return true


## 大营选测试图时同步名册/编队（不必先点卡片「出征」）
static func sync_roster_for_map_selection(gm: GameManager, map_id: String) -> bool:
	if gm == null or map_id == "":
		return false
	var md: Dictionary = DataLoader.map_data(map_id)
	if not should_lock_roster(md):
		return false
	if should_skip_test_roster_inject(gm):
		return false
	if str(md.get("test_scenario", "")) == "mia_wipe" and has_test_mia_casualties(gm):
		apply_on_prepare(gm, map_id)
		gm.formation_changed.emit()
		return false
	if is_roster_injected(gm, map_id):
		return false
	gm.ensure_test_run_session()
	apply_on_prepare(gm, map_id)
	gm.formation_changed.emit()
	return true


static func ensure_roster_for_run(gm: GameManager, map_id: String) -> void:
	if gm == null or not should_lock_roster(DataLoader.map_data(map_id)):
		return
	if should_skip_test_roster_inject(gm):
		return
	if is_roster_injected(gm, map_id) and str(DataLoader.map_data(map_id).get("test_scenario", "")) != "mia_wipe":
		return
	if str(DataLoader.map_data(map_id).get("test_scenario", "")) == "mia_wipe" and has_test_mia_casualties(gm):
		apply_on_prepare(gm, map_id)
		return
	if is_roster_injected(gm, map_id):
		return
	gm.ensure_test_run_session()
	apply_on_prepare(gm, map_id)


static func has_test_mia_casualties(gm: GameManager) -> bool:
	for m in gm.elite_roster:
		if m != null and m.is_test_stand_in and m.is_mia:
			return true
	for m in gm.normal_roster:
		if m != null and m.is_test_stand_in and m.is_mia:
			return true
	return false


static func _apply_mia_wipe_recovery_prepare(gm: GameManager, roster: Dictionary) -> void:
	_ensure_test_roster_rescue_merc(gm, roster)
	var form: Variant = roster.get("formation", {})
	if form is Dictionary:
		gm.squad_formation["active_half"] = SquadFormationService.HALF_B
		var part_a: Variant = form.get(SquadFormationService.HALF_A, {})
		if part_a is Dictionary:
			gm.squad_formation[SquadFormationService.HALF_A] = {
				"active": _copy_string_array(part_a.get("active", [])),
				"bench": _copy_string_array(part_a.get("bench", [])),
			}
		var part_b: Variant = form.get(SquadFormationService.HALF_B, {})
		if part_b is Dictionary:
			gm.squad_formation[SquadFormationService.HALF_B] = {
				"active": _copy_string_array(part_b.get("active", [])),
				"bench": _copy_string_array(part_b.get("bench", [])),
			}
	SquadFormationService.ensure_formation(gm)
	gm.formation_changed.emit()


static func _ensure_test_roster_rescue_merc(gm: GameManager, roster: Dictionary) -> void:
	for raw in roster.get("normal", []):
		if not raw is Dictionary:
			continue
		var mid: String = str(raw.get("merc_id", ""))
		if mid == "" or gm.find_mercenary_by_id(mid) != null:
			continue
		var merc_n: NormalMercenary = SaveSerializer.deserialize_normal(raw)
		if merc_n == null:
			continue
		merc_n.is_test_stand_in = true
		merc_n.reset_to_full_hp()
		merc_n.is_mia = false
		merc_n.is_near_death = false
		gm.normal_roster.append(merc_n)


## 死战灭团图：Boss 线接战前满血，避免带着濒死态秒结算
static func prepare_mia_wipe_boss_combat(run: WorldRun) -> void:
	if run == null or str(run.map_data.get("test_scenario", "")) != "mia_wipe":
		return
	if run.squad == null:
		return
	for m in run.squad.members:
		if m == null or not m.is_test_stand_in:
			continue
		m.reset_to_full_hp()
		m.is_mia = false


static func is_mia_wipe_ephemeral_mia(result: Dictionary) -> bool:
	if result.is_empty() or not is_ephemeral_test_result(result):
		return false
	if str(result.get("settlement_tier", "")) != "mia":
		return false
	var map_id: String = str(result.get("map_id", ""))
	return str(DataLoader.map_data(map_id).get("test_scenario", "")) == "mia_wipe"


static func _force_mia_on_roster_merc(merc: Mercenary) -> void:
	if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
		return
	merc.is_alive = true
	merc.is_near_death = false
	merc.is_mia = true
	merc.current_hp = 1


static func finalize_mia_wipe_after_run(gm: GameManager, result: Dictionary) -> void:
	if gm == null or not is_mia_wipe_ephemeral_mia(result):
		return
	var map_id: String = str(result.get("map_id", ""))
	var player_id: String = gm.player.merc_id if gm.player else "player_01"
	for mid in result.get("squad_member_ids", []):
		var merc_id: String = str(mid)
		if merc_id == player_id:
			continue
		var merc := gm.find_mercenary_by_id(merc_id)
		if merc != null and merc.merc_type != Mercenary.MercType.PLAYER:
			_force_mia_on_roster_merc(merc)
	apply_on_prepare(gm, map_id)
	gm._test_run_baseline.clear()
	result["mia_wipe_roster_locked"] = true


static func should_preserve_mia_after_ephemeral(result: Dictionary) -> bool:
	return is_mia_wipe_ephemeral_mia(result)


static func should_skip_test_session_restore(result: Dictionary) -> bool:
	return bool(result.get("mia_wipe_roster_locked", false)) or is_mia_wipe_ephemeral_mia(result)


static func _inject_mia_wipe_frozen_pool(gm: GameManager, map_id: String, roster: Dictionary) -> void:
	if gm == null or roster.is_empty():
		return
	var member_ids: Array[String] = []
	for e in roster.get("elite", []):
		if e is Dictionary:
			var mid: String = str(e.get("merc_id", ""))
			if mid != "":
				member_ids.append(mid)
	for n in roster.get("normal", []):
		if n is Dictionary:
			var mid_n: String = str(n.get("merc_id", ""))
			if mid_n != "":
				member_ids.append(mid_n)
	if member_ids.is_empty():
		return
	gm.account_meta = SaveSerializer.normalize_account_meta(gm.account_meta)
	var pools: Array = gm.account_meta.get("frozen_exp_pools", [])
	var kept: Array = []
	var prefix: String = "test_mia_%s_" % map_id
	for raw in pools:
		if raw is Dictionary and str(raw.get("run_id", "")).begins_with(prefix):
			continue
		kept.append(raw)
	var mc: int = member_ids.size()
	kept.append({
		"run_id": "%s%d" % [prefix, Time.get_unix_time_from_system()],
		"map_id": "grassland",
		"total": 1200,
		"mia_count": mc,
		"field_count": mc,
		"mia_ratio": 1.0,
		"timestamp": Time.get_unix_time_from_system(),
		"member_ids": member_ids.duplicate(),
	})
	gm.account_meta["frozen_exp_pools"] = kept
