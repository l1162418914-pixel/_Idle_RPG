extends Node
## Phase 1 MIA 回归探针（逻辑层）— godot --headless --path <根> --scene res://tools/MiaPhase1Probe.tscn

const _ParallaxBackdropScene = preload("res://scripts/ui/parallax_backdrop.gd")
const _FormationSlotCardScene = preload("res://scripts/ui/formation_slot_card.gd")
const _BaseCampBagUIScene = preload("res://scripts/ui/base_camp_bag_ui.gd")
const _MarchEventService = preload("res://scripts/run/march_event_service.gd")

var _failed: Array[String] = []
var _passed: Array[String] = []
var _gm_snapshot: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _exit_tree() -> void:
	_restore_gm()


func _snapshot_gm() -> void:
	_gm_snapshot = GameManager.to_save_dict().duplicate(true)


func _restore_gm() -> void:
	if _gm_snapshot.is_empty():
		return
	GameManager.from_save_dict(_gm_snapshot.duplicate(true))
	GameManager.current_run = null
	GameManager.selected_squad.clear()
	GameManager._pending_run_result = {}
	GameManager._test_run_baseline = {}
	GameManager.state = GameManager.GameState.BASE
	_gm_snapshot.clear()


func _run() -> void:
	DataLoader.load_all()
	_snapshot_gm()
	_reset_gm()
	_probe_r6_player_never_mia()
	_probe_r1_wipe_mia_alive()
	_probe_r3_abandon_permanent_death()
	_probe_r5_manual_no_mia()
	_probe_r7_frozen_exp_pool()
	_probe_r4_emergency_near_death_not_mia()
	_probe_p2_recovery_tier_and_unfreeze()
	_probe_p2_recovery_fail_no_mia()
	_probe_mia_wipe_recovery_prepare()
	_probe_mia_wipe_roster_guard()
	_probe_mia_wipe_preserve_return()
	_probe_mia_wipe_return_to_base()
	_probe_test_stand_in_abandon()
	_probe_mia_excluded_from_formation()
	_probe_p2_high_value_mia_revive_no_run()
	_probe_p3_downed_shield_and_mia()
	_probe_p3_pressure_zero_near_death()
	_probe_p3_recovery_near_death()
	_probe_p3_retreat_failure_b3a()
	_probe_p3_retreat_failure_b3b()
	_probe_p3_retreat_success_no_mia()
	_probe_p3_pressure_retreat_event()
	_probe_p3_single_pressure_substitute()
	_probe_p3_player_forced_return_mercs_continue()
	_probe_p3_player_forced_return_solo()
	_probe_p3_player_forced_return_finalize()
	_probe_p3_supply_point_passage()
	_probe_p3_mia_deterioration_tick()
	_probe_p3_mia_map_point_hidden()
	_probe_p3_pressure_stage2_camp()
	_probe_p3_substitute_combat_phases()
	_probe_p4_rescue_run_mode()
	_probe_p4_rescue_success_morgue()
	_probe_p4_rescue_failure_injury_cd()
	_probe_p4_morgue_medical_revive()
	_probe_p4_rescue_squad_rebuild()
	_probe_p5_recovery_fail_grants_scroll()
	_probe_p5_instant_recovery_success()
	_probe_p5_scroll_discount()
	_probe_p5_rescue_fail_no_scroll()
	_probe_p5_scroll_consume()
	_probe_p6_mia_settlement_records_half()
	_probe_p6_pick_target_opposite_half()
	_probe_p6_start_run_auto_recovery()
	_probe_p6_skip_mutual_normal()
	_probe_p6_auto_disabled()
	_probe_p7_rescue_locked_without_building()
	_probe_p7_rescue_unlock_after_upgrade()
	_probe_v2_march_advance_visual()
	_probe_v2_march_retreat_visual()
	_probe_v3_combat_anchor_spawn()
	_probe_v3_lane_anchor_freeze()
	_probe_v4_retreat_combat_scroll()
	_probe_v4_advance_combat_parallax_frozen()
	_probe_v4_parallax_retreat_direction()
	_probe_v5_boss_chase_silhouette()
	_probe_v5_combat_resume_delay()
	_probe_b15_map_card_select_deploy_split()
	_probe_b15_dock_button_min_height()
	_probe_b2_top_stability_bar()
	_probe_b2_run_ui_stability_relocated()
	_probe_b3_formation_slot_card()
	_probe_b3_half_stage_panel()
	_probe_b4_camp_bag_grid()
	_probe_b4_base_ui_bag_integration()
	_probe_m2_milestone_fire_once()
	_probe_m2_milestone_pause_rules()
	_probe_mv2_lane_markers_from_map()
	_probe_mv2_markers_hide_on_retreat()
	_probe_mv3_gather_deferred_loot()
	_probe_mv3_lane_gather_beat_state()
	_print_report()
	_restore_gm()
	get_tree().quit(1 if not _failed.is_empty() else 0)


func _reset_gm() -> void:
	GameManager.account_meta = SaveSerializer.default_account_meta()
	GameManager.normal_roster.clear()
	GameManager.elite_roster.clear()
	var merc := NormalMercenary.new()
	merc.merc_id = "probe_m1"
	merc.merc_name = "探针佣兵"
	merc.template_id = "warrior_normal"
	merc.merc_type = Mercenary.MercType.NORMAL
	merc.is_alive = true
	merc.level = 3
	merc.refresh_base_stats()
	merc.current_hp = merc.get_max_hp_value()
	GameManager.normal_roster.append(merc)
	_ensure_probe_player()
	if not GameManager.buildings.has("rescue_station"):
		GameManager.buildings["rescue_station"] = {"level": 1, "building_id": "rescue_station"}
	else:
		GameManager.buildings["rescue_station"]["level"] = 1
	MorgueService.sync_rescue_unlock_meta(GameManager)
	_ensure_probe_merc2()


func _ensure_probe_player() -> void:
	if GameManager.player != null:
		GameManager.player.is_mia = false
		GameManager.player.is_near_death = false
		GameManager.player.is_alive = true
		return
	GameManager._create_player("warrior")
	if GameManager.player:
		GameManager.player.is_mia = false
		GameManager.player.is_near_death = false
		GameManager.player.is_alive = true


func _make_probe_normal(id: String, name: String) -> NormalMercenary:
	var m := NormalMercenary.new()
	m.merc_id = id
	m.merc_name = name
	m.template_id = "warrior_normal"
	m.merc_type = Mercenary.MercType.NORMAL
	m.is_alive = true
	m.level = 3
	m.refresh_base_stats()
	m.current_hp = m.get_max_hp_value()
	return m


func _ensure_probe_normal(id: String, name: String) -> NormalMercenary:
	var existing := GameManager.find_mercenary_by_id(id)
	if existing is NormalMercenary:
		return existing as NormalMercenary
	var m := _make_probe_normal(id, name)
	GameManager.normal_roster.append(m)
	return m


func _ensure_probe_merc2() -> NormalMercenary:
	var m2 := GameManager.find_mercenary_by_id("probe_m2")
	if m2 != null:
		return m2 as NormalMercenary
	m2 = NormalMercenary.new()
	m2.merc_id = "probe_m2"
	m2.merc_name = "探针佣兵2"
	m2.template_id = "warrior_normal"
	m2.merc_type = Mercenary.MercType.NORMAL
	m2.is_alive = true
	m2.level = 3
	m2.refresh_base_stats()
	m2.current_hp = m2.get_max_hp_value()
	GameManager.normal_roster.append(m2)
	return m2


func _setup_p6_b_half_deploy() -> void:
	_ensure_probe_merc2()
	SquadFormationService.ensure_formation(GameManager)
	GameManager.squad_formation = {
		"A": {"active": [], "bench": []},
		"B": {"active": ["probe_m2"], "bench": []},
		"active_half": "B",
	}


func _probe_r6_player_never_mia() -> void:
	var p := GameManager.player
	if p == null:
		_fail("R6", "无主角")
		return
	p.enter_mia_state()
	if p.is_mia:
		_fail("R6", "主角 enter_mia_state 后 is_mia=true")
	else:
		_pass("R6", "主角永不 MIA")


func _probe_r1_wipe_mia_alive() -> void:
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("R1", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	if not merc.is_mia or not merc.is_alive:
		_fail("R1", "灭团后须 is_mia 且 is_alive (got mia=%s alive=%s)" % [merc.is_mia, merc.is_alive])
		return
	var squad := Squad.new()
	squad.build([merc])
	var run := WorldRun.new("grassland", squad)
	run.squad_wiped = true
	if run._resolve_settlement_tier(false) != "mia":
		_fail("R1", "settlement_tier 应为 mia")
		return
	_pass("R1", "灭团 → MIA 存活 + tier=mia")
	merc.clear_mia_state()
	merc.is_alive = true


func _probe_r3_abandon_permanent_death() -> void:
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("R3", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager.account_meta = SaveSerializer.default_account_meta()
	var pools: Array = GameManager.account_meta.get("frozen_exp_pools", [])
	pools.append({
		"run_id": "probe_run",
		"map_id": "grassland",
		"total": 100,
		"mia_count": 1,
		"field_count": 2,
		"mia_ratio": 0.5,
		"timestamp": 1,
		"member_ids": ["probe_m1"],
	})
	GameManager.account_meta["frozen_exp_pools"] = pools
	var code: int = GameManager.abandon_mia_search("probe_m1")
	if code != 0:
		_fail("R3", "abandon_mia_search 返回 %d" % code)
		return
	if merc.is_mia or merc.is_alive:
		_fail("R3", "放弃后须非 MIA 且非存活 (mia=%s alive=%s)" % [merc.is_mia, merc.is_alive])
		return
	var left: Array = GameManager.account_meta.get("frozen_exp_pools", [])
	if not left.is_empty():
		_fail("R3", "放弃后冻结池应清空该项 (left=%d)" % left.size())
		return
	_pass("R3", "放弃搜寻 → 永久死亡 + 清池")
	_reset_gm()


func _probe_r5_manual_no_mia() -> void:
	var squad := Squad.new()
	squad.build([])
	var run := WorldRun.new("grassland", squad)
	run.retreat_reason = "manual"
	run.squad_wiped = false
	if run._resolve_settlement_tier(true) != "manual":
		_fail("R5", "手动斩仓 tier 应为 manual")
		return
	if run._resolve_settlement_tier(true) == "mia":
		_fail("R5", "未灭团时 manual 不应为 mia")
		return
	_pass("R5", "manual → settlement_tier=manual（无灭团）")


func _probe_r7_frozen_exp_pool() -> void:
	GameManager.account_meta = SaveSerializer.default_account_meta()
	var before: int = GameManager.account_meta.get("frozen_exp_pools", []).size()
	var mia_result := {
		"settlement_tier": "mia",
		"total_exp": 200,
		"field_count": 2,
		"mia_count": 1,
		"squad_member_ids": ["probe_m1", "player"],
		"map_id": "grassland",
		"test_run_ephemeral": false,
	}
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc:
		merc.enter_mia_state()
	GameManager._record_frozen_exp_pool(mia_result)
	var after_mia: int = GameManager.account_meta.get("frozen_exp_pools", []).size()
	if after_mia <= before:
		_fail("R7", "MIA 结算后 frozen_exp_pools 未增加")
		return
	var success_result := {
		"settlement_tier": "success",
		"total_exp": 200,
		"field_count": 2,
		"mia_count": 0,
		"squad_member_ids": ["probe_m1"],
		"map_id": "grassland",
	}
	var before_ok: int = GameManager.account_meta.get("frozen_exp_pools", []).size()
	GameManager._record_frozen_exp_pool(success_result)
	var after_ok: int = GameManager.account_meta.get("frozen_exp_pools", []).size()
	if after_ok != before_ok:
		_fail("R7", "成功结算不应增加池 (before=%d after=%d)" % [before_ok, after_ok])
		return
	_pass("R7", "MIA 增池 / 成功不增池")
	if merc:
		merc.clear_mia_state()


func _probe_r4_emergency_near_death_not_mia() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("R4", "探针佣兵缺失")
		return
	var result := {
		"manual_withdraw": false,
		"emergency_retreat": true,
		"completed_retreat": true,
		"squad_member_ids": ["probe_m1"],
		"map_id": "grassland",
	}
	GameManager._apply_emergency_retreat_near_death_if_needed(result, true)
	if merc.is_mia:
		_fail("R4", "紧急抵营濒死不应 is_mia")
		return
	if not merc.is_near_death:
		_fail("R4", "紧急抵营应 is_near_death")
		return
	if not bool(result.get("near_death_penalty", false)):
		_fail("R4", "应标记 near_death_penalty")
		return
	_pass("R4", "抵营全队濒死 · 无 MIA")


func _probe_p2_recovery_tier_and_unfreeze() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P2a", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager.account_meta = SaveSerializer.default_account_meta()
	GameManager.account_meta["frozen_exp_pools"] = [{
		"run_id": "probe_rec",
		"map_id": "grassland",
		"total": 400,
		"mia_count": 1,
		"field_count": 2,
		"mia_ratio": 0.5,
		"timestamp": 2,
		"member_ids": ["probe_m1"],
	}]
	var run := WorldRun.new("grassland", null)
	run.run_mode = WorldRun.RunMode.RECOVERY
	run.recovery_failed = false
	run.max_distance = 72.0
	run.distance_traveled = 72.0
	if run._resolve_settlement_tier(false) != "recovery":
		_fail("P2a", "抵点回收 tier 应为 recovery (got %s)" % run._resolve_settlement_tier(false))
		return
	if not run.has_completed_recovery_advance():
		_fail("P2a", "has_completed_recovery_advance 应为 true")
		return
	var result := {
		"settlement_tier": "recovery",
		"recovery_target_ids": ["probe_m1"],
	}
	GameManager._apply_recovery_settlement(result)
	if merc.is_mia:
		_fail("P2a", "回收成功后应清 is_mia")
		return
	if not merc.is_near_death:
		_fail("P2a", "回收成功后应濒死+养伤（§5.5）")
		return
	if int(result.get("recovery_unfrozen_exp", 0)) != 100:
		_fail("P2a", "25%% 解冻应为 100 (got %d)" % int(result.get("recovery_unfrozen_exp", 0)))
		return
	if not GameManager.account_meta.get("frozen_exp_pools", []).is_empty():
		_fail("P2a", "回收成功后冻结池应移除目标")
		return
	_pass("P2a", "recovery tier + 25%% 解冻 + 清 MIA")


func _probe_p2_recovery_fail_no_mia() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P2b", "探针佣兵缺失")
		return
	merc.is_near_death = false
	merc.is_mia = false
	var run := WorldRun.new("grassland", null)
	run.run_mode = WorldRun.RunMode.RECOVERY
	run.recovery_failed = true
	if run._resolve_settlement_tier(false) != "recovery_fail":
		_fail("P2b", "回收失败 tier 应为 recovery_fail")
		return
	_pass("P2b", "recovery_fail tier 桩")


func _probe_mia_wipe_recovery_prepare() -> void:
	_reset_gm()
	var tank := GameManager.find_mercenary_by_id("t09_tank")
	if tank == null:
		TestScenarioService.apply_test_roster(
			GameManager,
			TestRosterLoader.roster_for_map("test_09_long_chase_pressure")
		)
		tank = GameManager.find_mercenary_by_id("t09_tank")
	if tank == null:
		_fail("P2c", "t09_tank 缺失")
		return
	tank.enter_mia_state()
	TestScenarioService.apply_on_prepare(GameManager, "test_09_long_chase_pressure")
	var rescue := GameManager.find_mercenary_by_id("t09_rescue")
	if rescue == null:
		_fail("P2c", "回收准备应注入 t09_rescue")
		return
	if not tank.is_mia:
		_fail("P2c", "回收准备应保留 is_mia")
		return
	if str(GameManager.squad_formation.get("active_half", "")) != "B":
		_fail("P2c", "回收准备应切到 B 半组")
		return
	_pass("P2c", "遗留保留 + B 半组援军")


func _probe_mia_wipe_roster_guard() -> void:
	GameManager.account_meta = SaveSerializer.default_account_meta()
	GameManager.normal_roster.clear()
	GameManager.elite_roster.clear()
	GameManager.ensure_test_run_session()
	if TestScenarioService.is_roster_injected(GameManager, "test_09_long_chase_pressure"):
		_fail("P2d", "空 roster 不应视为已注入")
		return
	TestScenarioService.ensure_roster_for_run(GameManager, "test_09_long_chase_pressure")
	if not TestScenarioService.is_roster_injected(GameManager, "test_09_long_chase_pressure"):
		_fail("P2d", "ensure_roster_for_run 未注入测试编队")
		return
	_pass("P2d", "出征前自动注入测试编队")


func _probe_mia_wipe_preserve_return() -> void:
	TestScenarioService.apply_test_roster(
		GameManager,
		TestRosterLoader.roster_for_map("test_09_long_chase_pressure")
	)
	GameManager.ensure_test_run_session()
	var result := {
		"map_id": "test_09_long_chase_pressure",
		"settlement_tier": "mia",
		"squad_wiped": true,
		"squad_member_ids": ["t09_tank", "t09_mage"],
		"test_run_ephemeral": true,
	}
	for mid in ["t09_tank", "t09_mage"]:
		var m := GameManager.find_mercenary_by_id(mid)
		if m != null:
			m.enter_mia_state()
	TestScenarioService.finalize_mia_wipe_after_run(GameManager, result)
	if GameManager.find_mercenary_by_id("t09_tank") == null:
		_fail("P2e", "回城保留后 t09_tank 不应被学徒快照覆盖")
		return
	if not GameManager.find_mercenary_by_id("t09_tank").is_mia:
		_fail("P2e", "回城保留后应仍为 is_mia")
		return
	if GameManager.get_mia_roster_entries().is_empty():
		_fail("P2e", "get_mia_roster_entries 应非空")
		return
	var rescue := GameManager.find_mercenary_by_id("t09_rescue")
	if rescue == null:
		_fail("P2e", "应注入 t09_rescue 供回收出征")
		return
	_pass("P2e", "死战回城保留遗留+援军（不回滚学徒）")


func _probe_mia_wipe_return_to_base() -> void:
	_reset_gm()
	GameManager.ensure_test_run_session()
	TestScenarioService.apply_test_roster(
		GameManager,
		TestRosterLoader.roster_for_map("test_09_long_chase_pressure")
	)
	var result := {
		"map_id": "test_09_long_chase_pressure",
		"settlement_tier": "mia",
		"squad_wiped": true,
		"squad_member_ids": ["t09_tank", "t09_mage"],
		"test_run_ephemeral": true,
	}
	TestScenarioService.finalize_mia_wipe_after_run(GameManager, result)
	GameManager._pending_run_result = result.duplicate(true)
	GameManager.state = GameManager.GameState.RESULT
	GameManager.return_to_base()
	if GameManager.find_mercenary_by_id("t09_tank") == null:
		_fail("P2f", "return_to_base 后 t09_tank 不应消失")
		return
	if not GameManager.find_mercenary_by_id("t09_tank").is_mia:
		_fail("P2f", "return_to_base 后 t09_tank 应仍为 is_mia")
		return
	if GameManager.get_mia_roster_entries().size() < 2:
		_fail("P2f", "return_to_base 后 get_mia_roster_entries 应≥2")
		return
	_pass("P2f", "死战 return_to_base 不清遗留、不回滚学徒")


func _probe_test_stand_in_abandon() -> void:
	_reset_gm()
	TestScenarioService.apply_test_roster(
		GameManager,
		TestRosterLoader.roster_for_map("test_09_long_chase_pressure")
	)
	var tank := GameManager.find_mercenary_by_id("t09_tank")
	if tank == null:
		_fail("P2g", "t09_tank 缺失")
		return
	tank.enter_mia_state()
	var mage := GameManager.find_mercenary_by_id("t09_mage")
	if mage != null:
		mage.enter_mia_state()
	GameManager.account_meta = SaveSerializer.default_account_meta()
	GameManager.account_meta["frozen_exp_pools"] = [{
		"run_id": "probe_t09",
		"map_id": "grassland",
		"total": 800,
		"mia_count": 2,
		"field_count": 2,
		"mia_ratio": 1.0,
		"timestamp": 1,
		"member_ids": ["t09_tank", "t09_mage"],
	}]
	var code: int = GameManager.abandon_mia_search("t09_tank")
	if code != 0:
		_fail("P2g", "测试佣兵放弃返回 %d" % code)
		return
	if GameManager.find_mercenary_by_id("t09_tank") != null:
		_fail("P2g", "放弃后应从名册移除 t09_tank")
		return
	if GameManager.get_mia_roster_entries().size() != 1:
		_fail("P2g", "放弃后应剩 1 名遗留 (got %d)" % GameManager.get_mia_roster_entries().size())
		return
	_pass("P2g", "测试佣兵放弃搜寻 → 移出名册+扣池")


func _probe_p2_high_value_mia_revive_no_run() -> void:
	_reset_gm()
	GameManager.gold = 100000
	GameManager.state = GameManager.GameState.BASE
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P2i", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager.account_meta = SaveSerializer.default_account_meta()
	GameManager.account_meta["frozen_exp_pools"] = [{
		"run_id": "probe_hv",
		"map_id": "grassland",
		"total": 800,
		"mia_count": 1,
		"field_count": 2,
		"mia_ratio": 0.5,
		"timestamp": 3,
		"member_ids": ["probe_m1"],
	}]
	var cost: int = GameManager.get_high_value_mia_revive_cost(merc)
	var gold_before: int = GameManager.gold
	var code: int = GameManager.try_high_value_mia_revive("probe_m1")
	if code != 0:
		_fail("P2i", "大价值复活返回 %d" % code)
		return
	if GameManager.state != GameManager.GameState.BASE:
		_fail("P2i", "大价值复活不应改变 BASE 状态")
		return
	if GameManager.current_run != null:
		_fail("P2i", "大价值复活不应创建 current_run")
		return
	if merc.is_mia:
		_fail("P2i", "大价值复活后应清 is_mia")
		return
	if GameManager.gold != gold_before - cost:
		_fail("P2i", "应扣金币 %d (got %d)" % [cost, gold_before - GameManager.gold])
		return
	var unfrozen: int = int(GameManager.last_high_value_revive_summary.get("unfrozen", 0))
	if unfrozen != 200:
		_fail("P2i", "25%% 解冻应为 200 (got %d)" % unfrozen)
		return
	if not GameManager.account_meta.get("frozen_exp_pools", []).is_empty():
		_fail("P2i", "大价值复活后冻结池应移除目标")
		return
	_pass("P2i", "大价值复活：大营即时、扣金、解冻、不跑图")


func _probe_p3_downed_shield_and_mia() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P3a", "探针佣兵缺失")
		return
	merc.enter_near_death_state(0.05)
	var cfg: Dictionary = DataLoader.near_death_config().get("downed_shield", {})
	var expected_shield: int = int(cfg.get("base_amount", 80))
	if merc.near_death_shield != expected_shield:
		_fail("P3a", "进濒死应授予护盾 %d (got %d)" % [expected_shield, merc.near_death_shield])
		return
	if merc.personal_stability != maxi(1, int(cfg.get("pressure_lock", 1))):
		_fail("P3a", "濒死应锁压力为 %d" % int(cfg.get("pressure_lock", 1)))
		return
	merc.near_death_shield = 0
	if not merc.try_enter_mia_from_downed_kill():
		_fail("P3b", "护盾破后应可进 MIA")
		return
	if not merc.is_mia:
		_fail("P3b", "二段死亡后应 is_mia")
		return
	_pass("P3a/P3b", "濒死护盾 + 二段→MIA")


func _probe_p3_pressure_zero_near_death() -> void:
	_reset_gm()
	GameManager.state = GameManager.GameState.RUNNING
	GameManager.current_run = WorldRun.new("grassland", null)
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P3c", "探针佣兵缺失")
		return
	merc.personal_stability = 5
	merc.modify_personal_stability(-5)
	if not merc.is_near_death:
		_fail("P3c", "出征中压力清零应进濒死")
		return
	GameManager.current_run = null
	GameManager.state = GameManager.GameState.BASE
	_pass("P3c", "压力清零→濒死（出征中）")


func _probe_p3_recovery_near_death() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P3d", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager._apply_recovery_settlement({
		"recovery_target_ids": ["probe_m1"],
		"settlement_tier": "recovery",
	})
	if merc.is_mia:
		_fail("P3d", "回收后应清 MIA")
		return
	if not merc.is_near_death:
		_fail("P3d", "回收后应保留濒死")
		return
	_pass("P3d", "回收成功→濒死+伤痕（非回满）")


func _probe_p3_retreat_failure_b3a() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P3e", "探针佣兵缺失")
		return
	var m2 := _ensure_probe_normal("probe_m2b", "探针佣兵2")
	m1.enter_near_death_state(0.05)
	m2.enter_near_death_state(0.05)
	var result := {
		"map_id": "grassland",
		"squad_member_ids": ["probe_m1", "probe_m2b"],
		"retreat_failure": true,
		"completed_retreat": false,
		"manual_withdraw": false,
		"is_retreating": true,
		"retreat_reason": "forced",
		"total_exp": 400,
		"field_count": 2,
	}
	RetreatFailureMiaService.apply_settlement(GameManager, result)
	if not m1.is_mia or not m2.is_mia:
		_fail("P3e", "B-3a 全员濒死应全进 MIA")
		return
	if str(result.get("retreat_failure_mode", "")) != "B-3a":
		_fail("P3e", "mode 应为 B-3a (got %s)" % str(result.get("retreat_failure_mode", "")))
		return
	_pass("P3e", "撤离失败 B-3a 全员遗留")


func _probe_p3_retreat_failure_b3b() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P3f", "探针佣兵缺失")
		return
	var m2 := _ensure_probe_normal("probe_m2c", "探针佣兵2")
	var m3 := _ensure_probe_normal("probe_m3c", "探针佣兵3")
	m1.enter_near_death_state(0.05)
	m2.enter_near_death_state(0.05)
	var result := {
		"map_id": "grassland",
		"squad_member_ids": ["probe_m1", "probe_m2c", "probe_m3c"],
		"retreat_failure": true,
		"completed_retreat": false,
		"retreat_reason": "emergency",
		"total_exp": 600,
		"field_count": 3,
	}
	RetreatFailureMiaService.apply_settlement(GameManager, result)
	if not m1.is_mia or not m2.is_mia:
		_fail("P3f", "B-3b 濒死者应进 MIA")
		return
	if m3.is_mia:
		_fail("P3f", "B-3b 幸存者不应进 MIA")
		return
	if not m3.is_near_death:
		_fail("P3f", "B-3b 幸存者应濒死")
		return
	if str(result.get("retreat_failure_mode", "")) != "B-3b":
		_fail("P3f", "mode 应为 B-3b")
		return
	_pass("P3f", "撤离失败 B-3b 大部分遗留+幸存者濒死")


func _probe_p3_retreat_success_no_mia() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P3g", "探针佣兵缺失")
		return
	var ok_result := {
		"completed_retreat": true,
		"emergency_retreat": true,
		"retreat_reason": "emergency",
		"manual_withdraw": false,
		"squad_member_ids": ["probe_m1"],
	}
	if RetreatFailureMiaService.should_settle(GameManager, ok_result):
		_fail("P3g", "抵营成功不应走撤离失败 MIA")
		return
	m1.is_near_death = false
	m1.current_hp = m1.get_max_hp_value()
	GameManager._apply_emergency_retreat_near_death_if_needed(ok_result, true)
	if m1.is_mia:
		_fail("P3g", "抵营濒死不应 MIA")
		return
	_pass("P3g", "B-3e 抵营=养伤无 MIA")


func _probe_p3_pressure_retreat_event() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P3h", "探针佣兵缺失")
		return
	m1.personal_stability = 25
	var squad := Squad.new()
	squad.build([GameManager.player, m1])
	var run := WorldRun.new("grassland", squad)
	run.is_active = true
	PressureOutcomeService.trigger_team_pressure_retreat(run)
	if not run.pressure_retreat_event:
		_fail("P3h", "应标记 pressure_retreat_event")
		return
	if not run.is_retreating or run.retreat_reason != "pressure":
		_fail("P3h", "应进入 pressure 撤离 (retreating=%s reason=%s)" % [run.is_retreating, run.retreat_reason])
		return
	if run.pressure_mia_quota < 1:
		_fail("P3h", "轻判定应给出 mia_quota>=1")
		return
	_pass("P3h", "团队压力收场→撤离事件")


func _probe_p3_single_pressure_substitute() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P3i", "探针佣兵缺失")
		return
	var bench := _ensure_probe_normal("probe_bench", "替补探针")
	bench.level = 2
	bench.refresh_base_stats()
	bench.current_hp = bench.get_max_hp_value()
	var squad := Squad.new()
	squad.build([GameManager.player, m1])
	var run := WorldRun.new("grassland", squad)
	run.is_active = true
	run.bench_reserves = [bench]
	m1.personal_stability = 3
	var ok: bool = PressureOutcomeService.try_single_pressure_substitute(run, m1)
	if not ok:
		_fail("P3i", "替补换人应成功")
		return
	if m1.is_near_death:
		_fail("P3i", "换人后不应立刻濒死")
		return
	if bench not in run.squad.members:
		_fail("P3i", "替补应上场")
		return
	if m1 not in run.bench_reserves:
		_fail("P3i", "被换下者应回替补席")
		return
	_pass("P3i", "单人压力触顶→替补换人")


func _probe_p3_player_forced_return_mercs_continue() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	var p := GameManager.player
	if m1 == null or p == null:
		_fail("P3j", "探针主角/佣兵缺失")
		return
	var squad := Squad.new()
	squad.build([p, m1])
	var run := WorldRun.new("grassland", squad)
	run.is_active = true
	GameManager.current_run = run
	p.enter_near_death_state(0.05)
	var summary: Dictionary = PlayerForcedReturnService.apply_combat_fall(run, p)
	if not run.player_forced_return:
		_fail("P3j", "应标记 player_forced_return")
		return
	if p.is_mia:
		_fail("P3j", "主角不应 MIA")
		return
	if not p.is_alive:
		_fail("P3j", "主角应 is_alive")
		return
	if not bool(summary.get("mercs_continue", false)):
		_fail("P3j", "有存活佣兵时应 mercs_continue")
		return
	if p in run.squad.members:
		_fail("P3j", "主角应离阵")
		return
	GameManager.current_run = null
	_pass("P3j", "主角濒死护盾破→强制回城·佣兵留场")


func _probe_p3_player_forced_return_solo() -> void:
	_reset_gm()
	var p := GameManager.player
	if p == null:
		_fail("P3k", "无主角")
		return
	var squad := Squad.new()
	squad.build([p])
	var run := WorldRun.new("grassland", squad)
	run.is_active = true
	var summary: Dictionary = PlayerForcedReturnService.apply_combat_fall(run, p)
	if not bool(summary.get("solo", false)):
		_fail("P3k", "独阵应 solo")
		return
	if bool(summary.get("mercs_continue", false)):
		_fail("P3k", "独阵不应 mercs_continue")
		return
	_pass("P3k", "主角独阵→强制回城·无佣兵留场")


func _probe_p3_player_forced_return_finalize() -> void:
	_reset_gm()
	var p := GameManager.player
	if p == null:
		_fail("P3l", "无主角")
		return
	p.is_alive = false
	var result: Dictionary = {
		"player_forced_return": true,
		"player_alive": false,
	}
	PlayerForcedReturnService.finalize_account_player(GameManager, result)
	if p.is_mia:
		_fail("P3l", "结算后主角不应 MIA")
		return
	if not p.is_alive:
		_fail("P3l", "结算后主角应 is_alive")
		return
	if not p.is_near_death:
		_fail("P3l", "结算后主角应濒死回营")
		return
	if not bool(result.get("player_alive", false)):
		_fail("P3l", "result.player_alive 应为 true")
		return
	_pass("P3l", "end_run 结算：主角濒死回营·永不 MIA")


func _probe_p3_supply_point_passage() -> void:
	_reset_gm()
	var squad := Squad.new()
	squad.build([GameManager.player])
	var run := WorldRun.new("grassland", squad)
	run.is_active = true
	run.max_distance_reached = 95.0
	run._tick_supply_point_passage()
	if not run.supply_point_passed:
		_fail("P3m", "推进过补给距离应标记 supply_point_passed")
		return
	var result: Dictionary = run.end_run(false)
	if not bool(result.get("supply_point_passed", false)):
		_fail("P3m", "end_run 应带出 supply_point_passed")
		return
	_pass("P3m", "过补给点标记（B-11b 前提）")


func _probe_p3_mia_deterioration_tick() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P3n", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "probe_pool",
			"map_id": "grassland",
			"total": 400,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	var pre: Array[String] = ["probe_m1"]
	var result: Dictionary = {
		"supply_point_passed": true,
		"run_mode": WorldRun.RunMode.NORMAL,
		"completed_retreat": true,
	}
	MiaDeteriorationService.on_run_finished(GameManager, result, pre)
	var pool: Dictionary = GameManager.account_meta["frozen_exp_pools"][0]
	if int(pool.get("skipped_runs", 0)) != 1:
		_fail("P3n", "过补给未捞应 skipped_runs=1 (got %d)" % int(pool.get("skipped_runs", 0)))
		return
	_pass("P3n", "B-11 计趟 +1")


func _probe_p3_mia_map_point_hidden() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P3o", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager.account_meta["frozen_exp_pools"] = [
		{
			"run_id": "probe_pool",
			"map_id": "grassland",
			"total": 400,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
			"skipped_runs": 2,
			"map_point_visible": false,
		},
	]
	if MiaDeteriorationService.is_map_recovery_available(GameManager, "probe_m1"):
		_fail("P3o", "2 趟后地图回收应不可用")
		return
	if GameManager.start_recovery_run("probe_m1") != -6:
		_fail("P3o", "start_recovery_run 应返回 -6")
		return
	_pass("P3o", "B-11c 地图点消失·大价值路仍开")


func _probe_p3_pressure_stage2_camp() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P3p", "探针佣兵缺失")
		return
	m1.personal_stability = 4
	m1.current_hp = int(float(m1.get_max_hp_value()) * 0.2)
	var result: Dictionary = {
		"pressure_retreat_event": true,
		"completed_retreat": true,
		"pressure_mia_quota": 1,
		"squad_member_ids": [GameManager.player.merc_id, "probe_m1"],
	}
	PressureOutcomeService.apply_camp_pressure_settlement(GameManager, result)
	if int(result.get("pressure_mia_rolled", 0)) < 1:
		_fail("P3p", "二阶段应至少 roll 1 人")
		return
	if not result.has("pressure_mia_applied"):
		_fail("P3p", "应写入 pressure_mia_applied")
		return
	_pass("P3p", "B-3c 抵营二阶段概率 MIA")


func _probe_p3_substitute_combat_phases() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	var bench := _make_probe_normal("probe_bench2", "替补2")
	bench.level = 2
	bench.refresh_base_stats()
	bench.current_hp = bench.get_max_hp_value()
	var combat := CombatController.new()
	combat.allies.clear()
	var e1 := CombatEntity.new()
	e1.init_from_merc(m1, "ally_")
	e1.formation_slot = 1
	combat.allies.append(e1)
	if not combat.eject_pressure_substitute(m1):
		_fail("P3q", "应先退场形成 3→2")
		return
	if combat.allies.size() != 0:
		_fail("P3q", "退场后场上应暂空")
		return
	if not combat.deploy_pressure_substitute(bench, 1):
		_fail("P3q", "读条后替补应上场")
		return
	if combat.allies.size() != 1:
		_fail("P3q", "上场后应为 3 人编制中的 1 战斗实体")
		return
	_pass("P3q", "换人读条 3→2→3 战斗相位")


func _probe_p4_rescue_run_mode() -> void:
	_reset_gm()
	GameManager.rescue_run_target_ids = ["probe_m1"]
	var squad := Squad.new()
	squad.build([GameManager.find_mercenary_by_id("probe_m1")])
	var run := WorldRun.new("grassland", squad)
	RescueRunService.apply(GameManager, run)
	if run.run_mode != WorldRun.RunMode.RESCUE:
		_fail("P4a", "应进入 RESCUE 模式")
		return
	if not bool(run.map_data.get("disable_mob_spawns", false)):
		_fail("P4a", "救援队应禁用刷怪")
		return
	_pass("P4a", "RESCUE 避战 Run 配置")


func _probe_p4_rescue_success_morgue() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P4b", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "p4_pool",
			"map_id": "grassland",
			"total": 300,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	var result: Dictionary = {
		"map_id": "grassland",
		"rescue_target_ids": ["probe_m1"],
		"squad_member_ids": ["probe_m2"],
		"settlement_tier": "rescue",
	}
	GameManager._apply_rescue_settlement(result)
	if merc.is_mia:
		_fail("P4b", "运尸后应清 is_mia")
		return
	if not merc.is_morgue_pending:
		_fail("P4b", "运尸后应入停尸间")
		return
	if GameManager.get_morgue_entries().is_empty():
		_fail("P4b", "停尸间应有条目")
		return
	if GameManager.get_frozen_exp_for_merc("probe_m1") > 0:
		_fail("P4b", "运尸应清冻结池（不取 B-6）")
		return
	_pass("P4b", "救援成功→停尸间·清地图遗留")


func _probe_p4_rescue_failure_injury_cd() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P4c", "探针佣兵缺失")
		return
	m1.enter_mia_state()
	var rescuer := _ensure_probe_normal("probe_rescuer", "救援队员")
	rescuer.level = 4
	rescuer.refresh_base_stats()
	rescuer.current_hp = rescuer.get_max_hp_value()
	var result: Dictionary = {
		"squad_member_ids": ["probe_rescuer"],
		"settlement_tier": "rescue_fail",
	}
	MorgueService.apply_failure_injury_cd(GameManager, result)
	if rescuer.is_mia:
		_fail("P4c", "救援失败队员不应 MIA")
		return
	if not rescuer.is_on_rescue_injury_cd():
		_fail("P4c", "救援失败应进养伤 CD")
		return
	if not m1.is_mia:
		_fail("P4c", "原遗留应仍在地图")
		return
	_pass("P4c", "B-12f 救援失败·养伤 CD·原 MIA 仍在")


func _probe_p4_morgue_medical_revive() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P4d", "探针佣兵缺失")
		return
	merc.enter_morgue_pending()
	MorgueService.admit_corpse(GameManager, "probe_m1", "grassland")
	GameManager.gold = 99999
	var code: int = GameManager.try_morgue_medical_revive("probe_m1")
	if code != 0:
		_fail("P4d", "医疗复活返回 %d" % code)
		return
	if merc.is_morgue_pending:
		_fail("P4d", "医疗后应清停尸间状态")
		return
	if not merc.is_alive:
		_fail("P4d", "医疗后应 is_alive")
		return
	if not merc.is_near_death:
		_fail("P4d", "医疗后应濒死养伤")
		return
	if not GameManager.get_morgue_entries().is_empty():
		_fail("P4d", "停尸间队列应移除")
		return
	_pass("P4d", "停尸间医疗复活")


func _probe_p4_rescue_squad_rebuild() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P4e", "探针佣兵缺失")
		return
	m1.enter_mia_state()
	RescueSquadService.rebuild_from_roster(GameManager)
	var deploy: Array[Mercenary] = RescueSquadService.resolve_deploy_squad(GameManager)
	if deploy.is_empty():
		_fail("P4e", "第三队应能编入健康佣兵")
		return
	if m1.merc_id in GameManager.rescue_squad.get("active", []):
		_fail("P4e", "MIA 不应进救援队")
		return
	_pass("P4e", "rescue_squad 自动编制")


func _probe_p5_recovery_fail_grants_scroll() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P5a", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	var result: Dictionary = {
		"settlement_tier": "recovery_fail",
		"recovery_target_ids": ["probe_m1"],
		"map_id": "grassland",
	}
	ReturnScrollService.grant_for_recovery_fail(GameManager, result)
	if not bool(result.get("return_scroll_granted", false)):
		_fail("P5a", "回收失败应发卷轴")
		return
	if ReturnScrollService.count_for_merc(GameManager, "probe_m1") < 1:
		_fail("P5a", "卷轴应绑定 probe_m1")
		return
	_pass("P5a", "B-7 回收失败→回城卷轴")


func _probe_p5_instant_recovery_success() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P5b", "探针佣兵缺失")
		return
	merc.enter_mia_state()
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "p5_pool",
			"map_id": "grassland",
			"total": 400,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	GameManager.gold = 99999
	var code: int = GameManager.try_instant_mia_recovery("probe_m1", false)
	if code != 0:
		_fail("P5b", "读条一键返回 %d" % code)
		return
	if merc.is_mia:
		_fail("P5b", "一键后应清 MIA")
		return
	if not merc.is_near_death:
		_fail("P5b", "一键后应濒死回营")
		return
	_pass("P5b", "读条一键回收成功")


func _probe_p5_scroll_discount() -> void:
	_reset_gm()
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("P5c", "探针佣兵缺失")
		return
	var no_scroll: int = InstantRecoveryService.gold_cost(GameManager, merc, false)
	var with_scroll: int = InstantRecoveryService.gold_cost(GameManager, merc, true)
	if with_scroll >= no_scroll:
		_fail("P5c", "卷轴应减价 (no=%d with=%d)" % [no_scroll, with_scroll])
		return
	_pass("P5c", "卷轴减价读条一键")


func _probe_p5_rescue_fail_no_scroll() -> void:
	_reset_gm()
	var before: int = ReturnScrollService.normalize_meta(GameManager).size()
	var result: Dictionary = {
		"settlement_tier": "rescue_fail",
		"recovery_target_ids": ["probe_m1"],
	}
	ReturnScrollService.grant_for_recovery_fail(GameManager, result)
	var after: int = ReturnScrollService.normalize_meta(GameManager).size()
	if after != before:
		_fail("P5d", "救援队失败不应发卷轴")
		return
	_pass("P5d", "B-12f 救援失败无卷轴")


func _probe_p5_scroll_consume() -> void:
	_reset_gm()
	GameManager.account_meta["return_scrolls"] = [{
		"scroll_id": "probe_scroll",
		"member_ids": ["probe_m1"],
		"run_id": "x",
		"map_id": "grassland",
	}]
	if not ReturnScrollService.consume_for_merc(GameManager, "probe_m1"):
		_fail("P5e", "应可消耗卷轴")
		return
	if ReturnScrollService.count_for_merc(GameManager, "probe_m1") > 0:
		_fail("P5e", "消耗后应无卷轴")
		return
	_pass("P5e", "卷轴绑批消耗")


func _probe_p6_mia_settlement_records_half() -> void:
	_reset_gm()
	GameManager.last_deploy_half = "A"
	var result: Dictionary = {
		"settlement_tier": "mia",
		"mia_count": 1,
		"squad_member_ids": ["probe_m1"],
	}
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P6a", "探针佣兵缺失")
		return
	m1.enter_mia_state()
	MutualRecoveryService.on_mia_settlement(GameManager, result)
	if str(GameManager.account_meta.get("mia_last_deploy_half", "")) != "A":
		_fail("P6a", "MIA 结算应记录 mia_last_deploy_half")
		return
	_pass("P6a", "MIA 结算记录出征半组")


func _probe_p6_pick_target_opposite_half() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P6b", "探针佣兵缺失")
		return
	m1.enter_mia_state()
	GameManager.account_meta["mia_last_deploy_half"] = "A"
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "p6_pool",
			"map_id": "grassland",
			"total": 100,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	var target: String = MutualRecoveryService.pick_target(GameManager, "B")
	if target != "probe_m1":
		_fail("P6b", "B 半组应互捞 probe_m1 (got %s)" % target)
		return
	_pass("P6b", "对半组互捞目标选择")


func _probe_p6_start_run_auto_recovery() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P6c", "探针佣兵缺失")
		return
	m1.enter_mia_state()
	GameManager.account_meta["mia_last_deploy_half"] = "A"
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "p6_pool",
			"map_id": "grassland",
			"total": 100,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	GameManager.state = GameManager.GameState.PREPARE
	GameManager.selected_map_id = "grassland"
	_setup_p6_b_half_deploy()
	var code: int = GameManager.start_run(false)
	if code != 0:
		_fail("P6c", "互捞出征启动 %d" % code)
		return
	if GameManager.current_run == null:
		_fail("P6c", "应创建 current_run")
		return
	if GameManager.current_run.run_mode != WorldRun.RunMode.RECOVERY:
		_fail("P6c", "互捞应为 RECOVERY 模式")
		return
	if "probe_m1" not in GameManager.current_run.recovery_target_ids:
		_fail("P6c", "应带 recovery_target probe_m1")
		return
	GameManager.current_run = null
	GameManager.state = GameManager.GameState.BASE
	_pass("P6c", "start_run 自动互捞短程回收")


func _probe_p6_skip_mutual_normal() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P6d", "探针佣兵缺失")
		return
	m1.enter_mia_state()
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "p6_pool",
			"map_id": "grassland",
			"total": 100,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	GameManager.state = GameManager.GameState.PREPARE
	GameManager.selected_map_id = "grassland"
	_setup_p6_b_half_deploy()
	var code: int = GameManager.start_run(true)
	if code != 0:
		_fail("P6d", "正常出征启动 %d" % code)
		return
	if GameManager.current_run.run_mode == WorldRun.RunMode.RECOVERY:
		_fail("P6d", "跳过互捞应为 NORMAL/非 RECOVERY")
		return
	GameManager.current_run = null
	GameManager.state = GameManager.GameState.BASE
	_pass("P6d", "B-10a 跳过互捞→正常远征")


func _probe_p6_auto_disabled() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("P6e", "探针佣兵缺失")
		return
	m1.enter_mia_state()
	GameManager.account_meta["mia_last_deploy_half"] = "A"
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "p6_pool",
			"map_id": "grassland",
			"total": 100,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	MutualRecoveryService.set_auto_enabled(GameManager, false)
	if MutualRecoveryService.pick_target(GameManager, "B") == "":
		_fail("P6e", "应有互捞目标供对照")
		return
	GameManager.state = GameManager.GameState.PREPARE
	GameManager.selected_map_id = "grassland"
	_setup_p6_b_half_deploy()
	var code: int = GameManager.start_run(false)
	if code != 0:
		_fail("P6e", "出征 %d" % code)
		return
	if GameManager.current_run.run_mode == WorldRun.RunMode.RECOVERY:
		_fail("P6e", "关闭互捞后不应 RECOVERY")
		return
	GameManager.current_run = null
	GameManager.state = GameManager.GameState.BASE
	MutualRecoveryService.set_auto_enabled(GameManager, true)
	_pass("P6e", "关闭互捞自动时不劫持出征")


func _probe_p7_rescue_locked_without_building() -> void:
	_reset_gm()
	GameManager.buildings["rescue_station"]["level"] = 0
	MorgueService.sync_rescue_unlock_meta(GameManager)
	if MorgueService.is_rescue_unlocked(GameManager):
		_fail("P7a", "救援站 Lv.0 应未解锁")
		return
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	m1.enter_mia_state()
	GameManager.account_meta["frozen_exp_pools"] = [
		MiaDeteriorationService.enrich_new_pool({
			"run_id": "p7_pool",
			"map_id": "grassland",
			"total": 100,
			"mia_count": 1,
			"field_count": 2,
			"mia_ratio": 0.5,
			"timestamp": 1,
			"member_ids": ["probe_m1"],
		}),
	]
	var code: int = GameManager.start_rescue_run("probe_m1")
	if code != -7:
		_fail("P7a", "未解锁救援队应返回 -7 (got %d)" % code)
		return
	_pass("P7a", "救援站 Lv.0 禁止救援队出征")


func _probe_p7_rescue_unlock_after_upgrade() -> void:
	_reset_gm()
	GameManager.buildings["rescue_station"]["level"] = 0
	MorgueService.sync_rescue_unlock_meta(GameManager)
	if not GameManager.upgrade_building("rescue_station"):
		_fail("P7b", "升级救援站失败")
		return
	if not MorgueService.is_rescue_unlocked(GameManager):
		_fail("P7b", "救援站 Lv.1 应解锁")
		return
	if not bool(GameManager.account_meta.get("rescue_unlocked", false)):
		_fail("P7b", "account_meta.rescue_unlocked 应同步为 true")
		return
	_pass("P7b", "救援站 Lv.1 解锁救援队")


func _probe_v2_march_advance_visual() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var merc := _make_probe_normal("v2_m1", "视差探针")
	var squad := Squad.new()
	squad.build([merc])
	var run := WorldRun.new("grassland", squad)
	run.is_active = true
	run.is_retreating = false
	run.distance_traveled = 40.0
	lane.on_run_started(run, 1)
	lane.on_world_tick(run, true)
	var snap: Dictionary = lane.get_snapshot()
	if str(snap.get("lane_state", "")) != "MarchAdvance":
		_fail("V2a", "进军应为 MarchAdvance (got %s)" % str(snap.get("lane_state", "")))
		lane.queue_free()
		return
	var parallax := lane.get_node_or_null("ParallaxBackdrop")
	var march_view := lane.get_node_or_null("RunMarchView")
	if parallax == null or not parallax.visible:
		_fail("V2a", "ParallaxBackdrop 应可见")
		lane.queue_free()
		return
	if march_view == null or not march_view.visible:
		_fail("V2a", "RunMarchView 进军应可见")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("V2a", "T-RUN-V2 进军视差+行军队列")


func _probe_v2_march_retreat_visual() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var merc := _make_probe_normal("v2_m2", "视差探针2")
	var squad := Squad.new()
	squad.build([merc])
	var run := WorldRun.new("grassland", squad)
	run.is_active = true
	run.is_retreating = true
	run.distance_traveled = 80.0
	lane.on_run_started(run, 1)
	lane.on_world_tick(run, true)
	var snap: Dictionary = lane.get_snapshot()
	if str(snap.get("lane_state", "")) != "MarchRetreat":
		_fail("V2b", "返程应为 MarchRetreat")
		lane.queue_free()
		return
	var march_view := lane.get_node_or_null("RunMarchView")
	if march_view == null or not march_view.visible:
		_fail("V2b", "返程 RunMarchView 应可见")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("V2b", "T-RUN-V2 返程行军表现")


func _probe_v3_stub_enemy() -> Dictionary:
	return {
		"uid": "probe_v3_gob",
		"name": "探针哥布林",
		"stats": {"hp": 40, "patk": 5, "pdef": 2, "mdef": 1, "spd": 4},
	}


func _probe_v3_combat_anchor_spawn() -> void:
	var merc := _make_probe_normal("v3_m1", "锚点探针")
	var squad := Squad.new()
	squad.build([merc])
	var enemy: Array = [_probe_v3_stub_enemy()]
	var run_near := WorldRun.new("grassland", squad)
	run_near.distance_traveled = 0.0
	run_near.max_distance = 600.0
	var ctrl_near := CombatController.new()
	ctrl_near.init_combat(squad, enemy, run_near, 0.0)
	if ctrl_near.allies.is_empty() or ctrl_near.enemies.is_empty():
		_fail("V3a", "接战应生成友敌实体")
		return
	var ally_near: float = ctrl_near.allies[0].position
	var enemy_near: float = ctrl_near.enemies[0].position
	if enemy_near <= ally_near:
		_fail("V3a", "敌应在友右 (near ally=%.1f enemy=%.1f)" % [ally_near, enemy_near])
		return
	var run_far := WorldRun.new("grassland", squad)
	run_far.distance_traveled = 360.0
	run_far.max_distance = 600.0
	var ctrl_far := CombatController.new()
	ctrl_far.init_combat(squad, enemy, run_far, 360.0)
	var ally_far: float = ctrl_far.allies[0].position
	if ally_far <= ally_near + 1.0:
		_fail("V3a", "深程锚点应右移友方 (near=%.1f far=%.1f)" % [ally_near, ally_far])
		return
	if ctrl_far.get_party_anchor_shift() <= ctrl_near.get_party_anchor_shift():
		_fail("V3a", "anchor_shift 应随里程增加")
		return
	_pass("V3a", "T-RUN-V3 接战锚点+敌偏右入画")


func _probe_v3_lane_anchor_freeze() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = false
	run.max_distance = 600.0
	run.distance_traveled = 180.0
	lane.on_run_started(run, 2)
	lane.on_combat_start(run, false)
	var frozen_anchor: float = lane.party_anchor_x
	run.distance_traveled = 420.0
	lane.on_world_tick(run, false)
	if absf(lane.party_anchor_x - frozen_anchor) > 0.01:
		_fail("V3b", "进军接战应冻结 party_anchor (%.1f vs %.1f)" % [frozen_anchor, lane.party_anchor_x])
		lane.queue_free()
		return
	if absf(lane.scroll_x - frozen_anchor) > 0.01:
		_fail("V3b", "进军接战应冻结 scroll_x")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("V3b", "T-RUN-V3 接战锚点冻结")


func _probe_v4_retreat_combat_scroll() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = true
	run.max_distance = 600.0
	run.distance_traveled = 280.0
	lane.on_run_started(run, 2)
	lane.on_combat_start(run, false)
	if lane.get_snapshot().get("freeze_distance", true):
		_fail("V4a", "返程接战不应 freeze_distance")
		lane.queue_free()
		return
	run.distance_traveled = 240.0
	lane.on_world_tick(run, true)
	var snap: Dictionary = lane.get_snapshot()
	if float(snap.get("scroll_x", 0.0)) > 250.0:
		_fail("V4a", "返程接战 world tick 应减少 scroll_x")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("V4a", "T-RUN-V4 返程接战距离/视差继续左撤")


func _probe_v4_advance_combat_parallax_frozen() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = false
	run.max_distance = 600.0
	run.distance_traveled = 120.0
	lane.on_run_started(run, 2)
	lane.on_combat_start(run, false)
	if not lane.get_snapshot().get("freeze_distance", false):
		_fail("V4b", "进军接战应 freeze_distance")
		lane.queue_free()
		return
	run.distance_traveled = 200.0
	lane.on_world_tick(run, false)
	if absf(lane.scroll_x - 120.0) > 0.01:
		_fail("V4b", "进军接战应冻结 scroll_x")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("V4b", "T-RUN-V4 进军接战视差停滚")


func _probe_v4_parallax_retreat_direction() -> void:
	var pb: Control = _ParallaxBackdropScene.new()
	pb.size = Vector2(400, 48)
	add_child(pb)
	pb.apply_scroll(300.0, true, false, 1.0)
	var x_far: float = pb.first_layer_offset_x()
	pb.apply_scroll(180.0, true, false, 1.0)
	var x_near: float = pb.first_layer_offset_x()
	pb.queue_free()
	if x_near >= x_far:
		_fail("V4c", "返程里程减时视差应左移 (far=%.2f near=%.2f)" % [x_far, x_near])
		return
	pb = _ParallaxBackdropScene.new()
	pb.size = Vector2(400, 48)
	add_child(pb)
	pb.apply_scroll(100.0, false, true, 1.0)
	var x_frozen_a: float = pb.first_layer_offset_x()
	pb.apply_scroll(250.0, false, true, 1.0)
	var x_frozen_b: float = pb.first_layer_offset_x()
	pb.queue_free()
	if absf(x_frozen_a - x_frozen_b) > 0.01:
		_fail("V4c", "进军接战冻结时视差不应随里程变化")
		return
	_pass("V4c", "T-RUN-V4 返程视差左向 + 进军接战静止")


func _probe_v5_boss_chase_silhouette() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = true
	run.max_distance = 600.0
	run.distance_traveled = 200.0
	run.boss_chase_active = true
	run.boss_chase_position = run.distance_traveled + 110.0
	lane.on_run_started(run, 2)
	lane.on_world_tick(run, true)
	var snap_far: Dictionary = lane.get_snapshot()
	if not bool(snap_far.get("boss_chase_silhouette_visible", false)):
		_fail("V5a", "返程 Boss 追击应显示剪影")
		lane.queue_free()
		return
	var silhouette := lane.get_node_or_null("BossChaseSilhouette")
	if silhouette == null:
		_fail("V5a", "BossChaseSilhouette 节点缺失")
		lane.queue_free()
		return
	var x_far: float = silhouette.get_body_x()
	run.boss_chase_position = run.distance_traveled + 30.0
	lane.on_world_tick(run, true)
	var x_near: float = silhouette.get_body_x()
	if x_near >= x_far - 4.0:
		_fail("V5a", "gap 缩小时剪影应更靠左 (far=%.1f near=%.1f)" % [x_far, x_near])
		lane.queue_free()
		return
	lane.on_combat_start(run, false)
	lane.on_world_tick(run, true)
	if lane.get_snapshot().get("boss_chase_silhouette_visible", true):
		_fail("V5a", "接战时不应显示 Boss 追击剪影")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("V5a", "T-RUN-V5 Boss 追击剪影可见且随 gap 逼近")


func _probe_v5_combat_resume_delay() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = true
	run.max_distance = 600.0
	run.distance_traveled = 150.0
	lane.on_run_started(run, 2)
	lane.on_combat_start(run, false)
	lane.on_combat_end(run)
	var snap_pending: Dictionary = lane.get_snapshot()
	if not bool(snap_pending.get("combat_resume_pending", false)):
		_fail("V5b", "接战结束应进入 resume 延迟")
		lane.queue_free()
		return
	if float(snap_pending.get("combat_resume_remaining", 0.0)) <= 0.0:
		_fail("V5b", "resume 剩余时间应 > 0")
		lane.queue_free()
		return
	var march_view := lane.get_node_or_null("RunMarchView")
	if march_view != null and march_view.visible:
		_fail("V5b", "延迟期间 RunMarchView 应隐藏")
		lane.queue_free()
		return
	if str(snap_pending.get("lane_state", "")) == "MarchRetreat":
		_fail("V5b", "延迟期间 lane_state 不应已恢复行军")
		lane.queue_free()
		return
	lane.advance_combat_resume(RunMarchLane.COMBAT_RESUME_DELAY_SEC + 0.05)
	var snap_done: Dictionary = lane.get_snapshot()
	if bool(snap_done.get("combat_resume_pending", true)):
		_fail("V5b", "延迟结束后应清除 combat_resume_pending")
		lane.queue_free()
		return
	if str(snap_done.get("lane_state", "")) != "MarchRetreat":
		_fail("V5b", "延迟结束后应恢复 MarchRetreat (got %s)" % str(snap_done.get("lane_state", "")))
		lane.queue_free()
		return
	if march_view == null or not march_view.visible:
		_fail("V5b", "延迟结束后 RunMarchView 应可见")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("V5b", "T-RUN-V5 接战结束 0.3s 恢复行军抛光")


func _probe_b15_map_card_select_deploy_split() -> void:
	var card := MapCardButton.new()
	card.size = Vector2(420, 120)
	add_child(card)
	var sel_holder: Dictionary = {"id": ""}
	var dep_holder: Dictionary = {"id": ""}
	card.card_selected.connect(func(id: String) -> void: sel_holder["id"] = id)
	card.deploy_pressed.connect(func(id: String) -> void: dep_holder["id"] = id)
	var md: Dictionary = {
		"map_id": "grassland",
		"name": "草原",
		"boss_distance": 600.0,
		"danger_level": 1,
		"description": "新手草原",
	}
	card.setup(md, false, false, true)
	var deploy_unselected := 0
	for c in card.get_children():
		if c is Button and str(c.text) == "出征":
			deploy_unselected += 1
	if deploy_unselected != 0:
		_fail("B1.5a", "未选中卡不应显示出征钮")
		card.queue_free()
		return
	for c in card.get_children():
		if c is Button and c.name == "SelectHit":
			(c as Button).pressed.emit()
			break
	if str(sel_holder.get("id", "")) != "grassland":
		_fail("B1.5a", "card_selected 信号应携带 map_id")
		card.queue_free()
		return
	if str(dep_holder.get("id", "")) != "":
		_fail("B1.5a", "选中不应触发 deploy_pressed")
		card.queue_free()
		return
	card.setup(md, true, false, true)
	var deploy_h: float = 0.0
	for c in card.get_children():
		if c is Button and str(c.text) == "出征":
			deploy_h = c.custom_minimum_size.y
			c.pressed.emit()
			break
	if deploy_h < 36.0:
		_fail("B1.5a", "出征钮高度应 ≥36px (got %.0f)" % deploy_h)
		card.queue_free()
		return
	if str(dep_holder.get("id", "")) != "grassland":
		_fail("B1.5a", "出征钮应单独 emit deploy_pressed")
		card.queue_free()
		return
	card.queue_free()
	_pass("B1.5a", "T-UI-B1.5 地图选中/出征分离 + 出征钮≥36px")


func _probe_b15_dock_button_min_height() -> void:
	if MapCardButton.DEPLOY_BTN_H < 36:
		_fail("B1.5b", "出征钮高度契约应 ≥36px (got %d)" % MapCardButton.DEPLOY_BTN_H)
		return
	var shell_src: String = FileAccess.get_file_as_string("res://scripts/ui/main_shell.gd")
	if shell_src.contains('_dock_buttons["redeploy"]'):
		_fail("B1.5b", "Dock 仍含「再战」重复按钮注册")
		return
	if not shell_src.contains("custom_minimum_size = Vector2(72, 36)"):
		_fail("B1.5b", "Dock 按钮应固定 ≥36px 高")
		return
	_pass("B1.5b", "T-UI-B1.5 点击目标≥36px · Dock 无再战重复项")


func _probe_b2_top_stability_bar() -> void:
	var shell_src: String = FileAccess.get_file_as_string("res://scripts/ui/main_shell.gd")
	if not shell_src.contains("_top_stability_bar"):
		_fail("B2a", "顶栏应含稳定度 ProgressBar")
		return
	if not shell_src.contains("apply_run_snapshot"):
		_fail("B2a", "MainShell 应同步 RUNNING 稳定度快照")
		return
	if not shell_src.contains("get_recovery_lock_message"):
		_fail("B2a", "养伤锁文案应走 SquadFormationService")
		return
	var driver_src: String = FileAccess.get_file_as_string("res://scripts/run/run_driver.gd")
	if not driver_src.contains("apply_run_snapshot"):
		_fail("B2a", "run_driver 应推送顶栏稳定度")
		return
	_pass("B2a", "T-UI-B2 顶栏稳定条 + 养伤锁上移契约")


func _probe_b2_run_ui_stability_relocated() -> void:
	var run_src: String = FileAccess.get_file_as_string("res://scripts/ui/run_ui.gd")
	if not run_src.contains("bind_main_shell"):
		_fail("B2b", "RunUI 应绑定 MainShell 并隐藏底栏稳定度")
		return
	if not run_src.contains("_stability_in_top_bar"):
		_fail("B2b", "RunUI 应跳过底栏稳定度刷新")
		return
	var base_src: String = FileAccess.get_file_as_string("res://scripts/ui/base_ui.gd")
	if base_src.contains("团队稳定度"):
		_fail("B2b", "base_ui 金币行不应再堆稳定度文案")
		return
	_pass("B2b", "T-UI-B2 底栏稳定度迁出顶栏")


func _probe_b3_formation_slot_card() -> void:
	var card: Control = _FormationSlotCardScene.new()
	card.size = Vector2(220, 48)
	add_child(card)
	card.apply_slot(
		"",
		"active",
		0,
		false,
		false,
		"(空槽)",
		0.0,
		"",
		Color(0.3, 0.32, 0.38),
		Color(0.1, 0.11, 0.14)
	)
	if card.custom_minimum_size.y < 36:
		_fail("B3a", "编组槽卡高度应 ≥36px")
		card.queue_free()
		return
	var hp_bar := card.find_child("SlotHpBar", true, false)
	if hp_bar == null:
		_fail("B3a", "编组槽卡应含 HP 条")
		card.queue_free()
		return
	card.apply_slot(
		"probe_m1",
		"active",
		0,
		true,
		true,
		"探针佣兵 Lv.1",
		0.85,
		"可出战",
		Color(0.38, 0.72, 0.95),
		Color(0.15, 0.2, 0.28)
	)
	var hit := card.get_child(card.get_child_count() - 1)
	if not (hit is Button):
		_fail("B3a", "编组槽卡应含点击热区")
		card.queue_free()
		return
	card.queue_free()
	_pass("B3a", "T-UI-B3 FormationSlotCard 卡牌≥36px + HP条")


func _probe_b3_half_stage_panel() -> void:
	var form_src: String = FileAccess.get_file_as_string("res://scripts/ui/formation_ui.gd")
	if not form_src.contains("FormationSlotCard"):
		_fail("B3b", "formation_ui 应使用 FormationSlotCard")
		return
	if not form_src.contains("_apply_half_stage_style"):
		_fail("B3b", "半组应使用舞台 Panel 样式")
		return
	if not form_src.contains("_make_slot_card"):
		_fail("B3b", "应通过 _make_slot_card 构建槽位")
		return
	_pass("B3b", "T-UI-B3 双半组舞台 + 槽位卡牌化")


func _probe_b4_camp_bag_grid() -> void:
	var bag_ui: Control = _BaseCampBagUIScene.new()
	bag_ui.size = Vector2(200, 180)
	add_child(bag_ui)
	if bag_ui.has_method("refresh"):
		bag_ui.refresh()
	if _BaseCampBagUIScene.CELL_PX < 12:
		_fail("B4a", "大营背包格像素应 ≥12")
		bag_ui.queue_free()
		return
	var host := bag_ui.find_child("CampBagGridHost", true, false)
	if host == null:
		_fail("B4a", "应含 CampBagGridHost 网格宿主")
		bag_ui.queue_free()
		return
	if host.get_child_count() < 4:
		_fail("B4a", "空背包也应绘制底格")
		bag_ui.queue_free()
		return
	bag_ui.queue_free()
	_pass("B4a", "T-UI-B4 BaseCampBagUI 网格预览")


func _probe_b4_base_ui_bag_integration() -> void:
	var base_src: String = FileAccess.get_file_as_string("res://scripts/ui/base_ui.gd")
	if not base_src.contains("BaseCampBagUI") and not base_src.contains("base_camp_bag_ui"):
		_fail("B4b", "base_ui 应接入大营背包网格")
		return
	if base_src.contains("BagPlaceholder"):
		_fail("B4b", "应移除 BagPlaceholder 纯文案占位")
		return
	var camp_src: String = FileAccess.get_file_as_string("res://scripts/ui/base_camp_bag_ui.gd")
	var run_src: String = FileAccess.get_file_as_string("res://scripts/ui/run_grid_ui.gd")
	if not run_src.contains("安全箱") or not camp_src.contains("大营背包"):
		_fail("B4b", "大营背包与出征网格应文案区分")
		return
	_pass("B4b", "T-UI-B4 右窗背包网格接入 + 与 RunGrid 区分")


func _probe_m2_milestone_fire_once() -> void:
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.distance_traveled = 80.0
	var hits: Array = _MarchEventService.tick(run, true)
	if hits.is_empty():
		_fail("M2a", "80m 应触发 abandoned_crate 里程碑")
		return
	var data: Dictionary = hits[0].get("data", {})
	if str(data.get("event_id", "")) != "abandoned_crate":
		_fail("M2a", "80m 事件应为 abandoned_crate (got %s)" % str(data.get("event_id", "")))
		return
	if run.march_events_fired.size() != 1:
		_fail("M2a", "应登记 1 条已触发里程碑")
		return
	var again: Array = _MarchEventService.tick(run, true)
	if not again.is_empty():
		_fail("M2a", "同里程不应重复触发")
		return
	var dists: Array = _MarchEventService.milestone_distances(run.map_data)
	if dists.size() < 2 or float(dists[0]) != 80.0:
		_fail("M2a", "地图 march_events 应含 80m 锚点")
		return
	_pass("M2a", "T-MARCH-M2 里程碑触发一次 + 地图锚点")


func _probe_m2_milestone_pause_rules() -> void:
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.distance_traveled = 200.0
	run.chase_combat_in_progress = true
	if not _MarchEventService.tick(run, true).is_empty():
		_fail("M2b", "追击接战期间不应触发里程碑")
		return
	run.chase_combat_in_progress = false
	run.is_retreating = true
	if not _MarchEventService.tick(run, true).is_empty():
		_fail("M2b", "返程期间不应触发进军里程碑")
		return
	run.is_retreating = false
	if not _MarchEventService.tick(run, false).is_empty():
		_fail("M2b", "allowed=false 时不应触发")
		return
	_pass("M2b", "T-MARCH-M2 接战/返程/暂停门禁")


func _probe_mv2_lane_markers_from_map() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = false
	run.distance_traveled = 0.0
	lane.on_run_started(run, 2)
	lane.on_world_tick(run, true)
	var markers := lane.get_node_or_null("MarchEventMarkers")
	if markers == null:
		_fail("MV2a", "RunMarchLane 应含 MarchEventMarkers")
		lane.queue_free()
		return
	if not markers.visible:
		_fail("MV2a", "进军起步应显示里程碑标记")
		lane.queue_free()
		return
	if markers.get_marker_count() < 2:
		_fail("MV2a", "grassland 应绘制≥2 个前方里程碑 (got %d)" % markers.get_marker_count())
		lane.queue_free()
		return
	run.distance_traveled = 85.0
	run.march_events_fired = [0]
	lane.on_world_tick(run, true)
	if markers.get_marker_count() < 1:
		_fail("MV2a", "触发 80m 后应仍显示前方里程碑")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("MV2a", "T-MARCH-V2 地图里程碑标记跟 scroll_x")


func _probe_mv2_markers_hide_on_retreat() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = true
	run.distance_traveled = 40.0
	lane.on_run_started(run, 2)
	lane.on_world_tick(run, true)
	var markers := lane.get_node_or_null("MarchEventMarkers")
	if markers == null:
		_fail("MV2b", "应含 MarchEventMarkers")
		lane.queue_free()
		return
	if markers.visible and markers.get_marker_count() > 0:
		_fail("MV2b", "返程不应显示进军里程碑")
		lane.queue_free()
		return
	lane.on_combat_start(run, false)
	lane.on_world_tick(run, false)
	markers = lane.get_node_or_null("MarchEventMarkers")
	if markers != null and markers.visible and markers.get_marker_count() > 0:
		_fail("MV2b", "接战期间不应显示里程碑")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("MV2b", "T-MARCH-V2 返程/接战隐藏里程碑")


func _probe_mv3_gather_deferred_loot() -> void:
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.distance_traveled = 80.0
	var hits: Array = _MarchEventService.tick(run, true)
	if hits.is_empty():
		_fail("MV3a", "80m abandoned_crate 应触发 gather 事件")
		return
	var data: Dictionary = hits[0].get("data", {})
	if not bool(data.get("gather_beat", false)):
		_fail("MV3a", "abandoned_crate 应标记 gather_beat")
		return
	if not bool(data.get("effects_deferred", false)):
		_fail("MV3a", "loot 事件应延迟结算")
		return
	if data.has("material_names"):
		_fail("MV3a", "延迟结算前不应已有物资名")
		return
	var pending: Array = data.get("pending_effects", [])
	if pending.is_empty():
		_fail("MV3a", "应保留 pending_effects")
		return
	var before_loot: int = run.exposed_loot.item_count() if run.exposed_loot else 0
	_MarchEventService.apply_pending_effects(run, data)
	if data.get("effects_applied", []).is_empty():
		_fail("MV3b", "结算后应记录 effects_applied")
		return
	var after_loot: int = run.exposed_loot.item_count() if run.exposed_loot else 0
	if after_loot <= before_loot and not data.has("material_names"):
		_fail("MV3b", "结算后应获得物资或 material_names")
		return
	_pass("MV3a", "T-MARCH-V3 loot 事件延迟至 GATHER_BEAT 后结算")
	_pass("MV3b", "T-MARCH-V3 apply_pending_effects 落地物资")


func _probe_mv3_lane_gather_beat_state() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.distance_traveled = 80.0
	lane.on_run_started(run, 2)
	lane.on_march_event({
		"event_id": "abandoned_crate",
		"gather_beat": true,
		"at_distance": 80.0,
	})
	if not lane.is_gather_active():
		_fail("MV3c", "gather_beat 应激活 GATHER_BEAT")
		lane.queue_free()
		return
	var snap: Dictionary = lane.get_snapshot()
	if str(snap.get("lane_state", "")) != "GatherBeat":
		_fail("MV3c", "lane_state 应为 GatherBeat (got %s)" % str(snap.get("lane_state", "")))
		lane.queue_free()
		return
	var gather_view := lane.get_node_or_null("MarchGatherView")
	if gather_view == null or not gather_view.visible:
		_fail("MV3c", "MarchGatherView 搜刮中应可见")
		lane.queue_free()
		return
	var march_view := lane.get_node_or_null("RunMarchView")
	if march_view != null and march_view.visible:
		_fail("MV3c", "搜刮中 RunMarchView 应隐藏")
		lane.queue_free()
		return
	lane.on_gather_end()
	if lane.is_gather_active():
		_fail("MV3d", "on_gather_end 应清除 gather_active")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("MV3c", "T-MARCH-V3 GATHER_BEAT 冻结里程+采集视图")
	_pass("MV3d", "T-MARCH-V3 采集结束恢复行军")


func _probe_mia_excluded_from_formation() -> void:
	_reset_gm()
	GameManager.account_meta["seed_casualty_fixtures"] = true
	GameManager.ensure_save_casualty_fixtures()
	GameManager.squad_formation = {
		"active_half": "A",
		"A": {
			"active": ["elite_01", "fixture_mia_elite"],
			"bench": ["fixture_mia_normal", "normal_01"],
		},
		"B": {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	for half in ["A", "B"]:
		for mid in SquadFormationService._half_all_ids(GameManager.squad_formation, half):
			var m := GameManager.find_mercenary_by_id(mid)
			if m != null and m.is_mia:
				_fail("P2h", "遗留 %s 不应在 %s 半组槽位" % [m.merc_id, half])
				return
	if GameManager.get_mia_roster_entries().size() < 2:
		_fail("P2h", "ensure_formation 后遗留名册应仍≥2")
		return
	_pass("P2h", "遗留/阵亡不进 A/B 替补出战槽")


func _pass(id: String, detail: String) -> void:
	_passed.append("%s: %s" % [id, detail])
	print("[PASS] %s — %s" % [id, detail])


func _fail(id: String, detail: String) -> void:
	_failed.append("%s: %s" % [id, detail])
	push_error("[FAIL] %s — %s" % [id, detail])


func _print_report() -> void:
	print("—— Phase 1 逻辑探针 ——")
	print("PASS: %d" % _passed.size())
	for line in _passed:
		print("  ", line)
	if not _failed.is_empty():
		print("FAIL: %d" % _failed.size())
		for line in _failed:
			print("  ", line)
	else:
		print("ALL LOGIC PROBES PASSED (R2 UI 需 F5 手测)")
