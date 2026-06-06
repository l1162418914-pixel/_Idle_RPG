extends Node
## DataLoader — 加载、缓存并提供 JSON 数据访问

const _EquipmentSetRegistry = preload("res://scripts/equipment/equipment_set_registry.gd")

var _enemy_templates: Dictionary = {}
var _merc_templates: Dictionary = {}
var _player_classes: Dictionary = {}
var _map_templates: Dictionary = {}
var _base_data: Dictionary = {}
var _equipment_data: Dictionary = {}
var _skill_templates: Dictionary = {}
var _equipment_sets: Dictionary = {}
var _loot_materials: Dictionary = {}
var _auto_retreat_rules: Dictionary = {}
var _extract_items: Dictionary = {}
var _near_death_config: Dictionary = {}
var _chase_drop_tables: Dictionary = {}
var _test_map_rosters: Dictionary = {}
var _march_search_pools: Dictionary = {}
var _march_events: Dictionary = {}


func load_all() -> void:
	_enemy_templates = _load_json("res://data/enemy_templates.json")
	_merc_templates = _load_json("res://data/mercenary_templates.json")
	_map_templates = _load_json("res://data/map_templates.json")
	_base_data = _load_json("res://data/base_data.json")
	_equipment_data = _load_json("res://data/equipment_data.json")
	_skill_templates = _load_json("res://data/skill_templates.json")
	_equipment_sets = _load_json("res://data/equipment_sets.json")
	_loot_materials = _load_json("res://data/loot_materials.json")
	_auto_retreat_rules = _load_json("res://data/auto_retreat_rules.json")
	_extract_items = _load_json("res://data/extract_items.json")
	_near_death_config = _load_json("res://data/near_death_config.json")
	_chase_drop_tables = _load_json("res://data/chase_drop_tables.json")
	_test_map_rosters = _load_json("res://data/test_map_rosters.json")
	_march_search_pools = _load_json("res://data/march_search_pools.json")
	_march_events = _load_json("res://data/march_events.json")
	_EquipmentSetRegistry.load_from_data(_equipment_sets)
	_index_merc()
	_index_player_classes()
	_index_maps()
	_index_base()
	_index_skills()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: 文件不存在 %s" % path)
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataLoader: 无法打开 %s" % path)
		return {}
	var text = f.get_as_text()
	f.close()
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("DataLoader: JSON解析失败 %s" % path)
		return {}
	return json.data


func _index_merc() -> void:
	_indexed_merc = {}
	if _merc_templates.has("mercenaries"):
		for m in _merc_templates.mercenaries:
			_indexed_merc[m.template_id] = m


func _index_player_classes() -> void:
	_indexed_player_classes = {}
	if _merc_templates.has("player_classes"):
		for pc in _merc_templates.player_classes:
			_indexed_player_classes[pc.class_id] = pc


func _index_maps() -> void:
	_indexed_maps = {}
	if _map_templates.has("maps"):
		for mp in _map_templates.maps:
			_indexed_maps[mp.map_id] = mp


func _index_base() -> void:
	_indexed_buildings = {}
	if _base_data.has("buildings"):
		for b in _base_data.buildings:
			_indexed_buildings[b.building_id] = b


func _index_skills() -> void:
	_indexed_skills = {}
	if _skill_templates.has("passive_skills"):
		for s in _skill_templates.passive_skills:
			_indexed_skills[s.skill_id] = s
	if _skill_templates.has("active_skills"):
		for s in _skill_templates.active_skills:
			_indexed_skills[s.skill_id] = s


var _indexed_merc: Dictionary = {}
var _indexed_player_classes: Dictionary = {}
var _indexed_maps: Dictionary = {}
var _indexed_buildings: Dictionary = {}
var _indexed_skills: Dictionary = {}


# --- Public API ---

func enemy_template(template_id: String) -> Dictionary:
	if _enemy_templates.has("enemies"):
		for e in _enemy_templates.enemies:
			if e.template_id == template_id:
				return e
	if _enemy_templates.has("bosses"):
		for b in _enemy_templates.bosses:
			if b.template_id == template_id:
				return b
	return {}


func merc_template(template_id: String) -> Dictionary:
	return _indexed_merc.get(template_id, {})


func all_merc_templates() -> Array:
	return _indexed_merc.values()


func player_class(class_id: String) -> Dictionary:
	return _indexed_player_classes.get(class_id, {})


func map_data(map_id: String) -> Dictionary:
	return _indexed_maps.get(map_id, {})


func all_maps() -> Array:
	if _map_templates.has("maps"):
		return _map_templates.maps
	return []


func building_data(building_id: String) -> Dictionary:
	return _indexed_buildings.get(building_id, {})


func all_building_data() -> Array:
	if _base_data.has("buildings"):
		return _base_data.buildings
	return []


func equipment_quality(tier: int) -> Dictionary:
	var arr = _equipment_data.get("quality_tiers", [])
	if tier >= 0 and tier < arr.size():
		return arr[tier]
	return arr[0] if arr.size() > 0 else {}


func equipment_slot(slot_id: String) -> Dictionary:
	for s in _equipment_data.get("slot_types", []):
		if s.id == slot_id:
			return s
	return {}


func equipment_base_stats(slot_id: String) -> Dictionary:
	return _equipment_data.get("base_stats_by_slot", {}).get(slot_id, {})


func all_prefixes() -> Array:
	return _equipment_data.get("prefixes", [])


func all_loot_materials() -> Array:
	return _loot_materials.get("materials", [])


func loot_material_shield_config() -> Dictionary:
	return _loot_materials.get("shield", {})


func auto_retreat_defaults() -> Dictionary:
	return _auto_retreat_rules.get("defaults", {})


func auto_retreat_rules() -> Array:
	return _auto_retreat_rules.get("rules", [])


func all_extract_items() -> Array:
	return _extract_items.get("items", [])


func equipment_set_name(set_id: String) -> String:
	if set_id == "":
		return ""
	for entry in _equipment_sets.get("sets", []):
		if entry is Dictionary and str(entry.get("set_id", "")) == set_id:
			return str(entry.get("name", set_id))
	return set_id


func near_death_config() -> Dictionary:
	return _near_death_config


func chase_drop_table(table_id: String) -> Dictionary:
	if table_id == "":
		return {}
	return _chase_drop_tables.get("tables", {}).get(table_id, {})


func skill_template(skill_id: String) -> Dictionary:
	return _indexed_skills.get(skill_id, {})


func test_map_rosters_data() -> Dictionary:
	return _test_map_rosters


func march_search_pool(pool_id: String) -> Dictionary:
	if pool_id == "":
		return {}
	return _march_search_pools.get("pools", {}).get(pool_id, {})


func march_event(event_id: String) -> Dictionary:
	if event_id == "":
		return {}
	return _march_events.get("events", {}).get(event_id, {})
