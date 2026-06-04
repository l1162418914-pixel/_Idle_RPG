extends Resource
class_name Equipment
## 装备 — 7品质 + 前后缀 + 基础属性

@export var slot: String = ""
@export var quality: int = 1
@export var quality_name: String = ""
@export var prefix_name: String = ""
@export var stats: Dictionary = {}
@export var item_name: String = ""
@export var item_id: String = ""
## 套装 id（可选，见 equipment_sets.json）
@export var set_id: String = ""


static func generate(slot_id: String, quality_tier: int = -1, base_level: int = 1) -> Equipment:
	return generate_with_options(slot_id, quality_tier, base_level, "")


static func generate_with_options(
	slot_id: String,
	quality_tier: int,
	base_level: int,
	set_id: String = ""
) -> Equipment:
	var equip = Equipment.new()
	equip.slot = slot_id
	equip.set_id = set_id
	
	if quality_tier < 0:
		quality_tier = _roll_quality(base_level)
	equip.quality = quality_tier
	var qdata = DataLoader.equipment_quality(quality_tier)
	equip.quality_name = qdata.get("name", "普通")
	
	# 基础属性
	var base_stats = DataLoader.equipment_base_stats(slot_id)
	if not base_stats.is_empty():
		for key in base_stats:
			var arr = base_stats[key]
			if arr is Array and arr.size() > quality_tier:
				equip.stats[key] = int(arr[quality_tier] * _variance_factor())
	
	# 前缀
	if randf() < 0.3 + quality_tier * 0.1:
		var prefixes = DataLoader.all_prefixes()
		if prefixes.size() > 0:
			var pf = prefixes[randi() % prefixes.size()]
			equip.prefix_name = pf.name
			for key in pf.effect:
				var arr = pf.effect[key]
				if arr is Array and arr.size() > quality_tier:
					equip.stats[key] = equip.stats.get(key, 0) + int(arr[quality_tier] * _variance_factor())
	
	# 名称
	var slot_name = DataLoader.equipment_slot(slot_id).get("name", slot_id)
	equip.item_name = equip.prefix_name + equip.quality_name + "·" + slot_name
	if set_id != "":
		var set_name: String = EquipmentSetRegistry.get_set_name(set_id)
		if set_name != "":
			equip.item_name += "·" + set_name
	equip.item_id = "eq_%s_%d_%d" % [slot_id, quality_tier, randi()]
	
	return equip


static func _roll_quality(base_level: int) -> int:
	var roll = randf()
	var bonus = min(base_level * 0.02, 0.3)
	
	if roll < 0.02 + bonus: return 5   # 传说
	if roll < 0.06 + bonus: return 4   # 史诗
	if roll < 0.15 + bonus: return 3   # 稀有
	if roll < 0.35 + bonus: return 2   # 精良
	if roll < 0.60 + bonus: return 1   # 普通
	return 0  # 破损


static func _variance_factor() -> float:
	return randf_range(0.85, 1.15)


func get_color() -> String:
	return DataLoader.equipment_quality(quality).get("color", "#FFFFFF")


func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"item_name": item_name,
		"slot": slot,
		"quality": quality,
		"quality_name": quality_name,
		"prefix_name": prefix_name,
		"set_id": set_id,
		"stats": stats.duplicate()
	}


static func from_dict(data: Dictionary) -> Equipment:
	var eq = Equipment.new()
	eq.item_id = data.get("item_id", "")
	eq.item_name = data.get("item_name", "")
	eq.slot = data.get("slot", "")
	eq.quality = data.get("quality", 1)
	eq.quality_name = data.get("quality_name", "")
	eq.prefix_name = data.get("prefix_name", "")
	eq.set_id = data.get("set_id", "")
	eq.stats = data.get("stats", {}).duplicate()
	return eq