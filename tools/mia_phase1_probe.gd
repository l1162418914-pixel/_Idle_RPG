extends Node
## Phase 1 MIA 回归探针（逻辑层）— godot --headless --path <根> --scene res://tools/MiaPhase1Probe.tscn

const _ParallaxBackdropScene = preload("res://scripts/ui/parallax_backdrop.gd")
const _FormationSlotCardScene = preload("res://scripts/ui/formation_slot_card.gd")
const _FormationPoolButtonScene = preload("res://scripts/ui/formation_pool_button.gd")
const _BaseCampBagUIScene = preload("res://scripts/ui/base_camp_bag_ui.gd")
const _MarchEventService = preload("res://scripts/run/march_event_service.gd")
const _MarchSearchService = preload("res://scripts/run/march_search_service.gd")
const _ArtManifest = preload("res://scripts/ui/art_manifest.gd")

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
	_probe_form_pool_button_clickable()
	_probe_b4_camp_bag_grid()
	_probe_b4_base_ui_bag_integration()
	_probe_m2_milestone_fire_once()
	_probe_m2_milestone_pause_rules()
	_probe_mv2_lane_markers_from_map()
	_probe_mv2_markers_hide_on_retreat()
	_probe_mv3_gather_deferred_loot()
	_probe_mv3_lane_gather_beat_state()
	_probe_m3_retreat_search_pool()
	_probe_m3_low_stability_weighting()
	_probe_m3_shield_depleted_blocks_loot()
	_probe_fw1_visual_constants()
	_probe_fw1_visual_slot()
	_probe_fw2_lane_visual_slots()
	_probe_fw2_gather_and_boss_slots()
	_probe_fw3_art_manifest()
	_probe_fw3_visual_slot_texture()
	_probe_t01_set_bonus_two_piece()
	_probe_t01_set_bonus_three_piece()
	_probe_t01_set_ui_progress_lines()
	_probe_t01_set_one_piece_no_bonus()
	_probe_t06_awakening_status_refresh()
	_probe_t06_buff_badges_visible()
	_probe_t06_awakening_badge_variant()
	_probe_t06_buff_badges_clear()
	_probe_t02_ranged_advance_toward_enemy()
	_probe_t02_ranged_enters_attack_range()
	_probe_t02_ranged_stays_behind_melee()
	_probe_t02_ranged_respects_forward_cap()
	_probe_02_dual_melee_tank_front()
	_probe_02_dual_melee_both_in_range()
	_probe_t03_elite_inherits_class_active_skills()
	_probe_t03_skill_cd_chip_shows_remaining()
	_probe_t03_skill_cd_chip_ready_state()
	_probe_t03_cooldown_from_template_on_cast()
	_probe_t04_battle_debug_toggle()
	_probe_t04_hp_multiplier_on_entity()
	_probe_t04_damage_scale()
	_probe_t04_test_map_auto_enable()
	_probe_t02c_merc_deploy_while_player_downed()
	_probe_t02c_deploy_excludes_player()
	_probe_t02c_recovery_lock_merc_only()
	_probe_t02c_merc_only_run_player_unchanged()
	_probe_t02c_strip_player_from_halves()
	_probe_t02c_no_lock_when_mercs_ready()
	_probe_t_ui_form_1_start_run_preserves_active_half()
	_probe_t_ui_form_2_manual_block_auto_fallback()
	_probe_t_ui_form_3r_recruit_stays_in_pool()
	_probe_t_ui_form_6_cross_half_assign()
	_probe_t_stab_half_aggregate()
	_probe_t_stab_half_ui_format()
	_probe_t_stab_half_display_combined_cap()
	_probe_t_stab_class_personal_max()
	_probe_t_stab_pool_cascade()
	_probe_t_ui_form_4_preferred_vs_deploy()
	_probe_t_ui_form_layout_1_summary()
	_probe_expedition_strategy_snapshot()
	_probe_expedition_push_blocks_auto_retreat()
	_probe_expedition_ui_retreat_row_layout()
	_probe_camp_1a_stage_lineup()
	_probe_stage_1a_bottom_stage()
	_probe_frame_1a_shell_zones()
	_probe_twin_1a_dual_window()
	_probe_m2c_search_blocked_during_combat()
	_probe_b3_grassland_march_events()
	_probe_c1_test_maps_march_events()
	_probe_02b_battlefield_slot_layout()
	_probe_02a_enemy_skips_downed()
	_probe_02a_downed_rear_snap()
	_probe_02a_only_downed_no_crash()
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
	var slot_src: String = FileAccess.get_file_as_string("res://scripts/ui/formation_slot_card.gd")
	var has_click_hit: bool = (
		slot_src.contains("MOUSE_FILTER_STOP")
		and (slot_src.contains("force_drag") or slot_src.contains("_get_drag_data"))
		and slot_src.contains("_on_hit_pressed")
		and slot_src.contains("_on_remove_pressed")
	)
	if not has_click_hit:
		_fail("B3a", "编组槽卡应支持点击/拖拽热区")
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


func _probe_form_pool_button_clickable() -> void:
	var pool_src: String = FileAccess.get_file_as_string("res://scripts/ui/formation_pool_button.gd")
	if not pool_src.contains("extends Button"):
		_fail("FORM-P1", "备战席按钮应继承 Button 以保证点击")
		return
	if not pool_src.contains("_get_drag_data"):
		_fail("FORM-P1", "备战席按钮应支持拖拽")
		return
	var form_src: String = FileAccess.get_file_as_string("res://scripts/ui/formation_ui.gd")
	if form_src.contains("FormationPoolScroll"):
		_fail("FORM-P2", "备战席不应嵌套内层 ScrollContainer（阻断点击）")
		return
	if not form_src.contains("MOUSE_FILTER_PASS"):
		_fail("FORM-P2", "备战席容器应放行鼠标到按钮")
		return
	var btn: Button = _FormationPoolButtonScene.new()
	btn.merc_id = "probe_pool_merc"
	add_child(btn)
	btn.apply_pool("探针佣兵", false, Color.WHITE, false)
	if btn.disabled:
		_fail("FORM-P1", "可出征备战席按钮不应 disabled")
		btn.queue_free()
		return
	if btn.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_fail("FORM-P1", "可出征备战席按钮 mouse_filter 不应 IGNORE")
		btn.queue_free()
		return
	btn.queue_free()
	_pass("FORM-P1", "备战席池按钮可点击 + 可拖拽")
	_pass("FORM-P2", "备战席无内层滚动 + 鼠标链放行")


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
	var has_80: bool = false
	for d in dists:
		if absf(float(d) - 80.0) < 0.01:
			has_80 = true
			break
	if dists.size() < 2 or not has_80:
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


func _probe_m3_retreat_search_pool() -> void:
	var cfg: Dictionary = DataLoader.map_data("grassland").get("march_search", {})
	var advance_id: String = _MarchSearchService.resolve_pool_id(cfg, false)
	var retreat_id: String = _MarchSearchService.resolve_pool_id(cfg, true)
	if advance_id != "grassland_search":
		_fail("M3a", "进军应使用 grassland_search (got %s)" % advance_id)
		return
	if retreat_id != "grassland_search_retreat":
		_fail("M3a", "返程应使用 grassland_search_retreat (got %s)" % retreat_id)
		return
	var advance_pool: Dictionary = DataLoader.march_search_pool(advance_id)
	var retreat_pool: Dictionary = DataLoader.march_search_pool(retreat_id)
	var ctx_advance: Dictionary = {"retreating": false, "team_stability": 80, "shields_depleted": false}
	var ctx_retreat: Dictionary = {"retreating": true, "team_stability": 80, "shields_depleted": false}
	var neg_advance: float = _MarchSearchService.pool_negative_weight_share(advance_pool, ctx_advance, cfg)
	var neg_retreat: float = _MarchSearchService.pool_negative_weight_share(retreat_pool, ctx_retreat, cfg)
	if neg_retreat <= neg_advance:
		_fail("M3b", "返程池负面占比应高于进军 (%.3f vs %.3f)" % [neg_retreat, neg_advance])
		return
	_pass("M3a", "T-MARCH-M3 返程分池 retreat_pool_id")
	_pass("M3b", "T-MARCH-M3 返程搜索负面权重更高")


func _probe_m3_low_stability_weighting() -> void:
	var pool: Dictionary = DataLoader.march_search_pool("grassland_search")
	var cfg: Dictionary = {}
	var entry: Dictionary = {"weight": 3, "result": "stability", "team_delta": -3}
	var mat_entry: Dictionary = {"weight": 18, "result": "material"}
	var ctx_high: Dictionary = {"retreating": false, "team_stability": 80, "shields_depleted": false}
	var ctx_low: Dictionary = {"retreating": false, "team_stability": 40, "shields_depleted": false}
	var neg_high: float = _MarchSearchService.entry_weight(entry, pool, ctx_high, cfg)
	var neg_low: float = _MarchSearchService.entry_weight(entry, pool, ctx_low, cfg)
	var mat_high: float = _MarchSearchService.entry_weight(mat_entry, pool, ctx_high, cfg)
	var mat_low: float = _MarchSearchService.entry_weight(mat_entry, pool, ctx_low, cfg)
	if neg_low <= neg_high:
		_fail("M3c", "稳定≤50 应提高负面条目权重")
		return
	if mat_low >= mat_high:
		_fail("M3c", "稳定≤50 应压低正面物资权重")
		return
	_pass("M3c", "T-MARCH-M3 低稳定加权")


func _probe_m3_shield_depleted_blocks_loot() -> void:
	var pool: Dictionary = DataLoader.march_search_pool("grassland_search_retreat")
	var cfg: Dictionary = {}
	var gold_entry: Dictionary = {"weight": 10, "result": "gold"}
	var neg_entry: Dictionary = {"weight": 12, "result": "stability", "team_delta": -2}
	var ctx_broken: Dictionary = {"retreating": true, "team_stability": 60, "shields_depleted": true}
	var ctx_ok: Dictionary = {"retreating": true, "team_stability": 60, "shields_depleted": false}
	if _MarchSearchService.entry_weight(gold_entry, pool, ctx_broken, cfg) != 0.0:
		_fail("M3d", "盾破后不应保留金币搜索权重")
		return
	if _MarchSearchService.entry_weight(neg_entry, pool, ctx_broken, cfg) <= 0.0:
		_fail("M3d", "盾破后仍应可触发负面搜索")
		return
	if _MarchSearchService.entry_weight(gold_entry, pool, ctx_ok, cfg) <= 0.0:
		_fail("M3d", "有盾时不应屏蔽金币搜索")
		return
	_pass("M3d", "T-MARCH-M3 盾破禁正面物资搜索")


func _probe_fw1_visual_constants() -> void:
	if VisualConstants.PARTY_SILHOUETTE_COLORS.is_empty():
		_fail("FW1a", "PARTY_SILHOUETTE_COLORS 不应为空")
		return
	if VisualConstants.party_color(0) != VisualConstants.PARTY_SILHOUETTE_COLORS[0]:
		_fail("FW1a", "party_color 应索引常量表")
		return
	var spec: Dictionary = VisualConstants.placeholder_spec("milestone/marker")
	if spec.is_empty() or not spec.has("color"):
		_fail("FW1a", "milestone/marker 应有占位 spec")
		return
	if VisualConstants.PARALLAX_LAYER_SPECS.size() < 3:
		_fail("FW1a", "视差层常量应≥3")
		return
	_pass("FW1a", "T-ART-FW-1 VisualConstants 常量表")


func _probe_fw1_visual_slot() -> void:
	var slot := VisualSlot.new()
	slot.slot_id = "probe_milestone"
	add_child(slot)
	slot.apply_art_key("milestone/fired")
	if slot.get_display_mode() != VisualSlot.DisplayMode.PLACEHOLDER:
		_fail("FW1b", "apply_art_key 应进入 PLACEHOLDER（未在 manifest 登记的键）")
		slot.queue_free()
		return
	if slot.pixel_size_from_placeholder() != VisualConstants.MILESTONE_MARKER_SIZE:
		_fail("FW1b", "占位尺寸应与常量一致")
		slot.queue_free()
		return
	slot.apply_texture(null)
	if slot.get_display_mode() != VisualSlot.DisplayMode.PLACEHOLDER:
		_fail("FW1b", "空纹理不应改变占位模式")
		slot.queue_free()
		return
	slot.clear_slot()
	if slot.get_display_mode() != VisualSlot.DisplayMode.HIDDEN:
		_fail("FW1b", "clear_slot 应隐藏")
		slot.queue_free()
		return
	slot.queue_free()
	_pass("FW1b", "T-ART-FW-1 VisualSlot 占位/清理")


func _probe_fw2_lane_visual_slots() -> void:
	var lane := RunMarchLane.new()
	lane.size = Vector2(480, 48)
	add_child(lane)
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.distance_traveled = 10.0
	lane.on_run_started(run, 3)
	lane.on_world_tick(run, true)
	var march_view := lane.get_node_or_null("RunMarchView")
	if march_view == null:
		_fail("FW2a", "应含 RunMarchView")
		lane.queue_free()
		return
	for child in march_view.get_children():
		if not child is VisualSlot:
			_fail("FW2a", "RunMarchView 子节点应为 VisualSlot")
			lane.queue_free()
			return
	var parallax := lane.get_node_or_null("ParallaxBackdrop")
	if parallax == null or parallax.get_child_count() < 3:
		_fail("FW2a", "ParallaxBackdrop 应含≥3 VisualSlot 层")
		lane.queue_free()
		return
	for child in parallax.get_children():
		if not child is VisualSlot:
			_fail("FW2a", "视差层应为 VisualSlot")
			lane.queue_free()
			return
	var markers := lane.get_node_or_null("MarchEventMarkers")
	if markers == null:
		_fail("FW2b", "应含 MarchEventMarkers")
		lane.queue_free()
		return
	if markers.get_marker_count() < 2:
		_fail("FW2b", "grassland 里程碑应经 VisualSlot 绘制")
		lane.queue_free()
		return
	lane.queue_free()
	_pass("FW2a", "T-ART-FW-2 RunMarchView/Parallax VisualSlot")
	_pass("FW2b", "T-ART-FW-2 MarchEventMarkers VisualSlot")


func _probe_fw2_gather_and_boss_slots() -> void:
	var gather := MarchGatherView.new()
	gather.size = Vector2(480, 48)
	add_child(gather)
	if gather.get_child_count() < 4:
		_fail("FW2c", "MarchGatherView 应含 prop+3 party VisualSlot")
		gather.queue_free()
		return
	for child in gather.get_children():
		if not child is VisualSlot:
			_fail("FW2c", "MarchGatherView 子节点应为 VisualSlot")
			gather.queue_free()
			return
	gather.queue_free()
	var boss := BossChaseSilhouette.new()
	boss.size = Vector2(480, 48)
	add_child(boss)
	if boss.get_child_count() < 2:
		_fail("FW2d", "BossChaseSilhouette 应含 body/crown VisualSlot")
		boss.queue_free()
		return
	for child in boss.get_children():
		if not child is VisualSlot:
			_fail("FW2d", "追击剪影子节点应为 VisualSlot")
			boss.queue_free()
			return
	boss.apply_chase(true, 40.0, false, true, 480.0)
	if not boss.is_visible_chase():
		_fail("FW2d", "apply_chase 应显示剪影")
		boss.queue_free()
		return
	boss.queue_free()
	_pass("FW2c", "T-ART-FW-2 MarchGatherView VisualSlot")
	_pass("FW2d", "T-ART-FW-2 BossChaseSilhouette VisualSlot")


func _probe_fw3_art_manifest() -> void:
	_ArtManifest.reset()
	_ArtManifest.configure({
		"textures": {
			"milestone/marker": "res://icon.svg",
			"milestone/missing": "res://assets/art/does_not_exist.png",
		},
	})
	if not _ArtManifest.has_entry("milestone/marker"):
		_fail("FW3a", "manifest 应登记 milestone/marker")
		return
	var tex: Texture2D = _ArtManifest.get_texture("milestone/marker")
	if tex == null:
		_fail("FW3a", "icon.svg 应可加载为纹理")
		return
	if _ArtManifest.get_texture("milestone/missing") != null:
		_fail("FW3a", "不存在路径应返回 null")
		return
	if _ArtManifest.get_texture("party/silhouette_0") != null:
		_fail("FW3a", "未登记键应返回 null")
		return
	_pass("FW3a", "T-ART-FW-3 ArtManifest 加载与缺文件回退")


func _probe_fw3_visual_slot_texture() -> void:
	_ArtManifest.reset()
	_ArtManifest.configure({"textures": {"milestone/marker": "res://icon.svg"}})
	var slot := VisualSlot.new()
	add_child(slot)
	slot.apply_art_key("milestone/marker")
	if slot.get_display_mode() != VisualSlot.DisplayMode.TEXTURE:
		_fail("FW3b", "manifest 命中应进入 TEXTURE")
		slot.queue_free()
		return
	_ArtManifest.configure({"textures": {"gather/prop": "res://assets/art/missing.png"}})
	slot.apply_art_key("gather/prop")
	if slot.get_display_mode() != VisualSlot.DisplayMode.PLACEHOLDER:
		_fail("FW3b", "缺文件应回退 PLACEHOLDER")
		slot.queue_free()
		return
	slot.queue_free()
	_ArtManifest.configure(DataLoader.art_manifest_data())
	_pass("FW3b", "T-ART-FW-3 VisualSlot manifest 优先于占位")


func _make_set_probe_piece(slot: String, set_id: String) -> Equipment:
	var item: Equipment = Equipment._create()
	item.slot = slot
	item.set_id = set_id
	item.item_name = "probe_%s" % slot
	return item


func _equip_set_on_merc(merc, set_id: String, slots: Array) -> void:
	for slot in slots:
		merc.equipment_slots[slot] = _make_set_probe_piece(str(slot), set_id)


func _probe_t01_set_bonus_two_piece() -> void:
	var merc := _make_probe_normal("t01_merc", "套装探针")
	var base_pdef: int = StatResolver.get_pdef(merc)
	_equip_set_on_merc(merc, "iron_guard", ["weapon", "armor"])
	if EquipmentSetRegistry.calc_set_bonus(merc, "pdef") != 8.0:
		_fail("01a", "铁卫 2/3 应贡献 pdef+8 (got %s)" % str(EquipmentSetRegistry.calc_set_bonus(merc, "pdef")))
		return
	if StatResolver.get_pdef(merc) - base_pdef != 8:
		_fail("01a", "StatResolver pdef 应比裸装 +8 (base=%d got=%d)" % [base_pdef, StatResolver.get_pdef(merc)])
		return
	_pass("01a", "T-01 铁卫 2/3 → StatResolver pdef+8")


func _probe_t01_set_bonus_three_piece() -> void:
	var merc := _make_probe_normal("t01_merc3", "套装探针3")
	var base_pdef: int = StatResolver.get_pdef(merc)
	var base_hp: int = StatResolver.get_max_hp(merc)
	_equip_set_on_merc(merc, "iron_guard", ["weapon", "armor", "helmet"])
	if StatResolver.get_pdef(merc) - base_pdef != 8:
		_fail("01b", "铁卫 3/3 仍应 pdef+8")
		return
	if StatResolver.get_max_hp(merc) - base_hp != 40:
		_fail("01b", "铁卫 3/3 应 max_hp+40 (delta=%d)" % (StatResolver.get_max_hp(merc) - base_hp))
		return
	_pass("01b", "T-01 铁卫 3/3 → pdef+8 + hp+40")


func _probe_t01_set_ui_progress_lines() -> void:
	var merc := _make_probe_normal("t01_ui", "套装UI")
	_equip_set_on_merc(merc, "iron_guard", ["weapon", "armor"])
	var lines: Array[String] = EquipmentSetRegistry.get_active_bonus_lines(merc)
	if lines.is_empty():
		_fail("01c", "2 件铁卫应有套装文案行")
		return
	var joined: String = ", ".join(lines)
	if "铁卫 2/3" not in joined:
		_fail("01c", "应含 铁卫 2/3 (got %s)" % joined)
		return
	if "物防+8" not in joined:
		_fail("01c", "应含已激活描述 物防+8 (got %s)" % joined)
		return
	_pass("01c", "T-01 UI get_active_bonus_lines 铁卫 2/3 + 描述")


func _probe_t01_set_one_piece_no_bonus() -> void:
	var merc := _make_probe_normal("t01_one", "套装单件")
	_equip_set_on_merc(merc, "iron_guard", ["weapon"])
	if EquipmentSetRegistry.calc_set_bonus(merc, "pdef") != 0.0:
		_fail("01d", "1 件不应有套装战斗加成")
		return
	var lines: Array[String] = EquipmentSetRegistry.get_active_bonus_lines(merc)
	if lines.is_empty() or "铁卫 1/3" not in lines[0]:
		_fail("01d", "UI 应显示 铁卫 1/3 (got %s)" % str(lines))
		return
	if "物防+8" in str(lines):
		_fail("01d", "1 件不应显示已激活 tier 描述")
		return
	_pass("01d", "T-01 1/3 仅进度无战斗加成")


func _probe_t06_awakening_status_refresh() -> void:
	var merc := _make_probe_normal("t06_aw", "觉醒探针")
	var entity := CombatEntity.new()
	entity.init_from_merc(merc, "t06_")
	entity.action_state = CombatEntity.ActionState.DOWNED
	var view := UnitView.new()
	add_child(view)
	view.setup(entity)
	if "(濒死)" not in view.get_status_text():
		_fail("06a", "初始应显示濒死 (got %s)" % view.get_status_text())
		view.queue_free()
		return
	entity.action_state = CombatEntity.ActionState.AWAKENING
	merc.is_awakening = true
	merc.awakening_variant_id = "damage_burst"
	view.sync_status_from_entity(entity)
	if "(觉醒" not in view.get_status_text() or "(濒死)" in view.get_status_text():
		_fail("06a", "觉醒后应刷新名称 (got %s)" % view.get_status_text())
		view.queue_free()
		return
	view.queue_free()
	_pass("06a", "T-06 濒死→觉醒 UnitView 状态刷新")


func _probe_t06_buff_badges_visible() -> void:
	var merc := _make_probe_normal("t06_buff", "Buff探针")
	merc.buff_system.apply_buff("test_patk", "patk", 5.0, 4.0)
	merc.buff_system.apply_buff("test_pdef", "pdef", 3.0, 4.0)
	var entity := CombatEntity.new()
	entity.init_from_merc(merc, "t06b_")
	var view := UnitView.new()
	add_child(view)
	view.setup(entity)
	if view.get_buff_badge_count() < 2:
		_fail("06b", "应显示至少 2 个 Buff 角标 (got %d)" % view.get_buff_badge_count())
		view.queue_free()
		return
	view.queue_free()
	_pass("06b", "T-06 战斗 Buff 角标可见")


func _probe_t06_awakening_badge_variant() -> void:
	var merc := _make_probe_normal("t06_var", "变体探针")
	merc.is_awakening = true
	merc.awakening_variant_id = "team_shield"
	var entity := CombatEntity.new()
	entity.init_from_merc(merc, "t06v_")
	entity.action_state = CombatEntity.ActionState.AWAKENING
	var view := UnitView.new()
	add_child(view)
	view.setup(entity)
	if not view.is_awakening_badge_visible():
		_fail("06c", "觉醒头标应可见")
		view.queue_free()
		return
	if "盾援" not in view.get_status_text():
		_fail("06c", "名称应含变体 盾援 (got %s)" % view.get_status_text())
		view.queue_free()
		return
	view.queue_free()
	_pass("06c", "T-06 觉醒头标 + 变体文案")


func _probe_t06_buff_badges_clear() -> void:
	var merc := _make_probe_normal("t06_clr", "Buff清")
	merc.buff_system.apply_buff("test_spd", "spd", 2.0, 1.0)
	var entity := CombatEntity.new()
	entity.init_from_merc(merc, "t06c_")
	var view := UnitView.new()
	add_child(view)
	view.setup(entity)
	if view.get_buff_badge_count() < 1:
		_fail("06d", "应有 Buff 角标")
		view.queue_free()
		return
	merc.buff_system.clear()
	view.sync_status_from_entity(entity)
	if view.get_buff_badge_count() != 0:
		_fail("06d", "Buff 清空后角标应消失 (got %d)" % view.get_buff_badge_count())
		view.queue_free()
		return
	view.queue_free()
	_pass("06d", "T-06 Buff 角标随 buff 清除")


func _make_probe_template_merc(id: String, name: String, template_id: String) -> NormalMercenary:
	var m := NormalMercenary.new()
	m.merc_id = id
	m.merc_name = name
	m.template_id = template_id
	m.merc_type = Mercenary.MercType.NORMAL
	m.is_alive = true
	m.level = 5
	m.init_from_template(DataLoader.merc_template(template_id))
	m.current_hp = m.get_max_hp_value()
	return m


func _probe_t02_build_ranged_melee_combat(enemy_x: float) -> CombatController:
	var combat := CombatController.new()
	var mage := _make_probe_template_merc("t02_mage", "术士", "mage_normal")
	var tank := _make_probe_template_merc("t02_tank", "铁卫", "warrior_normal")
	var ranged_e := CombatEntity.new()
	ranged_e.init_from_merc(mage, "ally_m")
	ranged_e.formation_slot = 0
	ranged_e.position = BattlefieldSlots.ALLY_SLOT_ORIGIN
	ranged_e.spawn_anchor_x = ranged_e.position
	var melee_e := CombatEntity.new()
	melee_e.init_from_merc(tank, "ally_t")
	melee_e.formation_slot = 1
	melee_e.position = BattlefieldSlots.ally_slot_x(3)
	melee_e.spawn_anchor_x = melee_e.position
	combat.allies.append(ranged_e)
	combat.allies.append(melee_e)
	var foe := CombatEntity.new()
	foe.init_from_enemy({
		"uid": "enemy_wolf",
		"name": "狼",
		"stats": {"hp": 80, "patk": 8, "attack_range": 50},
	})
	foe.formation_slot = 0
	foe.position = enemy_x
	foe.spawn_anchor_x = foe.position
	combat.enemies.append(foe)
	combat.is_active = true
	return combat


func _probe_t02_ranged_advance_toward_enemy() -> void:
	var combat := _probe_t02_build_ranged_melee_combat(400.0)
	var ranged_e: CombatEntity = combat.allies[0]
	var start_x: float = ranged_e.position
	if absf(ranged_e.position - combat.enemies[0].position) <= ranged_e.attack_range + 0.01:
		_fail("02-1", "探针布局应初始超出射程")
		return
	for _i in 80:
		combat.movement_tick_ally_advance(ranged_e, combat.enemies, 0.1, [])
	if ranged_e.position <= start_x + 2.0:
		_fail("02-1", "远程应前探 (%.0f -> %.0f)" % [start_x, ranged_e.position])
		return
	_pass("02-1", "T-02 远程前探接敌")


func _probe_t02_ranged_enters_attack_range() -> void:
	var combat := _probe_t02_build_ranged_melee_combat(400.0)
	var ranged_e: CombatEntity = combat.allies[0]
	for _i in 80:
		combat.movement_tick_ally_advance(ranged_e, combat.enemies, 0.1, [])
	var target: CombatEntity = combat.find_nearest_in_range(
		combat.enemies, ranged_e.position, ranged_e.attack_range
	)
	if target == null:
		_fail("02-2", "前探后应进入射程 (pos=%.0f range=%.0f)" % [ranged_e.position, ranged_e.attack_range])
		return
	_pass("02-2", "T-02 远程进入 attack_range")


func _probe_t02_ranged_stays_behind_melee() -> void:
	var combat := _probe_t02_build_ranged_melee_combat(400.0)
	var ranged_e: CombatEntity = combat.allies[0]
	var melee_e: CombatEntity = combat.allies[1]
	for _i in 80:
		combat.movement_tick_ally_advance(ranged_e, combat.enemies, 0.1, [])
	if ranged_e.position >= melee_e.position - 1.0:
		_fail("02-3", "远程应留在近战身后 (r=%.0f m=%.0f)" % [ranged_e.position, melee_e.position])
		return
	_pass("02-3", "T-02 远程守后排不抢前排位")


func _probe_t02_ranged_respects_forward_cap() -> void:
	var combat := _probe_t02_build_ranged_melee_combat(520.0)
	var ranged_e: CombatEntity = combat.allies[0]
	var melee_e: CombatEntity = combat.allies[1]
	var cap_x: float = melee_e.position - 24.0
	for _i in 120:
		combat.movement_tick_ally_advance(ranged_e, combat.enemies, 0.1, [])
	if ranged_e.position > cap_x + 1.0:
		_fail("02-4", "远程不应越过前排 standoff (pos=%.0f cap=%.0f)" % [ranged_e.position, cap_x])
		return
	_pass("02-4", "T-02 远程前探上限 = 前排 - standoff")


func _probe_02_build_dual_melee_combat() -> CombatController:
	var recruit := _make_probe_template_merc("dm_r", "新兵", "warrior_normal")
	var tank := _make_probe_elite("dm_t", "铁卫", "warrior_elite")
	var squad := Squad.new()
	squad.build([recruit, tank])
	var enemy: Array = [{
		"uid": "dm_wolf",
		"name": "野狼",
		"stats": {"hp": 200, "patk": 4, "pdef": 2, "mdef": 1, "spd": 4, "attack_range": 50},
	}]
	var combat := CombatController.new()
	combat.init_combat(squad, enemy, null, 0.0)
	return combat


func _probe_02_dual_melee_tank_front() -> void:
	var combat := _probe_02_build_dual_melee_combat()
	var tank_e: CombatEntity = null
	var recruit_e: CombatEntity = null
	for e in combat.allies:
		if e.entity_id.ends_with("dm_t"):
			tank_e = e
		elif e.entity_id.ends_with("dm_r"):
			recruit_e = e
	if tank_e == null or recruit_e == null:
		_fail("02-5", "双近战探针应生成铁卫+新兵")
		return
	if tank_e.formation_slot <= recruit_e.formation_slot:
		_fail("02-5", "铁卫应在前排槽 (t=%d r=%d)" % [tank_e.formation_slot, recruit_e.formation_slot])
		return
	if tank_e.position <= recruit_e.position + 0.5:
		_fail("02-5", "铁卫 logic_x 应更靠敌 (t=%.0f r=%.0f)" % [tank_e.position, recruit_e.position])
		return
	_pass("02-5", "T-02 双近战坦克前排")


func _probe_02_dual_melee_both_in_range() -> void:
	var combat := _probe_02_build_dual_melee_combat()
	for _i in 240:
		combat.tick(0.05)
	for e in combat.allies:
		if e.is_ranged_unit():
			continue
		var target: CombatEntity = combat.find_nearest_in_range(
			combat.enemies, e.position, e.attack_range
		)
		if target == null:
			_fail("02-6", "%s 应能接敌 (pos=%.0f range=%.0f)" % [
				e.display_name, e.position, e.attack_range
			])
			return
	_pass("02-6", "T-02 双近战均可进 attack_range")


func _make_probe_elite(id: String, name: String, template_id: String) -> EliteMercenary:
	var m := EliteMercenary.new()
	m.merc_id = id
	m.merc_name = name
	m.template_id = template_id
	m.merc_type = Mercenary.MercType.ELITE
	m.is_alive = true
	m.level = 5
	m.init_from_template(DataLoader.merc_template(template_id))
	m.current_hp = m.get_max_hp_value()
	return m


func _probe_t03_elite_inherits_class_active_skills() -> void:
	var mage := _make_probe_elite("t03_mage", "奥术", "mage_elite")
	if not ("fireball" in mage.active_skills and "heal" in mage.active_skills):
		_fail("03-1", "mage_elite 应继承法师主动技 (got %s)" % str(mage.active_skills))
		return
	var entity := CombatEntity.new()
	entity.init_from_merc(mage, "t03_")
	if entity.skill_cooldowns.size() < 2:
		_fail("03-1", "CombatEntity 应登记技能 CD 槽")
		return
	_pass("03-1", "T-03 精英模板继承 class active_skills")


func _probe_t03_skill_cd_chip_shows_remaining() -> void:
	var mage := _make_probe_elite("t03_cd", "术士", "mage_elite")
	var entity := CombatEntity.new()
	entity.init_from_merc(mage, "t03c_")
	entity.set_skill_cooldown("fireball", 3.2)
	var view := UnitView.new()
	add_child(view)
	view.setup(entity)
	if view.get_skill_chip_count() < 2:
		_fail("03-2", "应显示至少 2 个技能角标")
		view.queue_free()
		return
	var chip: String = view.get_skill_chip_text("fireball")
	if chip != "火4":
		_fail("03-2", "CD 角标应为 火4 (got %s)" % chip)
		view.queue_free()
		return
	view.queue_free()
	_pass("03-2", "T-03 UnitView 显示技能 CD 秒数")


func _probe_t03_skill_cd_chip_ready_state() -> void:
	var mage := _make_probe_elite("t03_rdy", "术士2", "mage_elite")
	var entity := CombatEntity.new()
	entity.init_from_merc(mage, "t03r_")
	entity.set_skill_cooldown("heal", 0.0)
	var view := UnitView.new()
	add_child(view)
	view.setup(entity)
	if view.get_skill_chip_text("heal") != "疗":
		_fail("03-3", "就绪技能应仅显示简称 (got %s)" % view.get_skill_chip_text("heal"))
		view.queue_free()
		return
	view.queue_free()
	_pass("03-3", "T-03 技能就绪角标无 CD 数字")


func _probe_t03_cooldown_from_template_on_cast() -> void:
	if absf(SkillSystem.get_active_cooldown("fireball") - 5.0) > 0.01:
		_fail("03-4", "fireball 模板 CD 应为 5s")
		return
	var mage := _make_probe_elite("t03_cast", "奥术2", "mage_elite")
	var entity := CombatEntity.new()
	entity.init_from_merc(mage, "t03x_")
	entity.set_skill_cooldown("fireball", 0.0)
	entity.set_skill_cooldown("fireball", SkillSystem.get_active_cooldown("fireball"))
	if entity.get_skill_cooldown_remaining("fireball") < 4.9:
		_fail("03-4", "施放后应写入模板 CD")
		return
	_pass("03-4", "T-03 技能 CD 与 skill_templates 一致")


func _probe_t04_battle_debug_toggle() -> void:
	BattleDebug.reset_session()
	if BattleDebug.is_enabled():
		_fail("04-1", "reset_session 后测试模式应关闭")
		return
	BattleDebug.set_enabled(true)
	if not BattleDebug.is_enabled():
		_fail("04-1", "set_enabled(true) 应开启测试模式")
		return
	BattleDebug.toggle_from_user()
	if BattleDebug.is_enabled():
		_fail("04-1", "toggle_from_user 应关闭测试模式")
		return
	BattleDebug.reset_session()
	_pass("04-1", "T-04 BattleDebug 运行时开关")


func _probe_t04_hp_multiplier_on_entity() -> void:
	BattleDebug.reset_session()
	BattleDebug.set_enabled(true)
	var entity := CombatEntity.new()
	entity.max_hp = 100
	entity.current_hp = 80
	BattleDebug.apply_entity_modifiers(entity)
	if entity.max_hp != 500 or entity.current_hp != 500:
		_fail("04-2", "HP 倍率应为 ×5 (got max=%d cur=%d)" % [entity.max_hp, entity.current_hp])
		BattleDebug.reset_session()
		return
	BattleDebug.reset_session()
	_pass("04-2", "T-04 接战 HP×5 倍率")


func _probe_t04_damage_scale() -> void:
	BattleDebug.reset_session()
	if BattleDebug.scale_damage(100) != 100:
		_fail("04-3", "关闭时伤害不应缩放")
		BattleDebug.reset_session()
		return
	BattleDebug.set_enabled(true)
	var scaled: int = BattleDebug.scale_damage(100)
	if scaled != 30:
		_fail("04-3", "开启时伤害应 ×0.3 (got %d)" % scaled)
		BattleDebug.reset_session()
		return
	BattleDebug.reset_session()
	_pass("04-3", "T-04 伤害 ×0.3 倍率")


func _probe_t04_test_map_auto_enable() -> void:
	BattleDebug.reset_session()
	var test_md: Dictionary = DataLoader.map_data("test_01_stability_retreat")
	if test_md.is_empty():
		_fail("04-4", "test_01 地图数据缺失")
		return
	BattleDebug.prepare_for_combat(test_md)
	if not BattleDebug.is_enabled():
		_fail("04-4", "测试图应自动开启战斗测试模式")
		BattleDebug.reset_session()
		return
	BattleDebug.reset_session()
	var prod_md: Dictionary = DataLoader.map_data("grassland")
	if prod_md.is_empty():
		_fail("04-4", "grassland 地图数据缺失")
		BattleDebug.reset_session()
		return
	BattleDebug.prepare_for_combat(prod_md)
	if BattleDebug.is_enabled():
		_fail("04-4", "正式图不应自动开启测试模式")
		BattleDebug.reset_session()
		return
	BattleDebug.reset_session()
	_pass("04-4", "T-04 测试图自动开 / 正式图默认关")


func _t02c_blank_formation() -> Dictionary:
	return {
		"active_half": SquadFormationService.HALF_A,
		SquadFormationService.HALF_A: {"active": [], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}


func _probe_t02c_merc_deploy_while_player_downed() -> void:
	_reset_gm()
	var p := GameManager.player
	p.apply_near_death_state(0.35)
	var m1 := _ensure_probe_normal("2c_b1", "佣甲")
	var m2 := _ensure_probe_normal("2c_b2", "佣乙")
	GameManager.squad_formation = _t02c_blank_formation()
	GameManager.squad_formation[SquadFormationService.HALF_B] = {
		"active": [m1.merc_id, m2.merc_id],
		"bench": [],
	}
	SquadFormationService.ensure_formation(GameManager)
	if not SquadFormationService.half_can_deploy(GameManager, SquadFormationService.HALF_B):
		_fail("2c-1", "主角濒死时 B 半组佣兵应可出征")
		return
	var deploy: Array = SquadFormationService.resolve_active_squad(GameManager, SquadFormationService.HALF_B)
	if deploy.is_empty() or p in deploy:
		_fail("2c-1", "出征名单应仅含佣兵")
		return
	_pass("2c-1", "T-02c 主角濒死·佣兵半组可出征")


func _probe_t02c_deploy_excludes_player() -> void:
	_reset_gm()
	var p := GameManager.player
	p.reset_to_full_hp()
	var m1 := _ensure_probe_normal("2c_a1", "佣A1")
	var m2 := _ensure_probe_normal("2c_a2", "佣A2")
	GameManager.squad_formation = _t02c_blank_formation()
	GameManager.squad_formation[SquadFormationService.HALF_A] = {
		"active": [m1.merc_id, m2.merc_id],
		"bench": [],
	}
	SquadFormationService.ensure_formation(GameManager)
	var half: String = SquadFormationService.pick_deploy_half(GameManager)
	if half != SquadFormationService.HALF_A:
		_fail("2c-2", "A 有佣兵时应优先 A (got %s)" % half)
		return
	var deploy: Array = SquadFormationService.resolve_active_squad(GameManager, half)
	if p in deploy:
		_fail("2c-2", "默认出征名单不应含主角")
		return
	_pass("2c-2", "T-02c A 优先出征且名单无主角")


func _probe_t02c_recovery_lock_merc_only() -> void:
	_reset_gm()
	GameManager.normal_roster.clear()
	GameManager.elite_roster.clear()
	var m1 := _make_probe_normal("2c_r1", "伤甲")
	var m2 := _make_probe_normal("2c_r2", "伤乙")
	m1.current_hp = 1
	m2.current_hp = 1
	GameManager.normal_roster.append(m1)
	GameManager.normal_roster.append(m2)
	GameManager.squad_formation = _t02c_blank_formation()
	GameManager.squad_formation[SquadFormationService.HALF_A] = {"active": [m1.merc_id], "bench": []}
	GameManager.squad_formation[SquadFormationService.HALF_B] = {"active": [m2.merc_id], "bench": []}
	SquadFormationService.ensure_formation(GameManager)
	GameManager.player.reset_to_full_hp()
	if not GameManager.is_recovery_lock_active():
		_fail("2c-3", "两半组佣兵均不可出战时应养伤锁")
		return
	_pass("2c-3", "T-02c 养伤锁仅看佣兵·与主角无关")


func _probe_t02c_merc_only_run_player_unchanged() -> void:
	_reset_gm()
	var p := GameManager.player
	p.current_hp = 42
	var player_hp_before: int = p.current_hp
	var m := _ensure_probe_normal("2c_run1", "出征佣")
	m.run_kills = 4
	m.run_damage_dealt = 120
	var squad := Squad.new()
	squad.build([m])
	var run := WorldRun.new("grassland", squad)
	run.squad_member_ids = [m.merc_id]
	var result: Dictionary = run.end_run(false)
	if p.current_hp != player_hp_before:
		_fail("2c-4", "纯佣兵趟主角 HP 不应变化")
		return
	if not bool(result.get("player_alive", false)):
		_fail("2c-4", "纯佣兵趟 player_alive 应反映留营主角")
		return
	if int(result.get("squad_kills", 0)) != 4:
		_fail("2c-4", "佣兵战果应写入结算")
		return
	_pass("2c-4", "T-02c 纯佣兵趟·主角留营不变")


func _probe_t02c_strip_player_from_halves() -> void:
	_reset_gm()
	var pid: String = GameManager.player.merc_id
	var m := _ensure_probe_normal("2c_old1", "旧档佣")
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_A,
		SquadFormationService.HALF_A: {"active": [pid, m.merc_id], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	var active: Array[String] = SquadFormationService.get_active_ids(
		GameManager.squad_formation, SquadFormationService.HALF_A
	)
	if pid in active:
		_fail("2c-5", "ensure_formation 应从 A/B 剥离主角")
		return
	if m.merc_id not in active:
		_fail("2c-5", "佣兵槽位应保留")
		return
	_pass("2c-5", "T-02c 旧档主角移出半组槽")


func _probe_t02c_no_lock_when_mercs_ready() -> void:
	_reset_gm()
	var m1 := _ensure_probe_normal("2c_ok1", "满血1")
	var m2 := _ensure_probe_normal("2c_ok2", "满血2")
	var m3 := _ensure_probe_normal("2c_ok3", "满血3")
	GameManager.player.apply_near_death_state(0.2)
	GameManager.squad_formation = _t02c_blank_formation()
	GameManager.squad_formation[SquadFormationService.HALF_A] = {
		"active": [m1.merc_id, m2.merc_id, m3.merc_id],
		"bench": [],
	}
	SquadFormationService.ensure_formation(GameManager)
	if GameManager.is_recovery_lock_active():
		_fail("2c-6", "主角未编入·A 佣兵满血不应养伤锁")
		return
	if not SquadFormationService.half_can_deploy(GameManager, SquadFormationService.HALF_A):
		_fail("2c-6", "A 半组应可出征")
		return
	_pass("2c-6", "T-02c 养伤锁误报修复（主角留营）")


func _probe_t_ui_form_1_start_run_preserves_active_half() -> void:
	_reset_gm()
	MutualRecoveryService.set_auto_enabled(GameManager, false)
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_B,
		SquadFormationService.HALF_A: {"active": ["probe_m1"], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	var deploy_h: String = SquadFormationService.resolve_deploy_half(GameManager)
	if deploy_h != SquadFormationService.HALF_A:
		_fail("FORM-1a", "B 优先但无可用出战时应改派 A (got %s)" % deploy_h)
		return
	GameManager.state = GameManager.GameState.PREPARE
	GameManager.selected_map_id = "grassland"
	var code: int = GameManager.start_run(true, true)
	if code != 0:
		_fail("FORM-1a", "start_run 应成功 (code %d)" % code)
		return
	if str(GameManager.squad_formation.get("active_half", "")) != SquadFormationService.HALF_B:
		_fail("FORM-1a", "start_run 后 active_half 应仍为 B")
		return
	if GameManager.last_deploy_half != SquadFormationService.HALF_A:
		_fail("FORM-1a", "start_run 后 last_deploy_half 应为 A (got %s)" % GameManager.last_deploy_half)
		return
	GameManager.current_run = null
	GameManager.state = GameManager.GameState.BASE
	MutualRecoveryService.set_auto_enabled(GameManager, true)
	_pass("FORM-1a", "T-UI-FORM-1 start_run 不覆盖 active_half")


func _probe_t_ui_form_2_manual_block_auto_fallback() -> void:
	_reset_gm()
	MutualRecoveryService.set_auto_enabled(GameManager, false)
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_B,
		SquadFormationService.HALF_A: {"active": ["probe_m1"], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	GameManager.state = GameManager.GameState.PREPARE
	GameManager.selected_map_id = "grassland"
	var manual: int = GameManager.start_run(false, false)
	if manual != -7:
		_fail("FORM-2a", "手动出征 B 优先不可出战应返回 -7 (got %d)" % manual)
		return
	if str(GameManager.squad_formation.get("active_half", "")) != SquadFormationService.HALF_B:
		_fail("FORM-2a", "手动 -7 后 active_half 应仍为 B")
		return
	var auto: int = GameManager.start_run(false, true)
	if auto != 0:
		_fail("FORM-2a", "自动改派出征应成功 (code %d)" % auto)
		return
	if GameManager.last_deploy_half != SquadFormationService.HALF_A:
		_fail("FORM-2a", "自动改派后 last_deploy_half 应为 A")
		return
	GameManager.current_run = null
	GameManager.state = GameManager.GameState.BASE
	_pass("FORM-2a", "T-UI-FORM-2 手动 -7 / 自动改派")


func _probe_t_ui_form_3r_recruit_stays_in_pool() -> void:
	_reset_gm()
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_B,
		SquadFormationService.HALF_A: {"active": [], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	var recruit := _make_probe_normal("form3r_new", "新兵")
	GameManager.normal_roster.append(recruit)
	SquadFormationService.rebalance_from_roster(GameManager)
	var new_id: String = recruit.merc_id
	if not SquadFormationService.find_merc_slot(GameManager, new_id).is_empty():
		_fail("FORM-3R", "招募后新佣兵不应自动进入 A/B 槽")
		return
	if str(GameManager.squad_formation.get("active_half", "")) != SquadFormationService.HALF_B:
		_fail("FORM-3R", "招募不应改变编组优先 active_half")
		return
	SquadFormationService.auto_fill_half(GameManager, SquadFormationService.HALF_B)
	var slot: Dictionary = SquadFormationService.find_merc_slot(GameManager, new_id)
	if slot.is_empty() or str(slot.get("half", "")) != SquadFormationService.HALF_B:
		_fail("FORM-3R", "补满优先半组后新佣兵应进入半组 B")
		return
	_reset_gm()
	GameManager.gold = 5000
	GameManager.normal_roster.clear()
	GameManager.elite_roster.clear()
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_B,
		SquadFormationService.HALF_A: {"active": [], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	GameManager.buildings["barracks"] = {"level": 2, "building_id": "barracks"}
	var roster_before: int = GameManager.normal_roster.size()
	var code: int = MercRecruitService.recruit_merc(GameManager, "normal")
	if code != 0:
		_fail("FORM-3R", "recruit_merc 应成功 (code=%d)" % code)
		return
	if GameManager.normal_roster.size() != roster_before + 1:
		_fail("FORM-3R", "recruit_merc 应增加一名佣兵")
		return
	var recruited_id: String = GameManager.normal_roster[GameManager.normal_roster.size() - 1].merc_id
	if SquadFormationService.is_merc_assigned(GameManager, recruited_id):
		_fail("FORM-3R", "recruit_merc 后新佣兵不应自动进入 A/B 槽")
		return
	if str(GameManager.squad_formation.get("active_half", "")) != SquadFormationService.HALF_B:
		_fail("FORM-3R", "recruit_merc 不应改变编组优先 active_half")
		return
	_pass("FORM-3R", "T-UI-FORM-3R 招募默认备战席")


func _probe_t_ui_form_6_cross_half_assign() -> void:
	_reset_gm()
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_B,
		SquadFormationService.HALF_A: {"active": ["probe_m1"], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	var code: int = GameManager.formation_assign("probe_m1", SquadFormationService.HALF_B, "active", 0)
	if code != 0:
		_fail("FORM-6a", "A→B 跨半组 assign 应成功 (code %d)" % code)
		return
	var a_active: Array[String] = SquadFormationService.get_active_ids(
		GameManager.squad_formation, SquadFormationService.HALF_A
	)
	if not a_active.is_empty() and a_active[0] != "":
		_fail("FORM-6a", "A 出战位应已清空")
		return
	var b_active: Array[String] = SquadFormationService.get_active_ids(
		GameManager.squad_formation, SquadFormationService.HALF_B
	)
	if b_active.is_empty() or b_active[0] != "probe_m1":
		_fail("FORM-6a", "B 出战位应有 probe_m1")
		return
	var back: int = GameManager.formation_clear_slot(SquadFormationService.HALF_B, "active", 0)
	if back != 0:
		_fail("FORM-6a", "拖回备战席等价 clear_slot 应成功")
		return
	_pass("FORM-6a", "T-UI-FORM-6 跨半组 assign / 移出")


func _probe_t_stab_half_aggregate() -> void:
	_reset_gm()
	MutualRecoveryService.set_auto_enabled(GameManager, false)
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	var m2 := GameManager.find_mercenary_by_id("probe_m2")
	if m1 == null or m2 == null:
		_fail("STAB-HALF-a", "探针佣兵缺失")
		return
	m1.personal_stability = 80
	m2.personal_stability = 55
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_A,
		SquadFormationService.HALF_A: {"active": ["probe_m1", "probe_m2"], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	if SquadFormationService.get_half_active_stability_min(GameManager, SquadFormationService.HALF_A) != 55:
		_fail("STAB-HALF-a", "战 min 应为 55 (got %d)" % SquadFormationService.get_half_active_stability_min(GameManager, SquadFormationService.HALF_A))
		return
	if SquadFormationService.get_half_bench_stability_min(GameManager, SquadFormationService.HALF_A) != 100:
		_fail("STAB-HALF-a", "空替补应视为无短板 (got %d)" % SquadFormationService.get_half_bench_stability_min(GameManager, SquadFormationService.HALF_A))
		return
	if SquadFormationService.get_half_stability(GameManager, SquadFormationService.HALF_A) != 135:
		_fail("STAB-HALF-a", "半组稳定应为 80+55=135 (got %d)" % SquadFormationService.get_half_stability(GameManager, SquadFormationService.HALF_A))
		return
	GameManager.squad_formation[SquadFormationService.HALF_A]["bench"] = ["probe_m2"]
	m1.personal_stability = 40
	if SquadFormationService.get_half_stability(GameManager, SquadFormationService.HALF_A) != 95:
		_fail("STAB-HALF-a", "战40+55 半组总和应为 95 (替补不计)")
		return
	if m1.get_personal_break_threshold() != 30:
		_fail("STAB-HALF-a", "个人崩溃线应为 max 30%% (got %d)" % m1.get_personal_break_threshold())
		return
	if StabilitySystem.get_team_withdraw_threshold() != 30:
		_fail("STAB-HALF-a", "团队强制撤阈值应为 30")
		return
	GameManager.squad_formation[SquadFormationService.HALF_B] = {"active": ["probe_m2"], "bench": []}
	m2.personal_stability = 90
	if GameManager.get_deploy_half_stability(SquadFormationService.HALF_B) != 90:
		_fail("STAB-HALF-a", "B 半组应不受全局 team_stability 影响")
		return
	GameManager.state = GameManager.GameState.PREPARE
	GameManager.selected_map_id = "grassland"
	var code: int = GameManager.start_run(false, false)
	if code != 0:
		_fail("STAB-HALF-a", "A 半组出征应成功 (code %d)" % code)
		return
	if GameManager.current_run == null or GameManager.current_run.stability == null:
		_fail("STAB-HALF-a", "应有 stability")
		return
	if GameManager.current_run.stability.team_stability != 95:
		_fail("STAB-HALF-a", "本趟团队起点应为半组总和 95 (got %d)" % GameManager.current_run.stability.team_stability)
		return
	GameManager.current_run = null
	GameManager.state = GameManager.GameState.BASE
	_pass("STAB-HALF-a", "T-STAB-POOL 出战4人总和 + 出征起点")


func _probe_t_stab_half_ui_format() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	if m1 == null:
		_fail("STAB-HALF-b", "探针佣兵缺失")
		return
	m1.personal_stability = 72
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_A,
		SquadFormationService.HALF_A: {"active": ["probe_m1"], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	if SquadFormationService.format_half_stability_text(GameManager, SquadFormationService.HALF_A) != "72/100":
		_fail("STAB-HALF-b", "单员应显示 72/100 (got %s)" % SquadFormationService.format_half_stability_text(GameManager, SquadFormationService.HALF_A))
		return
	if GameManager.get_team_stability() != 72:
		_fail("STAB-HALF-b", "get_team_stability 应读编组优先半组聚合")
		return
	GameManager.set_team_stability(5)
	if GameManager.get_deploy_half_stability(SquadFormationService.HALF_A) != 72:
		_fail("STAB-HALF-b", "set_team_stability 应不再影响半组聚合")
		return
	_pass("STAB-HALF-b", "T-STAB-POOL 文案 current/max 总和")


func _probe_t_stab_half_display_combined_cap() -> void:
	_reset_gm()
	var weak := NormalMercenary.new()
	weak.merc_id = "probe_weak"
	weak.init_from_template(DataLoader.merc_template("warrior_normal"))
	weak.personal_stability = weak.get_personal_stability_max()
	var strong := EliteMercenary.new()
	strong.merc_id = "probe_strong"
	strong.init_from_template(DataLoader.merc_template("warrior_elite"))
	strong.personal_stability = strong.get_personal_stability_max()
	GameManager.normal_roster.append(weak)
	GameManager.elite_roster.append(strong)
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_B,
		SquadFormationService.HALF_A: {"active": [], "bench": []},
		SquadFormationService.HALF_B: {
			"active": ["probe_weak", "probe_strong"],
			"bench": [],
		},
	}
	SquadFormationService.ensure_formation(GameManager)
	if SquadFormationService.format_half_stability_text(GameManager, SquadFormationService.HALF_B) != "230/230":
		_fail(
			"STAB-HALF-c",
			"双员应显示 230/230 (got %s)"
			% SquadFormationService.format_half_stability_text(GameManager, SquadFormationService.HALF_B)
		)
		return
	if SquadFormationService.get_half_stability(GameManager, SquadFormationService.HALF_B) != 230:
		_fail("STAB-HALF-c", "出征起点应为 105+125=230")
		return
	GameManager.squad_formation[SquadFormationService.HALF_A] = {"active": ["probe_strong"], "bench": []}
	if SquadFormationService.format_half_stability_text(GameManager, SquadFormationService.HALF_A) != "125/125":
		_fail("STAB-HALF-c", "A 单精英应显示 125/125")
		return
	if SquadFormationService.get_half_stability(GameManager, SquadFormationService.HALF_A) < 125:
		_fail("STAB-HALF-c", "单员出征起点应≥个人稳")
		return
	GameManager.squad_formation[SquadFormationService.HALF_A] = {"active": ["probe_weak"], "bench": []}
	weak.personal_stability = 72
	if SquadFormationService.get_half_stability(GameManager, SquadFormationService.HALF_A) != 72:
		_fail("STAB-HALF-c", "单人 72 稳出征起点应为 72")
		return
	_pass("STAB-HALF-c", "T-STAB-POOL 人多总和更高，出征≥个人稳")


func _probe_t_stab_class_personal_max() -> void:
	var w := NormalMercenary.new()
	w.init_from_template(DataLoader.merc_template("warrior_normal"))
	if w.get_personal_stability_max() != 105:
		_fail("STAB-CLASS-a", "warrior_normal 上限应为 105 (got %d)" % w.get_personal_stability_max())
		return
	var mg := NormalMercenary.new()
	mg.init_from_template(DataLoader.merc_template("mage_normal"))
	if mg.get_personal_stability_max() != 80:
		_fail("STAB-CLASS-a", "mage_normal 上限应为 80 (got %d)" % mg.get_personal_stability_max())
		return
	var rg := NormalMercenary.new()
	rg.init_from_template(DataLoader.merc_template("ranger_normal"))
	if rg.get_personal_stability_max() != 92:
		_fail("STAB-CLASS-a", "ranger_normal 上限应为 92 (got %d)" % rg.get_personal_stability_max())
		return
	var elite := EliteMercenary.new()
	elite.init_from_template(DataLoader.merc_template("warrior_elite"))
	if elite.get_personal_stability_max() != 125:
		_fail("STAB-CLASS-a", "warrior_elite+toughness 上限应为 125 (got %d)" % elite.get_personal_stability_max())
		return
	if w.get_personal_break_threshold() != 31:
		_fail("STAB-CLASS-a", "战105 崩溃线应为 31 (got %d)" % w.get_personal_break_threshold())
		return
	if mg.get_personal_break_threshold() != 24:
		_fail("STAB-CLASS-a", "法80 崩溃线应为 24 (got %d)" % mg.get_personal_break_threshold())
		return
	_pass("STAB-CLASS-a", "T-STAB-CLASS 职业个人稳定上限")


func _probe_t_stab_pool_cascade() -> void:
	_reset_gm()
	var m1 := GameManager.find_mercenary_by_id("probe_m1")
	var m2 := GameManager.find_mercenary_by_id("probe_m2")
	if m1 == null or m2 == null:
		_fail("STAB-POOL-b", "探针佣兵缺失")
		return
	m1.personal_stability = 100
	m2.personal_stability = 100
	var squad := Squad.new()
	squad.members = [m1, m2]
	var stab := StabilitySystem.new()
	stab.init(null, squad, 200, {}, 200)
	if stab.team_stability != 200:
		_fail("STAB-POOL-b", "团队条应等于个人之和 200")
		return
	stab._apply_personal_loss_with_cascade(m1, 100)
	stab._sync_team_from_squad()
	var spill: int = maxi(1, int(floor(float(m1.get_personal_stability_max()) * 0.10)))
	if m2.personal_stability != 100 - spill:
		_fail("STAB-POOL-b", "耗尽应牵连队友扣 10%% (got %d)" % m2.personal_stability)
		return
	if stab.team_stability != m1.personal_stability + m2.personal_stability:
		_fail("STAB-POOL-b", "团队条应随个人池同步")
		return
	_pass("STAB-POOL-b", "T-STAB-POOL 个人耗尽牵连 10%")


func _probe_t_ui_form_4_preferred_vs_deploy() -> void:
	_reset_gm()
	GameManager.squad_formation = {
		"active_half": SquadFormationService.HALF_B,
		SquadFormationService.HALF_A: {"active": ["probe_m1"], "bench": []},
		SquadFormationService.HALF_B: {"active": [], "bench": []},
	}
	SquadFormationService.ensure_formation(GameManager)
	var pref: String = SquadFormationService.get_preferred_half(GameManager)
	var deploy: String = SquadFormationService.resolve_deploy_half(GameManager)
	if pref != SquadFormationService.HALF_B:
		_fail("FORM-4a", "编组优先应为 B (got %s)" % pref)
		return
	if deploy != SquadFormationService.HALF_A:
		_fail("FORM-4a", "下趟出征应为 A (got %s)" % deploy)
		return
	if pref == deploy:
		_fail("FORM-4a", "编组优先与出征半组应可解耦")
		return
	_pass("FORM-4a", "T-UI-FORM-4 编组优先 vs 下趟出征语义")


func _probe_t_ui_form_layout_1_summary() -> void:
	var form_src: String = FileAccess.get_file_as_string("res://scripts/ui/formation_ui.gd")
	if not form_src.contains("const LAYOUT_REV := 9"):
		_fail("FORM-LAYOUT-1a", "formation_ui LAYOUT_REV 应为 9")
		return
	if not form_src.contains("FormationSummaryUI") or not form_src.contains("_summary_ui"):
		_fail("FORM-LAYOUT-1a", "应挂载 FormationSummaryUI 简表")
		return
	if not form_src.contains("高级编组") or not form_src.contains("_advanced_body"):
		_fail("FORM-LAYOUT-1a", "槽位墙应收进高级编组折叠区")
		return
	if not form_src.contains("_on_advanced_toggle_pressed") or not form_src.contains("set_advanced_collapsed"):
		_fail("FORM-LAYOUT-1a", "高级编组折叠条应可展开")
		return
	if not form_src.contains("_advanced_body.visible = false"):
		_fail("FORM-LAYOUT-1a", "高级编组默认应收起")
		return
	if not form_src.contains("_summary_ui.refresh"):
		_fail("FORM-LAYOUT-1a", "F2/刷新应走简表 refresh")
		return
	var summary_script: Script = load("res://scripts/ui/formation_summary_ui.gd") as Script
	if summary_script == null:
		_fail("FORM-LAYOUT-1a", "formation_summary_ui.gd 无法加载")
		return
	var summary: Node = summary_script.new() as Node
	if summary == null or not summary is FormationSummaryUI:
		_fail("FORM-LAYOUT-1a", "FormationSummaryUI 实例化失败")
		return
	summary.free()
	_pass("FORM-LAYOUT-1a", "T-UI-FORM-LAYOUT-1 简表 + 高级编组可展开")


func _probe_expedition_strategy_snapshot() -> void:
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("EXPED-1a", "探针佣兵缺失")
		return
	GameManager.expedition_priority = GameManager.EXPEDITION_PRIORITY_LOOT
	GameManager.loot_discard_overflow = true
	GameManager.auto_retreat_safe_only = true
	var squad := Squad.new()
	squad.build([merc])
	var run := WorldRun.new("grassland", squad)
	if run.start() != 0:
		_fail("EXPED-1a", "WorldRun.start 失败")
		return
	if run.expedition_priority != GameManager.EXPEDITION_PRIORITY_LOOT:
		_fail("EXPED-1a", "出征策略未快照")
		return
	if not is_equal_approx(run.expedition_advance_mult, 0.82):
		_fail("EXPED-1a", "推进倍率应为 0.82 (got %s)" % run.expedition_advance_mult)
		return
	if not run.loot_discard_overflow or not run.auto_retreat_safe_only:
		_fail("EXPED-1a", "战利品/撤离选项未快照")
		return
	GameManager.expedition_priority = GameManager.EXPEDITION_PRIORITY_PUSH
	GameManager.loot_discard_overflow = false
	if run.expedition_priority != GameManager.EXPEDITION_PRIORITY_LOOT:
		_fail("EXPED-1a", "本趟出发后不应随大营改动")
		return
	if run.loot_discard_overflow != true:
		_fail("EXPED-1a", "本趟战利品选项不应随大营改动")
		return
	_pass("EXPED-1a", "出征策略 start 快照锁定本趟")


func _probe_expedition_push_blocks_auto_retreat() -> void:
	var merc := GameManager.find_mercenary_by_id("probe_m1")
	if merc == null:
		_fail("EXPED-2a", "探针佣兵缺失")
		return
	GameManager.expedition_priority = GameManager.EXPEDITION_PRIORITY_PUSH
	var squad := Squad.new()
	squad.build([merc])
	var run := WorldRun.new("grassland", squad)
	if run.start() != 0:
		_fail("EXPED-2a", "WorldRun.start 失败")
		return
	if not ExpeditionStrategyService.is_push(run):
		_fail("EXPED-2a", "推图策略未快照")
		return
	if AutoRetreatService.check(run):
		_fail("EXPED-2a", "推图模式不应自动撤离")
		return
	_pass("EXPED-2a", "推图模式禁用自动撤离")


func _probe_expedition_ui_retreat_row_layout() -> void:
	var form_src: String = FileAccess.get_file_as_string("res://scripts/ui/formation_ui.gd")
	var base_src: String = FileAccess.get_file_as_string("res://scripts/ui/base_ui.gd")
	if not form_src.contains("const LAYOUT_REV := 9"):
		_fail("EXPED-UI-1", "formation_ui LAYOUT_REV 应为 9")
		return
	if not base_src.contains("const FORMATION_UI_LAYOUT_REV := 9"):
		_fail("EXPED-UI-1", "base_ui FORMATION_UI_LAYOUT_REV 应为 9")
		return
	if not form_src.contains("var _retreat_row"):
		_fail("EXPED-UI-1", "出征策略应拆分独立撤离行 _retreat_row")
		return
	if not form_src.contains("func _sync_expedition_retreat_row"):
		_fail("EXPED-UI-1", "应通过 _sync_expedition_retreat_row 整行显隐")
		return
	if not form_src.contains("_retreat_row.visible = march_only"):
		_fail("EXPED-UI-1", "均衡模式应控制整行 visible")
		return
	if not form_src.contains("_halves_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN"):
		_fail("EXPED-UI-1", "半组行应 SIZE_SHRINK_BEGIN 防纵向拉伸")
		return
	_pass("EXPED-UI-1", "均衡撤离行拆分 + 半组不纵向 FILL")


func _probe_camp_1a_stage_lineup() -> void:
	var form_src: String = FileAccess.get_file_as_string("res://scripts/ui/formation_ui.gd")
	if not form_src.contains("CampStage") or not form_src.contains("_refresh_camp_stage"):
		_fail("CAMP-1a", "formation_ui 应挂载 CampStage")
		return
	var stage: CampStage = CampStage.new()
	add_child(stage)
	if not stage.is_collapsed():
		_fail("CAMP-1a", "CampStage 应默认折叠")
		stage.queue_free()
		return
	stage.set_collapsed(false)
	var vis_fn := func(merc_id: String, _kind: String) -> Dictionary:
		if merc_id == "":
			return {
				"ready": false,
				"name_text": "",
				"accent": Color(0.3, 0.3, 0.32),
				"bg": Color(0.1, 0.1, 0.12, 0.9),
			}
		return {
			"ready": true,
			"name_text": merc_id,
			"accent": Color(0.4, 0.65, 0.9),
			"bg": Color(0.15, 0.2, 0.28, 0.95),
		}
	stage.refresh_lineup(
		["probe_m1", "", "", ""],
		["probe_m2", "", "", ""],
		"",
		vis_fn
	)
	if stage.find_child("CampRowA", true, false) == null:
		_fail("CAMP-1a", "CampStage 缺少 CampRowA")
		stage.queue_free()
		return
	if stage.count_filled_chips() != 2:
		_fail("CAMP-1a", "横排应显示 2 名出战成员 (got %d)" % stage.count_filled_chips())
		stage.queue_free()
		return
	stage.queue_free()
	_pass("CAMP-1a", "T-UI-CAMP-1 营地舞台 + A/B 横排")


func _probe_frame_1a_shell_zones() -> void:
	var shell_src: String = FileAccess.get_file_as_string("res://scripts/ui/main_shell.gd")
	if not shell_src.contains("UpperArea"):
		_fail("FRAME-1a", "main_shell 应保留 UpperArea 计划区")
		return
	if shell_src.contains("VSplitContainer") or shell_src.contains('name = "StageBar"'):
		_fail("FRAME-1a", "PlanningShell 不应再含 VSplit/StageBar")
		return
	if not shell_src.contains("UpperOverlayHost"):
		_fail("FRAME-1a", "后勤/装备浮窗应挂 UpperOverlayHost（只遮上区）")
		return
	var stage_src: String = FileAccess.get_file_as_string("res://scripts/ui/stage_shell.gd")
	if not stage_src.contains("StageBar") or not stage_src.contains("_apply_stage_bar_mouse_policy"):
		_fail("FRAME-1a", "StageShell 应承载 StageBar 表演层")
		return
	var camp_src: String = FileAccess.get_file_as_string("res://scripts/ui/camp_stage.gd")
	if not camp_src.contains("_collapsed: bool = true") and not camp_src.contains("_collapsed = true"):
		_fail("FRAME-1a", "CampStage 应默认折叠")
		return
	_pass("FRAME-1a", "T-UI-FRAME-1/TWIN 计划区与表演区分离")


func _probe_twin_1a_dual_window() -> void:
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_src.contains("StageWindow") or not main_src.contains("_stage_shell"):
		_fail("TWIN-1a", "main.gd 应创建 StageWindow 并持有 StageShell")
		return
	if not main_src.contains("_stage_shell.apply_state") or not main_src.contains("_main_shell.apply_state"):
		_fail("TWIN-1a", "state_changed 应同步 PlanningShell 与 StageShell")
		return
	if not main_src.contains("_shutdown_all_windows"):
		_fail("TWIN-1a", "关主窗应关闭副窗")
		return
	var stage_src: String = FileAccess.get_file_as_string("res://scripts/ui/stage_shell.gd")
	if not stage_src.contains("get_combat_view") or not stage_src.contains("BottomStage"):
		_fail("TWIN-1a", "StageShell 应提供 combat_view 与 BottomStage")
		return
	if not FileAccess.file_exists("res://scenes/stage_window.tscn"):
		_fail("TWIN-1a", "缺少 scenes/stage_window.tscn")
		return
	_pass("TWIN-1a", "T-UI-TWIN-1 双窗壳层拆分")


func _probe_stage_1a_bottom_stage() -> void:
	var stage_src: String = FileAccess.get_file_as_string("res://scripts/ui/stage_shell.gd")
	if not stage_src.contains("BottomStage") or not stage_src.contains("_bottom_stage"):
		_fail("STAGE-1a", "StageShell 应挂载 BottomStage")
		return
	var stage := BottomStage.new()
	stage.custom_minimum_size = Vector2(480, 220)
	stage.size = Vector2(480, 220)
	add_child(stage)
	stage.apply_game_state(GameManager.GameState.BASE)
	if not stage.is_bonfire_visible():
		_fail("STAGE-1a", "底栏营火 VisualSlot 应可见")
		stage.queue_free()
		return
	if stage.count_visible_party_slots() < 1:
		_fail("STAGE-1a", "底栏应显示至少 1 个队伍剪影")
		stage.queue_free()
		return
	stage.queue_free()
	_pass("STAGE-1a", "T-UI-STAGE-1/2 底栏营火+队伍剪影")


func _probe_m2c_search_blocked_during_combat() -> void:
	var run := WorldRun.new("grassland", null)
	run.is_active = true
	run.is_retreating = true
	run.distance_traveled = 48.0
	run.march_search_last_anchor = 0.0
	if not _MarchSearchService.tick(run, false).is_empty():
		_fail("M2c", "接战期间 allowed=false 不应触发搜索")
		return
	if not _MarchEventService.tick(run, false).is_empty():
		_fail("M2c", "接战期间 allowed=false 不应触发里程碑")
		return
	_pass("M2c", "T-MARCH 接战/返程战期间禁用搜索与里程碑")


func _probe_b3_grassland_march_events() -> void:
	var md: Dictionary = DataLoader.map_data("grassland")
	var entries: Array = _MarchEventService.milestone_entries(md)
	if entries.size() < 5:
		_fail("B3-1", "grassland 应至少 5 个里程碑 (got %d)" % entries.size())
		return
	var ids: PackedStringArray = []
	for e in entries:
		if e is Dictionary:
			ids.append(str(e.get("event_id", "")))
	for want in ["abandoned_crate", "wind_scoured_pack", "grassland_herbs", "fog_patch", "rusted_cart"]:
		if want not in ids:
			_fail("B3-1", "grassland 缺少事件 %s" % want)
			return
	if DataLoader.march_event("wind_scoured_pack").is_empty():
		_fail("B3-1", "march_events.json 缺少 wind_scoured_pack")
		return
	if not bool(DataLoader.march_event("wind_scoured_pack").get("gather_beat", false)):
		_fail("B3-2", "wind_scoured_pack 应为采集节拍")
		return
	_pass("B3-1", "T-MARCH-C1 草原里程碑表扩充")
	_pass("B3-2", "T-MARCH-C1 120m 采集事件定义")


func _probe_c1_test_maps_march_events() -> void:
	var t01: Dictionary = DataLoader.map_data("test_01_stability_retreat")
	var t01_entries: Array = _MarchEventService.milestone_entries(t01)
	if t01_entries.size() < 2:
		_fail("C1-1", "test_01 应至少 2 个里程碑")
		return
	var t01_ids: PackedStringArray = []
	for e in t01_entries:
		if e is Dictionary:
			t01_ids.append(str(e.get("event_id", "")))
	if "waypoint_sign" not in t01_ids or "fog_patch" not in t01_ids:
		_fail("C1-1", "test_01 应含 waypoint_sign + fog_patch")
		return
	var t02: Dictionary = DataLoader.map_data("test_02_extract_line")
	var t02_entries: Array = _MarchEventService.milestone_entries(t02)
	if t02_entries.size() < 2:
		_fail("C1-2", "test_02 应至少 2 个里程碑")
		return
	var t02_ids: PackedStringArray = []
	for e in t02_entries:
		if e is Dictionary:
			t02_ids.append(str(e.get("event_id", "")))
	if "cache_marker" not in t02_ids or "abandoned_crate" not in t02_ids:
		_fail("C1-2", "test_02 应含 cache_marker + abandoned_crate")
		return
	if DataLoader.march_event("cache_marker").is_empty():
		_fail("C1-2", "march_events.json 缺少 cache_marker")
		return
	_pass("C1-1", "T-MARCH-C1 test_01 里程碑扩充")
	_pass("C1-2", "T-MARCH-C1 test_02 撤离线里程碑")
	var remaining: PackedStringArray = [
		"test_03_boss_chase", "test_04_auto_value", "test_05_loot_full",
		"test_06_near_death_duo", "test_07_near_death_solo", "test_08_awakening",
		"test_09_long_chase_pressure", "forest", "cave", "death_trial"
	]
	for map_id in remaining:
		var md: Dictionary = DataLoader.map_data(map_id)
		if md.is_empty():
			_fail("C1-3", "缺少地图 %s" % map_id)
			return
		var entries: Array = _MarchEventService.milestone_entries(md)
		if entries.is_empty():
			_fail("C1-3", "%s 应至少 1 个里程碑" % map_id)
			return
		var has_anchor: bool = false
		for e in entries:
			if e is Dictionary:
				var dist: float = float(e.get("at_distance", 0))
				var eid: String = str(e.get("event_id", ""))
				if dist >= 10.0 and not eid.is_empty():
					if DataLoader.march_event(eid).is_empty():
						_fail("C1-3", "%s 引用未知事件 %s" % [map_id, eid])
						return
					has_anchor = true
		if not has_anchor:
			_fail("C1-3", "%s 缺少 ≥10m 有效里程碑" % map_id)
			return
	for want_evt in ["chase_omen", "forest_shrine", "cave_echo", "trial_monolith", "trail_ambush_sign"]:
		if DataLoader.march_event(want_evt).is_empty():
			_fail("C1-3", "march_events.json 缺少 %s" % want_evt)
			return
	_pass("C1-3", "T-MARCH-C1 测试图+主线图里程碑全覆盖")


func _probe_02b_battlefield_slot_layout() -> void:
	if not BattlefieldSlots.slot_gap_covers_visual(BattlefieldSlots.LANE_MIN_WIDTH):
		_fail("02b-1", "槽位间距在 lane=%.0f 时应覆盖色块宽" % BattlefieldSlots.LANE_MIN_WIDTH)
		return
	var inset: float = BattlefieldSlots.unit_sprite_inset_x()
	var expect_inset: float = (BattlefieldSlots.UNIT_VISUAL_WIDTH - BattlefieldSlots.SPRITE_HEIGHT) * 0.5
	if absf(inset - expect_inset) > 0.01:
		_fail("02b-2", "sprite inset 与 60/48 槽位不一致")
		return
	if BattlefieldSlots.SPRITE_HEIGHT != 48.0 or BattlefieldSlots.UNIT_VISUAL_WIDTH != 60.0:
		_fail("02b-2", "BattlefieldSlots 像素常量应为 60×48")
		return
	if BattlefieldSlots.UNIT_BASELINE_Y != 36.0:
		_fail("02b-2", "脚底基准线应为 36px")
		return
	_pass("02b-1", "T-02b 槽位间距覆盖色块宽")
	_pass("02b-2", "T-02b 60×48 脚线常量统一")


func _probe_02a_enemy_skips_downed() -> void:
	var combat := CombatController.new()
	var tank := CombatEntity.new()
	tank.init_from_merc(_make_probe_normal("02a_tank", "铁卫"), "ally_t")
	tank.formation_slot = 0
	tank.position = 180.0
	tank.action_state = CombatEntity.ActionState.DOWNED
	tank.current_hp = 1
	var mage := CombatEntity.new()
	mage.init_from_merc(_make_probe_normal("02a_mage", "术士"), "ally_m")
	mage.formation_slot = 1
	mage.position = 100.0
	combat.allies = [tank, mage]
	var target: CombatEntity = combat.find_nearest_in_range(
		combat.allies, 250.0, 200.0, combat._any_ally_fighter_on_field()
	)
	if target == null or target == tank:
		_fail("02a-1", "敌方应优先打可战友方，而非濒死前排")
		return
	if target.entity_id != mage.entity_id:
		_fail("02a-1", "应选中后排可战友方")
		return
	_pass("02a-1", "T-02a 敌方跳过濒死目标")


func _probe_02a_downed_rear_snap() -> void:
	var combat := CombatController.new()
	var fighter := CombatEntity.new()
	fighter.init_from_merc(_make_probe_normal("02a_f", "游侠"), "ally_f")
	fighter.formation_slot = 1
	fighter.position = 140.0
	var downed := CombatEntity.new()
	downed.init_from_merc(_make_probe_normal("02a_d", "铁卫"), "ally_d")
	downed.formation_slot = 0
	downed.position = 200.0
	downed.action_state = CombatEntity.ActionState.DOWNED
	downed.current_hp = 1
	combat.allies = [fighter, downed]
	combat.set_march_retreat_combat(true)
	if downed.position >= fighter.position:
		_fail(
			"02a-2",
			"濒死应归位后排 (downed=%.1f fighter=%.1f)" % [downed.position, fighter.position]
		)
		return
	_pass("02a-2", "T-02a 返程入场濒死后排归位")


func _probe_02a_only_downed_no_crash() -> void:
	var combat := CombatController.new()
	var downed := CombatEntity.new()
	downed.init_from_merc(_make_probe_normal("02a_solo", "铁卫"), "ally_s")
	downed.formation_slot = 0
	downed.position = 160.0
	downed.action_state = CombatEntity.ActionState.DOWNED
	downed.current_hp = 1
	combat.allies = [downed]
	var no_fighter_target: CombatEntity = combat.find_nearest_in_range(
		combat.allies, 200.0, 300.0, true
	)
	if no_fighter_target != null:
		_fail("02a-3", "仅濒死时 fighters_only 应无目标")
		return
	var fallback: CombatEntity = combat.find_nearest_in_range(
		combat.allies, 200.0, 300.0, false
	)
	if fallback == null:
		_fail("02a-3", "fallback 应仍能选中濒死")
		return
	_pass("02a-3", "T-02a 仅濒死剩场 fallback 不崩")


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
