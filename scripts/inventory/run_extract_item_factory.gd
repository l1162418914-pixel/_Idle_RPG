class_name RunExtractItemFactory
extends RefCounted
## 撤离物生成（与 RunExtractItem 分文件，避免 class_name 脚本自引用导致解析失败）

const _ITEM_SCRIPT := preload("res://scripts/inventory/run_extract_item.gd")


static func from_template(tpl: Dictionary) -> RunExtractItem:
	var it: RunExtractItem = _ITEM_SCRIPT.new()
	it.item_id = str(tpl.get("id", ""))
	it.item_name = str(tpl.get("name", "撤离物"))
	it.retreat_chance = clampf(float(tpl.get("retreat_chance", 0.7)), 0.0, 1.0)
	it.carry_value = maxi(1, int(tpl.get("carry_value", 50)))
	it.grid_w = maxi(1, int(tpl.get("grid_w", 1)))
	it.grid_h = maxi(1, int(tpl.get("grid_h", 1)))
	it.bonus_gold = int(tpl.get("bonus_gold", 0))
	it.bonus_exp = int(tpl.get("bonus_exp", 0))
	return it


static func roll_for_map(map_data: Dictionary) -> RunExtractItem:
	var map_id: String = str(map_data.get("map_id", ""))
	var pool: Array = _pool_for_map(map_id)
	if pool.is_empty():
		pool = _all_extract_templates()
	if pool.is_empty():
		return null
	var tpl: Dictionary = (pool[randi() % pool.size()] as Dictionary).duplicate()
	var mult: float = float(map_data.get("resource_yield", 1.0))
	var item: RunExtractItem = from_template(tpl)
	item.carry_value = maxi(1, int(float(item.carry_value) * mult))
	item.bonus_gold = int(float(item.bonus_gold) * mult)
	return item


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


static func _pool_for_map(map_id: String) -> Array:
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
