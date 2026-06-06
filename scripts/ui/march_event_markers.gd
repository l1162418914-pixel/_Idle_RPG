class_name MarchEventMarkers
extends Control
## T-MARCH-V2 骨架 · 里程碑/路旁点标记（无美术时色块三角，跟 scroll_x）


const MARKER_COLOR: Color = Color(0.9, 0.75, 0.35, 0.85)

var _markers: Array[ColorRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_milestone_markers(distances: Array, scroll_x: float, lane_width: float, max_distance: float) -> void:
	_clear_markers()
	if distances.is_empty() or lane_width <= 1.0 or max_distance <= 0.0:
		visible = false
		return
	visible = true
	for d in distances:
		var dist: float = float(d)
		var rel: float = dist - scroll_x
		var x_ratio: float = clampf(rel / max_distance, -0.05, 1.05)
		var px: float = lane_width * (0.12 + x_ratio * 0.76)
		if px < -8.0 or px > lane_width + 8.0:
			continue
		var tri := ColorRect.new()
		tri.color = MARKER_COLOR
		tri.custom_minimum_size = Vector2(6, 6)
		tri.size = Vector2(6, 6)
		tri.position = Vector2(px, size.y * 0.18)
		tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tri)
		_markers.append(tri)


func flash_at_distance(distance: float, scroll_x: float, lane_width: float, max_distance: float) -> void:
	if lane_width <= 1.0 or max_distance <= 0.0:
		return
	var rel: float = distance - scroll_x
	var x_ratio: float = clampf(rel / max_distance, 0.0, 1.0)
	var px: float = lane_width * (0.12 + x_ratio * 0.76)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.5, 0.95)
	flash.custom_minimum_size = Vector2(10, 10)
	flash.size = Vector2(10, 10)
	flash.position = Vector2(px - 2.0, size.y * 0.16)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_markers.append(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.45)
	tween.tween_callback(flash.queue_free)


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
