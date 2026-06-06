class_name InfirmaryService
extends RefCounted
## 医馆/伤痕 — 从 GameManager 迁出


static func get_scar_treatment_cost(gm: GameManager, merc: Mercenary) -> int:
	if merc == null or merc.scar_stacks <= 0:
		return 0
	var cfg: Dictionary = DataLoader.near_death_config().get("scar_treatment", {})
	var flat: int = int(cfg.get("base_gold_flat", 25))
	var per: int = int(cfg.get("base_gold_per_stack", 18))
	var lv: int = maxi(1, gm.get_building_level("infirmary"))
	return flat + per * merc.scar_stacks + (lv - 1) * 5


## 0=成功 -1=未找到 -2=无伤痕 -3=金币不足
static func treat_mercenary_scars(gm: GameManager, merc_id: String) -> int:
	var merc := gm.find_mercenary_by_id(merc_id)
	if merc == null:
		return -1
	if merc.scar_stacks <= 0:
		return -2
	var cost: int = get_scar_treatment_cost(gm, merc)
	if not gm.spend_gold(cost):
		return -3
	merc.scar_stacks = 0
	merc.refresh_base_stats()
	merc.clamp_hp_to_max()
	return 0


static func get_heal_speed_multiplier(gm: GameManager) -> float:
	var lv: int = gm.get_building_level("infirmary")
	var bdata: Dictionary = DataLoader.building_data("infirmary")
	if bdata.is_empty() or not bdata.has("effects"):
		return 1.0
	var arr: Array = bdata.effects.get("heal_time_reduction", [])
	if lv <= 0 or lv > arr.size():
		return 1.0
	return 1.0 + float(int(arr[lv - 1])) / 100.0
