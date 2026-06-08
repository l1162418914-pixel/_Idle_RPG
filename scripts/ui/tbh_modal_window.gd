class_name TbModalWindow
extends PanelContainer
## TBH 式上窗浮层：深色描边框 + 标题栏 + 关闭钮 + 内容槽

signal close_requested

var body: Control = null

var _built: bool = false
var _title_label: Label = null
var _icon_label: Label = null


func configure(title_text: String, icon_glyph: String, min_size: Vector2) -> void:
	_ensure_built()
	custom_minimum_size = min_size
	size = min_size
	if _title_label:
		_title_label.text = title_text
	if _icon_label:
		_icon_label.text = icon_glyph
	add_theme_stylebox_override("panel", make_frame_style())


func get_body_slot() -> Control:
	_ensure_built()
	return body


static func make_frame_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.1, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.55, 0.22, 0.18, 0.95)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 8
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 10
	return sb


static func make_title_banner_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.1, 0.1, 0.92)
	sb.border_width_bottom = 2
	sb.border_color = Color(0.72, 0.48, 0.18, 0.85)
	sb.content_margin_left = 8
	sb.content_margin_top = 4
	sb.content_margin_right = 8
	sb.content_margin_bottom = 4
	return sb


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)
	var head_wrap := PanelContainer.new()
	head_wrap.add_theme_stylebox_override("panel", make_title_banner_style())
	col.add_child(head_wrap)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head_wrap.add_child(head)
	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 16)
	_icon_label.modulate = Color(0.95, 0.78, 0.42)
	head.add_child(_icon_label)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.modulate = Color(0.92, 0.86, 0.72)
	head.add_child(_title_label)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.tooltip_text = "关闭 [Esc]"
	close_btn.custom_minimum_size = Vector2(34, 28)
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(close_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	body = Control.new()
	body.name = "BodySlot"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
