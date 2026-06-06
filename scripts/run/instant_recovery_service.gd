class_name InstantRecoveryService
extends RefCounted
## §5.2 读条一键回收 — 大营即时结算，代价低于大价值；卷轴再减价


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("instant_recovery", {})


static func readbar_sec() -> float:
	return float(config().get("readbar_sec", 2.0))


static func gold_cost(gm: GameManager, merc: Mercenary, use_scroll: bool) -> int:
	if gm == null or merc == null:
		return 0
	var hv: int = gm.get_high_value_mia_revive_cost(merc)
	var ratio: float = float(config().get("hv_cost_ratio", 0.42))
	var cost: int = maxi(1, int(floor(float(hv) * ratio)))
	if use_scroll:
		cost = maxi(1, int(floor(float(cost) * float(ReturnScrollService.config().get("discount", 0.55)))))
	return cost
