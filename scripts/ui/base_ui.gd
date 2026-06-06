extends Control
## BaseUI — 基地主界面

@onready var gold_label: Label = $MarginContainer/MainVBox/GoldLabel
@onready var maps_list: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/MapsList
@onready var buildings_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Buildings
@onready var roster_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Roster
@onready var dead_roster_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/DeadRoster
@onready var action_buttons: HFlowContainer = $MarginContainer/MainVBox/Actions
@onready var status_label: Label = $MarginContainer/MainVBox/StatusLabel
@onready var equipment_button: Button = $MarginContainer/MainVBox/Actions/EquipmentBtn

var _equipment_ui: Control = null
var _auto_run_check: CheckButton = null
var _formation_ui: VBoxContainer = null
var _redeploy_btn: Button = null

var shell_left_root: Control = null
var shell_center_root: Control = null
var shell_right_root: Control = null
var _shell_attached: bool = false
var _main_shell: MainShell = null
var _test_maps_expanded: bool = false
var _maps_scroll: ScrollContainer = null
var _form_scroll: ScrollContainer = null


func _ready() -> void:
	if status_label:
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.max_lines_visible = 4
	var root := get_tree().current_scene
	_equipment_ui = root.get_node_or_null("EquipmentUI") if root else null
	GameManager.gold_changed.connect(_update_gold)
	GameManager.state_changed.connect(_on_state_changed)
	if equipment_button:
		equipment_button.pressed.connect(_on_equipment_pressed)
	if _equipment_ui and _equipment_ui.has_signal("closed"):
		_equipment_ui.closed.connect(_refresh)
	GameManager.roster_healed.connect(_on_roster_healed)
	GameManager.squad_stability_changed.connect(_on_squad_stability_changed)
	GameManager.run_start_failed.connect(_on_run_start_failed)
	_ensure_auto_run_toggle()
	_ensure_redeploy_button()
	_refresh()


func _on_roster_healed() -> void:
	if GameManager.state == GameManager.GameState.BASE:
		_refresh()


func _on_squad_stability_changed(_value: int) -> void:
	if GameManager.state == GameManager.GameState.BASE:
		_refresh()


func ensure_formation_in(host: Control) -> VBoxContainer:
	if _formation_ui and is_instance_valid(_formation_ui):
		if _formation_ui.get_parent() != host:
			_formation_ui.reparent(host)
		return _formation_ui
	var script_res: Script = load("res://scripts/ui/formation_ui.gd")
	if script_res == null or host == null:
		return null
	_formation_ui = VBoxContainer.new()
	_formation_ui.set_script(script_res)
	_formation_ui.name = "FormationPanel"
	_formation_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(_formation_ui)
	return _formation_ui


func attach_to_shell(
	left_slot: Control,
	center_slot: Control,
	right_slot: Control,
	logistics_buildings: VBoxContainer,
	logistics_recruit: VBoxContainer,
	logistics_dead: VBoxContainer
) -> void:
	if _shell_attached:
		return
	_shell_attached = true
	var main_vbox: VBoxContainer = $MarginContainer/MainVBox
	for node_name in ["GoldLabel", "HSeparator", "Scroll", "HSeparator2"]:
		var n := main_vbox.get_node_or_null(node_name) as Control
		if n:
			n.visible = false
	var content: VBoxContainer = main_vbox.get_node_or_null("Scroll/Content") as VBoxContainer
	if content == null:
		return
	shell_left_root = VBoxContainer.new()
	shell_left_root.name = "BaseLeftMaps"
	shell_left_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_left_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var maps_title := content.get_node_or_null("MapsTitle") as Control
	if maps_title:
		maps_title.reparent(shell_left_root)
	_maps_scroll = ScrollContainer.new()
	_maps_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var maps_wrap := VBoxContainer.new()
	maps_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if maps_list:
		maps_list.reparent(maps_wrap)
	_maps_scroll.add_child(maps_wrap)
	shell_left_root.add_child(_maps_scroll)
	if status_label:
		status_label.visible = false
	left_slot.add_child(shell_left_root)
	shell_center_root = VBoxContainer.new()
	shell_center_root.name = "BaseCenterFormation"
	shell_center_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_center_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll = ScrollContainer.new()
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var form_host := VBoxContainer.new()
	form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_scroll.add_child(form_host)
	shell_center_root.add_child(_form_scroll)
	center_slot.add_child(shell_center_root)
	ensure_formation_in(form_host)
	shell_right_root = VBoxContainer.new()
	shell_right_root.name = "BaseRightRoster"
	shell_right_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_right_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster_title := Label.new()
	roster_title.text = "—— 存活名册 ——"
	shell_right_root.add_child(roster_title)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster_wrap := VBoxContainer.new()
	roster_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if roster_container:
		roster_container.reparent(roster_wrap)
	roster_scroll.add_child(roster_wrap)
	shell_right_root.add_child(roster_scroll)
	var bag_hint := Label.new()
	bag_hint.name = "BagPlaceholder"
	bag_hint.text = "大营背包 · %d/%d 件 (网格预览 T-05)" % [
		GameManager.inventory.size(), GameManager.get_inventory_capacity()
	]
	bag_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bag_hint.add_theme_font_size_override("font_size", 11)
	bag_hint.modulate = Color(0.55, 0.65, 0.8)
	shell_right_root.add_child(bag_hint)
	right_slot.add_child(shell_right_root)
	if logistics_buildings:
		if buildings_container:
			buildings_container.reparent(logistics_buildings)
		_reparent_logistics_upgrade_buttons(logistics_buildings)
	if logistics_recruit:
		_reparent_logistics_recruit(logistics_recruit)
	if logistics_dead:
		var dead_title := content.get_node_or_null("DeadTitle") as Control
		if dead_title:
			dead_title.reparent(logistics_dead)
		if dead_roster_container:
			dead_roster_container.reparent(logistics_dead)
	_hide_duplicate_logistics_actions()
	visible = false


func _reparent_logistics_upgrade_buttons(tab: VBoxContainer) -> void:
	if action_buttons == null:
		return
	for node_name in ["UpgradeBarracks", "UpgradeForge", "UpgradeInfirmary", "UpgradeWarehouse"]:
		var btn := action_buttons.get_node_or_null(node_name) as Button
		if btn:
			btn.custom_minimum_size = Vector2(0, 36)
			btn.reparent(tab)


func _reparent_logistics_recruit(tab: VBoxContainer) -> void:
	if action_buttons == null:
		return
	for node_name in ["RecruitNormal", "RecruitElite"]:
		var btn := action_buttons.get_node_or_null(node_name) as Button
		if btn:
			btn.custom_minimum_size = Vector2(0, 36)
			btn.reparent(tab)
	if _auto_run_check:
		_auto_run_check.reparent(tab)


func _hide_duplicate_logistics_actions() -> void:
	if action_buttons == null:
		return
	for node_name in ["ExploreBtn", "EquipmentBtn"]:
		var btn := action_buttons.get_node_or_null(node_name) as Control
		if btn:
			btn.visible = false
	if _redeploy_btn:
		_redeploy_btn.visible = false


func scroll_maps_list_to_top() -> void:
	if _maps_scroll:
		_maps_scroll.scroll_vertical = 0


func scroll_formation_into_view() -> void:
	if _form_scroll:
		_form_scroll.scroll_vertical = 0


func highlight_selected_map_card(duration: float = 2.0) -> void:
	scroll_maps_list_to_top()
	if maps_list == null:
		return
	for child in maps_list.get_children():
		_pulse_card_in_tree(child, duration)


func _pulse_card_in_tree(node: Node, duration: float) -> void:
	if node is MapCardButton:
		var card := node as MapCardButton
		if card.map_id == GameManager.selected_map_id:
			card.pulse_outline(duration)
	elif node is VBoxContainer:
		for c in node.get_children():
			_pulse_card_in_tree(c, duration)


func bind_main_shell(shell: MainShell) -> void:
	_main_shell = shell


func _user_feedback(text: String, color: Color = Color(0.85, 0.95, 1.0), duration: float = 4.0) -> void:
	if text == "":
		return
	if _main_shell and _main_shell.has_method("show_toast"):
		_main_shell.show_toast(text, color, duration)
	elif status_label:
		status_label.text = text
		status_label.modulate = color


func _dock_hint(text: String) -> void:
	if _main_shell and _main_shell.has_method("show_dock_hint"):
		_main_shell.show_dock_hint(text)
	elif status_label:
		status_label.text = text


func _ensure_auto_run_toggle() -> void:
	if _auto_run_check or action_buttons == null:
		return
	_auto_run_check = CheckButton.new()
	_auto_run_check.text = "自动连续出征"
	_auto_run_check.tooltip_text = "开启后：点地图即全选出发；遇敌即战；结算后自动再出征"
	_auto_run_check.toggled.connect(_on_auto_run_toggled)
	action_buttons.add_child(_auto_run_check)
	action_buttons.move_child(_auto_run_check, 0)


func _ensure_redeploy_button() -> void:
	if _redeploy_btn or action_buttons == null:
		return
	_redeploy_btn = Button.new()
	_redeploy_btn.text = "再战上次地图"
	_redeploy_btn.tooltip_text = "按上次选择的地图与编队快照立即出征（不进准备界面）"
	_redeploy_btn.pressed.connect(_on_redeploy_base_pressed)
	action_buttons.add_child(_redeploy_btn)
	action_buttons.move_child(_redeploy_btn, 1)


func _on_redeploy_base_pressed() -> void:
	var code: int = GameManager.redeploy_same_map()
	if code != 0:
		_user_feedback(GameManager.get_run_start_error_message(code), Color.ORANGE_RED)


func _on_auto_run_toggled(enabled: bool) -> void:
	GameManager.auto_run_preferred = enabled
	if not enabled:
		GameManager.stop_auto_run()


func _on_run_start_failed(code: int) -> void:
	_user_feedback(GameManager.get_run_start_error_message(code), Color.ORANGE_RED)


func _update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = "金币: %d" % amount


func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.BASE:
		_refresh()


func _refresh() -> void:
	if shell_right_root:
		var bag := shell_right_root.get_node_or_null("BagPlaceholder") as Label
		if bag:
			bag.text = "大营背包 · %d/%d 件 (网格预览 T-05)" % [
				GameManager.inventory.size(), GameManager.get_inventory_capacity()
			]
	if gold_label:
		var st: int = GameManager.get_team_stability()
		var st_text := ""
		if st < StabilitySystem.MAX_STABILITY:
			st_text = " | 团队稳定度: %d (回城恢复)" % st
		gold_label.text = "金币: %d%s" % [GameManager.gold, st_text]
	if _auto_run_check:
		_auto_run_check.set_block_signals(true)
		_auto_run_check.button_pressed = GameManager.auto_run_preferred
		_auto_run_check.set_block_signals(false)
	if _redeploy_btn:
		var can: bool = (
			not GameManager.is_recovery_lock_active()
			and GameManager.is_map_unlocked(GameManager.selected_map_id)
			and SquadFormationService.pick_deploy_half(GameManager) != ""
		)
		_redeploy_btn.disabled = not can
		var md: Dictionary = DataLoader.map_data(GameManager.selected_map_id)
		_redeploy_btn.text = "再战·%s" % str(md.get("name", GameManager.selected_map_id))
	
	_refresh_status_line()
	if _formation_ui and _formation_ui.has_method("_refresh"):
		_formation_ui._refresh()
	_refresh_maps_panel()
	_refresh_buildings()
	_refresh_roster()
	_refresh_dead_roster()
	_append_infirmary_status()


func _refresh_status_line() -> void:
	var parts: Array[String] = []
	if not GameManager.last_run_level_up_log.is_empty():
		parts.append("[升级] " + ", ".join(GameManager.last_run_level_up_log))
		GameManager.last_run_level_up_log.clear()
	if not GameManager.last_run_map_unlock_log.is_empty():
		parts.append("[新地图] " + ", ".join(GameManager.last_run_map_unlock_log))
		GameManager.last_run_map_unlock_log.clear()
	if GameManager.last_run_stability_note != "":
		parts.append("[稳定度] " + GameManager.last_run_stability_note)
		GameManager.last_run_stability_note = ""
	if not GameManager.last_run_loot_log.is_empty():
		var loot_n: int = GameManager.last_run_loot_log.size()
		if loot_n <= 3:
			parts.append("[掉落] " + ", ".join(GameManager.last_run_loot_log))
		else:
			parts.append("[掉落] %d 件装备 (背包共 %d 件)" % [loot_n, GameManager.inventory.size()])
		GameManager.last_run_loot_log.clear()
	if parts.is_empty():
		return
	var color := Color.CYAN
	if GameManager.is_recovery_lock_active():
		color = Color.ORANGE_RED
	_user_feedback(" | ".join(parts), color)


func _refresh_buildings() -> void:
	for child in buildings_container.get_children():
		child.queue_free()
	
	var all_data = DataLoader.all_building_data()
	for bdata in all_data:
		var bid = bdata.building_id
		var lv = GameManager.get_building_level(bid)
		var max_lv = bdata.max_level
		var label = Label.new()
		label.custom_minimum_size = Vector2(0, 24)
		
		var cost_str = ""
		if lv < max_lv:
			var cost = bdata.upgrade_costs.gold[lv]
			cost_str = "  升级: %d金币" % cost
		else:
			cost_str = "  (已满级)"
		
		label.text = "%s Lv.%d/%d%s" % [bdata.name, lv, max_lv, cost_str]
		buildings_container.add_child(label)


func _refresh_roster() -> void:
	for child in roster_container.get_children():
		child.queue_free()
	
	var player = GameManager.player
	if player and player.is_alive:
		_add_alive_row("[主角]", player, "", player.merc_id)
	
	for e in GameManager.elite_roster:
		if e.is_alive:
			_add_alive_row("[精英]", e, "elite", e.merc_id)
	
	for n in GameManager.normal_roster:
		if n.is_alive:
			_add_alive_row("[佣兵]", n, "normal", n.merc_id)
	
func _append_infirmary_status() -> void:
	var resting := _count_resting_mercs()
	if resting <= 0:
		return
	var heal_pct: int = int(RosterHealth.BASE_HEAL_RATIO_PER_TICK * GameManager.get_infirmary_heal_speed_multiplier() * 100.0)
	var line := "医疗室：%d 人休整中（约 %d%% 最大生命/秒）" % [resting, heal_pct]
	if _shell_attached:
		_dock_hint(line)
	else:
		_user_feedback(line, Color(0.75, 0.9, 1.0))


func _refresh_dead_roster() -> void:
	if not dead_roster_container:
		return
	for child in dead_roster_container.get_children():
		child.queue_free()
	
	var has_dead := false
	var player = GameManager.player
	if player and not player.is_alive:
		has_dead = true
		_add_dead_row("[主角]", player, "player", player.merc_id)
	for e in GameManager.elite_roster:
		if not e.is_alive:
			has_dead = true
			_add_dead_row("[精英]", e, "elite", e.merc_id)
	for n in GameManager.normal_roster:
		if not n.is_alive:
			has_dead = true
			_add_dead_row("[佣兵]", n, "normal", n.merc_id)
	
	if not has_dead:
		var hint := Label.new()
		hint.text = "（无阵亡单位）"
		hint.modulate = Color.GRAY
		dead_roster_container.add_child(hint)


func _add_alive_row(tag: String, merc: Mercenary, merc_type: String, merc_id: String) -> void:
	var max_hp := StatResolver.get_max_hp(merc)
	var atk := StatResolver.get_patk(merc)
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var extra := ""
	if merc.is_mia:
		extra = " [战场遗留·不可出征]"
	elif merc.is_near_death:
		extra = " [濒死·需在大营休养至满血]"
	elif merc.is_personal_break or not merc.is_personal_stability_ok():
		extra = " [个人稳定度不足]"
	elif merc.is_retreated:
		extra = " [休整·满血后可出征]"
	elif merc.current_hp < max_hp:
		extra = " [负伤]"
	if merc.scar_stacks > 0:
		var scar_fx: String = merc.get_scar_effect_summary()
		extra += " 伤痕×%d" % merc.scar_stacks
		if scar_fx != "":
			extra += " (%s)" % scar_fx
	label.text = "%s %s %s HP:%d/%d 个人稳:%d ATK:%d%s" % [
		tag, merc.merc_name, _level_exp_text(merc), merc.current_hp, max_hp, merc.personal_stability, atk, extra
	]
	if merc.is_mia:
		label.modulate = Color(0.5, 0.52, 0.58)
	elif merc.is_near_death:
		label.modulate = Color(1.0, 0.45, 0.45)
	elif merc.is_personal_break or not merc.is_personal_stability_ok():
		label.modulate = Color.GOLD
	elif merc.is_retreated:
		label.modulate = Color.GOLD
	elif merc.current_hp < max_hp:
		label.modulate = Color(1.0, 0.85, 0.7)
	else:
		label.modulate = Color.WHITE
	row.add_child(label)
	if merc == GameManager.player:
		var equip_btn := Button.new()
		equip_btn.text = "装备"
		equip_btn.custom_minimum_size = Vector2(48, 24)
		equip_btn.pressed.connect(_on_player_equip_pressed)
		row.add_child(equip_btn)
	if merc.scar_stacks > 0:
		var scar_btn := Button.new()
		scar_btn.text = "消伤×%d" % merc.scar_stacks
		scar_btn.tooltip_text = "医疗室清除伤痕（%d 金币）" % GameManager.get_scar_treatment_cost(merc)
		scar_btn.custom_minimum_size = Vector2(72, 24)
		scar_btn.pressed.connect(_on_treat_scars_pressed.bind(merc_id))
		row.add_child(scar_btn)
	if merc_type != "" and merc_type != "player" and not merc.is_mia:
		var btn := Button.new()
		btn.text = "解雇"
		btn.custom_minimum_size = Vector2(48, 24)
		btn.set_meta("merc_type", merc_type)
		btn.set_meta("merc_id", merc_id)
		btn.pressed.connect(_on_dismiss_pressed.bind(btn))
		row.add_child(btn)
	roster_container.add_child(row)


func _on_player_equip_pressed() -> void:
	open_equipment_for(GameManager.player)


func _count_resting_mercs() -> int:
	var n := 0
	for m in GameManager._all_roster_mercs():
		if not m.is_alive:
			continue
		if m.is_near_death or m.is_retreated or m.is_personal_break:
			n += 1
			continue
		var max_hp: int = StatResolver.get_max_hp(m)
		if m.current_hp < max_hp:
			n += 1
	return n


func _add_dead_row(tag: String, merc: Mercenary, merc_type: String, merc_id: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cost := GameManager.get_revive_cost(merc)
	label.text = "%s %s %s [阵亡] 复活:%dg" % [tag, merc.merc_name, _level_exp_text(merc), cost]
	label.modulate = Color.DIM_GRAY
	row.add_child(label)
	var btn := Button.new()
	btn.text = "复活"
	btn.custom_minimum_size = Vector2(52, 24)
	btn.pressed.connect(_on_revive_pressed.bind(merc_type, merc_id))
	row.add_child(btn)
	dead_roster_container.add_child(row)


func _level_exp_text(merc: Mercenary) -> String:
	if merc.level >= merc.max_level:
		return "Lv.%d MAX" % merc.level
	var need := ExpSystem.exp_required_for_next_level(merc.level)
	return "Lv.%d (%d/%d)" % [merc.level, merc.exp, need]


func _on_revive_pressed(merc_type: String, merc_id: String) -> void:
	var code := GameManager.revive_mercenary(merc_type, merc_id)
	match code:
		0:
			_user_feedback("[复活] 已恢复存活（30%% HP）", Color.GREEN)
		-1:
			_user_feedback("[复活] 该单位无需复活", Color.YELLOW)
		-2:
			_user_feedback("[复活失败] 金币不足", Color.RED)
	_refresh()


func _on_treat_scars_pressed(merc_id: String) -> void:
	var code: int = GameManager.treat_mercenary_scars(merc_id)
	match code:
		0:
			_user_feedback("已清除伤痕", Color.GREEN)
		-2:
			_user_feedback("该单位无伤痕", Color.YELLOW)
		-3:
			_user_feedback("金币不足，无法消伤痕", Color.ORANGE_RED)
		_:
			_user_feedback("消伤痕失败", Color.ORANGE_RED)
	_refresh()


func _on_dismiss_pressed(btn: Button) -> void:
	var merc_type: String = btn.get_meta("merc_type", "")
	var merc_id: String = btn.get_meta("merc_id", "")
	GameManager.dismiss_merc(merc_type, merc_id)
	_user_feedback("[解雇] 已解雇佣兵", Color.YELLOW)
	_refresh()


func _on_upgrade_pressed(building_id: String) -> void:
	GameManager.upgrade_building(building_id)
	_refresh()


func _refresh_maps_panel() -> void:
	if maps_list == null:
		return
	GameManager.sync_always_unlocked_maps()
	GameManager.refresh_map_unlocks()
	for child in maps_list.get_children():
		child.queue_free()

	var base_lv: int = GameManager.get_unlock_level()
	var prod_maps: Array = []
	var test_maps: Array = []
	for m in GameManager.get_all_maps_sorted():
		if TestScenarioService.is_test_map(m):
			test_maps.append(m)
		else:
			prod_maps.append(m)

	var prod_title := Label.new()
	prod_title.text = "正式地图"
	prod_title.add_theme_font_size_override("font_size", 12)
	prod_title.modulate = Color(0.75, 0.85, 0.95)
	maps_list.add_child(prod_title)

	var prod_box := VBoxContainer.new()
	prod_box.add_theme_constant_override("separation", 2)
	maps_list.add_child(prod_box)
	for m in prod_maps:
		_add_map_card(prod_box, m)

	if not test_maps.is_empty():
		test_maps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("test_priority", 99)) < int(b.get("test_priority", 99))
		)
		var qa_wrap := VBoxContainer.new()
		qa_wrap.add_theme_constant_override("separation", 2)
		maps_list.add_child(qa_wrap)
		var toggle := Button.new()
		toggle.flat = true
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var arrow := "▶" if not _test_maps_expanded else "▼"
		toggle.text = "%s QA 测试 (%d)" % [arrow, test_maps.size()]
		toggle.add_theme_font_size_override("font_size", 12)
		toggle.modulate = Color(0.65, 0.75, 0.88)
		var test_box := VBoxContainer.new()
		test_box.visible = _test_maps_expanded
		test_box.add_theme_constant_override("separation", 2)
		toggle.pressed.connect(func() -> void:
			_test_maps_expanded = not _test_maps_expanded
			test_box.visible = _test_maps_expanded
			toggle.text = ("%s QA 测试 (%d)" % ["▼" if _test_maps_expanded else "▶", test_maps.size()])
		)
		qa_wrap.add_child(toggle)
		qa_wrap.add_child(test_box)
		for m in test_maps:
			_add_map_card(test_box, m)

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 10)
	hint.text = "基地总等级 %d | 击败上一区域 Boss 解锁下一图" % base_lv
	hint.modulate = Color.DIM_GRAY
	maps_list.add_child(hint)


func _add_map_card(parent: VBoxContainer, m: Dictionary) -> void:
	var map_id: String = str(m.get("map_id", ""))
	if map_id == "":
		return
	var unlocked: bool = GameManager.is_map_unlocked(map_id)
	var test_map: bool = TestScenarioService.is_test_map(m)
	var recovery_lock: bool = GameManager.is_recovery_lock_active()
	var locked_prod: bool = recovery_lock and not test_map and unlocked
	var selected: bool = map_id == GameManager.selected_map_id
	var card := MapCardButton.new()
	card.setup(m, selected, locked_prod, unlocked)
	card.card_selected.connect(_on_map_card_selected)
	card.deploy_pressed.connect(_on_map_deploy)
	parent.add_child(card)


func _on_map_card_selected(map_id: String) -> void:
	if not GameManager.is_map_unlocked(map_id):
		return
	GameManager.selected_map_id = map_id
	_refresh_maps_panel()
	if _main_shell:
		_main_shell.apply_state(GameManager.state)


func _on_map_deploy(map_id: String) -> void:
	GameManager.start_prepare(map_id)


func _on_explore_pressed() -> void:
	GameManager.start_prepare("grassland")


func _on_equipment_pressed() -> void:
	open_equipment_for(GameManager.player)


func open_equipment_for(merc: Mercenary) -> void:
	if _equipment_ui and _equipment_ui.has_method("open_panel_for_merc"):
		_equipment_ui.open_panel_for_merc(merc)


## 显示招募结果反馈。code: 0=成功, -1=金币不足, -2=槽位满, -3=无模板
func show_recruit_result(merc_type: String, code: int) -> void:
	match code:
		0:
			_user_feedback("[招募] 获得新%s佣兵！" % ("精英" if merc_type == "elite" else ""), Color.GREEN)
		-1:
			_user_feedback("[招募失败] 金币不足", Color.RED)
		-2:
			_user_feedback("[招募失败] 槽位已满，请升级佣兵大厅", Color.RED)
		-3:
			_user_feedback("[招募失败] 暂无可用模板", Color.RED)
		_:
			_user_feedback("[招募失败] 未知错误(%d)" % code, Color.RED)
