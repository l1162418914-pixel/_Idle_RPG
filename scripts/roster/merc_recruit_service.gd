class_name MercRecruitService
extends RefCounted
## 佣兵招募/解雇 — 从 GameManager 迁出


static func get_max_normal_slots(gm: GameManager) -> int:
	var bdata = DataLoader.building_data("barracks")
	var lv = gm.get_building_level("barracks")
	if bdata.has("effects"):
		return bdata.effects.normal_slots[lv - 1]
	return 2


static func grant_starter_merc(gm: GameManager) -> bool:
	if not gm.normal_roster.is_empty() or not gm.elite_roster.is_empty():
		return false
	var pool: Array = []
	for tpl in DataLoader.all_merc_templates():
		if tpl.get("type", "") == "normal":
			pool.append(tpl)
	if pool.is_empty():
		return false
	var tpl: Dictionary = pool[randi() % pool.size()]
	var m := NormalMercenary.new()
	m.merc_id = "normal_starter_%d" % int(Time.get_unix_time_from_system())
	m.init_from_template(tpl)
	gm.normal_roster.append(m)
	# FORM-3R：赠兵仅进备战席，不自动占 A/B 槽
	SquadFormationService.rebalance_from_roster(gm)
	gm.formation_changed.emit()
	return true


## 返回值: 0=成功, -1=金币不足, -2=槽位已满, -3=模板池为空
static func recruit_merc(gm: GameManager, merc_type: String) -> int:
	const NORMAL_COST := 100
	const ELITE_COST := 500

	var cost := ELITE_COST if merc_type == "elite" else NORMAL_COST
	if gm.gold < cost:
		return -1

	var pool: Array = []
	for tpl in DataLoader.all_merc_templates():
		if tpl.get("type", "") == merc_type:
			pool.append(tpl)
	if pool.is_empty():
		return -3

	if merc_type == "elite":
		if gm.elite_roster.size() >= gm.get_max_elite_slots():
			return -2
	else:
		if gm.normal_roster.size() >= get_max_normal_slots(gm):
			return -2

	gm.spend_gold(cost)

	var tpl: Dictionary = pool[randi() % pool.size()]
	var id_seed: int = int(Time.get_unix_time_from_system())

	if merc_type == "elite":
		var m := EliteMercenary.new()
		m.merc_id = "elite_%d_%d" % [id_seed, randi()]
		m.init_from_template(tpl)
		gm.elite_roster.append(m)
	else:
		var m := NormalMercenary.new()
		m.merc_id = "normal_%d_%d" % [id_seed, randi()]
		m.init_from_template(tpl)
		gm.normal_roster.append(m)

	# FORM-3R：新招募仅进备战席，进半组须玩家点选/拖入或「补满优先半组」
	SquadFormationService.rebalance_from_roster(gm)
	gm.formation_changed.emit()
	return 0


static func dismiss_merc(gm: GameManager, merc_type: String, merc_id: String) -> bool:
	SquadFormationService.remove_merc_from_formation(gm, merc_id)
	var removed := false
	if merc_type == "elite":
		for i in range(gm.elite_roster.size()):
			if gm.elite_roster[i].merc_id == merc_id:
				gm.elite_roster.remove_at(i)
				removed = true
				break
	else:
		for i in range(gm.normal_roster.size()):
			if gm.normal_roster[i].merc_id == merc_id:
				gm.normal_roster.remove_at(i)
				removed = true
				break
	if removed:
		gm.formation_changed.emit()
	return removed
