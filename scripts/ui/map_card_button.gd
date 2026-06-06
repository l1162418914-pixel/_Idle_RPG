class_name MapCardButton
extends PanelContainer
## 大营左窗地图卡片（T-UI-B1 / B1.5 鼠标优先）

signal card_selected(map_id: String)
signal deploy_pressed(map_id: String)

const DEPLOY_BTN_H := 36
const DEPLOY_BTN_GAP := 8

var map_id: String = ""

var _accent: ColorRect = null
var _select_btn: Button = null
var _deploy_btn: Button = null
var _selected: bool = false
var _unlocked: bool = false
var _recovery_locked_prod: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 68)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_top", 2)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_bottom", 2)


func setup(
	map_data: Dictionary,
	selected: bool,
	recovery_locked_prod: bool,
	unlocked: bool
) -> void:
	map_id = str(map_data.get("map_id", ""))
	_selected = selected
	_unlocked = unlocked
	_recovery_locked_prod = recovery_locked_prod
	for c in get_children():
		c.queue_free()
	_accent = null
	_select_btn = null
	_deploy_btn = null

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 4)
	add_child(outer)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(row)

	_accent = ColorRect.new()
	_accent.custom_minimum_size = Vector2(4, 0)
	_accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_accent)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 2)
	row.add_child(body)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(title_row)

	var name: String = str(map_data.get("name", map_id))
	if TestScenarioService.is_test_map(map_data):
		name = "【测试】%s" % name
	var title := Label.new()
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title_row.add_child(title)

	if recovery_locked_prod:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.tooltip_text = SquadFormationService.get_recovery_lock_message(GameManager)
		title_row.add_child(lock_lbl)

	var meta := Label.new()
	meta.add_theme_font_size_override("font_size", 10)
	meta.modulate = Color(0.65, 0.72, 0.82)
	if unlocked:
		meta.text = "Boss %.0fm · 危险%d" % [
			float(map_data.get("boss_distance", 600)),
			int(map_data.get("danger_level", 1)),
		]
	else:
		meta.text = "需基地 Lv.%d" % int(map_data.get("unlock_base_level", 1))
	body.add_child(meta)

	var purpose := Label.new()
	purpose.add_theme_font_size_override("font_size", 10)
	purpose.modulate = Color(0.55, 0.62, 0.72)
	purpose.autowrap_mode = TextServer.AUTOWRAP_OFF
	purpose.clip_text = true
	purpose.text = _purpose_line(map_data)
	body.add_child(purpose)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 10)
	if not unlocked:
		status.text = "未解锁"
		status.modulate = Color(0.5, 0.5, 0.55)
	elif selected:
		status.text = "已选中 · 点「出征」进入准备"
		status.modulate = Color(0.55, 0.9, 1.0)
	elif recovery_locked_prod:
		status.text = "养伤锁 · 选中后可尝试出征"
		status.modulate = Color(0.75, 0.55, 0.5)
	else:
		status.text = "点击选中"
		status.modulate = Color(0.5, 0.85, 0.65)
	body.add_child(status)

	_select_btn = Button.new()
	_select_btn.name = "SelectHit"
	_select_btn.flat = true
	_select_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_select_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select_btn.offset_left = 0
	_select_btn.offset_top = 0
	_select_btn.offset_right = 0
	_select_btn.offset_bottom = 0
	if unlocked:
		_select_btn.pressed.connect(func() -> void: card_selected.emit(map_id))
	else:
		_select_btn.disabled = true
		_select_btn.tooltip_text = GameManager.get_map_lock_reason(map_id)
	var desc: String = str(map_data.get("description", ""))
	if TestScenarioService.is_test_map(map_data) and GameManager.is_recovery_lock_active():
		var reinject := "测试图将重新注入本图编队（阵亡/濒死后可重开）"
		_select_btn.tooltip_text = reinject if desc == "" else "%s\n\n%s" % [reinject, desc]
	elif desc != "":
		_select_btn.tooltip_text = desc if _select_btn.tooltip_text == "" else "%s\n\n%s" % [_select_btn.tooltip_text, desc]
	add_child(_select_btn)
	_apply_select_hit_inset(selected and unlocked)

	if selected and unlocked:
		_deploy_btn = Button.new()
		_deploy_btn.text = "出征"
		_deploy_btn.custom_minimum_size = Vector2(88, DEPLOY_BTN_H)
		_deploy_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_deploy_btn.z_index = 2
		_deploy_btn.pressed.connect(func() -> void: deploy_pressed.emit(map_id))
		_deploy_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_deploy_btn.offset_left = 10
		_deploy_btn.offset_top = -(DEPLOY_BTN_H + DEPLOY_BTN_GAP)
		_deploy_btn.offset_bottom = -DEPLOY_BTN_GAP
		_deploy_btn.grow_horizontal = Control.GROW_DIRECTION_END
		_deploy_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
		add_child(_deploy_btn)

	if selected and unlocked:
		custom_minimum_size = Vector2(0, 68 + DEPLOY_BTN_H + DEPLOY_BTN_GAP)
	else:
		custom_minimum_size = Vector2(0, 68)

	_apply_visual(unlocked, recovery_locked_prod)


func _apply_select_hit_inset(leave_deploy_strip: bool) -> void:
	if _select_btn == null:
		return
	if leave_deploy_strip:
		_select_btn.offset_bottom = -(DEPLOY_BTN_H + DEPLOY_BTN_GAP * 2)
	else:
		_select_btn.offset_bottom = 0


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_visual(_unlocked, _recovery_locked_prod)


func _apply_visual(unlocked: bool, recovery_locked_prod: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 6
	bg.content_margin_top = 4
	bg.content_margin_right = 6
	bg.content_margin_bottom = 4
	if not unlocked:
		bg.bg_color = Color(0.12, 0.13, 0.16, 0.9)
	elif recovery_locked_prod:
		bg.bg_color = Color(0.14, 0.14, 0.17, 0.95)
	elif _selected:
		bg.bg_color = Color(0.18, 0.28, 0.38, 0.95)
	else:
		bg.bg_color = Color(0.14, 0.17, 0.22, 0.9)
	add_theme_stylebox_override("panel", bg)
	if _accent:
		if _selected and unlocked:
			_accent.color = Color(0.35, 0.75, 1.0, 1.0)
		elif recovery_locked_prod and unlocked:
			_accent.color = Color(0.55, 0.45, 0.4, 0.8)
		else:
			_accent.color = Color(0.25, 0.3, 0.38, 0.5)
	if _select_btn:
		if recovery_locked_prod and unlocked:
			_select_btn.modulate = Color(0.72, 0.72, 0.78)
		elif not unlocked:
			_select_btn.modulate = Color(0.65, 0.65, 0.7)
		else:
			_select_btn.modulate = Color.WHITE


func pulse_outline(duration: float = 2.0) -> void:
	var hl := StyleBoxFlat.new()
	hl.corner_radius_top_left = 4
	hl.corner_radius_top_right = 4
	hl.corner_radius_bottom_left = 4
	hl.corner_radius_bottom_right = 4
	hl.border_width_left = 3
	hl.border_width_top = 3
	hl.border_width_right = 3
	hl.border_width_bottom = 3
	hl.border_color = Color(0.35, 0.85, 1.0, 1.0)
	hl.bg_color = Color(0.18, 0.28, 0.38, 0.95)
	hl.content_margin_left = 6
	hl.content_margin_top = 4
	hl.content_margin_right = 6
	hl.content_margin_bottom = 4
	add_theme_stylebox_override("panel", hl)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void:
		_apply_visual(_unlocked, _recovery_locked_prod)
	)


static func _purpose_line(map_data: Dictionary) -> String:
	var raw: String = str(map_data.get("description", "")).strip_edges()
	if raw == "":
		return "—"
	raw = raw.replace("\n", " ")
	if raw.length() > 42:
		return raw.substr(0, 42) + "…"
	return raw
