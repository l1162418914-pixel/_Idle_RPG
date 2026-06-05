extends RefCounted
## 撤离物掉落/守卫（无 class_name，避免与 WorldRun 全局类循环依赖）

const _EXTRACT_ITEM_SCRIPT := preload("res://scripts/inventory/run_extract_item.gd")


static func try_drop_on_defeat(run, enemy_data: Dictionary) -> void:
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
	var item = roll_extract_for_map(run.map_data)
	if item == null:
		return
	var placed: Dictionary = RunLootService.add_extract_item_drop(run, item)
	if not placed.get("ok", false):
		return
	resolve_on_pickup(run, item)


static func resolve_on_pickup(run, item) -> void:
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


static func apply_clear_bonus(run) -> void:
	if run == null or run.pending_extract_guard == null:
		return
	var item = run.pending_extract_guard
	run.total_gold_earned += item.bonus_gold
	run.total_exp_earned += item.bonus_exp
	var drop = LootSystem.roll_equipment(run.map_data, {"level": 5, "is_boss": false}, 0.1, 1)
	if drop != null:
		run._add_run_loot(drop)
	run.pending_extract_guard = null


static func roll_extract_for_map(map_data: Dictionary):
	var map_id: String = str(map_data.get("map_id", ""))
	var pool: Array = _extract_pool_for_map(map_id)
	if pool.is_empty():
		pool = _all_extract_templates()
	if pool.is_empty():
		return null
	var tpl: Dictionary = (pool[randi() % pool.size()] as Dictionary).duplicate()
	var mult: float = float(map_data.get("resource_yield", 1.0))
	var item = _extract_from_template(tpl)
	item.carry_value = maxi(1, int(float(item.carry_value) * mult))
	item.bonus_gold = int(float(item.bonus_gold) * mult)
	return item


static func _extract_from_template(tpl: Dictionary):
	var it = _EXTRACT_ITEM_SCRIPT.new()
	it.item_id = str(tpl.get("id", ""))
	it.item_name = str(tpl.get("name", "撤离物"))
	it.retreat_chance = clampf(float(tpl.get("retreat_chance", 0.7)), 0.0, 1.0)
	it.carry_value = maxi(1, int(tpl.get("carry_value", 50)))
	it.grid_w = maxi(1, int(tpl.get("grid_w", 1)))
	it.grid_h = maxi(1, int(tpl.get("grid_h", 1)))
	it.bonus_gold = int(tpl.get("bonus_gold", 0))
	it.bonus_exp = int(tpl.get("bonus_exp", 0))
	return it


static func _all_extract_templates() -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var dl = tree.root.get_node_or_null("/root/DataLoader")
		if dl != null and dl.has_method("all_extract_items"):
			return dl.all_extract_items()
	return _read_extract_items_from_disk()


static func _read_extract_items_from_disk() -> Array:
	if not FileAccess.file_exists("res://data/extract_items.json"):
		return []
	var f = FileAccess.open("res://data/extract_items.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed.get("items", [])
	return []


static func _extract_pool_for_map(map_id: String) -> Array:
	var pool: Array = []
	for tpl in _all_extract_templates():
		if tpl is not Dictionary:
			continue
		var allowed: Array = tpl.get("maps", [])
		if allowed is Array and allowed.size() > 0:
			if map_id in allowed:
				pool.append(tpl)
		else:
			pool.append(tpl)
	return pool
