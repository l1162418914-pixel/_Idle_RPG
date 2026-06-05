class_name GridInventory
extends RefCounted
## 二维网格背包：Equipment + RunMaterial + 撤离物（extract_item 字典项，鸭子类型）


var width: int = 1
var height: int = 1
## { equipment, x, y }
var _entries: Array[Dictionary] = []


func _init(grid_w: int = 4, grid_h: int = 3) -> void:
	width = maxi(1, grid_w)
	height = maxi(1, grid_h)
	_entries.clear()


func reset_size(grid_w: int, grid_h: int) -> void:
	width = maxi(1, grid_w)
	height = maxi(1, grid_h)
	_entries.clear()


func is_empty() -> bool:
	return _entries.is_empty()


func clear_all() -> void:
	_entries.clear()


func item_count() -> int:
	return _entries.size()


func get_all_equipment() -> Array[Equipment]:
	var list: Array[Equipment] = []
	for e in _entries:
		var eq: Equipment = e.get("equipment")
		if eq != null:
			list.append(eq)
	return list


func get_all_extract_items() -> Array:
	var list: Array = []
	for e in _entries:
		var it = e.get("extract_item")
		if it != null:
			list.append(it)
	return list


func get_all_materials() -> Array:
	var list: Array = []
	for e in _entries:
		var mat = e.get("material")
		if mat != null:
			list.append(mat)
	return list


func get_total_material_value() -> int:
	var total := 0
	for mat in get_all_materials():
		total += mat.material_value
	return total


func get_used_cell_count() -> int:
	var n := 0
	for e in _entries:
		n += _entry_cell_count(e)
	return n


func get_capacity_cells() -> int:
	return width * height


func get_fill_ratio() -> float:
	var cap := get_capacity_cells()
	if cap <= 0:
		return 0.0
	return clampf(float(get_used_cell_count()) / float(cap), 0.0, 1.0)


func can_place_at(equip: Equipment, at_x: int, at_y: int) -> bool:
	if equip == null:
		return false
	for cell in LootFootprint.occupied_cells(at_x, at_y, equip):
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			return false
		if _cell_occupied(cell.x, cell.y):
			return false
	return true


func find_place_position(equip: Equipment) -> Vector2i:
	if equip == null:
		return Vector2i(-1, -1)
	for y in range(height):
		for x in range(width):
			if can_place_at(equip, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func place_auto(equip: Equipment) -> bool:
	var pos := find_place_position(equip)
	if pos.x < 0:
		return false
	return place_at(equip, pos.x, pos.y)


func place_at(equip: Equipment, at_x: int, at_y: int) -> bool:
	if not can_place_at(equip, at_x, at_y):
		return false
	_entries.append({"equipment": equip, "x": at_x, "y": at_y})
	return true


func remove_equipment(target: Equipment) -> bool:
	for i in range(_entries.size()):
		if _entries[i].get("equipment") == target:
			_entries.remove_at(i)
			return true
	return false


func remove_lowest_density() -> Equipment:
	if _entries.is_empty():
		return null
	var worst_idx := 0
	var worst_density: float = INF
	for i in range(_entries.size()):
		var eq: Equipment = _entries[i].get("equipment")
		var cells: int = LootFootprint.cell_count(eq)
		var density: float = float(EquipmentCompare.power_score(eq)) / float(maxi(1, cells))
		if density < worst_density:
			worst_density = density
			worst_idx = i
	var removed: Equipment = _entries[worst_idx].get("equipment")
	_entries.remove_at(worst_idx)
	return removed


func remove_random_equipment() -> Equipment:
	var equip_indices: Array[int] = []
	for i in range(_entries.size()):
		if _entries[i].has("equipment"):
			equip_indices.append(i)
	if equip_indices.is_empty():
		return null
	var pick: int = equip_indices[randi() % equip_indices.size()]
	var removed: Equipment = _entries[pick].get("equipment")
	_entries.remove_at(pick)
	return removed


func can_place_material_at(mat, at_x: int, at_y: int) -> bool:
	if mat == null:
		return false
	for cell in _material_cells(at_x, at_y, mat):
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			return false
		if _cell_occupied(cell.x, cell.y):
			return false
	return true


func place_extract_auto(item) -> bool:
	if item == null:
		return false
	for y in range(height):
		for x in range(width):
			if can_place_extract_at(item, x, y):
				_entries.append({"extract_item": item, "x": x, "y": y})
				return true
	return false


func can_place_extract_at(item, at_x: int, at_y: int) -> bool:
	if item == null:
		return false
	for cell in _extract_cells(at_x, at_y, item):
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			return false
		if _cell_occupied(cell.x, cell.y):
			return false
	return true


func place_material_auto(mat) -> bool:
	if mat == null:
		return false
	for y in range(height):
		for x in range(width):
			if can_place_material_at(mat, x, y):
				_entries.append({"material": mat, "x": x, "y": y})
				return true
	return false


## 按 material_value 从低到高消耗，返回实际消耗的价值
func consume_material_value(target: int) -> int:
	if target <= 0:
		return 0
	var mats: Array[Dictionary] = []
	for i in range(_entries.size()):
		var mat = _entries[i].get("material")
		if mat != null:
			mats.append({"index": i, "material": mat, "density": float(mat.material_value) / float(maxi(1, mat.grid_w * mat.grid_h))})
	mats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.density < b.density
	)
	var consumed := 0
	var to_remove: Array[int] = []
	for entry in mats:
		if consumed >= target:
			break
		var mat = entry.material
		consumed += mat.material_value
		to_remove.append(entry.index)
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		_entries.remove_at(idx)
	return mini(consumed, target)


func _cell_occupied(cx: int, cy: int) -> bool:
	for e in _entries:
		for cell in _entry_occupied_cells(e):
			if cell.x == cx and cell.y == cy:
				return true
	return false


func _entry_cell_count(entry: Dictionary) -> int:
	if entry.has("equipment"):
		return LootFootprint.cell_count(entry.get("equipment"))
	if entry.has("material"):
		var mat = entry.get("material")
		return maxi(1, mat.grid_w * mat.grid_h)
	if entry.has("extract_item"):
		var ex = entry.get("extract_item")
		return maxi(1, ex.grid_w * ex.grid_h)
	return 1


func _entry_occupied_cells(entry: Dictionary) -> Array[Vector2i]:
	var x: int = entry.get("x", 0)
	var y: int = entry.get("y", 0)
	if entry.has("equipment"):
		return LootFootprint.occupied_cells(x, y, entry.get("equipment"))
	if entry.has("material"):
		return _material_cells(x, y, entry.get("material"))
	if entry.has("extract_item"):
		return _extract_cells(x, y, entry.get("extract_item"))
	return []


func _extract_cells(at_x: int, at_y: int, item) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if item == null:
		return cells
	for dy in range(item.grid_h):
		for dx in range(item.grid_w):
			cells.append(Vector2i(at_x + dx, at_y + dy))
	return cells


func _material_cells(at_x: int, at_y: int, mat) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if mat == null:
		return cells
	for dy in range(mat.grid_h):
		for dx in range(mat.grid_w):
			cells.append(Vector2i(at_x + dx, at_y + dy))
	return cells
