extends VBoxContainer
## 基地双半组编队：A/B 各 4 出战 + 2 替补；养伤锁详情

const SLOT_ACTIVE := "active"
const SLOT_BENCH := "bench"

var _recovery_panel: PanelContainer = null
var _recovery_body: Label = null
var _halves_row: HBoxContainer = null
var _pool_label: Label = null
var _selected: Dictionary = {}  # {half, kind, index} or empty
var _status_label: Label = null


func _ready() -> void:
	GameManager.formation_changed.connect(_refresh)
	GameManager.roster_healed.connect(_refresh)
	GameManager.state_changed.connect(_on_state_changed)
	_build_ui()
	_refresh()


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.BASE)
	if visible:
		_refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "—— 双半组编队（仅大营调整）——"
	add_child(title)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	add_child(_status_label)
	_recovery_panel = PanelContainer.new()
	var rv := VBoxContainer.new()
	_recovery_panel.add_child(rv)
	var rt := Label.new()
	rt.text = "全队养伤锁"
	rt.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	rv.add_child(rt)
	_recovery_body = Label.new()
	_recovery_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_body.add_theme_font_size_override("font_size", 11)
	rv.add_child(_recovery_body)
	add_child(_recovery_panel)
	_halves_row = HBoxContainer.new()
	_halves_row.add_theme_constant_override("separation", 12)
	add_child(_halves_row)
	_pool_label = Label.new()
	_pool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pool_label.add_theme_font_size_override("font_size", 11)
	_pool_label.modulate = Color(0.75, 0.85, 0.95)
	add_child(_pool_label)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	var fill_btn := Button.new()
	fill_btn.text = "补满优先半组"
	fill_btn.tooltip_text = "从名册与替补席补满当前优先半组的出战/替补空位"
	fill_btn.pressed.connect(_on_auto_fill_preferred)
	tools.add_child(fill_btn)
	add_child(tools)
	var hint := Label.new()
	hint.text = "拖拽换位；右键移出至未编入（出征前主角须在任一半组出战位）。"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color.DIM_GRAY
	add_child(hint)


func _refresh() -> void:
	if not visible and GameManager.state != GameManager.GameState.BASE:
		return
	SquadFormationService.ensure_formation(GameManager)
	_refresh_recovery()
	_refresh_halves()
	_refresh_pool()
	if _status_label:
		var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
		_status_label.text = SquadFormationService.get_formation_summary(GameManager)
		var next_h: String = SquadFormationService.pick_deploy_half(GameManager)
		if next_h != "":
			_status_label.text += " | 下趟优先:%s" % next_h
		_status_label.text += "（点半组标题改优先）"
		if GameManager.is_recovery_lock_active():
			_status_label.modulate = Color.ORANGE_RED
		else:
			_status_label.modulate = Color(0.85, 0.95, 1.0)


func _refresh_recovery() -> void:
	if _recovery_panel == null:
		return
	var st: Dictionary = SquadFormationService.get_recovery_status(GameManager)
	_recovery_panel.visible = st.get("locked", false)
	if not _recovery_panel.visible:
		return
	var lines: PackedStringArray = []
	lines.append("两半组均无法出征。医疗室优先治疗最快能满编的一组。")
	var eta: float = float(st.get("eta_seconds", 0.0))
	if eta > 0.5:
		if eta >= 120.0:
			lines.append("预计约 %.0f 分钟后可恢复出征" % (eta / 60.0))
		else:
			lines.append("预计约 %.0f 秒后可恢复出征" % eta)
	var nh: String = str(st.get("next_deploy_half", ""))
	if nh != "":
		lines.append("解锁后优先半组: %s" % nh)
	for half in ["A", "B"]:
		var hd: Dictionary = st.halves.get(half, {})
		var tag := "可出战" if hd.get("can_deploy", false) else "休整"
		lines.append("\n【半组 %s · %s】" % [half, tag])
		for m in hd.get("members", []):
			var md: Dictionary = m
			var pct: int = int(md.get("hp_pct", 0.0) * 100.0)
			lines.append(
				"  · %s%s — %d%%HP — %s" % [
					"★" if md.get("is_player", false) else "",
					md.get("name", "?"),
					pct,
					md.get("reason", ""),
				]
			)
	_recovery_body.text = "\n".join(lines)


func _refresh_halves() -> void:
	if _halves_row == null:
		return
	for c in _halves_row.get_children():
		c.queue_free()
	_halves_row.add_child(_build_half_column(SquadFormationService.HALF_A))
	_halves_row.add_child(_build_half_column(SquadFormationService.HALF_B))


func _build_half_column(half: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var can_dep: bool = SquadFormationService.half_can_deploy(GameManager, half)
	var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
	var head := Button.new()
	head.flat = true
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.text = "半组 %s [%s]%s" % [
		half,
		"可出战" if can_dep else "休整",
		" ←优先" if half == pref else "",
	]
	head.pressed.connect(_on_preferred_half.bind(half))
	col.add_child(head)
	col.add_child(_make_slot_label("出战位 (4)"))
	var active: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half)
	active = _pad(active, SquadFormationService.MAX_ACTIVE)
	for i in range(SquadFormationService.MAX_ACTIVE):
		col.add_child(_make_slot_button(half, SLOT_ACTIVE, i, active[i]))
	col.add_child(_make_slot_label("替补席 (2)"))
	var bench: Array[String] = SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	bench = _pad(bench, SquadFormationService.MAX_BENCH)
	for i in range(SquadFormationService.MAX_BENCH):
		col.add_child(_make_slot_button(half, SLOT_BENCH, i, bench[i]))
	return col


func _make_slot_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.modulate = Color.DIM_GRAY
	return l


func _make_slot_button(half: String, kind: String, index: int, merc_id: String) -> Button:
	var btn := FormationSlotButton.new()
	btn.custom_minimum_size = Vector2(0, 26)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.slot_half = half
	btn.slot_kind = kind
	btn.slot_index = index
	btn.formation_ui = self
	btn.text = _slot_text(merc_id, kind, index)
	btn.modulate = _slot_color(merc_id)
	var key := _slot_key(half, kind, index)
	if _selected.get("key", "") == key:
		btn.modulate = Color(0.6, 1.0, 0.75)
	btn.pressed.connect(_on_slot_pressed.bind(half, kind, index))
	return btn


func _on_auto_fill_preferred() -> void:
	var half: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	SquadFormationService.auto_fill_half(GameManager, half)
	GameManager.formation_changed.emit()
	_refresh()


func _handle_slot_drop(target_half: String, target_kind: String, target_index: int, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var merc_id: String = str(data.get("merc_id", ""))
	if merc_id == "":
		return
	if bool(data.get("from_pool", false)):
		var code_p: int = GameManager.formation_assign(merc_id, target_half, target_kind, target_index)
		_selected = {}
		_refresh()
		if code_p != 0 and _status_label:
			_status_label.text = GameManager.formation_error_message(code_p)
			_status_label.modulate = Color.ORANGE_RED
		return
	var src_half: String = str(data.get("half", ""))
	var src_kind: String = str(data.get("kind", ""))
	var src_index: int = int(data.get("index", -1))
	if src_half == target_half and src_kind == target_kind and src_index == target_index:
		return
	_selected = {}
	var target_merc: String = _get_slot_merc_id(target_half, target_kind, target_index)
	if src_half == target_half:
		var code: int = GameManager.formation_swap_slots(
			target_half, src_kind, src_index, target_kind, target_index
		)
		if code != 0 and _status_label:
			_status_label.text = GameManager.formation_error_message(code)
			_status_label.modulate = Color.ORANGE_RED
	else:
		var code: int = GameManager.formation_assign(merc_id, target_half, target_kind, target_index)
		if code != 0:
			if _status_label:
				_status_label.text = GameManager.formation_error_message(code)
				_status_label.modulate = Color.ORANGE_RED
			return
		if target_merc != "":
			var back: int = GameManager.formation_assign(target_merc, src_half, src_kind, src_index)
			if back != 0 and _status_label:
				_status_label.text = GameManager.formation_error_message(back)
				_status_label.modulate = Color.ORANGE_RED
	_refresh()


func _clear_slot(half: String, kind: String, index: int) -> void:
	_selected = {}
	var code: int = GameManager.formation_clear_slot(half, kind, index)
	_refresh()
	if code != 0 and _status_label:
		_status_label.text = GameManager.formation_error_message(code)
		_status_label.modulate = Color.ORANGE_RED


func _slot_text(merc_id: String, kind: String, index: int) -> String:
	if merc_id == "":
		return "%s%d · (空)" % ["战" if kind == SLOT_ACTIVE else "替", index + 1]
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m == null:
		return "%s%d · ?" % ["战" if kind == SLOT_ACTIVE else "替", index + 1]
	var tag := "★" if GameManager.player and GameManager.player.merc_id == merc_id else ""
	var max_hp: int = maxi(1, StatResolver.get_max_hp(m))
	var pct: int = int(float(m.current_hp) / float(max_hp) * 100.0)
	var st := "✓" if m.can_join_squad() else "×"
	return "%s%d · %s%s %d%% %s" % [
		"战" if kind == SLOT_ACTIVE else "替",
		index + 1,
		tag,
		m.merc_name,
		pct,
		st,
	]


func _slot_color(merc_id: String) -> Color:
	if merc_id == "":
		return Color(0.55, 0.55, 0.6)
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m == null:
		return Color.GRAY
	if m.can_join_squad():
		return Color.WHITE
	if m.is_near_death:
		return Color(1.0, 0.5, 0.5)
	return Color.GOLD


func _on_preferred_half(half: String) -> void:
	GameManager.formation_set_preferred_half(half)


func _on_slot_pressed(half: String, kind: String, index: int) -> void:
	var key := _slot_key(half, kind, index)
	if _selected.is_empty():
		_selected = {"half": half, "kind": kind, "index": index, "key": key}
		_refresh()
		return
	if _selected.get("key", "") == key:
		_selected = {}
		_refresh()
		return
	var sh: String = str(_selected.half)
	var sk: String = str(_selected.kind)
	var si: int = int(_selected.index)
	var code: int = 0
	if sh == half:
		code = GameManager.formation_swap_slots(half, sk, si, kind, index)
	else:
		var mid: String = _get_slot_merc_id(sh, sk, si)
		if mid != "":
			code = GameManager.formation_assign(mid, half, kind, index)
	_selected = {}
	_refresh()
	if code != 0 and _status_label:
		_status_label.text = GameManager.formation_error_message(code)
		_status_label.modulate = Color.ORANGE_RED


func _get_slot_merc_id(half: String, kind: String, index: int) -> String:
	var ids: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half) if kind == SLOT_ACTIVE else SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	ids = _pad(ids, SquadFormationService.MAX_ACTIVE if kind == SLOT_ACTIVE else SquadFormationService.MAX_BENCH)
	if index >= 0 and index < ids.size():
		return ids[index]
	return ""


func _on_pool_merc_pressed(merc_id: String) -> void:
	var half: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	for h in [half, SquadFormationService.HALF_B if half == SquadFormationService.HALF_A else SquadFormationService.HALF_A]:
		var active: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, h)
		if active.size() < SquadFormationService.MAX_ACTIVE:
			var code: int = GameManager.formation_assign(merc_id, h, SLOT_ACTIVE, active.size())
			if code == 0:
				return
		var bench: Array[String] = SquadFormationService.get_bench_ids(GameManager.squad_formation, h)
		if bench.size() < SquadFormationService.MAX_BENCH:
			var code_b: int = GameManager.formation_assign(merc_id, h, SLOT_BENCH, bench.size())
			if code_b == 0:
				return
	if _status_label:
		_status_label.text = "两半组槽位已满或该佣兵已在编"
		_status_label.modulate = Color.ORANGE


func _clear_pool_row() -> void:
	if _pool_label == null:
		return
	var parent: Node = _pool_label.get_parent()
	if parent == null:
		return
	var old_row: Node = parent.get_node_or_null("FormationPoolRow")
	if old_row:
		old_row.queue_free()


func _refresh_pool() -> void:
	if _pool_label == null:
		return
	_clear_pool_row()
	var in_form: Array[String] = []
	in_form.append_array(SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_A))
	in_form.append_array(SquadFormationService.get_bench_ids(GameManager.squad_formation, SquadFormationService.HALF_A))
	in_form.append_array(SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_B))
	in_form.append_array(SquadFormationService.get_bench_ids(GameManager.squad_formation, SquadFormationService.HALF_B))
	var unassigned: Array[String] = []
	if GameManager.player and GameManager.player.merc_id not in in_form:
		unassigned.append(GameManager.player.merc_id)
	for e in GameManager.elite_roster:
		if e.is_alive and e.merc_id not in in_form:
			unassigned.append(e.merc_id)
	for n in GameManager.normal_roster:
		if n.is_alive and n.merc_id not in in_form:
			unassigned.append(n.merc_id)
	if unassigned.is_empty():
		_pool_label.text = "未编入：无（全员已在 A/B 槽位）"
		return
	_pool_label.text = "未编入（点名字填入优先半组空位）："
	var parent: Node = _pool_label.get_parent()
	if parent == null:
		return
	var row := HFlowContainer.new()
	row.name = "FormationPoolRow"
	for mid in unassigned:
		var b := FormationPoolButton.new()
		var m := GameManager.find_mercenary_by_id(mid)
		b.merc_id = mid
		b.formation_ui = self
		b.text = m.merc_name if m else mid
		b.pressed.connect(_on_pool_merc_pressed.bind(mid))
		row.add_child(b)
	parent.add_child(row)
	parent.move_child(row, _pool_label.get_index() + 1)


func _slot_key(half: String, kind: String, index: int) -> String:
	return "%s_%s_%d" % [half, kind, index]


func _pad(ids: Array[String], n: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(n):
		out.append(ids[i] if i < ids.size() else "")
	return out
