extends Control
## ResultUI — 出征结算界面（掉落详情 + 对比 + 一键换装）

@onready var result_label: Label = $MarginContainer/MainVBox/ResultLabel
@onready var stats_label: Label = $MarginContainer/MainVBox/StatsLabel
@onready var loot_container: VBoxContainer = $MarginContainer/MainVBox/LootScroll/LootContainer
@onready var equip_all_button: Button = $MarginContainer/MainVBox/EquipAllButton
@onready var return_button: Button = $MarginContainer/MainVBox/ReturnButton
@onready var loot_status_label: Label = $MarginContainer/MainVBox/LootStatusLabel

var _last_result: Dictionary = {}
var _auto_continue_timer: Timer = null
var _stop_auto_button: Button = null


func _ready() -> void:
	GameManager.run_ended.connect(_show_result)
	GameManager.state_changed.connect(_on_state_changed)
	if return_button:
		return_button.pressed.connect(_on_return_pressed)
	if equip_all_button:
		equip_all_button.pressed.connect(_on_equip_all_pressed)
	_setup_auto_continue_timer()
	_setup_stop_auto_button()


func _setup_stop_auto_button() -> void:
	if return_button == null:
		return
	var parent: Node = return_button.get_parent()
	if parent == null:
		return
	_stop_auto_button = Button.new()
	_stop_auto_button.text = "停止自动"
	_stop_auto_button.visible = false
	_stop_auto_button.pressed.connect(_on_stop_auto_pressed)
	parent.add_child(_stop_auto_button)
	parent.move_child(_stop_auto_button, return_button.get_index())


func _setup_auto_continue_timer() -> void:
	_auto_continue_timer = Timer.new()
	_auto_continue_timer.one_shot = true
	_auto_continue_timer.wait_time = 1.5
	_auto_continue_timer.timeout.connect(_on_auto_continue_timeout)
	add_child(_auto_continue_timer)


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.RESULT)


func _show_result(result: Dictionary) -> void:
	if GameManager.state != GameManager.GameState.RESULT:
		return
	visible = true
	_last_result = result
	
	var player_alive: bool = result.get("player_alive", false)
	var forced: bool = result.get("forced_withdraw", false)
	var boss: bool = result.get("boss_defeated", false)
	var success: bool = player_alive and not forced
	
	var title := ""
	if boss:
		title = "Boss讨伐成功!"
	elif not player_alive:
		title = "全军覆没"
	elif forced:
		if result.get("near_death_penalty", false):
			title = "紧急撤离成功·全队濒死"
		elif result.get("completed_retreat", false) and result.get("distance", 0) <= 1.0:
			title = "已安全撤回大营"
		else:
			title = "已撤离"
	elif success:
		title = "安全撤离"
	else:
		title = "出征结束"
	
	if result_label:
		result_label.text = title
	
	if stats_label:
		var lost_on_retreat: int = int(result.get("loot_lost_on_retreat", 0))
		var stats_text := "击杀敌人: %d\n获得金币: %d\n获得经验: %d (队伍每人)\n获得装备: %d件\n行进距离: %.0fm" % [
			result.get("enemies_defeated", 0),
			result.get("total_gold", 0),
			result.get("total_exp", 0),
			result.get("total_loot", []).size(),
			result.get("distance", 0)
		]
		if lost_on_retreat > 0:
			stats_text += "\n返程遗失装备: %d 件" % lost_on_retreat
		if result.get("near_death_penalty", false):
			stats_text += "\n全队濒死（需在大营休养至满血，撤离失败才会阵亡）"
		if GameManager.last_run_stability_note != "":
			stats_text += "\n\n" + GameManager.last_run_stability_note
		var unlocked_maps: Array = result.get("maps_unlocked", [])
		if not unlocked_maps.is_empty():
			var names: Array[String] = []
			for mid in unlocked_maps:
				var md: Dictionary = DataLoader.map_data(str(mid))
				names.append(str(md.get("name", mid)))
			stats_text += "\n\n★ 解锁新地图: %s" % ", ".join(names)
		stats_label.text = stats_text
	
	_refresh_loot(result.get("total_loot", []))
	_update_equip_all_button()
	_maybe_schedule_auto_continue(result)


func _refresh_loot(loot: Array) -> void:
	for child in loot_container.get_children():
		child.queue_free()
	
	if loot.is_empty():
		var label := Label.new()
		label.text = "无掉落"
		loot_container.add_child(label)
		if loot_status_label:
			loot_status_label.text = ""
		return
	
	for item in loot:
		if item == null or not item is Equipment:
			continue
		var eq: Equipment = item as Equipment
		_add_loot_row(eq)
	
	if loot_status_label:
		loot_status_label.text = "提示：换装在返回基地前生效；换下装备仍会计入本次战利品"


func _add_loot_row(item: Equipment) -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 2)
	
	var title := Label.new()
	title.text = "[%s] %s" % [item.quality_name, item.item_name]
	title.modulate = Color(item.get_color()) if item.quality >= 2 else Color.WHITE
	panel.add_child(title)
	
	var stats_line := Label.new()
	stats_line.text = EquipmentCompare.format_stats_line(item)
	stats_line.add_theme_font_size_override("font_size", 12)
	panel.add_child(stats_line)
	
	if item.set_id != "":
		var set_lbl := Label.new()
		set_lbl.text = "套装: %s" % EquipmentSetRegistry.get_set_name(item.set_id)
		set_lbl.add_theme_font_size_override("font_size", 11)
		set_lbl.modulate = Color(0.7, 0.85, 1.0)
		panel.add_child(set_lbl)
	
	if GameManager.player:
		_add_compare_block(panel, item, GameManager.player, "主角")
	for e in GameManager.elite_roster:
		if e.is_alive:
			_add_compare_block(panel, item, e, e.merc_name)
	
	loot_container.add_child(panel)
	
	var sep := HSeparator.new()
	loot_container.add_child(sep)


func _add_compare_block(panel: VBoxContainer, item: Equipment, merc: Mercenary, who: String) -> void:
	var old_item: Equipment = merc.equipment_slots.get(item.slot)
	var row := HBoxContainer.new()
	var cmp := Label.new()
	cmp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmp.text = "%s: %s" % [who, EquipmentCompare.compare_label(item, old_item)]
	cmp.add_theme_font_size_override("font_size", 11)
	if EquipmentCompare.is_upgrade(item, old_item):
		cmp.modulate = Color.GREEN
	else:
		cmp.modulate = Color.DIM_GRAY
	row.add_child(cmp)
	if EquipmentCompare.is_upgrade(item, old_item):
		var equip_btn := Button.new()
		equip_btn.text = "装备"
		equip_btn.pressed.connect(_on_equip_item_pressed.bind(merc, item))
		row.add_child(equip_btn)
	panel.add_child(row)


func _on_equip_item_pressed(merc: Mercenary, item: Equipment) -> void:
	if GameManager.equip_pending_loot(merc, item):
		if loot_status_label:
			loot_status_label.text = "已装备: %s → %s" % [item.item_name, merc.merc_name]
			loot_status_label.modulate = Color.GREEN
		_refresh_loot(GameManager.get_pending_loot())
		_update_equip_all_button()
	else:
		if loot_status_label:
			loot_status_label.text = "装备失败"
			loot_status_label.modulate = Color.RED


func _on_equip_all_pressed() -> void:
	var n: int = GameManager.equip_all_pending_upgrades_for_player()
	if loot_status_label:
		if n > 0:
			loot_status_label.text = "已为装备 %d 件提升装备" % n
			loot_status_label.modulate = Color.GREEN
		else:
			loot_status_label.text = "没有可自动提升的装备"
			loot_status_label.modulate = Color.YELLOW
	_refresh_loot(GameManager.get_pending_loot())
	_update_equip_all_button()


func _update_equip_all_button() -> void:
	if equip_all_button == null:
		return
	var has_upgrade := false
	if GameManager.player:
		for item in GameManager.get_pending_loot():
			if item is Equipment:
				var eq: Equipment = item as Equipment
				var old: Equipment = GameManager.player.equipment_slots.get(eq.slot)
				if EquipmentCompare.is_upgrade(eq, old):
					has_upgrade = true
					break
	equip_all_button.disabled = not has_upgrade
	equip_all_button.visible = GameManager.player != null


func _maybe_schedule_auto_continue(result: Dictionary) -> void:
	if _auto_continue_timer:
		_auto_continue_timer.stop()
	if _stop_auto_button:
		_stop_auto_button.visible = GameManager.auto_run_enabled and GameManager.should_continue_auto_run(result)
	if not GameManager.should_continue_auto_run(result):
		return
	if result_label:
		result_label.text += "\n\n[自动] 1.5秒后回城并再次出征…"
	if _auto_continue_timer:
		_auto_continue_timer.start()


func _on_auto_continue_timeout() -> void:
	if GameManager.state != GameManager.GameState.RESULT:
		return
	GameManager.continue_auto_loop_after_result(_last_result)


func _on_stop_auto_pressed() -> void:
	if _auto_continue_timer:
		_auto_continue_timer.stop()
	GameManager.stop_auto_run()
	if _stop_auto_button:
		_stop_auto_button.visible = false
	if result_label:
		result_label.text = result_label.text.replace("\n\n[自动] 1.5秒后回城并再次出征…", "")
		result_label.text += "\n\n[已停止自动出征]"


func _on_return_pressed() -> void:
	if _auto_continue_timer:
		_auto_continue_timer.stop()
	GameManager.stop_auto_run()
	GameManager.return_to_base()
