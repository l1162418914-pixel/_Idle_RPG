extends Node
## GameManager — 全局状态机，管理 Base → Run → Result 循环

const _InventorySystemLib = preload("res://scripts/inventory/inventory_system.gd")

enum GameState { BASE, PREPARE, RUNNING, RESULT }

var state: int = GameState.BASE
var base_level: int = 1
var base_data: Dictionary = {}
var player: Player = null
var elite_roster: Array[EliteMercenary] = []
var normal_roster: Array[NormalMercenary] = []
var inventory = _InventorySystemLib.new()
var gold: int = 1000
var current_run: WorldRun = null
var unlocked_maps: Array[String] = ["grassland"]
## 已击败 Boss 的地图 id（用于解锁下一区域）
var defeated_map_bosses: Array[String] = []
## 本次 Boss 战新解锁的地图（结算 UI 展示后清空）
var last_unlocked_maps: Array[String] = []
var selected_map_id: String = "grassland"
var selected_squad: Array[Mercenary] = []
var buildings: Dictionary = {}
var rebirth_count: int = 0
var rebirth_bonus: float = 0.0
## 待发放奖励（end_run 写入，return_to_base 时 apply_run_rewards 消费）
var _pending_run_result: Dictionary = {}
var _run_rewards_applied: bool = false
## 上次结算升级记录，供 BaseUI 展示
var last_run_level_up_log: Array[String] = []
var last_run_map_unlock_log: Array[String] = []
## 用户偏好：点击地图后自动编队并连续出征
var auto_run_preferred: bool = false
## 当前是否处于自动连续出征循环中
var auto_run_enabled: bool = false
var auto_run_map_id: String = "grassland"
## 携带价值达标自动返程
var auto_retreat_value_enabled: bool = true
## 仅统计安全箱内价值（不含外露）
var auto_retreat_safe_only: bool = false
## 双半组编制 { active_half, A: {active, bench}, B: {...} }
var squad_formation: Dictionary = {}
var last_run_squad_snapshot: Array[String] = []
var last_deploy_half: String = "A"
var last_run_loot_log: Array[String] = []
var last_run_stability_note: String = ""
## 基地/下次出征共用的队伍稳定度（0-100）
var team_stability: int = 100

const REVIVE_COST_BASE: int = 80
const BASE_STABILITY_RECOVER_PER_SEC: float = 2.5
## 正常通关地图后额外扣除的稳定度（再加地图危险等级）
const MAP_CLEAR_STABILITY_BASE: int = 6
const REVIVE_COST_PER_LEVEL: int = 15

signal state_changed(new_state: int)
signal gold_changed(amount: int)
signal squad_ready()
signal run_started()
signal run_ended(result: Dictionary)
signal roster_healed()
signal team_stability_changed(new_value: int)
signal squad_stability_changed(new_value: int)
signal run_start_failed(code: int)
signal formation_changed

var _base_heal_timer: float = 0.0
var _stability_recover_accum: float = 0.0


func _ready() -> void:
	set_process(true)
	DataLoader.load_all()
	_init_buildings()
	
	# 有存档则读档，无存档留给 CharacterCreate 场景处理
	if SaveManager.has_save():
		SaveManager.load_game()
	else:
		state = GameState.BASE
		state_changed.emit(GameState.BASE)
		refresh_map_unlocks()
	SquadFormationService.ensure_formation(self)


func _init_buildings() -> void:
	buildings = {
		"barracks": {"level": 1, "building_id": "barracks"},
		"forge": {"level": 1, "building_id": "forge"},
		"infirmary": {"level": 1, "building_id": "infirmary"},
		"research_lab": {"level": 0, "building_id": "research_lab"},
		"warehouse": {"level": 1, "building_id": "warehouse"}
	}


func _create_player(pclass: String) -> void:
	var template = DataLoader.player_class(pclass)
	if template.is_empty():
		return
	player = Player.new()
	player.merc_id = "player_01"
	player.merc_name = "主角"
	player.init_from_template(template)


func start_prepare(map_id: String) -> void:
	if is_recovery_lock_active():
		run_start_failed.emit(-5)
		return
	if not is_map_unlocked(map_id):
		push_warning("地图未解锁: %s" % map_id)
		run_start_failed.emit(-4)
		return
	selected_map_id = map_id
	TestScenarioService.apply_on_prepare(self, map_id)
	if auto_run_preferred:
		var code: int = start_auto_expedition(map_id)
		if code != 0:
			run_start_failed.emit(code)
		return
	state = GameState.PREPARE
	state_changed.emit(GameState.PREPARE)


func get_run_start_error_message(code: int) -> String:
	match code:
		-1:
			return "无法出征：未选择队员或队伍为空"
		-2:
			return "无法出征：地图数据异常"
		-3:
			return "无法出征：主角无法出战（濒死/阵亡/休整中）"
		-4:
			return "无法出征：地图尚未解锁"
		-5:
			return "全队养伤锁：两半组均无法出征，请在大营恢复（≥70% 生命可清濒死）"
		_:
			return "无法出征（错误码 %d）" % code


func stop_auto_run() -> void:
	auto_run_enabled = false


func build_default_squad() -> void:
	SquadFormationService.apply_default_deploy(self)


## 开启自动出征：全选存活单位并立即出发（跳过编队界面）
func start_auto_expedition(map_id: String) -> int:
	if is_recovery_lock_active():
		return -5
	if not is_map_unlocked(map_id):
		return -1
	auto_run_enabled = true
	auto_run_map_id = map_id
	selected_map_id = map_id
	build_default_squad()
	if selected_squad.is_empty():
		auto_run_enabled = false
		return -2
	return start_run()


func is_recovery_lock_active() -> bool:
	SquadFormationService.ensure_formation(self)
	return SquadFormationService.is_recovery_lock_active(self)


func formation_assign(merc_id: String, half: String, slot_kind: String, slot_index: int) -> int:
	SquadFormationService.ensure_formation(self)
	var code: int = SquadFormationService.assign_merc_to_slot(self, merc_id, half, slot_kind, slot_index)
	if code == 0:
		formation_changed.emit()
	return code


func formation_swap_slots(
	half: String, kind_a: String, idx_a: int, kind_b: String, idx_b: int
) -> int:
	SquadFormationService.ensure_formation(self)
	var code: int = SquadFormationService.swap_formation_slots(self, half, kind_a, idx_a, kind_b, idx_b)
	if code == 0:
		formation_changed.emit()
	return code


func formation_clear_slot(half: String, slot_kind: String, slot_index: int) -> int:
	SquadFormationService.ensure_formation(self)
	var code: int = SquadFormationService.clear_slot(self, half, slot_kind, slot_index)
	if code == 0:
		formation_changed.emit()
	return code


func formation_set_preferred_half(half: String) -> void:
	SquadFormationService.set_preferred_half(self, half)
	formation_changed.emit()


func formation_error_message(code: int) -> String:
	match code:
		-2:
			return "该佣兵已在另一半组"
		-3:
			return "主角须在某半组出战位"
		-4:
			return "主角不能放替补席"
		_:
			return "编队调整失败(%d)" % code


func should_continue_auto_run(result: Dictionary = {}) -> bool:
	if not auto_run_enabled:
		return false
	if is_recovery_lock_active():
		return false
	if not result.is_empty():
		if not result.get("player_alive", false):
			return false
		if result.get("near_death_penalty", false):
			return false
		if result.get("manual_withdraw", false):
			return false
		return true
	if player == null or not player.is_alive or player.is_near_death:
		return false
	return true


## 结算后：换装 → 回城领奖励 → 再次出发
func continue_auto_loop_after_result(result: Dictionary) -> void:
	if not should_continue_auto_run(result):
		stop_auto_run()
		return
	equip_all_pending_upgrades_for_player()
	var map_id: String = auto_run_map_id
	return_to_base()
	if auto_run_enabled and player and player.is_alive and not player.is_near_death and is_map_unlocked(map_id):
		if is_recovery_lock_active():
			stop_auto_run()
			return
		SquadFormationService.rebuild_auto_squad(self)
		selected_map_id = map_id
		if selected_squad.is_empty():
			stop_auto_run()
			return
		start_run()
	else:
		stop_auto_run()


func is_map_unlocked(map_id: String) -> bool:
	return map_id in unlocked_maps


func get_unlock_level() -> int:
	var total := 0
	for bid in buildings:
		total += int(buildings[bid].get("level", 1))
	return maxi(1, total)


func get_map_lock_reason(map_id: String) -> String:
	var md: Dictionary = DataLoader.map_data(map_id)
	if is_map_unlocked(map_id):
		return ""
	return MapProgression.get_lock_reason(md, get_unlock_level(), defeated_map_bosses)


func get_all_maps_sorted() -> Array:
	var list: Array = DataLoader.all_maps()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("danger_level", 0)) < int(b.get("danger_level", 0))
	)
	return list


func get_available_maps() -> Array:
	refresh_map_unlocks()
	var list: Array = []
	for m in get_all_maps_sorted():
		var mid: String = str(m.get("map_id", ""))
		if mid != "" and is_map_unlocked(mid):
			list.append(m)
	return list


func refresh_map_unlocks() -> Array[String]:
	sync_always_unlocked_maps()
	last_unlocked_maps.clear()
	var base_lv: int = get_unlock_level()
	for m in DataLoader.all_maps():
		var mid: String = str(m.get("map_id", ""))
		if mid == "" or is_map_unlocked(mid):
			continue
		var md: Dictionary = DataLoader.map_data(mid)
		if md.is_empty():
			md = m
		if MapProgression.can_unlock(md, base_lv, defeated_map_bosses):
			unlocked_maps.append(mid)
			last_unlocked_maps.append(mid)
	return last_unlocked_maps.duplicate()


## 将所有 always_unlocked 地图并入 unlocked_maps（读档/热更新地图表后调用）
func sync_always_unlocked_maps() -> void:
	for m in DataLoader.all_maps():
		if not MapProgression.is_always_unlocked(m):
			continue
		var mid: String = str(m.get("map_id", ""))
		if mid != "" and mid not in unlocked_maps:
			unlocked_maps.append(mid)


func record_boss_defeat(map_id: String) -> void:
	if map_id == "":
		return
	if map_id not in defeated_map_bosses:
		defeated_map_bosses.append(map_id)


func _unlock_maps_by_progress() -> void:
	refresh_map_unlocks()


func start_run() -> int:
	if is_recovery_lock_active():
		return -5
	if player == null or not player.can_join_squad():
		return -3
	SquadFormationService.ensure_formation(self)
	var half: String = SquadFormationService.pick_deploy_half(self)
	if half == "":
		return -5
	squad_formation["active_half"] = half
	var md: Dictionary = DataLoader.map_data(selected_map_id)
	if not TestScenarioService.should_lock_roster(md):
		SquadFormationService.auto_fill_half(self, half)
	var deploy: Array[Mercenary] = SquadFormationService.resolve_active_squad(self, half)
	if deploy.is_empty():
		return -1
	selected_squad = deploy
	RetreatShieldService.tick_shield_cd_on_run_start()
	var squad = Squad.new()
	squad.build(deploy)
	current_run = WorldRun.new(selected_map_id, squad)
	var ok = current_run.start()
	if ok != 0:
		return -2
	state = GameState.RUNNING
	run_started.emit()
	state_changed.emit(GameState.RUNNING)
	return 0


func end_run(forced_withdraw: bool = false) -> void:
	if current_run:
		current_run.sync_stability_to_manager()
	var result = current_run.end_run(forced_withdraw)
	RetreatShieldService.apply_shield_cd_after_run(current_run, result)
	_apply_emergency_retreat_near_death_if_needed(result, forced_withdraw)
	last_run_map_unlock_log.clear()
	if result.get("boss_defeated", false) and current_run:
		record_boss_defeat(current_run.map_id)
		var unlocked: Array = refresh_map_unlocks()
		result["maps_unlocked"] = unlocked
		for mid in unlocked:
			var md: Dictionary = DataLoader.map_data(str(mid))
			last_run_map_unlock_log.append(md.get("name", str(mid)))
	else:
		result["maps_unlocked"] = []
	if not result.get("player_alive", true):
		stop_auto_run()
	last_run_stability_note = ""
	_apply_map_clear_stability_penalty(result)
	SquadFormationService.save_run_snapshot(self, result)
	SquadFormationService.rebalance_from_roster(self)
	_pending_run_result = result
	_run_rewards_applied = false
	state = GameState.RESULT
	state_changed.emit(GameState.RESULT)
	run_ended.emit(result)


## 将本次出征累计的金币、经验、掉落写入全局状态（仅在此处发放）
func apply_run_rewards(result: Dictionary) -> void:
	if _run_rewards_applied:
		return
	var gold_earned: int = result.get("total_gold", 0)
	if gold_earned > 0:
		add_gold(gold_earned)
	_apply_run_exp(result)
	last_run_loot_log.clear()
	for item in result.get("total_loot", []):
		if item is Equipment:
			inventory.add(item)
			last_run_loot_log.append("[%s] %s" % [item.quality_name, item.item_name])
	_run_rewards_applied = true


func get_forge_drop_rate_bonus() -> float:
	var lv: int = get_building_level("forge")
	var bdata: Dictionary = DataLoader.building_data("forge")
	if bdata.has("effects") and bdata.effects.has("drop_rate_bonus"):
		var arr: Array = bdata.effects.drop_rate_bonus
		if lv > 0 and lv <= arr.size():
			return float(arr[lv - 1]) / 100.0
	return 0.0


func get_all_equipped_items() -> Array[Equipment]:
	var list: Array[Equipment] = []
	if player:
		for slot in player.equipment_slots:
			var eq: Equipment = player.equipment_slots[slot]
			if eq != null:
				list.append(eq)
	for e in elite_roster:
		for slot in e.equipment_slots:
			var eq: Equipment = e.equipment_slots[slot]
			if eq != null:
				list.append(eq)
	for n in normal_roster:
		for slot in n.equipment_slots:
			var eq: Equipment = n.equipment_slots[slot]
			if eq != null:
				list.append(eq)
	return list


func organize_inventory() -> void:
	inventory.sort_items()


## 出售品质 ≤ max_quality 且未穿戴的装备，返回 {gold, count}
func sell_inventory_junk(max_quality: int = 1) -> Dictionary:
	var equipped: Array[Equipment] = get_all_equipped_items()
	var to_sell: Array[Equipment] = InventoryService.collect_sellable_junk(inventory, max_quality, equipped)
	var gold_gain := 0
	for item in to_sell:
		if item is Equipment:
			gold_gain += InventoryService.get_sell_price(item)
	var count: int = inventory.remove_items(to_sell)
	if gold_gain > 0:
		add_gold(gold_gain)
	if SaveManager and is_instance_valid(SaveManager):
		SaveManager.save_game()
	return {"gold": gold_gain, "count": count}


func get_forge_quality_bonus() -> int:
	var lv: int = get_building_level("forge")
	var bdata: Dictionary = DataLoader.building_data("forge")
	if bdata.has("effects") and bdata.effects.has("quality_bonus"):
		var arr: Array = bdata.effects.quality_bonus
		if lv > 0 and lv <= arr.size():
			return int(arr[lv - 1])
	return 0


func get_safe_box_grid_size() -> Vector2i:
	var lv: int = maxi(1, get_building_level("infirmary"))
	var bdata: Dictionary = DataLoader.building_data("infirmary")
	if bdata.is_empty() or not bdata.has("effects"):
		return Vector2i(2, 2)
	var ws: Array = bdata.effects.get("safe_box_w", [2])
	var hs: Array = bdata.effects.get("safe_box_h", [2])
	var wi: int = int(ws[mini(lv - 1, ws.size() - 1)])
	var hi: int = int(hs[mini(lv - 1, hs.size() - 1)])
	return Vector2i(maxi(1, wi), maxi(1, hi))


## 结算界面：将待领取掉落装备到佣兵（未返回基地前）
func equip_pending_loot(merc: Mercenary, item: Equipment) -> bool:
	if merc == null or item == null or _pending_run_result.is_empty():
		return false
	var loot: Array = _pending_run_result.get("total_loot", [])
	var idx: int = loot.find(item)
	if idx < 0:
		return false
	if not merc.equipment_slots.has(item.slot):
		return false
	loot.remove_at(idx)
	var old: Equipment = merc.equipment_slots.get(item.slot)
	if old != null:
		loot.append(old)
	merc.equip(item)
	return true


## 一键装备所有优于当前的主角的待领取掉落
func get_pending_loot() -> Array:
	if _pending_run_result.is_empty():
		return []
	return _pending_run_result.get("total_loot", [])


func equip_all_pending_upgrades_for_player() -> int:
	if player == null or _pending_run_result.is_empty():
		return 0
	var loot: Array = _pending_run_result.get("total_loot", []).duplicate()
	var equipped_count: int = 0
	loot.sort_custom(func(a: Equipment, b: Equipment) -> bool:
		return EquipmentCompare.power_score(a) > EquipmentCompare.power_score(b)
	)
	for item in loot:
		if not item is Equipment:
			continue
		var eq: Equipment = item as Equipment
		var old: Equipment = player.equipment_slots.get(eq.slot)
		if EquipmentCompare.is_upgrade(eq, old):
			if equip_pending_loot(player, eq):
				equipped_count += 1
	return equipped_count


func _apply_run_exp(result: Dictionary) -> void:
	last_run_level_up_log.clear()
	var total_exp: int = result.get("total_exp", 0)
	if total_exp <= 0:
		return
	var ids: Array = result.get("squad_member_ids", [])
	for merc_id in ids:
		var merc := find_mercenary_by_id(str(merc_id))
		if merc == null:
			continue
		var level_before: int = merc.level
		var levels_gained: int = merc.add_exp(total_exp)
		if levels_gained > 0:
			last_run_level_up_log.append(
				"%s Lv.%d → Lv.%d (+%d)" % [merc.merc_name, level_before, merc.level, levels_gained]
			)


func find_mercenary_by_id(merc_id: String) -> Mercenary:
	if player and player.merc_id == merc_id:
		return player
	for e in elite_roster:
		if e.merc_id == merc_id:
			return e
	for n in normal_roster:
		if n.merc_id == merc_id:
			return n
	return null


## 紧急撤离成功抵营：全队濒死（含战中阵亡者），不再记为永久死亡
func _apply_emergency_retreat_near_death_if_needed(result: Dictionary, forced_withdraw: bool) -> void:
	if result.get("manual_withdraw", false):
		return
	if not forced_withdraw:
		return
	if not result.get("emergency_retreat", false):
		return
	if not result.get("completed_retreat", false):
		return
	var ratio: float = 0.08
	var map_id: String = str(result.get("map_id", ""))
	var md: Dictionary = DataLoader.map_data(map_id)
	if md.has("emergency_near_death_hp_ratio"):
		ratio = float(md.emergency_near_death_hp_ratio)
	for mid in result.get("squad_member_ids", []):
		var merc := find_mercenary_by_id(str(mid))
		if merc:
			merc.apply_near_death_state(ratio)
	result["near_death_penalty"] = true
	result["player_alive"] = player != null and player.is_alive


## 复活阵亡佣兵。0=成功 -1=未死亡 -2=金币不足
func revive_mercenary(merc_type: String, merc_id: String) -> int:
	var merc := find_mercenary_by_id(merc_id)
	if merc == null or merc.is_alive:
		return -1
	var cost := get_revive_cost(merc)
	if not spend_gold(cost):
		return -2
	merc.revive(false)
	return 0


func get_revive_cost(merc: Mercenary) -> int:
	if merc == null:
		return REVIVE_COST_BASE
	return REVIVE_COST_BASE + merc.level * REVIVE_COST_PER_LEVEL


func is_save_allowed() -> bool:
	return state == GameState.BASE or state == GameState.PREPARE


## 放弃本次出征回基地（不发放未结算奖励），用于 RUNNING 时关窗等
func abort_run_to_base() -> void:
	if current_run:
		current_run.sync_stability_to_manager()
	_pending_run_result = {}
	_run_rewards_applied = false
	current_run = null
	selected_squad.clear()
	_sanitize_roster_for_base()
	state = GameState.BASE
	state_changed.emit(GameState.BASE)


## 结算或基地：不离开当前地图，领完奖后立刻再出征（非自动循环）
func redeploy_same_map() -> int:
	if is_recovery_lock_active():
		return -5
	if selected_map_id == "" or not is_map_unlocked(selected_map_id):
		return -4
	if player == null or not player.can_join_squad():
		return -3
	if state == GameState.RESULT:
		if not _pending_run_result.is_empty():
			apply_run_rewards(_pending_run_result)
		_pending_run_result = {}
		current_run = null
	elif state != GameState.BASE:
		return -1
	TestScenarioService.apply_on_prepare(self, selected_map_id)
	SquadFormationService.rebuild_auto_squad(self)
	var code: int = start_run()
	if code != 0:
		run_start_failed.emit(code)
	return code


func return_to_base() -> void:
	if not _pending_run_result.is_empty():
		apply_run_rewards(_pending_run_result)
	_pending_run_result = {}
	state = GameState.BASE
	if current_run:
		current_run = null
	selected_squad.clear()
	_sanitize_roster_for_base()
	state_changed.emit(GameState.BASE)
	if SaveManager and is_instance_valid(SaveManager):
		SaveManager.save_game()


## 关窗 / 退出：按状态决定存档策略（B4 方案 A）
func persist_on_shutdown() -> void:
	match state:
		GameState.BASE, GameState.PREPARE:
			if SaveManager and is_instance_valid(SaveManager):
				SaveManager.save_game()
		GameState.RUNNING:
			abort_run_to_base()
			if SaveManager and is_instance_valid(SaveManager):
				SaveManager.save_game()
		GameState.RESULT:
			return_to_base()
		_:
			if SaveManager and is_instance_valid(SaveManager):
				SaveManager.save_game()


func get_team_stability() -> int:
	return clampi(team_stability, 0, StabilitySystem.MAX_STABILITY)


func set_team_stability(value: int) -> void:
	var prev: int = team_stability
	team_stability = clampi(value, 0, StabilitySystem.MAX_STABILITY)
	if team_stability != prev:
		team_stability_changed.emit(team_stability)
		squad_stability_changed.emit(team_stability)


func get_squad_stability() -> int:
	return get_team_stability()


func set_squad_stability(value: int) -> void:
	set_team_stability(value)


func is_normal_map_completion(result: Dictionary) -> bool:
	if result.get("forced_withdraw", false):
		return false
	if not result.get("player_alive", false):
		return false
	return result.get("boss_defeated", false)


func _apply_map_clear_stability_penalty(result: Dictionary) -> void:
	if not is_normal_map_completion(result):
		return
	var map_id: String = str(result.get("map_id", ""))
	var md: Dictionary = DataLoader.map_data(map_id)
	var danger: int = int(md.get("danger_level", 1)) if not md.is_empty() else 1
	var cost: int = MAP_CLEAR_STABILITY_BASE + danger * 2
	var before: int = team_stability
	set_team_stability(team_stability - cost)
	var map_name: String = str(md.get("name", map_id))
	last_run_stability_note = "通关「%s」团队稳定度 -%d（%d → %d）" % [map_name, cost, before, team_stability]


func _process(delta: float) -> void:
	if state != GameState.BASE and state != GameState.PREPARE:
		return
	_tick_base_healing(delta)
	_tick_base_stability_recovery(delta)


func _tick_base_stability_recovery(delta: float) -> void:
	if team_stability >= StabilitySystem.MAX_STABILITY:
		_stability_recover_accum = 0.0
		return
	var rate: float = BASE_STABILITY_RECOVER_PER_SEC * get_infirmary_heal_speed_multiplier()
	_stability_recover_accum += delta * rate
	if _stability_recover_accum < 1.0:
		return
	var gain: int = int(_stability_recover_accum)
	_stability_recover_accum -= float(gain)
	set_team_stability(team_stability + gain)


func _tick_base_healing(delta: float) -> void:
	_base_heal_timer += delta
	if _base_heal_timer < RosterHealth.BASE_HEAL_TICK_SEC:
		return
	_base_heal_timer = 0.0
	var mult: float = get_infirmary_heal_speed_multiplier()
	if is_recovery_lock_active():
		mult *= 1.5
	var ratio: float = RosterHealth.get_heal_ratio_per_tick(mult)
	var healed_any := false
	for m in SquadFormationService.heal_priority_mercs(self):
		if RosterHealth.heal_mercenary(m, ratio) > 0:
			healed_any = true
		if RosterHealth.recover_personal_stability(m, ratio) > 0:
			healed_any = true
	if healed_any:
		roster_healed.emit()


func _all_roster_mercs() -> Array[Mercenary]:
	var list: Array[Mercenary] = []
	if player:
		list.append(player)
	list.append_array(elite_roster)
	list.append_array(normal_roster)
	return list


func get_scar_treatment_cost(merc: Mercenary) -> int:
	if merc == null or merc.scar_stacks <= 0:
		return 0
	var cfg: Dictionary = DataLoader.near_death_config().get("scar_treatment", {})
	var flat: int = int(cfg.get("base_gold_flat", 25))
	var per: int = int(cfg.get("base_gold_per_stack", 18))
	var lv: int = maxi(1, get_building_level("infirmary"))
	return flat + per * merc.scar_stacks + (lv - 1) * 5


## 0=成功 -1=未找到 -2=无伤痕 -3=金币不足
func treat_mercenary_scars(merc_id: String) -> int:
	var merc := find_mercenary_by_id(merc_id)
	if merc == null:
		return -1
	if merc.scar_stacks <= 0:
		return -2
	var cost: int = get_scar_treatment_cost(merc)
	if not spend_gold(cost):
		return -3
	merc.scar_stacks = 0
	merc.refresh_base_stats()
	merc.clamp_hp_to_max()
	return 0


func get_infirmary_heal_speed_multiplier() -> float:
	var lv: int = get_building_level("infirmary")
	var bdata: Dictionary = DataLoader.building_data("infirmary")
	if bdata.is_empty() or not bdata.has("effects"):
		return 1.0
	var arr: Array = bdata.effects.get("heal_time_reduction", [])
	if lv <= 0 or lv > arr.size():
		return 1.0
	return 1.0 + float(int(arr[lv - 1])) / 100.0


func _sanitize_roster_for_base() -> void:
	## 回基地：仅清 Buff、钳制 HP，不自动回满
	for m in _all_roster_mercs():
		m.buff_system.clear()
		if m.is_alive:
			m.clamp_hp_to_max()
			m.try_clear_retreat_on_full_heal()
			m.try_clear_near_death_for_deploy()
		else:
			m.current_hp = 0


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func upgrade_building(building_id: String) -> bool:
	if not buildings.has(building_id):
		return false
	var bdata = DataLoader.building_data(building_id)
	if bdata.is_empty():
		return false
	var b = buildings[building_id]
	var next_level = b.level + 1
	if next_level > bdata.max_level:
		return false
	var cost = bdata.upgrade_costs.gold[next_level - 1]
	if not spend_gold(cost):
		return false
	b.level = next_level
	refresh_map_unlocks()
	return true


func get_building_level(building_id: String) -> int:
	if buildings.has(building_id):
		return buildings[building_id].level
	return 0


func get_max_elite_slots() -> int:
	var bdata = DataLoader.building_data("barracks")
	var lv = get_building_level("barracks")
	if bdata.has("effects"):
		return bdata.effects.elite_slots[lv - 1]
	return 1


func reset_game_state() -> void:
	print("[GameManager] reset_game_state: 清空所有运行时数据...")
	print("  player 清空前: %s" % (player.merc_name if player else "null"))
	
	player = null
	elite_roster.clear()
	normal_roster.clear()
	inventory.clear()
	gold = 1000
	current_run = null
	selected_squad.clear()
	buildings.clear()
	unlocked_maps = ["grassland"]
	sync_always_unlocked_maps()
	refresh_map_unlocks()
	defeated_map_bosses.clear()
	last_run_map_unlock_log.clear()
	selected_map_id = "grassland"
	rebirth_count = 0
	rebirth_bonus = 0.0
	state = GameState.BASE
	
	_init_buildings()
	squad_formation.clear()
	last_run_squad_snapshot.clear()
	last_deploy_half = "A"
	
	print("  player 清空后: %s" % ("null" if player == null else player.merc_name))
	print("[GameManager] reset_game_state: 完成, state=%s" % state)


# ─── 序列化（to_save_dict / from_save_dict）────────────
# 所有权归 GameManager，SaveManager 只负责文件 I/O

func to_save_dict() -> Dictionary:
	return {
		"gold": gold,
		"rebirth_count": rebirth_count,
		"rebirth_bonus": rebirth_bonus,
		"unlocked_maps": unlocked_maps.duplicate(),
		"defeated_map_bosses": defeated_map_bosses.duplicate(),
		"auto_run_preferred": auto_run_preferred,
		"team_stability": team_stability,
		"squad_stability": team_stability,
		"buildings": buildings.duplicate(),
		"player": _serialize_merc(player),
		"roster": {
			"elite": _serialize_merc_array(elite_roster),
			"normal": _serialize_merc_array(normal_roster)
		},
		"inventory": inventory.to_dict_array(),
		"squad_formation": squad_formation.duplicate(true),
		"last_deploy_half": last_deploy_half,
		"last_run_squad_snapshot": last_run_squad_snapshot.duplicate(),
		"selected_map_id": selected_map_id,
		"cloud_reserved": {}
	}


func from_save_dict(data: Dictionary) -> void:
	gold = data.get("gold", 1000)
	rebirth_count = data.get("rebirth_count", 0)
	rebirth_bonus = data.get("rebirth_bonus", 0.0)
	unlocked_maps.assign(data.get("unlocked_maps", ["grassland"]))
	defeated_map_bosses.assign(data.get("defeated_map_bosses", []))
	auto_run_preferred = data.get("auto_run_preferred", false)
	auto_run_enabled = false
	var loaded_team: int = data.get("team_stability", data.get("squad_stability", StabilitySystem.MAX_STABILITY))
	team_stability = clampi(loaded_team, 0, StabilitySystem.MAX_STABILITY)
	sync_always_unlocked_maps()
	refresh_map_unlocks()
	buildings = data.get("buildings", {})
	
	var pdata = data.get("player", {})
	if not pdata.is_empty():
		player = _deserialize_player(pdata)
	
	var roster = data.get("roster", {})
	elite_roster.clear()
	for edata in roster.get("elite", []):
		var m = _deserialize_elite(edata)
		if m:
			elite_roster.append(m)
	normal_roster.clear()
	for ndata in roster.get("normal", []):
		var m = _deserialize_normal(ndata)
		if m:
			normal_roster.append(m)
	
	inventory.from_dict_array(data.get("inventory", []))
	squad_formation = data.get("squad_formation", {})
	last_deploy_half = data.get("last_deploy_half", "A")
	last_run_squad_snapshot.clear()
	for mid in data.get("last_run_squad_snapshot", []):
		last_run_squad_snapshot.append(str(mid))
	selected_map_id = str(data.get("selected_map_id", selected_map_id))
	SquadFormationService.ensure_formation(self)
	SquadFormationService.rebalance_from_roster(self)
	
	current_run = null
	selected_squad.clear()
	_pending_run_result = {}
	_run_rewards_applied = false
	state = GameState.BASE
	_sanitize_roster_for_base()


# ─── 内部序列化辅助 ────────────────────────────────────

func _serialize_merc(merc: Mercenary) -> Dictionary:
	if merc == null:
		return {}
	merc.refresh_base_stats()
	return {
		"merc_id": merc.merc_id,
		"merc_name": merc.merc_name,
		"merc_type": merc.merc_type,
		"merc_class": merc.merc_class,
		"level": merc.level,
		"exp": merc.exp,
		"max_level": merc.max_level,
		"current_hp": merc.current_hp,
		"is_alive": merc.is_alive,
		"is_near_death": merc.is_near_death,
		"scar_stacks": merc.scar_stacks,
		"is_retreated": merc.is_retreated,
		"is_personal_break": merc.is_personal_break,
		"personal_stability": merc.personal_stability,
		"attack_range": merc.attack_range,
		"attack_speed": merc.attack_speed,
		"equipment_slots": _serialize_equipment_slots(merc.equipment_slots),
		"passive_skills": merc.passive_skills.duplicate(),
		"buffs": merc.buff_system.to_dict_array(),
		"active_skills": merc.active_skills.duplicate(),
		"growth_per_level": merc.growth_per_level.duplicate(),
		"template_id": merc.template_id,
		"player_extra": _serialize_player_extra(merc)
	}


func _serialize_player_extra(merc: Mercenary) -> Dictionary:
	if not (merc is Player):
		return {}
	var p = merc as Player
	return {
		"base_exp_multiplier": p.base_exp_multiplier,
		"squad_stability_influence": p.squad_stability_influence,
		"owned_elite_ids": _extract_ids(p.owned_elite_roster),
		"owned_normal_ids": _extract_ids(p.owned_normal_roster)
	}


func _extract_ids(list: Array) -> Array:
	var ids: Array = []
	for m in list:
		if m is Mercenary:
			ids.append(m.merc_id)
	return ids


func _serialize_equipment_slots(slots: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot in slots:
		var eq = slots[slot]
		if eq is Equipment:
			result[slot] = eq.to_dict()
		else:
			result[slot] = null
	return result


func _serialize_merc_array(list: Array) -> Array:
	var result: Array = []
	for m in list:
		if m is Mercenary:
			result.append(_serialize_merc(m))
	return result


func _deserialize_player(data: Dictionary) -> Player:
	var p = Player.new()
	_apply_merc_data(p, data)
	var extra = data.get("player_extra", {})
	if not extra.is_empty():
		p.base_exp_multiplier = extra.get("base_exp_multiplier", 0.25)
		p.squad_stability_influence = extra.get("squad_stability_influence", 0.0)
	return p


func _deserialize_elite(data: Dictionary) -> EliteMercenary:
	var m = EliteMercenary.new()
	_apply_merc_data(m, data)
	return m


func _deserialize_normal(data: Dictionary) -> NormalMercenary:
	var m = NormalMercenary.new()
	_apply_merc_data(m, data)
	return m


func _apply_merc_data(merc: Mercenary, data: Dictionary) -> void:
	merc.merc_id = data.get("merc_id", "")
	merc.merc_name = data.get("merc_name", "")
	merc.merc_type = data.get("merc_type", Mercenary.MercType.NORMAL)
	merc.merc_class = data.get("merc_class", "")
	merc.level = data.get("level", 1)
	merc.exp = data.get("exp", 0)
	merc.max_level = data.get("max_level", 60)
	merc.current_hp = data.get("current_hp", 100)
	merc.is_alive = data.get("is_alive", true)
	merc.is_near_death = data.get("is_near_death", false)
	merc.scar_stacks = maxi(0, int(data.get("scar_stacks", 0)))
	merc.is_retreated = data.get("is_retreated", false)
	merc.is_personal_break = data.get("is_personal_break", false)
	merc.personal_stability = clampi(
		data.get("personal_stability", StabilitySystem.MAX_STABILITY),
		0,
		StabilitySystem.MAX_STABILITY
	)
	merc.attack_range = data.get("attack_range", 50.0)
	merc.attack_speed = data.get("attack_speed", 1.0)
	merc.passive_skills = data.get("passive_skills", [])
	merc.active_skills = data.get("active_skills", [])
	merc.growth_per_level = data.get("growth_per_level", {})
	merc.template_id = data.get("template_id", "")
	
	var eq_data = data.get("equipment_slots", {})
	for slot in eq_data:
		if eq_data[slot] is Dictionary:
			merc.equipment_slots[slot] = Equipment.from_dict(eq_data[slot])
		else:
			merc.equipment_slots[slot] = null
	
	merc.buff_system.from_dict_array(data.get("buffs", []))
	_sanitize_active_skills(merc)
	_restore_active_skills_if_missing(merc)
	EquipmentSystem.apply_to(merc)
	merc.clamp_hp_to_max()
	merc.try_clear_retreat_on_full_heal()
	merc.try_clear_personal_break()
	# 忽略旧版存档中的 final 属性字段（hp/patk 等），由模板+装备重算


func _sanitize_active_skills(merc: Mercenary) -> void:
	var cleaned: Array = []
	for skill_id in merc.active_skills:
		var sid := str(skill_id)
		if SkillSystem.is_active_skill(sid) or SkillSystem.get_skill_info(sid).size() > 0:
			cleaned.append(sid)
	merc.active_skills = cleaned


func _restore_active_skills_if_missing(merc: Mercenary) -> void:
	if not merc.active_skills.is_empty():
		return
	var tpl: Dictionary = DataLoader.merc_template(merc.template_id)
	if tpl.has("active_skills"):
		merc.active_skills = tpl.get("active_skills", []).duplicate()
		return
	if merc is Player:
		tpl = DataLoader.player_class(merc.merc_class)
		if tpl.has("active_skills"):
			merc.active_skills = tpl.get("active_skills", []).duplicate()
			return
	# 精英/普通佣兵：按职业从 player_classes 继承主动技能
	if merc.merc_class != "":
		var class_tpl: Dictionary = DataLoader.player_class(merc.merc_class)
		if class_tpl.has("active_skills"):
			merc.active_skills = class_tpl.get("active_skills", []).duplicate()


func get_max_normal_slots() -> int:
	var bdata = DataLoader.building_data("barracks")
	var lv = get_building_level("barracks")
	if bdata.has("effects"):
		return bdata.effects.normal_slots[lv - 1]
	return 2


## 招募佣兵。type: "normal" 或 "elite"
## 返回值: 0=成功, -1=金币不足, -2=槽位已满, -3=模板池为空
func recruit_merc(merc_type: String) -> int:
	const NORMAL_COST := 100
	const ELITE_COST := 500
	
	var cost := ELITE_COST if merc_type == "elite" else NORMAL_COST
	if gold < cost:
		return -1
	
	# 收集该类型模板
	var pool: Array = []
	var all := DataLoader.all_merc_templates()
	for tpl in all:
		if tpl.get("type", "") == merc_type:
			pool.append(tpl)
	if pool.is_empty():
		return -3
	
	# 检查槽位
	if merc_type == "elite":
		if elite_roster.size() >= get_max_elite_slots():
			return -2
	else:
		if normal_roster.size() >= get_max_normal_slots():
			return -2
	
	# 扣钱
	spend_gold(cost)
	
	# 随机抽取模板并实例化
	var tpl: Dictionary = pool[randi() % pool.size()]
	var id_seed: int = int(Time.get_unix_time_from_system())
	
	if merc_type == "elite":
		var m := EliteMercenary.new()
		m.merc_id = "elite_%d_%d" % [id_seed, randi()]
		m.init_from_template(tpl)
		elite_roster.append(m)
	else:
		var m := NormalMercenary.new()
		m.merc_id = "normal_%d_%d" % [id_seed, randi()]
		m.init_from_template(tpl)
		normal_roster.append(m)
	
	SquadFormationService.rebalance_from_roster(self)
	formation_changed.emit()
	return 0


## 解雇佣兵。返回 true 表示成功移除
func dismiss_merc(merc_type: String, merc_id: String) -> bool:
	SquadFormationService.remove_merc_from_formation(self, merc_id)
	var removed := false
	if merc_type == "elite":
		for i in range(elite_roster.size()):
			if elite_roster[i].merc_id == merc_id:
				elite_roster.remove_at(i)
				removed = true
				break
	else:
		for i in range(normal_roster.size()):
			if normal_roster[i].merc_id == merc_id:
				normal_roster.remove_at(i)
				removed = true
				break
	if removed:
		formation_changed.emit()
	return removed


func can_go_next_frame() -> bool:
	return state == GameState.RUNNING
