extends Control
## ResultUI — 出征结算界面

@onready var result_label: Label = $MarginContainer/MainVBox/ResultLabel
@onready var stats_label: Label = $MarginContainer/MainVBox/StatsLabel
@onready var loot_container: VBoxContainer = $MarginContainer/MainVBox/LootContainer
@onready var return_button: Button = $MarginContainer/MainVBox/ReturnButton


func _ready() -> void:
	GameManager.run_ended.connect(_show_result)
	GameManager.state_changed.connect(_on_state_changed)
	if return_button:
		return_button.pressed.connect(_on_return_pressed)


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.RESULT)


func _show_result(result: Dictionary) -> void:
	if not visible:
		return
	
	var success = result.get("player_alive", false) and not result.get("forced_withdraw", false)
	var boss = result.get("boss_defeated", false)
	
	var title = ""
	if boss:
		title = "Boss讨伐成功!"
	elif success:
		title = "安全撤离"
	else:
		title = "强制撤离..."
	
	if result_label:
		result_label.text = title
	
	if stats_label:
		stats_label.text = "击杀敌人: %d\n获得金币: %d\n获得装备: %d件\n行进距离: %.0fm" % [
			result.get("enemies_defeated", 0),
			result.get("total_gold", 0),
			result.get("total_loot", []).size(),
			result.get("distance", 0)
		]
	
	_refresh_loot(result.get("total_loot", []))


func _refresh_loot(loot: Array) -> void:
	for child in loot_container.get_children():
		child.queue_free()
	
	if loot.is_empty():
		var label = Label.new()
		label.text = "无掉落"
		loot_container.add_child(label)
		return
	
	for item in loot:
		if item == null:
			continue
		var label = Label.new()
		label.text = "[%s] %s" % [item.quality_name, item.item_name]
		if item.quality >= 3:
			label.modulate = Color(item.get_color())
		loot_container.add_child(label)


func _on_return_pressed() -> void:
	GameManager.return_to_base()