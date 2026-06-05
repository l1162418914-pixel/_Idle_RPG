class_name ExtractItemService
extends RefCounted


static func try_drop_on_defeat(run: WorldRun, enemy_data: Dictionary) -> void:
	if run == null or run.is_retreating:
		return
	if run.boss_defeated or run.extract_guard_cleared:
		return
	var chance: float = float(run.map_data.get("extract_drop_chance", 0.04))
	if enemy_data.get("is_boss", false) and not enemy_data.get("is_chase_encounter", false):
		return
	if enemy_data.get("is_chase_encounter", false):
		return
	if run._rng.randf() >= chance:
		return
	var item: RunExtractItem = RunExtractItem.roll_for_map(run.map_data)
	if item == null:
		return
	var placed: Dictionary = RunLootService.add_extract_item_drop(run, item)
	if not placed.get("ok", false):
		return
	resolve_on_pickup(run, item)


static func resolve_on_pickup(run: WorldRun, item: RunExtractItem) -> void:
	if run == null or item == null:
		return
	run.last_extract_item_name = item.item_name
	if run._rng.randf() < item.retreat_chance:
		run.pending_extract_guard = item
		run.emit_signal(
			"run_event",
			"extract_guard_triggered",
			{"item_name": item.item_name, "chance": item.retreat_chance}
		)
	else:
		run.emit_signal(
			"run_event",
			"extract_item_secured",
			{"item_name": item.item_name, "carry_value": item.carry_value}
		)


static func apply_clear_bonus(run: WorldRun) -> void:
	if run == null or run.pending_extract_guard == null:
		return
	var item: RunExtractItem = run.pending_extract_guard
	run.total_gold_earned += item.bonus_gold
	run.total_exp_earned += item.bonus_exp
	var drop: Equipment = LootSystem.roll_equipment(run.map_data, {"level": 5, "is_boss": false}, 0.1, 1)
	if drop != null:
		run._add_run_loot(drop)
	run.pending_extract_guard = null
