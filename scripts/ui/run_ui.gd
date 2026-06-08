extends Control
## RunUI — 出征中界面，显示距离、稳定度（战斗可视化由 CombatView 负责）

signal hint_posted(text: String, color: Color)

@onready var distance_label: Label = $MarginContainer/MainVBox/InfoHBox/DistanceLabel
@onready var stability_label: Label = $MarginContainer/MainVBox/InfoHBox/StabilityLabel
@onready var withdraw_button: Button = $MarginContainer/MainVBox/InfoHBox/WithdrawButton
@onready var run_hint_label: Label = $MarginContainer/MainVBox/RunHintLabel

var _auto_status_label: Label = null
var _stop_auto_button: Button = null
var _auto_retreat_safe_check: CheckButton = null
var _shield_bar_box: VBoxContainer = null
var _equip_shield_bar: ProgressBar = null
var _material_shield_bar: ProgressBar = null
var _chase_counter_button: Button = null
var _chase_stagger_button: Button = null
var _chase_deep_counter_button: Button = null
var _chase_stagger_bar: ProgressBar = null
var _stagger_hold: bool = false
var _combat_view: CombatView = null
var _chase_toolbar_host: HBoxContainer = null
var _lane_status_label: Label = null
var _lane_snapshot: Dictionary = {}
var _last_run_data: Dictionary = {}
var _probe_debug_label: Label = null
var _forced_return_overlay: CanvasLayer = null
var _forced_return_title: Label = null
var _forced_return_sub: Label = null
var _forced_return_timer: Timer = null
var _substitute_overlay: CanvasLayer = null
var _substitute_title: Label = null
var _substitute_bar: ProgressBar = null
var _substitute_timer: Timer = null
var _stability_in_top_bar: bool = false


func bind_main_shell(_shell: Control) -> void:
	_stability_in_top_bar = true
	if stability_label:
		stability_label.visible = false


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	if withdraw_button:
		withdraw_button.pressed.connect(_on_withdraw_pressed)
		_setup_auto_controls()
		_setup_shield_bars()
		_setup_lane_status()
		_setup_probe_debug()


func _setup_probe_debug() -> void:
	var parent := run_hint_label.get_parent() if run_hint_label else null
	if parent == null:
		return
	_probe_debug_label = Label.new()
	_probe_debug_label.name = "ProbeDebugLabel"
	_probe_debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_probe_debug_label.add_theme_font_size_override("font_size", 9)
	_probe_debug_label.modulate = Color(0.5, 0.58, 0.68)
	parent.add_child(_probe_debug_label)
	parent.move_child(_probe_debug_label, run_hint_label.get_index() + 1 if run_hint_label else 0)


func show_probe_summary(line: String) -> void:
	if _probe_debug_label:
		_probe_debug_label.text = line


func _setup_lane_status() -> void:
	var hbox: HBoxContainer = withdraw_button.get_parent() as HBoxContainer if withdraw_button else null
	if hbox == null:
		return
	_lane_status_label = Label.new()
	_lane_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lane_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lane_status_label.add_theme_font_size_override("font_size", 13)
	_lane_status_label.modulate = Color(0.75, 0.9, 1.0)
	hbox.add_child(_lane_status_label)


func _setup_auto_controls() -> void:
	var hbox: HBoxContainer = withdraw_button.get_parent() as HBoxContainer
	if hbox == null:
		return
	_auto_status_label = Label.new()
	_auto_status_label.visible = false
	hbox.add_child(_auto_status_label)
	hbox.move_child(_auto_status_label, 0)
	_stop_auto_button = Button.new()
	_stop_auto_button.text = "停止自动"
	_stop_auto_button.visible = false
	_stop_auto_button.pressed.connect(_on_stop_auto_pressed)
	hbox.add_child(_stop_auto_button)
	_auto_retreat_safe_check = CheckButton.new()
	_auto_retreat_safe_check.text = "本趟策略"
	_auto_retreat_safe_check.tooltip_text = "出征策略在大营 F2「出征策略」区设定，本趟出发时锁定"
	_auto_retreat_safe_check.disabled = true
	_auto_retreat_safe_check.button_pressed = true
	hbox.add_child(_auto_retreat_safe_check)
	_chase_counter_button = Button.new()
	_chase_counter_button.text = "追击反击"
	_chase_counter_button.visible = false
	_chase_counter_button.tooltip_text = "消耗稳定度将首领推远，获得击退经验（接战距离内不可用）"
	_chase_counter_button.pressed.connect(_on_chase_counter_pressed)
	hbox.add_child(_chase_counter_button)
	_chase_stagger_button = Button.new()
	_chase_stagger_button.text = "蓄力击退"
	_chase_stagger_button.visible = false
	_chase_stagger_button.tooltip_text = "按住蓄力，松手在接战僵持时推远首领（不击杀、继续返程）"
	_chase_stagger_button.button_down.connect(_on_stagger_down)
	_chase_stagger_button.button_up.connect(_on_stagger_up)
	hbox.add_child(_chase_stagger_button)
	_chase_deep_counter_button = Button.new()
	_chase_deep_counter_button.text = "深度反击"
	_chase_deep_counter_button.visible = false
	_chase_deep_counter_button.tooltip_text = "接战僵持中消耗更多稳定度重创首领并推远（不击杀，继续返程）"
	_chase_deep_counter_button.pressed.connect(_on_deep_counter_pressed)
	hbox.add_child(_chase_deep_counter_button)
	_chase_stagger_bar = ProgressBar.new()
	_chase_stagger_bar.visible = false
	_chase_stagger_bar.custom_minimum_size = Vector2(120, 14)
	_chase_stagger_bar.max_value = 1.0
	_chase_stagger_bar.show_percentage = false
	_chase_stagger_bar.tooltip_text = "按住「蓄力击退」充能，松手推远首领（不击杀）"


func bind_combat_view(combat_view: CombatView) -> void:
	_combat_view = combat_view
	_mount_chase_controls_in_combat_toolbar()


func _mount_chase_controls_in_combat_toolbar() -> void:
	if _combat_view == null or _chase_toolbar_host != null:
		return
	var toolbar := _combat_view.get_node_or_null("DebugToolbar") as HBoxContainer
	if toolbar == null:
		return
	_chase_toolbar_host = HBoxContainer.new()
	_chase_toolbar_host.add_theme_constant_override("separation", 6)
	toolbar.add_child(_chase_toolbar_host)
	var sep := VSeparator.new()
	_chase_toolbar_host.add_child(sep)
	var charge_lbl := Label.new()
	charge_lbl.text = "僵持"
	charge_lbl.add_theme_font_size_override("font_size", 12)
	_chase_toolbar_host.add_child(charge_lbl)
	_chase_toolbar_host.add_child(_chase_stagger_bar)
	if _chase_stagger_button:
		if _chase_stagger_button.get_parent():
			_chase_stagger_button.get_parent().remove_child(_chase_stagger_button)
		_chase_toolbar_host.add_child(_chase_stagger_button)
	if _chase_deep_counter_button:
		if _chase_deep_counter_button.get_parent():
			_chase_deep_counter_button.get_parent().remove_child(_chase_deep_counter_button)
		_chase_toolbar_host.add_child(_chase_deep_counter_button)
	_chase_toolbar_host.visible = false


func _on_stagger_down() -> void:
	_stagger_hold = true


func _on_stagger_up() -> void:
	_stagger_hold = false
	var main = get_tree().current_scene
	if main and main.has_method("_on_chase_stagger_released"):
		main._on_chase_stagger_released()


func _on_deep_counter_pressed() -> void:
	var main = get_tree().current_scene
	if main and main.has_method("_on_chase_deep_counter_pressed"):
		main._on_chase_deep_counter_pressed()


func _setup_shield_bars() -> void:
	if run_hint_label == null:
		return
	var parent: Node = run_hint_label.get_parent()
	if parent == null:
		return
	_shield_bar_box = VBoxContainer.new()
	_shield_bar_box.visible = false
	_shield_bar_box.add_theme_constant_override("separation", 2)
	parent.add_child(_shield_bar_box)
	parent.move_child(_shield_bar_box, run_hint_label.get_index())
	var eq_lbl := Label.new()
	eq_lbl.text = "装备护盾"
	eq_lbl.add_theme_font_size_override("font_size", 11)
	_shield_bar_box.add_child(eq_lbl)
	_equip_shield_bar = ProgressBar.new()
	_equip_shield_bar.custom_minimum_size = Vector2(180, 14)
	_equip_shield_bar.show_percentage = false
	_equip_shield_bar.modulate = Color(0.55, 0.85, 1.0)
	_shield_bar_box.add_child(_equip_shield_bar)
	var mt_lbl := Label.new()
	mt_lbl.text = "物资护盾"
	mt_lbl.add_theme_font_size_override("font_size", 11)
	_shield_bar_box.add_child(mt_lbl)
	_material_shield_bar = ProgressBar.new()
	_material_shield_bar.custom_minimum_size = Vector2(180, 14)
	_material_shield_bar.show_percentage = false
	_material_shield_bar.modulate = Color(0.75, 1.0, 0.65)
	_shield_bar_box.add_child(_material_shield_bar)


func _update_shield_bars(run_data: Dictionary) -> void:
	if _shield_bar_box == null:
		return
	var retreating: bool = run_data.get("is_retreating", false)
	var eq_max: int = int(run_data.get("equip_shield_max", 0))
	var mt_max: int = int(run_data.get("material_shield_max", 0))
	var show: bool = retreating and (eq_max + mt_max > 0)
	_shield_bar_box.visible = show
	if not show:
		return
	var eq_cur: int = int(run_data.get("equip_shield", 0))
	var mt_cur: int = int(run_data.get("material_shield", 0))
	_equip_shield_bar.max_value = maxf(1.0, float(eq_max))
	_equip_shield_bar.value = eq_cur
	_material_shield_bar.max_value = maxf(1.0, float(mt_max))
	_material_shield_bar.value = mt_cur
	var chase_mult: float = float(run_data.get("shield_damage_mult", 1.0))
	if chase_mult > 1.01 and _material_shield_bar:
		_material_shield_bar.tooltip_text = "追击加压：护盾消耗×%.2f" % chase_mult


func _on_state_changed(_new_state: int) -> void:
	pass


func _on_withdraw_pressed() -> void:
	var main = get_tree().current_scene
	if main and main.has_method("_on_manual_withdraw_pressed"):
		main._on_manual_withdraw_pressed()


func _on_chase_counter_pressed() -> void:
	var main = get_tree().current_scene
	if main and main.has_method("_on_chase_counter_pressed"):
		main._on_chase_counter_pressed()


func reset_run_hints() -> void:
	if run_hint_label:
		run_hint_label.text = ""
		run_hint_label.modulate = Color.WHITE
	if _lane_status_label:
		_lane_status_label.text = ""
	_lane_snapshot = {}
	_last_run_data = {}
	if _probe_debug_label:
		_probe_debug_label.text = ""
	_update_auto_indicator()


func _update_auto_indicator() -> void:
	var active: bool = GameManager.auto_run_enabled
	if _auto_status_label:
		_auto_status_label.visible = active
		if active:
			var md: Dictionary = DataLoader.map_data(GameManager.auto_run_map_id)
			var map_name: String = md.get("name", GameManager.auto_run_map_id)
			_auto_status_label.text = "[自动] %s" % map_name
			_auto_status_label.modulate = Color.SKY_BLUE
	if _stop_auto_button:
		_stop_auto_button.visible = active


func _on_stop_auto_pressed() -> void:
	GameManager.stop_auto_run()
	show_run_hint("已停止自动出征（本趟结束后不再循环）", Color.GRAY)
	_update_auto_indicator()


func show_chase_standoff_banner(charge: float) -> void:
	if run_hint_label == null:
		return
	var pct: int = int(round(charge * 100.0))
	run_hint_label.text = (
		"【追击僵持】按住战斗区红底条上的「蓄力击退」→ 充到 88%% 松手（当前 %d%%）" % pct
	)
	run_hint_label.modulate = Color(1.0, 0.55, 0.2)
	run_hint_label.add_theme_font_size_override("font_size", 16)


func clear_chase_standoff_banner() -> void:
	if run_hint_label == null:
		return
	run_hint_label.text = ""
	run_hint_label.remove_theme_font_size_override("font_size")
	run_hint_label.modulate = Color.WHITE


func show_run_hint(text: String, color: Color = Color.WHITE) -> void:
	if run_hint_label:
		run_hint_label.text = text
		run_hint_label.modulate = color
	hint_posted.emit(text, color)


func play_player_forced_return_overlay(mercs_continue: bool, player_name: String = "") -> void:
	_ensure_forced_return_overlay()
	var name_s: String = player_name if player_name != "" else "指挥官"
	if _forced_return_title:
		_forced_return_title.text = "%s 独自回城" % name_s
	if _forced_return_sub:
		_forced_return_sub.text = "佣兵继续作战…" if mercs_continue else "队伍紧急撤离"
	_forced_return_overlay.visible = true
	var sec: float = float(PlayerForcedReturnService.config().get("animation_sec", 2.2))
	if _forced_return_timer:
		_forced_return_timer.start(sec)


func _ensure_forced_return_overlay() -> void:
	if _forced_return_overlay != null:
		return
	_forced_return_overlay = CanvasLayer.new()
	_forced_return_overlay.layer = 50
	add_child(_forced_return_overlay)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.08, 0.12, 0.82)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_forced_return_overlay.add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var vbox := VBoxContainer.new()
	center.add_child(vbox)
	_forced_return_title = Label.new()
	_forced_return_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forced_return_title.add_theme_font_size_override("font_size", 22)
	_forced_return_title.modulate = Color(0.85, 0.92, 1.0)
	vbox.add_child(_forced_return_title)
	_forced_return_sub = Label.new()
	_forced_return_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forced_return_sub.add_theme_font_size_override("font_size", 15)
	_forced_return_sub.modulate = Color(0.7, 0.78, 0.88)
	vbox.add_child(_forced_return_sub)
	_forced_return_overlay.visible = false
	_forced_return_timer = Timer.new()
	_forced_return_timer.one_shot = true
	_forced_return_timer.timeout.connect(_hide_forced_return_overlay)
	add_child(_forced_return_timer)


func _hide_forced_return_overlay() -> void:
	if _forced_return_overlay:
		_forced_return_overlay.visible = false


func play_substitute_swap_overlay(out_name: String, in_name: String, duration_sec: float = 1.4) -> void:
	_ensure_substitute_overlay()
	var sec: float = maxf(0.4, duration_sec)
	if _substitute_title:
		_substitute_title.text = "3→2→3 换人读条\n%s 退场 → %s 上阵" % [out_name, in_name]
	if _substitute_bar:
		_substitute_bar.max_value = sec
		_substitute_bar.value = sec
	_substitute_overlay.visible = true
	if _substitute_timer:
		_substitute_timer.start(sec)


func _ensure_substitute_overlay() -> void:
	if _substitute_overlay != null:
		return
	_substitute_overlay = CanvasLayer.new()
	_substitute_overlay.layer = 49
	add_child(_substitute_overlay)
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.1, 0.14, 0.72)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_substitute_overlay.add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 0)
	center.add_child(vbox)
	_substitute_title = Label.new()
	_substitute_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_substitute_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_substitute_title.add_theme_font_size_override("font_size", 18)
	_substitute_title.modulate = Color(0.8, 0.9, 1.0)
	vbox.add_child(_substitute_title)
	_substitute_bar = ProgressBar.new()
	_substitute_bar.custom_minimum_size = Vector2(280, 18)
	_substitute_bar.show_percentage = false
	vbox.add_child(_substitute_bar)
	_substitute_overlay.visible = false
	_substitute_timer = Timer.new()
	_substitute_timer.one_shot = true
	_substitute_timer.timeout.connect(_hide_substitute_overlay)
	add_child(_substitute_timer)
	var bar_tick := Timer.new()
	bar_tick.wait_time = 0.05
	bar_tick.timeout.connect(_tick_substitute_bar)
	add_child(bar_tick)
	bar_tick.start()


func _tick_substitute_bar() -> void:
	if _substitute_overlay == null or not _substitute_overlay.visible or _substitute_bar == null:
		return
	if _substitute_timer and _substitute_timer.time_left > 0.0:
		_substitute_bar.value = _substitute_timer.time_left


func _hide_substitute_overlay() -> void:
	if _substitute_overlay:
		_substitute_overlay.visible = false


func apply_lane_snapshot(lane: Dictionary) -> void:
	_lane_snapshot = lane
	if _lane_status_label:
		_lane_status_label.text = str(lane.get("status_text", ""))
	if not _last_run_data.is_empty():
		_paint_distance_line(_last_run_data, lane)


func _update_chase_combat_controls(_run_data: Dictionary) -> void:
	# 僵持操作栏由 CombatView 独占，顶栏隐藏旧控件以免挤出视口
	if _chase_toolbar_host:
		_chase_toolbar_host.visible = false
	if _chase_deep_counter_button:
		_chase_deep_counter_button.visible = false
	if _chase_stagger_button:
		_chase_stagger_button.visible = false
	if _chase_stagger_bar:
		_chase_stagger_bar.visible = false


func update_display(run_data: Dictionary, lane: Dictionary = {}) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	_last_run_data = run_data
	if lane.is_empty():
		lane = _lane_snapshot
	_paint_distance_line(run_data, lane)
	if _lane_status_label and lane.has("status_text"):
		_lane_status_label.text = str(lane.get("status_text", ""))
	if _auto_retreat_safe_check:
		var exp_lbl: String = str(run_data.get("expedition_label", ""))
		if exp_lbl != "":
			_auto_retreat_safe_check.text = "策略:%s" % exp_lbl


func _paint_distance_line(run_data: Dictionary, lane: Dictionary) -> void:
	if distance_label == null:
		return
	var map_data = DataLoader.map_data(GameManager.selected_map_id)
	var max_dist: float = float(map_data.get("boss_distance", 600.0)) if not map_data.is_empty() else 600.0
	var cur_dist: float = float(run_data.get("distance", 0))
	if lane.get("freeze_distance", false):
		cur_dist = float(lane.get("display_distance", cur_dist))
	if run_data.get("is_retreating", false):
		var tier_lbl: String = str(run_data.get("retreat_spawn_label", ""))
		var tier_prefix := ""
		if tier_lbl != "":
			tier_prefix = "[%s] " % tier_lbl
		var dest: float = float(run_data.get("retreat_destination", 0))
		var final_dest: float = float(run_data.get("retreat_final_destination", 0))
		var progress: float = float(run_data.get("retreat_progress", 0)) * 100.0
		var dest_label := "大营"
		if dest > 1.0:
			dest_label = "撤离点 %.0fm" % dest
			if final_dest <= 1.0 and dest != cur_dist:
				dest_label += " → 大营"
		distance_label.text = "%s返程: %.0f → %s (%.0f%%)" % [tier_prefix, cur_dist, dest_label, progress]
		var eq_max: int = int(run_data.get("equip_shield_max", 0))
		var eq_cur: int = int(run_data.get("equip_shield", 0))
		var mt_max: int = int(run_data.get("material_shield_max", 0))
		var mt_cur: int = int(run_data.get("material_shield", 0))
		if eq_max + mt_max > 0:
			distance_label.text += "\n护盾 装%d/%d 物%d/%d" % [eq_cur, eq_max, mt_cur, mt_max]
		var ext_line_r: String = str(run_data.get("extract_line_label", ""))
		if ext_line_r != "":
			distance_label.text += "\n" + ext_line_r
		if run_data.get("guard_chase_active", false) and not run_data.get("boss_chase_active", false):
			distance_label.text += "\n撤离物线·守卫加压"
		if run_data.get("boss_chase_active", false):
			var gap: float = float(run_data.get("boss_chase_gap", 9999.0))
			var press: float = float(run_data.get("chase_pressure", 0.0))
			distance_label.text += "\nBoss 追击: %.0fm · 压力 %.0f%%" % [gap, press * 100.0]
			if gap <= 60.0:
				distance_label.modulate = Color(1.0, 0.35, 0.35)
			elif gap <= 120.0:
				distance_label.modulate = Color(1.0, 0.75, 0.35)
			else:
				distance_label.modulate = Color(0.85, 0.95, 1.0)
		else:
			distance_label.modulate = Color.WHITE
	else:
		var exp_lbl: String = str(run_data.get("expedition_label", ""))
		var exp_prefix := "[%s] " % exp_lbl if exp_lbl != "" else ""
		distance_label.text = "%s前进: %.0f / %.0fm" % [exp_prefix, cur_dist, max_dist]
		if exp_lbl != "推图":
			var carry: int = int(run_data.get("carry_value", 0))
			var cth: int = int(run_data.get("carry_value_threshold", 0))
			if cth > 0:
				distance_label.text += "\n携带价值: %d / %d" % [carry, cth]
		else:
			distance_label.text += "\n推图模式 · 仅手动撤离"
		var ext_line: String = str(run_data.get("extract_line_label", ""))
		if ext_line != "":
			distance_label.text += "\n" + ext_line
		distance_label.modulate = Color.WHITE
	
	if withdraw_button and GameManager.current_run:
		withdraw_button.disabled = GameManager.current_run.is_retreating
	
	if _chase_counter_button:
		var chase_on: bool = run_data.get("boss_chase_active", false) and run_data.get("is_retreating", false)
		_chase_counter_button.visible = chase_on
		if chase_on:
			var ready: bool = run_data.get("chase_counter_ready", false)
			var cd: float = float(run_data.get("chase_counter_cooldown", 0.0))
			_chase_counter_button.disabled = not ready
			if ready:
				_chase_counter_button.text = "追击反击"
			elif cd > 0.05:
				_chase_counter_button.text = "反击 %.0fs" % cd
			else:
				_chase_counter_button.text = "反击不可用"
			var gap: float = float(run_data.get("boss_chase_gap", 9999.0))
			if gap <= 18.0:
				_chase_counter_button.tooltip_text = "距离过近，只能接战"
			elif gap > 120.0:
				_chase_counter_button.tooltip_text = "首领尚远，暂无法反击"
			else:
				_chase_counter_button.tooltip_text = "消耗稳定度推远首领并获得击退经验"
	_update_chase_combat_controls(run_data)
	
	if stability_label and not _stability_in_top_bar:
		var team_st: int = int(run_data.get("team_stability", run_data.get("stability", 100)))
		var personal_min: int = int(run_data.get("min_personal_stability", 100))
		var color = Color.GREEN
		if team_st <= 30:
			color = Color.RED
		elif team_st <= 50:
			color = Color.ORANGE
		elif team_st <= 70:
			color = Color.YELLOW
		var pressure: float = float(run_data.get("stability_pressure", 1.0))
		var pressure_hint := ""
		if pressure > 1.01:
			pressure_hint = " [压力×%.1f]" % pressure
		var shield_hint := ""
		if run_data.get("is_retreating", false):
			var eq_max: int = int(run_data.get("equip_shield_max", 0))
			var eq_cur: int = int(run_data.get("equip_shield", 0))
			var mt_max: int = int(run_data.get("material_shield_max", 0))
			var mt_cur: int = int(run_data.get("material_shield", 0))
			if eq_max + mt_max > 0:
				if eq_cur + mt_cur > 0:
					shield_hint = " | 装%d/%d 物%d/%d" % [eq_cur, eq_max, mt_cur, mt_max]
				else:
					shield_hint = " | 护盾已碎"
		var loot_hint := ""
		var safe_n: int = int(run_data.get("safe_loot_count", 0))
		var exp_n: int = int(run_data.get("exposed_loot_count", 0))
		if safe_n > 0 or exp_n > 0:
			loot_hint = " | 箱%d 外露%d" % [safe_n, exp_n]
		stability_label.text = "团队:%d 个人最低:%d%s%s%s" % [
			team_st, personal_min, shield_hint, pressure_hint, loot_hint
		]
		stability_label.modulate = color
	_update_shield_bars(run_data)
	_update_auto_indicator()
