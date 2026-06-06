class_name RunMarchLane
extends Control

signal gather_beat_finished(event_id: String)

const _ParallaxBackdropScene = preload("res://scripts/ui/parallax_backdrop.gd")
const _RunMarchViewScene = preload("res://scripts/ui/run_march_view.gd")
const _BossChaseSilhouetteScene = preload("res://scripts/ui/boss_chase_silhouette.gd")
const _MarchEventMarkersScene = preload("res://scripts/ui/march_event_markers.gd")
const _MarchGatherViewScene = preload("res://scripts/ui/march_gather_view.gd")
const _MarchSearchToastScene = preload("res://scripts/ui/march_search_toast.gd")
const _MarchEventService = preload("res://scripts/run/march_event_service.gd")
const RETREAT_COMBAT_PARALLAX_MULT: float = 0.55
const COMBAT_RESUME_DELAY_SEC: float = 0.3
## 出征横版条 · 世界层状态机（T-RUN-V1）
## 只读 WorldRun 快照；禁止在此调用 WorldRun.tick() 或改战斗数值。

enum LaneState {
	IDLE_STANDBY,
	MARCH_ADVANCE,
	COMBAT_ENGAGED,
	MARCH_RETREAT,
	BOSS_ENGAGED,
	GATHER_BEAT,
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
var _parallax: Control = null
var _march_view: Control = null
var _boss_chase_silhouette: Control = null
var _event_markers: Control = null
var _gather_view: Control = null
var _search_toast: Control = null
var _party_count: int = 3
var _gather_active: bool = false
var _boss_chase_active: bool = false
var _boss_chase_gap: float = 9999.0
var _pending_march_after_combat: bool = false
var _combat_resume_timer: float = 0.0
var _milestone_entries: Array = []
var _fired_milestone_indices: Array = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 48)
	_parallax = _ParallaxBackdropScene.new()
	_parallax.name = "ParallaxBackdrop"
	_parallax.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parallax.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parallax.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_parallax)
	_march_view = _RunMarchViewScene.new()
	_march_view.name = "RunMarchView"
	_march_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_march_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_march_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_march_view)
	_boss_chase_silhouette = _BossChaseSilhouetteScene.new()
	_boss_chase_silhouette.name = "BossChaseSilhouette"
	_boss_chase_silhouette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_chase_silhouette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_chase_silhouette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_boss_chase_silhouette)
	_event_markers = _MarchEventMarkersScene.new()
	_event_markers.name = "MarchEventMarkers"
	_event_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_markers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_markers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_event_markers)
	_gather_view = _MarchGatherViewScene.new()
	_gather_view.name = "MarchGatherView"
	_gather_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gather_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gather_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_gather_view)
	_search_toast = _MarchSearchToastScene.new()
	_search_toast.name = "MarchSearchToast"
	if _gather_view and _gather_view.has_signal("gather_finished"):
		_gather_view.gather_finished.connect(_on_gather_view_finished)
	_search_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_search_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_toast.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_search_toast)
	_placeholder = Label.new()
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placeholder.size_flags_vertical = Control.SIZE_SHRINK_END
	_placeholder.add_theme_font_size_override("font_size", 10)
	_placeholder.modulate = Color(0.55, 0.7, 0.85)
	add_child(_placeholder)


func is_gather_active() -> bool:
	return _gather_active


func show_search_toast(data: Dictionary) -> void:
	if _search_toast and _search_toast.has_method("show_search"):
		_search_toast.show_search(data)


func on_march_event(data: Dictionary) -> void:
	if _event_markers and _event_markers.has_method("flash_at_distance"):
		_event_markers.flash_at_distance(
			float(data.get("at_distance", data.get("distance", 0.0))),
			scroll_x,
			size.x,
			_max_distance
		)
	if bool(data.get("gather_beat", false)):
		on_gather_start(str(data.get("event_id", "")))
		return


func on_gather_start(event_id: String = "") -> void:
	_gather_active = true
	_pending_march_after_combat = false
	_combat_resume_timer = 0.0
	set_process(false)
	_frozen_distance = _display_distance
	scroll_x = _frozen_distance
	lane_state = LaneState.GATHER_BEAT
	_combat_freeze_distance = true
	if _gather_view and _gather_view.has_method("play_gather"):
		_gather_view.play_gather(event_id, _is_retreating)
	_refresh_visuals()


func on_gather_end() -> void:
	if not _gather_active:
		return
	_gather_active = false
	_combat_freeze_distance = false
	if _gather_view and _gather_view.has_method("finish_gather"):
		_gather_view.finish_gather()
	_set_march_state()
	_refresh_visuals()


func _on_gather_view_finished(event_id: String) -> void:
	on_gather_end()
	gather_beat_finished.emit(event_id)


func on_run_started(run: WorldRun, party_count: int = 3) -> void:
	_in_combat = false
	_is_boss_combat = false
	_gather_active = false
	_pending_march_after_combat = false
	_combat_resume_timer = 0.0
	set_process(false)
	_advance_combat_halt_ok = true
	_party_count = maxi(1, party_count)
	if run == null:
		lane_state = LaneState.IDLE_STANDBY
		visible = false
		return
	_max_distance = run.max_distance
	_milestone_entries = _MarchEventService.milestone_entries(run.map_data)
	_fired_milestone_indices = run.march_events_fired.duplicate()
	_is_retreating = run.is_retreating
	_frozen_distance = run.distance_traveled
	_display_distance = run.distance_traveled
	scroll_x = run.distance_traveled
	party_anchor_x = run.distance_traveled
	_set_march_state()
	_combat_freeze_distance = false
	_refresh_visuals()


func on_world_tick(run: WorldRun, world_run_ticked: bool) -> void:
	if run == null:
		return
	_max_distance = run.max_distance
	_is_retreating = run.is_retreating
	_boss_chase_active = run.boss_chase_active
	_boss_chase_gap = run.get_boss_chase_gap()
	_fired_milestone_indices = run.march_events_fired.duplicate()
	var dist: float = run.distance_traveled

	if _gather_active:
		_display_distance = _frozen_distance
		scroll_x = _frozen_distance
		lane_state = LaneState.GATHER_BEAT
	elif _in_combat:
		var freeze_dist: bool = not _is_retreating or _is_boss_combat
		if freeze_dist:
			if not _is_retreating and dist > _frozen_distance + 0.001:
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
			lane_state = LaneState.COMBAT_ENGAGED
	else:
		_display_distance = dist
		scroll_x = dist
		party_anchor_x = dist
		_frozen_distance = dist
		if not _pending_march_after_combat:
			_set_march_state()

	_combat_freeze_distance = _gather_active or (_in_combat and (not _is_retreating or _is_boss_combat))
	_refresh_visuals()


func _process(delta: float) -> void:
	if not _pending_march_after_combat:
		return
	_combat_resume_timer -= delta
	if _combat_resume_timer <= 0.0:
		_finish_combat_resume()


func advance_combat_resume(delta: float) -> void:
	if not _pending_march_after_combat:
		return
	_combat_resume_timer -= delta
	if _combat_resume_timer <= 0.0:
		_finish_combat_resume()


func _finish_combat_resume() -> void:
	_pending_march_after_combat = false
	_combat_resume_timer = 0.0
	set_process(false)
	_set_march_state()
	_refresh_visuals()


func _visual_in_combat() -> bool:
	return _in_combat or _pending_march_after_combat


func on_combat_start(run: WorldRun, is_boss: bool = false) -> void:
	_pending_march_after_combat = false
	_combat_resume_timer = 0.0
	set_process(false)
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
	_combat_freeze_distance = not _is_retreating or is_boss
	_refresh_visuals()


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
		_boss_chase_active = run.boss_chase_active
		_boss_chase_gap = run.get_boss_chase_gap()
	_pending_march_after_combat = true
	_combat_resume_timer = COMBAT_RESUME_DELAY_SEC
	set_process(true)
	_refresh_visuals()


func on_run_ended() -> void:
	_in_combat = false
	_is_boss_combat = false
	_gather_active = false
	_pending_march_after_combat = false
	_combat_resume_timer = 0.0
	set_process(false)
	_combat_freeze_distance = false
	lane_state = LaneState.IDLE_STANDBY
	visible = false
	if _placeholder:
		_placeholder.text = ""
	if _march_view:
		_march_view.visible = false
	if _parallax:
		_parallax.visible = false


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
		LaneState.GATHER_BEAT:
			return "搜刮中"
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
		"combat_resume_pending": _pending_march_after_combat,
		"combat_resume_remaining": _combat_resume_timer,
		"boss_chase_silhouette_visible": (
			_boss_chase_silhouette != null and _boss_chase_silhouette.is_visible_chase()
		),
		"boss_chase_gap": _boss_chase_gap,
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
		LaneState.GATHER_BEAT:
			return "GatherBeat"
		_:
			return "Unknown"


func _set_march_state() -> void:
	if _gather_active:
		lane_state = LaneState.GATHER_BEAT
		return
	if _is_retreating:
		lane_state = LaneState.MARCH_RETREAT
	else:
		lane_state = LaneState.MARCH_ADVANCE


func _refresh_visuals() -> void:
	if lane_state == LaneState.IDLE_STANDBY:
		visible = false
		if _placeholder:
			_placeholder.text = ""
		if _march_view:
			_march_view.visible = false
		if _parallax:
			_parallax.visible = false
		return
	visible = true
	var frozen: bool = _combat_freeze_distance
	var parallax_speed: float = 1.0
	if _in_combat and _is_retreating and not frozen:
		parallax_speed = RETREAT_COMBAT_PARALLAX_MULT
	if _parallax:
		_parallax.visible = true
		_parallax.apply_scroll(scroll_x, _is_retreating, frozen, parallax_speed)
	var visual_busy: bool = _visual_in_combat() or _gather_active
	if _march_view:
		_march_view.apply_lane(lane_state, _is_retreating, visual_busy, _party_count)
	if _gather_view:
		_gather_view.visible = _gather_active
	if _event_markers and _event_markers.has_method("set_milestones"):
		var show_milestones: bool = (
			not _is_retreating
			and not visual_busy
			and lane_state == LaneState.MARCH_ADVANCE
		)
		_event_markers.set_milestones(
			_milestone_entries,
			scroll_x,
			size.x,
			_max_distance,
			_fired_milestone_indices,
			show_milestones
		)
	if _boss_chase_silhouette:
		_boss_chase_silhouette.apply_chase(
			_boss_chase_active,
			_boss_chase_gap,
			visual_busy,
			_is_retreating,
			size.x
		)
	if _placeholder:
		_placeholder.text = "%s · %s · %.0fm" % [
			get_lane_state_name(),
			get_status_text(),
			_display_distance,
		]
