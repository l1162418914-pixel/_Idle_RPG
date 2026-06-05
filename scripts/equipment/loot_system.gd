class_name LootSystem
extends RefCounted
## 地图 / 敌人 / 基地锻造 联动的掉落生成


static func roll_equipment(
	map_data: Dictionary,
	enemy_data: Dictionary,
	forge_drop_bonus: float = 0.0,
	forge_quality_bonus: int = 0
) -> Equipment:
	var slots: Array[String] = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]
	var slot: String = slots[randi() % slots.size()]
	var level: int = int(enemy_data.get("level", 1)) + int(map_data.get("loot_level_bonus", 0))
	if enemy_data.get("is_boss", false):
		level += 2
	
	var min_quality: int = int(map_data.get("loot_min_quality", 0))
	var quality_shift: int = int(map_data.get("loot_quality_shift", 0))
	if enemy_data.get("is_boss", false):
		min_quality = maxi(min_quality, 2)
		quality_shift += 1
	
	var tier: int
	if enemy_data.get("is_boss", false):
		tier = _roll_quality_tier(level, forge_quality_bonus + quality_shift)
	else:
		tier = _roll_mob_quality_tier(level, forge_quality_bonus + quality_shift)
		var mob_max_q: int = int(map_data.get("mob_max_quality", 1))
		tier = mini(tier, mob_max_q)
	tier = clampi(tier, min_quality, 6)
	
	var set_id: String = ""
	if tier >= 2 and randf() < float(map_data.get("set_drop_chance", 0.18)):
		set_id = _pick_set_for_map(map_data)
	
	return Equipment.generate_with_options(slot, tier, level, set_id)


static func roll_material(map_data: Dictionary, enemy_data: Dictionary) -> RunMaterial:
	return RunMaterial.roll_for_map(map_data, enemy_data)


static func get_material_drop_chance(map_data: Dictionary, enemy_data: Dictionary) -> float:
	var base: float = 0.22
	if enemy_data.get("is_boss", false):
		base = 0.38
	base *= float(map_data.get("resource_yield", 1.0))
	return minf(base, 0.55)


static func get_drop_chance(map_data: Dictionary, enemy_data: Dictionary, forge_drop_bonus: float) -> float:
	if enemy_data.get("is_boss", false):
		var boss_chance: float = float(map_data.get("drop_chance_boss", 1.0))
		boss_chance *= float(map_data.get("resource_yield", 1.0))
		return minf(boss_chance + forge_drop_bonus, 0.95)
	var chance: float = float(map_data.get("drop_chance", 0.15))
	chance *= float(map_data.get("mob_drop_mult", 1.5))
	chance *= float(map_data.get("resource_yield", 1.0))
	chance += forge_drop_bonus + float(map_data.get("mob_drop_bonus", 0.06))
	return minf(chance, 0.85)


static func _roll_mob_quality_tier(base_level: int, extra_shift: int) -> int:
	var roll: float = randf()
	var bonus: float = minf(base_level * 0.01, 0.12)
	var tier: int = 0
	if roll < 0.42 + bonus:
		tier = 0
	elif roll < 0.78 + bonus:
		tier = 1
	elif roll < 0.92:
		tier = 2
	elif roll < 0.98:
		tier = 3
	else:
		tier = 4
	return clampi(tier + extra_shift, 0, 6)


static func _roll_quality_tier(base_level: int, extra_shift: int) -> int:
	var roll: float = randf()
	var bonus: float = minf(base_level * 0.02, 0.35)
	var tier: int = 0
	if roll < 0.02 + bonus:
		tier = 5
	elif roll < 0.06 + bonus:
		tier = 4
	elif roll < 0.15 + bonus:
		tier = 3
	elif roll < 0.35 + bonus:
		tier = 2
	elif roll < 0.60 + bonus:
		tier = 1
	return clampi(tier + extra_shift, 0, 6)


static func _pick_set_for_map(map_data: Dictionary) -> String:
	var featured: String = str(map_data.get("featured_set_id", ""))
	if featured != "" and EquipmentSetRegistry.has_set(featured):
		return featured
	var pool: Array = EquipmentSetRegistry.all_set_ids()
	if pool.is_empty():
		return ""
	return str(pool[randi() % pool.size()])
