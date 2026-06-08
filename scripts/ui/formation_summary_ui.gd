class_name FormationSummaryUI
extends PanelContainer
## T-UI-FORM-LAYOUT-1 · 中窗编组简表（半组/备战行；数据只读 SquadFormationService）

const SLOT_ACTIVE := "active"
const SLOT_BENCH := "bench"

signal slot_row_pressed(half: String, kind: String, index: int)
signal pool_merc_pressed(merc_id: String, bench_only: bool)

var formation_ui: Control = null

var _shell_built: bool = false
var _header_pref: Label = null
var _header_deploy: Label = null
var _half_a_body: VBoxContainer = null
var _half_b_body: VBoxContainer = null
var _pool_body: VBoxContainer = null
var _pool_title: Label = null
var _row_nodes: Dictionary = {}
var _selected_key: String = ""


func _ready() -> void:
	_ensure_shell_built()


func refresh(selected_key: String, visual_fn: Callable) -> void:
	_ensure_shell_built()
	_selected_key = selected_key
	_refresh_headers()
	_refresh_half_block(
		_half_a_body,
		SquadFormationService.HALF_A,
		selected_key,
		visual_fn
	)
	_refresh_half_block(
		_half_b_body,
		SquadFormationService.HALF_B,
		selected_key,
		visual_fn
	)
	_refresh_pool(visual_fn)


func pulse_focus(seconds: float = 1.5) -> void:
	var orig: Color = modulate
	modulate = Color(0.82, 1.05, 1.12)
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds * 0.85))
	tween.tween_property(self, "modulate", orig, maxf(0.1, seconds * 0.15))


func _ensure_shell_built() -> void:
	if _shell_built:
		return
	_shell_built = true
	name = "FormationSummary"
	custom_minimum_size = Vector2(0, 120)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_panel_style()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	var caption := Label.new()
	caption.text = "编组简表"
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
	col.add_child(caption)
	_header_pref = Label.new()
	_header_pref.name = "SummaryPrefLine"
	_header_pref.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_pref.add_theme_font_size_override("font_size", 10)
	col.add_child(_header_pref)
	_header_deploy = Label.new()
	_header_deploy.name = "SummaryDeployLine"
	_header_deploy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_deploy.add_theme_font_size_override("font_size", 10)
	col.add_child(_header_deploy)
	col.add_child(_make_half_shell("半组 A", SquadFormationService.HALF_A))
	col.add_child(_make_half_shell("半组 B", SquadFormationService.HALF_B))
	var pool_head := Label.new()
	pool_head.text = "备战席"
	pool_head.add_theme_font_size_override("font_size", 10)
	pool_head.modulate = Color(0.72, 0.88, 1.0)
	col.add_child(pool_head)
	_pool_title = Label.new()
	_pool_title.add_theme_font_size_override("font_size", 9)
	_pool_title.modulate = Color(0.58, 0.68, 0.78)
	col.add_child(_pool_title)
	_pool_body = VBoxContainer.new()
	_pool_body.name = "SummaryPoolBody"
	_pool_body.add_theme_constant_override("separation", 2)
	col.add_child(_pool_body)


func _make_half_shell(title: String, half: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "SummaryHalf%s" % half
	block.add_theme_constant_override("separation", 2)
	var head := Label.new()
	head.name = "SummaryHalfHead%s" % half
	head.add_theme_font_size_override("font_size", 10)
	head.modulate = Color(0.82, 0.74, 0.58)
	block.add_child(head)
	var body := VBoxContainer.new()
	body.name = "SummaryHalfBody%s" % half
	body.add_theme_constant_override("separation", 1)
	block.add_child(body)
	if half == SquadFormationService.HALF_A:
		_half_a_body = body
	else:
		_half_b_body = body
	return block


func _refresh_headers() -> void:
	var pref: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	var a_tag := "可出战" if SquadFormationService.half_can_deploy(GameManager, SquadFormationService.HALF_A) else "休整"
	var b_tag := "可出战" if SquadFormationService.half_can_deploy(GameManager, SquadFormationService.HALF_B) else "休整"
	if _header_pref:
		_header_pref.text = "编组优先：半组 %s  ·  A:%s  ·  B:%s" % [pref, a_tag, b_tag]
		_header_pref.modulate = Color(0.75, 0.9, 1.0)
	var deploy_h: String = SquadFormationService.resolve_deploy_half(GameManager)
	if _header_deploy:
		if deploy_h == "":
			_header_deploy.text = "下趟出征：—（两半组均无法出战）"
			_header_deploy.modulate = Color(1.0, 0.55, 0.45)
		elif deploy_h != pref:
			_header_deploy.text = "下趟出征：半组 %s（优先 %s 休整·改派） · %s" % [
				deploy_h,
				pref,
				SquadFormationService.format_half_stability_text(GameManager, deploy_h),
			]
			_header_deploy.modulate = Color(1.0, 0.82, 0.55)
		else:
			_header_deploy.text = "下趟出征：半组 %s · %s" % [
				deploy_h,
				SquadFormationService.format_half_stability_text(GameManager, deploy_h),
			]
			_header_deploy.modulate = Color(0.72, 0.88, 0.95)
	for half in [SquadFormationService.HALF_A, SquadFormationService.HALF_B]:
		var head: Label = get_node_or_null(
			"MarginContainer/VBoxContainer/SummaryHalf%s/SummaryHalfHead%s" % [half, half]
		) as Label
		if head == null:
			continue
		var can_dep: bool = SquadFormationService.half_can_deploy(GameManager, half)
		var pref_mark := " ★优先" if pref == half else ""
		head.text = "半组 %s · %s%s · %s" % [
			half,
			"可出战" if can_dep else "休整",
			pref_mark,
			SquadFormationService.format_half_stability_text(GameManager, half),
		]


func _refresh_half_block(
	body: VBoxContainer,
	half: String,
	selected_key: String,
	visual_fn: Callable
) -> void:
	if body == null:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var active: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half)
	active = _pad(active, SquadFormationService.MAX_ACTIVE)
	for i in range(SquadFormationService.MAX_ACTIVE):
		_add_slot_row(body, half, SLOT_ACTIVE, i, active[i], selected_key, visual_fn, "战%d" % (i + 1))
	var bench: Array[String] = SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	bench = _pad(bench, SquadFormationService.MAX_BENCH)
	for i in range(SquadFormationService.MAX_BENCH):
		_add_slot_row(body, half, SLOT_BENCH, i, bench[i], selected_key, visual_fn, "替%d" % (i + 1))


func _add_slot_row(
	parent: VBoxContainer,
	half: String,
	kind: String,
	index: int,
	merc_id: String,
	selected_key: String,
	visual_fn: Callable,
	slot_tag: String
) -> void:
	var vis: Dictionary = visual_fn.call(merc_id, kind)
	var key := "%s:%s:%d" % [kind, half, index]
	var row := PanelContainer.new()
	row.name = "SummarySlot_%s" % key
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16, 0.92)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 6
	sb.content_margin_top = 2
	sb.content_margin_right = 6
	sb.content_margin_bottom = 2
	if key == selected_key:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.45, 0.85, 0.65)
	row.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	var badge: String = str(vis.get("badge", ""))
	var name_text: String = str(vis.get("name_text", "(空)"))
	if merc_id == "":
		lbl.text = "%s  ·  %s" % [slot_tag, name_text]
		lbl.modulate = Color(0.5, 0.52, 0.58)
	else:
		lbl.text = "%s  ·  %s  ·  %s" % [slot_tag, name_text, badge]
		lbl.modulate = Color(0.88, 0.92, 0.98) if bool(vis.get("ready", false)) else Color(0.75, 0.68, 0.62)
	lbl.add_theme_font_size_override("font_size", 9)
	row.add_child(lbl)
	row.gui_input.connect(_on_slot_row_input.bind(half, kind, index))
	parent.add_child(row)
	_row_nodes[key] = row


func _refresh_pool(visual_fn: Callable) -> void:
	if _pool_body == null:
		return
	for child in _pool_body.get_children():
		child.queue_free()
	var in_form: Array[String] = []
	in_form.append_array(SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_A))
	in_form.append_array(SquadFormationService.get_bench_ids(GameManager.squad_formation, SquadFormationService.HALF_A))
	in_form.append_array(SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_B))
	in_form.append_array(SquadFormationService.get_bench_ids(GameManager.squad_formation, SquadFormationService.HALF_B))
	var deploy_ids: Array[String] = []
	var rest_ids: Array[String] = []
	var mia_ids: Array[String] = []
	for e in GameManager.elite_roster:
		if e.merc_id in in_form:
			continue
		_bucket_pool_merc(e, deploy_ids, rest_ids, mia_ids)
	for n in GameManager.normal_roster:
		if n.merc_id in in_form:
			continue
		_bucket_pool_merc(n, deploy_ids, rest_ids, mia_ids)
	var total_n: int = deploy_ids.size() + rest_ids.size() + mia_ids.size()
	if _pool_title:
		if total_n == 0:
			if not SquadFormationService.has_living_merc_roster(GameManager):
				_pool_title.text = "未编入 · 无佣兵"
			else:
				_pool_title.text = "未编入 · 全员已在 A/B 槽"
		else:
			_pool_title.text = "未编入 · %d 人" % total_n
	if total_n == 0:
		var empty := Label.new()
		empty.text = "（空）"
		empty.modulate = Color(0.5, 0.58, 0.68)
		empty.add_theme_font_size_override("font_size", 9)
		_pool_body.add_child(empty)
		return
	if not deploy_ids.is_empty():
		_add_pool_group(_pool_body, "可出战", deploy_ids, visual_fn, false)
	if not rest_ids.is_empty():
		_add_pool_group(_pool_body, "养伤", rest_ids, visual_fn, true)
	if not mia_ids.is_empty():
		_add_pool_group(_pool_body, "遗留", mia_ids, visual_fn, false)


func _bucket_pool_merc(m: Mercenary, deploy_ids: Array[String], rest_ids: Array[String], mia_ids: Array[String]) -> void:
	if m.is_test_stand_in or m.is_alive:
		if m.is_test_stand_in or _pool_merc_ready(m):
			deploy_ids.append(m.merc_id)
		elif m.is_mia:
			mia_ids.append(m.merc_id)
		else:
			rest_ids.append(m.merc_id)


func _pool_merc_ready(m: Mercenary) -> bool:
	if formation_ui and formation_ui.has_method("_slot_merc_ready"):
		return formation_ui._slot_merc_ready(m)
	return m.can_join_squad()


func _add_pool_group(
	parent: VBoxContainer,
	group_title: String,
	ids: Array[String],
	visual_fn: Callable,
	bench_only: bool
) -> void:
	var tag := Label.new()
	tag.text = "— %s —" % group_title
	tag.add_theme_font_size_override("font_size", 9)
	tag.modulate = Color(0.55, 0.65, 0.75)
	parent.add_child(tag)
	for mid in ids:
		if mid == "":
			continue
		var vis: Dictionary = visual_fn.call(mid, SLOT_ACTIVE)
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.custom_minimum_size = Vector2(0, 22)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.14, 0.2, 0.95)
		sb.corner_radius_top_left = 3
		sb.corner_radius_top_right = 3
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		sb.content_margin_left = 6
		sb.content_margin_top = 2
		sb.content_margin_right = 6
		sb.content_margin_bottom = 2
		row.add_theme_stylebox_override("panel", sb)
		var lbl := Label.new()
		lbl.text = "%s  ·  %s" % [str(vis.get("name_text", mid)), str(vis.get("badge", ""))]
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.modulate = Color(0.82, 0.9, 1.0) if bool(vis.get("ready", false)) else Color(0.7, 0.65, 0.6)
		row.add_child(lbl)
		row.gui_input.connect(_on_pool_row_input.bind(mid, bench_only))
		parent.add_child(row)


func _on_slot_row_input(event: InputEvent, half: String, kind: String, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			slot_row_pressed.emit(half, kind, index)
			if formation_ui and formation_ui.has_method("_on_slot_pressed"):
				formation_ui._on_slot_pressed(half, kind, index)


func _on_pool_row_input(event: InputEvent, merc_id: String, bench_only: bool) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pool_merc_pressed.emit(merc_id, bench_only)
			if formation_ui and formation_ui.has_method("_on_pool_merc_pressed"):
				formation_ui._on_pool_merc_pressed(merc_id, bench_only)


func _pad(ids: Array[String], n: int) -> Array[String]:
	var out: Array[String] = ids.duplicate()
	while out.size() < n:
		out.append("")
	if out.size() > n:
		out.resize(n)
	return out


func _apply_panel_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.15, 0.92)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.28, 0.42, 0.55, 0.8)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", sb)
