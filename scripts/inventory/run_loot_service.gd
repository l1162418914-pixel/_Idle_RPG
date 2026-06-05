class_name RunLootService
extends RefCounted
## 本趟战利品：优先安全箱，挤占低密度，溢出外露


static func init_run_grids(run) -> void:
	if run == null:
		return
	var safe_size: Vector2i = Vector2i(2, 2)
	if GameManager:
		safe_size = GameManager.get_safe_box_grid_size()
	var exposed_w: int = 4
	var exposed_h: int = 3
	if not run.map_data.is_empty():
		exposed_w = int(run.map_data.get("exposed_grid_w", exposed_w))
		exposed_h = int(run.map_data.get("exposed_grid_h", exposed_h))
	run.safe_loot = GridInventory.new(safe_size.x, safe_size.y)
	run.exposed_loot = GridInventory.new(exposed_w, exposed_h)


static func add_equipment_drop(run, equip: Equipment) -> Dictionary:
	if run == null or equip == null:
		return {"ok": false, "where": "none"}
	LootFootprint.assign_for_equipment(equip)
	if run.safe_loot == null or run.exposed_loot == null:
		init_run_grids(run)
	if run.safe_loot.place_auto(equip):
		return {"ok": true, "where": "safe"}
	if _try_evict_safe_and_place(run, equip):
		return {"ok": true, "where": "safe", "evicted": true}
	if run.exposed_loot.place_auto(equip):
		return {"ok": true, "where": "exposed"}
	if _try_evict_exposed_and_place(run, equip):
		return {"ok": true, "where": "exposed", "evicted": true}
	return {"ok": false, "where": "none"}


static func add_extract_item_drop(run, item) -> Dictionary:
	if run == null or item == null:
		return {"ok": false, "where": "none"}
	if run.safe_loot == null or run.exposed_loot == null:
		init_run_grids(run)
	if run.safe_loot.place_extract_auto(item):
		return {"ok": true, "where": "safe"}
	if run.exposed_loot.place_extract_auto(item):
		return {"ok": true, "where": "exposed"}
	return {"ok": false, "where": "none"}


static func add_material_drop(run, mat: RunMaterial) -> Dictionary:
	if run == null or mat == null:
		return {"ok": false, "where": "none"}
	if run.safe_loot == null or run.exposed_loot == null:
		init_run_grids(run)
	if run.safe_loot.place_material_auto(mat):
		return {"ok": true, "where": "safe"}
	if run.exposed_loot.place_material_auto(mat):
		return {"ok": true, "where": "exposed"}
	if _try_evict_exposed_equipment_for_material(run, mat):
		return {"ok": true, "where": "exposed", "evicted": true}
	return {"ok": false, "where": "none"}


## 手动斩仓：舍弃外露格，仅保留安全箱（返回舍弃件数）
static func abandon_exposed_loot(run) -> int:
	if run == null or run.exposed_loot == null:
		return 0
	var count: int = run.exposed_loot.item_count()
	run.exposed_loot.clear_all()
	if run.has_method("_sync_total_loot_cache"):
		run._sync_total_loot_cache()
	return count


static func collect_loot_for_settlement(run, manual: bool) -> Array[Equipment]:
	if run == null:
		return []
	if manual:
		if run.safe_loot:
			return run.safe_loot.get_all_equipment()
		return []
	return collect_all_equipment(run)


static func collect_all_equipment(run) -> Array[Equipment]:
	var list: Array[Equipment] = []
	if run == null:
		return list
	if run.safe_loot:
		list.append_array(run.safe_loot.get_all_equipment())
	if run.exposed_loot:
		for eq in run.exposed_loot.get_all_equipment():
			if eq not in list:
				list.append(eq)
	return list


static func _try_evict_safe_and_place(run, equip: Equipment) -> bool:
	var new_cells: int = LootFootprint.cell_count(equip)
	var new_density: float = float(EquipmentCompare.power_score(equip)) / float(maxi(1, new_cells))
	var worst: Equipment = null
	var worst_density: float = INF
	for existing in run.safe_loot.get_all_equipment():
		var c: int = LootFootprint.cell_count(existing)
		var d: float = float(EquipmentCompare.power_score(existing)) / float(maxi(1, c))
		if d < worst_density:
			worst_density = d
			worst = existing
	if worst == null or new_density <= worst_density:
		return false
	run.safe_loot.remove_equipment(worst)
	if not run.safe_loot.place_auto(equip):
		run.safe_loot.place_auto(worst)
		return false
	if not run.exposed_loot.place_auto(worst):
		pass
	return true


static func _try_evict_exposed_and_place(run, equip: Equipment) -> bool:
	if run == null or run.exposed_loot == null or equip == null:
		return false
	var new_cells: int = LootFootprint.cell_count(equip)
	var new_density: float = float(EquipmentCompare.power_score(equip)) / float(maxi(1, new_cells))
	var worst: Equipment = null
	var worst_density: float = INF
	for existing in run.exposed_loot.get_all_equipment():
		var c: int = LootFootprint.cell_count(existing)
		var d: float = float(EquipmentCompare.power_score(existing)) / float(maxi(1, c))
		if d < worst_density:
			worst_density = d
			worst = existing
	if worst == null or new_density <= worst_density:
		return false
	run.exposed_loot.remove_equipment(worst)
	if not run.exposed_loot.place_auto(equip):
		run.exposed_loot.place_auto(worst)
		return false
	return true


static func _try_evict_exposed_equipment_for_material(run, mat: RunMaterial) -> bool:
	if run == null or run.exposed_loot == null or mat == null:
		return false
	var removed: Equipment = run.exposed_loot.remove_lowest_density()
	if removed == null:
		return false
	if run.exposed_loot.place_material_auto(mat):
		return true
	run.exposed_loot.place_auto(removed)
	return false
