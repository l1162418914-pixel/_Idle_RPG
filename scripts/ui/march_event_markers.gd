class_name MarchEventMarkers
extends Control
## T-MARCH-V2 · 里程碑标记（读地图 march_events[]，跟 scroll_x）


const HORIZON_START: float = VisualConstants.LANE_HORIZON_START
const HORIZON_SPAN: float = VisualConstants.LANE_HORIZON_SPAN
const PASSED_MARGIN_M: float = 3.0

var _markers: Array[ColorRect] = []
var _last_marker_count: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func get_marker_count() -> int:
	return _last_marker_count


func set_milestones(
	entries: Array,
	scroll_x: float,
	lane_width: float,
	max_distance: float,
	fired_indices: Array = [],
	show_markers: bool = true
) -> void:
	_clear_markers()
	_last_marker_count = 0
	if not show_markers or entries.is_empty() or lane_width <= 1.0 or max_distance <= 0.0:
		visible = false
		return
	visible = true
	for item in entries:
		if item is not Dictionary:
			continue
		var at_dist: float = float(item.get("at_distance", -1.0))
		if at_dist < scroll_x - PASSED_MARGIN_M:
			continue
		var idx: int = int(item.get("index", -1))
		var fired: bool = idx in fired_indices
		var px: float = _distance_to_px(at_dist, scroll_x, lane_width, max_distance)
		if px < -8.0 or px > lane_width + 8.0:
			continue
		var tri := ColorRect.new()
		tri.color = (
			VisualConstants.MILESTONE_FIRED_COLOR
			if fired
			else VisualConstants.MILESTONE_MARKER_COLOR
		)
		tri.custom_minimum_size = VisualConstants.MILESTONE_MARKER_SIZE
		tri.size = VisualConstants.MILESTONE_MARKER_SIZE
		tri.position = Vector2(px, size.y * 0.18)
		tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tri)
		_markers.append(tri)
		_last_marker_count += 1


func set_milestone_markers(distances: Array, scroll_x: float, lane_width: float, max_distance: float) -> void:
	var entries: Array = []
	for i in range(distances.size()):
		entries.append({
			"index": i,
			"at_distance": float(distances[i]),
			"event_id": "",
		})
	set_milestones(entries, scroll_x, lane_width, max_distance, [], true)


func flash_at_distance(distance: float, scroll_x: float, lane_width: float, max_distance: float) -> void:
	if lane_width <= 1.0 or max_distance <= 0.0:
		return
	var px: float = _distance_to_px(distance, scroll_x, lane_width, max_distance)
	var flash := ColorRect.new()
	flash.color = VisualConstants.MILESTONE_FLASH_COLOR
	flash.custom_minimum_size = VisualConstants.MILESTONE_FLASH_SIZE
	flash.size = VisualConstants.MILESTONE_FLASH_SIZE
	flash.position = Vector2(px - 2.0, size.y * 0.16)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_markers.append(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.45)
	tween.tween_callback(flash.queue_free)


func _distance_to_px(distance: float, scroll_x: float, lane_width: float, max_distance: float) -> float:
	var rel: float = distance - scroll_x
	var x_ratio: float = clampf(rel / max_distance, -0.05, 1.05)
	return lane_width * (HORIZON_START + x_ratio * HORIZON_SPAN)


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
