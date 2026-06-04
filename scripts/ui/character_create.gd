extends Control
## CharacterCreate — 角色创建界面，游戏入口场景

@onready var main_panel: VBoxContainer = $MarginContainer/MainVBox
@onready var name_input: LineEdit = $MarginContainer/MainVBox/NameHBox/NameInput
@onready var class_select: OptionButton = $MarginContainer/MainVBox/ClassHBox/ClassSelect
@onready var preview_label: Label = $MarginContainer/MainVBox/PreviewLabel
@onready var create_button: Button = $MarginContainer/MainVBox/CreateButton
@onready var status_label: Label = $MarginContainer/MainVBox/StatusLabel
@onready var overwrite_dialog: ConfirmationDialog = $OverwriteDialog

const CLASS_LIST: Array[Dictionary] = [
	{ "id": "warrior", "name": "战士" },
	{ "id": "mage",    "name": "法师" },
	{ "id": "ranger", "name": "游侠" }
]


func _ready() -> void:
	if SaveManager.has_save():
		_show_overwrite_prompt()
	else:
		_show_create_ui()


func _show_overwrite_prompt() -> void:
	main_panel.hide()

	if overwrite_dialog == null:
		return

	var player = GameManager.player

	if player == null:
		overwrite_dialog.dialog_text = "检测到已有存档\n\n是否覆盖并重新创建角色？"
		overwrite_dialog.popup_centered()
		return

	overwrite_dialog.dialog_text = "检测到已有存档：\n%s (Lv.%d %s)\n\n是否覆盖并重新创建角色？" % [
		player.merc_name, player.level, _class_display_name(player.merc_class)
	]
	overwrite_dialog.popup_centered()


func _show_create_ui() -> void:
	main_panel.show()
	overwrite_dialog.hide()
	_populate_class_select()
	if not create_button.pressed.is_connected(_on_create_pressed):
		create_button.pressed.connect(_on_create_pressed)
	if not class_select.item_selected.is_connected(_on_class_changed):
		class_select.item_selected.connect(_on_class_changed)
	_on_class_changed(0)


func _on_overwrite_yes() -> void:
	SaveManager.delete_save(1)
	_show_create_ui()


func _on_overwrite_no() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _class_display_name(class_id: String) -> String:
	match class_id:
		"warrior": return "战士"
		"mage":    return "法师"
		"ranger": return "游侠"
		_: return class_id


func _populate_class_select() -> void:
	class_select.clear()
	for i in range(CLASS_LIST.size()):
		var c = CLASS_LIST[i]
		class_select.add_item(c.name)
		class_select.set_item_metadata(i, c.id)


func _on_class_changed(index: int) -> void:
	var class_id = class_select.get_item_metadata(index)
	var template = DataLoader.player_class(class_id)
	if template.is_empty():
		preview_label.text = "数据加载失败"
		return
	var stats = template.get("base_stats", {})
	var hp = stats.get("hp", 0)
	var patk = stats.get("patk", 0)
	var matk = stats.get("matk", 0)
	var pdef = stats.get("pdef", 0)
	var mdef = stats.get("mdef", 0)
	var spd = stats.get("spd", 0)
	var skills = template.get("passive_skills", [])
	var skill_str = ", ".join(skills) if skills.size() > 0 else "无"
	preview_label.text = """[%s 初始属性]
HP: %d  |  物攻: %d  |  魔攻: %d
物防: %d  |  魔防: %d  |  速度: %d
被动技能: %s""" % [template.get("name", "???"), hp, patk, matk, pdef, mdef, spd, skill_str]


func _on_create_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name == "":
		status_label.text = "请输入角色名称"
		status_label.modulate = Color.RED
		return
	var class_id = class_select.get_item_metadata(class_select.selected)
	var template = DataLoader.player_class(class_id)
	if template.is_empty():
		status_label.text = "职业数据异常，请重试"
		status_label.modulate = Color.RED
		return
	GameManager.player = Player.new()
	GameManager.player.merc_name = player_name
	GameManager.player.init_from_template(template)
	

	
	GameManager.state = GameManager.GameState.BASE
	if not SaveManager.save_game(1):
		status_label.text = "存档失败，请重试"
		status_label.modulate = Color.RED
		return
	status_label.text = "创建成功，进入游戏..."
	status_label.modulate = Color.GREEN
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")
