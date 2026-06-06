class_name MarchEventMarkers
extends Control
## T-MARCH-V2 · 里程碑标记（占位色块；与 VisualConstants 里程碑色一致）

const HORIZON_START: float = 0.12
const HORIZON_SPAN: float = 0.76
const PASSED_MARGIN_M: float = 3.0
const MARKER_COLOR: Color = Color(0.9, 0.75, 0.35, 0.85)
const FIRED_COLOR: Color = Color(0.55, 0.5, 0.4, 0.42)
const FLASH_COLOR: Color = Color(1.0, 0.9, 0.5, 0.95)
const MARKER_SIZE: Vector2 = Vector2(6, 6)
const FLASH_SIZE: Vector2 = Vector2(10, 10)

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
		if not item is Dictionary:
			continue
		var at_dist: float = float(item.get("at_distance", -1.0))
		if at_dist < scroll_x - PASSED_MARGIN_M:
			continue
		var idx: int = int(item.get("index", -1))
		var fired: bool = idx in fired_indices
		var px: float = _distance_to_px(at_dist, scroll_x, lane_width, max_distance)
		if px < -8.0 or px > lane_width + 8.0:
			continue
		var marker := _make_block(FIRED_COLOR if fired else MARKER_COLOR, MARKER_SIZE)
		add_child(marker)
		marker.position = Vector2(px, size.y * 0.18)
		_markers.append(marker)
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
	var flash := _make_block(FLASH_COLOR, FLASH_SIZE)
	add_child(flash)
	flash.position = Vector2(px - 2.0, size.y * 0.16)
	_markers.append(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.45)
	tween.tween_callback(flash.queue_free)


func _make_block(color: Color, pixel_size: Vector2) -> ColorRect:
	var block := ColorRect.new()
	block.color = color
	block.custom_minimum_size = pixel_size
	block.size = pixel_size
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return block


func _distance_to_px(distance: float, scroll_x: float, lane_width: float, max_distance: float) -> float:
	var rel: float = distance - scroll_x
	var x_ratio: float = clampf(rel / max_distance, -0.05, 1.05)
	return lane_width * (HORIZON_START + x_ratio * HORIZON_SPAN)


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
