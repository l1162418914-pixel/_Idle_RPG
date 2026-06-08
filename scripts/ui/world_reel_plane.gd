extends Control
class_name WorldReelPlane
## T-UI-REEL-1 · 全宽横卷平面：CampSegment + MapSegment（chunk0 占位 / 雾锁）

const CAMP_SCREEN_RATIO := 1.2
const MAP_ENTRY_SCREEN_RATIO := 1.0
const BOTTOM_STAGE_HEAL_REFRESH_MS := 3000

signal active_slot_pressed(half: String, index: int)
signal building_pressed(building_id: String)

var _camp_host: Control = null
var _camp_segment = null
var _map_segment: Control = null
var _fog_lock: PanelContainer = null
var _fog_label: Label = null
var _chunk_panel: PanelContainer = null
var _chunk_title: Label = null
var _chunk_hint: Label = null
var _running_placeholder: Label = null
var _map_id: String = ""
var _shell_built: bool = false
var _last_heal_refresh_msec: int = 0


func _ready() -> void:
	_ensure_shell_built()
	resized.connect(_on_plane_resized)
	if not GameManager.formation_changed.is_connected(_on_formation_changed):
		GameManager.formation_changed.connect(_on_formation_changed)
	if not GameManager.formation_preference_changed.is_connected(_on_formation_preference_changed):
		GameManager.formation_preference_changed.connect(_on_formation_preference_changed)
	if not GameManager.roster_healed.is_connected(_on_roster_healed):
		GameManager.roster_healed.connect(_on_roster_healed)


func get_camp_segment():
	return _camp_segment


func apply_game_state(state: int) -> void:
	_ensure_shell_built()
	var show_camp_map := state in [
		GameManager.GameState.BASE,
		GameManager.GameState.PREPARE,
		GameManager.GameState.RESULT,
	]
	var show_running := state == GameManager.GameState.RUNNING
	if _camp_host:
		_camp_host.visible = show_camp_map
	if _map_segment:
		_map_segment.visible = show_camp_map
	if _running_placeholder:
		_running_placeholder.visible = show_running
	if show_camp_map and _camp_segment:
		_camp_segment.apply_game_state(state)
		var lock_scroll := state == GameManager.GameState.PREPARE
		_camp_segment.set_camp_scroll_locked(lock_scroll)
		_refresh_map_segment()
	elif show_running:
		if _camp_segment:
			_camp_segment.visible = false


func set_selected_map(map_id: String) -> void:
	_map_id = map_id.strip_edges()
	_refresh_map_segment()


func sync_formation_selection(selection_key: String) -> void:
	if _camp_segment:
		_camp_segment.set_formation_selection_key(selection_key)


func focus_camp_buildings(seconds: float = 2.0) -> void:
	if _camp_segment == null or not _camp_segment.visible:
		return
	_camp_segment.pulse_all_buildings(seconds)
	pulse_stage_focus(seconds)


func scroll_to_camp_building(building_id: String) -> void:
	if _camp_segment:
		_camp_segment.scroll_to_building(building_id)


func pulse_camp_building(building_id: String, seconds: float = 2.0) -> void:
	if _camp_segment:
		_camp_segment.pulse_building(building_id, seconds)


func pulse_stage_focus(seconds: float = 2.0) -> void:
	if _camp_segment == null or not _camp_segment.visible:
		return
	var orig: Color = _camp_segment.modulate
	_camp_segment.modulate = Color(1.06, 1.0, 0.92)
	var tween := create_tween()
	tween.tween_interval(maxf(0.1, seconds * 0.85))
	tween.tween_property(_camp_segment, "modulate", orig, maxf(0.1, seconds * 0.15))


func _ensure_shell_built() -> void:
	if _shell_built:
		return
	_shell_built = true
	name = "WorldReelPlane"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var row := HBoxContainer.new()
	row.name = "ReelRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 0.0
	row.offset_top = 0.0
	row.offset_right = 0.0
	row.offset_bottom = 0.0
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_camp_host = Control.new()
	_camp_host.name = "CampSegment"
	_camp_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_host.size_flags_stretch_ratio = CAMP_SCREEN_RATIO
	_camp_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_camp_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_camp_host)

	_camp_segment = BottomStage.new()
	_camp_segment.name = "CampBottomStage"
	_bind_full_rect(_camp_segment)
	if not _camp_segment.active_slot_pressed.is_connected(_on_camp_active_slot_pressed):
		_camp_segment.active_slot_pressed.connect(_on_camp_active_slot_pressed)
	if not _camp_segment.building_pressed.is_connected(_on_camp_building_pressed):
		_camp_segment.building_pressed.connect(_on_camp_building_pressed)
	_camp_host.add_child(_camp_segment)

	_map_segment = Control.new()
	_map_segment.name = "MapSegment"
	_map_segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_segment.size_flags_stretch_ratio = MAP_ENTRY_SCREEN_RATIO
	_map_segment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_map_segment)

	_fog_lock = PanelContainer.new()
	_fog_lock.name = "FogLock"
	_bind_full_rect(_fog_lock)
	_map_segment.add_child(_fog_lock)
	var fog_bg := ColorRect.new()
	fog_bg.name = "FogBg"
	fog_bg.color = Color(0.12, 0.14, 0.2, 0.92)
	_bind_full_rect(fog_bg)
	fog_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_lock.add_child(fog_bg)
	_fog_label = Label.new()
	_fog_label.name = "FogLabel"
	_fog_label.text = "雾锁 — 请在上区选地图出征"
	_fog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fog_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog_label.modulate = Color(0.55, 0.62, 0.75)
	_fog_label.add_theme_font_size_override("font_size", 12)
	_fog_lock.add_child(_fog_label)

	_chunk_panel = PanelContainer.new()
	_chunk_panel.name = "Chunk0Placeholder"
	_bind_full_rect(_chunk_panel)
	_chunk_panel.visible = false
	_map_segment.add_child(_chunk_panel)
	var chunk_bg := ColorRect.new()
	chunk_bg.name = "ChunkBg"
	chunk_bg.color = Color(0.18, 0.32, 0.22, 1.0)
	_bind_full_rect(chunk_bg)
	chunk_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chunk_panel.add_child(chunk_bg)
	var chunk_vbox := VBoxContainer.new()
	chunk_vbox.set_anchors_preset(Control.PRESET_CENTER)
	chunk_vbox.offset_left = -160.0
	chunk_vbox.offset_top = -28.0
	chunk_vbox.offset_right = 160.0
	chunk_vbox.offset_bottom = 28.0
	chunk_vbox.add_theme_constant_override("separation", 4)
	chunk_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chunk_panel.add_child(chunk_vbox)
	_chunk_title = Label.new()
	_chunk_title.name = "ChunkTitle"
	_chunk_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chunk_title.add_theme_font_size_override("font_size", 13)
	_chunk_title.modulate = Color(0.82, 0.95, 0.78)
	chunk_vbox.add_child(_chunk_title)
	_chunk_hint = Label.new()
	_chunk_hint.name = "ChunkHint"
	_chunk_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chunk_hint.add_theme_font_size_override("font_size", 10)
	_chunk_hint.modulate = Color(0.6, 0.72, 0.65)
	chunk_vbox.add_child(_chunk_hint)

	_running_placeholder = Label.new()
	_running_placeholder.name = "RunningPlaceholder"
	_running_placeholder.text = "行军卷轴 · REEL-2"
	_running_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_running_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_running_placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_running_placeholder.modulate = Color(0.5, 0.58, 0.68)
	_running_placeholder.visible = false
	_running_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_running_placeholder)


func _bind_full_rect(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _on_plane_resized() -> void:
	pass


func _refresh_map_segment() -> void:
	if _fog_lock == null or _chunk_panel == null:
		return
	var has_map := _map_id != ""
	_fog_lock.visible = not has_map
	_chunk_panel.visible = has_map
	if not has_map:
		return
	var md: Dictionary = DataLoader.map_data(_map_id)
	var map_name: String = str(md.get("name", _map_id))
	var reel: Dictionary = md.get("world_reel", {})
	var chunks: Array = reel.get("chunks", [])
	var chunk0: Dictionary = chunks[0] if chunks.size() > 0 else {}
	var chunk_label: String = str(chunk0.get("label", "入口"))
	if _chunk_title:
		_chunk_title.text = "%s · %s" % [map_name, chunk_label]
	if _chunk_hint:
		var chunk_n: int = chunks.size()
		var chunk_m: int = int(reel.get("chunk_distance_m", 100))
		_chunk_hint.text = "chunk[0] 占位 · %d×%dm（REEL-2 换景）" % [chunk_n, chunk_m]


func _on_camp_active_slot_pressed(half: String, index: int) -> void:
	active_slot_pressed.emit(half, index)


func _on_camp_building_pressed(building_id: String) -> void:
	building_pressed.emit(building_id)


func _on_formation_changed() -> void:
	call_deferred("_refresh_camp_from_state")


func _on_formation_preference_changed(_half: String) -> void:
	call_deferred("_refresh_camp_from_state")


func _on_roster_healed() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_heal_refresh_msec >= BOTTOM_STAGE_HEAL_REFRESH_MS:
		_last_heal_refresh_msec = now_msec
		call_deferred("_refresh_camp_from_state")


func _refresh_camp_from_state() -> void:
	if GameManager.state == GameManager.GameState.RUNNING:
		return
	apply_game_state(GameManager.state)
