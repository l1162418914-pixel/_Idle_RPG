extends Node
## DataLoader — 加载、缓存并提供 JSON 数据访问

var _enemy_templates: Dictionary = {}
var _merc_templates: Dictionary = {}
var _player_classes: Dictionary = {}
var _map_templates: Dictionary = {}
var _base_data: Dictionary = {}
var _equipment_data: Dictionary = {}
var _skill_templates: Dictionary = {}
var _equipment_sets: Dictionary = {}


func load_all() -> void:
	_enemy_templates = _load_json("res://data/enemy_templates.json")
	_merc_templates = _load_json("res://data/mercenary_templates.json")
	_map_templates = _load_json("res://data/map_templates.json")
	_base_data = _load_json("res://data/base_data.json")
	_equipment_data = _load_json("res://data/equipment_data.json")
	_skill_templates = _load_json("res://data/skill_templates.json")
	_equipment_sets = _load_json("res://data/equipment_sets.json")
	EquipmentSetRegistry.load_from_data(_equipment_sets)
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


func skill_template(skill_id: String) -> Dictionary:
	return _indexed_skills.get(skill_id, {})
