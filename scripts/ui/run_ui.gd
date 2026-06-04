extends Control
## RunUI — 出征中界面，显示距离、稳定度（战斗可视化由 CombatView 负责）

@onready var distance_label: Label = $MarginContainer/MainVBox/InfoHBox/DistanceLabel
@onready var stability_label: Label = $MarginContainer/MainVBox/InfoHBox/StabilityLabel


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: int) -> void:
	visible = (new_state == GameManager.GameState.RUNNING)


func update_display(run_data: Dictionary) -> void:
	if not visible:
		return
	
	if distance_label:
		var map_data = DataLoader.map_data(GameManager.selected_map_id)
		var max_dist = map_data.get("boss_distance", 600.0) if not map_data.is_empty() else 600.0
		distance_label.text = "距离: %.0f / %.0fm" % [run_data.get("distance", 0), max_dist]
	
	if stability_label:
		var st = run_data.get("stability", 100)
		var color = Color.GREEN
		if st <= 30: color = Color.RED
		elif st <= 50: color = Color.ORANGE
		elif st <= 70: color = Color.YELLOW
		stability_label.text = "稳定度: %d" % st
		stability_label.modulate = color
