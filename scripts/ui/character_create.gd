extends Control
## CharacterCreate — 入口：三槽位选择 / 新建角色

@onready var slot_panel: VBoxContainer = $MarginContainer/SlotPanel
@onready var slot_list_host: VBoxContainer = $MarginContainer/SlotPanel/SlotListHost
@onready var slot_hint_label: Label = $MarginContainer/SlotPanel/SlotHintLabel
@onready var main_panel: VBoxContainer = $MarginContainer/MainVBox
@onready var title_label: Label = $MarginContainer/MainVBox/TitleLabel
@onready var name_input: LineEdit = $MarginContainer/MainVBox/NameHBox/NameInput
@onready var class_select: OptionButton = $MarginContainer/MainVBox/ClassHBox/ClassSelect
@onready var preview_label: Label = $MarginContainer/MainVBox/PreviewLabel
@onready var create_button: Button = $MarginContainer/MainVBox/CreateButton
@onready var back_button: Button = $MarginContainer/MainVBox/BackButton
@onready var status_label: Label = $MarginContainer/MainVBox/StatusLabel
@onready var delete_dialog: ConfirmationDialog = $DeleteDialog

const CLASS_LIST: Array[Dictionary] = [
	{ "id": "warrior", "name": "战士" },
	{ "id": "mage", "name": "法师" },
	{ "id": "ranger", "name": "游侠" },
]

var _active_slot: int = 1
var _pending_delete_slot: int = -1
var _delete_then_create: bool = false


func _ready() -> void:
	if not create_button.pressed.is_connected(_on_create_pressed):
		create_button.pressed.connect(_on_create_pressed)
	if not class_select.item_selected.is_connected(_on_class_changed):
		class_select.item_selected.connect(_on_class_changed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if not delete_dialog.confirmed.is_connected(_on_delete_confirmed):
		delete_dialog.confirmed.connect(_on_delete_confirmed)
	_populate_class_select()
	_show_slot_panel()


func _show_slot_panel() -> void:
	slot_panel.show()
	main_panel.hide()
	_refresh_slot_list()
	if slot_hint_label:
		slot_hint_label.text = "选择槽位继续游戏，或在空槽位新建角色（共 %d 槽）" % SaveManager.MAX_SLOTS


func _show_create_ui(slot: int) -> void:
	_active_slot = slot
	slot_panel.hide()
	main_panel.show()
	title_label.text = "槽位 %d · 新建角色" % slot
	status_label.text = ""
	status_label.modulate = Color.WHITE
	name_input.text = ""
	_on_class_changed(class_select.selected)


func _refresh_slot_list() -> void:
	if slot_list_host == null:
		return
	for child in slot_list_host.get_children():
		child.queue_free()
	for summary in SaveManager.get_slot_list():
		if summary is Dictionary:
			_add_slot_row(summary)


func _add_slot_row(summary: Dictionary) -> void:
	var slot: int = int(summary.get("slot", 0))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 14)
	if bool(summary.get("exists", false)):
		var tag := ""
		if bool(summary.get("test_fixtures", false)):
			tag = " · [测试档 fixture]"
		var ts: String = str(summary.get("timestamp", ""))
		var time_part := (" · %s" % ts) if ts != "" else ""
		title.text = "槽位 %d：%s Lv.%d %s · 金币 %d%s%s" % [
			slot,
			str(summary.get("name", "")),
			int(summary.get("level", 1)),
			_class_display_name(str(summary.get("class_id", ""))),
			int(summary.get("gold", 0)),
			time_part,
			tag,
		]
		title.modulate = Color(0.82, 0.9, 1.0)
	else:
		title.text = "槽位 %d：（空）" % slot
		title.modulate = Color(0.55, 0.6, 0.68)
	box.add_child(title)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	if bool(summary.get("exists", false)):
		var cont_btn := Button.new()
		cont_btn.text = "继续游戏"
		cont_btn.pressed.connect(_on_continue_slot.bind(slot))
		actions.add_child(cont_btn)
		var new_btn := Button.new()
		new_btn.text = "覆盖并新建"
		new_btn.pressed.connect(_on_overwrite_slot.bind(slot))
		actions.add_child(new_btn)
		var del_btn := Button.new()
		del_btn.text = "删除存档"
		del_btn.pressed.connect(_on_delete_slot_pressed.bind(slot))
		actions.add_child(del_btn)
	else:
		var create_btn := Button.new()
		create_btn.text = "新建角色"
		create_btn.pressed.connect(_on_new_slot.bind(slot))
		actions.add_child(create_btn)
	box.add_child(actions)
	slot_list_host.add_child(panel)


func _on_continue_slot(slot: int) -> void:
	SaveManager.set_current_slot(slot)
	if not SaveManager.load_game(slot):
		status_label.text = "读档失败（槽位 %d）" % slot
		status_label.modulate = Color.RED
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_new_slot(slot: int) -> void:
	_active_slot = slot
	SaveManager.set_current_slot(slot)
	GameManager.reset_game_state()
	_show_create_ui(slot)


func _on_overwrite_slot(slot: int) -> void:
	_pending_delete_slot = slot
	_delete_then_create = true
	delete_dialog.title = "覆盖槽位 %d" % slot
	delete_dialog.dialog_text = (
		"将删除槽位 %d 的现有存档并新建角色。\n此操作不可撤销，确认吗？" % slot
	)
	delete_dialog.popup_centered()


func _on_delete_slot_pressed(slot: int) -> void:
	_pending_delete_slot = slot
	_delete_then_create = false
	delete_dialog.title = "删除存档"
	delete_dialog.dialog_text = "确认删除槽位 %d 的存档？此操作不可撤销。" % slot
	delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var slot: int = _pending_delete_slot
	var open_create: bool = _delete_then_create
	_pending_delete_slot = -1
	_delete_then_create = false
	if slot < 1:
		return
	SaveManager.delete_save(slot)
	if open_create:
		_on_new_slot(slot)
	else:
		_refresh_slot_list()


func _on_back_pressed() -> void:
	_show_slot_panel()


func _class_display_name(class_id: String) -> String:
	match class_id:
		"warrior":
			return "战士"
		"mage":
			return "法师"
		"ranger":
			return "游侠"
		_:
			return class_id


func _populate_class_select() -> void:
	class_select.clear()
	for i in range(CLASS_LIST.size()):
		var c: Dictionary = CLASS_LIST[i]
		class_select.add_item(str(c.name))
		class_select.set_item_metadata(i, c.id)


func _on_class_changed(index: int) -> void:
	var class_id: String = str(class_select.get_item_metadata(index))
	var template: Dictionary = DataLoader.player_class(class_id)
	if template.is_empty():
		preview_label.text = "数据加载失败"
		return
	var stats: Dictionary = template.get("base_stats", {})
	var hp: int = int(stats.get("hp", 0))
	var patk: int = int(stats.get("patk", 0))
	var matk: int = int(stats.get("matk", 0))
	var pdef: int = int(stats.get("pdef", 0))
	var mdef: int = int(stats.get("mdef", 0))
	var spd: int = int(stats.get("spd", 0))
	var skills: Array = template.get("passive_skills", [])
	var skill_str: String = ", ".join(skills) if skills.size() > 0 else "无"
	preview_label.text = """[%s 初始属性]
HP: %d  |  物攻: %d  |  魔攻: %d
物防: %d  |  魔防: %d  |  速度: %d
被动技能: %s""" % [
		template.get("name", "???"), hp, patk, matk, pdef, mdef, spd, skill_str
	]


func _on_create_pressed() -> void:
	var player_name: String = name_input.text.strip_edges()
	if player_name == "":
		status_label.text = "请输入角色名称"
		status_label.modulate = Color.RED
		return
	var class_id: String = str(class_select.get_item_metadata(class_select.selected))
	var template: Dictionary = DataLoader.player_class(class_id)
	if template.is_empty():
		status_label.text = "职业数据异常，请重试"
		status_label.modulate = Color.RED
		return
	SaveManager.set_current_slot(_active_slot)
	GameManager.player = Player.new()
	GameManager.player.merc_name = player_name
	GameManager.player.init_from_template(template)
	GameManager.elite_roster.clear()
	GameManager.normal_roster.clear()
	GameManager.selected_squad.clear()
	GameManager.squad_formation = {}
	SquadFormationService.ensure_formation(GameManager)
	SquadFormationService.rebalance_from_roster(GameManager)
	var got_starter: bool = GameManager.grant_starter_merc()
	GameManager.sync_always_unlocked_maps()
	GameManager.refresh_map_unlocks()
	GameManager.state = GameManager.GameState.BASE
	if not SaveManager.save_game(_active_slot):
		status_label.text = "存档失败，请重试"
		status_label.modulate = Color.RED
		return
	if got_starter:
		status_label.text = "槽位 %d 创建成功！已配备起始佣兵…" % _active_slot
	else:
		status_label.text = "槽位 %d 创建成功，进入游戏…" % _active_slot
	status_label.modulate = Color.GREEN
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")
