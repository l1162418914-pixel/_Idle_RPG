extends Control
## SquadUI — 出征编队界面

@onready var available_list: VBoxContainer = $MarginContainer/MainVBox/RosterHBox/LeftPanel/AvailableScroll/Available
@onready var selected_list: VBoxContainer = $MarginContainer/MainVBox/RosterHBox/RightPanel/SelectedScroll/Selected
@onready var map_label: Label = $MarginContainer/MainVBox/MapLabel
@onready var start_button: Button = $MarginContainer/MainVBox/ButtonHBox/StartButton
@onready var back_button: Button = $MarginContainer/MainVBox/ButtonHBox/BackButton

var _selected_ids: Array[String] = []


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.PREPARE)
	if visible:
		_refresh()


func _refresh() -> void:
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
			lines.append("（本测试图编队已锁定，请回大营「双半组编队」调整槽位）")
		else:
			lines.append("（编队在大营「双半组编队」调整；此处为即将出征名单）")
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
		map_label.text = "\n".join(lines)
		if GameManager.is_recovery_lock_active():
			map_label.modulate = Color.ORANGE_RED
		else:
			map_label.modulate = Color.WHITE
	
	_refresh_available()
	_refresh_selected()
	_update_start_button()


func _refresh_available() -> void:
	if not available_list:
		return
	for child in available_list.get_children():
		child.queue_free()
	
	var lock_roster: bool = TestScenarioService.should_lock_roster(
		DataLoader.map_data(GameManager.selected_map_id)
	)
	var player = GameManager.player
	if player:
		var btn = _make_merc_button(player, true)
		if lock_roster:
			btn.disabled = true
		available_list.add_child(btn)
	for e in GameManager.elite_roster:
		var btn = _make_merc_button(e, false)
		if lock_roster:
			btn.disabled = true
		available_list.add_child(btn)
	
	for n in GameManager.normal_roster:
		var btn = _make_merc_button(n, false)
		if lock_roster:
			btn.disabled = true
		available_list.add_child(btn)


func _make_merc_button(merc: Mercenary, is_player: bool) -> Button:
	var btn = Button.new()
	var prefix = "[主角]" if is_player else ("[精英]" if merc is EliteMercenary else "[佣兵]")
	
	if merc.is_dead():
		btn.text = "%s %s Lv.%d [阵亡]" % [prefix, merc.merc_name, merc.level]
		btn.modulate = Color.DIM_GRAY
		btn.disabled = true
	elif merc.is_near_death:
		var scar_line := ""
		if merc.scar_stacks > 0:
			scar_line = " 伤×%d %s" % [merc.scar_stacks, merc.get_scar_effect_summary()]
		btn.text = "%s %s Lv.%d [濒死·需≥70%%HP]%s" % [
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


func _update_start_button() -> void:
	if start_button:
		var half: String = SquadFormationService.pick_deploy_half(GameManager)
		start_button.disabled = half == "" or GameManager.is_recovery_lock_active()
		start_button.text = "按半组 %s 出征" % half if half != "" else "无法出征"


func _on_start_pressed() -> void:
	if GameManager.selected_squad.size() < 1:
		return
	var code: int = GameManager.start_run()
	if code != 0 and map_label:
		map_label.text = GameManager.get_run_start_error_message(code)
		map_label.modulate = Color.ORANGE_RED


func _on_back_pressed() -> void:
	GameManager.return_to_base()