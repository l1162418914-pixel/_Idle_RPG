class_name RunDriver
extends RefCounted
## 出征驱动 — WorldRun.tick + 接战生命周期（从 main.gd 迁出）

const _EXTRACT_ITEM_SERVICE_PATH := "res://scripts/run/extract_item_service.gd"
const _PATH_MARCH_SEARCH := "res://scripts/run/march_search_service.gd"
const _PATH_MARCH_EVENT := "res://scripts/run/march_event_service.gd"

var _march_service_cache: Dictionary = {}

var _main_shell: MainShell = null
var _run_ui: Control = null
var _combat_view: CombatView = null
var _run_march_lane: RunMarchLane = null

var _pending_enemies: Array = []
var _combat: CombatController = null
var _in_combat: bool = false
var _combat_resolved_enemies: Array = []
var _encounter_session: EncounterSession = null
var _last_probe_tick_dist: float = -1.0
var _pending_substitute: Dictionary = {}
var _pending_substitute_until_ms: int = 0
var _pending_gather_settle: Dictionary = {}


func _march_service(path: String) -> Script:
	if not _march_service_cache.has(path):
		_march_service_cache[path] = load(path)
	return _march_service_cache[path] as Script


func bind_ui(
	main_shell: MainShell,
	run_ui: Control,
	combat_view: CombatView,
	run_march_lane: RunMarchLane
) -> void:
	_main_shell = main_shell
	_run_ui = run_ui
	_combat_view = combat_view
	_run_march_lane = run_march_lane
	if _run_march_lane and not _run_march_lane.gather_beat_finished.is_connected(_on_gather_beat_finished):
		_run_march_lane.gather_beat_finished.connect(_on_gather_beat_finished)


func process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	var run = GameManager.current_run
	if run == null or not run.is_active:
		return
	
	var gather_active: bool = _run_march_lane != null and _run_march_lane.is_gather_active()
	var world_run_ticked: bool = (run.is_retreating or not _in_combat) and not gather_active
	var march_allowed: bool = world_run_ticked and not _in_combat
	if world_run_ticked:
		_tick_world_run(delta, run, march_allowed)
	if _in_combat:
		_tick_combat(delta, run, world_run_ticked)
	_tick_pending_substitute()
	_sync_run_march_lane(run, world_run_ticked)


func _tick_world_run(delta: float, run: WorldRun, march_allowed: bool = true) -> void:
	var result = run.tick(delta)
	_emit_march_search_hits(run, march_allowed)
	_emit_march_event_hits(run, march_allowed)
	if run.is_retreating and run.squad != null and not run.squad.has_anyone_alive():
		_mark_squad_wiped(run)
		_end_run(run, false)
		return
	
	if _run_ui:
		var lane_snap: Dictionary = _run_march_lane.get_snapshot() if _run_march_lane else {}
		_run_ui.update_display(result, lane_snap)
	if _main_shell and _main_shell.has_method("apply_run_snapshot"):
		_main_shell.apply_run_snapshot(result)
	if run.boss_chase_active:
		RunProbeLog.log_chase_state(
			float(result.get("boss_chase_gap", run.get_boss_chase_gap())),
			float(result.get("chase_counter_cooldown", 0.0)),
			run.chase_combat_in_progress,
			run.distance_traveled
		)
	if _main_shell and _main_shell.has_method("refresh_running_panels"):
		_main_shell.refresh_running_panels()
	
	var events: Array = result.get("events", [])
	for ev in events:
		match ev.type:
			"enemy_spawn":
				if run.chase_combat_in_progress:
					RunProbeLog.log_spawn_blocked("chase_combat_in_progress", ev.data)
					continue
				if _in_combat and _encounter_session != null and not _encounter_session.allows_pending_append():
					RunProbeLog.log_spawn_blocked(
						"encounter_no_append",
						ev.data,
						_encounter_session.kind
					)
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
			if _should_execute_chase_catch_on_downed(run):
				if _run_ui:
					_run_ui.show_run_hint("追猎者追上濒死编队，全军覆没…", Color.ORANGE_RED)
				run.emit_signal("run_event", "boss_chase_catch_execute", {"gap": run.get_boss_chase_gap()})
				_mark_squad_wiped(run)
				_end_run(run, false)
				return
			_start_chase_boss_combat(run)
			return
		if run.has_completed_retreat():
			_end_run(run, true)
		return
	
	if run.stability.should_withdraw() and not run.is_retreating:
		PressureOutcomeService.trigger_team_pressure_retreat(run)
		return
	
	if run.run_mode == WorldRun.RunMode.RECOVERY and run.has_completed_recovery_advance():
		_end_run(run, true)
		return

	if run.run_mode == WorldRun.RunMode.RESCUE and run.has_completed_rescue_advance():
		_end_run(run, true)
		return
	
	if run.boss_defeated and not run.is_retreating:
		_end_run(run, false)
		return
	
	if run.extract_guard_cleared and not run.is_retreating:
		_end_run(run, false)


func _start_combat(run: WorldRun) -> void:
	if run != null and run.run_mode == WorldRun.RunMode.RESCUE:
		_pending_enemies.clear()
		return
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
	_pending_enemies.clear()
	_pending_enemies = session.enemies.duplicate()
	session.on_combat_begin(run)
	
	_combat = CombatController.new()
	
	# CombatView 必须在 init_combat 之前连接信号，否则 combat_started 先于连接触发
	if _combat_view:
		_combat_view.init_for_combat(_combat)
		_combat_view.reset_march_scroll_binding()
	
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.entity_dead.connect(_on_combat_entity_dead)
	if _run_march_lane:
		_run_march_lane.on_combat_start(run, session.is_boss_lane() or session.is_chase_boss())
	var anchor_dist: float = run.distance_traveled
	if _run_march_lane:
		anchor_dist = _run_march_lane.party_anchor_x
	if _combat_view and run.is_retreating:
		_combat_view.begin_retreat_combat_scroll(anchor_dist)
	BattleDebug.prepare_for_combat(run.map_data)
	_combat.init_combat(run.squad, session.enemies, run, anchor_dist)
	_combat.set_movement_policy(session.movement_policy_for(run))
	if _combat_view:
		_combat_view.sync_from_active_combat()
	
	_in_combat = true
	_combat_resolved_enemies.clear()
	RunProbeLog.log_encounter_begin(session.kind, session.enemies, run.distance_traveled)
	if session.is_chase_boss():
		if _combat_view and _combat_view.has_method("refresh_chase_combat_hud"):
			_combat_view.refresh_chase_combat_hud(run)
		if _run_ui and _run_ui.has_method("show_chase_standoff_banner"):
			_run_ui.show_chase_standoff_banner(run.chase_stagger_charge)


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
		if _combat_view and _combat_view.has_method("refresh_chase_combat_hud"):
			_combat_view.refresh_chase_combat_hud(run)
		if _run_ui and _run_ui.has_method("show_chase_standoff_banner"):
			_run_ui.show_chase_standoff_banner(run.chase_stagger_charge)
	
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
	
	elif result.status == "inactive" and _in_combat:
		_in_combat = false
		_pending_enemies.clear()
		_clear_encounter_session(run)
		_combat = null
		_finish_combat()
	
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
			_clear_encounter_session(run, "victory:end_run")
			if _run_ui and outcome.has("hint"):
				_run_ui.show_run_hint(str(outcome.hint), outcome.get("hint_color", Color.GREEN))
			_finish_combat()
			_end_run(run, false)
		"chase_repel":
			run.on_chase_boss_repelled(float(outcome.get("push_mult", 1.0)))
			_pending_enemies.clear()
			_clear_encounter_session(run, "victory:chase_repel")
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
			_clear_encounter_session(run, "victory:finish")
			_finish_combat()


func _apply_defeat_outcome(run: WorldRun, outcome: Dictionary) -> void:
	var action: String = str(outcome.get("action", "emergency_retreat"))
	_pending_enemies.clear()
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat = null
	match action:
		"chase_defeat":
			_clear_encounter_session(run, "defeat:chase_defeat")
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
					PressureOutcomeService.trigger_team_pressure_retreat(run)
			else:
				_mark_squad_wiped(run)
				if _combat_view:
					_clear_combat_view_after_run(run)
				_end_run(run, false)
		"emergency_retreat":
			if outcome.get("clear_pending_guard", false):
				run.pending_extract_guard = null
			_clear_encounter_session(run, "defeat:emergency_retreat")
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
			_clear_encounter_session(run, "defeat:wipe")
			_mark_squad_wiped(run)
			_finish_combat()
			_end_run(run, false)


func _clear_encounter_session(run: WorldRun, outcome: String = "cleared") -> void:
	if _encounter_session != null:
		var kind: int = _encounter_session.kind
		_encounter_session.on_combat_end(run)
		var dist: float = run.distance_traveled if run else -1.0
		RunProbeLog.log_encounter_end(kind, outcome, dist)
	_encounter_session = null


func _on_combat_ended(victory: bool) -> void:
	pass


func _on_combat_entity_dead(entity: CombatEntity) -> void:
	if not _in_combat or _combat == null:
		return
	if entity.team == CombatEntity.Team.ALLY:
		var run = GameManager.current_run
		if entity.source_merc is Player:
			if run and PlayerForcedReturnService.mercs_continue_on_field(run):
				return
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
	_pending_enemies.clear()
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat = null
	var run := GameManager.current_run
	_clear_encounter_session(run)
	if _run_ui and _run_ui.has_method("clear_chase_standoff_banner"):
		_run_ui.clear_chase_standoff_banner()
	if _combat_view and _combat_view.has_method("hide_chase_combat_panel"):
		_combat_view.hide_chase_combat_panel()
	if _run_march_lane and run:
		_run_march_lane.on_combat_end(run)
	if _combat_view:
		_clear_combat_view_after_run(run)
	if run:
		if run.stability:
			run.stability.refresh_pressure_multipliers()
		_process_run_retreats(run)
		if run.pending_extract_guard != null and not _in_combat and not run.is_retreating:
			_start_extract_guard_combat(run)


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


func _apply_pressure_substitute_in_combat(data: Dictionary) -> void:
	if _combat == null or not _in_combat:
		return
	var out_m := GameManager.find_mercenary_by_id(str(data.get("out_merc_id", "")))
	var in_m := GameManager.find_mercenary_by_id(str(data.get("in_merc_id", "")))
	if out_m == null or in_m == null:
		return
	var preferred_slot: int = -1
	for entity in _combat.allies:
		if entity.source_merc == out_m:
			preferred_slot = entity.formation_slot
			break
	if not _combat.eject_pressure_substitute(out_m):
		return
	if _combat_view and _combat_view.has_method("sync_from_active_combat"):
		_combat_view.sync_from_active_combat()
	var sec: float = float(PressureOutcomeService.config().get("substitute_swap_sec", 1.4))
	_pending_substitute = {
		"in_merc_id": in_m.merc_id,
		"preferred_slot": preferred_slot,
		"out_name": str(data.get("out_name", "")),
		"in_name": str(data.get("in_name", "")),
	}
	_pending_substitute_until_ms = Time.get_ticks_msec() + int(sec * 1000.0)
	if _run_ui and _run_ui.has_method("play_substitute_swap_overlay"):
		_run_ui.play_substitute_swap_overlay(
			str(data.get("out_name", "")),
			str(data.get("in_name", "")),
			sec
		)


func _tick_pending_substitute() -> void:
	if _pending_substitute.is_empty():
		return
	if Time.get_ticks_msec() < _pending_substitute_until_ms:
		return
	var in_id: String = str(_pending_substitute.get("in_merc_id", ""))
	var slot: int = int(_pending_substitute.get("preferred_slot", -1))
	_pending_substitute.clear()
	_pending_substitute_until_ms = 0
	if _combat == null or not _in_combat:
		return
	var in_m := GameManager.find_mercenary_by_id(in_id)
	if in_m == null:
		return
	if _combat.deploy_pressure_substitute(in_m, slot):
		if _combat_view and _combat_view.has_method("sync_from_active_combat"):
			_combat_view.sync_from_active_combat()


func _abort_combat_for_forced_withdraw(run: WorldRun) -> void:
	if not _in_combat:
		if not run.is_retreating:
			PressureOutcomeService.trigger_team_pressure_retreat(run)
		_process_run_retreats(run)
		return
	abort_active_combat()
	if not run.is_retreating:
		PressureOutcomeService.trigger_team_pressure_retreat(run)
	_process_run_retreats(run)


func abort_active_combat() -> void:
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
	if _in_combat and _combat_view:
		_combat_view.apply_march_lane_scroll(
			float(snap.get("scroll_x", run.distance_traveled)),
			run.is_retreating,
			true
		)
	if snap.get("freeze_distance", false):
		RunProbeLog.log_distance_frozen(
			run.distance_traveled,
			float(snap.get("display_distance", run.distance_traveled)),
			str(snap.get("lane_state", ""))
		)
	elif world_run_ticked:
		var dist: float = run.distance_traveled
		var delta: float = dist - _last_probe_tick_dist if _last_probe_tick_dist >= 0.0 else 0.0
		RunProbeLog.log_distance_tick(dist, delta)
		_last_probe_tick_dist = dist
	if _run_ui and _run_ui.has_method("apply_lane_snapshot"):
		_run_ui.apply_lane_snapshot(snap)
	if _run_ui and _run_ui.has_method("show_probe_summary"):
		_run_ui.show_probe_summary(RunProbeLog.get_summary_line())
	if _main_shell and _main_shell.has_method("apply_lane_snapshot"):
		_main_shell.apply_lane_snapshot(snap)


func on_run_started() -> void:
	var run = GameManager.current_run
	if run == null:
		return
	_pending_gather_settle.clear()
	_last_probe_tick_dist = run.distance_traveled
	RunProbeLog.clear_on_run_start(run.map_id)
	if _run_march_lane:
		var party_n: int = run.squad.get_combat_ready_count() if run.squad else 1
		_run_march_lane.on_run_started(run, party_n)
	if _combat_view:
		_combat_view.prepare_between_encounters()
	if not run.run_event.is_connected(on_world_run_event):
		run.run_event.connect(on_world_run_event)
	if _run_ui and _run_ui.has_method("reset_run_hints"):
		_run_ui.reset_run_hints()
	if _run_ui and _run_ui.has_method("show_probe_summary"):
		_run_ui.show_probe_summary(RunProbeLog.get_summary_line())
	var md: Dictionary = run.map_data
	var banner: String = TestScenarioService.get_run_start_banner(md)
	if banner != "" and _run_ui:
		_run_ui.show_run_hint(banner, Color(0.75, 0.9, 1.0))


func _emit_march_search_hits(run: WorldRun, world_run_ticked: bool) -> void:
	for hit in _march_service(_PATH_MARCH_SEARCH).tick(run, world_run_ticked):
		_emit_run_event_payload(run, hit)


func _emit_march_event_hits(run: WorldRun, world_run_ticked: bool) -> void:
	for hit in _march_service(_PATH_MARCH_EVENT).tick(run, world_run_ticked):
		_emit_run_event_payload(run, hit)


func _emit_run_event_payload(run: WorldRun, hit: Dictionary) -> void:
	var event_name: String = str(hit.get("event_name", ""))
	var data: Dictionary = hit.get("data", {})
	if event_name == "":
		return
	run.emit_signal("run_event", event_name, data)


func on_world_run_event(event_name: String, data: Dictionary) -> void:
	if event_name == "march_event" and bool(data.get("effects_deferred", false)):
		_pending_gather_settle = data.duplicate(true)
		if _run_ui:
			_run_ui.show_run_hint(
				"【事件】%s（搜刮中）" % str(data.get("log", "路旁事件。")),
				Color(0.88, 0.78, 0.55)
			)
		if _run_march_lane:
			_run_march_lane.on_march_event(data)
		return
	RunEventPresenter.present(event_name, data, _run_ui, GameManager.current_run)
	if event_name == "march_search_hit" and _run_march_lane:
		_run_march_lane.show_search_toast(data)
	if event_name == "march_event" and _run_march_lane:
		_run_march_lane.on_march_event(data)
	if event_name == "pressure_substitute":
		_apply_pressure_substitute_in_combat(data)
	elif event_name == "player_forced_return":
		_apply_player_forced_return_in_combat(data)


func _on_gather_beat_finished(_event_id: String) -> void:
	var run := GameManager.current_run
	if run == null or _pending_gather_settle.is_empty():
		return
	var settled: Dictionary = _pending_gather_settle.duplicate(true)
	_march_service(_PATH_MARCH_EVENT).apply_pending_effects(run, settled)
	_pending_gather_settle.clear()
	RunEventPresenter.present("march_event", settled, _run_ui, run)


func _apply_player_forced_return_in_combat(data: Dictionary) -> void:
	if _combat == null:
		return
	var player := GameManager.player
	if player == null:
		return
	for entity in _combat.allies.duplicate():
		if entity.source_merc == player:
			_combat.allies.erase(entity)
			break
	if _combat_view and _combat_view.has_method("sync_from_active_combat"):
		_combat_view.sync_from_active_combat()
	var run := GameManager.current_run
	if run == null:
		return
	if bool(data.get("mercs_continue", false)):
		return
	_trigger_emergency_retreat_from_combat(
		run,
		"指挥官撤退，佣兵紧急撤离！",
		"emergency"
	)


func _count_combat_allies_alive() -> int:
	if _combat == null:
		return 0
	return _combat.count_active_allies()


func _mark_squad_wiped(run: WorldRun) -> void:
	if run == null:
		return
	if run.run_mode == WorldRun.RunMode.RECOVERY:
		run.recovery_failed = true
		run.squad_wiped = false
		if run.squad != null:
			for m in run.squad.members:
				if m != null and not TestScenarioService.test_merc_blocks_casualties(m):
					m.apply_near_death_state(0.08)
		return
	if run.run_mode == WorldRun.RunMode.RESCUE:
		run.rescue_failed = true
		run.squad_wiped = false
		return
	if run.is_retreating or run.retreat_reason in ["forced", "emergency", "combat_fail", "pressure"]:
		run.retreat_failure = true
		run.squad_wiped = false
		return
	run.squad_wiped = true
	if run.squad != null:
		for m in run.squad.members:
			if m != null and not TestScenarioService.test_merc_blocks_casualties(m):
				m.enter_mia_state()
		return
	for mid in run.squad_member_ids:
		var merc = GameManager.find_mercenary_by_id(mid)
		if merc != null and not TestScenarioService.test_merc_blocks_casualties(merc):
			merc.enter_mia_state()


func _should_execute_chase_catch_on_downed(run: WorldRun) -> bool:
	if run == null or not bool(run.map_data.get("chase_catch_executes_downed", false)):
		return false
	if run.squad == null:
		return false
	# 全队已无法再战但仍算存活 → 追击处决灭团（MIA）
	return run.squad.get_combat_ready_count() == 0 and run.squad.has_anyone_alive()


func on_chase_stagger_released() -> void:
	var run = GameManager.current_run
	if run == null or _encounter_session == null or not _encounter_session.is_chase_boss() or _combat == null:
		return
	if run.chase_stagger_charge < 0.88:
		if _run_ui:
			_run_ui.show_run_hint("蓄力不足，继续按住「蓄力击退」", Color.ORANGE)
		return
	_resolve_chase_stagger_repel(run)


func on_chase_deep_counter_pressed() -> void:
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
	if _combat_view and _combat_view.has_method("hide_chase_combat_panel"):
		_combat_view.hide_chase_combat_panel()
	if _run_ui and _run_ui.has_method("clear_chase_standoff_banner"):
		_run_ui.clear_chase_standoff_banner()
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
	if _combat_view and _combat_view.has_method("hide_chase_combat_panel"):
		_combat_view.hide_chase_combat_panel()
	if _run_ui and _run_ui.has_method("clear_chase_standoff_banner"):
		_run_ui.clear_chase_standoff_banner()
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


func on_chase_counter_pressed() -> void:
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




func execute_manual_withdraw(run: WorldRun) -> void:
	if run.is_retreating:
		return
	abort_active_combat()
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
	RunProbeLog.log_run_end()
	GameManager.end_run(forced)
