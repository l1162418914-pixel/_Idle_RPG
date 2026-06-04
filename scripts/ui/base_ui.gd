extends Control
## BaseUI — 基地主界面

@onready var gold_label: Label = $MarginContainer/MainVBox/GoldLabel
@onready var buildings_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Buildings
@onready var roster_container: VBoxContainer = $MarginContainer/MainVBox/Scroll/Content/Roster
@onready var action_buttons: HFlowContainer = $MarginContainer/MainVBox/Actions


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
		var label = Label.new()
		label.custom_minimum_size = Vector2(0, 24)
		if e.is_dead():
			label.text = "[精英·死亡] %s Lv.%d HP:0/%d ATK:%d" % [
				e.merc_name, e.level,
				EquipmentSystem.get_max_hp(e),
				EquipmentSystem.get_attack(e)
			]
			label.modulate = Color.DIM_GRAY
		else:
			label.text = "[精英] %s Lv.%d HP:%d/%d ATK:%d" % [
				e.merc_name, e.level, e.current_hp,
				EquipmentSystem.get_max_hp(e),
				EquipmentSystem.get_attack(e)
			]
		roster_container.add_child(label)
	
	for n in GameManager.normal_roster:
		var label = Label.new()
		label.custom_minimum_size = Vector2(0, 24)
		if n.is_dead():
			label.text = "[佣兵·死亡] %s Lv.%d HP:0/%d ATK:%d" % [
				n.merc_name, n.level,
				EquipmentSystem.get_max_hp(n),
				EquipmentSystem.get_attack(n)
			]
			label.modulate = Color.DIM_GRAY
		else:
			label.text = "[佣兵] %s Lv.%d HP:%d/%d ATK:%d" % [
				n.merc_name, n.level, n.current_hp,
				EquipmentSystem.get_max_hp(n),
				EquipmentSystem.get_attack(n)
			]
		roster_container.add_child(label)


func _on_upgrade_pressed(building_id: String) -> void:
	GameManager.upgrade_building(building_id)
	_refresh()


func _on_explore_pressed() -> void:
	# TODO: 打开地图选择
	GameManager.start_prepare("grassland")
