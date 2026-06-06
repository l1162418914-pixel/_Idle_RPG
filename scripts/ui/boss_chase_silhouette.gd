class_name BossChaseSilhouette
extends Control
## T-RUN-V5 · 返程 Boss 追击剪影（T-ART-FW-2 VisualSlot）


const WARN_GAP: float = 120.0
const DANGER_GAP: float = 60.0
const CATCH_GAP: float = 18.0

var _body_slot: VisualSlot = null
var _crown_slot: VisualSlot = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_slot = VisualSlot.new()
	_body_slot.slot_id = "boss_chase_body"
	add_child(_body_slot)
	_body_slot.apply_art_key("boss_chase/body")
	_crown_slot = VisualSlot.new()
	_crown_slot.slot_id = "boss_chase_crown"
	add_child(_crown_slot)
	_crown_slot.apply_art_key("boss_chase/crown")
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
	var base_x: float = lane_width * lerpf(0.88, 0.42, threat)
	var bob: float = sin(Time.get_ticks_msec() * 0.006) * 1.5
	_body_slot.position = Vector2(base_x, size.y * 0.22 + bob)
	_crown_slot.position = Vector2(base_x + 4.0, size.y * 0.12 + bob)
	var scale_v: float = lerpf(1.0, 1.22, threat)
	_body_slot.scale = Vector2(scale_v, scale_v)
	_crown_slot.scale = Vector2(scale_v, scale_v)
	if gap <= CATCH_GAP:
		_body_slot.set_placeholder_color(VisualConstants.BOSS_CHASE_CATCH_BODY_COLOR)
	elif gap <= DANGER_GAP:
		_body_slot.set_placeholder_color(VisualConstants.BOSS_CHASE_DANGER_BODY_COLOR)
	else:
		_body_slot.set_placeholder_color(VisualConstants.BOSS_CHASE_BODY_COLOR)


func is_visible_chase() -> bool:
	return visible


func get_body_x() -> float:
	return _body_slot.position.x if _body_slot else -1.0
