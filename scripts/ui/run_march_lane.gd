class_name RunMarchLane
extends Control
## 出征横版条 · 世界层状态机（T-RUN-V1）
## 只读 WorldRun 快照；禁止在此调用 WorldRun.tick() 或改战斗数值。

enum LaneState {
	IDLE_STANDBY,
	MARCH_ADVANCE,
	COMBAT_ENGAGED,
	MARCH_RETREAT,
	BOSS_ENGAGED,
}

var lane_state: LaneState = LaneState.IDLE_STANDBY
var scroll_x: float = 0.0
var party_anchor_x: float = 0.0

var _in_combat: bool = false
var _is_retreating: bool = false
var _is_boss_combat: bool = false
var _frozen_distance: float = 0.0
var _display_distance: float = 0.0
var _max_distance: float = 600.0
var _combat_freeze_distance: bool = false
var _advance_combat_halt_ok: bool = true

var _placeholder: Label = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder = Label.new()
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder.add_theme_font_size_override("font_size", 11)
	_placeholder.modulate = Color(0.55, 0.7, 0.85)
	add_child(_placeholder)


func on_run_started(run: WorldRun) -> void:
	_in_combat = false
	_is_boss_combat = false
	_advance_combat_halt_ok = true
	if run == null:
		lane_state = LaneState.IDLE_STANDBY
		visible = false
		return
	_max_distance = run.max_distance
	_is_retreating = run.is_retreating
	_frozen_distance = run.distance_traveled
	_display_distance = run.distance_traveled
	scroll_x = run.distance_traveled
	party_anchor_x = run.distance_traveled
	_set_march_state()
	_combat_freeze_distance = false
	_refresh_placeholder()


func on_world_tick(run: WorldRun, world_run_ticked: bool) -> void:
	if run == null:
		return
	_max_distance = run.max_distance
	_is_retreating = run.is_retreating
	var dist: float = run.distance_traveled

	if _in_combat:
		if not _is_retreating:
			if dist > _frozen_distance + 0.001:
				push_warning(
					"RunMarchLane: advance combat distance increased %.2f -> %.2f (expected halt)"
					% [_frozen_distance, dist]
				)
				_advance_combat_halt_ok = false
			_display_distance = _frozen_distance
			scroll_x = _frozen_distance
			lane_state = LaneState.BOSS_ENGAGED if _is_boss_combat else LaneState.COMBAT_ENGAGED
		else:
			_display_distance = dist
			scroll_x = dist
			party_anchor_x = dist
			_frozen_distance = dist
			lane_state = LaneState.BOSS_ENGAGED if _is_boss_combat else LaneState.COMBAT_ENGAGED
	else:
		_display_distance = dist
		scroll_x = dist
		party_anchor_x = dist
		_frozen_distance = dist
		_set_march_state()

	_combat_freeze_distance = _in_combat and not _is_retreating
	_refresh_placeholder()


func on_combat_start(run: WorldRun, is_boss: bool = false) -> void:
	_in_combat = true
	_is_boss_combat = is_boss
	if run:
		_frozen_distance = run.distance_traveled
		_display_distance = run.distance_traveled
		party_anchor_x = run.distance_traveled
		scroll_x = run.distance_traveled
		_is_retreating = run.is_retreating
		_max_distance = run.max_distance
	lane_state = LaneState.BOSS_ENGAGED if is_boss else LaneState.COMBAT_ENGAGED
	_combat_freeze_distance = not _is_retreating
	_refresh_placeholder()


func on_combat_end(run: WorldRun) -> void:
	if not _in_combat:
		return
	_in_combat = false
	_is_boss_combat = false
	_combat_freeze_distance = false
	if run:
		_is_retreating = run.is_retreating
		_display_distance = run.distance_traveled
		scroll_x = run.distance_traveled
		party_anchor_x = run.distance_traveled
		_frozen_distance = run.distance_traveled
	_set_march_state()
	_refresh_placeholder()


func on_run_ended() -> void:
	_in_combat = false
	_is_boss_combat = false
	_combat_freeze_distance = false
	lane_state = LaneState.IDLE_STANDBY
	visible = false
	if _placeholder:
		_placeholder.text = ""


func get_status_text() -> String:
	match lane_state:
		LaneState.MARCH_ADVANCE:
			return "推进中"
		LaneState.MARCH_RETREAT:
			return "返程中"
		LaneState.COMBAT_ENGAGED, LaneState.BOSS_ENGAGED:
			if _is_retreating:
				return "接战中·撤离"
			return "接战中"
		_:
			return ""


func get_snapshot() -> Dictionary:
	return {
		"lane_state": get_lane_state_name(),
		"status_text": get_status_text(),
		"scroll_x": scroll_x,
		"party_anchor_x": party_anchor_x,
		"display_distance": _display_distance,
		"max_distance": _max_distance,
		"freeze_distance": _combat_freeze_distance,
		"advance_combat_halt_ok": _advance_combat_halt_ok,
		"in_combat": _in_combat,
		"is_retreating": _is_retreating,
	}


func get_lane_state_name() -> String:
	match lane_state:
		LaneState.IDLE_STANDBY:
			return "IdleStandby"
		LaneState.MARCH_ADVANCE:
			return "MarchAdvance"
		LaneState.COMBAT_ENGAGED:
			return "CombatEngaged"
		LaneState.MARCH_RETREAT:
			return "MarchRetreat"
		LaneState.BOSS_ENGAGED:
			return "BossEngaged"
		_:
			return "Unknown"


func _set_march_state() -> void:
	if _is_retreating:
		lane_state = LaneState.MARCH_RETREAT
	else:
		lane_state = LaneState.MARCH_ADVANCE


func _refresh_placeholder() -> void:
	if _placeholder == null:
		return
	if lane_state == LaneState.IDLE_STANDBY:
		visible = false
		_placeholder.text = ""
		return
	visible = true
	_placeholder.text = "行军层 · %s · %s · %.0fm" % [
		get_lane_state_name(),
		get_status_text(),
		_display_distance,
	]
