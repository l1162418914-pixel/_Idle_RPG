extends Node
## Main — 主场景，驱动 GameManager 循环

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
var _chase_combat_active: bool = false


func _ready() -> void:
	randomize()
	_find_ui_refs()
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.run_started.connect(_on_run_started)
	
	# 初始状态
	_on_state_changed(GameManager.state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameManager.persist_on_shutdown()


func _find_ui_refs() -> void:
	_base_ui = get_node_or_null("BaseUI")
	_squad_ui = get_node_or_null("SquadUI")
	_run_ui = get_node_or_null("RunUI")
	_result_ui = get_node_or_null("ResultUI")
	_combat_view = _run_ui.get_node_or_null("MarginContainer/MainVBox/CombatView") if _run_ui else null


func _on_state_changed(new_state: int) -> void:
	_show_only(new_state)


func _show_only(state: int) -> void:
	if _base_ui: _base_ui.visible = (state == GameManager.GameState.BASE)
	if _squad_ui: _squad_ui.visible = (state == GameManager.GameState.PREPARE)
	if _run_ui: _run_ui.visible = (state == GameManager.GameState.RUNNING)
	if _result_ui: _result_ui.visible = (state == GameManager.GameState.RESULT)


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


func _tick_world_run(delta: float, run: WorldRun) -> void:
	var result = run.tick(delta)
	
	if _run_ui:
		_run_ui.update_display(result)
	
	var events: Array = result.get("events", [])
	for ev in events:
		match ev.type:
			"enemy_spawn":
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


func _start_combat(run: WorldRun) -> void:
	if _pending_enemies.is_empty():
		return
	if _in_combat:
		return
	if run.squad == null:
		_pending_enemies.clear()
		return
	if run.squad.get_battlefield_members().is_empty():
		_pending_enemies.clear()
		return
	
	_combat = CombatController.new()
	
	# CombatView 必须在 init_combat 之前连接信号，否则 combat_started 先于连接触发
	if _combat_view:
		_combat_view.init_for_combat(_combat)
	
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.entity_dead.connect(_on_combat_entity_dead)
	_combat.init_combat(run.squad, _pending_enemies, run)
	if _combat_view:
		_combat_view.sync_from_active_combat()
	
	_in_combat = true
	_combat_resolved_enemies.clear()


func _start_chase_boss_combat(run: WorldRun) -> void:
	if _in_combat:
		return
	_pending_enemies.clear()
	_pending_enemies.append(run.build_chase_boss_encounter())
	_chase_combat_active = true
	run.chase_combat_in_progress = true
	if _run_ui:
		_run_ui.show_run_hint("首领追上你了！接战！", Color.ORANGE_RED)
	_start_combat(run)


func _tick_combat(delta: float, run: WorldRun, world_run_already_ticked: bool = false) -> void:
	if _combat == null:
		_in_combat = false
		return
	if run.is_retreating:
		_combat.set_march_retreat_combat(true)
	
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
	
	if not world_run_already_ticked and run.stability and run.stability.should_withdraw():
		_abort_combat_for_forced_withdraw(run)
		return
	
	if result.status == "victory":
		_in_combat = false
		if _chase_combat_active:
			for e_data in _pending_enemies:
				run.register_chase_boss_defeat(e_data)
			run.on_chase_boss_repelled()
			_chase_combat_active = false
			if _run_ui:
				_run_ui.show_run_hint("击退首领！争取距离后快撤…", Color.SKY_BLUE)
		else:
			for e_data in _pending_enemies:
				run.register_enemy_defeat(e_data)
		_combat_resolved_enemies = _pending_enemies.duplicate()
		_pending_enemies.clear()
		_finish_combat()
		
	elif result.status == "defeat":
		_in_combat = false
		if _chase_combat_active:
			_chase_combat_active = false
			_pending_enemies.clear()
			if _combat:
				_combat.sync_allies_hp_to_mercs()
				_combat = null
			run.chase_combat_in_progress = false
			if run.squad and run.squad.has_anyone_alive():
				run.on_chase_boss_catch_penalty()
				if _run_ui:
					_run_ui.show_run_hint("接战失利！稳定度大跌，首领仍在靠近", Color.ORANGE_RED)
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
		else:
			_pending_enemies.clear()
			if _combat:
				_combat.sync_allies_hp_to_mercs()
				_combat = null
			run.chase_combat_in_progress = false
			if run.squad and run.squad.has_anyone_alive():
				var hint := "战斗失利，紧急撤离！"
				if run.squad.has_any_member_near_death():
					hint = "队员濒死，紧急撤离！（返程移速减半）"
				_trigger_emergency_retreat_from_combat(run, hint)
			else:
				_mark_squad_wiped(run)
				_finish_combat()
				_end_run(run, false)
	
	elif not _in_combat:
		# tick 内已通过 entity_dead → _end_run 结束战斗，收尾
		_pending_enemies.clear()
		_finish_combat()


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
					var hint := "队伍溃散，紧急撤离！"
					if run.squad.has_any_member_near_death():
						hint = "队员濒死，紧急撤离！（返程移速减半）"
					_trigger_emergency_retreat_from_combat(run, hint)
				else:
					_mark_squad_wiped(run)
					_end_run(run, false)


func _trigger_emergency_retreat_from_combat(run: WorldRun, hint: String) -> void:
	_in_combat = false
	_pending_enemies.clear()
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat.force_end()
		_combat = null
	run.chase_combat_in_progress = false
	_chase_combat_active = false
	if not run.is_retreating:
		run.begin_retreat("emergency")
	elif run.retreat_shield_current <= 0:
		run.refresh_retreat_shield("emergency")
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
	if run:
		run.chase_combat_in_progress = false
		if run.stability:
			run.stability.refresh_pressure_multipliers()
		_process_run_retreats(run)
	if _combat_view:
		_clear_combat_view_after_run(run)


func _clear_combat_view_after_run(run: WorldRun) -> void:
	if run != null and run.is_retreating:
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
	_chase_combat_active = false
	var run := GameManager.current_run
	if run:
		run.chase_combat_in_progress = false
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
	if not hp_names.is_empty() and _run_ui:
		_run_ui.show_run_hint("%s 血量过低，已撤离队伍" % ", ".join(hp_names), Color.ORANGE)
	if not morale_names.is_empty() and _run_ui:
		_run_ui.show_run_hint("%s 个人稳定度过低，已撤离队伍" % ", ".join(morale_names), Color.GOLD)


func _on_run_started() -> void:
	var run = GameManager.current_run
	if run == null:
		return
	if not run.run_event.is_connected(_on_world_run_event):
		run.run_event.connect(_on_world_run_event)
	if _run_ui and _run_ui.has_method("reset_run_hints"):
		_run_ui.reset_run_hints()


func _on_world_run_event(event_name: String, data: Dictionary) -> void:
	if _run_ui == null:
		return
	match event_name:
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
		"boss_chase_started":
			_run_ui.show_run_hint("首领开始追击！注意头顶距离", Color.ORANGE)
		"boss_chase_repelled":
			var gap: float = float(data.get("gap", 0))
			_run_ui.show_run_hint("首领被击退 %.0fm，趁现在快跑！" % gap, Color.SKY_BLUE)
		"boss_chase_penalty":
			_run_ui.show_run_hint("接战失利！稳定度大跌，首领仍在靠近", Color.ORANGE_RED)
		"retreat_shield_started":
			var sh: int = int(data.get("shield", 0))
			var sh_max: int = int(data.get("shield_max", sh))
			_run_ui.show_run_hint("护卫护盾 %d/%d（领队生命上限）" % [sh, sh_max], Color.CYAN)
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
	if run == null or run.squad == null:
		return
	for m in run.squad.members:
		m.mark_permanent_death()


func _on_manual_withdraw_pressed() -> void:
	var run = GameManager.current_run
	if run == null or GameManager.state != GameManager.GameState.RUNNING:
		return
	if run.is_retreating:
		return
	run.manual_withdraw()
	if _run_ui:
		_run_ui.show_run_hint("已下令撤离，沿来路返回（遇敌可战，行程不中断）", Color.SKY_BLUE)


func _end_run(run: WorldRun, forced: bool) -> void:
	# 防重入：state 已变更说明已结束
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	_chase_combat_active = false
	_in_combat = false
	_pending_enemies.clear()
	_finish_combat()
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
