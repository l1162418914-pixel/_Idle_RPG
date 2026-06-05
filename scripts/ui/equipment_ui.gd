extends Control
## EquipmentUI — 背包与佣兵装备槽管理（使用 Mercenary.equip / unequip + InventorySystem）

signal closed

const SLOT_ORDER: Array[String] = [
	"weapon", "armor", "helmet", "boots", "ring", "amulet"
]

@onready var merc_tabs: HBoxContainer = $MarginContainer/MainVBox/MercTabs
@onready var stats_label: Label = $MarginContainer/MainVBox/StatsLabel
@onready var body_hbox: HBoxContainer = $MarginContainer/MainVBox/BodyHBox
@onready var left_panel: VBoxContainer = $MarginContainer/MainVBox/BodyHBox/LeftPanel
@onready var inventory_list: VBoxContainer = $MarginContainer/MainVBox/BodyHBox/LeftPanel/InventoryScroll/InventoryList
@onready var slots_list: VBoxContainer = $MarginContainer/MainVBox/BodyHBox/RightPanel/SlotsList
@onready var close_button: Button = $MarginContainer/MainVBox/CloseButton
@onready var status_label: Label = $MarginContainer/MainVBox/StatusLabel

var _selected_merc: Mercenary = null
var _merc_button_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	GameManager.state_changed.connect(_on_game_state_changed)
	_setup_inventory_toolbar()


func _on_game_state_changed(new_state: int) -> void:
	if new_state != GameManager.GameState.BASE:
		hide_panel()


func _setup_inventory_toolbar() -> void:
	if left_panel == null:
		return
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var sort_btn := Button.new()
	sort_btn.text = "一键整理"
	sort_btn.pressed.connect(_on_sort_inventory_pressed)
	bar.add_child(sort_btn)
	var sell_btn := Button.new()
	sell_btn.text = "出售破旧"
	sell_btn.tooltip_text = "出售背包中品质≤普通的未穿戴装备"
	sell_btn.pressed.connect(_on_sell_junk_pressed)
	bar.add_child(sell_btn)
	var inv_title := left_panel.get_node_or_null("InvTitle")
	if inv_title:
		left_panel.add_child(bar)
		left_panel.move_child(bar, inv_title.get_index() + 1)
	else:
		left_panel.add_child(bar)


func _on_sort_inventory_pressed() -> void:
	GameManager.organize_inventory()
	status_label.text = "背包已整理（按部位·品质排序）"
	status_label.modulate = Color.SKY_BLUE
	_refresh_inventory()


func _on_sell_junk_pressed() -> void:
	var result: Dictionary = GameManager.sell_inventory_junk(1)
	var count: int = int(result.get("count", 0))
	var gold: int = int(result.get("gold", 0))
	if count <= 0:
		status_label.text = "没有可出售的破旧装备（破损/普通且未穿戴）"
		status_label.modulate = Color.GRAY
	else:
		status_label.text = "已出售 %d 件，获得 %d 金币" % [count, gold]
		status_label.modulate = Color.GREEN
	_refresh_all()


func open_panel() -> void:
	if GameManager.state != GameManager.GameState.BASE:
		return
	visible = true
	_select_default_merc()
	_rebuild_merc_tabs()
	_refresh_all()
	status_label.text = ""


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _select_default_merc() -> void:
	if GameManager.player:
		_selected_merc = GameManager.player
	elif not GameManager.elite_roster.is_empty():
		_selected_merc = GameManager.elite_roster[0]
	elif not GameManager.normal_roster.is_empty():
		_selected_merc = GameManager.normal_roster[0]
	else:
		_selected_merc = null


func _rebuild_merc_tabs() -> void:
	for child in merc_tabs.get_children():
		child.queue_free()
	
	_add_merc_tab(GameManager.player, "[主角]")
	for e in GameManager.elite_roster:
		_add_merc_tab(e, "[精英]")
	for n in GameManager.normal_roster:
		_add_merc_tab(n, "[佣兵]")


func _add_merc_tab(merc: Mercenary, prefix: String) -> void:
	if merc == null:
		return
	var btn := Button.new()
	btn.text = "%s %s" % [prefix, merc.merc_name]
	btn.toggle_mode = true
	btn.button_group = _merc_button_group
	btn.pressed.connect(_on_merc_tab_pressed.bind(merc, btn))
	merc_tabs.add_child(btn)
	if merc == _selected_merc:
		btn.button_pressed = true


func _on_merc_tab_pressed(merc: Mercenary, btn: Button) -> void:
	_selected_merc = merc
	btn.button_pressed = true
	_refresh_all()


func _refresh_all() -> void:
	_refresh_stats()
	_refresh_inventory()
	_refresh_slots()


func _refresh_stats() -> void:
	if _selected_merc == null:
		stats_label.text = "未选择佣兵"
		return
	var m := _selected_merc
	var set_lines: Array[String] = EquipmentSetRegistry.get_active_bonus_lines(m)
	var set_text := ""
	if not set_lines.is_empty():
		set_text = " | 套装:" + ", ".join(set_lines)
	stats_label.text = "%s Lv.%d | HP:%d/%d | ATK:%d | DEF:%d%s" % [
		m.merc_name, m.level, m.current_hp,
		StatResolver.get_max_hp(m),
		StatResolver.get_patk(m),
		StatResolver.get_pdef(m),
		set_text
	]


func _refresh_inventory() -> void:
	for child in inventory_list.get_children():
		child.queue_free()

	var cap: int = GameManager.get_inventory_capacity()
	var used: int = GameManager.inventory.size()
	var inv_title := left_panel.get_node_or_null("InvTitle") as Label
	if inv_title:
		inv_title.text = "背包 (%d/%d)" % [used, cap]
	
	if GameManager.inventory.is_empty():
		var empty := Label.new()
		empty.text = "（背包为空）"
		inventory_list.add_child(empty)
		return
	
	for i in range(GameManager.inventory.items.size()):
		var item: Equipment = GameManager.inventory.items[i]
		if item == null:
			continue
		if _is_item_equipped_anywhere(item):
			continue
		var btn := Button.new()
		var price: int = InventoryService.get_sell_price(item)
		btn.text = "%s  售%d金" % [_format_item(item), price]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_inventory_item_pressed.bind(item))
		inventory_list.add_child(btn)


func _refresh_slots() -> void:
	for child in slots_list.get_children():
		child.queue_free()
	
	if _selected_merc == null:
		var hint := Label.new()
		hint.text = "请选择佣兵"
		slots_list.add_child(hint)
		return
	
	for slot_id in SLOT_ORDER:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		var slot_name := _slot_display_name(slot_id)
		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(56, 0)
		name_lbl.text = slot_name
		row.add_child(name_lbl)
		
		var item: Equipment = _selected_merc.equipment_slots.get(slot_id)
		var item_btn := Button.new()
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if item:
			item_btn.text = _format_item(item)
			item_btn.pressed.connect(_on_slot_item_pressed.bind(slot_id))
		else:
			item_btn.text = "（空）"
			item_btn.disabled = true
		row.add_child(item_btn)
		slots_list.add_child(row)


func _on_inventory_item_pressed(item: Equipment) -> void:
	if _selected_merc == null:
		status_label.text = "请先选择佣兵"
		return
	if _equip_from_inventory(_selected_merc, item):
		status_label.text = "已装备: %s" % item.item_name
		status_label.modulate = Color.GREEN
		_refresh_all()
	else:
		status_label.text = "无法装备（槽位冲突或已穿戴）"
		status_label.modulate = Color.RED


func _on_slot_item_pressed(slot_id: String) -> void:
	if _selected_merc == null:
		return
	if _unequip_to_inventory(_selected_merc, slot_id):
		status_label.text = "已卸下"
		status_label.modulate = Color.YELLOW
		_refresh_all()


func _equip_from_inventory(merc: Mercenary, item: Equipment) -> bool:
	if item == null or merc == null:
		return false
	if _is_item_equipped_anywhere(item):
		return false
	if not merc.equipment_slots.has(item.slot):
		return false
	
	if not GameManager.inventory.has(item):
		return false
	if not GameManager.inventory.remove(item):
		return false
	
	var old: Equipment = merc.equipment_slots[item.slot]
	if old != null and not GameManager.inventory.can_add():
		GameManager.inventory.add(item)
		status_label.text = "背包已满，无法替换装备"
		status_label.modulate = Color.ORANGE_RED
		return false
	if old != null:
		GameManager.inventory.add(old)
	merc.equip(item)
	return true


func _unequip_to_inventory(merc: Mercenary, slot_id: String) -> bool:
	if merc == null or not merc.equipment_slots.has(slot_id):
		return false
	var item: Equipment = merc.equipment_slots[slot_id]
	if item == null:
		return false
	if not GameManager.inventory.can_add():
		status_label.text = "背包已满 (%d/%d)，无法卸下" % [
			GameManager.inventory.size(), GameManager.get_inventory_capacity()
		]
		status_label.modulate = Color.ORANGE_RED
		return false
	merc.unequip(slot_id)
	if not GameManager.inventory.add(item):
		merc.equip(item)
		status_label.text = "背包已满，卸下失败"
		status_label.modulate = Color.ORANGE_RED
		return false
	return true


func _is_item_equipped_anywhere(item: Equipment) -> bool:
	return _find_merc_with_item(item) != null


func _find_merc_with_item(item: Equipment) -> Mercenary:
	if item == null:
		return null
	if GameManager.player:
		for slot in GameManager.player.equipment_slots:
			if GameManager.player.equipment_slots[slot] == item:
				return GameManager.player
	for e in GameManager.elite_roster:
		for slot in e.equipment_slots:
			if e.equipment_slots[slot] == item:
				return e
	for n in GameManager.normal_roster:
		for slot in n.equipment_slots:
			if n.equipment_slots[slot] == item:
				return n
	return null


func _format_item(item: Equipment) -> String:
	if item.set_id != "":
		return "[%s] %s ·%s" % [item.quality_name, item.item_name, EquipmentSetRegistry.get_set_name(item.set_id)]
	return "[%s] %s" % [item.quality_name, item.item_name]


func _slot_display_name(slot_id: String) -> String:
	var data := DataLoader.equipment_slot(slot_id)
	if data.is_empty():
		return slot_id
	return data.get("name", slot_id)


func _on_close_pressed() -> void:
	hide_panel()
	if SaveManager and is_instance_valid(SaveManager):
		SaveManager.save_game()
