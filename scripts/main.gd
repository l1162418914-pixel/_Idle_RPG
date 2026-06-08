extends Control
## Main — 主场景薄壳：Planning 根窗 + StageWindow 屏坐标固定的兄弟窗 + RunDriver

const STAGE_WINDOW_SCENE := preload("res://scenes/stage_window.tscn")
const PLANNING_WIDTH := 1280
const PLANNING_HEIGHT := 460
const STAGE_HEIGHT := 260

var _main_shell: MainShell = null
var _stage_window: Window = null
var _stage_shell: StageShell = null
var _base_ui: Control = null
var _squad_ui: Control = null
var _run_ui: Control = null
var _result_ui: Control = null
var _combat_view: CombatView = null
var _run_march_lane: RunMarchLane = null
var _manual_withdraw_dialog: ConfirmationDialog = null
var _run_driver: RunDriver = RunDriver.new()
var _shutting_down: bool = false
var _syncing_stage_layout: bool = false
var _stage_screen_anchored: bool = false


func _ready() -> void:
	randomize()
	_configure_planning_window()
	_find_ui_refs()
	_setup_stage_window()
	_attach_planning_as_stage_child()
	if _stage_shell and _run_ui:
		_stage_shell.setup(_run_ui, _main_shell)
		_combat_view = _stage_shell.get_combat_view()
		_run_march_lane = _stage_shell.get_run_march_lane()
	_run_driver.bind_ui(_main_shell, _run_ui, _combat_view, _run_march_lane)
	if _run_ui and _run_ui.has_method("bind_combat_view"):
		_run_ui.bind_combat_view(_combat_view)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.run_started.connect(_on_run_started)
	_setup_manual_withdraw_dialog()
	call_deferred("_on_state_changed", GameManager.state)


func _configure_planning_window() -> void:
	var main_win := get_window() as Window
	if main_win == null:
		return
	main_win.title = "TBH Idle RPG — 管理"
	main_win.size = Vector2i(PLANNING_WIDTH, PLANNING_HEIGHT)
	main_win.min_size = Vector2i(PLANNING_WIDTH, 360)
	if main_win.has_signal("size_changed"):
		if not main_win.size_changed.is_connected(_on_planning_window_size_changed):
			main_win.size_changed.connect(_on_planning_window_size_changed)


func _setup_stage_window() -> void:
	if _stage_window != null:
		return
	_stage_window = STAGE_WINDOW_SCENE.instantiate() as Window
	if _stage_window == null:
		push_error("Main: StageWindow 场景加载失败")
		return
	_stage_window.name = "StageWindow"
	_stage_window.title = "TBH Idle RPG — Stage"
	_stage_shell = _stage_window.get_node_or_null("StageShell") as StageShell
	if _stage_shell == null:
		push_error("Main: StageShell 缺失")
		return
	if not _stage_window.close_requested.is_connected(_on_stage_window_close_requested):
		_stage_window.close_requested.connect(_on_stage_window_close_requested)
	if _stage_window.has_signal("size_changed"):
		if not _stage_window.size_changed.is_connected(_on_stage_window_size_changed):
			_stage_window.size_changed.connect(_on_stage_window_size_changed)
	_stage_window.size = Vector2i(PLANNING_WIDTH, STAGE_HEIGHT)


func _attach_planning_as_stage_child() -> void:
	if _stage_window == null:
		return
	var planning_win := get_window() as Window
	if planning_win == null:
		return
	if not planning_win.close_requested.is_connected(_on_planning_window_close_requested):
		planning_win.close_requested.connect(_on_planning_window_close_requested)
	var root := get_tree().root
	var parent := _stage_window.get_parent()
	if parent != root:
		if parent != null:
			parent.remove_child(_stage_window)
		root.add_child(_stage_window)
	_stage_window.transient = false
	planning_win.visible = true
	planning_win.show()
	_stage_window.show()
	call_deferred("_sync_twin_window_layout", true)


func _sync_twin_window_layout(anchor_stage: bool = false) -> void:
	if _syncing_stage_layout or _stage_window == null:
		return
	_syncing_stage_layout = true
	var planning_win := get_window() as Window
	if planning_win != null:
		var w: int = maxi(maxi(planning_win.size.x, _stage_window.size.x), PLANNING_WIDTH)
		planning_win.size = Vector2i(w, PLANNING_HEIGHT)
		_stage_window.size = Vector2i(w, STAGE_HEIGHT)
		if anchor_stage or not _stage_screen_anchored:
			_stage_window.position = Vector2i(
				planning_win.position.x,
				planning_win.position.y + planning_win.size.y
			)
			_stage_screen_anchored = true
		planning_win.visible = true
		planning_win.show()
		_stage_window.visible = true
		_stage_window.show()
	_syncing_stage_layout = false


func _on_planning_window_close_requested() -> void:
	_shutdown_all_windows()


func _on_planning_window_size_changed() -> void:
	_sync_twin_window_layout(true)


func _on_stage_window_size_changed() -> void:
	_sync_twin_window_layout(false)


func _setup_manual_withdraw_dialog() -> void:
	_manual_withdraw_dialog = ConfirmationDialog.new()
	_manual_withdraw_dialog.title = "手动斩仓"
	_manual_withdraw_dialog.ok_button_text = "确认撤离"
	_manual_withdraw_dialog.cancel_button_text = "取消"
	_manual_withdraw_dialog.confirmed.connect(_on_manual_withdraw_confirmed)
	add_child(_manual_withdraw_dialog)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown_all_windows()


func _on_stage_window_close_requested() -> void:
	_shutdown_all_windows()


func _shutdown_all_windows() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	GameManager.persist_on_shutdown()
	if _stage_window and is_instance_valid(_stage_window):
		_stage_window.hide()
		_stage_window.queue_free()
		_stage_window = null
		_stage_shell = null
	get_tree().quit()


func _find_ui_refs() -> void:
	_main_shell = get_node_or_null("MainShell") as MainShell
	_base_ui = get_node_or_null("BaseUI")
	_squad_ui = get_node_or_null("SquadUI")
	_run_ui = get_node_or_null("RunUI")
	_result_ui = get_node_or_null("ResultUI")
	if _main_shell == null:
		push_error("Main: MainShell 缺失，Planning 壳为唯一上窗路径")
		return
	_main_shell.setup(_base_ui, _squad_ui, _run_ui, _result_ui)
	_main_shell.bind_window_host(self)
	var equip_ui := get_node_or_null("EquipmentUI") as Control
	if equip_ui and _main_shell:
		_main_shell.attach_equipment_ui(equip_ui)


func focus_stage_window() -> void:
	if _stage_window == null or not is_instance_valid(_stage_window):
		return
	_stage_window.grab_focus()
	if _stage_window.has_method("move_to_foreground"):
		_stage_window.move_to_foreground()


func raise_planning_subwindow() -> void:
	var planning_win := get_window() as Window
	if planning_win == null:
		return
	# 角标/建筑点击只开上窗浮层，不重置下窗屏坐标、不抢焦点（避免 WM 带动 Stage 位移）
	planning_win.visible = true
	planning_win.show()


func _on_state_changed(new_state: int) -> void:
	if _main_shell:
		_main_shell.apply_state(new_state)
	if _stage_shell:
		_stage_shell.apply_state(new_state)


func _process(delta: float) -> void:
	_run_driver.process(delta)


func _on_run_started() -> void:
	_run_driver.on_run_started()


func _on_chase_stagger_released() -> void:
	_run_driver.on_chase_stagger_released()


func _on_chase_deep_counter_pressed() -> void:
	_run_driver.on_chase_deep_counter_pressed()


func _on_chase_counter_pressed() -> void:
	_run_driver.on_chase_counter_pressed()


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
	_run_driver.execute_manual_withdraw(run)


func _on_manual_withdraw_confirmed() -> void:
	var run = GameManager.current_run
	if run == null or GameManager.state != GameManager.GameState.RUNNING:
		return
	_run_driver.execute_manual_withdraw(run)


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
