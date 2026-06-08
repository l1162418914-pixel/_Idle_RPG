extends Control
class_name StageShell
## T-UI-TWIN-1 · StageWindow 表演壳（BottomStage / RunMarchLane / CombatView）

const STAGE_MIN_HEIGHT := 220
const BOTTOM_STAGE_HEAL_REFRESH_MS := 3000

var _run_ui: Control = null
var _planning_shell: MainShell = null
var _combat_view: CombatView = null
var _run_controls_host: VBoxContainer = null
var _march_lane_host: Control = null
var _run_march_lane: RunMarchLane = null
var _combat_host: VBoxContainer = null
var _standby_label: Label = null
var _bottom_stage: BottomStage = null
var _stage_bar: VBoxContainer = null
var _last_bottom_stage_heal_refresh_msec: int = 0
var _shell_built: bool = false


func setup(run_ui: Control, planning_shell: MainShell = null) -> void:
	_run_ui = run_ui
	_planning_shell = planning_shell
	_ensure_shell_built()
	_embed_run_combat()
	_connect_signals()
	_apply_stage_bar_mouse_policy()
	call_deferred("apply_state", GameManager.state)


func get_combat_view() -> CombatView:
	return _combat_view


func get_run_march_lane() -> RunMarchLane:
	return _run_march_lane


func pulse_stage_focus(seconds: float = 2.0) -> void:
	if _bottom_stage == null or not _bottom_stage.visible:
		return
	var orig: Color = _bottom_stage.modulate
	_bottom_stage.modulate = Color(1.06, 1.0, 0.92)
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds * 0.85))
	tween.tween_property(_bottom_stage, "modulate", orig, maxf(0.1, seconds * 0.15))


func apply_state(state: int) -> void:
	_update_run_bar_mode(state)
	_refresh_bottom_stage(state)
	if _run_ui:
		_run_ui.visible = state == GameManager.GameState.RUNNING


func _ensure_shell_built() -> void:
	if _shell_built:
		return
	_shell_built = true
	name = "StageShell"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_bar = VBoxContainer.new()
	_stage_bar.name = "StageBar"
	_stage_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_bar.offset_left = 0
	_stage_bar.offset_top = 0
	_stage_bar.offset_right = 0
	_stage_bar.offset_bottom = 0
	_stage_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage_bar.add_theme_constant_override("separation", 4)
	_stage_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_bar.clip_contents = true
	add_child(_stage_bar)
	_run_controls_host = VBoxContainer.new()
	_run_controls_host.name = "RunControlsHost"
	_run_controls_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_run_controls_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_bar.add_child(_run_controls_host)
	_march_lane_host = Control.new()
	_march_lane_host.name = "MarchLaneHost"
	_march_lane_host.custom_minimum_size = Vector2(0, 52)
	_march_lane_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_march_lane_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_bar.add_child(_march_lane_host)
	_run_march_lane = RunMarchLane.new()
	_run_march_lane.name = "RunMarchLane"
	_run_march_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_march_lane_host.add_child(_run_march_lane)
	_combat_host = VBoxContainer.new()
	_combat_host.name = "CombatHost"
	_combat_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_bar.add_child(_combat_host)
	_bottom_stage = BottomStage.new()
	_bottom_stage.name = "BottomStage"
	_bottom_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_stage.visible = false
	_stage_bar.add_child(_bottom_stage)
	_standby_label = Label.new()
	_standby_label.name = "StandbyLabel"
	_standby_label.text = "营火边陲 — 选择地图出征"
	_standby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_standby_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_standby_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_standby_label.add_theme_font_size_override("font_size", 14)
	_standby_label.modulate = Color(0.65, 0.75, 0.9)
	_standby_label.visible = false
	_standby_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_bar.add_child(_standby_label)


func _embed_run_combat() -> void:
	if _run_ui:
		_mount_in_slot(_run_ui, _run_controls_host)
		if _run_ui.has_method("bind_main_shell") and _planning_shell:
			_run_ui.bind_main_shell(_planning_shell)
		var combat_node := _run_ui.get_node_or_null("MarginContainer/MainVBox/CombatView")
		if combat_node:
			_combat_view = combat_node as CombatView
			_mount_in_slot(_combat_view, _combat_host)
			_combat_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var bf := _combat_view.get_node_or_null("BattlefieldHBox") as Control
			if bf:
				bf.custom_minimum_size = Vector2(0, 120)
	_apply_stage_bar_mouse_policy()


func _mount_in_slot(node: Control, slot: Control) -> void:
	if node == null or slot == null:
		return
	var parent := node.get_parent()
	if parent != slot:
		if parent:
			parent.remove_child(node)
		slot.add_child(node)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _apply_stage_bar_mouse_policy() -> void:
	if _stage_bar:
		_stage_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _combat_host:
		_combat_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _march_lane_host:
		_march_lane_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _run_controls_host:
		_run_controls_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _combat_view:
		_combat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var toolbar := _combat_view.get_node_or_null("DebugToolbar") as Control
		if toolbar:
			toolbar.mouse_filter = Control.MOUSE_FILTER_STOP


func _connect_signals() -> void:
	if not GameManager.formation_changed.is_connected(_on_formation_changed):
		GameManager.formation_changed.connect(_on_formation_changed)
	if not GameManager.formation_preference_changed.is_connected(_on_formation_preference_changed):
		GameManager.formation_preference_changed.connect(_on_formation_preference_changed)
	if not GameManager.roster_healed.is_connected(_on_roster_healed):
		GameManager.roster_healed.connect(_on_roster_healed)


func _on_formation_changed() -> void:
	call_deferred("_refresh_bottom_stage", GameManager.state)


func _on_formation_preference_changed(_half: String) -> void:
	call_deferred("_refresh_bottom_stage", GameManager.state)


func _on_roster_healed() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_bottom_stage_heal_refresh_msec >= BOTTOM_STAGE_HEAL_REFRESH_MS:
		_last_bottom_stage_heal_refresh_msec = now_msec
		_refresh_bottom_stage(GameManager.state)


func _refresh_bottom_stage(state: int = GameManager.state) -> void:
	if _bottom_stage == null:
		return
	if state == GameManager.GameState.RUNNING:
		return
	if state in [
		GameManager.GameState.BASE,
		GameManager.GameState.PREPARE,
		GameManager.GameState.RESULT,
	]:
		_bottom_stage.apply_game_state(state)


func _update_run_bar_mode(state: int) -> void:
	if _standby_label:
		_standby_label.visible = false
	var show_camp_stage := false
	var show_run_stage := false
	match state:
		GameManager.GameState.BASE, GameManager.GameState.PREPARE, GameManager.GameState.RESULT:
			show_camp_stage = true
		GameManager.GameState.RUNNING:
			show_run_stage = true
		_:
			show_camp_stage = false
			show_run_stage = false
	if _bottom_stage:
		_bottom_stage.visible = show_camp_stage
	if _run_controls_host:
		_run_controls_host.visible = show_run_stage
	if _march_lane_host:
		_march_lane_host.visible = show_run_stage
	if _combat_host:
		_combat_host.visible = show_run_stage
	if _combat_view:
		_combat_view.visible = show_run_stage
