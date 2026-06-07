class_name FormationPoolButton
extends Button
## 未编入 / 养伤备战席：点击编入、拖拽到半组槽位

var merc_id: String = ""
var formation_ui: Control = null
var bench_only: bool = false
var pool_disabled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	flat = false
	custom_minimum_size = Vector2(96, 36)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_font_size_override("font_size", 11)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.22, 0.3, 0.98)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 10
	sb.content_margin_top = 6
	sb.content_margin_right = 10
	sb.content_margin_bottom = 6
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.45, 0.58, 0.9)
	add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.28, 0.38, 0.98)
	add_theme_stylebox_override("hover", hover)
	var pressed_sb := sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = Color(0.14, 0.18, 0.26, 0.98)
	add_theme_stylebox_override("pressed", pressed_sb)
	add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	add_theme_color_override("font_hover_color", Color(0.96, 0.99, 1.0))
	add_theme_color_override("font_pressed_color", Color(0.85, 0.9, 0.98))
	pressed.connect(_on_pressed)


func apply_pool(text: String, not_clickable: bool, modulate_color: Color, bench_only_mode: bool = false) -> void:
	bench_only = bench_only_mode
	pool_disabled = not_clickable
	self.text = text
	modulate = modulate_color
	disabled = not_clickable
	if not_clickable:
		tooltip_text = ""
	elif bench_only_mode:
		tooltip_text = "养伤佣兵仅可编入替补席（先点「替」空槽，或拖入替补槽）"
	else:
		tooltip_text = "点选编入；按住拖动到半组槽位"


func _on_pressed() -> void:
	if pool_disabled or merc_id == "":
		return
	if formation_ui != null and formation_ui.has_method("_on_pool_merc_pressed"):
		formation_ui._on_pool_merc_pressed(merc_id, bench_only)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if pool_disabled or merc_id == "":
		return null
	var m := GameManager.find_mercenary_by_id(merc_id)
	var preview := Label.new()
	preview.text = m.merc_name if m else merc_id
	preview.modulate = Color(0.85, 0.95, 1.0)
	set_drag_preview(preview)
	return {"merc_id": merc_id, "from_pool": true, "bench_only": bench_only}
