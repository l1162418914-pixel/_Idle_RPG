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


func _ready() -> void:
	randomize()
	_find_ui_refs()
	GameManager.state_changed.connect(_on_state_changed)
	
	# 初始状态
	_on_state_changed(GameManager.state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.force_auto_save()


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
	
	if _in_combat:
		_tick_combat(delta, run)
	else:
		_tick_exploration(delta, run)


func _tick_exploration(delta: float, run: WorldRun) -> void:
	var result = run.tick(delta)
	
	# 更新 UI
	if _run_ui:
		_run_ui.update_display(result)
	
	# 处理事件
	var events: Array = result.get("events", [])
	for ev in events:
		match ev.type:
			"enemy_spawn":
				_pending_enemies.append(ev.data)
				# 累积一定敌人后进入战斗
				if _pending_enemies.size() >= 2 or ev.data.get("is_boss", false):
					_start_combat(run)
			
			"boss":
				_pending_enemies.append(ev.data)
				if not _in_combat:
					_start_combat(run)
	
	# 检查撤离
	if run.is_retreating or run.stability.should_withdraw():
		_end_run(run, true)
		return
	
	# Boss被击败
	if run.boss_defeated:
		_end_run(run, false)


func _start_combat(run: WorldRun) -> void:
	if _pending_enemies.is_empty():
		return
	if _in_combat:
		return
	
	_combat = CombatController.new()
	
	# CombatView 必须在 init_combat 之前连接信号，否则 combat_started 先于连接触发
	if _combat_view:
		_combat_view.init_for_combat(_combat)
	
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.entity_dead.connect(_on_combat_entity_dead)
	_combat.init_combat(run.squad, _pending_enemies, run)
	
	_in_combat = true
	_combat_resolved_enemies.clear()


func _tick_combat(delta: float, run: WorldRun) -> void:
	if _combat == null:
		_in_combat = false
		return
	
	var result = _combat.tick(delta)
	
	if result.status == "victory":
		_in_combat = false
		for e_data in _pending_enemies:
			run.register_enemy_defeat(e_data)
		_combat_resolved_enemies = _pending_enemies.duplicate()
		_pending_enemies.clear()
		_finish_combat()
		
	elif result.status == "defeat":
		# 全队覆没
		_in_combat = false
		_pending_enemies.clear()
		_finish_combat()
		_end_run(run, true)
	
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
		if entity.source_merc and entity.source_merc is Player:
			# 主角倒下
			if run:
				_end_run(run, true)


func _finish_combat() -> void:
	if _combat:
		_combat.sync_allies_hp_to_mercs()
		_combat = null
	if _combat_view:
		_combat_view.cleanup()


func _end_run(run: WorldRun, forced: bool) -> void:
	# 防重入：state 已变更说明已结束
	if GameManager.state != GameManager.GameState.RUNNING:
		return
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
