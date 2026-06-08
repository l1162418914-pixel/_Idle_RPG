class_name ExpeditionStrategyService
extends RefCounted
## 出征策略语义：推图 / 均衡 / 搜刮（非单纯速度倍率）


const HIGH_VALUE_ITEM_RATIO := 0.32
const HIGH_VALUE_QUALITY_MIN := 3
const LOOT_SAFE_FILL := 0.92
const LOOT_EXPOSED_FILL := 0.88
const MARCH_SAFE_FILL := 0.92
const MARCH_EXPOSED_FILL := 0.95


static func is_push(run: WorldRun) -> bool:
	return run != null and run.expedition_priority == GameManager.EXPEDITION_PRIORITY_PUSH


static func is_loot(run: WorldRun) -> bool:
	return run != null and run.expedition_priority == GameManager.EXPEDITION_PRIORITY_LOOT


static func is_march(run: WorldRun) -> bool:
	return run == null or run.expedition_priority == GameManager.EXPEDITION_PRIORITY_MARCH


static func allows_periodic_auto_retreat(run: WorldRun) -> bool:
	if run == null or is_push(run):
		return false
	if is_loot(run):
		return true
	return bool(run.auto_retreat_value_enabled)


static func should_use_fill_rules(run: WorldRun) -> bool:
	return run != null and is_march(run)


static func get_value_threshold(run: WorldRun) -> int:
	return AutoRetreatService.get_value_threshold(run)


static func is_high_value_equipment(run: WorldRun, equip: Equipment) -> bool:
	if equip == null:
		return false
	var threshold: int = maxi(1, get_value_threshold(run))
	if EquipmentCompare.power_score(equip) >= int(float(threshold) * HIGH_VALUE_ITEM_RATIO):
		return true
	var min_q: int = _map_min_quality(run)
	return equip.quality >= maxi(min_q, HIGH_VALUE_QUALITY_MIN)


static func is_high_value_material(run: WorldRun, mat: RunMaterial) -> bool:
	if mat == null:
		return false
	var threshold: int = maxi(1, get_value_threshold(run))
	return mat.material_value >= int(float(threshold) * HIGH_VALUE_ITEM_RATIO * 0.45)


static func bags_full_for_loot(run: WorldRun) -> bool:
	if run == null:
		return false
	var safe_ratio: float = run.safe_loot.get_fill_ratio() if run.safe_loot else 0.0
	var exposed_ratio: float = run.exposed_loot.get_fill_ratio() if run.exposed_loot else 0.0
	return safe_ratio >= LOOT_SAFE_FILL and exposed_ratio >= LOOT_EXPOSED_FILL


static func on_equipment_acquired(run: WorldRun, equip: Equipment, placed: Dictionary) -> bool:
	if run == null or equip == null or not is_loot(run):
		return false
	if is_high_value_equipment(run, equip):
		return trigger_retreat(run, "loot_high_value", equip.item_name)
	if bags_full_for_loot(run):
		return trigger_retreat(run, "loot_bags_full", "")
	if not placed.get("ok", false) and where_not_discarded(placed):
		return trigger_retreat(run, "loot_bags_full", equip.item_name)
	return false


static func on_material_acquired(run: WorldRun, mat: RunMaterial, placed: Dictionary) -> bool:
	if run == null or mat == null or not is_loot(run):
		return false
	if is_high_value_material(run, mat):
		return trigger_retreat(run, "loot_high_value", mat.item_name)
	if bags_full_for_loot(run):
		return trigger_retreat(run, "loot_bags_full", "")
	if not placed.get("ok", false):
		return trigger_retreat(run, "loot_bags_full", mat.item_name)
	return false


static func check_periodic(run: WorldRun) -> bool:
	if run == null or not allows_periodic_auto_retreat(run):
		return false
	if is_loot(run):
		if bags_full_for_loot(run):
			return trigger_retreat(run, "loot_bags_full", "")
		return false
	return false


static func trigger_retreat(run: WorldRun, reason: String, item_hint: String = "") -> bool:
	if run == null or not run.is_active or run.is_retreating:
		return false
	run.begin_retreat(reason)
	run.emit_signal(
		"run_event",
		"auto_retreat",
		{
			"reason": reason,
			"strategy": run.expedition_priority,
			"item_hint": item_hint,
			"carry_value": CarryValueService.compute(run, false),
			"threshold": get_value_threshold(run),
		}
	)
	return true


static func where_not_discarded(placed: Dictionary) -> bool:
	return str(placed.get("where", "")) != "discarded"


static func _map_min_quality(run: WorldRun) -> int:
	if run == null or run.map_data.is_empty():
		return 1
	return maxi(1, int(run.map_data.get("loot_min_quality", 1)))
