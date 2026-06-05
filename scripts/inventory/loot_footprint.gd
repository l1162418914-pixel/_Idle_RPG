class_name LootFootprint
extends RefCounted
## 掉落占格：首期 1×1、1×2、2×1、2×2（固定朝向，不旋转）


static func assign_for_equipment(equip) -> void:
	if equip == null:
		return
	if equip.grid_w > 0 and equip.grid_h > 0:
		return
	var roll: float = randf()
	if equip.quality <= 1:
		equip.grid_w = 1
		equip.grid_h = 1
	elif equip.quality == 2:
		if roll < 0.55:
			equip.grid_w = 1
			equip.grid_h = 1
		elif roll < 0.775:
			equip.grid_w = 1
			equip.grid_h = 2
		else:
			equip.grid_w = 2
			equip.grid_h = 1
	elif equip.quality == 3:
		if roll < 0.35:
			equip.grid_w = 1
			equip.grid_h = 2
		elif roll < 0.7:
			equip.grid_w = 2
			equip.grid_h = 1
		else:
			equip.grid_w = 2
			equip.grid_h = 2
	else:
		if roll < 0.25:
			equip.grid_w = 2
			equip.grid_h = 1
		elif roll < 0.5:
			equip.grid_w = 1
			equip.grid_h = 2
		else:
			equip.grid_w = 2
			equip.grid_h = 2


static func cell_count(equip) -> int:
	if equip == null:
		return 1
	return maxi(1, equip.grid_w * equip.grid_h)


static func occupied_cells(x: int, y: int, equip) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if equip == null:
		return cells
	for dy in range(equip.grid_h):
		for dx in range(equip.grid_w):
			cells.append(Vector2i(x + dx, y + dy))
	return cells
