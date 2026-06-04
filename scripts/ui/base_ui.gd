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


func _ready() -> void:
	_equipment_ui = get_parent().get_node_or_null("EquipmentUI")
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
	_refresh()


func _on_roster_healed() -> void:
	if visible:
		_refresh()


func _on_squad_stability_changed(_value: int) -> void:
	if visible:
		_refresh()


func _ensure_auto_run_toggle() -> void:
	if _auto_run_check or action_buttons == null:
		return
	_auto_run_check = CheckButton.new()
	_auto_run_check.text = "自动连续出征"
	_auto_run_check.tooltip_text = "开启后：点地图即全选出发；遇敌即战；结算后自动再出征"
	_auto_run_check.toggled.connect(_on_auto_run_toggled)
	action_buttons.add_child(_auto_run_check)
	action_buttons.move_child(_auto_run_check, 0)


func _on_auto_run_toggled(enabled: bool) -> void:
	GameManager.auto_run_preferred = enabled
	if not enabled:
		GameManager.stop_auto_run()


func _on_run_start_failed(code: int) -> void:
	if status_label:
		status_label.text = GameManager.get_run_start_error_message(code)
		status_label.modulate = Color.ORANGE_RED


func _update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = "金币: %d" % amount


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.BASE)
	if visible:
		_refresh()


func _refresh() -> void:
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
	
	_show_run_return_notice()
	_refresh_maps_panel()
	_refresh_buildings()
	_refresh_roster()
	_refresh_dead_roster()
	_append_infirmary_status()


func _show_run_return_notice() -> void:
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
	if parts.is_empty() or status_label == null:
		return
	status_label.text = "  ".join(parts)
	status_label.modulate = Color.CYAN


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
		_add_alive_row("[主角]", player, "", "player")
	
	for e in GameManager.elite_roster:
		if e.is_alive:
			_add_alive_row("[精英]", e, "elite", e.merc_id)
	
	for n in GameManager.normal_roster:
		if n.is_alive:
			_add_alive_row("[佣兵]", n, "normal", n.merc_id)
	
func _append_infirmary_status() -> void:
	if status_label == null:
		return
	var resting := _count_resting_mercs()
	if resting <= 0:
		return
	var heal_pct: int = int(RosterHealth.BASE_HEAL_RATIO_PER_TICK * GameManager.get_infirmary_heal_speed_multiplier() * 100.0)
	var line := "医疗室：%d 人休整中（约 %d%% 最大生命/秒，满血后可再出征）" % [resting, heal_pct]
	if status_label.text.is_empty():
		status_label.text = line
		status_label.modulate = Color(0.75, 0.9, 1.0)
	else:
		status_label.text += "  |  " + line


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
	if merc.is_near_death:
		extra = " [濒死·需在大营休养至满血]"
	elif merc.is_personal_break or not merc.is_personal_stability_ok():
		extra = " [个人稳定度不足]"
	elif merc.is_retreated:
		extra = " [休整·满血后可出征]"
	elif merc.current_hp < max_hp:
		extra = " [负伤]"
	label.text = "%s %s %s HP:%d/%d 个人稳:%d ATK:%d%s" % [
		tag, merc.merc_name, _level_exp_text(merc), merc.current_hp, max_hp, merc.personal_stability, atk, extra
	]
	if merc.is_near_death:
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
	if merc_type != "" and merc_type != "player":
		var btn := Button.new()
		btn.text = "解雇"
		btn.custom_minimum_size = Vector2(48, 24)
		btn.set_meta("merc_type", merc_type)
		btn.set_meta("merc_id", merc_id)
		btn.pressed.connect(_on_dismiss_pressed.bind(btn))
		row.add_child(btn)
	roster_container.add_child(row)


func _count_resting_mercs() -> int:
	var n := 0
	for m in GameManager.elite_roster:
		if m.is_alive and m.is_retreated:
			n += 1
	for m in GameManager.normal_roster:
		if m.is_alive and m.is_retreated:
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
			status_label.text = "[复活] 已恢复存活（30%% HP）"
			status_label.modulate = Color.GREEN
		-1:
			status_label.text = "[复活] 该单位无需复活"
			status_label.modulate = Color.YELLOW
		-2:
			status_label.text = "[复活失败] 金币不足"
			status_label.modulate = Color.RED
	_refresh()


func _on_dismiss_pressed(btn: Button) -> void:
	var merc_type: String = btn.get_meta("merc_type", "")
	var merc_id: String = btn.get_meta("merc_id", "")
	GameManager.dismiss_merc(merc_type, merc_id)
	status_label.text = "[解雇] 已解雇佣兵"
	status_label.modulate = Color.YELLOW
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
	for m in GameManager.get_all_maps_sorted():
		var map_id: String = str(m.get("map_id", ""))
		if map_id == "":
			continue
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 32)
		
		var name: String = str(m.get("name", map_id))
		var danger: int = int(m.get("danger_level", 1))
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if GameManager.is_map_unlocked(map_id):
			btn.text = "%s  危险%d  [已解锁]" % [name, danger]
			if danger >= 8:
				btn.text = "%s  [极难]" % name
			btn.pressed.connect(_on_map_selected.bind(map_id))
		else:
			btn.text = "%s  🔒" % name
			btn.disabled = true
			var reason: String = GameManager.get_map_lock_reason(map_id)
			btn.tooltip_text = reason
			btn.modulate = Color(0.55, 0.55, 0.55)
		
		var desc: String = str(m.get("description", ""))
		if desc != "" and GameManager.is_map_unlocked(map_id):
			btn.tooltip_text = desc
		
		row.add_child(btn)
		
		var info := Label.new()
		info.custom_minimum_size = Vector2(72, 0)
		info.add_theme_font_size_override("font_size", 10)
		if GameManager.is_map_unlocked(map_id):
			info.text = "Boss %.0fm" % float(m.get("boss_distance", 600))
		else:
			info.text = "Lv.%d" % int(m.get("unlock_base_level", 1))
		info.modulate = Color.DIM_GRAY
		row.add_child(info)
		
		maps_list.add_child(row)
	
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 11)
	hint.text = "基地总等级 %d（各建筑等级之和）| 击败上一区域 Boss 解锁下一图" % base_lv
	hint.modulate = Color.DIM_GRAY
	maps_list.add_child(hint)


func _on_map_selected(map_id: String) -> void:
	GameManager.start_prepare(map_id)


func _on_explore_pressed() -> void:
	GameManager.start_prepare("grassland")


func _on_equipment_pressed() -> void:
	if _equipment_ui and _equipment_ui.has_method("open_panel"):
		_equipment_ui.open_panel()


## 显示招募结果反馈。code: 0=成功, -1=金币不足, -2=槽位满, -3=无模板
func show_recruit_result(merc_type: String, code: int) -> void:
	if not status_label:
		return
	match code:
		0:
			status_label.text = "[招募] 获得新%s佣兵！" % ("精英" if merc_type == "elite" else "")
			status_label.modulate = Color.GREEN
		-1:
			status_label.text = "[招募失败] 金币不足"
			status_label.modulate = Color.RED
		-2:
			status_label.text = "[招募失败] 槽位已满，请升级佣兵大厅"
			status_label.modulate = Color.RED
		-3:
			status_label.text = "[招募失败] 暂无可用模板"
			status_label.modulate = Color.RED
		_:
			status_label.text = "[招募失败] 未知错误(%d)" % code
			status_label.modulate = Color.RED
