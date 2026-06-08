extends VBoxContainer
## 基地双半组编队：A/B 各 4 出战 + 2 替补；养伤锁详情

const LAYOUT_REV := 9  ## 变更布局时递增，强制重建节点树
const PREF_TOOLBAR_MAX_RETRIES := 60

const _FormationSlotCardScene = preload("res://scripts/ui/formation_slot_card.gd")
const _FormationPoolDropZoneScene = preload("res://scripts/ui/formation_pool_drop_zone.gd")
const _CampStageScene = preload("res://scripts/ui/camp_stage.gd")
const _FormationSummaryUIScene = preload("res://scripts/ui/formation_summary_ui.gd")

const SLOT_ACTIVE := "active"
const SLOT_BENCH := "bench"
const HALF_STAGE_ACTIVE_BG := Color(0.14, 0.18, 0.24, 0.95)
const HALF_STAGE_REST_BG := Color(0.11, 0.12, 0.15, 0.92)

var _recovery_panel: PanelContainer = null
var _recovery_title: Label = null
var _recovery_body: Label = null
var _player_panel: PanelContainer = null
var _player_body: Label = null
var _formation_block: VBoxContainer = null
var _camp_stage: CampStage = null
var _pref_toolbar: HBoxContainer = null
var _pref_buttons: Dictionary = {}
var _halves_row: HBoxContainer = null
var _pool_label: Label = null
var _pool_scroll: ScrollContainer = null
var _expedition_summary: Label = null
var _pool_panel: PanelContainer = null
var _pool_body: HBoxContainer = null
var _summary_ui: FormationSummaryUI = null
var _advanced_panel: PanelContainer = null
var _advanced_body: VBoxContainer = null
var _advanced_toggle: Button = null
var _advanced_collapsed: bool = true
var _selected: Dictionary = {}  # {half, kind, index} or empty
var _status_label: Label = null
var _expedition_panel: PanelContainer = null
var _prio_group: ButtonGroup = null
var _prio_push_btn: CheckButton = null
var _prio_march_btn: CheckButton = null
var _prio_loot_btn: CheckButton = null
var _loot_evict_check: CheckButton = null
var _loot_discard_check: CheckButton = null
var _auto_retreat_check: CheckButton = null
var _auto_retreat_safe_check: CheckButton = null
var _retreat_row: HBoxContainer = null
var _syncing_expedition_prefs: bool = false
var _refresh_pending: bool = false
var _refreshing: bool = false
var _refresh_again: bool = false
var _refreshing_halves: bool = false


func _ready() -> void:
	GameManager.formation_changed.connect(_schedule_refresh)
	GameManager.roster_healed.connect(_refresh_heal_visuals)
	GameManager.state_changed.connect(_on_state_changed)
	_ensure_ui_built()
	_schedule_refresh()


func _ensure_ui_built() -> void:
	if get_meta("layout_rev", -1) == LAYOUT_REV and _formation_block != null:
		return
	_clear_ui_children()
	set_meta("layout_rev", LAYOUT_REV)
	_build_ui()


func _clear_ui_children() -> void:
	_formation_block = null
	_camp_stage = null
	_pref_toolbar = null
	_pref_buttons = {}
	_halves_row = null
	_pool_label = null
	_pool_scroll = null
	_pool_panel = null
	_pool_body = null
	_summary_ui = null
	_advanced_panel = null
	_advanced_body = null
	_advanced_toggle = null
	_advanced_collapsed = true
	_status_label = null
	_expedition_panel = null
	_expedition_summary = null
	_retreat_row = null
	_player_panel = null
	_player_body = null
	_recovery_panel = null
	_recovery_title = null
	_recovery_body = null
	for child in get_children():
		remove_child(child)
		child.free()


func _on_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.BASE:
		_schedule_refresh()


func _schedule_refresh() -> void:
	if not is_inside_tree():
		return
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	_refresh_pending = false
	_refresh()


func _refresh_heal_visuals() -> void:
	if GameManager.state != GameManager.GameState.BASE:
		return
	if _refreshing or _refresh_pending:
		return
	_refresh_heal_lightweight()


func pulse_formation_focus(seconds: float = 2.0) -> void:
	pulse_stage_focus(seconds)
	if _summary_ui:
		_summary_ui.pulse_focus(seconds)


func pulse_stage_focus(seconds: float = 2.0) -> void:
	var stage := _find_stage_shell()
	if stage:
		stage.pulse_stage_focus(seconds)


func _find_stage_shell() -> StageShell:
	var root := get_tree().root
	if root:
		var stage := root.get_node_or_null("StageWindow/StageShell") as StageShell
		if stage:
			return stage
	var scene := get_tree().current_scene
	if scene:
		return scene.get_node_or_null("StageWindow/StageShell") as StageShell
	return null


func pulse_camp_focus(seconds: float = 2.0) -> void:
	pulse_stage_focus(seconds)
	if _camp_stage and not _camp_stage.is_collapsed():
		_camp_stage.pulse_focus(seconds)


func scroll_camp_into_view() -> void:
	if _camp_stage == null:
		return
	var scroll := _find_parent_scroll()
	if scroll:
		scroll.ensure_control_visible(_camp_stage)


func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var title := Label.new()
	title.text = "双半组编队"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	add_child(title)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.max_lines_visible = 2
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.modulate = Color(0.72, 0.8, 0.9)
	add_child(_status_label)
	_formation_block = VBoxContainer.new()
	_formation_block.name = "FormationBlock"
	_formation_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formation_block.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_formation_block.add_theme_constant_override("separation", 6)
	add_child(_formation_block)
	_summary_ui = _FormationSummaryUIScene.new()
	_summary_ui.formation_ui = self
	_formation_block.add_child(_summary_ui)
	_build_advanced_formation_panel(_formation_block)
	_build_expedition_prefs(_formation_block)
	_expedition_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_player_panel = PanelContainer.new()
	_player_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pv := VBoxContainer.new()
	_player_panel.add_child(pv)
	var pt := Label.new()
	pt.text = "战略核心（留营）"
	pt.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	pv.add_child(pt)
	_player_body = Label.new()
	_player_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_player_body.add_theme_font_size_override("font_size", 11)
	pv.add_child(_player_body)
	var player_tools := HBoxContainer.new()
	player_tools.add_theme_constant_override("separation", 8)
	var player_equip_btn := Button.new()
	player_equip_btn.text = "管理装备"
	player_equip_btn.pressed.connect(_on_player_equip_pressed)
	player_tools.add_child(player_equip_btn)
	pv.add_child(player_tools)
	_apply_player_panel_style()
	add_child(_player_panel)
	_recovery_panel = PanelContainer.new()
	_recovery_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_recovery_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rv := VBoxContainer.new()
	_recovery_panel.add_child(rv)
	_recovery_title = Label.new()
	_recovery_title.text = "全队养伤锁"
	_recovery_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	rv.add_child(_recovery_title)
	_recovery_body = Label.new()
	_recovery_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_body.add_theme_font_size_override("font_size", 11)
	rv.add_child(_recovery_body)
	add_child(_recovery_panel)


func _build_advanced_formation_panel(parent: Node) -> void:
	_advanced_collapsed = true
	_advanced_panel = PanelContainer.new()
	_advanced_panel.name = "AdvancedFormationPanel"
	_advanced_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advanced_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var shell_sb := StyleBoxFlat.new()
	shell_sb.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	shell_sb.border_width_left = 1
	shell_sb.border_width_top = 1
	shell_sb.border_width_right = 1
	shell_sb.border_width_bottom = 1
	shell_sb.border_color = Color(0.22, 0.34, 0.46, 0.7)
	shell_sb.corner_radius_top_left = 5
	shell_sb.corner_radius_top_right = 5
	shell_sb.corner_radius_bottom_left = 5
	shell_sb.corner_radius_bottom_right = 5
	shell_sb.content_margin_left = 4
	shell_sb.content_margin_top = 2
	shell_sb.content_margin_right = 4
	shell_sb.content_margin_bottom = 4
	_advanced_panel.add_theme_stylebox_override("panel", shell_sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_advanced_panel.add_child(col)
	_advanced_toggle = Button.new()
	_advanced_toggle.name = "AdvancedFormationToggle"
	_advanced_toggle.flat = true
	_advanced_toggle.focus_mode = Control.FOCUS_NONE
	_advanced_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_advanced_toggle.add_theme_font_size_override("font_size", 10)
	_advanced_toggle.pressed.connect(_on_advanced_toggle_pressed)
	col.add_child(_advanced_toggle)
	_sync_advanced_toggle_label()
	_advanced_body = VBoxContainer.new()
	_advanced_body.name = "AdvancedFormationBody"
	_advanced_body.visible = false
	_advanced_body.add_theme_constant_override("separation", 6)
	_advanced_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advanced_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(_advanced_body)
	parent.add_child(_advanced_panel)
	_camp_stage = _CampStageScene.new()
	_camp_stage.formation_ui = self
	if not _camp_stage.slot_chip_pressed.is_connected(_on_slot_pressed):
		_camp_stage.slot_chip_pressed.connect(_on_slot_pressed)
	_advanced_body.add_child(_camp_stage)
	_build_preferred_half_toolbar(_advanced_body)
	_halves_row = HBoxContainer.new()
	_halves_row.add_theme_constant_override("separation", 10)
	_halves_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_halves_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_advanced_body.add_child(_halves_row)
	_build_pool_panel(_advanced_body)


func _on_advanced_toggle_pressed() -> void:
	set_advanced_collapsed(not _advanced_collapsed)


func set_advanced_collapsed(collapsed: bool) -> void:
	_advanced_collapsed = collapsed
	if _advanced_body:
		_advanced_body.visible = not _advanced_collapsed
	_sync_advanced_toggle_label()
	if not _advanced_collapsed:
		_refresh_camp_stage()
		_refresh_halves()
		_refresh_pool()


func _sync_advanced_toggle_label() -> void:
	if _advanced_toggle == null:
		return
	var arrow := "▸" if _advanced_collapsed else "▾"
	_advanced_toggle.text = "%s 高级编组（槽位墙 / 拖放 / CampStage）" % arrow


func _build_pool_panel(parent: Node) -> void:
	_pool_panel = PanelContainer.new()
	_pool_panel.name = "FormationPoolPanel"
	_pool_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_pool_panel.custom_minimum_size = Vector2(0, 72)
	var shell_sb := StyleBoxFlat.new()
	shell_sb.bg_color = Color(0.09, 0.11, 0.15, 0.88)
	shell_sb.border_width_left = 1
	shell_sb.border_width_top = 1
	shell_sb.border_width_right = 1
	shell_sb.border_width_bottom = 1
	shell_sb.border_color = Color(0.24, 0.38, 0.5, 0.75)
	shell_sb.corner_radius_top_left = 5
	shell_sb.corner_radius_top_right = 5
	shell_sb.corner_radius_bottom_left = 5
	shell_sb.corner_radius_bottom_right = 5
	shell_sb.content_margin_left = 6
	shell_sb.content_margin_top = 4
	shell_sb.content_margin_right = 6
	shell_sb.content_margin_bottom = 4
	_pool_panel.add_theme_stylebox_override("panel", shell_sb)
	_pool_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_pool_panel.add_child(col)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)
	_pool_label = Label.new()
	_pool_label.text = "备战席"
	_pool_label.add_theme_font_size_override("font_size", 11)
	_pool_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_pool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_pool_label)
	var fill_btn := Button.new()
	fill_btn.text = "补满优先"
	fill_btn.tooltip_text = "补满编组优先半组；不跨半组搬人请用 A↔B 互换"
	fill_btn.custom_minimum_size = Vector2(72, 28)
	fill_btn.pressed.connect(_on_auto_fill_preferred)
	header.add_child(fill_btn)
	var swap_btn := Button.new()
	swap_btn.text = "A↔B"
	swap_btn.tooltip_text = "互换两半组出战/替补编组"
	swap_btn.custom_minimum_size = Vector2(52, 28)
	swap_btn.pressed.connect(_on_swap_halves)
	header.add_child(swap_btn)
	var header_hint := Label.new()
	header_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hint.text = "拖入槽位编入 · 从槽拖回此处移出"
	header_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_hint.add_theme_font_size_override("font_size", 9)
	header_hint.modulate = Color(0.55, 0.65, 0.75)
	header.add_child(header_hint)
	var pool_drop: FormationPoolDropZone = _FormationPoolDropZoneScene.new()
	pool_drop.name = "FormationPoolDropZone"
	pool_drop.formation_ui = self
	pool_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(pool_drop)
	_pool_scroll = ScrollContainer.new()
	_pool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_pool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pool_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_scroll.custom_minimum_size = Vector2(0, 52)
	pool_drop.add_child(_pool_scroll)
	_pool_body = HBoxContainer.new()
	_pool_body.name = "FormationPoolBody"
	_pool_body.add_theme_constant_override("separation", 6)
	_pool_body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pool_scroll.add_child(_pool_body)
	parent.add_child(_pool_panel)


func _build_preferred_half_toolbar(parent: Node) -> void:
	_pref_toolbar = HBoxContainer.new()
	_pref_toolbar.name = "PreferredHalfToolbar"
	_pref_toolbar.add_theme_constant_override("separation", 8)
	var hint := Label.new()
	hint.text = "编组优先"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.65, 0.75, 0.88)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pref_toolbar.add_child(hint)
	_pref_buttons = {}
	for half in [SquadFormationService.HALF_A, SquadFormationService.HALF_B]:
		var btn := Button.new()
		btn.name = "PreferredHalf%s" % half
		btn.custom_minimum_size = Vector2(96, 30)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_pref_toolbar_pressed.bind(half))
		_pref_toolbar.add_child(btn)
		_pref_buttons[half] = btn
	parent.add_child(_pref_toolbar)
	_sync_preferred_toolbar()


func scroll_pool_into_view() -> void:
	if _summary_ui == null:
		return
	var scroll := _find_parent_scroll()
	if scroll:
		scroll.ensure_control_visible(_summary_ui)


func _find_parent_scroll() -> ScrollContainer:
	var n: Node = get_parent()
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null


func pulse_pool_focus(seconds: float = 1.5) -> void:
	if _summary_ui:
		_summary_ui.pulse_focus(seconds)


func _build_expedition_prefs(parent: Node) -> void:
	_expedition_panel = PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	_expedition_panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	margin.add_child(col)
	var head := Label.new()
	head.text = "出征策略"
	head.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	head.add_theme_font_size_override("font_size", 12)
	col.add_child(head)
	_expedition_summary = Label.new()
	_expedition_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expedition_summary.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_expedition_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expedition_summary.max_lines_visible = 2
	_expedition_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_expedition_summary.add_theme_font_size_override("font_size", 10)
	_expedition_summary.modulate = Color(0.65, 0.78, 0.9)
	col.add_child(_expedition_summary)
	_prio_group = ButtonGroup.new()
	var prio_row := HBoxContainer.new()
	prio_row.add_theme_constant_override("separation", 6)
	var prio_lbl := Label.new()
	prio_lbl.text = "跑图"
	prio_lbl.add_theme_font_size_override("font_size", 10)
	prio_lbl.modulate = Color(0.7, 0.8, 0.9)
	prio_row.add_child(prio_lbl)
	_prio_push_btn = CheckButton.new()
	_prio_push_btn.text = "推图"
	_prio_push_btn.tooltip_text = "目标：击杀 Boss 解锁下一关。优先推进与战斗；不自动撤离（仅手动撤）"
	_prio_push_btn.button_group = _prio_group
	_prio_push_btn.toggled.connect(_on_expedition_priority_toggled.bind(GameManager.EXPEDITION_PRIORITY_PUSH))
	prio_row.add_child(_prio_push_btn)
	_prio_march_btn = CheckButton.new()
	_prio_march_btn.text = "均衡"
	_prio_march_btn.tooltip_text = "正常跑图节奏；携带价值或背包将满时可自动撤离（可勾选下方选项）"
	_prio_march_btn.button_group = _prio_group
	_prio_march_btn.toggled.connect(_on_expedition_priority_toggled.bind(GameManager.EXPEDITION_PRIORITY_MARCH))
	prio_row.add_child(_prio_march_btn)
	_prio_loot_btn = CheckButton.new()
	_prio_loot_btn.text = "搜刮"
	_prio_loot_btn.tooltip_text = "资源优先：更密搜索、少接战（避战待后续）。满载或拾取高价值物自动撤离"
	_prio_loot_btn.button_group = _prio_group
	_prio_loot_btn.toggled.connect(_on_expedition_priority_toggled.bind(GameManager.EXPEDITION_PRIORITY_LOOT))
	prio_row.add_child(_prio_loot_btn)
	col.add_child(prio_row)
	var loot_row := HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 8)
	loot_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var loot_lbl := Label.new()
	loot_lbl.text = "战利品"
	loot_lbl.add_theme_font_size_override("font_size", 10)
	loot_lbl.modulate = Color(0.7, 0.8, 0.9)
	loot_row.add_child(loot_lbl)
	_loot_evict_check = CheckButton.new()
	_loot_evict_check.text = "挤占低值"
	_loot_evict_check.custom_minimum_size = Vector2(0, 28)
	_loot_evict_check.tooltip_text = "格满时用高价值替换最低价值装备"
	_loot_evict_check.toggled.connect(_on_loot_evict_toggled)
	loot_row.add_child(_loot_evict_check)
	_loot_discard_check = CheckButton.new()
	_loot_discard_check.text = "溢出丢弃"
	_loot_discard_check.custom_minimum_size = Vector2(0, 28)
	_loot_discard_check.tooltip_text = "无法放入且无法挤占时丢弃新掉落"
	_loot_discard_check.toggled.connect(_on_loot_discard_toggled)
	loot_row.add_child(_loot_discard_check)
	col.add_child(loot_row)
	_retreat_row = HBoxContainer.new()
	_retreat_row.name = "ExpeditionRetreatRow"
	_retreat_row.add_theme_constant_override("separation", 8)
	_retreat_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ret_lbl := Label.new()
	ret_lbl.text = "撤离"
	ret_lbl.add_theme_font_size_override("font_size", 10)
	ret_lbl.modulate = Color(0.7, 0.8, 0.9)
	_retreat_row.add_child(ret_lbl)
	_auto_retreat_check = CheckButton.new()
	_auto_retreat_check.name = "ExpeditionAutoRetreat"
	_auto_retreat_check.text = "达标撤"
	_auto_retreat_check.custom_minimum_size = Vector2(0, 28)
	_auto_retreat_check.tooltip_text = "均衡模式：携带价值达标时自动撤离"
	_auto_retreat_check.toggled.connect(_on_auto_retreat_toggled)
	_retreat_row.add_child(_auto_retreat_check)
	_auto_retreat_safe_check = CheckButton.new()
	_auto_retreat_safe_check.name = "ExpeditionAutoRetreatSafe"
	_auto_retreat_safe_check.text = "仅安全箱"
	_auto_retreat_safe_check.custom_minimum_size = Vector2(0, 28)
	_auto_retreat_safe_check.tooltip_text = "均衡模式：撤离阈值只计安全箱（不含外露）"
	_auto_retreat_safe_check.toggled.connect(_on_auto_retreat_safe_toggled)
	_retreat_row.add_child(_auto_retreat_safe_check)
	col.add_child(_retreat_row)
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.bg_color = Color(0.1, 0.13, 0.18, 0.9)
	sb.border_width_left = 1
	sb.border_color = Color(0.28, 0.5, 0.68, 0.65)
	_expedition_panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(_expedition_panel)


func _sync_expedition_prefs_ui() -> void:
	if _expedition_panel == null:
		return
	_syncing_expedition_prefs = true
	var pri: String = GameManager.expedition_priority
	if _prio_push_btn:
		_prio_push_btn.button_pressed = pri == GameManager.EXPEDITION_PRIORITY_PUSH
	if _prio_march_btn:
		_prio_march_btn.button_pressed = pri == GameManager.EXPEDITION_PRIORITY_MARCH
	if _prio_loot_btn:
		_prio_loot_btn.button_pressed = pri == GameManager.EXPEDITION_PRIORITY_LOOT
	if _loot_evict_check:
		_loot_evict_check.button_pressed = GameManager.loot_auto_evict_low_value
	if _loot_discard_check:
		_loot_discard_check.button_pressed = GameManager.loot_discard_overflow
	if _auto_retreat_check:
		_auto_retreat_check.button_pressed = GameManager.auto_retreat_value_enabled
	if _auto_retreat_safe_check:
		_auto_retreat_safe_check.button_pressed = GameManager.auto_retreat_safe_only
		_auto_retreat_safe_check.disabled = not GameManager.auto_retreat_value_enabled
	_sync_expedition_retreat_row()
	_update_expedition_summary()
	_syncing_expedition_prefs = false


func _sync_expedition_retreat_row() -> void:
	var pri: String = GameManager.expedition_priority
	var march_only: bool = pri == GameManager.EXPEDITION_PRIORITY_MARCH
	if _retreat_row:
		_retreat_row.visible = march_only


func _update_expedition_summary() -> void:
	if _expedition_summary == null:
		return
	_expedition_summary.text = GameManager.get_expedition_prefs_summary()


func _on_expedition_priority_toggled(pressed: bool, priority: String) -> void:
	if _syncing_expedition_prefs or not pressed:
		return
	GameManager.expedition_priority = priority
	_sync_expedition_retreat_row()
	_notify_expedition_prefs_changed()


func _on_loot_evict_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.loot_auto_evict_low_value = pressed
	_notify_expedition_prefs_changed()


func _on_loot_discard_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.loot_discard_overflow = pressed
	_notify_expedition_prefs_changed()


func _on_auto_retreat_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.auto_retreat_value_enabled = pressed
	if _auto_retreat_safe_check:
		_auto_retreat_safe_check.disabled = not pressed
	_notify_expedition_prefs_changed()


func _on_auto_retreat_safe_toggled(pressed: bool) -> void:
	if _syncing_expedition_prefs:
		return
	GameManager.auto_retreat_safe_only = pressed
	_notify_expedition_prefs_changed()


func _notify_expedition_prefs_changed() -> void:
	_update_expedition_summary()
	var shell := get_tree().root.get_node_or_null("MainShell") if get_tree() else null
	if shell and shell.has_method("show_toast"):
		shell.show_toast("出征策略已更新 · %s" % GameManager.get_expedition_prefs_summary(), Color(0.8, 0.95, 1.0), 3.0)


func _format_compact_status() -> String:
	var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
	var deploy_h: String = SquadFormationService.resolve_deploy_half(GameManager)
	var a_tag := "可出战" if SquadFormationService.half_can_deploy(GameManager, SquadFormationService.HALF_A) else "休整"
	var b_tag := "可出战" if SquadFormationService.half_can_deploy(GameManager, SquadFormationService.HALF_B) else "休整"
	var line1 := "编组优先 %s · A:%s · B:%s · 主角留营" % [pref, a_tag, b_tag]
	var stab_ab: String = SquadFormationService.format_halves_stability_summary(GameManager)
	var line2 := "稳定 %s" % stab_ab
	if deploy_h != "":
		var stab_txt: String = SquadFormationService.format_half_stability_text(GameManager, deploy_h)
		if deploy_h != pref:
			line2 += " · 下趟 %s %s（%s 休整·改派）" % [deploy_h, stab_txt, pref]
		else:
			line2 += " · 下趟 %s %s" % [deploy_h, stab_txt]
	var sel_md: Dictionary = DataLoader.map_data(GameManager.selected_map_id)
	if GameManager.state == GameManager.GameState.BASE and TestScenarioService.should_lock_roster(sel_md):
		if str(sel_md.get("test_scenario", "")) == "mia_wipe":
			if TestScenarioService.has_test_mia_casualties(GameManager):
				line2 += " · 测试⑨：F5 回收遗留"
			elif TestScenarioService.is_roster_injected(GameManager, GameManager.selected_map_id):
				line2 += " · 测试⑨：A 灭团后 F5 回收"
			else:
				line2 += " · 测试⑨：点地图出征注入"
		elif not TestScenarioService.is_roster_injected(GameManager, GameManager.selected_map_id):
			var roster: Dictionary = TestRosterLoader.roster_for_map(GameManager.selected_map_id)
			var label: String = str(roster.get("display_name", "测试编队"))
			line2 += " · 测试图待注入 %s" % label
	if GameManager.is_recovery_lock_active():
		line2 += " · " + SquadFormationService.get_recovery_lock_message(GameManager)
	return line1 + "\n" + line2


func _refresh() -> void:
	if GameManager.state != GameManager.GameState.BASE:
		return
	if _refreshing:
		_refresh_again = true
		return
	_refreshing = true
	_refresh_again = false
	SquadFormationService.ensure_formation(GameManager)
	GameManager.repair_roster_base_stats()
	_sync_expedition_prefs_ui()
	_refresh_player_card()
	_refresh_recovery()
	_refresh_summary()
	if not _advanced_collapsed:
		_refresh_camp_stage()
		_refresh_halves()
		_refresh_pool()
	if _status_label:
		_status_label.text = _format_compact_status()
		if GameManager.is_recovery_lock_active():
			_status_label.modulate = Color.ORANGE_RED
		else:
			_status_label.modulate = Color(0.85, 0.95, 1.0)
	if _player_panel:
		_player_panel.visible = GameManager.player != null
	if _recovery_panel:
		_recovery_panel.visible = GameManager.is_recovery_lock_active()
	_sync_preferred_toolbar()
	_sync_preferred_column_headers()
	_refreshing = false
	if _refresh_again:
		_schedule_refresh()


func _for_each_slot_card(callback: Callable) -> void:
	if _halves_row == null:
		return
	for shell in _halves_row.get_children():
		_walk_slot_cards(shell, callback)


func _walk_slot_cards(node: Node, callback: Callable) -> void:
	if node is FormationSlotCard:
		callback.call(node)
	for child in node.get_children():
		_walk_slot_cards(child, callback)


func _refresh_selection_highlights() -> void:
	var sel_key: String = str(_selected.get("key", ""))
	_for_each_slot_card(func(card: FormationSlotCard) -> void:
		var key := _slot_key(card.slot_half, card.slot_kind, card.slot_index)
		card.set_selected_highlight(key == sel_key)
	)
	if _camp_stage:
		_camp_stage.set_selection_highlight(sel_key)
	_refresh_summary()


func _refresh_summary() -> void:
	if _summary_ui == null:
		return
	_summary_ui.refresh(str(_selected.get("key", "")), Callable(self, "_slot_card_visual"))


func _refresh_camp_stage() -> void:
	if _camp_stage == null:
		return
	if _camp_stage.is_collapsed():
		return
	var a_ids: Array[String] = SquadFormationService.get_active_ids(
		GameManager.squad_formation, SquadFormationService.HALF_A
	)
	var b_ids: Array[String] = SquadFormationService.get_active_ids(
		GameManager.squad_formation, SquadFormationService.HALF_B
	)
	_camp_stage.refresh_lineup(
		_pad(a_ids, SquadFormationService.MAX_ACTIVE),
		_pad(b_ids, SquadFormationService.MAX_ACTIVE),
		str(_selected.get("key", "")),
		_slot_card_visual
	)


func _on_player_equip_pressed() -> void:
	var base_ui := _find_base_ui()
	if base_ui and base_ui.has_method("open_equipment_for"):
		base_ui.open_equipment_for(GameManager.player)


func _find_base_ui() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("open_equipment_for"):
			return n
		n = n.get_parent()
	return null


func _refresh_player_card() -> void:
	if _player_panel == null or _player_body == null:
		return
	var p = GameManager.player
	if p == null:
		_player_panel.visible = false
		return
	_player_panel.visible = true
	var max_hp: int = maxi(1, StatResolver.get_max_hp(p))
	var pct: int = int(float(p.current_hp) / float(max_hp) * 100.0)
	var status := "可出战"
	if p.is_near_death:
		status = "濒死·留营恢复"
	elif not p.can_join_squad():
		status = "休整·留营恢复"
	_player_body.text = "★ %s Lv.%d · %d%%HP · %s · 留营不占槽" % [
		p.merc_name, p.level, pct, status,
	]


func _refresh_recovery() -> void:
	if _recovery_panel == null:
		return
	var st: Dictionary = SquadFormationService.get_recovery_status(GameManager)
	_recovery_panel.visible = st.get("locked", false)
	if not _recovery_panel.visible:
		return
	var no_mercs: bool = st.get("no_mercs", false)
	if _recovery_title:
		_recovery_title.text = "无法出征" if no_mercs else "全队养伤锁"
	var lines: PackedStringArray = []
	if no_mercs:
		lines.append("暂无佣兵可编组。请打开兵营招募至少 1 名佣兵，再编入 A/B 半组出战位。")
	else:
		lines.append("两半组均无法出征（顶栏已显示养伤锁与预计恢复时间）。")
	var eta: float = float(st.get("eta_seconds", 0.0))
	if not no_mercs and eta > 0.5:
		if eta >= 120.0:
			lines.append("预计约 %.0f 分钟后可恢复出征" % (eta / 60.0))
		else:
			lines.append("预计约 %.0f 秒后可恢复出征" % eta)
	var nh: String = str(st.get("next_deploy_half", ""))
	if not no_mercs and nh != "":
		lines.append("解锁后优先半组: %s" % nh)
	if no_mercs:
		_recovery_body.text = "\n".join(lines)
		return
	for half in ["A", "B"]:
		var hd: Dictionary = st.halves.get(half, {})
		var tag := "可出战" if hd.get("can_deploy", false) else "休整"
		lines.append("\n【半组 %s · %s】" % [half, tag])
		for m in hd.get("members", []):
			var md: Dictionary = m
			var cur_hp: int = int(md.get("current_hp", 0))
			var max_hp: int = maxi(1, int(md.get("max_hp", 1)))
			var pct: int = int(float(cur_hp) / float(max_hp) * 100.0)
			lines.append(
				"  · %s%s — HP %d/%d (%d%%) — %s" % [
					"★" if md.get("is_player", false) else "",
					md.get("name", "?"),
					cur_hp,
					max_hp,
					pct,
					md.get("reason", ""),
				]
			)
	_recovery_body.text = "\n".join(lines)


func _refresh_heal_lightweight() -> void:
	GameManager.repair_roster_base_stats()
	_refresh_player_card()
	_refresh_recovery()
	_refresh_slot_cards_visuals()
	_sync_camp_stage_visuals()
	_refresh_summary()
	if not _selected.is_empty():
		_refresh_selection_highlights()
	if _status_label:
		_status_label.text = _format_compact_status()
		if GameManager.is_recovery_lock_active():
			_status_label.modulate = Color.ORANGE_RED
		else:
			_status_label.modulate = Color(0.85, 0.95, 1.0)
	if _recovery_panel:
		_recovery_panel.visible = GameManager.is_recovery_lock_active()


func _refresh_slot_cards_visuals() -> void:
	if _halves_row == null:
		return
	_for_each_slot_card(func(card: FormationSlotCard) -> void:
		var mid := _get_slot_merc_id(card.slot_half, card.slot_kind, card.slot_index)
		var vis: Dictionary = _slot_card_visual(mid, card.slot_kind)
		card.update_merc_visual(
			bool(vis.get("ready", false)),
			str(vis.get("name_text", "")),
			float(vis.get("hp_ratio", 0.0)),
			str(vis.get("badge", "")),
			vis.get("accent", Color.WHITE),
			vis.get("bg", Color(0.14, 0.17, 0.22))
		)
	)


func _sync_camp_stage_visuals() -> void:
	if _camp_stage == null or _camp_stage.is_collapsed():
		return
	var a_ids: Array[String] = _pad(
		SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_A),
		SquadFormationService.MAX_ACTIVE
	)
	var b_ids: Array[String] = _pad(
		SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_B),
		SquadFormationService.MAX_ACTIVE
	)
	var sel_key: String = str(_selected.get("key", ""))
	if not _camp_stage.sync_lineup_visuals(a_ids, b_ids, sel_key, _slot_card_visual):
		_refresh_camp_stage()


func _refresh_halves() -> void:
	if _halves_row == null:
		return
	if _refreshing_halves:
		return
	_refreshing_halves = true
	for c in _halves_row.get_children():
		_halves_row.remove_child(c)
		c.free()
	_halves_row.add_child(_build_half_column(SquadFormationService.HALF_A))
	_halves_row.add_child(_build_half_column(SquadFormationService.HALF_B))
	_refreshing_halves = false
	_sync_preferred_column_headers()


func _build_half_column(half: String) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.set_meta("half", half)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_half_stage_style(shell, half)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	shell.add_child(margin)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var can_dep: bool = SquadFormationService.half_can_deploy(GameManager, half)
	var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
	var head := Label.new()
	head.name = "HalfHead%s" % half
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.text = _half_column_head_text(half, can_dep, pref)
	head.add_theme_font_size_override("font_size", 12)
	if half == pref:
		head.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	col.add_child(head)
	var stab_lbl := Label.new()
	stab_lbl.name = "HalfStability%s" % half
	stab_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stab_lbl.add_theme_font_size_override("font_size", 10)
	var stab_parts: Dictionary = SquadFormationService.get_half_stability_parts(GameManager, half)
	var active_sum: int = int(stab_parts.get("active_sum", 0))
	var active_max_sum: int = int(stab_parts.get("active_max_sum", 0))
	var stab_txt: String = SquadFormationService.format_half_stability_text(GameManager, half)
	var bench_min: int = int(stab_parts.get("bench_min", StabilitySystem.MAX_STABILITY))
	if bench_min < StabilitySystem.MAX_STABILITY:
		stab_lbl.text = "稳定 %s · 替补最弱%d（不计入总和）" % [stab_txt, bench_min]
	else:
		stab_lbl.text = "稳定 %s（出战4人总和）" % stab_txt
	var withdraw: int = StabilitySystem.get_team_withdraw_threshold_for_max(maxi(1, active_max_sum))
	stab_lbl.modulate = Color(0.7, 0.85, 1.0) if active_sum > withdraw else Color(1.0, 0.65, 0.45)
	col.add_child(stab_lbl)
	col.add_child(_make_slot_label("出战 (4)"))
	var active: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half)
	active = _pad(active, SquadFormationService.MAX_ACTIVE)
	for i in range(SquadFormationService.MAX_ACTIVE):
		col.add_child(_make_slot_card(half, SLOT_ACTIVE, i, active[i]))
	col.add_child(_make_slot_label("替补 (2)"))
	var bench_row := HBoxContainer.new()
	bench_row.add_theme_constant_override("separation", 4)
	bench_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bench: Array[String] = SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	bench = _pad(bench, SquadFormationService.MAX_BENCH)
	for i in range(SquadFormationService.MAX_BENCH):
		var bench_card := _make_slot_card(half, SLOT_BENCH, i, bench[i])
		bench_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_row.add_child(bench_card)
	col.add_child(bench_row)
	return shell


func _make_slot_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.modulate = Color.DIM_GRAY
	return l


func _make_slot_card(half: String, kind: String, index: int, merc_id: String) -> Control:
	var card := _FormationSlotCardScene.new()
	card.slot_half = half
	card.slot_kind = kind
	card.slot_index = index
	card.formation_ui = self
	var key := _slot_key(half, kind, index)
	var selected: bool = _selected.get("key", "") == key
	var vis: Dictionary = _slot_card_visual(merc_id, kind)
	card.apply_slot(
		merc_id,
		kind,
		index,
		selected,
		bool(vis.get("ready", false)),
		str(vis.get("name_text", "")),
		float(vis.get("hp_ratio", 0.0)),
		str(vis.get("badge", "")),
		vis.get("accent", Color.WHITE),
		vis.get("bg", Color(0.14, 0.17, 0.22))
	)
	return card


func _slot_card_visual(merc_id: String, kind: String) -> Dictionary:
	if merc_id == "":
		return {
			"ready": false,
			"name_text": "(空槽 · 拖入或点选未编入)",
			"hp_ratio": 0.0,
			"badge": "",
			"accent": Color(0.28, 0.3, 0.36),
			"bg": Color(0.1, 0.11, 0.14, 0.88),
		}
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m == null:
		return {
			"ready": false,
			"name_text": "未知单位",
			"hp_ratio": 0.0,
			"badge": "?",
			"accent": Color(0.4, 0.4, 0.45),
			"bg": Color(0.12, 0.12, 0.14, 0.9),
		}
	var max_hp: int = maxi(1, StatResolver.get_max_hp(m))
	var hp_ratio: float = float(m.current_hp) / float(max_hp)
	var ready: bool = _slot_merc_ready(m)
	var badge := "可出战" if ready else "休整"
	if m.is_mia:
		badge = "遗留"
	elif m.is_near_death:
		badge = "濒死"
	var tag := "★ " if GameManager.player and GameManager.player.merc_id == merc_id else ""
	var accent := Color(0.38, 0.72, 0.95) if kind == SLOT_ACTIVE else Color(0.45, 0.52, 0.62)
	if not ready:
		accent = Color(0.72, 0.48, 0.38) if m.is_near_death else Color(0.55, 0.5, 0.45)
	var bg := Color(0.15, 0.2, 0.28, 0.95) if ready else Color(0.14, 0.14, 0.17, 0.92)
	if m.is_test_stand_in:
		bg = Color(0.16, 0.22, 0.26, 0.95)
	return {
		"ready": ready,
		"name_text": "%s%s Lv.%d" % [tag, m.merc_name, m.level],
		"hp_ratio": hp_ratio,
		"badge": badge,
		"accent": accent,
		"bg": bg,
	}


func _apply_half_stage_style(panel: PanelContainer, half: String) -> void:
	var can_dep: bool = SquadFormationService.half_can_deploy(GameManager, half)
	var pref: bool = str(GameManager.squad_formation.get("active_half", "A")) == half
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.bg_color = HALF_STAGE_ACTIVE_BG if can_dep else HALF_STAGE_REST_BG
	if pref:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.35, 0.75, 1.0, 0.95)
	panel.add_theme_stylebox_override("panel", sb)


func _apply_player_panel_style() -> void:
	if _player_panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.bg_color = Color(0.12, 0.18, 0.26, 0.95)
	sb.border_width_left = 2
	sb.border_color = Color(0.45, 0.78, 1.0, 0.85)
	_player_panel.add_theme_stylebox_override("panel", sb)


func _on_auto_fill_preferred() -> void:
	var half: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	SquadFormationService.auto_fill_half(GameManager, half)
	GameManager.formation_changed.emit()


func _on_swap_halves() -> void:
	GameManager.formation_swap_halves()
	_selected = {}
	if _status_label:
		var pref: String = str(GameManager.squad_formation.get("active_half", "A"))
		_status_label.text = "已互换半组 A/B 编组（编组优先仍为半组 %s）" % pref
		_status_label.modulate = Color(0.75, 0.95, 0.85)


func _handle_pool_drop(data: Variant) -> void:
	if not (data is Dictionary):
		return
	if bool(data.get("from_pool", false)):
		return
	var half: String = str(data.get("half", ""))
	var kind: String = str(data.get("kind", ""))
	var index: int = int(data.get("index", -1))
	if half == "" or kind == "" or index < 0:
		return
	_clear_slot(half, kind, index)


func _handle_slot_drop(target_half: String, target_kind: String, target_index: int, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var merc_id: String = str(data.get("merc_id", ""))
	if merc_id == "":
		return
	if bool(data.get("from_pool", false)):
		if bool(data.get("bench_only", false)) and target_kind != SLOT_BENCH:
			if _status_label:
				_status_label.text = "养伤佣兵仅能拖入替补席"
				_status_label.modulate = Color.ORANGE_RED
			return
		var code_p: int = GameManager.formation_assign(merc_id, target_half, target_kind, target_index)
		_selected = {}
		_show_assign_feedback(code_p, merc_id, target_half, target_kind, target_index)
		return
	var src_half: String = str(data.get("half", ""))
	var src_kind: String = str(data.get("kind", ""))
	var src_index: int = int(data.get("index", -1))
	if src_half == target_half and src_kind == target_kind and src_index == target_index:
		return
	_selected = {}
	var target_merc: String = _get_slot_merc_id(target_half, target_kind, target_index)
	if src_half == target_half:
		var code: int = GameManager.formation_swap_slots(
			target_half, src_kind, src_index, target_kind, target_index
		)
		if code != 0:
			_show_assign_feedback(code, merc_id, target_half, target_kind, target_index)
		elif _status_label:
			_status_label.text = "已换位（半组%s）" % target_half
			_status_label.modulate = Color(0.75, 0.95, 0.85)
		return
	var code: int = GameManager.formation_assign(merc_id, target_half, target_kind, target_index)
	if code != 0:
		_show_assign_feedback(code, merc_id, target_half, target_kind, target_index)
		return
	if target_merc != "":
		var back: int = GameManager.formation_assign(target_merc, src_half, src_kind, src_index)
		if back != 0:
			_show_assign_feedback(back, merc_id, target_half, target_kind, target_index)
			return
		if _status_label:
			var moved := GameManager.find_mercenary_by_id(merc_id)
			var moved_name: String = moved.merc_name if moved else merc_id
			_status_label.text = "已跨半组互换 %s ↔ 半组%s" % [moved_name, target_half]
			_status_label.modulate = Color(0.75, 0.95, 0.85)
		return
	_show_assign_feedback(0, merc_id, target_half, target_kind, target_index)


func _clear_slot(half: String, kind: String, index: int) -> void:
	var removed_name: String = ""
	var mid: String = _get_slot_merc_id(half, kind, index)
	if mid != "":
		var m := GameManager.find_mercenary_by_id(mid)
		if m != null:
			removed_name = m.merc_name
	_selected = {}
	var code: int = GameManager.formation_clear_slot(half, kind, index)
	if code == 0 and _status_label:
		if removed_name != "":
			_status_label.text = "已移出至未编入：%s（半组%s·%s%d）" % [
				removed_name,
				half,
				"战" if kind == SLOT_ACTIVE else "替",
				index + 1,
			]
		_status_label.modulate = Color(0.75, 0.95, 0.85)
	elif code != 0 and _status_label:
		_status_label.text = GameManager.formation_error_message(code)
		_status_label.modulate = Color.ORANGE_RED


func _slot_text(merc_id: String, kind: String, index: int) -> String:
	if merc_id == "":
		return "%s%d · (空)" % ["战" if kind == SLOT_ACTIVE else "替", index + 1]
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m == null:
		return "%s%d · ?" % ["战" if kind == SLOT_ACTIVE else "替", index + 1]
	var tag := "★" if GameManager.player and GameManager.player.merc_id == merc_id else ""
	var max_hp: int = maxi(1, StatResolver.get_max_hp(m))
	var pct: int = int(float(m.current_hp) / float(max_hp) * 100.0)
	var st := "✓" if _slot_merc_ready(m) else "×"
	return "%s%d · %s%s %d/%d (%d%%) %s" % [
		"战" if kind == SLOT_ACTIVE else "替",
		index + 1,
		tag,
		m.merc_name,
		m.current_hp,
		max_hp,
		pct,
		st,
	]


func _slot_merc_ready(m: Mercenary) -> bool:
	if m == null or not m.is_alive:
		return false
	if m.is_test_stand_in:
		return true
	m.try_clear_near_death_for_deploy()
	if not m.can_join_squad():
		return false
	return m.get_hp_ratio() >= RosterHealth.DEPLOY_HP_RATIO


func _slot_color(merc_id: String) -> Color:
	if merc_id == "":
		return Color(0.55, 0.55, 0.6)
	var m := GameManager.find_mercenary_by_id(merc_id)
	if m == null:
		return Color.GRAY
	if m.is_test_stand_in or _slot_merc_ready(m):
		return Color(0.75, 0.9, 1.0) if m.is_test_stand_in else Color.WHITE
	if m.is_mia:
		return Color(0.55, 0.5, 0.65)
	if m.is_near_death:
		return Color(1.0, 0.5, 0.5)
	return Color.GOLD


func _half_column_head_text(half: String, can_dep: bool, pref: String) -> String:
	return "半组 %s · %s%s" % [
		half,
		"可出战" if can_dep else "休整",
		" · 编组优先★" if half == pref else "",
	]


func _on_pref_toolbar_pressed(half: String) -> void:
	call_deferred("_apply_pref_toolbar_pressed", half)


func _apply_pref_toolbar_pressed(half: String, retry: int = 0) -> void:
	if _refreshing or _refreshing_halves or _refresh_pending:
		if retry >= PREF_TOOLBAR_MAX_RETRIES:
			if _status_label:
				_status_label.text = "编组界面刷新中，请稍后再试"
				_status_label.modulate = Color.ORANGE_RED
			return
		call_deferred("_apply_pref_toolbar_pressed", half, retry + 1)
		return
	var current: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	if current == half:
		_on_preferred_half_already(half)
		return
	GameManager.formation_set_preferred_half(half)
	_selected = {}
	_sync_preferred_toolbar()
	_sync_preferred_column_headers()
	_set_preferred_half_status(half)
	if _camp_stage:
		_camp_stage.set_selection_highlight("")


func _sync_preferred_toolbar() -> void:
	var pref: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	for half in [SquadFormationService.HALF_A, SquadFormationService.HALF_B]:
		var btn: Button = _pref_buttons.get(half) as Button
		if btn == null:
			continue
		btn.text = "★半组%s优先" % half if half == pref else "半组%s优先" % half
		btn.disabled = half == pref


func _sync_preferred_column_headers() -> void:
	var pref: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	if _halves_row == null:
		return
	for shell in _halves_row.get_children():
		if not (shell is PanelContainer):
			continue
		var half: String = str(shell.get_meta("half", ""))
		if half not in [SquadFormationService.HALF_A, SquadFormationService.HALF_B]:
			continue
		_apply_half_stage_style(shell as PanelContainer, half)
		var margin := shell.get_child(0) as MarginContainer
		if margin == null or margin.get_child_count() == 0:
			continue
		var col := margin.get_child(0) as VBoxContainer
		if col == null:
			continue
		var head := col.get_node_or_null("HalfHead%s" % half) as Label
		if head == null:
			continue
		var can_dep: bool = SquadFormationService.half_can_deploy(GameManager, half)
		head.text = _half_column_head_text(half, can_dep, pref)
		if half == pref:
			head.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		else:
			head.remove_theme_color_override("font_color")


func _set_preferred_half_status(half: String) -> void:
	if _status_label == null:
		return
	var can: bool = SquadFormationService.half_can_deploy(GameManager, half)
	var deploy_h: String = SquadFormationService.resolve_deploy_half(GameManager)
	var extra := ""
	if deploy_h != "" and deploy_h != half:
		extra = "（下趟实际出征半组 %s）" % deploy_h
	_status_label.text = "已设半组 %s 为编组优先%s · %s" % [
		half,
		extra,
		"可出战" if can else "休整中·编满后可出征",
	]
	_status_label.modulate = Color(0.55, 0.92, 1.0)


func _on_preferred_half_already(half: String) -> void:
	if _status_label:
		_status_label.text = "半组 %s 已是编组优先半组" % half
		_status_label.modulate = Color(0.75, 0.9, 1.0)


func _on_slot_pressed(half: String, kind: String, index: int) -> void:
	var key := _slot_key(half, kind, index)
	if _selected.is_empty():
		_selected = {"half": half, "kind": kind, "index": index, "key": key}
		_show_slot_selection(half, kind, index)
		_refresh_selection_highlights()
		return
	if _selected.get("key", "") == key:
		var mid_same: String = _get_slot_merc_id(half, kind, index)
		if mid_same != "":
			_clear_slot(half, kind, index)
		else:
			_selected = {}
			_refresh_selection_highlights()
		return
	var sh: String = str(_selected.half)
	var sk: String = str(_selected.kind)
	var si: int = int(_selected.index)
	var mid: String = _get_slot_merc_id(sh, sk, si)
	var target_mid: String = _get_slot_merc_id(half, kind, index)
	var code: int = 0
	if sh == half:
		code = GameManager.formation_swap_slots(half, sk, si, kind, index)
		if code == 0:
			_selected = {}
			if _status_label:
				_status_label.text = "已换位（半组%s）" % half
				_status_label.modulate = Color(0.75, 0.95, 0.85)
		else:
			_show_assign_feedback(code, mid if mid != "" else target_mid, half, kind, index)
		return
	if mid != "":
		code = GameManager.formation_assign(mid, half, kind, index)
		if code == 0 and target_mid != "":
			code = GameManager.formation_assign(target_mid, sh, sk, si)
	elif target_mid != "":
		code = GameManager.formation_assign(target_mid, sh, sk, si)
	if code == 0 and (mid != "" or target_mid != ""):
		_selected = {}
		_show_assign_feedback(0, mid if mid != "" else target_mid, half, kind, index)
	elif code != 0:
		_show_assign_feedback(code, mid if mid != "" else target_mid, half, kind, index)


func _get_slot_merc_id(half: String, kind: String, index: int) -> String:
	var ids: Array[String] = SquadFormationService.get_active_ids(GameManager.squad_formation, half) if kind == SLOT_ACTIVE else SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	ids = _pad(ids, SquadFormationService.MAX_ACTIVE if kind == SLOT_ACTIVE else SquadFormationService.MAX_BENCH)
	if index >= 0 and index < ids.size():
		return ids[index]
	return ""


func _on_pool_merc_pressed(merc_id: String, bench_only: bool = false) -> void:
	var m := GameManager.find_mercenary_by_id(merc_id)
	if _status_label and m != null:
		_status_label.text = "编入 %s…" % m.merc_name
		_status_label.modulate = Color(0.85, 0.95, 1.0)
	elif _status_label:
		_status_label.text = "编入 %s…" % merc_id
		_status_label.modulate = Color(0.85, 0.95, 1.0)
	if m != null and m.is_mia:
		if _status_label:
			_status_label.text = "[遗留] 不可编入"
			_status_label.modulate = Color.ORANGE_RED
		return
	if not _selected.is_empty():
		var sh: String = str(_selected.half)
		var sk: String = str(_selected.kind)
		var si: int = int(_selected.index)
		if bench_only and sk != SLOT_BENCH:
			if _status_label:
				_status_label.text = "养伤佣兵仅能编入替补席，请先点选「替」空槽"
				_status_label.modulate = Color.ORANGE_RED
			return
		if (
			not bench_only
			and sk == SLOT_ACTIVE
			and m != null
			and not m.is_test_stand_in
			and not _slot_merc_ready(m)
		):
			if _status_label:
				_status_label.text = "该佣兵暂不可出战，请点选替补空槽"
				_status_label.modulate = Color.ORANGE_RED
			return
		var code_sel: int = GameManager.formation_assign(merc_id, sh, sk, si)
		_selected = {}
		_show_assign_feedback(code_sel, merc_id, sh, sk, si)
		return
	if bench_only:
		_assign_pool_to_bench(merc_id)
		return
	_assign_pool_auto(merc_id)


func _assign_pool_auto(merc_id: String) -> void:
	var half: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	if _try_assign_pool_to_half(merc_id, half, false):
		return
	var other: String = (
		SquadFormationService.HALF_B if half == SquadFormationService.HALF_A else SquadFormationService.HALF_A
	)
	if _try_assign_pool_to_half(merc_id, other, true):
		return
	if _status_label:
		_status_label.text = "两半组槽位已满或该佣兵已在编"
		_status_label.modulate = Color.ORANGE_RED


func _try_assign_pool_to_half(merc_id: String, half: String, _is_fallback: bool) -> bool:
	var last_code: int = 0
	var a_idx: int = _first_free_slot_index(half, SLOT_ACTIVE)
	if a_idx >= 0:
		var code: int = GameManager.formation_assign(merc_id, half, SLOT_ACTIVE, a_idx)
		if code == 0:
			_show_assign_feedback(0, merc_id, half, SLOT_ACTIVE, a_idx)
			return true
		last_code = code
	var b_idx: int = _first_free_slot_index(half, SLOT_BENCH)
	if b_idx >= 0:
		var code_b: int = GameManager.formation_assign(merc_id, half, SLOT_BENCH, b_idx)
		if code_b == 0:
			_show_assign_feedback(0, merc_id, half, SLOT_BENCH, b_idx)
			return true
		last_code = code_b
	if last_code != 0 and _status_label:
		_status_label.text = GameManager.formation_error_message(last_code)
		_status_label.modulate = Color.ORANGE_RED
	return false


func _assign_pool_to_bench(merc_id: String) -> void:
	var half: String = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
	var other: String = (
		SquadFormationService.HALF_B if half == SquadFormationService.HALF_A else SquadFormationService.HALF_A
	)
	for h in [half, other]:
		var b_idx: int = _first_free_slot_index(h, SLOT_BENCH)
		if b_idx >= 0:
			var code: int = GameManager.formation_assign(merc_id, h, SLOT_BENCH, b_idx)
			if code == 0:
				_show_assign_feedback(0, merc_id, h, SLOT_BENCH, b_idx)
				return
	if _status_label:
		_status_label.text = "替补席已满或该佣兵已在编"
		_status_label.modulate = Color.ORANGE_RED


func _show_slot_selection(half: String, kind: String, index: int) -> void:
	if _status_label == null:
		return
	var slot_name: String = "半组%s·%s%d" % [
		half,
		"战" if kind == SLOT_ACTIVE else "替",
		index + 1,
	]
	var mid: String = _get_slot_merc_id(half, kind, index)
	if mid != "":
		var m := GameManager.find_mercenary_by_id(mid)
		var name_text: String = m.merc_name if m else mid
		_status_label.text = "已选 %s（%s）— 再点另一槽换位，或点未编入填入" % [name_text, slot_name]
	else:
		_status_label.text = "已选空槽 %s — 点未编入佣兵或拖入填入" % slot_name
	_status_label.modulate = Color(0.7, 1.0, 0.85)


func _clear_pool_row() -> void:
	if _pool_body == null:
		return
	for child in _pool_body.get_children():
		_pool_body.remove_child(child)
		child.queue_free()


func _refresh_pool() -> void:
	if _pool_label == null:
		return
	_clear_pool_row()
	var in_form: Array[String] = []
	in_form.append_array(SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_A))
	in_form.append_array(SquadFormationService.get_bench_ids(GameManager.squad_formation, SquadFormationService.HALF_A))
	in_form.append_array(SquadFormationService.get_active_ids(GameManager.squad_formation, SquadFormationService.HALF_B))
	in_form.append_array(SquadFormationService.get_bench_ids(GameManager.squad_formation, SquadFormationService.HALF_B))
	var deploy_ids: Array[String] = []
	var rest_ids: Array[String] = []
	var mia_ids: Array[String] = []
	for e in GameManager.elite_roster:
		if e.merc_id in in_form:
			continue
		if e.is_test_stand_in or e.is_alive:
			if e.is_test_stand_in or _slot_merc_ready(e):
				deploy_ids.append(e.merc_id)
			elif e.is_mia:
				mia_ids.append(e.merc_id)
			else:
				rest_ids.append(e.merc_id)
	for n in GameManager.normal_roster:
		if n.merc_id in in_form:
			continue
		if n.is_test_stand_in or n.is_alive:
			if n.is_test_stand_in or _slot_merc_ready(n):
				deploy_ids.append(n.merc_id)
			elif n.is_mia:
				mia_ids.append(n.merc_id)
			else:
				rest_ids.append(n.merc_id)
	if _pool_body == null:
		return
	var total_n: int = deploy_ids.size() + rest_ids.size() + mia_ids.size()
	if total_n == 0:
		if not SquadFormationService.has_living_merc_roster(GameManager):
			_pool_label.text = "备战席 · 无佣兵"
		else:
			_pool_label.text = "备战席 · 全员已编入"
		var empty := Label.new()
		empty.text = "（空）"
		empty.modulate = Color(0.5, 0.58, 0.68)
		empty.add_theme_font_size_override("font_size", 10)
		_pool_body.add_child(empty)
		return
	_pool_label.text = "备战席 · %d人" % total_n
	deploy_ids = _unique_merc_ids(deploy_ids)
	rest_ids = _unique_merc_ids(rest_ids)
	mia_ids = _unique_merc_ids(mia_ids)
	if not deploy_ids.is_empty():
		_add_pool_section(_pool_body, "FormationPoolRow", deploy_ids, false, "可出战", false)
	if not rest_ids.is_empty():
		_add_pool_section(_pool_body, "FormationPoolRest", rest_ids, false, "养伤", true)
	if not mia_ids.is_empty():
		_add_pool_section(_pool_body, "FormationPoolMia", mia_ids, true, "遗留", false)


func _unique_merc_ids(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for mid in ids:
		if mid == "" or seen.has(mid):
			continue
		seen[mid] = true
		out.append(mid)
	return out


func _add_pool_section(
	parent: HBoxContainer,
	row_name: String,
	merc_ids: Array[String],
	not_clickable: bool,
	prefix: String = "",
	bench_only: bool = false
) -> void:
	if prefix != "":
		var lbl := Label.new()
		lbl.name = row_name + "Title"
		lbl.text = prefix
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.modulate = Color.DIM_GRAY if not_clickable else Color(0.7, 0.82, 0.92)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.custom_minimum_size = Vector2(0, 32)
		parent.add_child(lbl)
	var pending: Array[Dictionary] = []
	for mid in merc_ids:
		var b := FormationPoolButton.new()
		var m := GameManager.find_mercenary_by_id(mid)
		b.merc_id = mid
		b.formation_ui = self
		var label_text: String = m.merc_name if m else mid
		if m != null and m.is_mia:
			label_text = "%s·遗" % m.merc_name
		var tint := Color.WHITE
		if m != null:
			if m.is_mia:
				tint = Color(0.55, 0.5, 0.65)
			elif m.is_near_death:
				tint = Color(1.0, 0.5, 0.5)
			elif not _slot_merc_ready(m):
				tint = Color.GOLD
			else:
				tint = Color(0.85, 0.92, 1.0)
		parent.add_child(b)
		pending.append({
			"btn": b,
			"text": label_text,
			"not_clickable": not_clickable,
			"tint": tint,
			"bench_only": bench_only,
		})
	for entry in pending:
		var btn: FormationPoolButton = entry.btn
		btn.apply_pool(entry.text, entry.not_clickable, entry.tint, entry.bench_only)


func _first_free_slot_index(half: String, kind: String) -> int:
	var max_n: int = (
		SquadFormationService.MAX_ACTIVE if kind == SLOT_ACTIVE else SquadFormationService.MAX_BENCH
	)
	var ids: Array[String] = (
		SquadFormationService.get_active_ids(GameManager.squad_formation, half)
		if kind == SLOT_ACTIVE
		else SquadFormationService.get_bench_ids(GameManager.squad_formation, half)
	)
	ids = _pad(ids, max_n)
	for i in range(max_n):
		if ids[i] == "":
			return i
	return -1


func _show_assign_feedback(code: int, merc_id: String, half: String, kind: String, index: int) -> void:
	if _status_label == null:
		return
	if code != 0:
		_status_label.text = GameManager.formation_error_message(code)
		_status_label.modulate = Color.ORANGE_RED
		return
	var m := GameManager.find_mercenary_by_id(merc_id)
	var name_text: String = m.merc_name if m else merc_id
	_status_label.text = "已编入 %s → 半组%s·%s%d" % [
		name_text,
		half,
		"战" if kind == SLOT_ACTIVE else "替",
		index + 1,
	]
	_status_label.modulate = Color(0.75, 0.95, 0.85)


func _slot_key(half: String, kind: String, index: int) -> String:
	return "%s_%s_%d" % [half, kind, index]


func _pad(ids: Array[String], n: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(n):
		out.append(ids[i] if i < ids.size() else "")
	return out
