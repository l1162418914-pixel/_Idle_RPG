class_name BottomStage
extends Control
## T-UI-STAGE-1/2 · 底栏 CQ 动画舞台（营火 + 队伍 idle；只读 GameManager / 编队快照）

enum StageMode {
	BASE_REST,
	BASE_RECOVERY,
	PREPARE_MUSTER,
	RESULT_RETURN,
}

const MAX_PARTY_SLOTS := 4
const _VisualSlotLib = preload("res://scripts/ui/visual_slot.gd")
const _VisualConstantsLib = preload("res://scripts/ui/visual_constants.gd")

var _shell_built: bool = false
var _mode: StageMode = StageMode.BASE_REST
var _ground: ColorRect = null
var _horizon: ColorRect = null
var _top_rim: ColorRect = null
var _bonfire_slot: VisualSlot = null
var _party_hosts: Array[Control] = []
var _party_slots: Array[VisualSlot] = []
var _caption: Label = null
var _half_tag: Label = null
var _bob_phase: float = 0.0
var _party_ids: Array[String] = []
var _layout_dirty: bool = true


func _ready() -> void:
	_ensure_shell_built()
	set_process(true)
	resized.connect(_on_resized)


func _on_resized() -> void:
	_layout_dirty = true


func _process(delta: float) -> void:
	if not visible:
		return
	_bob_phase += delta * (_bob_speed())
	_animate_idle()
	if _layout_dirty:
		_layout_party()
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ground = ColorRect.new()
	_ground.name = "CampGround"
	_ground.color = _VisualConstantsLib.CAMP_GROUND_COLOR
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)
	_horizon = ColorRect.new()
	_horizon.name = "CampHorizon"
	_horizon.color = Color(0.22, 0.16, 0.12, 0.92)
	_horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_horizon)
	_top_rim = ColorRect.new()
	_top_rim.name = "StageTopRim"
	_top_rim.color = Color(0.4, 0.34, 0.28, 0.9)
	_top_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_rim)
	_bonfire_slot = _VisualSlotLib.new()
	_bonfire_slot.name = "CampBonfire"
	_bonfire_slot.slot_id = "camp_bonfire"
	add_child(_bonfire_slot)
	_bonfire_slot.apply_art_key("camp/bonfire")
	for i in range(MAX_PARTY_SLOTS):
		var host := Control.new()
		host.name = "PartyHost%d" % i
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot: VisualSlot = _VisualSlotLib.new()
		slot.name = "PartySilhouette%d" % i
		slot.slot_id = "camp_party_%d" % i
		host.add_child(slot)
		slot.apply_art_key("party/silhouette_%d" % i)
		add_child(host)
		_party_hosts.append(host)
		_party_slots.append(slot)
	_caption = Label.new()
	_caption.name = "StageCaption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 11)
	_caption.modulate = Color(0.78, 0.72, 0.62)
	add_child(_caption)
	_half_tag = Label.new()
	_half_tag.name = "HalfTag"
	_half_tag.add_theme_font_size_override("font_size", 10)
	_half_tag.modulate = Color(0.65, 0.78, 0.9)
	add_child(_half_tag)


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
			_caption.text = "大营休息 — 营火边陲"
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


func _layout_party() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	if _top_rim:
		_top_rim.position = Vector2.ZERO
		_top_rim.size = Vector2(size.x, 2.0)
	if _horizon:
		_horizon.position = Vector2(0.0, size.y * 0.58)
		_horizon.size = Vector2(size.x, size.y * 0.42)
	if _bonfire_slot:
		var bonfire_sz: Vector2 = _VisualConstantsLib.CAMP_BONFIRE_SIZE
		_bonfire_slot.position = Vector2(size.x * 0.36 - bonfire_sz.x * 0.5, size.y * 0.38)
	if _caption:
		_caption.position = Vector2(8.0, 6.0)
		_caption.size = Vector2(size.x - 16.0, 18.0)
	if _half_tag:
		_half_tag.position = Vector2(size.x - 72.0, 6.0)
		_half_tag.size = Vector2(64.0, 16.0)
	var base_x: float = size.x * 0.46
	var base_y: float = size.y * 0.52
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


func _animate_idle() -> void:
	if _bonfire_slot and _bonfire_slot.visible:
		var flicker: float = 0.88 + sin(_bob_phase * 2.4) * 0.12
		_bonfire_slot.modulate = Color(1.0, flicker, flicker * 0.75, 1.0)
		var bob_y: float = sin(_bob_phase * 1.6) * 2.0
		var bonfire_sz: Vector2 = _VisualConstantsLib.CAMP_BONFIRE_SIZE
		_bonfire_slot.position.y = size.y * 0.38 + bob_y
	for i in range(_party_hosts.size()):
		var host: Control = _party_hosts[i]
		if not host.visible:
			continue
		var base_y: float = size.y * 0.52
		var bob: float = sin(_bob_phase + float(i) * 0.75) * 4.0
		host.position.y = base_y + bob
