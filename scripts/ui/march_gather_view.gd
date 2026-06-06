class_name MarchGatherView
extends Control
## T-MARCH-V3 骨架 · 采集短演出（GATHER_BEAT 时替代 RunMarchView）


const GATHER_DURATION: float = 0.45

var _prop: ColorRect = null
var _party_blocks: Array[ColorRect] = []
var _active: bool = false
var _timer: float = 0.0
var _event_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_prop = ColorRect.new()
	_prop.color = Color(0.55, 0.42, 0.28, 0.92)
	_prop.custom_minimum_size = Vector2(28, 20)
	_prop.size = Vector2(28, 20)
	_prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prop)
	for i in 3:
		var block := ColorRect.new()
		block.color = Color(0.45, 0.72, 0.95)
		block.custom_minimum_size = Vector2(8, 12)
		block.size = Vector2(8, 12)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(block)
		_party_blocks.append(block)


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
	if _prop:
		_prop.position.y = size.y * 0.28 + bob * 0.3
	for i in _party_blocks.size():
		_party_blocks[i].position.y = size.y * 0.34 + sin(_timer * 10.0 + float(i)) * bob
	if _timer <= 0.0:
		_finish()


func finish_gather() -> void:
	_active = false
	visible = false
	set_process(false)


func _finish() -> void:
	finish_gather()


func _layout_party(retreating: bool) -> void:
	var base_x: float = size.x * 0.28
	var dir: float = -1.0 if retreating else 1.0
	if _prop:
		_prop.position = Vector2(size.x * 0.58, size.y * 0.28)
	for i in _party_blocks.size():
		_party_blocks[i].position = Vector2(base_x + float(i) * 12.0 * dir, size.y * 0.34)
		_party_blocks[i].scale.x = -1.0 if retreating else 1.0
