class_name ParallaxBackdrop
extends Control
## T-RUN-V2 · 2～3 层视差背景（T-ART-FW-2 VisualSlot）


const LAYER_SPECS: Array[Dictionary] = VisualConstants.PARALLAX_LAYER_SPECS

var _layer_slots: Array[VisualSlot] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for i in LAYER_SPECS.size():
		var slot := VisualSlot.new()
		slot.slot_id = "parallax_%d" % i
		add_child(slot)
		slot.apply_art_key("parallax/layer_%d" % i)
		_layer_slots.append(slot)
	resized.connect(_layout_layers)
	_layout_layers()


func apply_scroll(
	scroll_x: float,
	retreating: bool,
	frozen: bool,
	speed_mult: float = 1.0
) -> void:
	var dir: float = 0.0
	if not frozen:
		dir = -1.0 if retreating else 1.0
		dir *= clampf(speed_mult, 0.05, 1.0)
	var i := 0
	for spec in LAYER_SPECS:
		if i >= _layer_slots.size():
			break
		var slot: VisualSlot = _layer_slots[i]
		var factor: float = float(spec["factor"])
		var w: float = maxf(size.x * 2.0, 400.0)
		var offset: float = fmod(scroll_x * factor * dir, w)
		slot.position.x = -offset
		i += 1


func first_layer_offset_x() -> float:
	if _layer_slots.is_empty():
		return 0.0
	return _layer_slots[0].position.x


func _layout_layers() -> void:
	var i := 0
	for spec in LAYER_SPECS:
		if i >= _layer_slots.size():
			break
		var slot: VisualSlot = _layer_slots[i]
		var h_ratio: float = float(spec["h"])
		var layer_color: Color = spec.get("color", Color.GRAY)
		var layer_size := Vector2(maxf(size.x * 2.0, 400.0), maxf(4.0, size.y * h_ratio))
		slot.resize_placeholder(layer_size)
		slot.set_placeholder_color(layer_color)
		slot.position.y = size.y * (1.0 - h_ratio)
		i += 1
