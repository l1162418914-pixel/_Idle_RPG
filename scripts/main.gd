extends Node
## Main — 主场景，驱动 GameManager 循环

const _EXTRACT_ITEM_SERVICE_PATH := "res://scripts/run/extract_item_service.gd"

var _main_shell: MainShell = null
var _base_ui: Control = null
var _squad_ui: Control = null
var _run_ui: Control = null
var _result_ui: Control = null
var _combat_view: CombatView = null

var _pending_enemies: Array = []
var _combat: CombatController = null
var _in_combat: bool = false
var _run_tick_timer: float = 0.0
var _combat_resolved_enemies: Array = []
var _encounter_session: EncounterSession = null
var _manual_withdraw_dialog: ConfirmationDialog = null
var _run_march_lane: RunMarchLane = null


func _ready() -> void:
	randomize()
	_find_ui_refs()
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.run_started.connect(_on_run_started)
	
	_setup_manual_withdraw_dialog()
	# 初始状态
	_on_state_changed(GameManager.state)


func _setup_manual_withdraw_dialog() -> void:
	_manual_withdraw_dialog = ConfirmationDialog.new()
	_manual_withdraw_dialog.title = "手动斩仓"
	_manual_withdraw_dialog.ok_button_text = "确认撤离"
	_manual_withdraw_dialog.cancel_button_text = "取消"
	_manual_withdraw_dialog.confirmed.connect(_on_manual_withdraw_confirmed)
	add_child(_manual_withdraw_dialog)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameManager.persist_on_shutdown()


func _find_ui_refs() -> void:
	_main_shell = get_node_or_null("MainShell") as MainShell
	_base_ui = get_node_or_null("BaseUI")
	_squad_ui = get_node_or_null("SquadUI")
	_run_ui = get_node_or_null("RunUI")
	_result_ui = get_node_or_null("ResultUI")
	if _main_shell:
		_main_shell.setup(_base_ui, _squad_ui, _run_ui, _result_ui)
		_combat_view = _main_shell.get_combat_view()
		_run_march_lane = _main_shell.get_run_march_lane()
		var equip_ui := get_node_or_null("EquipmentUI") as Control
		if equip_ui:
			equip_ui.move_to_front()
	elif _run_ui:
		_combat_view = _run_ui.get_node_or_null("MarginContainer/MainVBox/CombatView") as CombatView


func _on_state_changed(new_state: int) -> void:
	if _main_shell:
		_main_shell.apply_state(new_state)
	else:
		_show_only_legacy(new_state)


func _show_only_legacy(state: int) -> void:
	if _base_ui:
		_base_ui.visible = (state == GameManager.GameState.BASE)
	if _squad_ui:
		_squad_ui.visible = (state == GameManager.GameState.PREPARE)
	if _run_ui:
		_run_ui.visible = (state == GameManager.GameState.RUNNING)
	if _result_ui:
		_result_ui.visible = (state == GameManager.GameState.RESULT)
		if _result_ui.visible:
			_result_ui.move_to_front()


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	var run = GameManager.current_run
	if run == null or not run.is_active:
		return
	
	var world_run_ticked: bool = run.is_retreating or not _in_combat
	if world_run_ticked:
		_tick_world_run(delta, run)
	if _in_combat:
		_tick_combat(delta, run, world_run_ticked)
	_sync_run_march_lane(run, world_run_ticked)


func _tick_world_run(delta: float, run: WorldRun) -> void:
	var result = run.tick(delta)
	
	if _run_ui:
		var lane_snap: Dictionary = _run_march_lane.get_snapshot() if _run_march_lane else {}
		_run_ui.update_display(result, lane_snap)
	if _main_shell and _main_shell.has_method("refresh_running_panels"):
		_main_shell.refresh_running_panels()
	
	var events: Array = result.get("events", [])
	for ev in events:
		match ev.type:
			"enemy_spawn":
				if _in_combat and _encounter_session != null and not _encounter_session.allows_pending_append():
					continue
				_pending_enemies.append(ev.data)
				var min_enemies := 1
				if not run.is_retreating and not GameManager.auto_run_enabled:
					min_enemies = 2
				if _pending_enemies.size() >= min_enemies or ev.data.get("is_boss", false):
					_start_combat(run)
			
			"boss":
				_pending_enemies.append(ev.data)
				if not _in_combat:
					_start_combat(run)
	
	if run.is_retreating:
		if run.should_trigger_chase_combat() and not _in_combat:
			_start_chase_boss_combat(run)
			return
		if run.has_completed_retreat():
			_end_run(run, true)
		return
	
	if run.stability.should_withdraw() and not run.is_retreating:
		run.begin_retreat("forced")
		return
	
	if run.boss_defeated and not run.is_retreating:
		_end_run(run, false)
		return
	
	if run.extract_guard_cleared and not run.is_retreating:
		_end_run(run, false)


func _start_combat(run: WorldRun) -> void:
	if _pending_enemies.is_empty():
		return
	if _in_combat:
		return
	var session := EncounterSession.begin(
		EncounterSession.infer_kind(_pending_enemies, run),
		_pending_enemies
	)
	_start_encounter(run, session)


func _start_encounter(run: WorldRun, session: EncounterSession) -> void:
	if session.enemies.is_empty():
		return
	if _in_combat:
		return
	if run.squad == null:
		_pending_enemies.clear()
		return
	if run.squad.get_battlefield_members().is_empty():
		_pending_enemies.clear()
		return
	
	_encounter_session = session
	_pending_enemies = session.enemies.duplicate()
	session.on_combat_begin(run)
	
	_combat = CombatController.new()
	
	# CombatView 必须在 init_combat 之前连接信号，否则 combat_started 先于连接触发
	if _combat_view:
		_combat_view.init_for_combat(_combat)
	
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.entity_dead.connect(_on_combat_entity_dead)
	_combat.init_combat(run.squad, session.enemies, run)
	_combat.set_movement_policy(session.movement_policy_for(run))
	if _combat_view:
		_combat_view.sync_from_active_combat()
	
	_in_combat = true
	_combat_resolved_enemies.clear()
	if _run_march_lane:
		_run_march_lane.on_combat_start(run, session.is_boss_lane() or session.is_chase_boss())


func _start_chase_boss_combat(run: WorldRun) -> void:
	if _in_combat:
		return
	_pending_enemies.clear()
	var boss_data: Dictionary = run.build_chase_boss_encounter()
	if boss_data.is_empty():
		return
	_pending_enemies.append(boss_data)
	if _run_ui:
		_run_ui.show_run_hint("首领追上你了！接战！", Color.ORANGE_RED)
	_start_encounter(run, EncounterSession.begin(EncounterKind.CHASE_BOSS, _pending_enemies))


func _tick_combat(delta: float, run: WorldRun, world_run_already_ticked: bool = false) -> void:
	if _combat == null:
		_in_combat = false
		return
	var combat_delta: float = delta * BattleDebug.get_time_scale()
	if not world_run_already_ticked:
		if run.is_retreating and run.boss_chase_active:
			run.tick_boss_chase(combat_delta)
		if run.stability:
			run.stability.tick(combat_delta)
			if run.stability.should_withdraw():
				_abort_combat_for_forced_withdraw(run)
				return
	
	var result = _combat.tick(combat_delta)
	if _encounter_session != null and _encounter_session.is_chase_boss():
		run.tick_chase_stagger_charge(combat_delta)
		BossChaseService.tick_deep_counter_cooldown(run, combat_delta)
	
	if not world_run_already_ticked and run.stability and run.stability.should_withdraw():
		_abort_combat_for_forced_withdraw(run)
		return
	
	if result.status == "victory":
		_in_combat = false
		var victory_outcome: Dictionary = {}
		if _encounter_session != null:
			victory_outcome = _encounter_session.resolve_victory(run)
		else:
			victory_outcome = {"action": "finish", "register_defeats": true, "store_resolved": true}
		_apply_victory_outcome(run, victory_outcome)
		
	elif result.status == "defeat":
		_in_combat = false
		var defeat_outcome: Dictionary = {}
		if _encounter_session != null:
			defeat_outcome = _encounter_session.resolve_defeat(run)
		else:
			defeat_outcome = {
				"action": "emergency_retreat",
				"hint": "战斗失利，紧急撤离！",
				"retreat_reason": "emergency",
			}
		_apply_defeat_outcome(run, defeat_outcome)
	
	elif not _in_combat:
		# tick 内已通过 entity_dead → _end_run 结束战斗，收尾
		_pending_enemies.clear()
		_finish_combat()


func _apply_victory_outcome(run: WorldRun, outcome: Dictionary) -> void:
	var action: String = str(outcome.get("action", "finish"))
	match action:
		"end_run":
			if outcome.get("clear_extract_guard", false):
				run.extract_guard_cleared = true
				load(_EXTRACT_ITEM_SERVICE_PATH).apply_clear_bonus(run)
			if outcome.get("register_chase_kill", false):
				for e_data in _pending_enemies:
					run.register_chase_boss_kill(e_data)
			_pending_enemies.clear()
			_clear_encounter_session(run)
			if _run_ui and outcome.has("hint"):
				_run_ui.show_run_hint(str(outcome.hint), outcome.get("hint_color", Color.GREEN))
			_finish_combat()
			_end_run(run, false)
		"chase_repel":
			run.on_chase_boss_repelled(float(outcome.get("push_mult", 1.0)))
			_pending_enemies.clear()
			_clear_encounter_session(run)
			if _run_ui and outcome.has("hint"):
				_run_ui.show_run_hint(str(outcome.hint), outcome.get("hint_color", Color.SKY_BLUE))
			_finish_combat()
			if _combat_view:
				_clear_combat_view_after_run(run)
		_:
			if outcome.get("register_defeats", false):
				for e_data in _pending_enemies:
					run.register_enemy_defeat(e_data)
			if outcome.get("store_resolved", false):
				_combat_resolved_enemies = _pending_enemies.duplicate()
			_pending_enemies.clear()
			_clear_encounter_session(run)
			_finish_combat()


func _apply_defeat_outcome(run: WorldRun, outcome: Dictionary) -> void:
	var action: String = str(outcome.get("action", "emergency_retreat"))
	_pending_enemies.clear()
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat = null
	match action:
		"chase_defeat":
			_clear_encounter_session(run)
			if run.squad and run.squad.has_anyone_alive():
				if _should_execute_chase_catch_on_downed(run):
					if _run_ui:
						_run_ui.show_run_hint("追击首领追上濒死编队，全军覆没…", Color.ORANGE_RED)
					_mark_squad_wiped(run)
					if _combat_view:
						_clear_combat_view_after_run(run)
					_end_run(run, false)
					return
				run.on_chase_boss_catch_penalty()
				if _run_ui and outcome.has("hint"):
					_run_ui.show_run_hint(str(outcome.hint), outcome.get("hint_color", Color.ORANGE_RED))
				_process_run_retreats(run)
				if _combat_view:
					_clear_combat_view_after_run(run)
				if run.stability and run.stability.should_withdraw():
					run.begin_retreat("forced")
			else:
				_mark_squad_wiped(run)
				if _combat_view:
					_clear_combat_view_after_run(run)
				_end_run(run, false)
		"emergency_retreat":
			if outcome.get("clear_pending_guard", false):
				run.pending_extract_guard = null
			_clear_encounter_session(run)
			if run.squad and run.squad.has_anyone_alive():
				_trigger_emergency_retreat_from_combat(
					run,
					str(outcome.get("hint", "战斗失利，紧急撤离！")),
					str(outcome.get("retreat_reason", "emergency"))
				)
			else:
				_mark_squad_wiped(run)
				_finish_combat()
				_end_run(run, false)
		_:
			_clear_encounter_session(run)
			_mark_squad_wiped(run)
			_finish_combat()
			_end_run(run, false)


func _clear_encounter_session(run: WorldRun) -> void:
	if _encounter_session != null:
		_encounter_session.on_combat_end(run)
	_encounter_session = null


func _on_combat_ended(victory: bool) -> void:
	pass


func _on_combat_entity_dead(entity: CombatEntity) -> void:
	if not _in_combat or _combat == null:
		return
	if entity.team == CombatEntity.Team.ALLY:
		var run = GameManager.current_run
		if run:
			run.on_member_down()
		# 濒死仍在战场上，不算溃散
		if entity.is_downed():
			return
		if _combat and _combat.count_allies_on_field() == 0:
			if run:
				if run.squad and run.squad.has_anyone_alive():
					var fail_reason := "emergency"
					if _encounter_session != null:
						fail_reason = _encounter_session.combat_fail_retreat_reason()
					var hint := "队伍溃散，紧急撤离！"
					if fail_reason == "combat_fail":
						hint = "区域首领战失利！撤向撤离点…"
					elif run.squad.has_any_member_near_death():
						hint = "队员濒死，紧急撤离！（返程移速减半）"
					_trigger_emergency_retreat_from_combat(run, hint, fail_reason)
				else:
					_mark_squad_wiped(run)
					_end_run(run, false)


func _trigger_emergency_retreat_from_combat(
	run: WorldRun, hint: String, retreat_reason: String = "emergency"
) -> void:
	_in_combat = false
	_pending_enemies.clear()
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat.force_end()
		_combat = null
	_clear_encounter_session(run)
	if not run.is_retreating:
		run.begin_retreat(retreat_reason)
	elif run.retreat_shield_current <= 0:
		run.refresh_retreat_shield(retreat_reason)
	if _run_ui:
		_run_ui.show_run_hint(hint, Color.CYAN)
	_process_run_retreats(run)
	if _combat_view:
		_clear_combat_view_after_run(run)


func _finish_combat() -> void:
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat = null
	var run := GameManager.current_run
	_clear_encounter_session(run)
	if _run_march_lane and run:
		_run_march_lane.on_combat_end(run)
	if run:
		if run.stability:
			run.stability.refresh_pressure_multipliers()
		_process_run_retreats(run)
		if run.pending_extract_guard != null and not _in_combat and not run.is_retreating:
			_start_extract_guard_combat(run)
	if _combat_view:
		_clear_combat_view_after_run(run)


func _start_extract_guard_combat(run: WorldRun) -> void:
	if _in_combat or run == null or run.pending_extract_guard == null:
		return
	if run.is_retreating:
		return
	_pending_enemies.clear()
	_pending_enemies.append(run.build_extract_guard_encounter())
	var item_name: String = run.pending_extract_guard.item_name
	if _run_ui:
		_run_ui.show_run_hint("封存物引动守卫！迎战：%s" % item_name, Color.ORANGE)
	_start_encounter(run, EncounterSession.begin(EncounterKind.EXTRACT_GUARD, _pending_enemies))


func _clear_combat_view_after_run(run: WorldRun) -> void:
	# 本趟仍在 RUNNING：保留战斗面板可见，仅清单位（下一场重建）
	if (
		run != null
		and run.is_active
		and GameManager.state == GameManager.GameState.RUNNING
	):
		_combat_view.prepare_between_encounters()
	else:
		_combat_view.cleanup()


func _abort_combat_for_forced_withdraw(run: WorldRun) -> void:
	if not run.is_retreating:
		run.begin_retreat("forced")
	if _run_ui:
		_run_ui.show_run_hint("稳定度过低，强制返程（行程不中断）…", Color.ORANGE_RED)
	_process_run_retreats(run)


func _abort_active_combat() -> void:
	if not _in_combat:
		_pending_enemies.clear()
		return
	_in_combat = false
	var run := GameManager.current_run
	_clear_encounter_session(run)
	_pending_enemies.clear()
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat.force_end()
		_combat = null
	if _combat_view:
		_clear_combat_view_after_run(run)


func _process_run_retreats(run: WorldRun) -> void:
	if run == null or run.squad == null:
		return
	var to_remove: Array[Mercenary] = []
	var hp_names: Array[String] = []
	var morale_names: Array[String] = []
	for m in run.squad.members:
		if m.should_auto_retreat():
			m.mark_retreated()
			to_remove.append(m)
			hp_names.append(m.merc_name)
		elif m.should_personal_break():
			m.mark_personal_break()
			to_remove.append(m)
			morale_names.append(m.merc_name)
	for m in to_remove:
		run.squad.members.erase(m)
		run.on_member_retreat()
	var bench_added: Array[String] = SquadFormationService.try_bench_reinforcements(run)
	if not bench_added.is_empty() and _run_ui:
		_run_ui.show_run_hint("替补上阵: %s" % ", ".join(bench_added), Color.SKY_BLUE)
		NearDeathRunService.assign_carry_support(run.squad)
	if not hp_names.is_empty() and _run_ui:
		_run_ui.show_run_hint("%s 血量过低，已撤离队伍" % ", ".join(hp_names), Color.ORANGE)
	if not morale_names.is_empty() and _run_ui:
		_run_ui.show_run_hint("%s 个人稳定度过低，已撤离队伍" % ", ".join(morale_names), Color.GOLD)


func _sync_run_march_lane(run: WorldRun, world_run_ticked: bool) -> void:
	if _run_march_lane == null or run == null:
		return
	_run_march_lane.on_world_tick(run, world_run_ticked)
	var snap: Dictionary = _run_march_lane.get_snapshot()
	if _run_ui and _run_ui.has_method("apply_lane_snapshot"):
		_run_ui.apply_lane_snapshot(snap)
	if _main_shell and _main_shell.has_method("apply_lane_snapshot"):
		_main_shell.apply_lane_snapshot(snap)


func _on_run_started() -> void:
	var run = GameManager.current_run
	if run == null:
		return
	if _run_march_lane:
		_run_march_lane.on_run_started(run)
	if _combat_view:
		_combat_view.prepare_between_encounters()
	if not run.run_event.is_connected(_on_world_run_event):
		run.run_event.connect(_on_world_run_event)
	if _run_ui and _run_ui.has_method("reset_run_hints"):
		_run_ui.reset_run_hints()
	var md: Dictionary = run.map_data
	var banner: String = TestScenarioService.get_run_start_banner(md)
	if banner != "" and _run_ui:
		_run_ui.show_run_hint(banner, Color(0.75, 0.9, 1.0))


func _on_world_run_event(event_name: String, data: Dictionary) -> void:
	if _run_ui == null:
		return
	match event_name:
		"test_auto_retreat":
			_run_ui.show_run_hint(str(data.get("reason", "测试图自动返程")), Color.SKY_BLUE)
		"forced_withdraw":
			_run_ui.show_run_hint("稳定度过低，强制返程（行程不中断）…", Color.ORANGE_RED)
		"retreat_started":
			var dest: float = float(data.get("destination", 0))
			var origin: float = float(data.get("origin", 0))
			var label := "大营"
			if dest > 1.0:
				label = "撤离点 %.0fm" % dest
			var extra := "（行程继续，可接战）"
			var run = GameManager.current_run
			if run and run.squad and run.squad.has_any_member_near_death():
				extra = "（有队员濒死，返程移速减半，濒死者无法战斗）"
			_run_ui.show_run_hint("从 %.0fm 返程 → %s%s" % [origin, label, extra], Color.SKY_BLUE)
		"extract_reached":
			_run_ui.show_run_hint("已抵达撤离点，继续返回大营…", Color.SKY_BLUE)
		"guard_chase_started":
			_run_ui.show_run_hint("撤离物线：返程刷怪加密、护盾消耗加快", Color.ORANGE)
		"boss_chase_started":
			_run_ui.show_run_hint("首领开始追击！注意头顶距离", Color.ORANGE)
		"boss_chase_repelled":
			var gap: float = float(data.get("gap", 0))
			var rx: int = int(data.get("exp", 0))
			var rg: int = int(data.get("gold", 0))
			var msg := "首领被击退，距你 %.0fm，趁现在快跑！" % gap
			if data.get("counter", false):
				msg = "反击推远首领！当前距离 %.0fm" % gap
			if rx > 0 or rg > 0:
				msg += "（+%d 经验" % rx
				if rg > 0:
					msg += "、%d 金币" % rg
				msg += "）"
			var rl: Dictionary = data.get("repel_loot", {})
			if rl is Dictionary and str(rl.get("item_name", "")) != "":
				msg += " · 追击表掉落 [%s]" % str(rl.get("item_name", ""))
			_run_ui.show_run_hint(msg, Color.SKY_BLUE)
		"chase_repel_loot":
			_run_ui.show_run_hint(
				"追击击退额外掉落: [%s] → %s" % [str(data.get("quality", "")), str(data.get("item_name", ""))],
				Color(0.75, 0.95, 1.0)
			)
		"chase_boss_killed":
			_run_ui.show_run_hint("追击首领被击杀！", Color.GREEN)
		"chase_stagger_repelled":
			_run_ui.show_run_hint("僵持击退经验 +%d" % int(data.get("exp", 0)), Color.CYAN)
		"chase_deep_counter_repelled":
			_run_ui.show_run_hint("深度反击额外经验 +%d" % int(data.get("exp", 0)), Color(0.55, 0.95, 1.0))
		"boss_chase_counter":
			var push: float = float(data.get("push_mult", 1.0))
			var rx: int = int(data.get("exp", 0))
			_run_ui.show_run_hint(
				"反击成功！首领被推远（×%.2f）+%d 经验" % [push, rx],
				Color.CYAN
			)
		"boss_chase_penalty":
			_run_ui.show_run_hint("接战失利！稳定度大跌，首领仍在靠近", Color.ORANGE_RED)
		"retreat_shield_started":
			var eq_c: int = int(data.get("equip_shield", 0))
			var eq_m: int = int(data.get("equip_shield_max", 0))
			var mt_c: int = int(data.get("material_shield", 0))
			var mt_m: int = int(data.get("material_shield_max", 0))
			_run_ui.show_run_hint(
				"返程护盾 装备 %d/%d · 物资 %d/%d" % [eq_c, eq_m, mt_c, mt_m],
				Color.CYAN
			)
		"material_dropped":
			_run_ui.show_run_hint("获得物资: %s" % str(data.get("name", "")), Color(0.75, 0.9, 1.0))
		"auto_retreat":
			var cv: int = int(data.get("carry_value", 0))
			var th: int = int(data.get("threshold", 0))
			var ar: String = str(data.get("reason", ""))
			var msg := "携带价值 %d 达标，自动返程" % cv
			if ar == "auto_rule":
				msg = "自动规则触发返程（携带 %d）" % cv
			elif th > 0:
				msg = "携带价值 %d≥%d，自动返程" % [cv, th]
			_run_ui.show_run_hint(msg, Color.SKY_BLUE)
		"extract_guard_triggered":
			_run_ui.show_run_hint(
				"拾取 %s：触发宝库守卫战！" % str(data.get("item_name", "")),
				Color.ORANGE
			)
		"extract_item_secured":
			_run_ui.show_run_hint(
				"拾取 %s：未引动守卫，已占格" % str(data.get("item_name", "")),
				Color(0.8, 0.95, 1.0)
			)
		"awakening_started":
			var v_id: String = str(data.get("variant", "damage_burst"))
			var v_label: String = {
				"damage_burst": "爆发",
				"team_shield": "盾援",
				"taunt": "铁壁",
				"heal_snap": "回光",
			}.get(v_id, v_id)
			_run_ui.show_run_hint(
				"%s 绝境觉醒·%s！" % [str(data.get("name", "")), v_label],
				Color(1.0, 0.85, 0.35)
			)
		"retreat_shield_broken":
			_run_ui.show_run_hint("护盾破碎！返程受击可能遗失战利品", Color.ORANGE_RED)
		"loot_lost_on_retreat":
			var lost_name: String = str(data.get("item_name", "装备"))
			var remain: int = int(data.get("remaining", 0))
			_run_ui.show_run_hint(
				"返程受击！遗失 %s（剩余战利品 %d 件）" % [lost_name, remain],
				Color.ORANGE_RED
			)
		"withdraw_confirm":
			var st: int = int(data.get("stability", 0))
			_run_ui.show_run_hint("稳定度 %d，建议撤离" % st, Color.ORANGE)


func _count_combat_allies_alive() -> int:
	if _combat == null:
		return 0
	return _combat.count_active_allies()


func _mark_squad_wiped(run: WorldRun) -> void:
	if run == null:
		return
	run.squad_wiped = true
	for mid in run.squad_member_ids:
		var m: Mercenary = GameManager.find_mercenary_by_id(mid)
		if m != null:
			m.enter_mia_state()


func _should_execute_chase_catch_on_downed(run: WorldRun) -> bool:
	if run == null or not bool(run.map_data.get("chase_catch_executes_downed", false)):
		return false
	if run.squad == null:
		return false
	# 全队已无法再战但仍算存活 → 追击处决灭团（MIA）
	return run.squad.get_combat_ready_count() == 0 and run.squad.has_anyone_alive()


func _on_chase_stagger_released() -> void:
	var run = GameManager.current_run
	if run == null or _encounter_session == null or not _encounter_session.is_chase_boss() or _combat == null:
		return
	if run.chase_stagger_charge < 0.88:
		if _run_ui:
			_run_ui.show_run_hint("蓄力不足，继续按住「蓄力击退」", Color.ORANGE)
		return
	_resolve_chase_stagger_repel(run)


func _on_chase_deep_counter_pressed() -> void:
	var run = GameManager.current_run
	if run == null or GameManager.state != GameManager.GameState.RUNNING:
		return
	if _encounter_session == null or not _encounter_session.is_chase_boss() or _combat == null:
		if _run_ui:
			_run_ui.show_run_hint("深度反击仅在追击接战僵持时可用", Color.ORANGE)
		return
	var result: Dictionary = BossChaseService.try_deep_counter_strike(run, _combat)
	if not result.get("ok", false):
		var reason: String = str(result.get("reason", ""))
		var msg := "无法深度反击"
		match reason:
			"cooldown":
				msg = "深度反击冷却中（%.0fs）" % float(result.get("remaining", 0.0))
			"low_charge":
				msg = "僵持蓄力不足（需约 %.0f%%）" % (
					float(run.map_data.get("chase_deep_counter_min_charge", 0.22)) * 100.0
				)
			"unavailable":
				msg = "稳定度不足或条件未满足"
		if _run_ui:
			_run_ui.show_run_hint(msg, Color.ORANGE)
		return
	_resolve_chase_deep_counter_repel(run, result)


func _resolve_chase_deep_counter_repel(run: WorldRun, strike: Dictionary) -> void:
	var enemy_data: Dictionary = _encounter_session.primary_enemy() if _encounter_session else {}
	_in_combat = false
	_clear_encounter_session(run)
	run.chase_stagger_charge = 0.0
	run.chase_stagger_holding = false
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat.is_active = false
		_combat = null
	if not enemy_data.is_empty():
		run.register_chase_deep_counter_repelled(enemy_data)
	var push_mult: float = float(strike.get("push_mult", 1.65))
	var rewards: Dictionary = run.on_chase_boss_repelled(push_mult)
	_pending_enemies.clear()
	_finish_combat()
	if _run_ui:
		var dmg: int = int(strike.get("damage", 0))
		_run_ui.show_run_hint(
			"深度反击！重创首领并推远（-%d HP 伤 +%d 经验）" % [dmg, int(rewards.get("exp", 0))],
			Color(0.55, 0.95, 1.0)
		)
	if _combat_view:
		_combat_view.sync_from_active_combat()


func _resolve_chase_stagger_repel(run: WorldRun) -> void:
	var enemy_data: Dictionary = _encounter_session.primary_enemy() if _encounter_session else {}
	_in_combat = false
	_clear_encounter_session(run)
	run.chase_stagger_charge = 0.0
	run.chase_stagger_holding = false
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat.is_active = false
		_combat = null
	if not enemy_data.is_empty():
		run.register_chase_stagger_repelled(enemy_data)
	var push_mult: float = float(run.map_data.get("chase_stagger_push_mult", 1.35))
	run.on_chase_boss_repelled(push_mult)
	_pending_enemies.clear()
	_finish_combat()
	if _run_ui:
		_run_ui.show_run_hint("僵持击退！首领被推远，继续返程", Color.CYAN)
	if _combat_view:
		_combat_view.sync_from_active_combat()


func _on_chase_counter_pressed() -> void:
	var run = GameManager.current_run
	if run == null or GameManager.state != GameManager.GameState.RUNNING:
		return
	if _in_combat:
		return
	var result: Dictionary = run.try_chase_counter_strike()
	if not result.get("ok", false):
		var reason: String = str(result.get("reason", ""))
		var msg := "无法反击"
		match reason:
			"cooldown":
				msg = "反击冷却中（%.0fs）" % float(result.get("remaining", 0.0))
			"too_close":
				msg = "距离过近，请接战或快撤"
			"low_stability":
				msg = "稳定度不足（需约 %d）" % int(result.get("cost", 8))
			"in_combat":
				msg = "战斗中无法反击"
		if _run_ui:
			_run_ui.show_run_hint(msg, Color.ORANGE)
		return


func _on_manual_withdraw_pressed() -> void:
	var run = GameManager.current_run
	if run == null or GameManager.state != GameManager.GameState.RUNNING:
		return
	if run.is_retreating:
		return
	var exposed_n: int = run.exposed_loot.item_count() if run.exposed_loot else 0
	if exposed_n > 0 and _manual_withdraw_dialog:
		_manual_withdraw_dialog.dialog_text = (
			"放弃外露格 %d 件战利品，仅带走安全箱内容。\n"
			+ "不进入返程、无护盾，结算按战败档处理。\n\n确认斩仓撤离？"
		) % exposed_n
		_manual_withdraw_dialog.popup_centered()
		return
	_execute_manual_withdraw(run)


func _on_manual_withdraw_confirmed() -> void:
	var run = GameManager.current_run
	if run == null or GameManager.state != GameManager.GameState.RUNNING:
		return
	_execute_manual_withdraw(run)


func _execute_manual_withdraw(run: WorldRun) -> void:
	if run.is_retreating:
		return
	_abort_active_combat()
	var abandoned: int = run.prepare_manual_withdraw()
	if _run_ui:
		var msg := "手动斩仓：仅安全箱带回大营"
		if abandoned > 0:
			msg += "（已舍弃外露 %d 件）" % abandoned
		_run_ui.show_run_hint(msg, Color.ORANGE)
	_end_run(run, true)


func _end_run(run: WorldRun, forced: bool) -> void:
	# 防重入：state 已变更说明已结束
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	_in_combat = false
	_pending_enemies.clear()
	_clear_encounter_session(run)
	_finish_combat()
	if _run_march_lane:
		_run_march_lane.on_run_ended()
	GameManager.end_run(forced)


# --- 按钮回调 ---
func _on_upgrade_barracks() -> void:
	GameManager.upgrade_building("barracks")
	if _base_ui:
		_base_ui._refresh()

func _on_upgrade_forge() -> void:
	GameManager.upgrade_building("forge")
	if _base_ui:
		_base_ui._refresh()

func _on_upgrade_infirmary() -> void:
	GameManager.upgrade_building("infirmary")
	if _base_ui:
		_base_ui._refresh()

func _on_upgrade_warehouse() -> void:
	GameManager.upgrade_building("warehouse")
	if _base_ui:
		_base_ui._refresh()

func _on_recruit_normal() -> void:
	var code := GameManager.recruit_merc("normal")
	if code != 0:
		printerr("[Recruit] normal failed, code=%d" % code)
		if _base_ui:
			_base_ui.show_recruit_result("normal", code)
	else:
		if _base_ui:
			_base_ui.show_recruit_result("normal", 0)
			_base_ui._refresh()


func _on_recruit_elite() -> void:
	var code := GameManager.recruit_merc("elite")
	if code != 0:
		printerr("[Recruit] elite failed, code=%d" % code)
		if _base_ui:
			_base_ui.show_recruit_result("elite", code)
	else:
		if _base_ui:
			_base_ui.show_recruit_result("elite", 0)
			_base_ui._refresh()


func _on_explore() -> void:
	GameManager.start_prepare("grassland")


func _on_map_selected(map_id: String) -> void:
	GameManager.start_prepare(map_id)
