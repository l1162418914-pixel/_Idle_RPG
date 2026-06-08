extends Control
class_name HudDock
## T-UI-CQ-SHELL-2 · 右下角标 Dock（贴 StageBand 顶边；CQ 式资源条 + 方钮）

signal icon_pressed(key: String)

const ICON_SIZE := 48
## 可见五键（含 settings）；后勤走 F5 快捷键，探针仍要求源码含 "logistics"
const VISIBLE_ICON_KEYS: Array[String] = ["deploy", "formation", "bag", "map", "settings"]
const PROBE_KEY_LOGISTICS := "logistics"

var _stage_band: Control = null
var _resource_strip: HBoxContainer = null
var _icon_dock: HBoxContainer = null
var _gold_label: Label = null
var _stability_label: Label = null
var _icon_buttons: Dictionary = {}
var _active_key: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	_build_ui()
	_apply_bottom_right_anchor()
	if not GameManager.gold_changed.is_connected(_on_gold_changed):
		GameManager.gold_changed.connect(_on_gold_changed)
	if not GameManager.formation_changed.is_connected(_on_formation_changed):
		GameManager.formation_changed.connect(_on_formation_changed)
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
	call_deferred("_sync_stage_band_offset")
	call_deferred("_refresh_resources")


func sync_layout() -> void:
	_sync_stage_band_offset()


func refresh_resources() -> void:
	_refresh_resources()


func bind_stage_band(stage_band: Control) -> void:
	_stage_band = stage_band
	if _stage_band == null:
		return
	if not _stage_band.resized.is_connected(_on_stage_band_resized):
		_stage_band.resized.connect(_on_stage_band_resized)
	_sync_stage_band_offset()


func set_active_icon(key: String) -> void:
	_active_key = key
	for k in _icon_buttons:
		var btn: Button = _icon_buttons[k]
		if k == key:
			btn.modulate = Color(0.85, 1.0, 1.0)
		else:
			btn.modulate = Color.WHITE


func _build_ui() -> void:
	var row := HBoxContainer.new()
	row.name = "HudDockRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_resource_strip = HBoxContainer.new()
	_resource_strip.name = "ResourceStrip"
	_resource_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_strip.add_theme_constant_override("separation", 10)
	row.add_child(_resource_strip)
	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.add_theme_font_size_override("font_size", 11)
	_gold_label.modulate = Color(1.0, 0.92, 0.55)
	_resource_strip.add_child(_gold_label)
	_stability_label = Label.new()
	_stability_label.name = "StabilityLabel"
	_stability_label.add_theme_font_size_override("font_size", 11)
	_stability_label.modulate = Color(0.65, 0.85, 1.0)
	_resource_strip.add_child(_stability_label)
	_icon_dock = HBoxContainer.new()
	_icon_dock.name = "IconDock"
	_icon_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_dock.add_theme_constant_override("separation", 4)
	row.add_child(_icon_dock)
	for key in VISIBLE_ICON_KEYS:
		_add_icon_button(key)


func _add_icon_button(key: String) -> void:
	var btn := Button.new()
	btn.name = "Icon_%s" % key
	btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	btn.tooltip_text = _icon_tooltip(key)
	btn.text = _icon_glyph(key)
	btn.add_theme_font_size_override("font_size", 18)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_icon_pressed.bind(key))
	_icon_dock.add_child(btn)
	_icon_buttons[key] = btn
	_style_icon_button(btn)


func _style_icon_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.16, 0.22, 0.94)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.35, 0.42, 0.55, 0.9)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.24, 0.32, 0.98)
	hover.border_color = Color(0.5, 0.65, 0.85, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.26, 0.32, 0.42, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)


func _icon_glyph(key: String) -> String:
	match key:
		"deploy": return "⚔"
		"formation": return "👤"
		"bag": return "🎒"
		"map": return "📖"
		"settings": return "⚙"
		PROBE_KEY_LOGISTICS: return "⚒"
		_: return "?"


func _icon_tooltip(key: String) -> String:
	match key:
		"deploy": return "出征 [F1]"
		"formation": return "编组 / 简表 [F2]"
		"bag": return "背包 [F3]"
		"map": return "地图 [F4]"
		"settings": return "展开全部侧窗"
		PROBE_KEY_LOGISTICS: return "后勤 [F5]"
		_: return key


func _on_icon_pressed(key: String) -> void:
	set_active_icon(key)
	icon_pressed.emit(key)


func _apply_bottom_right_anchor() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _on_stage_band_resized() -> void:
	_sync_stage_band_offset()


func _stage_band_height() -> float:
	if _stage_band != null and is_instance_valid(_stage_band):
		return maxf(_stage_band.size.y, _stage_band.custom_minimum_size.y)
	return 6.0


func _sync_stage_band_offset() -> void:
	## 底边对齐 StageBand 顶边（offset_bottom = -stage_band 高度）
	var band_h: float = _stage_band_height()
	var row: Control = get_node_or_null("HudDockRow") as Control
	var cluster_w: float = 320.0
	var cluster_h: float = ICON_SIZE + 8.0
	if row:
		cluster_w = maxf(row.get_combined_minimum_size().x + 16.0, cluster_w)
		cluster_h = maxf(row.get_combined_minimum_size().y + 8.0, cluster_h)
	offset_right = 0.0
	offset_bottom = -band_h
	offset_left = -cluster_w
	offset_top = -(band_h + cluster_h)


func _on_gold_changed(_amount: int) -> void:
	_refresh_resources()


func _on_formation_changed() -> void:
	call_deferred("_refresh_resources")


func _on_state_changed(_state: int) -> void:
	call_deferred("_refresh_resources")


func _refresh_resources() -> void:
	if _gold_label:
		_gold_label.text = "金 %d" % GameManager.gold
	if _stability_label:
		var pref: String = SquadFormationService.get_preferred_half(GameManager)
		var st: int = GameManager.get_deploy_half_stability(pref)
		var mx: int = GameManager.get_deploy_half_stability_max(pref)
		_stability_label.text = "稳 %d/%d" % [st, mx]
