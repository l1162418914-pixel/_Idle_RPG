class_name CarryValueService
extends RefCounted


static func compute(run: WorldRun, safe_only: bool = false) -> int:
	if run == null:
		return 0
	var total := 0
	if run.safe_loot:
		total += _grid_value(run.safe_loot)
	if not safe_only and run.exposed_loot:
		total += _grid_value(run.exposed_loot)
	return total


static func _grid_value(grid: GridInventory) -> int:
	var total := 0
	for eq in grid.get_all_equipment():
		total += EquipmentCompare.power_score(eq)
	total += grid.get_total_material_value()
	for item in grid.get_all_extract_items():
		total += item.carry_value
	return total
