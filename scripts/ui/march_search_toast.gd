class_name MarchSearchToast
extends Control
## T-MARCH-V1 · 【搜索】飘字（行军不停滚，叠在 RunMarchLane 最前）


const MAX_TOASTS: int = 4
const TOAST_LIFETIME: float = 1.8
const TOAST_COLOR: Color = Color(0.72, 0.88, 0.95, 0.95)
const TOAST_COLOR_LOOT: Color = Color(0.85, 0.95, 0.75, 0.98)
const TOAST_COLOR_RISK: Color = Color(0.95, 0.72, 0.55, 0.98)

var _slots: Array[Label] = []
var _slot_timers: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_TOASTS:
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.modulate = TOAST_COLOR
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		_slots.append(lbl)
		_slot_timers.append(0.0)
	resized.connect(_layout_slots)


func show_search(data: Dictionary) -> void:
	var text: String = _format_text(data)
	var color: Color = _pick_color(data)
	var slot_idx: int = _acquire_slot()
	if slot_idx < 0:
		slot_idx = 0
	var lbl: Label = _slots[slot_idx]
	lbl.text = text
	lbl.modulate = color
	lbl.visible = true
	_slot_timers[slot_idx] = TOAST_LIFETIME
	_layout_slots()


func _process(delta: float) -> void:
	var any: bool = false
	for i in _slots.size():
		if not _slots[i].visible:
			continue
		_slot_timers[i] -= delta
		if _slot_timers[i] <= 0.0:
			_slots[i].visible = false
		else:
			any = true
			var t: float = clampf(_slot_timers[i] / TOAST_LIFETIME, 0.0, 1.0)
			_slots[i].modulate.a = lerpf(0.25, 1.0, t)
	if not any:
		set_process(false)


func _acquire_slot() -> int:
	for i in _slots.size():
		if not _slots[i].visible:
			set_process(true)
			return i
	set_process(true)
	return 0


func _format_text(data: Dictionary) -> String:
	var log: String = str(data.get("log", "搜索检定。"))
	var result: String = str(data.get("result", "empty"))
	var extra: String = ""
	match result:
		"gold":
			extra = " +%d金" % int(data.get("gold", 0))
		"material":
			var name: String = str(data.get("material_name", ""))
			if name != "":
				extra = " [%s]" % name
		"stability":
			var d: int = int(data.get("team_delta", 0))
			if d != 0:
				extra = " 稳定%+d" % d
	return "【搜索】%s%s" % [log, extra]


func _pick_color(data: Dictionary) -> Color:
	var result: String = str(data.get("result", "empty"))
	match result:
		"gold", "material":
			return TOAST_COLOR_LOOT
		"stability":
			if int(data.get("team_delta", 0)) < 0:
				return TOAST_COLOR_RISK
			return TOAST_COLOR_LOOT
		_:
			return TOAST_COLOR


func _layout_slots() -> void:
	var base_y: float = size.y * 0.08
	var spacing: float = 14.0
	for i in _slots.size():
		var lbl: Label = _slots[i]
		if not lbl.visible:
			continue
		lbl.position = Vector2(size.x * 0.5 - 80.0, base_y + float(i) * spacing)
		lbl.size = Vector2(160.0, 12.0)
