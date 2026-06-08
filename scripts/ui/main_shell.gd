extends Control
class_name MainShell
## PlanningWindow 主壳（T-UI-TWIN-1）
## ShellVBox → TopBar / Toast / UpperArea / DockBar
## CQ 表演已迁至独立 StageWindow（`StageShell`）

const MIN_VIEWPORT_WIDTH := 1280
const TOP_BAR_HEIGHT := 40
const DOCK_HEIGHT := 48
const PANEL_COLLAPSED_WIDTH := 44
const PANEL_RATIO_LEFT := 0.32
const PANEL_RATIO_CENTER := 0.36
const PANEL_RATIO_RIGHT := 0.32
const BOTTOM_STAGE_HEAL_REFRESH_MS := 3000

var _base_ui: Control = null
var _squad_ui: Control = null
var _run_ui: Control = null
var _result_ui: Control = null

var _top_gold: Label = null
var _top_stability_bar: ProgressBar = null
var _top_stability_detail: Label = null
var _top_recovery: Label = null
var _top_map: Label = null
var _last_run_data: Dictionary = {}
var _left_slot: Control = null
var _center_slot: Control = null
var _right_slot: Control = null
var _left_panel: PanelContainer = null
var _center_panel: PanelContainer = null
var _right_panel: PanelContainer = null
var _left_placeholder: Label = null
var _center_placeholder: Label = null
var _right_placeholder: Label = null
var _lane_status_text: String = ""
var _narrow_hint: Label = null
var _upper_wrap: Control = null
var _upper_area: HBoxContainer = null
var _upper_overlay_host: Control = null
var _dock_hint: Label = null
var _dock_buttons: Dictionary = {}
var _toast_panel: PanelContainer = null
var _toast_label: Label = null
var _toast_timer: Timer = null

var _running_left_root: Control = null
var _running_center_root: Control = null
var _running_right_root: Control = null
var _run_log: RichTextLabel = null
var _run_hp_list: VBoxContainer = null
var _run_grid_ui: RunGridUI = null
var _result_grid_ui: RunGridUI = null
var _logistics_overlay: ColorRect = null
var _logistics_panel: PanelContainer = null
var _logistics_tabs: TabContainer = null
var _logistics_tab_buildings: VBoxContainer = null
var _logistics_tab_recruit: VBoxContainer = null
var _logistics_tab_recovery: VBoxContainer = null
var _logistics_tab_dead: VBoxContainer = null
var _recovery_ui: RecoveryUI = null
var _logistics_open: bool = false
var _panel_highlight_tween: Tween = null
var _panel_collapsed: Dictionary = {
	"left": false,
	"center": false,
	"right": false,
}
var _left_rail: Button = null
var _center_rail: Button = null
var _right_rail: Button = null
var _left_collapse_btn: Button = null
var _center_collapse_btn: Button = null
var _right_collapse_btn: Button = null


func setup(
	base_ui: Control,
	squad_ui: Control,
	run_ui: Control,
	result_ui: Control
) -> void:
	_base_ui = base_ui
	_squad_ui = squad_ui
	_run_ui = run_ui
	_result_ui = result_ui
	_build_layout()
	_build_logistics_popup()
	_build_running_panels()
	_attach_shell_content()
	_wire_dock()
	_connect_signals()
	set_process_unhandled_input(true)
	_check_viewport_width()
	resized.connect(_on_shell_resized)
	_hide_all_placeholders()
	call_deferred("apply_state", GameManager.state)


func attach_equipment_ui(equipment_ui: Control) -> void:
	if equipment_ui == null or _upper_overlay_host == null:
		return
	if equipment_ui.get_parent() != _upper_overlay_host:
		equipment_ui.reparent(_upper_overlay_host)
	equipment_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	equipment_ui.offset_left = 0
	equipment_ui.offset_top = 0
	equipment_ui.offset_right = 0
	equipment_ui.offset_bottom = 0
	equipment_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_lane_snapshot(lane: Dictionary) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	_lane_status_text = str(lane.get("status_text", ""))
	if _top_recovery:
		_top_recovery.text = _lane_status_text
		_top_recovery.modulate = Color(0.75, 0.9, 1.0)


func apply_state(state: int) -> void:
	if state != GameManager.GameState.RUNNING:
		_lane_status_text = ""
		_last_run_data.clear()
	_apply_default_panel_collapse(state)
	_refresh_top_bar(state)
	_apply_slot_visibility(state)
	_update_dock_highlight(state)
	if state == GameManager.GameState.BASE and _base_ui and _base_ui.has_method("schedule_refresh"):
		_base_ui.schedule_refresh()
	elif state == GameManager.GameState.BASE and _base_ui and _base_ui.has_method("_refresh"):
		call_deferred("_deferred_base_ui_refresh")
	if state == GameManager.GameState.PREPARE and _squad_ui and _squad_ui.has_method("_refresh"):
		_squad_ui._refresh()
	if state == GameManager.GameState.RUNNING:
		refresh_running_panels()
	elif state == GameManager.GameState.RESULT:
		_refresh_result_grid()


func refresh_running_panels() -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	var run = GameManager.current_run
	if _run_hp_list:
		for child in _run_hp_list.get_children():
			child.queue_free()
		if run and run.squad:
			for m in run.squad.members:
				var max_hp: int = maxi(1, StatResolver.get_max_hp(m))
				var lbl := Label.new()
				var tag := ""
				if m.is_test_stand_in:
					tag = " (测试·锁定)"
				elif m.is_near_death:
					tag = " (濒死)"
				elif m.current_hp < max_hp:
					tag = " (负伤)"
				lbl.text = "%s %d/%d HP%s" % [m.merc_name, m.current_hp, max_hp, tag]
				if m.is_test_stand_in:
					lbl.modulate = Color(0.75, 0.9, 1.0)
				elif m.is_near_death:
					lbl.modulate = Color(1.0, 0.45, 0.45)
				_run_hp_list.add_child(lbl)
	if _run_grid_ui and run:
		_run_grid_ui.refresh_from_run(run)


func _refresh_result_grid() -> void:
	if _result_grid_ui == null:
		return
	var run = GameManager.current_run
	if run and run.safe_loot and run.exposed_loot:
		_result_grid_ui.refresh_from_run(run)
	else:
		_result_grid_ui.show_empty_preview(
			GameManager.get_safe_box_grid_size(),
			_get_map_exposed_size(GameManager.selected_map_id)
		)


func _get_map_exposed_size(map_id: String) -> Vector2i:
	var md: Dictionary = DataLoader.map_data(map_id)
	return Vector2i(
		int(md.get("exposed_grid_w", 4)),
		int(md.get("exposed_grid_h", 3))
	)


func _build_layout() -> void:
	if get_node_or_null("ShellVBox") != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shell_vbox := VBoxContainer.new()
	shell_vbox.name = "ShellVBox"
	shell_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell_vbox.offset_left = 0
	shell_vbox.offset_top = 0
	shell_vbox.offset_right = 0
	shell_vbox.offset_bottom = 0
	add_child(shell_vbox)

	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0, TOP_BAR_HEIGHT)
	top_bar.add_theme_constant_override("separation", 16)
	shell_vbox.add_child(top_bar)

	_top_gold = _make_top_label(top_bar, "金币: 0")
	_build_top_stability(top_bar)
	_top_recovery = _make_top_label(top_bar, "")
	_top_recovery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_map = _make_top_label(top_bar, "地图: 大营")
	_top_map.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_build_toast(shell_vbox)

	_upper_wrap = Control.new()
	_upper_wrap.name = "UpperArea"
	_upper_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_upper_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_vbox.add_child(_upper_wrap)
	_upper_area = HBoxContainer.new()
	_upper_area.name = "UpperAreaHBox"
	_upper_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_upper_area.offset_left = 0
	_upper_area.offset_top = 0
	_upper_area.offset_right = 0
	_upper_area.offset_bottom = 0
	_upper_area.add_theme_constant_override("separation", 4)
	_upper_wrap.add_child(_upper_area)
	var upper := _upper_area

	var left_pack := _make_collapsible_panel(upper, "LeftPanel", PANEL_RATIO_LEFT, "left", "地图")
	_left_panel = left_pack.panel
	_left_slot = left_pack.slot
	_left_rail = left_pack.rail
	_left_collapse_btn = left_pack.collapse_btn
	_left_placeholder = _make_placeholder(_left_slot, "左窗 · 地图 / 结算")

	var center_pack := _make_collapsible_panel(upper, "CenterPanel", PANEL_RATIO_CENTER, "center", "编组")
	_center_panel = center_pack.panel
	_center_slot = center_pack.slot
	_center_rail = center_pack.rail
	_center_collapse_btn = center_pack.collapse_btn
	_center_placeholder = _make_placeholder(_center_slot, "中窗 · 编组 / 准备")

	var right_pack := _make_collapsible_panel(upper, "RightPanel", PANEL_RATIO_RIGHT, "right", "背包")
	_right_panel = right_pack.panel
	_right_slot = right_pack.slot
	_right_rail = right_pack.rail
	_right_collapse_btn = right_pack.collapse_btn
	_right_placeholder = _make_placeholder(_right_slot, "右窗 · 背包 / 网格 (T-05)")

	_apply_panel_collapse_layout()

	_upper_overlay_host = Control.new()
	_upper_overlay_host.name = "UpperOverlayHost"
	_upper_overlay_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_upper_overlay_host.offset_left = 0
	_upper_overlay_host.offset_top = 0
	_upper_overlay_host.offset_right = 0
	_upper_overlay_host.offset_bottom = 0
	_upper_overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upper_wrap.add_child(_upper_overlay_host)

	var dock := HBoxContainer.new()
	dock.name = "DockBar"
	dock.custom_minimum_size = Vector2(0, DOCK_HEIGHT)
	dock.add_theme_constant_override("separation", 8)
	shell_vbox.add_child(dock)

	_dock_buttons["deploy"] = _make_dock_button(dock, "出征", "F1")
	_dock_buttons["formation"] = _make_dock_button(dock, "编组", "F2")
	_dock_buttons["bag"] = _make_dock_button(dock, "背包", "F3")
	_dock_buttons["map"] = _make_dock_button(dock, "地图", "F4")
	_dock_buttons["logistics"] = _make_dock_button(dock, "后勤", "F5")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(spacer)
	_dock_hint = Label.new()
	_dock_hint.text = "◀ 可单独收起侧窗 · 设置=全部展开"
	_dock_hint.modulate = Color(0.55, 0.6, 0.7)
	dock.add_child(_dock_hint)
	_dock_buttons["settings"] = _make_dock_button(dock, "设置", "")

	_narrow_hint = Label.new()
	_narrow_hint.name = "NarrowWindowHint"
	_narrow_hint.text = "请放大窗口至 1280×720 以上"
	_narrow_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrow_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narrow_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narrow_hint.offset_left = 0
	_narrow_hint.offset_top = 0
	_narrow_hint.offset_right = 0
	_narrow_hint.offset_bottom = 0
	_narrow_hint.modulate = Color(1.0, 0.85, 0.4)
	var narrow_bg := ColorRect.new()
	narrow_bg.color = Color(0.05, 0.06, 0.1, 0.82)
	narrow_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	narrow_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(narrow_bg)
	add_child(_narrow_hint)
	_narrow_hint.visible = false
	narrow_bg.visible = false
	narrow_bg.name = "NarrowWindowBg"
	_narrow_hint.set_meta("bg", narrow_bg)


func show_toast(text: String, color: Color = Color(0.85, 0.95, 1.0), duration: float = 4.0) -> void:
	if text == "":
		return
	if _toast_label:
		_toast_label.text = text
		_toast_label.modulate = color
	if _toast_panel:
		_toast_panel.visible = true
	if _toast_timer:
		_toast_timer.stop()
		_toast_timer.wait_time = clampf(duration, 2.0, 8.0)
		_toast_timer.start()


func show_dock_hint(text: String) -> void:
	if _dock_hint:
		_dock_hint.text = text


func _build_toast(shell_vbox: VBoxContainer) -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastBar"
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.14, 0.2, 0.92)
	style.content_margin_left = 10
	style.content_margin_top = 4
	style.content_margin_right = 10
	style.content_margin_bottom = 4
	_toast_panel.add_theme_stylebox_override("panel", style)
	shell_vbox.add_child(_toast_panel)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast_panel.add_child(margin)
	_toast_label = Label.new()
	_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.max_lines_visible = 2
	_toast_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(_toast_label)
	_toast_timer = Timer.new()
	_toast_timer.name = "ToastTimer"
	_toast_timer.one_shot = true
	add_child(_toast_timer)
	_toast_timer.timeout.connect(func() -> void:
		if _toast_panel:
			_toast_panel.visible = false
	)


func _make_top_label(parent: HBoxContainer, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)
	return lbl


func _build_top_stability(parent: HBoxContainer) -> void:
	var box := HBoxContainer.new()
	box.name = "TopStabilityBox"
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(280, 0)
	var caption := Label.new()
	caption.text = "半组稳定"
	caption.add_theme_font_size_override("font_size", 11)
	caption.modulate = Color(0.75, 0.82, 0.9)
	box.add_child(caption)
	_top_stability_bar = ProgressBar.new()
	_top_stability_bar.name = "TopStabilityBar"
	_top_stability_bar.custom_minimum_size = Vector2(92, 14)
	_top_stability_bar.max_value = StabilitySystem.MAX_STABILITY
	_top_stability_bar.show_percentage = false
	box.add_child(_top_stability_bar)
	_top_stability_detail = Label.new()
	_top_stability_detail.name = "TopStabilityDetail"
	_top_stability_detail.add_theme_font_size_override("font_size", 11)
	box.add_child(_top_stability_detail)
	parent.add_child(box)
	_apply_stability_bar_visual(0)


func _stability_tint(value: int, max_value: int = StabilitySystem.MAX_STABILITY) -> Color:
	var cap: int = maxi(1, max_value)
	var withdraw: int = StabilitySystem.get_team_withdraw_threshold_for_max(cap)
	if value <= withdraw:
		return Color(1.0, 0.35, 0.35)
	if value <= int(float(cap) * 0.50):
		return Color(1.0, 0.72, 0.3)
	if value <= int(float(cap) * 0.70):
		return Color(0.95, 0.88, 0.35)
	return Color(0.45, 0.82, 0.55)


func _apply_stability_bar_visual(value: int, max_value: int = StabilitySystem.MAX_STABILITY) -> void:
	if _top_stability_bar == null:
		return
	var cap: int = maxi(1, max_value)
	_top_stability_bar.max_value = cap
	_top_stability_bar.value = clampi(value, 0, cap)
	var fill := StyleBoxFlat.new()
	fill.bg_color = _stability_tint(value, cap)
	_top_stability_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.14, 0.18)
	_top_stability_bar.add_theme_stylebox_override("background", bg)


func apply_run_snapshot(run_data: Dictionary) -> void:
	_last_run_data = run_data
	if GameManager.state == GameManager.GameState.RUNNING:
		_refresh_top_bar(GameManager.GameState.RUNNING)


func _make_collapsible_panel(
	parent: HBoxContainer,
	panel_name: String,
	ratio: float,
	side_key: String,
	rail_label: String
) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.clip_contents = true
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.name = "PanelRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 0
	row.offset_top = 0
	row.offset_right = 0
	row.offset_bottom = 0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)
	var rail := Button.new()
	rail.name = "%sRail" % panel_name
	rail.text = "▶\n%s" % rail_label
	rail.tooltip_text = "展开%s窗" % rail_label
	rail.custom_minimum_size = Vector2(PANEL_COLLAPSED_WIDTH, 0)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.visible = false
	rail.pressed.connect(_on_panel_rail_pressed.bind(side_key))
	row.add_child(rail)
	var slot := MarginContainer.new()
	slot.name = "%sSlot" % panel_name
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("margin_left", 6)
	slot.add_theme_constant_override("margin_top", 6)
	slot.add_theme_constant_override("margin_right", 6)
	slot.add_theme_constant_override("margin_bottom", 6)
	row.add_child(slot)
	var collapse_btn := Button.new()
	collapse_btn.name = "%sCollapse" % panel_name
	collapse_btn.text = "◀"
	collapse_btn.tooltip_text = "收起%s窗" % rail_label
	collapse_btn.custom_minimum_size = Vector2(26, 0)
	collapse_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collapse_btn.pressed.connect(_on_panel_collapse_pressed.bind(side_key))
	row.add_child(collapse_btn)
	return {
		"panel": panel,
		"slot": slot,
		"rail": rail,
		"collapse_btn": collapse_btn,
	}


func _panel_ratio(side_key: String) -> float:
	match side_key:
		"left":
			return PANEL_RATIO_LEFT
		"center":
			return PANEL_RATIO_CENTER
		"right":
			return PANEL_RATIO_RIGHT
		_:
			return 0.32


func _panel_by_side(side_key: String) -> PanelContainer:
	match side_key:
		"left":
			return _left_panel
		"center":
			return _center_panel
		"right":
			return _right_panel
		_:
			return null


func _slot_by_side(side_key: String) -> Control:
	match side_key:
		"left":
			return _left_slot
		"center":
			return _center_slot
		"right":
			return _right_slot
		_:
			return null


func _rail_by_side(side_key: String) -> Button:
	match side_key:
		"left":
			return _left_rail
		"center":
			return _center_rail
		"right":
			return _right_rail
		_:
			return null


func _collapse_btn_by_side(side_key: String) -> Button:
	match side_key:
		"left":
			return _left_collapse_btn
		"center":
			return _center_collapse_btn
		"right":
			return _right_collapse_btn
		_:
			return null


func _apply_default_panel_collapse(state: int) -> void:
	# 仅 RUNNING 默认收起左/中，突出底栏战斗与右窗战利品；其余状态三窗可同时满屏展开
	match state:
		GameManager.GameState.RUNNING:
			_panel_collapsed = {"left": true, "center": true, "right": false}
		GameManager.GameState.BASE, GameManager.GameState.PREPARE, GameManager.GameState.RESULT:
			_panel_collapsed = {"left": false, "center": false, "right": false}
		_:
			pass
	_apply_panel_collapse_layout()


func _set_panel_collapsed(side_key: String, collapsed: bool) -> void:
	if not _panel_collapsed.has(side_key):
		return
	_panel_collapsed[side_key] = collapsed
	_apply_panel_collapse_layout()


func _ensure_panel_expanded(side_key: String) -> void:
	_set_panel_collapsed(side_key, false)


func _expand_all_panels() -> void:
	for key in _panel_collapsed.keys():
		_panel_collapsed[key] = false
	_apply_panel_collapse_layout()


func _apply_panel_collapse_layout() -> void:
	for side_key in ["left", "center", "right"]:
		var collapsed: bool = bool(_panel_collapsed.get(side_key, false))
		var panel := _panel_by_side(side_key)
		var slot := _slot_by_side(side_key)
		var rail := _rail_by_side(side_key)
		var collapse_btn := _collapse_btn_by_side(side_key)
		if panel == null:
			continue
		if slot:
			slot.visible = not collapsed
		if rail:
			rail.visible = collapsed
		if collapse_btn:
			collapse_btn.visible = not collapsed
		if collapsed:
			panel.size_flags_stretch_ratio = 0.0
			panel.custom_minimum_size.x = PANEL_COLLAPSED_WIDTH
		else:
			panel.size_flags_stretch_ratio = _panel_ratio(side_key)
			panel.custom_minimum_size.x = 0


func _on_panel_rail_pressed(side_key: String) -> void:
	_ensure_panel_expanded(side_key)


func _on_panel_collapse_pressed(side_key: String) -> void:
	_set_panel_collapsed(side_key, true)


func _make_placeholder(slot: Control, text: String) -> Label:
	var lbl := Label.new()
	lbl.name = "Placeholder"
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.modulate = Color(0.5, 0.55, 0.65)
	slot.add_child(lbl)
	return lbl


func _make_dock_button(parent: HBoxContainer, label: String, shortcut: String) -> Button:
	var btn := Button.new()
	btn.text = label if shortcut == "" else "%s [%s]" % [label, shortcut]
	btn.custom_minimum_size = Vector2(72, 36)
	parent.add_child(btn)
	return btn


func _build_logistics_popup() -> void:
	var overlay_parent: Node = _upper_overlay_host if _upper_overlay_host else self
	_logistics_overlay = ColorRect.new()
	_logistics_overlay.name = "LogisticsOverlay"
	_logistics_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logistics_overlay.offset_left = 0
	_logistics_overlay.offset_top = 0
	_logistics_overlay.offset_right = 0
	_logistics_overlay.offset_bottom = 0
	_logistics_overlay.color = Color(0.04, 0.05, 0.08, 0.75)
	_logistics_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_logistics_overlay.visible = false
	overlay_parent.add_child(_logistics_overlay)
	_logistics_overlay.gui_input.connect(_on_logistics_overlay_input)
	_logistics_panel = PanelContainer.new()
	_logistics_panel.name = "LogisticsPanel"
	_logistics_panel.custom_minimum_size = Vector2(520, 420)
	_logistics_panel.set_anchors_preset(Control.PRESET_CENTER)
	_logistics_panel.offset_left = -260
	_logistics_panel.offset_top = -210
	_logistics_panel.offset_right = 260
	_logistics_panel.offset_bottom = 210
	_logistics_panel.visible = false
	overlay_parent.add_child(_logistics_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_logistics_panel.add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var title := Label.new()
	title.text = "后勤"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	_logistics_tabs = TabContainer.new()
	_logistics_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_logistics_tab_buildings = _add_logistics_tab(_logistics_tabs, "建筑")
	_logistics_tab_recruit = _add_logistics_tab(_logistics_tabs, "招募")
	_logistics_tab_recovery = _add_logistics_tab(_logistics_tabs, "回收")
	_logistics_tab_dead = _add_logistics_tab(_logistics_tabs, "阵亡")
	outer.add_child(_logistics_tabs)
	var close_btn := Button.new()
	close_btn.text = "关闭 [F5 / Esc]"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.pressed.connect(_close_logistics)
	outer.add_child(close_btn)


func _add_logistics_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_child_count() - 1, title)
	return body


func _build_running_panels() -> void:
	_running_left_root = VBoxContainer.new()
	_running_left_root.name = "RunningLeftLog"
	_running_left_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_running_left_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_title := Label.new()
	log_title.text = "—— 行程提示 ——"
	_running_left_root.add_child(log_title)
	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_log = RichTextLabel.new()
	_run_log.bbcode_enabled = true
	_run_log.scroll_following = true
	_run_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_log.custom_minimum_size = Vector2(0, 120)
	log_scroll.add_child(_run_log)
	_running_left_root.add_child(log_scroll)
	_left_slot.add_child(_running_left_root)
	_running_center_root = VBoxContainer.new()
	_running_center_root.name = "RunningCenterHp"
	_running_center_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_running_center_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hp_title := Label.new()
	hp_title.text = "—— 本趟成员 HP (只读) ——"
	_running_center_root.add_child(hp_title)
	var hp_scroll := ScrollContainer.new()
	hp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_hp_list = VBoxContainer.new()
	_run_hp_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_scroll.add_child(_run_hp_list)
	_running_center_root.add_child(hp_scroll)
	_center_slot.add_child(_running_center_root)
	_running_right_root = VBoxContainer.new()
	_running_right_root.name = "RunningRightGrid"
	_running_right_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_running_right_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_run_grid_ui = RunGridUI.new()
	_run_grid_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_grid_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_running_right_root.add_child(_run_grid_ui)
	_right_slot.add_child(_running_right_root)
	_result_grid_ui = RunGridUI.new()
	_result_grid_ui.name = "ResultGridSnapshot"
	_result_grid_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_grid_ui.visible = false


func _attach_shell_content() -> void:
	if _base_ui and _base_ui.has_method("attach_to_shell"):
		_base_ui.attach_to_shell(
			_left_slot,
			_center_slot,
			_right_slot,
			_logistics_tab_buildings,
			_logistics_tab_recruit,
			_logistics_tab_dead
		)
		if _base_ui.has_method("bind_main_shell"):
			_base_ui.bind_main_shell(self)
	_mount_recovery_ui()
	if _squad_ui and _squad_ui.has_method("attach_to_shell"):
		_squad_ui.attach_to_shell(_left_slot, _center_slot, _right_slot)
	if _result_ui and _result_ui.has_method("attach_to_shell"):
		_result_ui.attach_to_shell(_left_slot, _center_slot, _right_slot, _result_grid_ui)
		var bg := _result_ui.get_node_or_null("PanelBg") as ColorRect
		if bg:
			bg.visible = false


func _apply_slot_visibility(state: int) -> void:
	var is_base := state == GameManager.GameState.BASE
	var is_prepare := state == GameManager.GameState.PREPARE
	var is_running := state == GameManager.GameState.RUNNING
	var is_result := state == GameManager.GameState.RESULT
	if _base_ui:
		if _base_ui.shell_left_root:
			_base_ui.shell_left_root.visible = is_base
		if _base_ui.shell_center_root:
			_base_ui.shell_center_root.visible = is_base
		if _base_ui.shell_right_root:
			_base_ui.shell_right_root.visible = is_base
	if _squad_ui:
		if _squad_ui.shell_left_root:
			_squad_ui.shell_left_root.visible = is_prepare
		if _squad_ui.shell_center_root:
			_squad_ui.shell_center_root.visible = is_prepare
		if _squad_ui.shell_right_root:
			_squad_ui.shell_right_root.visible = is_prepare
	if _result_ui:
		if _result_ui.shell_left_root:
			_result_ui.shell_left_root.visible = is_result
		if _result_ui.shell_center_root:
			_result_ui.shell_center_root.visible = is_result
		if _result_ui.shell_right_root:
			_result_ui.shell_right_root.visible = is_result
	if _running_left_root:
		_running_left_root.visible = is_running
	if _running_center_root:
		_running_center_root.visible = is_running
	if _running_right_root:
		_running_right_root.visible = is_running
	if _result_grid_ui:
		_result_grid_ui.visible = is_result


func _hide_all_placeholders() -> void:
	if _left_placeholder:
		_left_placeholder.visible = false
	if _center_placeholder:
		_center_placeholder.visible = false
	if _right_placeholder:
		_right_placeholder.visible = false


func _append_run_log(text: String, color: Color) -> void:
	if _run_log == null or text == "":
		return
	var hex := color.to_html(false)
	_run_log.append_text("[color=#%s]%s[/color]\n" % [hex, text])
	while _run_log.get_line_count() > 80:
		_run_log.remove_paragraph(0)


func _mount_in_slot(node: Control, slot: Control) -> void:
	if node == null or slot == null:
		return
	var parent := node.get_parent()
	if parent != slot:
		if parent:
			parent.remove_child(node)
		slot.add_child(node)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _connect_signals() -> void:
	if not GameManager.gold_changed.is_connected(_on_gold_changed):
		GameManager.gold_changed.connect(_on_gold_changed)
	if not GameManager.formation_changed.is_connected(_on_formation_changed):
		GameManager.formation_changed.connect(_on_formation_changed)
	if not GameManager.formation_preference_changed.is_connected(_on_formation_preference_changed):
		GameManager.formation_preference_changed.connect(_on_formation_preference_changed)
	if not GameManager.roster_healed.is_connected(_on_roster_healed_top_bar):
		GameManager.roster_healed.connect(_on_roster_healed_top_bar)
	if not GameManager.state_changed.is_connected(_on_state_changed_top_bar):
		GameManager.state_changed.connect(_on_state_changed_top_bar)
	if _run_ui and not _run_ui.hint_posted.is_connected(_on_run_hint_posted):
		_run_ui.hint_posted.connect(_on_run_hint_posted)
	if not GameManager.run_started.is_connected(_on_run_started_clear_log):
		GameManager.run_started.connect(_on_run_started_clear_log)
	if not GameManager.run_ended.is_connected(_on_run_ended_refresh_grid):
		GameManager.run_ended.connect(_on_run_ended_refresh_grid)


func _on_run_ended_refresh_grid(_result: Dictionary) -> void:
	_refresh_result_grid()


func _on_run_started_clear_log() -> void:
	if _run_log:
		_run_log.clear()


func _on_run_hint_posted(text: String, color: Color) -> void:
	_append_run_log(text, color)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			_on_dock_deploy()
		KEY_F2:
			_on_dock_formation()
		KEY_F3:
			_on_dock_bag()
		KEY_F4:
			_on_dock_map()
		KEY_F5:
			_toggle_logistics()
		KEY_ESCAPE:
			if _logistics_open:
				_close_logistics()


func _wire_dock() -> void:
	if _dock_buttons.has("deploy"):
		_dock_buttons["deploy"].pressed.connect(_on_dock_deploy)
	if _dock_buttons.has("formation"):
		_dock_buttons["formation"].pressed.connect(_on_dock_formation)
	if _dock_buttons.has("map"):
		_dock_buttons["map"].pressed.connect(_on_dock_map)
	if _dock_buttons.has("bag"):
		_dock_buttons["bag"].pressed.connect(_on_dock_bag)
	if _dock_buttons.has("logistics"):
		_dock_buttons["logistics"].pressed.connect(_toggle_logistics)
	if _dock_buttons.has("settings"):
		_dock_buttons["settings"].pressed.connect(_on_dock_settings)


func _on_gold_changed(_amount: int) -> void:
	_refresh_top_bar(GameManager.state)


func _on_roster_healed_top_bar() -> void:
	_refresh_top_bar(GameManager.state)


func _on_formation_changed() -> void:
	call_deferred("_refresh_top_bar", GameManager.state)


func _on_formation_preference_changed(_half: String) -> void:
	call_deferred("_refresh_top_bar", GameManager.state)


func _on_state_changed_top_bar(state: int) -> void:
	_refresh_top_bar(state)


func _refresh_top_bar(state: int) -> void:
	if _top_gold:
		_top_gold.text = "金币: %d" % GameManager.gold
	_refresh_top_stability(state)
	if _top_recovery:
		if state == GameManager.GameState.RUNNING and _lane_status_text != "":
			_top_recovery.text = _lane_status_text
			_top_recovery.modulate = Color(0.75, 0.9, 1.0)
		elif GameManager.is_recovery_lock_active():
			var msg: String = SquadFormationService.get_recovery_lock_message(GameManager)
			if SquadFormationService.has_living_merc_roster(GameManager):
				var eta: float = float(
					SquadFormationService.get_recovery_status(GameManager).get("eta_seconds", 0.0)
				)
				if eta > 1.0:
					msg = "%s · 约%.0fs" % [msg, eta]
			_top_recovery.text = msg
			_top_recovery.modulate = Color(1.0, 0.55, 0.45)
		else:
			_top_recovery.text = ""
			_top_recovery.modulate = Color.WHITE


func _refresh_top_stability(state: int) -> void:
	var pref: String = SquadFormationService.get_preferred_half(GameManager)
	var bar_st: int = GameManager.get_deploy_half_stability(pref)
	var bar_max: int = GameManager.get_deploy_half_stability_max(pref)
	var detail: String = SquadFormationService.format_halves_stability_summary(GameManager)
	var pressure_hint := ""
	if state == GameManager.GameState.RUNNING and not _last_run_data.is_empty():
		bar_st = int(
			_last_run_data.get("team_stability", _last_run_data.get("stability", bar_st))
		)
		bar_max = int(_last_run_data.get("team_stability_max", bar_max))
		if bar_max <= 0:
			bar_max = maxi(bar_st, StabilitySystem.MAX_STABILITY)
		var personal_min: int = int(_last_run_data.get("min_personal_stability", bar_st))
		var run_half: String = str(GameManager.last_deploy_half)
		if run_half in [SquadFormationService.HALF_A, SquadFormationService.HALF_B]:
			detail = "半组%s %d/%d · 个人最低%d" % [run_half, bar_st, bar_max, personal_min]
		else:
			detail = "%d/%d · 个人最低%d" % [bar_st, bar_max, personal_min]
		var pressure: float = float(_last_run_data.get("stability_pressure", 1.0))
		if pressure > 1.01:
			pressure_hint = " ×%.1f" % pressure
	elif state == GameManager.GameState.PREPARE:
		var deploy_half: String = SquadFormationService.resolve_manual_deploy_half(GameManager)
		if deploy_half == "":
			deploy_half = pref
		bar_st = GameManager.get_deploy_half_stability(deploy_half)
		bar_max = GameManager.get_deploy_half_stability_max(deploy_half)
		detail = "半组%s %s（出征）" % [
			deploy_half,
			SquadFormationService.format_half_stability_text(GameManager, deploy_half),
		]
	elif state == GameManager.GameState.BASE:
		detail = SquadFormationService.format_halves_stability_summary(GameManager)
		bar_max = maxi(maxi(bar_max, bar_st), StabilitySystem.MAX_STABILITY)
	_apply_stability_bar_visual(bar_st, bar_max)
	if _top_stability_detail:
		_top_stability_detail.text = detail + pressure_hint
		_top_stability_detail.modulate = _stability_tint(bar_st, bar_max)
	if _top_map:
		match state:
			GameManager.GameState.BASE:
				var sel: String = GameManager.selected_map_id
				if sel != "" and GameManager.is_map_unlocked(sel):
					var base_md: Dictionary = DataLoader.map_data(sel)
					var sel_name: String = str(base_md.get("name", sel))
					_top_map.text = "已选：%s" % sel_name
				else:
					_top_map.text = "地图: 大营"
			GameManager.GameState.PREPARE, GameManager.GameState.RUNNING, GameManager.GameState.RESULT:
				var md: Dictionary = DataLoader.map_data(GameManager.selected_map_id)
				var map_name: String = str(md.get("name", GameManager.selected_map_id))
				_top_map.text = "地图: %s" % map_name
			_:
				_top_map.text = "地图: —"


func _update_dock_highlight(state: int) -> void:
	var active_key := "map"
	match state:
		GameManager.GameState.PREPARE, GameManager.GameState.RUNNING:
			active_key = "deploy"
		GameManager.GameState.RESULT:
			active_key = "bag"
		_:
			active_key = "map"
	for key in _dock_buttons:
		var btn: Button = _dock_buttons[key]
		if key == active_key:
			btn.modulate = Color(0.85, 1.0, 1.0)
		else:
			btn.modulate = Color.WHITE


func _highlight_panel(panel: PanelContainer, seconds: float = 2.0) -> void:
	if panel == null:
		return
	if _panel_highlight_tween and _panel_highlight_tween.is_valid():
		_panel_highlight_tween.kill()
	var hl := StyleBoxFlat.new()
	hl.border_width_left = 3
	hl.border_width_top = 3
	hl.border_width_right = 3
	hl.border_width_bottom = 3
	hl.border_color = Color(0.35, 0.75, 1.0, 1.0)
	hl.bg_color = Color(0.12, 0.16, 0.22, 0.35)
	panel.add_theme_stylebox_override("panel", hl)
	_panel_highlight_tween = create_tween()
	_panel_highlight_tween.tween_interval(seconds)
	_panel_highlight_tween.tween_callback(func() -> void:
		panel.remove_theme_stylebox_override("panel")
	)


func _on_dock_map() -> void:
	_ensure_panel_expanded("left")
	match GameManager.state:
		GameManager.GameState.BASE:
			if _base_ui and _base_ui.has_method("scroll_maps_list_to_top"):
				_base_ui.scroll_maps_list_to_top()
			if _base_ui and _base_ui.has_method("highlight_selected_map_card"):
				_base_ui.highlight_selected_map_card(2.0)
			_highlight_panel(_left_panel, 2.0)
			if _dock_hint:
				_dock_hint.text = "左窗 · 地图列表（点卡片选中，再点出征）"
		GameManager.GameState.PREPARE:
			if _squad_ui and _squad_ui.has_method("scroll_prepare_left_to_top"):
				_squad_ui.scroll_prepare_left_to_top()
			_highlight_panel(_left_panel, 2.0)
			if _dock_hint:
				_dock_hint.text = "左窗 · 本图详情（可展开）"
		GameManager.GameState.RUNNING:
			show_toast("行程中 · 地图信息见顶栏", Color(0.75, 0.85, 1.0), 3.0)
		_:
			pass


func _on_dock_formation() -> void:
	_ensure_panel_expanded("center")
	match GameManager.state:
		GameManager.GameState.BASE:
			if _base_ui and _base_ui.has_method("scroll_formation_into_view"):
				_base_ui.scroll_formation_into_view(2.0)
			_highlight_panel(_center_panel, 2.0)
			if _dock_hint:
				_dock_hint.text = "中窗 · 双半组编组"
		GameManager.GameState.PREPARE:
			if _squad_ui and _squad_ui.has_method("scroll_prepare_center_to_top"):
				_squad_ui.scroll_prepare_center_to_top()
			if _squad_ui and _squad_ui.has_method("pulse_prepare_center"):
				_squad_ui.pulse_prepare_center(2.0)
			_highlight_panel(_center_panel, 2.0)
			if _dock_hint:
				_dock_hint.text = "中窗 · 出征名单"
		_:
			pass


func _on_dock_bag() -> void:
	_ensure_panel_expanded("right")
	_highlight_panel(_right_panel, 2.0)
	if GameManager.state == GameManager.GameState.BASE and _base_ui:
		_base_ui._on_equipment_pressed()
	if _dock_hint:
		_dock_hint.text = "右窗 · 背包 / 装备"


func _on_dock_deploy() -> void:
	match GameManager.state:
		GameManager.GameState.BASE:
			if GameManager.selected_map_id != "" and GameManager.is_map_unlocked(GameManager.selected_map_id):
				GameManager.start_prepare(GameManager.selected_map_id)
			else:
				show_toast("请先在左窗点地图选中，再点出征", Color(1.0, 0.85, 0.5), 3.0)
				if _dock_hint:
					_dock_hint.text = "左窗 · 点卡片选中 → 出征"
		GameManager.GameState.PREPARE:
			var code: int = GameManager.start_run()
			if code != 0:
				show_toast(GameManager.get_run_start_error_message(code), Color.ORANGE_RED, 4.0)
		_:
			pass


func _toggle_logistics() -> void:
	if _logistics_open:
		_close_logistics()
	else:
		_open_logistics()


func _mount_recovery_ui() -> void:
	if _logistics_tab_recovery == null or _recovery_ui != null:
		return
	_recovery_ui = RecoveryUI.new()
	_recovery_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recovery_ui.bind_main_shell(self)
	_logistics_tab_recovery.add_child(_recovery_ui)


func refresh_base_panels() -> void:
	if _base_ui and _base_ui.has_method("refresh_from_shell"):
		_base_ui.refresh_from_shell()
	if _recovery_ui:
		_recovery_ui.refresh()


func _open_logistics() -> void:
	_sync_upper_overlay_bounds()
	_logistics_open = true
	if _logistics_overlay:
		_logistics_overlay.visible = true
		_logistics_overlay.move_to_front()
	if _logistics_panel:
		_logistics_panel.visible = true
		_logistics_panel.move_to_front()
	refresh_base_panels()
	if _base_ui and _base_ui.has_method("schedule_refresh"):
		_base_ui.schedule_refresh()
	elif _base_ui and _base_ui.has_method("_refresh"):
		call_deferred("_deferred_base_ui_refresh")
	if _dock_hint:
		_dock_hint.text = "后勤：建筑升级 / 招募 / 阵亡名册"


func _deferred_base_ui_refresh() -> void:
	if _base_ui and _base_ui.has_method("_refresh"):
		_base_ui._refresh()


func _close_logistics() -> void:
	_logistics_open = false
	if _logistics_overlay:
		_logistics_overlay.visible = false
	if _logistics_panel:
		_logistics_panel.visible = false


func _on_logistics_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_logistics()


func _on_dock_settings() -> void:
	_expand_all_panels()
	if _dock_hint:
		_dock_hint.text = "已展开全部侧窗（点 ◀ 可单独收起；战斗速度见 Stage 窗 Debug）"


func _on_shell_resized() -> void:
	_check_viewport_width()
	_sync_upper_overlay_bounds()


func _sync_upper_overlay_bounds() -> void:
	if _upper_overlay_host == null:
		return
	_upper_overlay_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upper_overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _check_viewport_width() -> void:
	var vp := get_viewport_rect().size
	var narrow := vp.x < MIN_VIEWPORT_WIDTH
	if _narrow_hint:
		_narrow_hint.visible = narrow
	var bg: ColorRect = _narrow_hint.get_meta("bg") if _narrow_hint.has_meta("bg") else null
	if bg:
		bg.visible = narrow
