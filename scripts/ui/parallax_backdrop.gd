class_name ParallaxBackdrop
extends Control
## T-RUN-V2 · 2～3 层视差背景（只读 scroll_x，不改战斗数值）


const LAYER_SPECS: Array[Dictionary] = [
	{"color": Color(0.12, 0.16, 0.22, 1.0), "factor": 0.15, "h": 1.0},
	{"color": Color(0.18, 0.24, 0.32, 1.0), "factor": 0.35, "h": 0.55},
	{"color": Color(0.28, 0.36, 0.46, 1.0), "factor": 0.65, "h": 0.28},
]

var _layers: Array[ColorRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for spec in LAYER_SPECS:
		var layer := ColorRect.new()
		layer.color = spec["color"]
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		_layers.append(layer)
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
		# 进军：里程增 → 层向左移；返程：里程减 → 层仍向左移（朝大营）
		dir = -1.0 if retreating else 1.0
		dir *= clampf(speed_mult, 0.05, 1.0)
	var i := 0
	for spec in LAYER_SPECS:
		if i >= _layers.size():
			break
		var layer: ColorRect = _layers[i]
		var factor: float = float(spec["factor"])
		var w: float = maxf(size.x * 2.0, 400.0)
		var offset: float = fmod(scroll_x * factor * dir, w)
		layer.position.x = -offset
		i += 1


func first_layer_offset_x() -> float:
	if _layers.is_empty():
		return 0.0
	return _layers[0].position.x


func _layout_layers() -> void:
	var i := 0
	for spec in LAYER_SPECS:
		if i >= _layers.size():
			break
		var layer: ColorRect = _layers[i]
		var h_ratio: float = float(spec["h"])
		layer.size = Vector2(maxf(size.x * 2.0, 400.0), maxf(4.0, size.y * h_ratio))
		layer.position.y = size.y * (1.0 - h_ratio)
		i += 1
