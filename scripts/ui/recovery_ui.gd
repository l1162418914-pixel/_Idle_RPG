extends VBoxContainer
class_name RecoveryUI
## 大营回收占位 — 后勤「回收」Tab：MIA 列表、放弃搜寻、大价值复活占位

var _list_host: VBoxContainer = null
var _summary_label: Label = null
var _confirm_dialog: ConfirmationDialog = null
var _pending_abandon_id: String = ""
var _main_shell: MainShell = null
var _readbar_overlay: PanelContainer = null
var _readbar_label: Label = null
var _readbar_bar: ProgressBar = null
var _readbar_timer: Timer = null
var _pending_instant_merc_id: String = ""


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var hint := Label.new()
	hint.text = "战场遗留：互捞短程回收 / 大价值复活 / 放弃搜寻。第三队救援队：避战运尸入停尸间（不取冻结经验）；停尸间待医疗复活。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.7, 0.78, 0.9)
	add_child(hint)
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 11)
	_summary_label.modulate = Color(0.65, 0.72, 0.82)
	add_child(_summary_label)
	_list_host = VBoxContainer.new()
	_list_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_host.add_theme_constant_override("separation", 6)
	add_child(_list_host)
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "放弃搜寻"
	_confirm_dialog.ok_button_text = "确认放弃"
	_confirm_dialog.cancel_button_text = "取消"
	_confirm_dialog.dialog_text = ""
	_confirm_dialog.confirmed.connect(_on_abandon_confirmed)
	add_child(_confirm_dialog)


func bind_main_shell(shell: MainShell) -> void:
	_main_shell = shell


func refresh() -> void:
	if _list_host == null:
		return
	for child in _list_host.get_children():
		child.queue_free()
	var mia_list: Array = GameManager.get_mia_roster_entries()
	var frozen_total: int = GameManager.get_total_frozen_exp()
	if _summary_label:
		if mia_list.is_empty():
			_summary_label.text = "当前无战场遗留队员。"
		else:
			_summary_label.text = "遗留 %d 人 · 账号冻结经验 %d（放弃搜寻将按人扣减对应池）" % [
				mia_list.size(), frozen_total
			]
	if mia_list.is_empty():
		var empty := Label.new()
		empty.text = "（无战场遗留）"
		empty.modulate = Color.GRAY
		_list_host.add_child(empty)
	else:
		for entry in mia_list:
			if entry is Dictionary:
				_add_mia_row(entry)
	_add_morgue_section()


func _add_mia_row(entry: Dictionary) -> void:
	var merc: Mercenary = entry.get("merc")
	if merc == null:
		return
	var merc_id: String = str(entry.get("merc_id", merc.merc_id))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tag: String = str(entry.get("tag", "[佣兵]"))
	var frozen: int = int(entry.get("frozen_exp", 0))
	var map_name: String = str(entry.get("map_name", ""))
	var map_part := (" · %s" % map_name) if map_name != "" else ""
	var skips: int = int(entry.get("skipped_runs", 0))
	var map_ok: bool = bool(entry.get("map_point_visible", true))
	var deter_part := ""
	if skips > 0:
		deter_part = " · 未捞%d趟" % skips
	if not map_ok:
		deter_part += " · 地图点已失"
	var scroll_n: int = int(entry.get("scroll_count", 0))
	var scroll_part := ""
	if scroll_n > 0:
		scroll_part = " · 卷轴×%d" % scroll_n
	label.text = "%s %s Lv.%d [遗留]%s · 冻结经验 %d%s%s" % [
		tag, merc.merc_name, merc.level, map_part, frozen, deter_part, scroll_part
	]
	label.modulate = Color(0.55, 0.58, 0.68)
	row.add_child(label)
	var run_btn := Button.new()
	run_btn.text = "发起回收"
	run_btn.custom_minimum_size = Vector2(80, 28)
	run_btn.tooltip_text = "派出可出战半组短程回收跑图；抵点即胜，成功清遗留并解冻 25% 冻结经验"
	run_btn.disabled = not map_ok
	if not map_ok:
		run_btn.tooltip_text = "地图回收点已消失，请用大价值复活"
	run_btn.pressed.connect(_on_recovery_run_pressed.bind(merc_id))
	row.add_child(run_btn)
	var revive_btn := Button.new()
	revive_btn.text = "大价值复活"
	revive_btn.custom_minimum_size = Vector2(88, 28)
	var hv_cost: int = GameManager.get_high_value_mia_revive_cost(merc)
	revive_btn.tooltip_text = "大营即时复活，无需跑图；消耗 %d 金币，清遗留并解冻 25% 冻结经验" % hv_cost
	revive_btn.pressed.connect(_on_high_value_pressed.bind(merc_id))
	row.add_child(revive_btn)
	var rescue_btn := Button.new()
	rescue_btn.text = "救援队"
	rescue_btn.custom_minimum_size = Vector2(72, 28)
	var rescue_ok: bool = MorgueService.is_rescue_unlocked(GameManager)
	rescue_btn.disabled = not map_ok or not rescue_ok
	rescue_btn.tooltip_text = "第三队避战运尸；成功入停尸间，地图点清除，不解冻 B-6 池"
	if not rescue_ok:
		rescue_btn.tooltip_text = "需升级大营「救援站」至 Lv.1"
	elif not map_ok:
		rescue_btn.tooltip_text = "地图点已失，请大价值复活"
	rescue_btn.pressed.connect(_on_rescue_run_pressed.bind(merc_id))
	row.add_child(rescue_btn)
	var instant_btn := Button.new()
	instant_btn.text = "读条一键"
	instant_btn.custom_minimum_size = Vector2(72, 28)
	var use_scroll: bool = scroll_n > 0
	var inst_cost: int = InstantRecoveryService.gold_cost(GameManager, merc, use_scroll)
	instant_btn.tooltip_text = (
		"大营读条即时捞人（%d 金%s）· 低于大价值" % [
			inst_cost, " · 卷轴减价" if use_scroll else ""
		]
	)
	instant_btn.pressed.connect(_on_instant_recovery_pressed.bind(merc_id))
	row.add_child(instant_btn)
	var abandon_btn := Button.new()
	abandon_btn.text = "放弃搜寻"
	abandon_btn.custom_minimum_size = Vector2(80, 28)
	abandon_btn.pressed.connect(_on_abandon_pressed.bind(merc_id, merc.merc_name))
	row.add_child(abandon_btn)
	_list_host.add_child(row)


func _on_abandon_pressed(merc_id: String, merc_name: String) -> void:
	_pending_abandon_id = merc_id
	var frozen: int = GameManager.get_frozen_exp_for_merc(merc_id)
	var dialog_lines: String = (
		"确认放弃搜寻「%s」？\n\n该佣兵将永久阵亡并从遗留列表移除。" % merc_name
	)
	if frozen > 0:
		dialog_lines += "\n冻结经验池将扣减约 %d。" % frozen
	_confirm_dialog.dialog_text = dialog_lines
	_confirm_dialog.popup_centered()


func _on_abandon_confirmed() -> void:
	var merc_id: String = _pending_abandon_id
	_pending_abandon_id = ""
	if merc_id == "":
		return
	var code: int = GameManager.abandon_mia_search(merc_id)
	var msg: String = ""
	var color := Color.ORANGE_RED
	match code:
		0:
			msg = "已放弃搜寻，队员记为永久阵亡。"
			color = Color(0.85, 0.75, 0.75)
		-2:
			msg = "主角无法放弃搜寻。"
		_:
			msg = "无法放弃搜寻（非遗留状态或找不到单位）。"
	_toast(msg, color)
	refresh()
	if _main_shell and _main_shell.has_method("refresh_base_panels"):
		_main_shell.refresh_base_panels()


func _add_morgue_section() -> void:
	var morgue: Array = GameManager.get_morgue_entries()
	var sep := Label.new()
	sep.text = "—— 停尸间（待医疗）——"
	sep.add_theme_font_size_override("font_size", 11)
	sep.modulate = Color(0.6, 0.65, 0.75)
	_list_host.add_child(sep)
	if morgue.is_empty():
		var empty := Label.new()
		empty.text = "（无待医疗尸体）"
		empty.modulate = Color.GRAY
		_list_host.add_child(empty)
		return
	for entry in morgue:
		if entry is Dictionary:
			_add_morgue_row(entry)


func _add_morgue_row(entry: Dictionary) -> void:
	var merc: Mercenary = entry.get("merc")
	if merc == null:
		return
	var merc_id: String = str(entry.get("merc_id", merc.merc_id))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var map_name: String = str(entry.get("map_name", ""))
	var map_part := (" · %s" % map_name) if map_name != "" else ""
	label.text = "[停尸] %s Lv.%d%s" % [merc.merc_name, merc.level, map_part]
	label.modulate = Color(0.5, 0.52, 0.62)
	row.add_child(label)
	var med_btn := Button.new()
	med_btn.text = "医疗复活"
	med_btn.custom_minimum_size = Vector2(88, 28)
	var cost: int = MorgueService.medical_revive_cost(merc)
	med_btn.tooltip_text = "停尸间医疗复活，消耗 %d 金币；回营濒死养伤" % cost
	med_btn.pressed.connect(_on_morgue_revive_pressed.bind(merc_id))
	row.add_child(med_btn)
	_list_host.add_child(row)


func _on_instant_recovery_pressed(merc_id: String) -> void:
	_pending_instant_merc_id = merc_id
	_ensure_readbar_overlay()
	var sec: float = InstantRecoveryService.readbar_sec()
	if _readbar_label:
		_readbar_label.text = "读条一键回收中…"
	if _readbar_bar:
		_readbar_bar.max_value = sec
		_readbar_bar.value = sec
	if _readbar_overlay:
		_readbar_overlay.visible = true
	if _readbar_timer:
		_readbar_timer.start(sec)


func _ensure_readbar_overlay() -> void:
	if _readbar_overlay != null:
		return
	_readbar_overlay = PanelContainer.new()
	_readbar_overlay.visible = false
	_readbar_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_readbar_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 40)
	_readbar_overlay.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(280, 0)
	center.add_child(vbox)
	_readbar_label = Label.new()
	_readbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_readbar_label)
	_readbar_bar = ProgressBar.new()
	_readbar_bar.custom_minimum_size = Vector2(260, 16)
	_readbar_bar.show_percentage = false
	vbox.add_child(_readbar_bar)
	_readbar_timer = Timer.new()
	_readbar_timer.one_shot = true
	_readbar_timer.timeout.connect(_on_readbar_finished)
	add_child(_readbar_timer)
	var tick := Timer.new()
	tick.wait_time = 0.05
	tick.timeout.connect(_tick_readbar)
	add_child(tick)
	tick.start()


func _tick_readbar() -> void:
	if _readbar_overlay == null or not _readbar_overlay.visible or _readbar_timer == null:
		return
	if _readbar_bar:
		_readbar_bar.value = _readbar_timer.time_left


func _on_readbar_finished() -> void:
	if _readbar_overlay:
		_readbar_overlay.visible = false
	var merc_id: String = _pending_instant_merc_id
	_pending_instant_merc_id = ""
	if merc_id == "":
		return
	var code: int = GameManager.try_instant_mia_recovery(merc_id, true)
	match code:
		0:
			var summary: Dictionary = GameManager.last_instant_recovery_summary
			var msg := "读条一键成功（-%d 金" % int(summary.get("cost", 0))
			if bool(summary.get("scroll_used", false)):
				msg += "·卷轴"
			msg += "）"
			var unfrozen: int = int(summary.get("unfrozen", 0))
			if unfrozen > 0:
				msg += "，解冻 %d 经验" % unfrozen
			_toast(msg, Color(0.82, 0.94, 0.85))
			refresh()
			if _main_shell and _main_shell.has_method("refresh_base_panels"):
				_main_shell.refresh_base_panels()
		-2:
			_toast("金币不足。", Color.ORANGE_RED)
		-3:
			_toast("当前已在出征中。", Color.ORANGE)
		_:
			_toast("仅战场遗留队员可读条一键。", Color.ORANGE)


func _on_rescue_run_pressed(merc_id: String) -> void:
	var code: int = GameManager.start_rescue_run(merc_id)
	match code:
		0:
			_toast("救援队已出发（避战运尸）。", Color(0.75, 0.88, 1.0))
		-3:
			_toast("当前已在出征中。", Color.ORANGE)
		-4:
			_toast("无法确定救援地图。", Color.ORANGE_RED)
		-5:
			_toast("第三队可用队员不足，请恢复佣兵或等待养伤 CD 结束。", Color.ORANGE_RED)
		-6:
			_toast("地图点已消失。", Color.ORANGE_RED)
		-7:
			_toast("救援队尚未解锁。", Color.ORANGE_RED)
		-2:
			_toast("救援出征启动失败。", Color.ORANGE_RED)
		_:
			_toast("仅战场遗留队员可派救援队。", Color.ORANGE)


func _on_morgue_revive_pressed(merc_id: String) -> void:
	var code: int = GameManager.try_morgue_medical_revive(merc_id)
	match code:
		0:
			_toast("医疗复活成功，队员回营濒死养伤。", Color(0.85, 0.92, 0.8))
			refresh()
			if _main_shell and _main_shell.has_method("refresh_base_panels"):
				_main_shell.refresh_base_panels()
		-2:
			_toast("金币不足。", Color.ORANGE_RED)
		-3:
			_toast("当前已在出征中。", Color.ORANGE)
		_:
			_toast("仅停尸间尸体可医疗复活。", Color.ORANGE)


func _on_recovery_run_pressed(merc_id: String) -> void:
	var code: int = GameManager.start_recovery_run(merc_id)
	match code:
		0:
			_toast("已发起回收出征，抵点即胜。", Color(0.75, 0.9, 1.0))
		-3:
			_toast("当前已在出征中。", Color.ORANGE)
		-4:
			_toast("无法确定回收地图（冻结池缺失或未解锁）。", Color.ORANGE_RED)
		-5:
			_toast("无可用出战半组，请先恢复佣兵至可出征状态。", Color.ORANGE_RED)
		-6:
			_toast("地图回收点已消失，请使用大价值复活。", Color.ORANGE_RED)
		-2:
			_toast("回收出征启动失败。", Color.ORANGE_RED)
		_:
			_toast("仅战场遗留队员可发起回收。", Color.ORANGE)


func _on_high_value_pressed(merc_id: String) -> void:
	var code: int = GameManager.try_high_value_mia_revive(merc_id)
	match code:
		0:
			var summary: Dictionary = GameManager.last_high_value_revive_summary
			var cost: int = int(summary.get("cost", 0))
			var unfrozen: int = int(summary.get("unfrozen", 0))
			var msg := "大价值复活成功（-%d 金）" % cost
			if unfrozen > 0:
				msg += "，解冻 %d 经验" % unfrozen
			_toast(msg, Color(0.85, 0.95, 0.8))
			refresh()
			if _main_shell and _main_shell.has_method("refresh_base_panels"):
				_main_shell.refresh_base_panels()
		-2:
			_toast("金币不足，无法大价值复活。", Color.ORANGE_RED)
		-3:
			_toast("当前已在出征中。", Color.ORANGE)
		_:
			_toast("仅战场遗留队员可大价值复活。", Color.ORANGE)


func _toast(text: String, color: Color = Color.WHITE) -> void:
	if _main_shell and _main_shell.has_method("show_toast"):
		_main_shell.show_toast(text, color, 4.5)
	else:
		push_warning("RecoveryUI: %s" % text)
