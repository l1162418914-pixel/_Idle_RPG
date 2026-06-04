extends Control
## BaseUI — 基地主界面

@onready var gold_label: Label = $MarginContainer/MainVBox/GoldLabel
@onready var buildings_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Buildings
@onready var roster_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Roster
@onready var action_buttons: HFlowContainer = $MarginContainer/MainVBox/Actions
@onready var status_label: Label = $MarginContainer/MainVBox/StatusLabel


func _ready() -> void:
	GameManager.gold_changed.connect(_update_gold)
	GameManager.state_changed.connect(_on_state_changed)
	_refresh()


func _update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = "金币: %d" % amount


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.BASE)


func _refresh() -> void:
	if gold_label:
		gold_label.text = "金币: %d" % GameManager.gold
	
	_refresh_buildings()
	_refresh_roster()


func _refresh_buildings() -> void:
	for child in buildings_container.get_children():
		child.queue_free()
	
	var all_data = DataLoader.all_building_data()
	for bdata in all_data:
		var bid = bdata.building_id
		var lv = GameManager.get_building_level(bid)
		var max_lv = bdata.max_level
		var label = Label.new()
		label.custom_minimum_size = Vector2(0, 24)
		
		var cost_str = ""
		if lv < max_lv:
			var cost = bdata.upgrade_costs.gold[lv]
			cost_str = "  升级: %d金币" % cost
		else:
			cost_str = "  (已满级)"
		
		label.text = "%s Lv.%d/%d%s" % [bdata.name, lv, max_lv, cost_str]
		buildings_container.add_child(label)


func _refresh_roster() -> void:
	for child in roster_container.get_children():
		child.queue_free()
	
	var player = GameManager.player
	if player:
		var pl_label = Label.new()
		pl_label.custom_minimum_size = Vector2(0, 24)
		if player.is_dead():
			pl_label.text = "[主角·死亡] %s Lv.%d HP:0/%d ATK:%d (复活可用)" % [
				player.merc_name, player.level,
				EquipmentSystem.get_max_hp(player),
				EquipmentSystem.get_attack(player)
			]
			pl_label.modulate = Color.DIM_GRAY
		else:
			pl_label.text = "[主角] %s Lv.%d HP:%d/%d ATK:%d" % [
				player.merc_name, player.level, player.current_hp,
				EquipmentSystem.get_max_hp(player),
				EquipmentSystem.get_attack(player)
			]
		roster_container.add_child(pl_label)
	
	for e in GameManager.elite_roster:
		_add_merc_row("[精英]", e.merc_name, e.level, e.current_hp,
			EquipmentSystem.get_max_hp(e), EquipmentSystem.get_attack(e),
			e.is_dead(), "elite", e.merc_id)
	
	for n in GameManager.normal_roster:
		_add_merc_row("[佣兵]", n.merc_name, n.level, n.current_hp,
			EquipmentSystem.get_max_hp(n), EquipmentSystem.get_attack(n),
			n.is_dead(), "normal", n.merc_id)


func _add_merc_row(tag: String, name: String, lv: int, hp: int, max_hp: int, atk: int,
		is_dead: bool, merc_type: String, merc_id: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_dead:
		label.text = "%s·死亡 %s Lv.%d HP:0/%d ATK:%d" % [tag, name, lv, max_hp, atk]
		label.modulate = Color.DIM_GRAY
	else:
		label.text = "%s %s Lv.%d HP:%d/%d ATK:%d" % [tag, name, lv, hp, max_hp, atk]
	row.add_child(label)
	
	var btn: Button = Button.new()
	btn.text = "解雇"
	btn.custom_minimum_size = Vector2(48, 24)
	btn.set_meta("merc_type", merc_type)
	btn.set_meta("merc_id", merc_id)
	btn.pressed.connect(_on_dismiss_pressed.bind(btn))
	row.add_child(btn)
	
	roster_container.add_child(row)


func _on_dismiss_pressed(btn: Button) -> void:
	var merc_type: String = btn.get_meta("merc_type", "")
	var merc_id: String = btn.get_meta("merc_id", "")
	GameManager.dismiss_merc(merc_type, merc_id)
	status_label.text = "[解雇] 已解雇佣兵"
	status_label.modulate = Color.YELLOW
	_refresh()


func _on_upgrade_pressed(building_id: String) -> void:
	GameManager.upgrade_building(building_id)
	_refresh()


func _on_explore_pressed() -> void:
	# TODO: 打开地图选择
	GameManager.start_prepare("grassland")


## 显示招募结果反馈。code: 0=成功, -1=金币不足, -2=槽位满, -3=无模板
func show_recruit_result(merc_type: String, code: int) -> void:
	if not status_label:
		return
	match code:
		0:
			status_label.text = "[招募] 获得新%s佣兵！" % ("精英" if merc_type == "elite" else "")
			status_label.modulate = Color.GREEN
		-1:
			status_label.text = "[招募失败] 金币不足"
			status_label.modulate = Color.RED
		-2:
			status_label.text = "[招募失败] 槽位已满，请升级佣兵大厅"
			status_label.modulate = Color.RED
		-3:
			status_label.text = "[招募失败] 暂无可用模板"
			status_label.modulate = Color.RED
		_:
			status_label.text = "[招募失败] 未知错误(%d)" % code
			status_label.modulate = Color.RED
