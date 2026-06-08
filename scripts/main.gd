extends Control
## Main — 单窗 1280×720 + RunDriver（T-UI-REEL-1）

const WINDOW_WIDTH := 1280
const WINDOW_HEIGHT := 720

var _main_shell: MainShell = null
var _base_ui: Control = null
var _squad_ui: Control = null
var _run_ui: Control = null
var _result_ui: Control = null
var _manual_withdraw_dialog: ConfirmationDialog = null
var _run_driver: RunDriver = RunDriver.new()
var _shutting_down: bool = false


func _ready() -> void:
	randomize()
	_configure_main_window()
	_find_ui_refs()
	_run_driver.bind_ui(_main_shell, _run_ui, null, null)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.run_started.connect(_on_run_started)
	_setup_manual_withdraw_dialog()
	call_deferred("_on_state_changed", GameManager.state)


func _configure_main_window() -> void:
	var main_win := get_window() as Window
	if main_win == null:
		return
	main_win.title = "TBH Idle RPG"
	main_win.size = Vector2i(WINDOW_WIDTH, WINDOW_HEIGHT)
	main_win.min_size = Vector2i(WINDOW_WIDTH, 560)


func _setup_manual_withdraw_dialog() -> void:
	_manual_withdraw_dialog = ConfirmationDialog.new()
	_manual_withdraw_dialog.title = "手动斩仓"
	_manual_withdraw_dialog.ok_button_text = "确认撤离"
	_manual_withdraw_dialog.cancel_button_text = "取消"
	_manual_withdraw_dialog.confirmed.connect(_on_manual_withdraw_confirmed)
	add_child(_manual_withdraw_dialog)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()


func _shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	GameManager.persist_on_shutdown()
	get_tree().quit()


func _find_ui_refs() -> void:
	_main_shell = get_node_or_null("MainShell") as MainShell
	_base_ui = get_node_or_null("BaseUI")
	_squad_ui = get_node_or_null("SquadUI")
	_run_ui = get_node_or_null("RunUI")
	_result_ui = get_node_or_null("ResultUI")
	if _main_shell == null:
		push_error("Main: MainShell 缺失")
		return
	_main_shell.setup(_base_ui, _squad_ui, _run_ui, _result_ui)
	var equip_ui := get_node_or_null("EquipmentUI") as Control
	if equip_ui and _main_shell:
		_main_shell.attach_equipment_ui(equip_ui)


func _on_state_changed(new_state: int) -> void:
	if _main_shell:
		_main_shell.apply_state(new_state)


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
