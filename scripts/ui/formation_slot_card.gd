class_name FormationSlotCard
extends PanelContainer
## T-UI-B3 · 编组槽位卡牌（出战/替补）— 点击/拖拽/投放

const CARD_MIN_H := 40

var slot_half: String = ""
var slot_kind: String = ""
var slot_index: int = 0
var formation_ui: Control = null

var _accent: ColorRect = null
var _role_lbl: Label = null
var _name_lbl: Label = null
var _hp_bar: ProgressBar = null
var _badge_lbl: Label = null
var _press_pos: Vector2 = Vector2.ZERO
var _drag_started: bool = false

const DRAG_THRESHOLD := 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, CARD_MIN_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func apply_slot(
	merc_id: String,
	kind: String,
	index: int,
	selected: bool,
	ready: bool,
	name_text: String,
	hp_ratio: float,
	badge_text: String,
	accent: Color,
	panel_bg: Color
) -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_accent = null
	_role_lbl = null
	_name_lbl = null
	_hp_bar = null
	_badge_lbl = null

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_accent = ColorRect.new()
	_accent.custom_minimum_size = Vector2(4, 0)
	_accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_accent.color = accent
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_accent)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 2)
	row.add_child(body)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title_row)

	_role_lbl = Label.new()
	_role_lbl.text = "%s%d" % ["战" if kind == "active" else "替", index + 1]
	_role_lbl.add_theme_font_size_override("font_size", 10)
	_role_lbl.modulate = Color(0.6, 0.72, 0.85)
	_role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_role_lbl)

	_name_lbl = Label.new()
	_name_lbl.text = name_text
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 12)
	_name_lbl.clip_text = true
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_name_lbl)

	_badge_lbl = Label.new()
	_badge_lbl.text = badge_text
	_badge_lbl.add_theme_font_size_override("font_size", 10)
	_badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_badge_lbl)

	if merc_id != "":
		var rm := Button.new()
		rm.name = "SlotRemoveBtn"
		rm.text = "×"
		rm.tooltip_text = "移出至未编入"
		rm.custom_minimum_size = Vector2(28, 22)
		rm.add_theme_font_size_override("font_size", 12)
		rm.mouse_filter = Control.MOUSE_FILTER_STOP
		rm.pressed.connect(func(): call_deferred("_on_remove_pressed"))
		title_row.add_child(rm)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "SlotHpBar"
	_hp_bar.custom_minimum_size = Vector2(0, 8)
	_hp_bar.max_value = 100.0
	_hp_bar.value = hp_ratio * 100.0
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.78, 0.45) if ready else Color(0.85, 0.55, 0.3)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.16)
	_hp_bar.add_theme_stylebox_override("background", bg)
	body.add_child(_hp_bar)

	var panel := StyleBoxFlat.new()
	panel.corner_radius_top_left = 4
	panel.corner_radius_top_right = 4
	panel.corner_radius_bottom_left = 4
	panel.corner_radius_bottom_right = 4
	panel.content_margin_left = 6
	panel.content_margin_top = 4
	panel.content_margin_right = 6
	panel.content_margin_bottom = 4
	panel.bg_color = panel_bg
	if selected:
		panel.border_width_left = 2
		panel.border_width_top = 2
		panel.border_width_right = 2
		panel.border_width_bottom = 2
		panel.border_color = Color(0.4, 0.9, 0.65)
	add_theme_stylebox_override("panel", panel)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			call_deferred("_on_remove_pressed")
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_drag_started = false
			elif not _drag_started and not _local_point_over_child_button(event.position):
				call_deferred("_on_hit_pressed")
			accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _drag_started or _local_point_over_child_button(_press_pos):
			return
		if _press_pos.distance_to(event.position) < DRAG_THRESHOLD:
			return
		var data: Variant = _build_drag_payload()
		if data == null:
			return
		_drag_started = true
		var m := GameManager.find_mercenary_by_id(str(data.get("merc_id", "")))
		var preview := Label.new()
		preview.text = m.merc_name if m else str(data.get("merc_id", ""))
		preview.modulate = Color(0.7, 1.0, 0.85)
		force_drag(data, preview)
		accept_event()


func _local_point_over_child_button(local_pos: Vector2) -> bool:
	var global_mp: Vector2 = get_global_transform() * local_pos
	for btn in _descendant_buttons(self):
		if btn is Control and (btn as Control).get_global_rect().has_point(global_mp):
			return true
	return false


func _descendant_buttons(node: Node) -> Array:
	var out: Array = []
	if node is BaseButton:
		out.append(node)
	for child in node.get_children():
		out.append_array(_descendant_buttons(child))
	return out


func _on_hit_pressed() -> void:
	if formation_ui != null and formation_ui.has_method("_on_slot_pressed"):
		formation_ui._on_slot_pressed(slot_half, slot_kind, slot_index)


func _on_remove_pressed() -> void:
	if formation_ui == null or not formation_ui.has_method("_clear_slot"):
		return
	formation_ui._clear_slot(slot_half, slot_kind, slot_index)


func _build_drag_payload() -> Variant:
	if formation_ui == null or not formation_ui.has_method("_get_slot_merc_id"):
		return null
	var merc_id: String = formation_ui._get_slot_merc_id(slot_half, slot_kind, slot_index)
	if merc_id == "":
		return null
	return {
		"merc_id": merc_id,
		"half": slot_half,
		"kind": slot_kind,
		"index": slot_index,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("merc_id", "")) != ""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if formation_ui != null and formation_ui.has_method("_handle_slot_drop"):
		formation_ui._handle_slot_drop(slot_half, slot_kind, slot_index, data)
