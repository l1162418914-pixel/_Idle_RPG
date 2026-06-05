extends Control
## RunUI — 出征中界面，显示距离、稳定度（战斗可视化由 CombatView 负责）

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


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	if withdraw_button:
		withdraw_button.pressed.connect(_on_withdraw_pressed)
		_setup_auto_controls()
		_setup_shield_bars()


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
	_auto_retreat_safe_check.text = "自动撤:仅安全箱"
	_auto_retreat_safe_check.tooltip_text = "携带价值只统计安全箱时勾选"
	_auto_retreat_safe_check.button_pressed = GameManager.auto_retreat_safe_only
	_auto_retreat_safe_check.toggled.connect(_on_auto_retreat_safe_toggled)
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
	var parent := run_hint_label.get_parent() if run_hint_label else null
	if parent:
		_chase_stagger_bar = ProgressBar.new()
		_chase_stagger_bar.visible = false
		_chase_stagger_bar.custom_minimum_size = Vector2(200, 12)
		_chase_stagger_bar.max_value = 1.0
		_chase_stagger_bar.show_percentage = false
		parent.add_child(_chase_stagger_bar)
		parent.move_child(_chase_stagger_bar, run_hint_label.get_index())


func _process(_delta: float) -> void:
	var run = GameManager.current_run
	if run:
		run.chase_stagger_holding = _stagger_hold and run.chase_combat_in_progress


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


func _on_auto_retreat_safe_toggled(pressed: bool) -> void:
	GameManager.auto_retreat_safe_only = pressed


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


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.RUNNING)


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


func show_run_hint(text: String, color: Color = Color.WHITE) -> void:
	if run_hint_label:
		run_hint_label.text = text
		run_hint_label.modulate = color


func update_display(run_data: Dictionary) -> void:
	if not visible:
		return
	
	if distance_label:
		var map_data = DataLoader.map_data(GameManager.selected_map_id)
		var max_dist: float = float(map_data.get("boss_distance", 600.0)) if not map_data.is_empty() else 600.0
		var cur_dist: float = float(run_data.get("distance", 0))
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
			distance_label.text = "前进: %.0f / %.0fm" % [cur_dist, max_dist]
			var carry: int = int(run_data.get("carry_value", 0))
			var cth: int = int(run_data.get("carry_value_threshold", 0))
			if cth > 0:
				distance_label.text += "\n携带价值: %d / %d" % [carry, cth]
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
	if _chase_deep_counter_button:
		var deep_on: bool = run_data.get("chase_combat_in_progress", false)
		_chase_deep_counter_button.visible = deep_on
		if deep_on:
			var d_ready: bool = run_data.get("chase_deep_counter_ready", false)
			var d_cd: float = float(run_data.get("chase_deep_counter_cooldown", 0.0))
			_chase_deep_counter_button.disabled = not d_ready
			var charge: float = float(run_data.get("chase_stagger_charge", 0.0))
			var min_ch: float = 0.22
			if GameManager.current_run != null:
				min_ch = float(
					GameManager.current_run.map_data.get("chase_deep_counter_min_charge", 0.22)
				)
			if d_ready:
				_chase_deep_counter_button.text = "深度反击"
			elif d_cd > 0.05:
				_chase_deep_counter_button.text = "深度 %.0fs" % d_cd
			else:
				_chase_deep_counter_button.text = "深度蓄力中"
			_chase_deep_counter_button.tooltip_text = (
				"僵持蓄力≥%.0f%% 时重创首领并推远（高稳定消耗，不击杀）" % (min_ch * 100.0)
				if charge < min_ch
				else "消耗较多稳定度重创首领并推远（不击杀）"
			)
	if _chase_stagger_button:
		var run_ref = GameManager.current_run
		_chase_stagger_button.visible = run_ref != null and run_ref.chase_combat_in_progress
		var charge: float = float(run_data.get("chase_stagger_charge", 0.0))
		if charge < 0.92:
			_chase_stagger_button.text = "蓄力 %.0f%%" % (charge * 100.0)
		else:
			_chase_stagger_button.text = "松开击退!"
	if _chase_stagger_bar:
		var show_bar: bool = (
			GameManager.current_run != null and GameManager.current_run.chase_combat_in_progress
		)
		_chase_stagger_bar.visible = show_bar
		if show_bar:
			_chase_stagger_bar.value = float(run_data.get("chase_stagger_charge", 0.0))
	
	if stability_label:
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
