extends Control
## BaseUI — 基地主界面

const _BaseCampBagUIScene = preload("res://scripts/ui/base_camp_bag_ui.gd")
const FORMATION_UI_LAYOUT_REV := 9  ## 与 formation_ui.gd LAYOUT_REV 同步

@onready var gold_label: Label = $MarginContainer/MainVBox/GoldLabel
@onready var maps_list: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/MapsList
@onready var buildings_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Buildings
@onready var roster_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Roster
@onready var dead_roster_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/DeadRoster
var rest_roster_container: VBoxContainer = null
var mia_roster_container: VBoxContainer = null
@onready var action_buttons: HFlowContainer = $MarginContainer/MainVBox/Actions
@onready var status_label: Label = $MarginContainer/MainVBox/StatusLabel
@onready var equipment_button: Button = $MarginContainer/MainVBox/Actions/EquipmentBtn

var _equipment_ui: Control = null
var _auto_run_check: CheckButton = null
var _formation_ui: VBoxContainer = null
var shell_left_root: Control = null
var shell_center_root: Control = null
var shell_right_root: Control = null
var _shell_attached: bool = false
var _main_shell: MainShell = null
var _test_maps_expanded: bool = false
var _maps_scroll: ScrollContainer = null
var _camp_bag_ui: Control = null


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
	GameManager.formation_changed.connect(_on_formation_layout_refresh)
	GameManager.run_start_failed.connect(_on_run_start_failed)
	GameManager.deploy_half_reassigned.connect(_on_deploy_half_reassigned)
	_ensure_auto_run_toggle()
	_ensure_legacy_roster_sections()
	schedule_refresh()


func _on_roster_healed() -> void:
	if GameManager.state != GameManager.GameState.BASE:
		return
	_refresh_roster()
	_append_infirmary_status()


func schedule_refresh(include_formation: bool = true) -> void:
	call_deferred("_refresh", include_formation)


func _on_formation_layout_refresh() -> void:
	if GameManager.state != GameManager.GameState.BASE:
		return
	_refresh_roster()


func ensure_formation_in(host: Control) -> VBoxContainer:
	var script_res: Script = load("res://scripts/ui/formation_ui.gd")
	if script_res == null or host == null:
		return null
	if _formation_ui and is_instance_valid(_formation_ui):
		var rev: int = int(_formation_ui.get_meta("layout_rev", -1)) if _formation_ui.has_meta("layout_rev") else -1
		if rev == FORMATION_UI_LAYOUT_REV:
			if _formation_ui.get_parent() != host:
				_formation_ui.reparent(host)
			return _formation_ui
		_formation_ui.queue_free()
		_formation_ui = null
	_formation_ui = VBoxContainer.new()
	_formation_ui.set_script(script_res)
	_formation_ui.name = "FormationPanel"
	_formation_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation_ui.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	var center_scroll := ScrollContainer.new()
	center_scroll.name = "BaseCenterScroll"
	center_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_slot.add_child(center_scroll)
	shell_center_root = VBoxContainer.new()
	shell_center_root.name = "BaseCenterFormation"
	shell_center_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_center_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	center_scroll.add_child(shell_center_root)
	var form_host := VBoxContainer.new()
	form_host.name = "FormationHost"
	form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell_center_root.add_child(form_host)
	ensure_formation_in(form_host)
	shell_right_root = VBoxContainer.new()
	shell_right_root.name = "BaseRightRoster"
	shell_right_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_right_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster_title := Label.new()
	roster_title.text = "—— 名册（可编入备战席；出征须满足条件）——"
	shell_right_root.add_child(roster_title)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster_wrap := VBoxContainer.new()
	roster_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if roster_container:
		roster_container.reparent(roster_wrap)
	roster_scroll.add_child(roster_wrap)
	shell_right_root.add_child(roster_scroll)
	var rest_block: Dictionary = _make_roster_section("—— 养伤名册 ——")
	rest_roster_container = rest_block.container
	shell_right_root.add_child(rest_block.root)
	var mia_block: Dictionary = _make_roster_section("—— 战场遗留 ——")
	mia_roster_container = mia_block.container
	shell_right_root.add_child(mia_block.root)
	var bag_scroll := ScrollContainer.new()
	bag_scroll.name = "CampBagScroll"
	bag_scroll.custom_minimum_size = Vector2(0, 140)
	bag_scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_camp_bag_ui = _BaseCampBagUIScene.new()
	_camp_bag_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _camp_bag_ui.has_method("bind_open_equipment"):
		_camp_bag_ui.bind_open_equipment(_on_equipment_pressed)
	bag_scroll.add_child(_camp_bag_ui)
	shell_right_root.add_child(bag_scroll)
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
func scroll_maps_list_to_top() -> void:
	if _maps_scroll:
		_maps_scroll.scroll_vertical = 0


func scroll_formation_into_view(pulse_sec: float = 0.0) -> void:
	if _formation_ui and _formation_ui.has_method("scroll_pool_into_view"):
		_formation_ui.scroll_pool_into_view()
	if pulse_sec > 0.0 and _formation_ui:
		if _formation_ui.has_method("pulse_formation_focus"):
			_formation_ui.pulse_formation_focus(pulse_sec * 0.6)
		if _formation_ui.has_method("pulse_pool_focus"):
			_formation_ui.pulse_pool_focus(pulse_sec)


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


func refresh_from_shell() -> void:
	if GameManager.state == GameManager.GameState.BASE:
		_refresh()


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
	_auto_run_check.tooltip_text = "开启后：卡片「出征」或 Dock「出征」将跳过准备页直接进 RUNNING"
	_auto_run_check.toggled.connect(_on_auto_run_toggled)
	action_buttons.add_child(_auto_run_check)
	action_buttons.move_child(_auto_run_check, 0)


func _on_auto_run_toggled(enabled: bool) -> void:
	GameManager.auto_run_preferred = enabled
	if not enabled:
		GameManager.stop_auto_run()


func _on_run_start_failed(code: int) -> void:
	_user_feedback(GameManager.get_run_start_error_message(code), Color.ORANGE_RED)


func _on_deploy_half_reassigned(preferred: String, actual: String) -> void:
	_user_feedback(
		"编组优先半组 %s 不可出征，本趟改派半组 %s" % [preferred, actual],
		Color(1.0, 0.85, 0.55),
	)


func _update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = "金币: %d" % amount


func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.BASE:
		_refresh()


func _refresh(include_formation: bool = true) -> void:
	if _camp_bag_ui and _camp_bag_ui.has_method("refresh"):
		_camp_bag_ui.refresh()
	if gold_label:
		gold_label.text = "金币: %d" % GameManager.gold
	if _auto_run_check:
		_auto_run_check.set_block_signals(true)
		_auto_run_check.button_pressed = GameManager.auto_run_preferred
		_auto_run_check.set_block_signals(false)
	_refresh_status_line()
	if include_formation and _formation_ui and _formation_ui.has_method("_schedule_refresh"):
		_formation_ui._schedule_refresh()
	elif include_formation and _formation_ui and _formation_ui.has_method("_refresh"):
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


func _make_roster_section(title_text: String) -> Dictionary:
	var root := VBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	root.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 56)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrap)
	root.add_child(scroll)
	return {"root": root, "container": wrap, "scroll": scroll}


func _ensure_legacy_roster_sections() -> void:
	if _shell_attached or mia_roster_container != null:
		return
	var content := get_node_or_null("MarginContainer/MainVBox/Scroll/Content") as VBoxContainer
	if content == null:
		return
	var dead_title := content.get_node_or_null("DeadTitle")
	var roster_title := Label.new()
	roster_title.text = "—— 名册（可编入备战席；出征须满足条件）——"
	content.add_child(roster_title)
	if roster_container:
		content.move_child(roster_title, roster_container.get_index())
	var rest_block: Dictionary = _make_roster_section("—— 养伤名册 ——")
	rest_roster_container = rest_block.container
	content.add_child(rest_block.root)
	if dead_title:
		content.move_child(rest_block.root, dead_title.get_index())
	var mia_block: Dictionary = _make_roster_section("—— 战场遗留 ——")
	mia_roster_container = mia_block.container
	content.add_child(mia_block.root)
	if dead_title:
		content.move_child(mia_block.root, dead_title.get_index())


func _clear_roster_container(container: VBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _merc_needs_rest(merc: Mercenary) -> bool:
	if merc == null or merc.is_test_stand_in or not merc.is_alive or merc.is_mia:
		return false
	if merc.is_near_death or merc.is_retreated or merc.is_personal_break:
		return true
	if not merc.is_personal_stability_ok():
		return true
	return merc.current_hp < StatResolver.get_max_hp(merc)


func _roster_section_for(merc: Mercenary) -> String:
	if merc.is_mia:
		return "mia"
	if merc.is_test_stand_in:
		return "active"
	if _merc_needs_rest(merc):
		return "rest"
	return "active"


func _roster_container_for(section: String) -> VBoxContainer:
	match section:
		"mia":
			return mia_roster_container if mia_roster_container else roster_container
		"rest":
			return rest_roster_container if rest_roster_container else roster_container
		_:
			return roster_container


func _refresh_roster() -> void:
	_clear_roster_container(roster_container)
	_clear_roster_container(rest_roster_container)
	_clear_roster_container(mia_roster_container)
	var counts := {"active": 0, "rest": 0, "mia": 0}
	var player = GameManager.player
	if player and player.is_alive:
		var sec_p := _roster_section_for(player)
		_add_roster_row("[主角]", player, "", player.merc_id, sec_p)
		counts[sec_p] = int(counts[sec_p]) + 1
	for e in GameManager.elite_roster:
		if e.is_alive or e.is_test_stand_in:
			var sec := _roster_section_for(e)
			_add_roster_row("[精英]", e, "elite", e.merc_id, sec)
			counts[sec] = int(counts[sec]) + 1
	for n in GameManager.normal_roster:
		if n.is_alive or n.is_test_stand_in:
			var sec_n := _roster_section_for(n)
			_add_roster_row("[佣兵]", n, "normal", n.merc_id, sec_n)
			counts[sec_n] = int(counts[sec_n]) + 1
	_add_roster_empty_hint(roster_container, "（无可出征单位）", counts.active == 0)
	_add_roster_empty_hint(rest_roster_container, "（无养伤单位）", counts.rest == 0)
	_add_roster_empty_hint(mia_roster_container, "（无战场遗留）", counts.mia == 0)


func _add_roster_empty_hint(container: VBoxContainer, text: String, show: bool) -> void:
	if container == null or not show:
		return
	var hint := Label.new()
	hint.text = text
	hint.modulate = Color.GRAY
	container.add_child(hint)


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
		if not e.is_alive and not e.is_test_stand_in:
			has_dead = true
			_add_dead_row("[精英]", e, "elite", e.merc_id)
	for n in GameManager.normal_roster:
		if not n.is_alive and not n.is_test_stand_in:
			has_dead = true
			_add_dead_row("[佣兵]", n, "normal", n.merc_id)
	
	if not has_dead:
		var hint := Label.new()
		hint.text = "（无阵亡单位）"
		hint.modulate = Color.GRAY
		dead_roster_container.add_child(hint)


func _add_roster_row(tag: String, merc: Mercenary, merc_type: String, merc_id: String, section: String) -> void:
	var max_hp := StatResolver.get_max_hp(merc)
	var atk := StatResolver.get_patk(merc)
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var extra := ""
	match section:
		"active":
			if merc.is_test_stand_in:
				extra = " [测试·锁定]"
		"mia":
			extra = " [遗留]"
		"rest":
			if merc.is_near_death:
				extra = " [濒死·需在大营休养至满血]"
			elif merc.is_personal_break or not merc.is_personal_stability_ok():
				extra = " [个人稳定度不足]"
			elif merc.is_retreated:
				extra = " [休整·满血后可出征]"
			elif merc.current_hp < max_hp:
				extra = " [负伤·医疗室恢复中]"
	if merc.scar_stacks > 0:
		var scar_fx: String = merc.get_scar_effect_summary()
		extra += " 伤痕×%d" % merc.scar_stacks
		if scar_fx != "":
			extra += " (%s)" % scar_fx
	var stab_max: int = merc.get_personal_stability_max()
	label.text = "%s %s %s HP:%d/%d 个人稳:%d/%d ATK:%d%s" % [
		tag, merc.merc_name, _level_exp_text(merc), merc.current_hp, max_hp,
		merc.personal_stability, stab_max, atk, extra
	]
	match section:
		"active":
			if merc.is_test_stand_in:
				label.modulate = Color(0.75, 0.9, 1.0)
			else:
				label.modulate = Color.WHITE
		"mia":
			label.modulate = Color(0.5, 0.52, 0.58)
		"rest":
			if merc.is_near_death:
				label.modulate = Color(1.0, 0.45, 0.45)
			elif merc.is_personal_break or not merc.is_personal_stability_ok():
				label.modulate = Color.GOLD
			elif merc.is_retreated:
				label.modulate = Color.GOLD
			else:
				label.modulate = Color(1.0, 0.85, 0.7)
	row.add_child(label)
	if merc == GameManager.player and section != "mia":
		var equip_btn := Button.new()
		equip_btn.text = "装备"
		equip_btn.custom_minimum_size = Vector2(48, 24)
		equip_btn.pressed.connect(_on_player_equip_pressed)
		row.add_child(equip_btn)
	if merc.scar_stacks > 0 and section != "mia":
		var scar_btn := Button.new()
		scar_btn.text = "消伤×%d" % merc.scar_stacks
		scar_btn.tooltip_text = "医疗室清除伤痕（%d 金币）" % GameManager.get_scar_treatment_cost(merc)
		scar_btn.custom_minimum_size = Vector2(72, 24)
		scar_btn.pressed.connect(_on_treat_scars_pressed.bind(merc_id))
		row.add_child(scar_btn)
	if merc_type != "" and merc_type != "player" and section == "active":
		var btn := Button.new()
		btn.text = "解雇"
		btn.custom_minimum_size = Vector2(48, 24)
		btn.set_meta("merc_type", merc_type)
		btn.set_meta("merc_id", merc_id)
		btn.pressed.connect(_on_dismiss_pressed.bind(btn))
		row.add_child(btn)
	_roster_container_for(section).add_child(row)


func _on_player_equip_pressed() -> void:
	open_equipment_for(GameManager.player)


func _count_resting_mercs() -> int:
	var n := 0
	for m in GameManager._all_roster_mercs():
		if m.is_test_stand_in or not m.is_alive or m.is_mia:
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
	if GameManager.state == GameManager.GameState.BASE:
		if (
			TestScenarioService.should_lock_roster(DataLoader.map_data(map_id))
			and TestScenarioService.should_skip_test_roster_inject(GameManager)
			and _main_shell
			and _main_shell.has_method("show_toast")
		):
			_main_shell.show_toast(
				"已保留存档名册（含阵亡/遗留 fixture），未注入测试编队",
				Color(0.75, 0.88, 1.0),
				3.5
			)
		var injected: bool = TestScenarioService.sync_roster_for_map_selection(GameManager, map_id)
		if injected and _main_shell and _main_shell.has_method("show_toast"):
			var roster: Dictionary = TestRosterLoader.roster_for_map(map_id)
			var hint: String = str(roster.get("display_name", "测试编队"))
			if hint.length() > 48:
				hint = hint.substr(0, 45) + "…"
			_main_shell.show_toast("已注入测试编队 · %s" % hint, Color(0.75, 0.92, 1.0), 4.0)
	_refresh_maps_panel()
	_refresh_roster()
	if _formation_ui and _formation_ui.has_method("_schedule_refresh"):
		_formation_ui._schedule_refresh()
	if _main_shell:
		_main_shell.apply_state(GameManager.state)


func _on_map_deploy(map_id: String) -> void:
	var md: Dictionary = DataLoader.map_data(map_id)
	if (
		str(md.get("test_scenario", "")) == "mia_wipe"
		and TestScenarioService.has_test_mia_casualties(GameManager)
	):
		if _main_shell and _main_shell.has_method("show_toast"):
			_main_shell.show_toast(
				"已有战场遗留：请 F5 后勤 · 回收，勿重复出征灭团",
				Color(1.0, 0.85, 0.55),
				4.5
			)
		return
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
