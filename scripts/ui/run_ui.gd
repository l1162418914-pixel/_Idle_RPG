extends Control
## RunUI — 出征中界面，显示距离、稳定度（战斗可视化由 CombatView 负责）

@onready var distance_label: Label = $MarginContainer/MainVBox/InfoHBox/DistanceLabel
@onready var stability_label: Label = $MarginContainer/MainVBox/InfoHBox/StabilityLabel
@onready var withdraw_button: Button = $MarginContainer/MainVBox/InfoHBox/WithdrawButton
@onready var run_hint_label: Label = $MarginContainer/MainVBox/RunHintLabel

var _auto_status_label: Label = null
var _stop_auto_button: Button = null


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	if withdraw_button:
		withdraw_button.pressed.connect(_on_withdraw_pressed)
		_setup_auto_controls()


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


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.RUNNING)


func _on_withdraw_pressed() -> void:
	var main = get_tree().current_scene
	if main and main.has_method("_on_manual_withdraw_pressed"):
		main._on_manual_withdraw_pressed()


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
			var dest: float = float(run_data.get("retreat_destination", 0))
			var final_dest: float = float(run_data.get("retreat_final_destination", 0))
			var progress: float = float(run_data.get("retreat_progress", 0)) * 100.0
			var dest_label := "大营"
			if dest > 1.0:
				dest_label = "撤离点 %.0fm" % dest
				if final_dest <= 1.0 and dest != cur_dist:
					dest_label += " → 大营"
			distance_label.text = "返程: %.0f → %s (%.0f%%)" % [cur_dist, dest_label, progress]
			var sh_max: int = int(run_data.get("retreat_shield_max", 0))
			var sh_cur: int = int(run_data.get("retreat_shield", 0))
			if sh_max > 0:
				distance_label.text += "\n护卫护盾: %d/%d" % [sh_cur, sh_max]
			if run_data.get("boss_chase_active", false):
				var gap: float = float(run_data.get("boss_chase_gap", 9999.0))
				distance_label.text += "\nBoss 追击: %.0fm" % gap
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
			distance_label.modulate = Color.WHITE
	
	if withdraw_button and GameManager.current_run:
		withdraw_button.disabled = GameManager.current_run.is_retreating
	
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
			var sh_max: int = int(run_data.get("retreat_shield_max", 0))
			var sh_cur: int = int(run_data.get("retreat_shield", 0))
			if sh_max > 0:
				if sh_cur > 0:
					shield_hint = " | 护盾%d/%d" % [sh_cur, sh_max]
				else:
					shield_hint = " | 护盾已碎"
		stability_label.text = "团队:%d 个人最低:%d%s%s" % [team_st, personal_min, shield_hint, pressure_hint]
		stability_label.modulate = color
	_update_auto_indicator()
