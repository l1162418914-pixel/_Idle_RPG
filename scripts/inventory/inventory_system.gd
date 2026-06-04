extends RefCounted
class_name InventorySystem
## 背包管理系统 — 管理 Equipment 数组的增删查改


var items: Array[Equipment] = []


# ─── 增删 ─────────────────────────────────────────────

func add(item: Equipment) -> void:
	items.append(item)


func remove(item: Equipment) -> bool:
	var idx := items.find(item)
	if idx == -1:
		return false
	items.remove_at(idx)
	return true


func remove_at(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	items.remove_at(index)
	return true


# ─── 查询 ─────────────────────────────────────────────

func get_by_slot(slot: String) -> Array[Equipment]:
	var result: Array[Equipment] = []
	for eq in items:
		if eq.slot == slot:
			result.append(eq)
	return result


## 返回指定槽位中最合适的装备（按 quality 排序，同品质按指定属性排序）
func get_best_for_slot(slot: String, stat: String = "") -> Equipment:
	var candidates := get_by_slot(slot)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Equipment, b: Equipment):
		if a.quality != b.quality:
			return a.quality > b.quality
		if stat != "":
			return a.stats.get(stat, 0) > b.stats.get(stat, 0)
		return false
	)
	return candidates[0]


func size() -> int:
	return items.size()


func is_empty() -> bool:
	return items.is_empty()


func has(item: Equipment) -> bool:
	return items.has(item)


func clear() -> void:
	items.clear()


func sort_items() -> void:
	InventoryService.sort_inventory(self)


func remove_items(to_remove: Array) -> int:
	var n := 0
	for item in to_remove:
		if item is Equipment and remove(item):
			n += 1
	return n


# ─── 序列化 ───────────────────────────────────────────

func to_dict_array() -> Array:
	var result: Array = []
	for eq in items:
		if eq is Equipment:
			result.append(eq.to_dict())
	return result


func from_dict_array(data: Array) -> void:
	items.clear()
	for d in data:
		if d is Dictionary:
			items.append(Equipment.from_dict(d))