class_name BossChaseSilhouette
extends Control
## T-RUN-V5 · 返程 Boss 追击剪影（右侧逼近，只读 chase gap）


const WARN_GAP: float = 120.0
const DANGER_GAP: float = 60.0
const CATCH_GAP: float = 18.0

var _body: ColorRect = null
var _crown: ColorRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body = ColorRect.new()
	_body.color = Color(0.72, 0.18, 0.14, 0.92)
	_body.custom_minimum_size = Vector2(22, 32)
	_body.size = Vector2(22, 32)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_crown = ColorRect.new()
	_crown.color = Color(0.9, 0.35, 0.2, 0.95)
	_crown.custom_minimum_size = Vector2(14, 8)
	_crown.size = Vector2(14, 8)
	_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crown)
	visible = false


func apply_chase(
	active: bool,
	gap: float,
	in_combat: bool,
	retreating: bool,
	lane_width: float
) -> void:
	if not active or in_combat or not retreating or lane_width <= 1.0:
		visible = false
		return
	visible = true
	var threat: float = 1.0 - clampf(gap / WARN_GAP, 0.0, 1.0)
	var x_ratio: float = lerpf(0.88, 0.42, threat)
	var base_x: float = lane_width * x_ratio
	var bob: float = sin(Time.get_ticks_msec() * 0.006) * 1.5
	_body.position = Vector2(base_x, size.y * 0.22 + bob)
	_crown.position = Vector2(base_x + 4.0, size.y * 0.12 + bob)
	var scale_v: float = lerpf(1.0, 1.22, threat)
	_body.scale = Vector2(scale_v, scale_v)
	_crown.scale = Vector2(scale_v, scale_v)
	if gap <= CATCH_GAP:
		_body.color = Color(1.0, 0.25, 0.12, 0.98)
	elif gap <= DANGER_GAP:
		_body.color = Color(0.85, 0.2, 0.12, 0.95)
	else:
		_body.color = Color(0.72, 0.18, 0.14, 0.88)


func is_visible_chase() -> bool:
	return visible


func get_body_x() -> float:
	return _body.position.x if _body else -1.0
