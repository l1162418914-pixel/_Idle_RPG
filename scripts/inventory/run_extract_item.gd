class_name RunExtractItem
extends Resource
## 撤离物：占格；拾取后按 retreat_chance 可能触发守卫战

@export var item_id: String = ""
@export var item_name: String = ""
@export var retreat_chance: float = 0.7
@export var carry_value: int = 50
@export var grid_w: int = 1
@export var grid_h: int = 1
@export var bonus_gold: int = 0
@export var bonus_exp: int = 0

const _SCRIPT_PATH := "res://scripts/inventory/run_extract_item.gd"


static func _create():
	return load(_SCRIPT_PATH).new()


static func from_template(tpl: Dictionary):
	var it = _create()
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


static func roll_for_map(map_data: Dictionary):
	var map_id: String = str(map_data.get("map_id", ""))
	var pool: Array = _pool_for_map(map_id)
	if pool.is_empty():
		pool = _all_extract_templates()
	if pool.is_empty():
		return null
	var tpl: Dictionary = (pool[randi() % pool.size()] as Dictionary).duplicate()
	var mult: float = float(map_data.get("resource_yield", 1.0))
	var item = from_template(tpl)
	item.carry_value = maxi(1, int(float(item.carry_value) * mult))
	item.bonus_gold = int(float(item.bonus_gold) * mult)
	return item
