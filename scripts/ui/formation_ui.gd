extends VBoxContainer
## 基地双半组编队：A/B 各 4 出战 + 2 替补；养伤锁详情

const _FormationSlotCardScene = preload("res://scripts/ui/formation_slot_card.gd")

const SLOT_ACTIVE := "active"
const SLOT_BENCH := "bench"
const HALF_STAGE_ACTIVE_BG := Color(0.14, 0.18, 0.24, 0.95)
const HALF_STAGE_REST_BG := Color(0.11, 0.12, 0.15, 0.92)

var _recovery_panel: PanelContainer = null
var _recovery_title: Label = null
var _recovery_body: Label = null
var _player_panel: PanelContainer = null
var _player_body: Label = null
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
	if new_state == GameManager.GameState.BASE:
		_refresh()


func pulse_formation_focus(seconds: float = 2.0) -> void:
	if _halves_row == null:
		return
	var orig: Color = _halves_row.modulate
	_halves_row.modulate = Color(0.7, 1.05, 1.2)
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds * 0.85))
	tween.tween_property(_halves_row, "modulate", orig, maxf(0.1, seconds * 0.15))


func _build_ui() -> void:
	var title := Label.new()
	title.text = "—— 双半组编队（仅大营调整）——"
	add_child(title)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	add_child(_status_label)
	_player_panel = PanelContainer.new()
	var pv := VBoxContainer.new()
	_player_panel.add_child(pv)
	var pt := Label.new()
	pt.text = "战略核心（留营）"
	pt.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	pv.add_child(pt)
	_player_body = Label.new()
	_player_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_player_body.add_theme_font_size_override("font_size", 11)
	pv.add_child(_player_body)
	var player_tools := HBoxContainer.new()
	player_tools.add_theme_constant_override("separation", 8)
	var player_equip_btn := Button.new()
	player_equip_btn.text = "管理装备"
	player_equip_btn.pressed.connect(_on_player_equip_pressed)
	player_tools.add_child(player_equip_btn)
	pv.add_child(player_tools)
	_apply_player_panel_style()
	add_child(_player_panel)
	_recovery_panel = PanelContainer.new()
	var rv := VBoxContainer.new()
	_recovery_panel.add_child(rv)
	_recovery_title = Label.new()
	_recovery_title.text = "全队养伤锁"
	_recovery_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	rv.add_child(_recovery_title)
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
	hint.text = "拖拽换位；右键移出至未编入。A/B 仅编佣兵，主角留营；纯佣兵可出征。"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color.DIM_GRAY
	add_child(hint)


func _refresh() -> void:
	if not visible and GameManager.state != GameManager.GameState.BASE:
		return
	SquadFormationService.ensure_formation(GameManager)
	GameManager.repair_roster_base_stats()
	_refresh_player_card()
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
		var sel_md: Dictionary = DataLoader.map_data(GameManager.selected_map_id)
		if (
			GameManager.state == GameManager.GameState.BASE
			and TestScenarioService.should_lock_roster(sel_md)
		):
			if str(sel_md.get("test_scenario", "")) == "mia_wipe":
				if TestScenarioService.has_test_mia_casualties(GameManager):
					_status_label.text += " | 测试⑨：已有遗留 → F5 后勤·回收（勿再灭团出征）"
				elif TestScenarioService.is_roster_injected(GameManager, GameManager.selected_map_id):
					_status_label.text += " | 测试⑨：半组 A 出征灭团 → 回城 F5 回收"
				else:
					_status_label.text += " | 测试⑨：选图后自动注入编队，点「出征」开战"
			elif not TestScenarioService.is_roster_injected(GameManager, GameManager.selected_map_id):
				var roster: Dictionary = TestRosterLoader.roster_for_map(GameManager.selected_map_id)
				var label: String = str(roster.get("display_name", "测试编队"))
				_status_label.text += " | 已选测试图：点地图「出征」注入 %s" % label
		if GameManager.is_recovery_lock_active():
			_status_label.modulate = Color.ORANGE_RED
		else:
			_status_label.modulate = Color(0.85, 0.95, 1.0)


func _on_player_equip_pressed() -> void:
	var base_ui := _find_base_ui()
	if base_ui and base_ui.has_method("open_equipment_for"):
		base_ui.open_equipment_for(GameManager.player)


func _find_base_ui() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("open_equipment_for"):
			return n
		n = n.get_parent()
	return null


func _refresh_player_card() -> void:
	if _player_panel == null or _player_body == null:
		return
	var p = GameManager.player
	if p == null:
		_player_panel.visible = false
		return
	_player_panel.visible = true
	var max_hp: int = maxi(1, StatResolver.get_max_hp(p))
	var pct: int = int(float(p.current_hp) / float(max_hp) * 100.0)
	var status := "可出战"
	if p.is_near_death:
		status = "濒死·留营恢复"
	elif not p.can_join_squad():
		status = "休整·留营恢复"
	_player_body.text = (
		"★ %s Lv.%d · %d%%HP · %s\n"
		+ "主角留营指挥，不占 A/B 槽；出征请编佣兵。点「管理装备」配置主角。"
	) % [p.merc_name, p.level, pct, status]


func _refresh_recovery() -> void:
	if _recovery_panel == null:
		return
	var st: Dictionary = SquadFormationService.get_recovery_status(GameManager)
	_recovery_panel.visible = st.get("locked", false)
	if not _recovery_panel.visible:
		return
	var no_mercs: bool = st.get("no_mercs", false)
	if _recovery_title:
		_recovery_title.text = "无法出征" if no_mercs else "全队养伤锁"
	var lines: PackedStringArray = []
	if no_mercs:
		lines.append("暂无佣兵可编组。请打开兵营招募至少 1 名佣兵，再编入 A/B 半组出战位。")
	else:
		lines.append("两半组均无法出征（顶栏已显示养伤锁与预计恢复时间）。")
	var eta: float = float(st.get("eta_seconds", 0.0))
	if not no_mercs and eta > 0.5:
		if eta >= 120.0:
			lines.append("预计约 %.0f 分钟后可恢复出征" % (eta / 60.0))
		else:
			lines.append("预计约 %.0f 秒后可恢复出征" % eta)
	var nh: String = str(st.get("next_deploy_half", ""))
	if not no_mercs and nh != "":
		lines.append("解锁后优先半组: %s" % nh)
	if no_mercs:
		_recovery_body.text = "\n".join(lines)
		return
	for half in ["A", "B"]:
		var hd: Dictionary = st.halves.get(half, {})
		var tag := "可出战" if hd.get("can_deploy", false) else "休整"
		lines.append("\n【半组 %s · %s】" % [half, tag])
		for m in hd.get("members", []):
			var md: Dictionary = m
			var cur_hp: int = int(md.get("current_hp", 0))
			var max_hp: int = maxi(1, int(md.get("max_hp", 1)))
			var pct: int = int(float(cur_hp) / float(max_hp) * 100.0)
			lines.append(
				"  · %s%s — HP %d/%d (%d%%) — %s" % [
					"★" if md.get("is_player", false) else "",
					md.get("name", "?"),
					cur_hp,
					max_hp,
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


func _build_half_column(half: String) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_half_stage_style(shell, half)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	shell.add_child(margin)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var can_dep: bool = SquadFormationService.half_can_deploy(GameManager, half)
	var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
	var head := Button.new()
	head.flat = true
	head.custom_minimum_size = Vector2(0, 32)
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.text = "半组 %s · %s%s" % [
		half,
		"可出战" if can_dep else "休整",
		" ★优先" if half == pref else "",
	]
	head.pressed.connect(_on_preferred_half.bind(half))
	col.add_child(head)
	col.add_child(_make_slot_label("出战 (4)"))
	var active: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half)
	active = _pad(active, SquadFormationService.MAX_ACTIVE)
	for i in range(SquadFormationService.MAX_ACTIVE):
		col.add_child(_make_slot_card(half, SLOT_ACTIVE, i, active[i]))
	col.add_child(_make_slot_label("替补 (2)"))
	var bench: Array[String] = SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	bench = _pad(bench, SquadFormationService.MAX_BENCH)
	for i in range(SquadFormationService.MAX_BENCH):
		col.add_child(_make_slot_card(half, SLOT_BENCH, i, bench[i]))
	return shell


func _make_slot_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.modulate = Color.DIM_GRAY
	return l


func _make_slot_card(half: String, kind: String, index: int, merc_id: String) -> Control:
	var card := _FormationSlotCardScene.new()
	card.slot_half = half
	card.slot_kind = kind
	card.slot_index = index
	card.formation_ui = self
	var key := _slot_key(half, kind, index)
	var selected: bool = _selected.get("key", "") == key
	var vis: Dictionary = _slot_card_visual(merc_id, kind)
	card.apply_slot(
		merc_id,
		kind,
		index,
		selected,
		bool(vis.get("ready", false)),
		str(vis.get("name_text", "")),
		float(vis.get("hp_ratio", 0.0)),
		str(vis.get("badge", "")),
		vis.get("accent", Color.WHITE),
		vis.get("bg", Color(0.14, 0.17, 0.22))
	)
	return card


func _slot_card_visual(merc_id: String, kind: String) -> Dictionary:
	if merc_id == "":
		return {
			"ready": false,
			"name_text": "(空槽 · 拖入或点选未编入)",
			"hp_ratio": 0.0,
			"badge": "",
			"accent": Color(0.28, 0.3, 0.36),
			"bg": Color(0.1, 0.11, 0.14, 0.88),
		}
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m == null:
		return {
			"ready": false,
			"name_text": "未知单位",
			"hp_ratio": 0.0,
			"badge": "?",
			"accent": Color(0.4, 0.4, 0.45),
			"bg": Color(0.12, 0.12, 0.14, 0.9),
		}
	var max_hp: int = maxi(1, StatResolver.get_max_hp(m))
	var hp_ratio: float = float(m.current_hp) / float(max_hp)
	var ready: bool = _slot_merc_ready(m)
	var badge := "可出战" if ready else "休整"
	if m.is_mia:
		badge = "遗留"
	elif m.is_near_death:
		badge = "濒死"
	var tag := "★ " if GameManager.player and GameManager.player.merc_id == merc_id else ""
	var accent := Color(0.38, 0.72, 0.95) if kind == SLOT_ACTIVE else Color(0.45, 0.52, 0.62)
	if not ready:
		accent = Color(0.72, 0.48, 0.38) if m.is_near_death else Color(0.55, 0.5, 0.45)
	var bg := Color(0.15, 0.2, 0.28, 0.95) if ready else Color(0.14, 0.14, 0.17, 0.92)
	if m.is_test_stand_in:
		bg = Color(0.16, 0.22, 0.26, 0.95)
	return {
		"ready": ready,
		"name_text": "%s%s Lv.%d" % [tag, m.merc_name, m.level],
		"hp_ratio": hp_ratio,
		"badge": badge,
		"accent": accent,
		"bg": bg,
	}


func _apply_half_stage_style(panel: PanelContainer, half: String) -> void:
	var can_dep: bool = SquadFormationService.half_can_deploy(GameManager, half)
	var pref: bool = str(GameManager.squad_formation.get("active_half", "A")) == half
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.bg_color = HALF_STAGE_ACTIVE_BG if can_dep else HALF_STAGE_REST_BG
	if pref:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.35, 0.75, 1.0, 0.95)
	panel.add_theme_stylebox_override("panel", sb)


func _apply_player_panel_style() -> void:
	if _player_panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.bg_color = Color(0.12, 0.18, 0.26, 0.95)
	sb.border_width_left = 2
	sb.border_color = Color(0.45, 0.78, 1.0, 0.85)
	_player_panel.add_theme_stylebox_override("panel", sb)


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
	var st := "✓" if _slot_merc_ready(m) else "×"
	return "%s%d · %s%s %d/%d (%d%%) %s" % [
		"战" if kind == SLOT_ACTIVE else "替",
		index + 1,
		tag,
		m.merc_name,
		m.current_hp,
		max_hp,
		pct,
		st,
	]


func _slot_merc_ready(m: Mercenary) -> bool:
	if m == null or not m.is_alive:
		return false
	if m.is_test_stand_in:
		return true
	if m.is_mia or m.is_near_death or m.is_retreated or m.is_personal_break:
		return false
	if not m.is_personal_stability_ok():
		return false
	return m.get_hp_ratio() >= RosterHealth.DEPLOY_HP_RATIO


func _slot_color(merc_id: String) -> Color:
	if merc_id == "":
		return Color(0.55, 0.55, 0.6)
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m == null:
		return Color.GRAY
	if m.is_test_stand_in or _slot_merc_ready(m):
		return Color(0.75, 0.9, 1.0) if m.is_test_stand_in else Color.WHITE
	if m.is_mia:
		return Color(0.55, 0.5, 0.65)
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
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m != null and m.is_mia:
		if _status_label:
			_status_label.text = "[遗留] 不可编入"
			_status_label.modulate = Color.ORANGE_RED
		return
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
	var to_remove: Array[Node] = []
	for child in parent.get_children():
		if str(child.name).begins_with("FormationPool"):
			to_remove.append(child)
	for child in to_remove:
		parent.remove_child(child)
		child.free()


func _refresh_pool() -> void:
	if _pool_label == null:
		return
	_clear_pool_row()
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
		if e.is_test_stand_in or e.is_alive:
			if e.is_test_stand_in or _slot_merc_ready(e):
				deploy_ids.append(e.merc_id)
			elif e.is_mia:
				mia_ids.append(e.merc_id)
			else:
				rest_ids.append(e.merc_id)
	for n in GameManager.normal_roster:
		if n.merc_id in in_form:
			continue
		if n.is_test_stand_in or n.is_alive:
			if n.is_test_stand_in or _slot_merc_ready(n):
				deploy_ids.append(n.merc_id)
			elif n.is_mia:
				mia_ids.append(n.merc_id)
			else:
				rest_ids.append(n.merc_id)
	var parent: Node = _pool_label.get_parent()
	if parent == null:
		return
	var insert_idx: int = _pool_label.get_index() + 1
	if deploy_ids.is_empty() and rest_ids.is_empty() and mia_ids.is_empty():
		if not SquadFormationService.has_living_merc_roster(GameManager):
			_pool_label.text = "未编入：无佣兵（请先在兵营招募）"
		else:
			_pool_label.text = "未编入：无（全员已在 A/B 槽位）"
		return
	_pool_label.text = "未编入（点名字填入优先半组空位）："
	deploy_ids = _unique_merc_ids(deploy_ids)
	rest_ids = _unique_merc_ids(rest_ids)
	mia_ids = _unique_merc_ids(mia_ids)
	if not deploy_ids.is_empty():
		insert_idx = _add_pool_section(parent, insert_idx, "FormationPoolRow", deploy_ids, false)
	if not rest_ids.is_empty():
		insert_idx = _add_pool_section(parent, insert_idx, "FormationPoolRest", rest_ids, true, "养伤（未编入，不可出征）：")
	if not mia_ids.is_empty():
		_add_pool_section(parent, insert_idx, "FormationPoolMia", mia_ids, true, "[遗留]（未编入）：")


func _unique_merc_ids(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for mid in ids:
		if mid == "" or seen.has(mid):
			continue
		seen[mid] = true
		out.append(mid)
	return out


func _add_pool_section(
	parent: Node,
	insert_idx: int,
	row_name: String,
	merc_ids: Array[String],
	disabled: bool,
	prefix: String = ""
) -> int:
	if prefix != "":
		var lbl := Label.new()
		lbl.name = row_name + "Title"
		lbl.text = prefix
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = Color.DIM_GRAY if disabled else Color(0.75, 0.85, 0.95)
		parent.add_child(lbl)
		parent.move_child(lbl, insert_idx)
		insert_idx += 1
	var row := HFlowContainer.new()
	row.name = row_name
	for mid in merc_ids:
		var b := FormationPoolButton.new()
		var m := GameManager.find_mercenary_by_id(mid)
		b.merc_id = mid
		b.formation_ui = self
		if m != null and m.is_mia:
			b.text = "%s [遗留]" % m.merc_name
		else:
			b.text = m.merc_name if m else mid
		b.disabled = disabled
		if m != null:
			if m.is_mia:
				b.modulate = Color(0.55, 0.5, 0.65)
			elif m.is_near_death:
				b.modulate = Color(1.0, 0.5, 0.5)
			elif not _slot_merc_ready(m):
				b.modulate = Color.GOLD
		if not disabled:
			b.pressed.connect(_on_pool_merc_pressed.bind(mid))
		row.add_child(b)
	parent.add_child(row)
	parent.move_child(row, insert_idx)
	return insert_idx + 1


func _slot_key(half: String, kind: String, index: int) -> String:
	return "%s_%s_%d" % [half, kind, index]


func _pad(ids: Array[String], n: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(n):
		out.append(ids[i] if i < ids.size() else "")
	return out
