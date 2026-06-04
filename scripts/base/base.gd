class_name BaseManager
extends RefCounted
## 基地管理 — 建筑升级、招募、解锁

const BARRACKS = "barracks"
const FORGE = "forge"
const INFIRMARY = "infirmary"
const RESEARCH_LAB = "research_lab"
const WAREHOUSE = "warehouse"

var buildings: Dictionary = {}
var _gm = null


func init(game_manager) -> void:
	_gm = game_manager
	_build_from_gm()


func _build_from_gm() -> void:
	buildings = _gm.buildings


func upgrade(building_id: String) -> bool:
	return _gm.upgrade_building(building_id)


func get_level(building_id: String) -> int:
	return _gm.get_building_level(building_id)


func can_afford(building_id: String) -> bool:
	var bdata = DataLoader.building_data(building_id)
	if bdata.is_empty():
		return false
	var lv = get_level(building_id)
	if lv >= bdata.max_level:
		return false
	var cost = bdata.upgrade_costs.gold[lv]  # lv 是当前等级，下一级费用索引为 lv
	return _gm.gold >= cost


func get_next_cost(building_id: String) -> int:
	var bdata = DataLoader.building_data(building_id)
	if bdata.is_empty():
		return 0
	var lv = get_level(building_id)
	if lv >= bdata.max_level:
		return -1
	return bdata.upgrade_costs.gold[lv]


func can_recruit_elite() -> bool:
	var current = _gm.elite_roster.size() if _gm.player else 0
	return current < _gm.get_max_elite_slots()


func can_recruit_normal() -> bool:
	var current = _gm.normal_roster.size()
	return current < _gm.get_max_normal_slots()


func recruit_elite(template_id: String) -> EliteMercenary:
	var tpl = DataLoader.merc_template(template_id)
	if tpl.is_empty():
		return null
	var merc = EliteMercenary.new()
	merc.merc_id = "elite_%d_%s" % [_gm.elite_roster.size() + 1, template_id]
	merc.init_from_template(tpl)
	_gm.elite_roster.append(merc)
	if _gm.player:
		_gm.player.add_to_roster(merc)
	return merc


func recruit_normal(template_id: String) -> NormalMercenary:
	var tpl = DataLoader.merc_template(template_id)
	if tpl.is_empty():
		return null
	var merc = NormalMercenary.new()
	merc.merc_id = "normal_%d_%s" % [_gm.normal_roster.size() + 1, template_id]
	merc.init_from_template(tpl)
	_gm.normal_roster.append(merc)
	if _gm.player:
		_gm.player.add_to_roster(merc)
	return merc


func get_drop_rate_bonus() -> float:
	var lv = get_level(FORGE)
	var bdata = DataLoader.building_data(FORGE)
	if bdata.has("effects") and bdata.effects.has("drop_rate_bonus"):
		return bdata.effects.drop_rate_bonus[lv - 1] / 100.0
	return 0.0


func get_quality_bonus() -> int:
	var lv = get_level(FORGE)
	var bdata = DataLoader.building_data(FORGE)
	if bdata.has("effects") and bdata.effects.has("quality_bonus"):
		return bdata.effects.quality_bonus[lv - 1]
	return 0


func get_inventory_capacity() -> int:
	var lv = get_level(WAREHOUSE)
	var bdata = DataLoader.building_data(WAREHOUSE)
	if bdata.has("effects") and bdata.effects.has("inventory_slots"):
		return bdata.effects.inventory_slots[lv - 1]
	return 30