extends Control
## SquadUI — 出征编队界面

@onready var available_list: VBoxContainer = $MarginContainer/MainVBox/RosterHBox/LeftPanel/AvailableScroll/Available
@onready var selected_list: VBoxContainer = $MarginContainer/MainVBox/RosterHBox/RightPanel/SelectedScroll/Selected
@onready var map_label: Label = $MarginContainer/MainVBox/MapLabel
@onready var start_button: Button = $MarginContainer/MainVBox/ButtonHBox/StartButton
@onready var back_button: Button = $MarginContainer/MainVBox/ButtonHBox/BackButton

var _selected_ids: Array[String] = []

var shell_left_root: Control = null
var shell_center_root: Control = null
var shell_right_root: Control = null
var _safe_preview_label: Label = null
var _prepare_grid_ui: RunGridUI = null
var _shell_attached: bool = false
var _prepare_left_scroll: ScrollContainer = null
var _prepare_center_scroll: ScrollContainer = null
var _prepare_expand_btn: Button = null
var _prepare_full_text: String = ""
var _prepare_detail_expanded: bool = false
var _mutual_hint_label: Label = null
var _skip_mutual_check: CheckButton = null


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PREPARE:
		_refresh()


func attach_to_shell(left_slot: Control, center_slot: Control, right_slot: Control) -> void:
	if _shell_attached:
		return
	_shell_attached = true
	var main_vbox: VBoxContainer = $MarginContainer/MainVBox
	shell_left_root = VBoxContainer.new()
	shell_left_root.name = "PrepareLeftDetail"
	shell_left_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_left_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prepare_left_scroll = ScrollContainer.new()
	_prepare_left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_wrap := VBoxContainer.new()
	left_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if map_label:
		map_label.reparent(left_wrap)
		map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		map_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		map_label.max_lines_visible = 2
	_prepare_expand_btn = Button.new()
	_prepare_expand_btn.text = "展开详情"
	_prepare_expand_btn.custom_minimum_size = Vector2(96, 36)
	_prepare_expand_btn.pressed.connect(_on_prepare_expand_toggled)
	left_wrap.add_child(_prepare_expand_btn)
	_mutual_hint_label = Label.new()
	_mutual_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mutual_hint_label.add_theme_font_size_override("font_size", 11)
	_mutual_hint_label.modulate = Color(0.72, 0.82, 0.95)
	left_wrap.add_child(_mutual_hint_label)
	_skip_mutual_check = CheckButton.new()
	_skip_mutual_check.text = "本趟正常远征（跳过互捞）"
	_skip_mutual_check.visible = false
	_skip_mutual_check.toggled.connect(func(_on: bool) -> void: _update_start_button())
	left_wrap.add_child(_skip_mutual_check)
	_prepare_left_scroll.add_child(left_wrap)
	shell_left_root.add_child(_prepare_left_scroll)
	left_slot.add_child(shell_left_root)
	shell_center_root = VBoxContainer.new()
	shell_center_root.name = "PrepareCenterSquad"
	shell_center_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_center_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sep := main_vbox.get_node_or_null("HSeparator") as Control
	if sep:
		sep.reparent(shell_center_root)
	_prepare_center_scroll = ScrollContainer.new()
	_prepare_center_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var center_wrap := VBoxContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var roster_hbox := main_vbox.get_node_or_null("RosterHBox") as Control
	if roster_hbox:
		roster_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		roster_hbox.reparent(center_wrap)
	var btn_hbox := main_vbox.get_node_or_null("ButtonHBox") as Control
	if btn_hbox:
		btn_hbox.reparent(center_wrap)
		if start_button:
			start_button.text = "出发"
			start_button.custom_minimum_size = Vector2(96, 36)
		if back_button:
			back_button.custom_minimum_size = Vector2(96, 36)
	_prepare_center_scroll.add_child(center_wrap)
	shell_center_root.add_child(_prepare_center_scroll)
	center_slot.add_child(shell_center_root)
	shell_right_root = VBoxContainer.new()
	shell_right_root.name = "PrepareRightPreview"
	shell_right_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_right_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prepare_grid_ui = RunGridUI.new()
	_prepare_grid_ui.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell_right_root.add_child(_prepare_grid_ui)
	_safe_preview_label = Label.new()
	_safe_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_safe_preview_label.size_flags_vertical = Control.SIZE_SHRINK_END
	shell_right_root.add_child(_safe_preview_label)
	right_slot.add_child(shell_right_root)
	visible = false


func _refresh() -> void:
	_prepare_detail_expanded = false
	_selected_ids.clear()
	GameManager.selected_squad.clear()
	SquadFormationService.ensure_formation(GameManager)
	var half: String = SquadFormationService.pick_deploy_half(GameManager)
	var md: Dictionary = DataLoader.map_data(GameManager.selected_map_id)
	var lock_roster: bool = TestScenarioService.should_lock_roster(md)
	if half == "":
		_selected_ids.clear()
	else:
		if not lock_roster:
			SquadFormationService.auto_fill_half(GameManager, half)
		for m in SquadFormationService.resolve_active_squad(GameManager, half):
			_selected_ids.append(m.merc_id)
	
	if map_label:
		var map_name: String = md.get("name", GameManager.selected_map_id) if not md.is_empty() else GameManager.selected_map_id
		var danger: int = int(md.get("danger_level", 1)) if not md.is_empty() else 1
		var boss_dist: float = float(md.get("boss_distance", 600.0))
		var extra := ""
		var req: String = str(md.get("unlock_after_boss_on_map", ""))
		if req != "":
			var prev: Dictionary = DataLoader.map_data(req)
			extra = " | 前置: %s Boss" % prev.get("name", req)
		var team_st: int = GameManager.get_team_stability()
		var withdraw_hint := ""
		if team_st <= StabilitySystem.TEAM_WITHDRAW_THRESHOLD + 10:
			withdraw_hint = " (团队≤30强制撤离)"
		var form_hint: String = SquadFormationService.get_formation_summary(GameManager)
		var lines: PackedStringArray = []
		lines.append(
			"地图: %s | 危险%d | Boss %.0fm | 团队稳定度:%d%s%s" % [
				map_name, danger, boss_dist, team_st, withdraw_hint, extra
			]
		)
		lines.append(form_hint)
		var test_banner: String = TestScenarioService.get_run_start_banner(md)
		if test_banner != "":
			lines.append(test_banner)
		if lock_roster:
			lines.append("（本测试图编队已锁定 — 选图时自动注入自带测试人物，见 [本图编队] 行）")
		else:
			lines.append("（编队在大营「双半组编队」调整；此处为即将出征名单）")
		if half != "" and GameManager.player != null:
			var merc_only := true
			for mid in _selected_ids:
				if mid == GameManager.player.merc_id:
					merc_only = false
					break
			if merc_only:
				lines.append("（本趟佣兵出征，主角留营）")
		if md.has("extract_distance"):
			lines.append(
				"撤离点 %.0fm · 智能撤离阈值 %d · 撤离物掉率 %.0f%%" % [
					float(md.extract_distance),
					int(md.get("auto_carry_value_threshold", 0)),
					float(md.get("extract_drop_chance", 0.04)) * 100.0,
				]
			)
		elif TestScenarioService.is_test_map(md):
			var test_hints: PackedStringArray = []
			if md.has("auto_carry_value_threshold"):
				test_hints.append("携带价值阈值 %d" % int(md.get("auto_carry_value_threshold", 0)))
			if md.has("exposed_grid_w"):
				test_hints.append(
					"外露格 %dx%d" % [int(md.get("exposed_grid_w", 4)), int(md.get("exposed_grid_h", 3))]
				)
			if float(md.get("drop_chance", 0.0)) > 0.001:
				test_hints.append("装备掉率 %.0f%%" % (float(md.drop_chance) * 100.0))
			if bool(md.get("disable_boss_chase", false)):
				test_hints.append("无 Boss 追击")
			if bool(md.get("auto_retreat_on_boss_spawn", false)):
				test_hints.append("区域首领出现即自动返程")
			if test_hints.size() > 0:
				lines.append("测试参数: " + " · ".join(test_hints))
		_prepare_full_text = "\n".join(lines)
		_apply_prepare_left_display()
		if GameManager.is_recovery_lock_active():
			map_label.modulate = Color.ORANGE_RED
		else:
			map_label.modulate = Color.WHITE
	
	_refresh_safe_preview(md)
	_refresh_available()
	_refresh_selected()
	_update_start_button()


func _refresh_safe_preview(md: Dictionary) -> void:
	if _prepare_grid_ui:
		var safe_sz: Vector2i = GameManager.get_safe_box_grid_size()
		var exposed_sz := Vector2i(
			int(md.get("exposed_grid_w", 4)),
			int(md.get("exposed_grid_h", 3))
		)
		_prepare_grid_ui.show_empty_preview(safe_sz, exposed_sz)
	if _safe_preview_label == null:
		return
	var lines: PackedStringArray = []
	lines.append("—— 安全箱 / 外露格预览 ——")
	if md.is_empty():
		_safe_preview_label.text = "（无地图数据）"
		return
	if md.has("exposed_grid_w"):
		lines.append(
			"外露格 %dx%d (出征后占格，T-05 完整交互)" % [
				int(md.get("exposed_grid_w", 4)), int(md.get("exposed_grid_h", 3))
			]
		)
	else:
		lines.append("外露格：标准 4×3 (占位)")
	if md.has("auto_carry_value_threshold"):
		lines.append("智能撤离阈值: %d" % int(md.get("auto_carry_value_threshold", 0)))
	if TestScenarioService.is_test_map(md):
		lines.append("测试图：结算后编队可重注入")
	_safe_preview_label.text = "\n".join(lines)
	_safe_preview_label.modulate = Color(0.7, 0.82, 0.95)


func _refresh_available() -> void:
	if not available_list:
		return
	for child in available_list.get_children():
		child.queue_free()
	
	var lock_roster: bool = TestScenarioService.should_lock_roster(
		DataLoader.map_data(GameManager.selected_map_id)
	)
	_add_player_stay_label()
	var deploy: Array[Mercenary] = []
	var rest: Array[Mercenary] = []
	var mia: Array[Mercenary] = []
	for e in GameManager.elite_roster:
		if e.is_test_stand_in:
			deploy.append(e)
			continue
		if not e.is_alive:
			continue
		if e.is_mia:
			mia.append(e)
		elif not e.can_join_squad():
			rest.append(e)
		else:
			deploy.append(e)
	for n in GameManager.normal_roster:
		if n.is_test_stand_in:
			deploy.append(n)
			continue
		if not n.is_alive:
			continue
		if n.is_mia:
			mia.append(n)
		elif not n.can_join_squad():
			rest.append(n)
		else:
			deploy.append(n)
	_add_available_section("可出征", deploy, lock_roster)
	_add_available_section("养伤", rest, true)
	_add_available_section("战场遗留", mia, true)


func _add_available_section(title: String, mercs: Array[Mercenary], force_disabled: bool) -> void:
	if mercs.is_empty():
		return
	var head := Label.new()
	head.text = "—— %s ——" % title
	head.add_theme_font_size_override("font_size", 11)
	head.modulate = Color.DIM_GRAY
	available_list.add_child(head)
	for merc in mercs:
		var btn := _make_merc_button(merc, false)
		if force_disabled:
			btn.disabled = true
		available_list.add_child(btn)


func _add_player_stay_label() -> void:
	var p = GameManager.player
	if p == null:
		return
	var max_hp: int = maxi(1, StatResolver.get_max_hp(p))
	var pct: int = int(float(p.current_hp) / float(max_hp) * 100.0)
	var status := "留营"
	if p.is_near_death:
		status = "濒死·留营恢复"
	elif not p.can_join_squad():
		status = "休整·留营恢复"
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = "[主角留营] %s Lv.%d · %d%%HP · %s（本趟不出征）" % [
		p.merc_name, p.level, pct, status,
	]
	lbl.modulate = Color(0.75, 0.9, 1.0)
	available_list.add_child(lbl)


func _make_merc_button(merc: Mercenary, is_player: bool) -> Button:
	var btn = Button.new()
	var prefix = "[主角]" if is_player else ("[精英]" if merc is EliteMercenary else "[佣兵]")
	if merc.is_test_stand_in:
		var max_hp_t: int = StatResolver.get_max_hp(merc)
		btn.text = "%s %s Lv.%d HP:%d/%d [测试·锁定]" % [
			prefix, merc.merc_name, merc.level, merc.current_hp, max_hp_t,
		]
		btn.modulate = Color(0.75, 0.9, 1.0)
		return btn
	if merc.is_dead():
		btn.text = "%s %s Lv.%d [阵亡]" % [prefix, merc.merc_name, merc.level]
		btn.modulate = Color.DIM_GRAY
		btn.disabled = true
	elif merc.is_mia:
		btn.text = "%s %s Lv.%d [遗留]" % [prefix, merc.merc_name, merc.level]
		btn.modulate = Color(0.55, 0.5, 0.65)
		btn.disabled = true
	elif merc.is_near_death:
		var scar_line := ""
		if merc.scar_stacks > 0:
			scar_line = " 伤×%d %s" % [merc.scar_stacks, merc.get_scar_effect_summary()]
		btn.text = "%s %s Lv.%d [濒死·需先恢复]%s" % [
			prefix, merc.merc_name, merc.level, scar_line
		]
		btn.modulate = Color.ORANGE_RED
		btn.disabled = true
	elif not merc.can_join_squad():
		var reason := "[个人稳定不足]"
		if merc.is_personal_break or not merc.is_personal_stability_ok():
			reason = "[个人稳定不足·回城恢复]"
		elif merc.is_retreated:
			reason = "[休整·满血后可出征]"
		btn.text = "%s %s Lv.%d HP:%d/%d 个人稳:%d %s" % [
			prefix, merc.merc_name, merc.level, merc.current_hp, StatResolver.get_max_hp(merc),
			merc.personal_stability, reason
		]
		btn.modulate = Color.GOLD
		btn.disabled = true
	else:
		btn.text = "%s %s Lv.%d HP:%d/%d 个人稳:%d ATK:%d" % [
			prefix, merc.merc_name, merc.level, merc.current_hp, StatResolver.get_max_hp(merc),
			merc.personal_stability, StatResolver.get_patk(merc)
		]
		btn.disabled = true
		if merc.merc_id in _selected_ids:
			btn.modulate = Color.GREEN
		else:
			btn.modulate = Color(0.7, 0.75, 0.8)
	
	return btn


func _on_merc_selected(merc_id: String, btn: Button) -> void:
	var md: Dictionary = DataLoader.map_data(GameManager.selected_map_id)
	if TestScenarioService.should_lock_roster(md):
		return
	if merc_id in _selected_ids:
		_selected_ids.erase(merc_id)
		btn.modulate = Color.WHITE
	else:
		_selected_ids.append(merc_id)
		btn.modulate = Color.GREEN
	_refresh_selected()
	_update_start_button()


func _refresh_selected() -> void:
	if not selected_list:
		return
	for child in selected_list.get_children():
		child.queue_free()
	
	GameManager.selected_squad.clear()
	
	for mid in _selected_ids:
		var merc = _find_merc(mid)
		if merc and merc.can_join_squad():
			GameManager.selected_squad.append(merc)
			var label = Label.new()
			label.text = "%s Lv.%d ATK:%d" % [merc.merc_name, merc.level, StatResolver.get_patk(merc)]
			selected_list.add_child(label)


func _find_merc(merc_id: String) -> Mercenary:
	if GameManager.player and GameManager.player.merc_id == merc_id:
		return GameManager.player
	for e in GameManager.elite_roster:
		if e.merc_id == merc_id:
			return e
	for n in GameManager.normal_roster:
		if n.merc_id == merc_id:
			return n
	return null


func _apply_prepare_left_display() -> void:
	if map_label == null:
		return
	if _prepare_detail_expanded:
		map_label.max_lines_visible = 0
		map_label.text = _prepare_full_text
		if _prepare_expand_btn:
			_prepare_expand_btn.text = "收起详情"
	else:
		map_label.max_lines_visible = 2
		var parts: PackedStringArray = _prepare_full_text.split("\n", false)
		if parts.size() <= 2:
			map_label.text = _prepare_full_text
		else:
			map_label.text = "%s\n%s" % [parts[0], parts[1]]
		if _prepare_expand_btn:
			_prepare_expand_btn.text = "展开详情"
			_prepare_expand_btn.visible = parts.size() > 2 or _prepare_full_text.length() > 80


func _on_prepare_expand_toggled() -> void:
	_prepare_detail_expanded = not _prepare_detail_expanded
	_apply_prepare_left_display()


func scroll_prepare_left_to_top() -> void:
	if _prepare_left_scroll:
		_prepare_left_scroll.scroll_vertical = 0


func scroll_prepare_center_to_top() -> void:
	if _prepare_center_scroll:
		_prepare_center_scroll.scroll_vertical = 0


func pulse_prepare_center(seconds: float = 2.0) -> void:
	if shell_center_root == null:
		return
	var orig: Color = shell_center_root.modulate
	shell_center_root.modulate = Color(0.7, 1.05, 1.2)
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds * 0.85))
	tween.tween_property(shell_center_root, "modulate", orig, maxf(0.1, seconds * 0.15))


func _update_start_button() -> void:
	if start_button:
		var half: String = SquadFormationService.pick_deploy_half(GameManager)
		start_button.disabled = half == "" or GameManager.is_recovery_lock_active()
		var mutual_target: String = ""
		if (
			half != ""
			and MutualRecoveryService.is_auto_enabled(GameManager)
			and not (_skip_mutual_check and _skip_mutual_check.button_pressed)
		):
			mutual_target = MutualRecoveryService.pick_target(GameManager, half)
		if mutual_target != "":
			start_button.text = "出发·互捞"
		else:
			start_button.text = "出发" if half != "" else "无法出征"
	_update_mutual_recovery_hint()


func _update_mutual_recovery_hint() -> void:
	if _mutual_hint_label == null:
		return
	var half: String = SquadFormationService.pick_deploy_half(GameManager)
	if half == "" or not MutualRecoveryService.is_auto_enabled(GameManager):
		_mutual_hint_label.text = ""
		if _skip_mutual_check:
			_skip_mutual_check.visible = false
		return
	var desc: String = MutualRecoveryService.describe_pending(GameManager, half)
	if desc == "":
		_mutual_hint_label.text = ""
		if _skip_mutual_check:
			_skip_mutual_check.visible = false
	else:
		_mutual_hint_label.text = desc
		if _skip_mutual_check:
			_skip_mutual_check.visible = true


func _on_start_pressed() -> void:
	if GameManager.selected_squad.size() < 1:
		return
	var skip_mutual: bool = _skip_mutual_check != null and _skip_mutual_check.visible and _skip_mutual_check.button_pressed
	var code: int = GameManager.start_run(skip_mutual)
	if code != 0 and map_label:
		map_label.text = GameManager.get_run_start_error_message(code)
		map_label.modulate = Color.ORANGE_RED


func _on_back_pressed() -> void:
	GameManager.return_to_base()