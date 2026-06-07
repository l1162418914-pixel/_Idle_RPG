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
var _pool_panel: PanelContainer = null
var _pool_body: VBoxContainer = null
var _selected: Dictionary = {}  # {half, kind, index} or empty
var _status_label: Label = null
var _expedition_panel: PanelContainer = null
var _prio_group: ButtonGroup = null
var _prio_push_btn: CheckButton = null
var _prio_march_btn: CheckButton = null
var _prio_loot_btn: CheckButton = null
var _loot_evict_check: CheckButton = null
var _loot_discard_check: CheckButton = null
var _auto_retreat_check: CheckButton = null
var _auto_retreat_safe_check: CheckButton = null
var _syncing_expedition_prefs: bool = false
var _refresh_pending: bool = false


func _ready() -> void:
	GameManager.formation_changed.connect(_schedule_refresh)
	GameManager.roster_healed.connect(_refresh_heal_visuals)
	GameManager.state_changed.connect(_on_state_changed)
	_build_ui()
	_refresh()


func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.BASE:
		_schedule_refresh()


func _schedule_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	_refresh_pending = false
	_refresh()


func _refresh_heal_visuals() -> void:
	if GameManager.state != GameManager.GameState.BASE:
		return
	GameManager.repair_roster_base_stats()
	_refresh_player_card()
	_refresh_recovery()
	_refresh_halves()


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
	_halves_row = HBoxContainer.new()
	_halves_row.add_theme_constant_override("separation", 12)
	add_child(_halves_row)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	var fill_btn := Button.new()
	fill_btn.text = "补满优先半组"
	fill_btn.tooltip_text = "从名册与替补席补满当前优先半组的出战/替补空位"
	fill_btn.pressed.connect(_on_auto_fill_preferred)
	tools.add_child(fill_btn)
	var swap_btn := Button.new()
	swap_btn.text = "A↔B 互换半组"
	swap_btn.tooltip_text = "交换两半组的出战/替补编组（佣兵整体对调）"
	swap_btn.pressed.connect(_on_swap_halves)
	tools.add_child(swap_btn)
	add_child(tools)
	var hint := Label.new()
	hint.text = "未编入→点名字或拖入空槽；先点「替」空槽再点名字可指定替补；槽位「×」移出；点两槽换位。"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color.DIM_GRAY
	add_child(hint)
	_build_pool_panel()
	_build_expedition_prefs()
	_expedition_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_player_panel = PanelContainer.new()
	_player_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	_recovery_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_recovery_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _build_pool_panel() -> void:
	_pool_panel = PanelContainer.new()
	_pool_panel.name = "FormationPoolPanel"
	_pool_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var shell_sb := StyleBoxFlat.new()
	shell_sb.bg_color = Color(0.1, 0.12, 0.16, 0.92)
	shell_sb.border_width_left = 1
	shell_sb.border_width_top = 1
	shell_sb.border_width_right = 1
	shell_sb.border_width_bottom = 1
	shell_sb.border_color = Color(0.28, 0.42, 0.55, 0.8)
	shell_sb.corner_radius_top_left = 6
	shell_sb.corner_radius_top_right = 6
	shell_sb.corner_radius_bottom_left = 6
	shell_sb.corner_radius_bottom_right = 6
	shell_sb.content_margin_left = 8
	shell_sb.content_margin_top = 6
	shell_sb.content_margin_right = 8
	shell_sb.content_margin_bottom = 6
	_pool_panel.add_theme_stylebox_override("panel", shell_sb)
	_pool_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_pool_panel.add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	_pool_label = Label.new()
	_pool_label.text = "—— 备战席 / 未编入 ——"
	_pool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pool_label.add_theme_font_size_override("font_size", 11)
	_pool_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_pool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_pool_label)
	_pool_body = VBoxContainer.new()
	_pool_body.name = "FormationPoolBody"
	_pool_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_body.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_pool_body)
	add_child(_pool_panel)


func scroll_pool_into_view() -> void:
	if _pool_panel == null:
		return
	var scroll := _find_parent_scroll()
	if scroll:
		scroll.ensure_control_visible(_pool_panel)


func _find_parent_scroll() -> ScrollContainer:
	var n: Node = get_parent()
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null


func pulse_pool_focus(seconds: float = 1.5) -> void:
	if _pool_panel == null:
		return
	var orig: Color = _pool_panel.modulate
	_pool_panel.modulate = Color(0.75, 1.05, 1.15)
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds * 0.85))
	tween.tween_property(_pool_panel, "modulate", orig, maxf(0.1, seconds * 0.15))


func _build_expedition_prefs() -> void:
	_expedition_panel = PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_expedition_panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var head := Label.new()
	head.text = "出征策略（大营预设，下趟生效）"
	head.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	col.add_child(head)
	_prio_group = ButtonGroup.new()
	var prio_row := HBoxContainer.new()
	prio_row.add_theme_constant_override("separation", 10)
	_prio_push_btn = CheckButton.new()
	_prio_push_btn.text = "推图优先"
	_prio_push_btn.tooltip_text = "推进更快、搜索更少"
	_prio_push_btn.button_group = _prio_group
	_prio_push_btn.toggled.connect(_on_expedition_priority_toggled.bind(GameManager.EXPEDITION_PRIORITY_PUSH))
	prio_row.add_child(_prio_push_btn)
	_prio_march_btn = CheckButton.new()
	_prio_march_btn.text = "均衡跑图"
	_prio_march_btn.tooltip_text = "推进与搜索默认节奏"
	_prio_march_btn.button_group = _prio_group
	_prio_march_btn.toggled.connect(_on_expedition_priority_toggled.bind(GameManager.EXPEDITION_PRIORITY_MARCH))
	prio_row.add_child(_prio_march_btn)
	_prio_loot_btn = CheckButton.new()
	_prio_loot_btn.text = "搜刮优先"
	_prio_loot_btn.tooltip_text = "搜索更密、推进略慢"
	_prio_loot_btn.button_group = _prio_group
	_prio_loot_btn.toggled.connect(_on_expedition_priority_toggled.bind(GameManager.EXPEDITION_PRIORITY_LOOT))
	prio_row.add_child(_prio_loot_btn)
	col.add_child(prio_row)
	var loot_row := HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 12)
	_loot_evict_check = CheckButton.new()
	_loot_evict_check.text = "高价值自动挤占低价值"
	_loot_evict_check.tooltip_text = "安全箱/外露格满时，用更高价值装备替换最低价值格"
	_loot_evict_check.toggled.connect(_on_loot_evict_toggled)
	loot_row.add_child(_loot_evict_check)
	_loot_discard_check = CheckButton.new()
	_loot_discard_check.text = "格满溢出自动丢弃"
	_loot_discard_check.tooltip_text = "无法放入且无法挤占时，直接丢弃新掉落"
	_loot_discard_check.toggled.connect(_on_loot_discard_toggled)
	loot_row.add_child(_loot_discard_check)
	col.add_child(loot_row)
	var retreat_row := HBoxContainer.new()
	retreat_row.add_theme_constant_override("separation", 12)
	_auto_retreat_check = CheckButton.new()
	_auto_retreat_check.text = "携带价值达标自动撤离"
	_auto_retreat_check.toggled.connect(_on_auto_retreat_toggled)
	retreat_row.add_child(_auto_retreat_check)
	_auto_retreat_safe_check = CheckButton.new()
	_auto_retreat_safe_check.text = "撤离仅计安全箱"
	_auto_retreat_safe_check.tooltip_text = "勾选后外露战利品不计入自动撤离阈值"
	_auto_retreat_safe_check.toggled.connect(_on_auto_retreat_safe_toggled)
	retreat_row.add_child(_auto_retreat_safe_check)
	col.add_child(retreat_row)
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.bg_color = Color(0.1, 0.14, 0.2, 0.92)
	sb.border_width_left = 1
	sb.border_color = Color(0.3, 0.55, 0.75, 0.7)
	_expedition_panel.add_theme_stylebox_override("panel", sb)
	add_child(_expedition_panel)


func _sync_expedition_prefs_ui() -> void:
	if _expedition_panel == null:
		return
	_syncing_expedition_prefs = true
	var pri: String = GameManager.expedition_priority
	if _prio_push_btn:
		_prio_push_btn.button_pressed = pri == GameManager.EXPEDITION_PRIORITY_PUSH
	if _prio_march_btn:
		_prio_march_btn.button_pressed = pri == GameManager.EXPEDITION_PRIORITY_MARCH
	if _prio_loot_btn:
		_prio_loot_btn.button_pressed = pri == GameManager.EXPEDITION_PRIORITY_LOOT
	if _loot_evict_check:
		_loot_evict_check.button_pressed = GameManager.loot_auto_evict_low_value
	if _loot_discard_check:
		_loot_discard_check.button_pressed = GameManager.loot_discard_overflow
	if _auto_retreat_check:
		_auto_retreat_check.button_pressed = GameManager.auto_retreat_value_enabled
	if _auto_retreat_safe_check:
		_auto_retreat_safe_check.button_pressed = GameManager.auto_retreat_safe_only
		_auto_retreat_safe_check.disabled = not GameManager.auto_retreat_value_enabled
	_syncing_expedition_prefs = false


func _on_expedition_priority_toggled(pressed: bool, priority: String) -> void:
	if _syncing_expedition_prefs or not pressed:
		return
	GameManager.expedition_priority = priority


func _on_loot_evict_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.loot_auto_evict_low_value = pressed


func _on_loot_discard_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.loot_discard_overflow = pressed


func _on_auto_retreat_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.auto_retreat_value_enabled = pressed
	if _auto_retreat_safe_check:
		_auto_retreat_safe_check.disabled = not pressed


func _on_auto_retreat_safe_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.auto_retreat_safe_only = pressed


func _refresh() -> void:
	if GameManager.state != GameManager.GameState.BASE:
		return
	SquadFormationService.ensure_formation(GameManager)
	GameManager.repair_roster_base_stats()
	_sync_expedition_prefs_ui()
	_refresh_player_card()
	_refresh_recovery()
	_refresh_halves()
	_refresh_pool()
	if _status_label:
		var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
		_status_label.text = SquadFormationService.get_formation_summary(GameManager)
		var deploy_h: String = SquadFormationService.resolve_deploy_half(GameManager)
		_status_label.text += " | 已设优先:%s" % pref
		if deploy_h != "":
			if deploy_h != pref:
				_status_label.text += " | 下趟出征:%s（%s休整·自动改派）" % [deploy_h, pref]
			else:
				_status_label.text += " | 下趟出征:%s" % deploy_h
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
		_halves_row.remove_child(c)
		c.free()
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
	var head_row := HBoxContainer.new()
	head_row.mouse_filter = Control.MOUSE_FILTER_PASS
	head_row.add_theme_constant_override("separation", 6)
	col.add_child(head_row)
	var head := Label.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.text = "半组 %s · %s" % [half, "可出战" if can_dep else "休整"]
	head.add_theme_font_size_override("font_size", 12)
	if half == pref:
		head.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	head_row.add_child(head)
	var pref_btn := Button.new()
	pref_btn.name = "PreferredHalf%s" % half
	pref_btn.text = "★ 优先" if half == pref else "设为优先"
	pref_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	pref_btn.custom_minimum_size = Vector2(88, 32)
	pref_btn.z_index = 2
	if half == pref:
		pref_btn.pressed.connect(func(): call_deferred("_on_preferred_half_already", half))
	else:
		pref_btn.pressed.connect(func(): call_deferred("_on_preferred_half", half))
	head_row.add_child(pref_btn)
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


func _on_swap_halves() -> void:
	GameManager.formation_swap_halves()
	_selected = {}
	if _status_label:
		var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
		_status_label.text = "已互换半组 A/B 编组（当前优先仍为半组 %s）" % pref
		_status_label.modulate = Color(0.75, 0.95, 0.85)


func _handle_slot_drop(target_half: String, target_kind: String, target_index: int, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var merc_id: String = str(data.get("merc_id", ""))
	if merc_id == "":
		return
	if bool(data.get("from_pool", false)):
		if bool(data.get("bench_only", false)) and target_kind != SLOT_BENCH:
			if _status_label:
				_status_label.text = "养伤佣兵仅能拖入替补席"
				_status_label.modulate = Color.ORANGE_RED
			return
		var code_p: int = GameManager.formation_assign(merc_id, target_half, target_kind, target_index)
		_selected = {}
		_show_assign_feedback(code_p, merc_id, target_half, target_kind, target_index)
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
		if code != 0:
			_show_assign_feedback(code, merc_id, target_half, target_kind, target_index)
		elif _status_label:
			_status_label.text = "已换位（半组%s）" % target_half
			_status_label.modulate = Color(0.75, 0.95, 0.85)
		return
	else:
		var code: int = GameManager.formation_assign(merc_id, target_half, target_kind, target_index)
		if code != 0:
			if _status_label:
				_status_label.text = GameManager.formation_error_message(code)
				_status_label.modulate = Color.ORANGE_RED
			return
		if target_merc != "":
			var back: int = GameManager.formation_assign(target_merc, src_half, src_kind, src_index)
			if back != 0:
				_show_assign_feedback(back, merc_id, target_half, target_kind, target_index)
				return
	_show_assign_feedback(0, merc_id, target_half, target_kind, target_index)


func _clear_slot(half: String, kind: String, index: int) -> void:
	var removed_name: String = ""
	var mid: String = _get_slot_merc_id(half, kind, index)
	if mid != "":
		var m := GameManager.find_mercenary_by_id(mid)
		if m != null:
			removed_name = m.merc_name
	_selected = {}
	var code: int = GameManager.formation_clear_slot(half, kind, index)
	if code == 0 and _status_label:
		if removed_name != "":
			_status_label.text = "已移出至未编入：%s（半组%s·%s%d）" % [
				removed_name,
				half,
				"战" if kind == SLOT_ACTIVE else "替",
				index + 1,
			]
		_status_label.modulate = Color(0.75, 0.95, 0.85)
	elif code != 0 and _status_label:
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
	m.try_clear_near_death_for_deploy()
	if not m.can_join_squad():
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
	_selected = {}
	if _status_label:
		var can: bool = SquadFormationService.half_can_deploy(GameManager, half)
		var deploy_h: String = SquadFormationService.resolve_deploy_half(GameManager)
		var extra := ""
		if deploy_h != "" and deploy_h != half:
			extra = "（下趟实际出征半组 %s）" % deploy_h
		_status_label.text = "已设半组 %s 为优先%s · %s" % [
			half,
			extra,
			"可出战" if can else "休整中·编满后可出征",
		]
		_status_label.modulate = Color(0.55, 0.92, 1.0)


func _on_preferred_half_already(half: String) -> void:
	if _status_label:
		_status_label.text = "半组 %s 已是当前优先半组" % half
		_status_label.modulate = Color(0.75, 0.9, 1.0)


func _on_slot_pressed(half: String, kind: String, index: int) -> void:
	var key := _slot_key(half, kind, index)
	if _selected.is_empty():
		_selected = {"half": half, "kind": kind, "index": index, "key": key}
		_show_slot_selection(half, kind, index)
		_refresh()
		return
	if _selected.get("key", "") == key:
		var mid_same: String = _get_slot_merc_id(half, kind, index)
		if mid_same != "":
			_clear_slot(half, kind, index)
		else:
			_selected = {}
			_refresh()
		return
	var sh: String = str(_selected.half)
	var sk: String = str(_selected.kind)
	var si: int = int(_selected.index)
	var mid: String = _get_slot_merc_id(sh, sk, si)
	var target_mid: String = _get_slot_merc_id(half, kind, index)
	var code: int = 0
	if sh == half:
		code = GameManager.formation_swap_slots(half, sk, si, kind, index)
		_selected = {}
		if code != 0:
			_show_assign_feedback(code, mid if mid != "" else target_mid, half, kind, index)
		elif _status_label:
			_status_label.text = "已换位（半组%s）" % half
			_status_label.modulate = Color(0.75, 0.95, 0.85)
		return
	if mid != "":
		code = GameManager.formation_assign(mid, half, kind, index)
		if code == 0 and target_mid != "":
			code = GameManager.formation_assign(target_mid, sh, sk, si)
	elif target_mid != "":
		code = GameManager.formation_assign(target_mid, sh, sk, si)
	_selected = {}
	if code == 0 and (mid != "" or target_mid != ""):
		_show_assign_feedback(0, mid if mid != "" else target_mid, half, kind, index)
	elif code != 0:
		_show_assign_feedback(code, mid if mid != "" else target_mid, half, kind, index)


func _get_slot_merc_id(half: String, kind: String, index: int) -> String:
	var ids: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half) if kind == SLOT_ACTIVE else SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	ids = _pad(ids, SquadFormationService.MAX_ACTIVE if kind == SLOT_ACTIVE else SquadFormationService.MAX_BENCH)
	if index >= 0 and index < ids.size():
		return ids[index]
	return ""


func _on_pool_merc_pressed(merc_id: String, bench_only: bool = false) -> void:
	var m := GameManager.find_mercenary_by_id(merc_id)
	if _status_label and m != null:
		_status_label.text = "编入 %s…" % m.merc_name
		_status_label.modulate = Color(0.85, 0.95, 1.0)
	elif _status_label:
		_status_label.text = "编入 %s…" % merc_id
		_status_label.modulate = Color(0.85, 0.95, 1.0)
	if m != null and m.is_mia:
		if _status_label:
			_status_label.text = "[遗留] 不可编入"
			_status_label.modulate = Color.ORANGE_RED
		return
	if not _selected.is_empty():
		var sh: String = str(_selected.half)
		var sk: String = str(_selected.kind)
		var si: int = int(_selected.index)
		if bench_only and sk != SLOT_BENCH:
			if _status_label:
				_status_label.text = "养伤佣兵仅能编入替补席，请先点选「替」空槽"
				_status_label.modulate = Color.ORANGE_RED
			return
		if (
			not bench_only
			and sk == SLOT_ACTIVE
			and m != null
			and not m.is_test_stand_in
			and not _slot_merc_ready(m)
		):
			if _status_label:
				_status_label.text = "该佣兵暂不可出战，请点选替补空槽"
				_status_label.modulate = Color.ORANGE_RED
			return
		var code_sel: int = GameManager.formation_assign(merc_id, sh, sk, si)
		_selected = {}
		_show_assign_feedback(code_sel, merc_id, sh, sk, si)
		return
	if bench_only:
		_assign_pool_to_bench(merc_id)
		return
	_assign_pool_auto(merc_id)


func _assign_pool_auto(merc_id: String) -> void:
	var half: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	if _try_assign_pool_to_half(merc_id, half, false):
		return
	var other: String = (
		SquadFormationService.HALF_B if half == SquadFormationService.HALF_A else SquadFormationService.HALF_A
	)
	if _try_assign_pool_to_half(merc_id, other, true):
		return
	if _status_label:
		_status_label.text = "两半组槽位已满或该佣兵已在编"
		_status_label.modulate = Color.ORANGE_RED


func _try_assign_pool_to_half(merc_id: String, half: String, _is_fallback: bool) -> bool:
	var last_code: int = 0
	var a_idx: int = _first_free_slot_index(half, SLOT_ACTIVE)
	if a_idx >= 0:
		var code: int = GameManager.formation_assign(merc_id, half, SLOT_ACTIVE, a_idx)
		if code == 0:
			_show_assign_feedback(0, merc_id, half, SLOT_ACTIVE, a_idx)
			return true
		last_code = code
	var b_idx: int = _first_free_slot_index(half, SLOT_BENCH)
	if b_idx >= 0:
		var code_b: int = GameManager.formation_assign(merc_id, half, SLOT_BENCH, b_idx)
		if code_b == 0:
			_show_assign_feedback(0, merc_id, half, SLOT_BENCH, b_idx)
			return true
		last_code = code_b
	if last_code != 0 and _status_label:
		_status_label.text = GameManager.formation_error_message(last_code)
		_status_label.modulate = Color.ORANGE_RED
	return false


func _assign_pool_to_bench(merc_id: String) -> void:
	var half: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	var other: String = (
		SquadFormationService.HALF_B if half == SquadFormationService.HALF_A else SquadFormationService.HALF_A
	)
	for h in [half, other]:
		var b_idx: int = _first_free_slot_index(h, SLOT_BENCH)
		if b_idx >= 0:
			var code: int = GameManager.formation_assign(merc_id, h, SLOT_BENCH, b_idx)
			if code == 0:
				_show_assign_feedback(0, merc_id, h, SLOT_BENCH, b_idx)
				return
	if _status_label:
		_status_label.text = "替补席已满或该佣兵已在编"
		_status_label.modulate = Color.ORANGE_RED


func _show_slot_selection(half: String, kind: String, index: int) -> void:
	if _status_label == null:
		return
	var slot_name: String = "半组%s·%s%d" % [
		half,
		"战" if kind == SLOT_ACTIVE else "替",
		index + 1,
	]
	var mid: String = _get_slot_merc_id(half, kind, index)
	if mid != "":
		var m := GameManager.find_mercenary_by_id(mid)
		var name_text: String = m.merc_name if m else mid
		_status_label.text = "已选 %s（%s）— 再点另一槽换位，或点未编入填入" % [name_text, slot_name]
	else:
		_status_label.text = "已选空槽 %s — 点未编入佣兵或拖入填入" % slot_name
	_status_label.modulate = Color(0.7, 1.0, 0.85)


func _clear_pool_row() -> void:
	if _pool_body == null:
		return
	var to_remove: Array[Node] = []
	for child in _pool_body.get_children():
		if str(child.name).begins_with("FormationPool"):
			to_remove.append(child)
	for child in to_remove:
		_pool_body.remove_child(child)
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
	if _pool_body == null:
		return
	var insert_idx: int = 0
	if deploy_ids.is_empty() and rest_ids.is_empty() and mia_ids.is_empty():
		if not SquadFormationService.has_living_merc_roster(GameManager):
			_pool_label.text = "—— 备战席 / 未编入 ——（无佣兵，请兵营招募）"
		else:
			_pool_label.text = "—— 备战席 / 未编入 ——（全员已在 A/B 槽，点 × 移出）"
		return
	_pool_label.text = "—— 备战席 / 未编入 ——（点选或拖入半组槽位）"
	deploy_ids = _unique_merc_ids(deploy_ids)
	rest_ids = _unique_merc_ids(rest_ids)
	mia_ids = _unique_merc_ids(mia_ids)
	if not deploy_ids.is_empty():
		insert_idx = _add_pool_section(_pool_body, insert_idx, "FormationPoolRow", deploy_ids, false, "可出征：", false)
	if not rest_ids.is_empty():
		insert_idx = _add_pool_section(
			_pool_body, insert_idx, "FormationPoolRest", rest_ids, false,
			"养伤（仅可编入替补席）：", true
		)
	if not mia_ids.is_empty():
		_add_pool_section(_pool_body, insert_idx, "FormationPoolMia", mia_ids, true, "[遗留]：", false)


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
	not_clickable: bool,
	prefix: String = "",
	bench_only: bool = false
) -> int:
	if prefix != "":
		var lbl := Label.new()
		lbl.name = row_name + "Title"
		lbl.text = prefix
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = Color.DIM_GRAY if not_clickable else Color(0.75, 0.85, 0.95)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)
		parent.move_child(lbl, insert_idx)
		insert_idx += 1
	var row := HFlowContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var pending: Array[Dictionary] = []
	for mid in merc_ids:
		var b := FormationPoolButton.new()
		var m := GameManager.find_mercenary_by_id(mid)
		b.merc_id = mid
		b.formation_ui = self
		var label_text: String = m.merc_name if m else mid
		if m != null and m.is_mia:
			label_text = "%s [遗留]" % m.merc_name
		var tint := Color.WHITE
		if m != null:
			if m.is_mia:
				tint = Color(0.55, 0.5, 0.65)
			elif m.is_near_death:
				tint = Color(1.0, 0.5, 0.5)
			elif not _slot_merc_ready(m):
				tint = Color.GOLD
			else:
				tint = Color(0.85, 0.92, 1.0)
		row.add_child(b)
		pending.append({
			"btn": b,
			"text": label_text,
			"not_clickable": not_clickable,
			"tint": tint,
			"bench_only": bench_only,
		})
	parent.add_child(row)
	parent.move_child(row, insert_idx)
	for entry in pending:
		var btn: FormationPoolButton = entry.btn
		btn.apply_pool(entry.text, entry.not_clickable, entry.tint, entry.bench_only)
	return insert_idx + 1


func _first_free_slot_index(half: String, kind: String) -> int:
	var max_n: int = (
		SquadFormationService.MAX_ACTIVE if kind == SLOT_ACTIVE else SquadFormationService.MAX_BENCH
	)
	var ids: Array[String] = (
		SquadFormationService.get_active_ids(GameManager.squad_formation, half)
		if kind == SLOT_ACTIVE
		else SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	)
	ids = _pad(ids, max_n)
	for i in range(max_n):
		if ids[i] == "":
			return i
	return -1


func _show_assign_feedback(code: int, merc_id: String, half: String, kind: String, index: int) -> void:
	if _status_label == null:
		return
	if code != 0:
		_status_label.text = GameManager.formation_error_message(code)
		_status_label.modulate = Color.ORANGE_RED
		return
	var m := GameManager.find_mercenary_by_id(merc_id)
	var name_text: String = m.merc_name if m else merc_id
	_status_label.text = "已编入 %s → 半组%s·%s%d" % [
		name_text,
		half,
		"战" if kind == SLOT_ACTIVE else "替",
		index + 1,
	]
	_status_label.modulate = Color(0.75, 0.95, 0.85)


func _slot_key(half: String, kind: String, index: int) -> String:
	return "%s_%s_%d" % [half, kind, index]


func _pad(ids: Array[String], n: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(n):
		out.append(ids[i] if i < ids.size() else "")
	return out
