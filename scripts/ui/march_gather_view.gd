class_name MarchGatherView
extends Control
## T-MARCH-V3 · 采集短演出（T-ART-FW-2 VisualSlot）

const _VisualSlotLib = preload("res://scripts/ui/visual_slot.gd")
const GATHER_DURATION: float = 0.45

signal gather_finished(event_id: String)

var _prop_slot = null
var _party_slots: Array = []
var _active: bool = false
var _timer: float = 0.0
var _event_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_prop_slot = _VisualSlotLib.new()
	_prop_slot.slot_id = "gather_prop"
	add_child(_prop_slot)
	_prop_slot.apply_art_key("gather/prop")
	for i in 3:
		var slot = _VisualSlotLib.new()
		slot.slot_id = "gather_party_%d" % i
		add_child(slot)
		slot.apply_art_key("party/silhouette_%d" % i)
		_party_slots.append(slot)


func play_gather(event_id: String, retreating: bool) -> void:
	_event_id = event_id
	_active = true
	_timer = GATHER_DURATION
	visible = true
	set_process(true)
	_layout_party(retreating)


func is_playing() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	var bob: float = sin((GATHER_DURATION - _timer) * 14.0) * 1.5
	if _prop_slot:
		_prop_slot.position.y = size.y * 0.28 + bob * 0.3
	for i in _party_slots.size():
		_party_slots[i].position.y = size.y * 0.34 + sin(_timer * 10.0 + float(i)) * bob
	if _timer <= 0.0:
		_finish()


func finish_gather() -> void:
	_active = false
	visible = false
	set_process(false)


func _finish() -> void:
	var finished_id: String = _event_id
	finish_gather()
	gather_finished.emit(finished_id)


func _layout_party(retreating: bool) -> void:
	var base_x: float = size.x * 0.28
	var dir: float = -1.0 if retreating else 1.0
	if _prop_slot:
		_prop_slot.position = Vector2(size.x * 0.58, size.y * 0.28)
	for i in _party_slots.size():
		_party_slots[i].position = Vector2(base_x + float(i) * 12.0 * dir, size.y * 0.34)
		_party_slots[i].scale.x = -1.0 if retreating else 1.0
