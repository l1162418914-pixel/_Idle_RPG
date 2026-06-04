extends Control
## SquadUI — 出征编队界面

@onready var available_list: VBoxContainer = $MarginContainer/MainVBox/RosterHBox/LeftPanel/AvailableScroll/Available
@onready var selected_list: VBoxContainer = $MarginContainer/MainVBox/RosterHBox/RightPanel/SelectedScroll/Selected
@onready var map_label: Label = $MarginContainer/MainVBox/MapLabel
@onready var start_button: Button = $MarginContainer/MainVBox/ButtonHBox/StartButton
@onready var back_button: Button = $MarginContainer/MainVBox/ButtonHBox/BackButton

var _selected_ids: Array[String] = []


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.PREPARE)
	if visible:
		_refresh()


func _refresh() -> void:
	_selected_ids.clear()
	GameManager.selected_squad.clear()
	
	# 预选所有存活佣兵，死亡角色不入选
	if GameManager.player and GameManager.player.is_alive:
		_selected_ids.append(GameManager.player.merc_id)
	for e in GameManager.elite_roster:
		if e.is_alive:
			_selected_ids.append(e.merc_id)
	for n in GameManager.normal_roster:
		if n.is_alive:
			_selected_ids.append(n.merc_id)
	
	if map_label:
		map_label.text = "地图: %s" % GameManager.selected_map_id
	
	_refresh_available()
	_refresh_selected()
	_update_start_button()


func _refresh_available() -> void:
	if not available_list:
		return
	for child in available_list.get_children():
		child.queue_free()
	
	var player = GameManager.player
	if player:
		var btn = _make_merc_button(player, true)
		available_list.add_child(btn)
	
	for e in GameManager.elite_roster:
		var btn = _make_merc_button(e, false)
		available_list.add_child(btn)
	
	for n in GameManager.normal_roster:
		var btn = _make_merc_button(n, false)
		available_list.add_child(btn)


func _make_merc_button(merc: Mercenary, is_player: bool) -> Button:
	var btn = Button.new()
	var prefix = "[主角]" if is_player else ("[精英]" if merc is EliteMercenary else "[佣兵]")
	
	if merc.is_dead():
		btn.text = "%s %s Lv.%d [阵亡]" % [prefix, merc.merc_name, merc.level]
		btn.modulate = Color.DIM_GRAY
		btn.disabled = true
	else:
		btn.text = "%s %s Lv.%d HP:%d/%d ATK:%d" % [prefix, merc.merc_name, merc.level, merc.current_hp, EquipmentSystem.get_max_hp(merc), EquipmentSystem.get_attack(merc)]
		btn.pressed.connect(_on_merc_selected.bind(merc.merc_id, btn))
		if merc.merc_id in _selected_ids:
			btn.modulate = Color.GREEN
	
	return btn


func _on_merc_selected(merc_id: String, btn: Button) -> void:
	if merc_id in _selected_ids:
		_selected_ids.erase(merc_id)
		btn.modulate = Color.WHITE
	else:
		_selected_ids.append(merc_id)
		btn.modulate = Color.GREEN
	_refresh_selected()
	_update_start_button()


func _refresh_selected() -> void:
	if not selected_list:
		return
	for child in selected_list.get_children():
		child.queue_free()
	
	GameManager.selected_squad.clear()
	
	for mid in _selected_ids:
		var merc = _find_merc(mid)
		if merc:
			GameManager.selected_squad.append(merc)
			var label = Label.new()
			label.text = "%s Lv.%d ATK:%d" % [merc.merc_name, merc.level, EquipmentSystem.get_attack(merc)]
			selected_list.add_child(label)


func _find_merc(merc_id: String) -> Mercenary:
	if GameManager.player and GameManager.player.merc_id == merc_id:
		return GameManager.player
	for e in GameManager.elite_roster:
		if e.merc_id == merc_id:
			return e
	for n in GameManager.normal_roster:
		if n.merc_id == merc_id:
			return n
	return null


func _update_start_button() -> void:
	if start_button:
		start_button.disabled = _selected_ids.size() < 1


func _on_start_pressed() -> void:
	if GameManager.selected_squad.size() < 1:
		return
	GameManager.start_run()


func _on_back_pressed() -> void:
	GameManager.return_to_base()