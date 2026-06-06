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
var _redeploy_button: Button = null

var shell_left_root: Control = null
var shell_center_root: Control = null
var shell_right_root: Control = null
var _center_exp_label: Label = null
var _shell_attached: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	_ensure_overlay_bg()
	_fix_scroll_layout()
	GameManager.run_ended.connect(_show_result)
	GameManager.state_changed.connect(_on_state_changed)
	if return_button:
		return_button.pressed.connect(_on_return_pressed)
	if equip_all_button:
		equip_all_button.pressed.connect(_on_equip_all_pressed)
	_setup_auto_continue_timer()
	_setup_stop_auto_button()
	_setup_redeploy_button()


func _ensure_overlay_bg() -> void:
	if get_node_or_null("PanelBg") != null:
		return
	var bg := ColorRect.new()
	bg.name = "PanelBg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.color = Color(0.08, 0.1, 0.14, 0.96)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)


func _fix_scroll_layout() -> void:
	if result_label:
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if stats_label == null:
		return
	var parent: Node = stats_label.get_parent()
	if parent == null or parent.get_node_or_null("StatsScroll") != null:
		return
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var idx: int = stats_label.get_index()
	parent.remove_child(stats_label)
	var scroll := ScrollContainer.new()
	scroll.name = "StatsScroll"
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(stats_label)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	parent.move_child(scroll, idx)
	var main_vbox: VBoxContainer = parent as VBoxContainer
	if main_vbox:
		main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = main_vbox.get_parent() as MarginContainer if main_vbox else null
	if margin:
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if loot_status_label:
		loot_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		loot_status_label.max_lines_visible = 3
	if equip_all_button:
		equip_all_button.size_flags_vertical = Control.SIZE_SHRINK_END
	if return_button:
		return_button.size_flags_vertical = Control.SIZE_SHRINK_END


func _setup_redeploy_button() -> void:
	if return_button == null:
		return
	var parent: Node = return_button.get_parent()
	if parent == null:
		return
	_redeploy_button = Button.new()
	_redeploy_button.text = "同地图再战"
	_redeploy_button.custom_minimum_size = Vector2(120, 36)
	_redeploy_button.tooltip_text = "领取本次奖励后立即再出征（当前地图，沿用编队快照补员）"
	_redeploy_button.pressed.connect(_on_redeploy_pressed)
	parent.add_child(_redeploy_button)
	parent.move_child(_redeploy_button, return_button.get_index())


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


func _on_state_changed(_new_state: int) -> void:
	pass


func attach_to_shell(left_slot: Control, center_slot: Control, right_slot: Control, grid_snapshot: Control = null) -> void:
	if _shell_attached:
		return
	_shell_attached = true
	var main_vbox: VBoxContainer = $MarginContainer/MainVBox
	shell_left_root = VBoxContainer.new()
	shell_left_root.name = "ResultLeftSummary"
	shell_left_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_left_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if result_label:
		result_label.reparent(shell_left_root)
	var stats_scroll := main_vbox.get_node_or_null("StatsScroll") as Control
	if stats_scroll:
		stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_scroll.reparent(shell_left_root)
	elif stats_label:
		stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_label.reparent(shell_left_root)
	left_slot.add_child(shell_left_root)
	shell_center_root = VBoxContainer.new()
	shell_center_root.name = "ResultCenterMeta"
	shell_center_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_center_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_exp_label = Label.new()
	_center_exp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center_exp_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_center_root.add_child(_center_exp_label)
	center_slot.add_child(shell_center_root)
	shell_right_root = VBoxContainer.new()
	shell_right_root.name = "ResultRightLoot"
	shell_right_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_right_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if grid_snapshot:
		grid_snapshot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		shell_right_root.add_child(grid_snapshot)
	var loot_scroll := main_vbox.get_node_or_null("LootScroll") as Control
	if loot_scroll:
		loot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		loot_scroll.reparent(shell_right_root)
	if loot_status_label:
		loot_status_label.reparent(shell_right_root)
	if equip_all_button:
		equip_all_button.reparent(shell_right_root)
	if return_button:
		return_button.custom_minimum_size = Vector2(120, 36)
		return_button.reparent(shell_right_root)
	right_slot.add_child(shell_right_root)
	visible = false


func _show_result(result: Dictionary) -> void:
	if GameManager.state != GameManager.GameState.RESULT:
		return
	_last_result = result
	
	var player_alive: bool = result.get("player_alive", false)
	var forced: bool = result.get("forced_withdraw", false)
	var manual: bool = result.get("manual_withdraw", false)
	var boss: bool = result.get("boss_defeated", false)
	var extract_clear: bool = result.get("extract_clear", false)
	var success: bool = result.get("run_success", player_alive and not forced)
	var settlement_tier: String = str(result.get("settlement_tier", "success"))
	
	var title := ""
	if settlement_tier == "mia" and bool(result.get("retreat_failure_mia", false)):
		var mode: String = str(result.get("retreat_failure_mode", ""))
		if mode == "B-3b" or mode == "B-3b-partial":
			title = "撤离失败·部分遗留"
		else:
			title = "撤离失败·战场遗留"
	elif settlement_tier == "mia":
		title = "战场遗留"
	elif settlement_tier == "recovery":
		if bool(result.get("mutual_recovery", false)):
			title = "互捞回收成功"
		else:
			title = "回收成功"
	elif settlement_tier == "recovery_fail":
		title = "回收失败"
	elif settlement_tier == "rescue":
		title = "救援队运尸成功"
	elif settlement_tier == "rescue_fail":
		title = "救援队失败·养伤 CD"
	elif extract_clear and boss:
		title = "Boss讨伐成功!"
	elif extract_clear:
		title = "宝库守卫战胜利!"
	elif manual:
		title = "手动斩仓撤离"
	elif bool(result.get("player_forced_return", false)):
		if bool(result.get("mercs_continue_after_player_return", false)):
			title = "指挥官回城·佣兵留场"
		else:
			title = "指挥官独自回城"
	elif not player_alive:
		title = "全军覆没（永久阵亡）"
	elif forced:
		if result.get("near_death_penalty", false) and bool(result.get("pressure_retreat_event", false)):
			title = "压力收场·抵营养伤"
		elif result.get("near_death_penalty", false):
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
		var dist: float = float(result.get("distance", 0))
		var origin: float = float(result.get("retreat_origin", 0))
		var dist_line := "行进距离: %.0fm" % dist
		if origin > dist + 1.0:
			dist_line += "（最深推进 %.0fm）" % origin
		var stats_text := "击杀敌人: %d\n获得金币: %d\n获得经验: %d (队伍每人)\n获得装备: %d件\n%s" % [
			result.get("enemies_defeated", 0),
			result.get("total_gold", 0),
			result.get("total_exp", 0),
			result.get("total_loot", []).size(),
			dist_line
		]
		if lost_on_retreat > 0:
			stats_text += "\n返程遗失装备: %d 件" % lost_on_retreat
		var rr: String = str(result.get("retreat_reason", ""))
		if rr != "":
			stats_text += "\n返程原因: %s" % _retreat_reason_label(rr)
		if result.get("completed_retreat", false):
			stats_text += "\n已完整抵营返程"
		var evade_xp: int = int(result.get("chase_evade_exp", 0))
		if evade_xp > 0:
			stats_text += "\n追击逃脱奖励: +%d 经验" % evade_xp
		var chase_p: float = float(result.get("chase_pressure", 0.0))
		if chase_p > 0.05 and (
			bool(result.get("boss_defeated", false))
			or int(result.get("chase_boss_repelled", 0)) > 0
			or str(result.get("retreat_spawn_tier", "")) == "chase"
		):
			stats_text += "\n追击压力峰值: %d%%" % int(round(chase_p * 100.0))
		var repelled: int = int(result.get("chase_boss_repelled", 0))
		if repelled > 0 and not result.get("boss_defeated", false):
			stats_text += "\n追击击退次数: %d" % repelled
		var counters: int = int(result.get("chase_counter_uses", 0))
		if counters > 0:
			stats_text += "\n追击反击: %d 次" % counters
		var stag: int = int(result.get("chase_stagger_repelled", 0))
		if stag > 0:
			stats_text += "\n僵持击退: %d 次" % stag
		var deep_n: int = int(result.get("chase_deep_counter_uses", 0))
		if deep_n > 0:
			stats_text += "\n深度反击: %d 次" % deep_n
		var tier: String = str(result.get("retreat_spawn_tier", ""))
		if tier == "chase":
			stats_text += "\n返程阶段: 追击加压刷怪"
		elif tier == "sparse" and rr != "":
			stats_text += "\n返程阶段: 稀疏刷怪"
		if result.get("extract_guard_cleared", false):
			stats_text += "\n宝库守卫: 已击退"
		var last_ext: String = str(result.get("last_extract_item_name", ""))
		if last_ext != "" and not result.get("extract_guard_cleared", false):
			stats_text += "\n本趟撤离物: %s" % last_ext
		var abandoned: int = int(result.get("loot_abandoned_manual", 0))
		if abandoned > 0:
			stats_text += "\n斩仓舍弃外露: %d 件（仅安全箱带回）" % abandoned
		if bool(result.get("player_forced_return", false)):
			stats_text += "\n指挥官濒死回营（永不战场遗留）"
			if bool(result.get("mercs_continue_after_player_return", false)):
				stats_text += " · 佣兵曾留场作战"
		if bool(result.get("pressure_retreat_event", false)) and int(result.get("pressure_mia_quota", 0)) > 0:
			stats_text += "\n压力收场撤离 · 预估遗留风险 %d 人" % int(result.get("pressure_mia_quota", 0))
			if int(result.get("pressure_mia_applied", -1)) >= 0:
				stats_text += " · 抵营二阶段实留 %d 人" % int(result.get("pressure_mia_applied", 0))
		if settlement_tier == "mia" and bool(result.get("retreat_failure_mia", false)):
			var mia_n: int = int(result.get("mia_count", 0))
			var mode_l: String = str(result.get("retreat_failure_mode", ""))
			stats_text += "\n撤离未抵营：%d 人战场遗留（%s）" % [mia_n, mode_l]
			stats_text += "\n请 F5 后勤 · 回收"
		elif settlement_tier == "mia" and bool(result.get("mia_wipe_recovery_hint", false)):
			stats_text += "\n测试⑨：回大营后勿再点「出征」（会重置遗留）；请 F5 后勤 · 回收"
		if settlement_tier == "recovery":
			var unfrozen: int = int(result.get("recovery_unfrozen_exp", 0))
			var targets: Array = result.get("recovery_target_ids", [])
			if bool(result.get("mutual_recovery", false)):
				stats_text += "\nB-10 双半组互捞回收"
			if targets.size() > 0:
				stats_text += "\n已寻回 %d 名遗留队员；回大营领取解冻经验" % targets.size()
			if unfrozen > 0:
				stats_text += "\n冻结经验解冻入账: %d（25%%）" % unfrozen
		elif settlement_tier == "recovery_fail":
			stats_text += "\n回收失败：捞人队濒死回营（未新增遗留）；可休养后再试"
			if bool(result.get("return_scroll_granted", false)):
				stats_text += "\n获得回城卷轴（读条一键减价）"
		elif settlement_tier == "rescue":
			var targets_r: Array = result.get("rescue_target_ids", [])
			if targets_r.size() > 0:
				stats_text += "\n已运回 %d 具尸体至停尸间；请后勤医疗复活" % targets_r.size()
			var rep_gain: int = int(result.get("rescue_reputation_gain", 0))
			if rep_gain > 0:
				stats_text += "\n救援声望 +%d · 等级 %d" % [
					rep_gain, int(result.get("rescue_rank", 0))
				]
			var bonus: int = int(result.get("rescue_bonus_exp", 0))
			if bonus > 0:
				stats_text += "\n救援队经验 +%d（不取冻结池）" % bonus
		elif settlement_tier == "rescue_fail":
			stats_text += "\n救援队失败：队员养伤 CD，原遗留仍在地图"
		elif settlement_tier == "mia":
			stats_text += "\n队员失踪（战场遗留 / MIA）；回大营后打开后勤 [F5] · 回收"
			var frozen: int = int(result.get("frozen_exp_recorded", 0))
			if frozen > 0:
				var ratio_pct: int = int(round(float(result.get("frozen_exp_mia_ratio", 0.0)) * 100.0))
				stats_text += "\n经验已冻结: %d（MIA 占比 %d%%，回收后解冻）" % [frozen, ratio_pct]
			elif int(result.get("total_exp", 0)) > 0:
				stats_text += "\n本趟经验未入账（待回收解冻）"
		elif result.get("near_death_penalty", false):
			stats_text += "\n全队濒死（需在大营休养至满血，撤离失败才会阵亡）"
		if GameManager.last_run_stability_note != "":
			stats_text += "\n\n" + GameManager.last_run_stability_note
		if result.get("test_run_ephemeral", false):
			stats_text += "\n\n[测试图] 以上为模拟结算；回大营不入账、不影响正式进度"
		var unlocked_maps: Array = result.get("maps_unlocked", [])
		if not unlocked_maps.is_empty():
			var names: Array[String] = []
			for mid in unlocked_maps:
				var md: Dictionary = DataLoader.map_data(str(mid))
				names.append(str(md.get("name", mid)))
			stats_text += "\n\n★ 解锁新地图: %s" % ", ".join(names)
		stats_label.text = stats_text
	if _center_exp_label:
		var center_lines: PackedStringArray = []
		center_lines.append("—— 升级 / 再战 ——")
		if settlement_tier == "mia":
			var frozen_c: int = int(result.get("frozen_exp_recorded", 0))
			if frozen_c > 0:
				center_lines.append("经验: 已冻结 %d（本趟不入账）" % frozen_c)
			else:
				center_lines.append("经验: 本趟未入账（MIA 结算）")
		elif settlement_tier == "recovery":
			var unfrozen_c: int = int(result.get("recovery_unfrozen_exp", 0))
			if unfrozen_c > 0:
				center_lines.append("经验: 回收解冻 +%d（目标队员）" % unfrozen_c)
			else:
				center_lines.append("经验: 遗留已清除（无冻结池可解冻）")
		elif settlement_tier == "recovery_fail":
			center_lines.append("经验: 本趟回收无入账；捞人队需休养")
		else:
			center_lines.append("经验: +%d (队伍每人)" % int(result.get("total_exp", 0)))
		if result.get("test_run_ephemeral", false):
			center_lines.append("测试图：回大营时不发放奖励")
		if not GameManager.last_run_level_up_log.is_empty():
			center_lines.append("升级: " + ", ".join(GameManager.last_run_level_up_log))
		if GameManager.is_recovery_lock_active():
			center_lines.append(SquadFormationService.get_recovery_lock_message(GameManager))
		else:
			center_lines.append("可再战 / 回大营领取奖励")
		_center_exp_label.text = "\n".join(center_lines)
		if GameManager.is_recovery_lock_active():
			_center_exp_label.modulate = Color.ORANGE_RED
		else:
			_center_exp_label.modulate = Color(0.85, 0.95, 1.0)
	
	_refresh_loot(result.get("total_loot", []))
	_update_equip_all_button()
	_maybe_schedule_auto_continue(result)
	_update_redeploy_button(result)


func _update_redeploy_button(result: Dictionary) -> void:
	if _redeploy_button == null:
		return
	var ok: bool = (
		result.get("player_alive", false)
		and not result.get("manual_withdraw", false)
		and not GameManager.is_recovery_lock_active()
	)
	_redeploy_button.visible = ok
	var map_id: String = str(result.get("map_id", GameManager.selected_map_id))
	var md: Dictionary = DataLoader.map_data(map_id)
	var map_name: String = str(md.get("name", map_id))
	_redeploy_button.text = "再战·%s" % map_name
	_redeploy_button.disabled = not ok


func _on_redeploy_pressed() -> void:
	if _auto_continue_timer:
		_auto_continue_timer.stop()
	GameManager.stop_auto_run()
	var code: int = GameManager.redeploy_same_map()
	if code != 0 and loot_status_label:
		loot_status_label.text = GameManager.get_run_start_error_message(code)
		loot_status_label.modulate = Color.ORANGE_RED


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


func _retreat_reason_label(reason: String) -> String:
	match reason:
		"forced": return "稳定度过低"
		"boss_auto": return "到达Boss线自动返程"
		"auto_value": return "携带价值达标"
		"auto_rule": return "自动规则"
		"manual": return "手动斩仓"
		"combat_fail": return "战斗失利"
		"emergency": return "紧急撤离"
		"pressure": return "压力收场·撤离事件"
		_: return reason


func _on_return_pressed() -> void:
	if _auto_continue_timer:
		_auto_continue_timer.stop()
	GameManager.stop_auto_run()
	GameManager.return_to_base()
