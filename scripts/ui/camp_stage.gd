class_name CampStage
extends PanelContainer
## T-UI-CAMP-1 · 中窗营地缩略（默认折叠；主 CQ 视觉在 StageBar/BottomStage）

const CHIP_MIN_W := 54
const CHIP_MIN_H := 76
const ACTIVE_KIND := "active"
const COLLAPSED_HEIGHT := 34
const EXPANDED_MIN_HEIGHT := 128

signal slot_chip_pressed(half: String, kind: String, index: int)

var formation_ui: Control = null

var _row_a: HBoxContainer = null
var _row_b: HBoxContainer = null
var _chip_nodes: Dictionary = {}
var _shell_built: bool = false
var _highlighted_key: String = ""
var _collapsed: bool = true
var _body: VBoxContainer = null
var _toggle_btn: Button = null


func _ready() -> void:
	_ensure_shell_built()


func is_collapsed() -> bool:
	return _collapsed


func set_collapsed(collapsed: bool) -> void:
	_ensure_shell_built()
	_collapsed = collapsed
	_apply_collapsed()


func _ensure_shell_built() -> void:
	if _shell_built:
		return
	_shell_built = true
	name = "CampStage"
	custom_minimum_size = Vector2(0, COLLAPSED_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_stage_style()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)
	_toggle_btn = Button.new()
	_toggle_btn.name = "CampToggle"
	_toggle_btn.flat = true
	_toggle_btn.custom_minimum_size = Vector2(24, 24)
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_btn.pressed.connect(_on_toggle_collapsed)
	header.add_child(_toggle_btn)
	var caption := Label.new()
	caption.text = "营地缩略（展开）· 主视觉在底栏"
	caption.add_theme_font_size_override("font_size", 10)
	caption.modulate = Color(0.72, 0.62, 0.48)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(caption)
	_body = VBoxContainer.new()
	_body.name = "CampBody"
	_body.add_theme_constant_override("separation", 4)
	col.add_child(_body)
	_body.add_child(_make_team_row("半组 A", SquadFormationService.HALF_A))
	_body.add_child(_make_team_row("半组 B", SquadFormationService.HALF_B))
	_apply_collapsed()


func _on_toggle_collapsed() -> void:
	_collapsed = not _collapsed
	_apply_collapsed()
	if not _collapsed and formation_ui != null and formation_ui.has_method("_refresh_camp_stage"):
		formation_ui.call_deferred("_refresh_camp_stage")


func _apply_collapsed() -> void:
	if _body:
		_body.visible = not _collapsed
	if _toggle_btn:
		_toggle_btn.text = "▸" if _collapsed else "▾"
	custom_minimum_size = Vector2(0, COLLAPSED_HEIGHT if _collapsed else EXPANDED_MIN_HEIGHT)


func _apply_stage_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.14, 0.11, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.42, 0.32, 0.22, 0.85)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 4
	add_theme_stylebox_override("panel", sb)


func _make_team_row(title: String, half: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 10)
	head.modulate = Color(0.82, 0.74, 0.58)
	block.add_child(head)
	var row := HBoxContainer.new()
	row.name = "CampRow%s" % half
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(row)
	if half == SquadFormationService.HALF_A:
		_row_a = row
	else:
		_row_b = row
	return block


func refresh_lineup(
	half_a_ids: Array[String],
	half_b_ids: Array[String],
	selected_key: String,
	slot_visual_fn: Callable
) -> void:
	_ensure_shell_built()
	_chip_nodes.clear()
	_highlighted_key = selected_key
	_refresh_row(_row_a, SquadFormationService.HALF_A, half_a_ids, selected_key, slot_visual_fn)
	_refresh_row(_row_b, SquadFormationService.HALF_B, half_b_ids, selected_key, slot_visual_fn)


func sync_lineup_visuals(
	half_a_ids: Array[String],
	half_b_ids: Array[String],
	selected_key: String,
	slot_visual_fn: Callable
) -> bool:
	if not _row_matches_ids(_row_a, SquadFormationService.HALF_A, half_a_ids):
		return false
	if not _row_matches_ids(_row_b, SquadFormationService.HALF_B, half_b_ids):
		return false
	_sync_row_visuals(_row_a, SquadFormationService.HALF_A, half_a_ids, selected_key, slot_visual_fn)
	_sync_row_visuals(_row_b, SquadFormationService.HALF_B, half_b_ids, selected_key, slot_visual_fn)
	return true


func _row_matches_ids(row: HBoxContainer, half: String, ids: Array[String]) -> bool:
	if row == null or row.get_child_count() != ids.size():
		return false
	for i in range(ids.size()):
		var key := _chip_key(half, i)
		if not _chip_nodes.has(key):
			return false
		var chip: PanelContainer = _chip_nodes[key] as PanelContainer
		if chip == null or chip.get_meta("merc_id", "") != ids[i]:
			return false
	return true


func _sync_row_visuals(
	row: HBoxContainer,
	half: String,
	ids: Array[String],
	selected_key: String,
	slot_visual_fn: Callable
) -> void:
	for i in range(ids.size()):
		var merc_id: String = ids[i]
		var key := _chip_key(half, i)
		var chip: PanelContainer = _chip_nodes[key] as PanelContainer
		if chip == null:
			continue
		var vis: Dictionary = slot_visual_fn.call(merc_id, ACTIVE_KIND)
		_apply_chip_content(chip, half, i, merc_id, selected_key, vis)


func _apply_chip_content(
	chip: PanelContainer,
	half: String,
	index: int,
	merc_id: String,
	selected_key: String,
	vis: Dictionary
) -> void:
	chip.set_meta("merc_id", merc_id)
	var accent: Color = vis.get("accent", Color(0.4, 0.45, 0.5))
	var ready: bool = bool(vis.get("ready", false))
	var key := _chip_key(half, index)
	var panel := chip.get_theme_stylebox("panel")
	var sb: StyleBoxFlat
	if panel is StyleBoxFlat:
		sb = (panel as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		sb = StyleBoxFlat.new()
		sb.corner_radius_top_left = 5
		sb.corner_radius_top_right = 5
		sb.corner_radius_bottom_left = 5
		sb.corner_radius_bottom_right = 5
	sb.bg_color = vis.get("bg", Color(0.12, 0.13, 0.16, 0.9))
	if key == selected_key:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.55, 0.9, 0.65)
	elif merc_id == "":
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.35, 0.32, 0.28, 0.7)
	else:
		sb.border_width_left = 0
		sb.border_width_top = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0
	chip.add_theme_stylebox_override("panel", sb)
	if chip.get_child_count() == 0:
		return
	var margin := chip.get_child(0) as MarginContainer
	if margin == null or margin.get_child_count() == 0:
		return
	var col := margin.get_child(0) as VBoxContainer
	if col == null or col.get_child_count() < 2:
		return
	var silhouette := col.get_child(0) as ColorRect
	var name_lbl := col.get_child(1) as Label
	if silhouette:
		if merc_id == "":
			silhouette.color = Color(0.22, 0.2, 0.18, 0.55)
		else:
			silhouette.color = _silhouette_fill(accent, ready)
	if name_lbl:
		if merc_id == "":
			name_lbl.text = "空"
			name_lbl.modulate = Color(0.5, 0.48, 0.44)
		else:
			var short_name: String = str(vis.get("name_text", ""))
			if short_name.length() > 8:
				short_name = short_name.substr(0, 7) + "…"
			name_lbl.text = short_name
			name_lbl.modulate = Color(0.88, 0.84, 0.78) if ready else Color(0.72, 0.65, 0.58)


func set_selection_highlight(selected_key: String) -> void:
	if selected_key == _highlighted_key:
		return
	var prev := _highlighted_key
	_highlighted_key = selected_key
	if prev != "" and _chip_nodes.has(prev):
		_apply_chip_selection_border(_chip_nodes[prev] as PanelContainer, prev, "")
	if selected_key != "" and _chip_nodes.has(selected_key):
		_apply_chip_selection_border(_chip_nodes[selected_key] as PanelContainer, selected_key, selected_key)


func count_filled_chips() -> int:
	var n: int = 0
	for key in _chip_nodes.keys():
		var chip: PanelContainer = _chip_nodes[key]
		if chip != null and chip.get_meta("merc_id", "") != "":
			n += 1
	return n


func pulse_focus(seconds: float = 2.0) -> void:
	if _collapsed:
		_collapsed = false
		_apply_collapsed()
	var orig: Color = modulate
	modulate = Color(1.05, 0.95, 0.82)
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds * 0.85))
	tween.tween_property(self, "modulate", orig, maxf(0.1, seconds * 0.15))


func _refresh_row(
	row: HBoxContainer,
	half: String,
	ids: Array[String],
	selected_key: String,
	slot_visual_fn: Callable
) -> void:
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.free()
	for i in range(ids.size()):
		var merc_id: String = ids[i]
		var vis: Dictionary = slot_visual_fn.call(merc_id, ACTIVE_KIND)
		var chip := _make_chip(half, i, merc_id, selected_key, vis)
		row.add_child(chip)
		_chip_nodes[_chip_key(half, i)] = chip


func _make_chip(
	half: String,
	index: int,
	merc_id: String,
	selected_key: String,
	vis: Dictionary
) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "CampChip_%s_%d" % [half, index]
	chip.custom_minimum_size = Vector2(CHIP_MIN_W, CHIP_MIN_H)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.set_meta("merc_id", merc_id)
	chip.set_meta("half", half)
	chip.set_meta("index", index)
	var accent: Color = vis.get("accent", Color(0.4, 0.45, 0.5))
	var ready: bool = bool(vis.get("ready", false))
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.bg_color = vis.get("bg", Color(0.12, 0.13, 0.16, 0.9))
	var key := _chip_key(half, index)
	if key == selected_key:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.55, 0.9, 0.65)
	elif merc_id == "":
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.35, 0.32, 0.28, 0.7)
	chip.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	chip.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	margin.add_child(col)
	var silhouette := ColorRect.new()
	silhouette.custom_minimum_size = Vector2(CHIP_MIN_W - 12, 36)
	if merc_id == "":
		silhouette.color = Color(0.22, 0.2, 0.18, 0.55)
	else:
		silhouette.color = _silhouette_fill(accent, ready)
	col.add_child(silhouette)
	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	if merc_id == "":
		name_lbl.text = "空"
		name_lbl.modulate = Color(0.5, 0.48, 0.44)
	else:
		var short_name: String = str(vis.get("name_text", ""))
		if short_name.length() > 8:
			short_name = short_name.substr(0, 7) + "…"
		name_lbl.text = short_name
		name_lbl.modulate = Color(0.88, 0.84, 0.78) if ready else Color(0.72, 0.65, 0.58)
	col.add_child(name_lbl)
	chip.gui_input.connect(_on_chip_gui_input.bind(half, index))
	_chip_nodes[key] = chip
	return chip


func _on_chip_gui_input(event: InputEvent, half: String, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			slot_chip_pressed.emit(half, ACTIVE_KIND, index)


func _apply_chip_selection_border(chip: PanelContainer, key: String, selected_key: String) -> void:
	if chip == null:
		return
	var panel := chip.get_theme_stylebox("panel")
	if not panel is StyleBoxFlat:
		return
	var sb := (panel as StyleBoxFlat).duplicate() as StyleBoxFlat
	if key == selected_key and selected_key != "":
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.55, 0.9, 0.65)
	else:
		var merc_id: String = chip.get_meta("merc_id", "")
		if merc_id == "":
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.35, 0.32, 0.28, 0.7)
		else:
			sb.border_width_left = 0
			sb.border_width_top = 0
			sb.border_width_right = 0
			sb.border_width_bottom = 0
	chip.add_theme_stylebox_override("panel", sb)


func _chip_key(half: String, index: int) -> String:
	return "%s_%s_%d" % [half, ACTIVE_KIND, index]


func _silhouette_fill(accent: Color, ready: bool) -> Color:
	if ready:
		return accent.lerp(Color(0.92, 0.9, 0.86), 0.35)
	return accent.darkened(0.25)
