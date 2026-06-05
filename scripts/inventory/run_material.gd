class_name RunMaterial
extends Resource
## 出征物资（网格占格，material_value 可转返程物资护盾）

const _SCRIPT := preload("res://scripts/inventory/run_material.gd")

@export var material_id: String = ""
@export var item_name: String = ""
@export var material_value: int = 10
@export var grid_w: int = 1
@export var grid_h: int = 1


static func from_template(tpl: Dictionary) -> RunMaterial:
	var m: RunMaterial = _SCRIPT.new()
	m.material_id = str(tpl.get("id", ""))
	m.item_name = str(tpl.get("name", "物资"))
	m.material_value = maxi(1, int(tpl.get("material_value", 10)))
	m.grid_w = maxi(1, int(tpl.get("grid_w", 1)))
	m.grid_h = maxi(1, int(tpl.get("grid_h", 1)))
	return m


static func _all_loot_material_templates() -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var dl = tree.root.get_node_or_null("/root/DataLoader")
		if dl != null and dl.has_method("all_loot_materials"):
			return dl.all_loot_materials()
	if not FileAccess.file_exists("res://data/loot_materials.json"):
		return []
	var f = FileAccess.open("res://data/loot_materials.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed.get("materials", [])
	return []


static func roll_for_map(map_data: Dictionary, enemy_data: Dictionary) -> RunMaterial:
	var pool: Array = _all_loot_material_templates()
	if pool.is_empty():
		return null
	var tpl: Dictionary = pool[randi() % pool.size()].duplicate()
	var mult: float = float(map_data.get("resource_yield", 1.0))
	if enemy_data.get("is_boss", false):
		mult *= 1.35
	var mat: RunMaterial = from_template(tpl)
	mat.material_value = maxi(1, int(float(mat.material_value) * mult))
	return mat


func to_dict() -> Dictionary:
	return {
		"material_id": material_id,
		"item_name": item_name,
		"material_value": material_value,
		"grid_w": grid_w,
		"grid_h": grid_h,
	}


static func from_dict(data: Dictionary) -> RunMaterial:
	var m: RunMaterial = _SCRIPT.new()
	m.material_id = data.get("material_id", "")
	m.item_name = data.get("item_name", "")
	m.material_value = maxi(1, int(data.get("material_value", 10)))
	m.grid_w = maxi(1, int(data.get("grid_w", 1)))
	m.grid_h = maxi(1, int(data.get("grid_h", 1)))
	return m
