extends SceneTree
## 诊断 BottomStage / ScrollContainer 实际尺寸（Godot 4.6 headless）

const _StageScene := preload("res://scenes/stage_window.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var win: Window = _StageScene.instantiate() as Window
	if win == null:
		push_error("stage_window load failed")
		quit(1)
		return
	root.add_child(win)
	await process_frame
	await process_frame
	var shell: StageShell = win.get_node_or_null("StageShell") as StageShell
	if shell == null:
		push_error("StageShell missing")
		quit(1)
		return
	shell.setup(null, null)
	await process_frame
	await process_frame
	shell.apply_state(GameManager.GameState.BASE)
	await process_frame
	await process_frame
	var bottom: BottomStage = shell.get_node_or_null("StageBar/BottomStage") as BottomStage
	if bottom == null:
		push_error("BottomStage missing")
		quit(1)
		return
	var scroll: ScrollContainer = bottom.get_node_or_null("CampScrollLane") as ScrollContainer
	var world: HBoxContainer = bottom.get_node_or_null("CampScrollLane/CampWorld") as HBoxContainer
	print("godot_version=", Engine.get_version_info())
	print("bottom_size=", bottom.size, " visible=", bottom.visible)
	if scroll:
		print("scroll_size=", scroll.size, " scroll_h=", scroll.scroll_horizontal)
	if world:
		print("world_size=", world.size, " world_min=", world.get_combined_minimum_size())
		for child in world.get_children():
			if child is Control:
				var c := child as Control
				print("  zone ", c.name, " size=", c.size, " min=", c.custom_minimum_size)
				var sky := c.get_node_or_null("Sky") as ColorRect
				if sky:
					print("    sky size=", sky.size)
	var bonfire: VisualSlot = bottom.get_node_or_null(
		"CampScrollLane/CampWorld/ZoneCenter/CampBonfire"
	) as VisualSlot
	if bonfire:
		print("bonfire visible=", bonfire.visible, " mode=", bonfire.get_display_mode(), " size=", bonfire.size)
	print("bonfire_visible_fn=", bottom.is_bonfire_visible())
	quit(0)
