extends Control
class_name BottomStage
## T-UI-STAGE-1/2/5 + CQ 横滑营地 · 建筑热点可点 → 上窗后勤/背包

enum StageMode {
	BASE_REST,
	BASE_RECOVERY,
	PREPARE_MUSTER,
	RESULT_RETURN,
}

const MAX_PARTY_SLOTS := 4
const ZONE_MIN_WIDTH := 360.0
const ZONE_CENTER_WIDTH := 480.0
const WORLD_WIDTH_MIN := 1680.0
const _VisualSlotLib = preload("res://scripts/ui/visual_slot.gd")
const _VisualConstantsLib = preload("res://scripts/ui/visual_constants.gd")

signal active_slot_pressed(half: String, index: int)
signal building_pressed(building_id: String)

const BUILDING_INFIRMARY := "infirmary"
const BUILDING_BARRACKS := "barracks"
const BUILDING_WAREHOUSE := "warehouse"

var _shell_built: bool = false
var _mode: StageMode = StageMode.BASE_REST
var _camp_scroll: ScrollContainer = null
var _camp_world: HBoxContainer = null
var _zone_infirmary: Control = null
var _zone_center: Control = null
var _zone_barracks: Control = null
var _zone_warehouse: Control = null
var _bonfire_slot: VisualSlot = null
var _party_hosts: Array[Control] = []
var _party_slots: Array[VisualSlot] = []
var _caption: Label = null
var _half_tag: Label = null
var _scroll_hint: Label = null
var _bob_phase: float = 0.0
var _party_ids: Array[String] = []
var _display_half: String = "A"
var _selection_key: String = ""
var _layout_dirty: bool = true
var _drag_scroll_active: bool = false
var _drag_scroll_last_x: float = 0.0
var _building_hosts: Dictionary = {}
var _building_bodies: Dictionary = {}
var _building_base_colors: Dictionary = {}
var _pulse_building_id: String = ""
var _pulse_building_until: float = 0.0
var _scroll_locked: bool = false


func _ready() -> void:
	_ensure_shell_built()
	set_process(true)
	resized.connect(_on_resized)
	if _camp_scroll:
		_camp_scroll.gui_input.connect(_on_camp_scroll_input)
	call_deferred("_request_layout")


func _on_resized() -> void:
	_layout_dirty = true
	call_deferred("_request_layout")


func _process(delta: float) -> void:
	if not visible:
		return
	_bob_phase += delta * (_bob_speed())
	_animate_idle()
	_tick_building_pulse()
	if _layout_dirty:
		_request_layout()


func _request_layout() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_layout_world()
	_layout_dirty = false


func apply_game_state(state: int) -> void:
	_ensure_shell_built()
	match state:
		GameManager.GameState.BASE:
			if GameManager.is_recovery_lock_active():
				_apply_mode(StageMode.BASE_RECOVERY)
			else:
				_apply_mode(StageMode.BASE_REST)
		GameManager.GameState.PREPARE:
			_apply_mode(StageMode.PREPARE_MUSTER)
		GameManager.GameState.RESULT:
			_apply_mode(StageMode.RESULT_RETURN)
		_:
			visible = false


func is_bonfire_visible() -> bool:
	return _bonfire_slot != null and _bonfire_slot.visible


func count_visible_party_slots() -> int:
	var n: int = 0
	for slot in _party_slots:
		if slot != null and slot.visible:
			n += 1
	return n


func get_stage_mode() -> int:
	return _mode


func get_camp_scroll() -> ScrollContainer:
	return _camp_scroll


func set_camp_scroll_locked(locked: bool) -> void:
	_scroll_locked = locked
	if _scroll_hint:
		_scroll_hint.visible = not locked


func scroll_to_building(building_id: String) -> void:
	if _camp_scroll == null or size.x < 8.0:
		return
	_request_layout()
	var zone: Control = _zone_for_building(building_id)
	if zone == null:
		return
	var view_w: float = maxf(size.x, 1.0)
	var focus_x: float = zone.position.x + zone.size.x * 0.5 - view_w * 0.5
	var max_scroll: float = maxf(_world_content_width() - view_w, 0.0)
	_camp_scroll.scroll_horizontal = int(clampf(focus_x, 0.0, max_scroll))


func pulse_building(building_id: String, seconds: float = 2.0) -> void:
	_pulse_building_id = building_id
	_pulse_building_until = Time.get_ticks_msec() / 1000.0 + maxf(0.2, seconds)
	scroll_to_building(building_id)


func pulse_all_buildings(seconds: float = 2.0) -> void:
	_pulse_building_id = "all"
	_pulse_building_until = Time.get_ticks_msec() / 1000.0 + maxf(0.2, seconds)


func set_formation_selection_key(key: String) -> void:
	_selection_key = key
	_apply_party_selection_visuals()


func _bob_speed() -> float:
	if _mode == StageMode.BASE_RECOVERY:
		return 3.5
	return 5.5


func _ensure_shell_built() -> void:
	if _shell_built:
		return
	_shell_built = true
	name = "BottomStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_camp_scroll = ScrollContainer.new()
	_camp_scroll.name = "CampScrollLane"
	_camp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_camp_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_camp_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_full_rect(_camp_scroll)
	add_child(_camp_scroll)
	_camp_world = HBoxContainer.new()
	_camp_world.name = "CampWorld"
	_camp_world.add_theme_constant_override("separation", 0)
	_camp_world.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_camp_scroll.add_child(_camp_world)
	_zone_infirmary = _make_zone("ZoneInfirmary", ZONE_MIN_WIDTH)
	_zone_center = _make_zone("ZoneCenter", ZONE_CENTER_WIDTH)
	_zone_barracks = _make_zone("ZoneBarracks", ZONE_MIN_WIDTH)
	_zone_warehouse = _make_zone("ZoneWarehouse", ZONE_MIN_WIDTH)
	_camp_world.add_child(_zone_infirmary)
	_camp_world.add_child(_zone_center)
	_camp_world.add_child(_zone_barracks)
	_camp_world.add_child(_zone_warehouse)
	_add_building_marker(_zone_infirmary, "infirmary", "医疗", Color(0.35, 0.55, 0.75, 0.95))
	_add_building_marker(_zone_barracks, "barracks", "营房", Color(0.55, 0.42, 0.32, 0.95))
	_add_building_marker(_zone_warehouse, "warehouse", "仓库", Color(0.62, 0.5, 0.28, 0.95))
	_bonfire_slot = _mount_visual_slot(_zone_center, "CampBonfire", "camp_bonfire", "camp/bonfire")
	for i in range(MAX_PARTY_SLOTS):
		var host := Control.new()
		host.name = "PartyHost%d" % i
		host.mouse_filter = Control.MOUSE_FILTER_STOP
		host.gui_input.connect(_on_party_host_input.bind(i))
		var slot: VisualSlot = _mount_visual_slot(host, "PartySilhouette%d" % i, "camp_party_%d" % i, "party/silhouette_%d" % i)
		_zone_center.add_child(host)
		_party_hosts.append(host)
		_party_slots.append(slot)
	_caption = Label.new()
	_caption.name = "StageCaption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 11)
	_caption.modulate = Color(0.78, 0.72, 0.62)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.z_index = 2
	add_child(_caption)
	_half_tag = Label.new()
	_half_tag.name = "HalfTag"
	_half_tag.add_theme_font_size_override("font_size", 10)
	_half_tag.modulate = Color(0.65, 0.78, 0.9)
	_half_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_half_tag.z_index = 2
	add_child(_half_tag)
	_scroll_hint = Label.new()
	_scroll_hint.name = "ScrollHint"
	_scroll_hint.text = "← 拖动 / 滚轮横滑查看营地 →"
	_scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll_hint.add_theme_font_size_override("font_size", 9)
	_scroll_hint.modulate = Color(0.5, 0.55, 0.65)
	_scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_hint.z_index = 2
	add_child(_scroll_hint)


func _bind_full_rect(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _make_zone(zone_name: String, min_width: float) -> Control:
	var zone := Control.new()
	zone.name = zone_name
	zone.custom_minimum_size = Vector2(min_width, 120.0)
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.set_meta("sky", _make_band_rect("Sky", Color(0.1, 0.14, 0.22, 1.0)))
	zone.set_meta("ground", _make_band_rect("Ground", Color(0.32, 0.24, 0.16, 1.0)))
	zone.set_meta("rim", _make_band_rect("HorizonRim", Color(0.48, 0.36, 0.24, 0.85)))
	zone.add_child(zone.get_meta("sky"))
	zone.add_child(zone.get_meta("ground"))
	zone.add_child(zone.get_meta("rim"))
	return zone


func _make_band_rect(rect_name: String, color: Color) -> ColorRect:
	var band := ColorRect.new()
	band.name = rect_name
	band.color = color
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return band


func _mount_visual_slot(parent: Node, node_name: String, slot_id: String, art_key: String) -> VisualSlot:
	var slot: VisualSlot = _VisualSlotLib.new()
	slot.name = node_name
	slot.slot_id = slot_id
	parent.add_child(slot)
	if slot.is_node_ready():
		slot.apply_art_key(art_key)
	else:
		slot.ready.connect(func() -> void: slot.apply_art_key(art_key), CONNECT_ONE_SHOT)
	return slot


func _add_building_marker(zone: Control, id: String, label_text: String, color: Color) -> void:
	var host := Control.new()
	host.name = "Building_%s" % id
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.tooltip_text = "%s · 点击打开" % label_text
	host.gui_input.connect(_on_building_host_input.bind(id))
	host.mouse_entered.connect(_on_building_host_hover.bind(id, true))
	host.mouse_exited.connect(_on_building_host_hover.bind(id, false))
	var body := ColorRect.new()
	body.name = "Body"
	body.color = color
	body.custom_minimum_size = Vector2(64, 48)
	body.size = Vector2(64, 48)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(body)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.position = Vector2(0, 50)
	lbl.size = Vector2(64, 16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)
	zone.add_child(host)
	_building_hosts[id] = host
	_building_bodies[id] = body
	_building_base_colors[id] = color


func _world_content_width() -> float:
	return maxf(
		ZONE_MIN_WIDTH * 3.0 + ZONE_CENTER_WIDTH,
		maxf(size.x * 2.2, WORLD_WIDTH_MIN)
	)


func _apply_mode(mode: StageMode) -> void:
	_mode = mode
	visible = true
	_party_ids = _resolve_party_ids(mode)
	_update_caption(mode)
	_update_party_visibility()
	_layout_dirty = true
	modulate = Color.WHITE
	if mode == StageMode.BASE_RECOVERY:
		modulate = Color(0.92, 0.82, 0.78)
	elif mode == StageMode.RESULT_RETURN:
		modulate = Color(0.88, 0.9, 0.95)
	call_deferred("_request_layout")
	call_deferred("_scroll_to_default_camp_view")


func _scroll_to_default_camp_view() -> void:
	if _camp_scroll == null or size.x < 8.0:
		return
	_request_layout()
	var ww: float = _world_content_width()
	var view_w: float = maxf(size.x, 1.0)
	var focus_x: float = ZONE_MIN_WIDTH + ZONE_CENTER_WIDTH * 0.42 - view_w * 0.5
	var max_scroll: float = maxf(ww - view_w, 0.0)
	_camp_scroll.scroll_horizontal = int(clampf(focus_x, 0.0, max_scroll))


func _zone_for_building(building_id: String) -> Control:
	match building_id:
		BUILDING_INFIRMARY:
			return _zone_infirmary
		BUILDING_BARRACKS:
			return _zone_barracks
		BUILDING_WAREHOUSE:
			return _zone_warehouse
		_:
			return null


func _building_clicks_enabled() -> bool:
	return GameManager.state == GameManager.GameState.BASE


func _on_building_host_input(event: InputEvent, building_id: String) -> void:
	if not _building_clicks_enabled():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drag_scroll_active = false
			building_pressed.emit(building_id)
			accept_event()


func _on_building_host_hover(building_id: String, inside: bool) -> void:
	if not _building_clicks_enabled():
		return
	var body: ColorRect = _building_bodies.get(building_id, null) as ColorRect
	var base: Color = _building_base_colors.get(building_id, Color.WHITE)
	if body == null:
		return
	if inside:
		body.color = Color(
			clampf(base.r + 0.18, 0.0, 1.0),
			clampf(base.g + 0.18, 0.0, 1.0),
			clampf(base.b + 0.18, 0.0, 1.0),
			base.a
		)
	else:
		body.color = base


func _tick_building_pulse() -> void:
	if _pulse_building_id == "":
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now > _pulse_building_until:
		_pulse_building_id = ""
		for building_id in _building_bodies:
			var body: ColorRect = _building_bodies[building_id] as ColorRect
			if body:
				body.modulate = Color.WHITE
		return
	var t: float = (now - (_pulse_building_until - 2.0)) * 5.0
	var pulse_col := Color(1.0, 0.95 + sin(t) * 0.05, 0.85 + sin(t * 1.3) * 0.1)
	if _pulse_building_id == "all":
		for building_id in _building_bodies:
			var body_all: ColorRect = _building_bodies[building_id] as ColorRect
			if body_all:
				body_all.modulate = pulse_col
		return
	var body: ColorRect = _building_bodies.get(_pulse_building_id, null) as ColorRect
	if body:
		body.modulate = pulse_col


func _on_camp_scroll_input(event: InputEvent) -> void:
	if _camp_scroll == null or _scroll_locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_camp_scroll.scroll_horizontal = maxi(0, _camp_scroll.scroll_horizontal - 56)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var max_h: int = maxi(0, int(_world_content_width() - size.x))
			_camp_scroll.scroll_horizontal = mini(max_h, _camp_scroll.scroll_horizontal + 56)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_scroll_active = true
				_drag_scroll_last_x = mb.position.x
			else:
				_drag_scroll_active = false
			accept_event()
	elif event is InputEventMouseMotion and _drag_scroll_active:
		var mm := event as InputEventMouseMotion
		var delta_x: float = _drag_scroll_last_x - mm.position.x
		_drag_scroll_last_x = mm.position.x
		var max_h: int = maxi(0, int(_world_content_width() - size.x))
		_camp_scroll.scroll_horizontal = clampi(
			_camp_scroll.scroll_horizontal + int(delta_x),
			0,
			max_h
		)
		accept_event()


func _resolve_party_ids(mode: StageMode) -> Array[String]:
	SquadFormationService.ensure_formation(GameManager)
	var half: String = SquadFormationService.get_preferred_half(GameManager)
	match mode:
		StageMode.PREPARE_MUSTER:
			var manual: String = SquadFormationService.resolve_manual_deploy_half(GameManager)
			if manual != "":
				half = manual
		StageMode.RESULT_RETURN:
			var last: String = str(GameManager.last_deploy_half)
			if last in [SquadFormationService.HALF_A, SquadFormationService.HALF_B]:
				half = last
	_display_half = half
	var raw: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half)
	var out: Array[String] = []
	for mid in raw:
		if mid != "":
			var m := GameManager.find_mercenary_by_id(mid)
			if m != null and m.is_alive and not m.is_mia:
				out.append(mid)
	if _half_tag:
		_half_tag.text = "半组 %s" % half
	return out


func _update_caption(mode: StageMode) -> void:
	if _caption == null:
		return
	match mode:
		StageMode.BASE_REST:
			_caption.text = "大营休息 — 营火边陲（可横滑）"
		StageMode.BASE_RECOVERY:
			_caption.text = "养伤休整 — 全队恢复中"
		StageMode.PREPARE_MUSTER:
			_caption.text = "列队出征 — 确认编组后出发"
		StageMode.RESULT_RETURN:
			_caption.text = "抵营清点 — 本趟已结束"
		_:
			_caption.text = ""


func _update_party_visibility() -> void:
	var show_n: int = maxi(1, mini(_party_ids.size(), MAX_PARTY_SLOTS))
	if _mode == StageMode.PREPARE_MUSTER or _mode == StageMode.RESULT_RETURN:
		show_n = maxi(show_n, mini(2, MAX_PARTY_SLOTS))
	for i in range(_party_slots.size()):
		var slot: VisualSlot = _party_slots[i]
		var host: Control = _party_hosts[i]
		if i < show_n:
			host.visible = true
			slot.visible = true
			if i < _party_ids.size():
				slot.modulate = Color.WHITE
			else:
				slot.modulate = Color(0.45, 0.42, 0.4, 0.65)
		else:
			host.visible = false
	_apply_party_selection_visuals()


func _on_party_host_input(event: InputEvent, index: int) -> void:
	if not _formation_clicks_enabled():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			active_slot_pressed.emit(_display_half, index)
			accept_event()


func _formation_clicks_enabled() -> bool:
	return GameManager.state in [
		GameManager.GameState.BASE,
		GameManager.GameState.PREPARE,
	]


func _apply_party_selection_visuals() -> void:
	for i in range(_party_hosts.size()):
		var host: Control = _party_hosts[i]
		var slot: VisualSlot = _party_slots[i]
		if host == null or slot == null or not host.visible:
			continue
		var sel_key := "active:%s:%d" % [_display_half, i]
		var selected: bool = sel_key == _selection_key
		if selected:
			slot.modulate = Color(0.55, 1.0, 0.72)
			host.tooltip_text = "已选 · %s" % _party_host_tooltip(i)
		else:
			if i < _party_ids.size():
				slot.modulate = Color.WHITE
			else:
				slot.modulate = Color(0.45, 0.42, 0.4, 0.65)
			host.tooltip_text = _party_host_tooltip(i)


func _party_host_tooltip(index: int) -> String:
	if index < _party_ids.size():
		var mid: String = _party_ids[index]
		var m := GameManager.find_mercenary_by_id(mid)
		return m.merc_name if m else mid
	return "出战位 %d（空）· 点击选中/编入" % (index + 1)


func _layout_world() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	if _camp_scroll:
		_bind_full_rect(_camp_scroll)
	var wh: float = size.y
	var zone_h: float = maxf(wh - 14.0, 120.0)
	var extra_w: float = maxf(_world_content_width() - (ZONE_MIN_WIDTH * 3.0 + ZONE_CENTER_WIDTH), 0.0)
	var center_w: float = ZONE_CENTER_WIDTH + extra_w * 0.55
	var side_w: float = ZONE_MIN_WIDTH + extra_w * 0.15
	var total_w: float = side_w * 3.0 + center_w
	if _camp_world:
		_camp_world.custom_minimum_size = Vector2(total_w, zone_h)
	_set_zone_width(_zone_infirmary, side_w, zone_h)
	_set_zone_width(_zone_center, center_w, zone_h)
	_set_zone_width(_zone_barracks, side_w, zone_h)
	_set_zone_width(_zone_warehouse, side_w, zone_h)
	_place_building(_zone_infirmary, 0.5, 0.56)
	_place_building(_zone_barracks, 0.5, 0.56)
	_place_building(_zone_warehouse, 0.5, 0.56)
	if _bonfire_slot:
		var bonfire_sz: Vector2 = _VisualConstantsLib.CAMP_BONFIRE_SIZE
		_bonfire_slot.position = Vector2(center_w * 0.34 - bonfire_sz.x * 0.5, zone_h * 0.34)
	var base_x: float = center_w * 0.52
	var base_y: float = zone_h * 0.5
	var spacing: float = 18.0
	for i in range(_party_hosts.size()):
		var host: Control = _party_hosts[i]
		if not host.visible:
			continue
		var slot: VisualSlot = _party_slots[i]
		var psz: Vector2 = _VisualConstantsLib.PARTY_BLOCK_SIZE
		if slot.get_display_mode() == VisualSlot.DisplayMode.PLACEHOLDER:
			psz = slot.custom_minimum_size
		host.position = Vector2(base_x + float(i) * spacing, base_y)
		host.size = psz
	if _caption:
		_caption.position = Vector2(8.0, 6.0)
		_caption.size = Vector2(size.x - 16.0, 18.0)
	if _half_tag:
		_half_tag.position = Vector2(size.x - 72.0, 6.0)
		_half_tag.size = Vector2(64.0, 16.0)
	if _scroll_hint:
		_scroll_hint.position = Vector2(8.0, size.y - 18.0)
		_scroll_hint.size = Vector2(size.x - 16.0, 14.0)


func _set_zone_width(zone: Control, width: float, height: float) -> void:
	if zone == null:
		return
	zone.custom_minimum_size = Vector2(width, height)
	zone.size = Vector2(width, height)
	_resize_zone_backgrounds(zone, width, height)


func _resize_zone_backgrounds(zone: Control, width: float, height: float) -> void:
	var sky: ColorRect = zone.get_meta("sky", null) as ColorRect
	var ground: ColorRect = zone.get_meta("ground", null) as ColorRect
	var rim: ColorRect = zone.get_meta("rim", null) as ColorRect
	var horizon_y: float = height * 0.58
	if sky:
		sky.position = Vector2.ZERO
		sky.size = Vector2(width, horizon_y)
	if ground:
		ground.position = Vector2(0.0, horizon_y)
		ground.size = Vector2(width, height - horizon_y)
	if rim:
		rim.position = Vector2(0.0, height * 0.56)
		rim.size = Vector2(width, height * 0.04)


func _place_building(zone: Control, x_ratio: float, y_ratio: float) -> void:
	if zone == null:
		return
	for child in zone.get_children():
		if not str(child.name).begins_with("Building_"):
			continue
		var host := child as Control
		if host == null:
			continue
		host.position = Vector2(zone.size.x * x_ratio - 32.0, zone.size.y * y_ratio)
		host.size = Vector2(64, 66)


func _animate_idle() -> void:
	if size.y < 8.0:
		return
	var zone_h: float = maxf(size.y - 14.0, 48.0)
	var center_w: float = _zone_center.size.x if _zone_center else ZONE_CENTER_WIDTH
	if _bonfire_slot and _bonfire_slot.visible:
		var flicker: float = 0.88 + sin(_bob_phase * 2.4) * 0.12
		_bonfire_slot.modulate = Color(1.0, flicker, flicker * 0.75, 1.0)
		var bob_y: float = sin(_bob_phase * 1.6) * 2.0
		var bonfire_sz: Vector2 = _VisualConstantsLib.CAMP_BONFIRE_SIZE
		_bonfire_slot.position = Vector2(center_w * 0.34 - bonfire_sz.x * 0.5, zone_h * 0.34 + bob_y)
	for i in range(_party_hosts.size()):
		var host: Control = _party_hosts[i]
		if not host.visible:
			continue
		var base_y: float = zone_h * 0.5
		var bob: float = sin(_bob_phase + float(i) * 0.75) * 4.0
		host.position.y = base_y + bob
