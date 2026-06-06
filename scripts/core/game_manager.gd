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
## 槽位级账号 meta（经验冻结池等，见 SAVE_FORMAT §account_meta）
var account_meta: Dictionary = {}
## 救援队编组占位（与 squad_formation 并列，见 SAVE_FORMAT §rescue_squad）
var rescue_squad: Dictionary = {}
## 回收出征目标（留营 MIA 佣兵 id；出征后由 RecoveryRunService 写入 WorldRun）
var recovery_run_target_ids: Array[String] = []
var rescue_run_target_ids: Array[String] = []
## 出征出发时已在册的 MIA id（B-11 计趟：仅对这些批次累加 skipped_runs）
var mia_ids_at_run_departure: Array[String] = []
## 最近一次大价值复活结算摘要（供回收 UI toast）
var last_high_value_revive_summary: Dictionary = {}
var last_instant_recovery_summary: Dictionary = {}
## 本趟是否为 B-10 互捞自动回收出征
var mutual_recovery_this_run: bool = false
## 出征 UI 勾选：本趟跳过互捞改打正常远征（B-10a）
var skip_mutual_recovery_next_run: bool = false

const REVIVE_COST_BASE: int = 80
const HIGH_VALUE_MIA_REVIVE_MULT: int = 12
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
## 测试图出征前快照（回大营时还原，不入账）
var _test_run_baseline: Dictionary = {}


func _ready() -> void:
	set_process(true)
	DataLoader.load_all()
	_init_buildings()
	
	# 槽位选择在 CharacterCreate 完成；启动时不自动读档
	account_meta = SaveSerializer.default_account_meta()
	rescue_squad = SaveSerializer.default_rescue_squad()
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
		"warehouse": {"level": 1, "building_id": "warehouse"},
		"rescue_station": {"level": 0, "building_id": "rescue_station"},
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
	if not is_map_unlocked(map_id):
		push_warning("地图未解锁: %s" % map_id)
		run_start_failed.emit(-4)
		return
	selected_map_id = map_id
	var md: Dictionary = DataLoader.map_data(map_id)
	var inject_test_roster_first: bool = TestScenarioService.should_lock_roster(md)
	if inject_test_roster_first and not TestScenarioService.should_skip_test_roster_inject(self):
		_begin_test_run_session()
		TestScenarioService.apply_on_prepare(self, map_id)
	if is_recovery_lock_active():
		run_start_failed.emit(-5)
		return
	if not inject_test_roster_first:
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
			return "无法出征：半组无可用佣兵"
		-4:
			return "无法出征：地图尚未解锁"
		-5:
			return SquadFormationService.get_recovery_lock_message(self)
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


func apply_map_test_roster(roster: Dictionary) -> void:
	TestScenarioService.apply_test_roster(self, roster)


func formation_error_message(code: int) -> String:
	match code:
		-2:
			return "该佣兵已在另一半组"
		-3:
			return "主角不占半组槽位，请编入佣兵后出征"
		-4:
			return "主角不占半组槽位"
		-5:
			return "战场遗留，不可编入"
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
	return not is_recovery_lock_active()


## 结算后：换装 → 回城领奖励 → 再次出发
func continue_auto_loop_after_result(result: Dictionary) -> void:
	if not should_continue_auto_run(result):
		stop_auto_run()
		return
	equip_all_pending_upgrades_for_player()
	var map_id: String = auto_run_map_id
	return_to_base()
	if auto_run_enabled and is_map_unlocked(map_id):
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
	return MapUnlockService.is_map_unlocked(self, map_id)


func get_unlock_level() -> int:
	return MapUnlockService.get_unlock_level(self)


func get_map_lock_reason(map_id: String) -> String:
	return MapUnlockService.get_map_lock_reason(self, map_id)


func get_all_maps_sorted() -> Array:
	return MapUnlockService.get_all_maps_sorted()


func get_available_maps() -> Array:
	return MapUnlockService.get_available_maps(self)


func refresh_map_unlocks() -> Array[String]:
	return MapUnlockService.refresh_map_unlocks(self)


func sync_always_unlocked_maps() -> void:
	MapUnlockService.sync_always_unlocked_maps(self)


func record_boss_defeat(map_id: String) -> void:
	MapUnlockService.record_boss_defeat(self, map_id)


func _unlock_maps_by_progress() -> void:
	refresh_map_unlocks()


func start_recovery_run(merc_id: String) -> int:
	if merc_id == "":
		return -1
	if state == GameState.RUNNING:
		return -3
	SquadFormationService.ensure_formation(self)
	var half: String = SquadFormationService.pick_deploy_half(self)
	if half == "":
		return -5
	return _begin_recovery_run(merc_id, half, false)


func _begin_recovery_run(merc_id: String, deploy_half: String, mutual: bool) -> int:
	if merc_id == "":
		return -1
	if state == GameState.RUNNING:
		return -3
	var target := find_mercenary_by_id(merc_id)
	if target == null or not target.is_mia or target.merc_type == Mercenary.MercType.PLAYER:
		return -1
	if not MiaDeteriorationService.is_map_recovery_available(self, merc_id):
		return -6
	var map_id: String = _recovery_map_id_for_merc(merc_id)
	if map_id == "" or not is_map_unlocked(map_id):
		return -4
	stop_auto_run()
	SquadFormationService.ensure_formation(self)
	if deploy_half == "":
		return -5
	squad_formation["active_half"] = deploy_half
	SquadFormationService.auto_fill_half(self, deploy_half)
	var deploy: Array[Mercenary] = SquadFormationService.resolve_active_squad(self, deploy_half)
	if deploy.is_empty():
		return -5
	selected_map_id = map_id
	selected_squad = deploy
	recovery_run_target_ids = [merc_id]
	mutual_recovery_this_run = mutual
	RetreatShieldService.tick_shield_cd_on_run_start()
	var squad := Squad.new()
	squad.build(deploy)
	current_run = WorldRun.new(map_id, squad)
	RunModeService.apply_for_departure(self, current_run)
	var ok = current_run.start()
	_snapshot_mia_ids_at_departure()
	recovery_run_target_ids.clear()
	if ok != 0:
		current_run = null
		mutual_recovery_this_run = false
		return -2
	state = GameState.RUNNING
	run_started.emit()
	state_changed.emit(GameState.RUNNING)
	return 0


func start_rescue_run(merc_id: String) -> int:
	if merc_id == "":
		return -1
	if state == GameState.RUNNING:
		return -3
	if not MorgueService.is_rescue_unlocked(self):
		return -7
	var target := find_mercenary_by_id(merc_id)
	if target == null or not target.is_mia or target.merc_type == Mercenary.MercType.PLAYER:
		return -1
	if not MiaDeteriorationService.is_map_recovery_available(self, merc_id):
		return -6
	var map_id: String = _recovery_map_id_for_merc(merc_id)
	if map_id == "" or not is_map_unlocked(map_id):
		return -4
	stop_auto_run()
	RescueSquadService.rebuild_from_roster(self)
	var deploy: Array[Mercenary] = RescueSquadService.resolve_deploy_squad(self)
	if deploy.size() < RescueSquadService.min_active():
		return -5
	selected_map_id = map_id
	selected_squad = deploy
	rescue_run_target_ids = [merc_id]
	RetreatShieldService.tick_shield_cd_on_run_start()
	var squad := Squad.new()
	squad.build(deploy)
	current_run = WorldRun.new(map_id, squad)
	RunModeService.apply_for_departure(self, current_run)
	var ok = current_run.start()
	_snapshot_mia_ids_at_departure()
	rescue_run_target_ids.clear()
	if ok != 0:
		current_run = null
		return -2
	state = GameState.RUNNING
	run_started.emit()
	state_changed.emit(GameState.RUNNING)
	return 0


func get_morgue_entries() -> Array:
	return MorgueService.get_entries(self)


func try_morgue_medical_revive(merc_id: String) -> int:
	if state == GameState.RUNNING:
		return -3
	var target := find_mercenary_by_id(merc_id)
	if target == null or not target.is_morgue_pending:
		return -1
	var cost: int = MorgueService.medical_revive_cost(target)
	if not spend_gold(cost):
		return -2
	target.clear_morgue_pending()
	target.is_alive = true
	target.apply_near_death_state(0.35)
	MorgueService.remove_corpse(self, merc_id)
	SquadFormationService.ensure_formation(self)
	formation_changed.emit()
	return 0


func start_run(skip_mutual_recovery: bool = false) -> int:
	if is_recovery_lock_active():
		return -5
	SquadFormationService.ensure_formation(self)
	var half: String = SquadFormationService.pick_deploy_half(self)
	if half == "":
		return -5
	var skip_mutual: bool = skip_mutual_recovery or skip_mutual_recovery_next_run
	skip_mutual_recovery_next_run = false
	if (
		not skip_mutual
		and MutualRecoveryService.is_auto_enabled(self)
	):
		var auto_target: String = MutualRecoveryService.pick_target(self, half)
		if auto_target != "":
			return _begin_recovery_run(auto_target, half, true)
	mutual_recovery_this_run = false
	squad_formation["active_half"] = half
	var md: Dictionary = DataLoader.map_data(selected_map_id)
	TestScenarioService.ensure_roster_for_run(self, selected_map_id)
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
	RunModeService.apply_for_departure(self, current_run)
	var ok = current_run.start()
	if ok != 0:
		return -2
	_snapshot_mia_ids_at_departure()
	state = GameState.RUNNING
	run_started.emit()
	state_changed.emit(GameState.RUNNING)
	return 0


func _snapshot_mia_ids_at_departure() -> void:
	mia_ids_at_run_departure.clear()
	for merc in _all_roster_mercs():
		if merc != null and merc.is_mia and merc.merc_type != Mercenary.MercType.PLAYER:
			mia_ids_at_run_departure.append(merc.merc_id)


func end_run(forced_withdraw: bool = false) -> void:
	var run_md: Dictionary = DataLoader.map_data(current_run.map_id) if current_run else {}
	var is_test_run: bool = TestScenarioService.is_test_map(run_md)
	if current_run:
		current_run.sync_stability_to_manager()
	var result = current_run.end_run(forced_withdraw)
	if mutual_recovery_this_run:
		result["mutual_recovery"] = true
	mutual_recovery_this_run = false
	if is_test_run:
		result["test_run_ephemeral"] = true
	if not is_test_run:
		RetreatShieldService.apply_shield_cd_after_run(current_run, result)
	_apply_retreat_failure_mia_if_needed(result)
	PlayerForcedReturnService.finalize_account_player(self, result)
	_apply_emergency_retreat_near_death_if_needed(result, forced_withdraw)
	PressureOutcomeService.apply_camp_pressure_settlement(self, result)
	MiaDeteriorationService.on_run_finished(self, result, mia_ids_at_run_departure)
	mia_ids_at_run_departure.clear()
	last_run_map_unlock_log.clear()
	if not is_test_run and result.get("boss_defeated", false) and current_run:
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
	if not is_test_run:
		_apply_map_clear_stability_penalty(result)
	_annotate_frozen_exp_preview(result)
	_annotate_mia_wipe_frozen_preview(result)
	_annotate_recovery_preview(result)
	if TestScenarioService.is_mia_wipe_ephemeral_mia(result):
		TestScenarioService.finalize_mia_wipe_after_run(self, result)
	if not is_test_run:
		SquadFormationService.save_run_snapshot(self, result)
	SquadFormationService.ensure_formation(self)
	if not bool(result.get("mia_wipe_roster_locked", false)):
		SquadFormationService.rebalance_from_roster(self)
	formation_changed.emit()
	_pending_run_result = result
	_run_rewards_applied = false
	state = GameState.RESULT
	state_changed.emit(GameState.RESULT)
	run_ended.emit(result)


## 将本次出征累计的金币、经验、掉落写入全局状态（仅在此处发放）
func apply_run_rewards(result: Dictionary) -> void:
	if _run_rewards_applied:
		return
	if TestScenarioService.is_ephemeral_test_result(result):
		_run_rewards_applied = true
		return
	var gold_earned: int = result.get("total_gold", 0)
	if gold_earned > 0:
		add_gold(gold_earned)
	var tier: String = str(result.get("settlement_tier", "success"))
	if tier == "mia" and _should_persist_run_rewards(result):
		_record_frozen_exp_pool(result)
		MutualRecoveryService.on_mia_settlement(self, result)
	elif tier == "recovery":
		_apply_recovery_settlement(result)
	elif tier == "rescue":
		_apply_rescue_settlement(result)
	elif tier == "rescue_fail":
		MorgueService.apply_failure_injury_cd(self, result)
	elif tier == "recovery_fail":
		ReturnScrollService.grant_for_recovery_fail(self, result)
	elif tier != "mia" and tier != "recovery_fail":
		_apply_run_exp(result)
	last_run_loot_log.clear()
	for item in result.get("total_loot", []):
		if item is Equipment:
			if inventory.add(item):
				last_run_loot_log.append("[%s] %s" % [item.quality_name, item.item_name])
			else:
				last_run_loot_log.append("[仓库已满] %s（未入仓）" % item.item_name)
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


func get_inventory_capacity() -> int:
	var lv: int = get_building_level("warehouse")
	var bdata: Dictionary = DataLoader.building_data("warehouse")
	if bdata.has("effects") and bdata.effects.has("inventory_slots"):
		var arr: Array = bdata.effects.inventory_slots
		if lv > 0 and lv <= arr.size():
			return int(arr[lv - 1])
	return 30


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
	if TestScenarioService.is_ephemeral_test_result(_pending_run_result):
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
	if TestScenarioService.is_ephemeral_test_result(_pending_run_result):
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


func _count_mia_squad_members(result: Dictionary) -> int:
	var n := 0
	for mid in result.get("squad_member_ids", []):
		var merc := find_mercenary_by_id(str(mid))
		if merc != null and merc.is_mia:
			n += 1
	return n


func _should_persist_run_rewards(result: Dictionary) -> bool:
	return not TestScenarioService.is_ephemeral_test_result(result)


func ensure_test_run_session() -> void:
	_begin_test_run_session()


func _begin_test_run_session() -> void:
	if not _test_run_baseline.is_empty():
		return
	_test_run_baseline = _capture_test_run_baseline()


func _capture_test_run_baseline() -> Dictionary:
	return {
		"team_stability": team_stability,
		"elite": SaveSerializer.serialize_merc_array(elite_roster),
		"normal": SaveSerializer.serialize_merc_array(normal_roster),
		"squad_formation": squad_formation.duplicate(true),
		"last_run_squad_snapshot": last_run_squad_snapshot.duplicate(),
		"last_deploy_half": last_deploy_half,
	}


func _finish_test_run_session() -> void:
	if _test_run_baseline.is_empty():
		return
	set_team_stability(int(_test_run_baseline.get("team_stability", team_stability)))
	elite_roster.clear()
	for edata in _test_run_baseline.get("elite", []):
		if edata is Dictionary:
			var e: EliteMercenary = SaveSerializer.deserialize_elite(edata)
			if e != null:
				elite_roster.append(e)
	normal_roster.clear()
	for ndata in _test_run_baseline.get("normal", []):
		if ndata is Dictionary:
			var n: NormalMercenary = SaveSerializer.deserialize_normal(ndata)
			if n != null:
				normal_roster.append(n)
	squad_formation = _test_run_baseline.get("squad_formation", {}).duplicate(true)
	last_run_squad_snapshot.clear()
	for mid in _test_run_baseline.get("last_run_squad_snapshot", []):
		last_run_squad_snapshot.append(str(mid))
	last_deploy_half = str(_test_run_baseline.get("last_deploy_half", "A"))
	_test_run_baseline.clear()
	SquadFormationService.ensure_formation(self)
	formation_changed.emit()


func _compute_frozen_exp_entry(result: Dictionary, ts: int = -1) -> Dictionary:
	var total_exp: int = int(result.get("total_exp", 0))
	if total_exp <= 0:
		return {}
	var field_count: int = int(result.get("field_count", 0))
	if field_count <= 0:
		field_count = result.get("squad_member_ids", []).size()
	if field_count <= 0:
		return {}
	var mia_count: int = int(result.get("mia_count", -1))
	if mia_count < 0:
		mia_count = _count_mia_squad_members(result)
	if mia_count <= 0:
		return {}
	var mia_ratio: float = float(mia_count) / float(field_count)
	var frozen_total: int = int(floor(float(total_exp) * mia_ratio))
	if frozen_total <= 0:
		return {}
	var stamp: int = ts if ts >= 0 else Time.get_unix_time_from_system()
	var map_id: String = str(result.get("map_id", ""))
	var member_ids: Array = _mia_member_ids_from_result(result)
	return MiaDeteriorationService.enrich_new_pool({
		"run_id": "%s_%d" % [map_id, stamp],
		"map_id": map_id,
		"total": frozen_total,
		"mia_count": mia_count,
		"field_count": field_count,
		"mia_ratio": mia_ratio,
		"timestamp": stamp,
		"member_ids": member_ids,
	})


func _mia_member_ids_from_result(result: Dictionary) -> Array:
	var ids: Array = []
	for mid in result.get("squad_member_ids", []):
		var merc := find_mercenary_by_id(str(mid))
		if merc != null and merc.is_mia and merc.merc_type != Mercenary.MercType.PLAYER:
			ids.append(str(mid))
	return ids


func get_mia_roster_entries() -> Array:
	var out: Array = []
	for merc in _all_roster_mercs():
		if merc == null or not merc.is_mia or merc.is_morgue_pending:
			continue
		if merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		var tag := "[佣兵]"
		if merc is EliteMercenary:
			tag = "[精英]"
		elif merc.merc_type == Mercenary.MercType.PLAYER:
			tag = "[主角]"
		var skips: int = MiaDeteriorationService.get_skipped_runs_for_merc(self, merc.merc_id)
		var map_ok: bool = MiaDeteriorationService.is_map_recovery_available(self, merc.merc_id)
		out.append({
			"merc": merc,
			"merc_id": merc.merc_id,
			"tag": tag,
			"frozen_exp": get_frozen_exp_for_merc(merc.merc_id),
			"map_name": _frozen_exp_map_label_for_merc(merc.merc_id),
			"skipped_runs": skips,
			"map_point_visible": map_ok,
			"scroll_count": ReturnScrollService.count_for_merc(self, merc.merc_id),
		})
	return out


func try_instant_mia_recovery(merc_id: String, use_scroll: bool = true) -> int:
	if state == GameState.RUNNING:
		return -3
	var target := find_mercenary_by_id(merc_id)
	if target == null or not target.is_mia or target.merc_type == Mercenary.MercType.PLAYER:
		return -1
	var scroll_used: bool = use_scroll and ReturnScrollService.has_scroll_for_merc(self, merc_id)
	var cost: int = InstantRecoveryService.gold_cost(self, target, scroll_used)
	if not spend_gold(cost):
		return -2
	if scroll_used:
		ReturnScrollService.consume_for_merc(self, merc_id)
	var settlement_result: Dictionary = {
		"recovery_target_ids": [merc_id],
		"settlement_tier": "recovery",
	}
	_apply_recovery_settlement(settlement_result)
	last_instant_recovery_summary = {
		"merc_id": merc_id,
		"cost": cost,
		"scroll_used": scroll_used,
		"unfrozen": int(settlement_result.get("recovery_unfrozen_exp", 0)),
	}
	return 0


func get_total_frozen_exp() -> int:
	account_meta = SaveSerializer.normalize_account_meta(account_meta)
	var total := 0
	for raw in account_meta.get("frozen_exp_pools", []):
		if raw is Dictionary:
			total += int(raw.get("total", 0))
	return total


func get_frozen_exp_for_merc(merc_id: String) -> int:
	if merc_id == "":
		return 0
	account_meta = SaveSerializer.normalize_account_meta(account_meta)
	var sum := 0
	for raw in account_meta.get("frozen_exp_pools", []):
		if not raw is Dictionary:
			continue
		var p: Dictionary = raw
		var members: Array = p.get("member_ids", [])
		var pool_total: int = int(p.get("total", 0))
		var mc: int = maxi(1, int(p.get("mia_count", 1)))
		if members.size() > 0:
			if merc_id in members:
				sum += int(floor(float(pool_total) / float(members.size())))
		elif mc == 1:
			sum += pool_total
		elif _count_mia_mercs() > 0:
			sum += int(floor(float(pool_total) / float(mc)))
	return sum


func _frozen_exp_map_label_for_merc(merc_id: String) -> String:
	account_meta = SaveSerializer.normalize_account_meta(account_meta)
	for raw in account_meta.get("frozen_exp_pools", []):
		if not raw is Dictionary:
			continue
		var p: Dictionary = raw
		var members: Array = p.get("member_ids", [])
		if members.size() > 0 and merc_id in members:
			var md: Dictionary = DataLoader.map_data(str(p.get("map_id", "")))
			return str(md.get("name", p.get("map_id", "")))
	return ""


func _count_mia_mercs() -> int:
	var n := 0
	for m in _all_roster_mercs():
		if m != null and m.is_mia:
			n += 1
	return n


## 放弃搜寻：唯一永久死亡入口（除主角）
func abandon_mia_search(merc_id: String) -> int:
	var merc := find_mercenary_by_id(merc_id)
	if merc == null or not merc.is_mia:
		return -1
	if merc.merc_type == Mercenary.MercType.PLAYER:
		return -2
	_prune_frozen_exp_for_merc(merc_id)
	if merc.is_test_stand_in:
		_remove_abandoned_test_mia_merc(merc_id)
	else:
		merc.mark_permanent_death()
	SquadFormationService.ensure_formation(self)
	formation_changed.emit()
	if SaveManager and is_instance_valid(SaveManager):
		SaveManager.save_game()
	return 0


func _remove_abandoned_test_mia_merc(merc_id: String) -> void:
	SquadFormationService.remove_merc_from_formation(self, merc_id)
	var kept_elite: Array[EliteMercenary] = []
	for e in elite_roster:
		if e != null and str(e.merc_id) != merc_id:
			kept_elite.append(e)
	elite_roster.clear()
	for e in kept_elite:
		elite_roster.append(e)
	var kept_normal: Array[NormalMercenary] = []
	for n in normal_roster:
		if n != null and str(n.merc_id) != merc_id:
			kept_normal.append(n)
	normal_roster.clear()
	for n in kept_normal:
		normal_roster.append(n)


func get_high_value_mia_revive_cost(merc: Mercenary) -> int:
	if merc == null:
		return REVIVE_COST_BASE * HIGH_VALUE_MIA_REVIVE_MULT
	return get_revive_cost(merc) * HIGH_VALUE_MIA_REVIVE_MULT


## 大价值复活：大营即时结算，无需跑图。0=成功 -1=非遗留 -2=金币不足 -3=出征中
func try_high_value_mia_revive(merc_id: String) -> int:
	if merc_id == "":
		return -1
	if state == GameState.RUNNING:
		return -3
	var target := find_mercenary_by_id(merc_id)
	if target == null or not target.is_mia or target.merc_type == Mercenary.MercType.PLAYER:
		return -1
	var cost := get_high_value_mia_revive_cost(target)
	if not spend_gold(cost):
		return -2
	var result := {
		"recovery_target_ids": [merc_id],
		"settlement_tier": "recovery",
		"recovery_high_value": true,
	}
	_apply_recovery_settlement(result)
	last_high_value_revive_summary = {
		"merc_id": merc_id,
		"cost": cost,
		"unfrozen": int(result.get("recovery_unfrozen_exp", 0)),
	}
	return 0


func try_high_value_revive_placeholder(merc_id: String) -> int:
	return try_high_value_mia_revive(merc_id)


func _recovery_map_id_for_merc(merc_id: String) -> String:
	account_meta = SaveSerializer.normalize_account_meta(account_meta)
	for raw in account_meta.get("frozen_exp_pools", []):
		if not raw is Dictionary:
			continue
		var p: Dictionary = raw
		var members: Array = p.get("member_ids", [])
		if members.size() > 0 and merc_id in members:
			var mid: String = str(p.get("map_id", ""))
			if mid != "":
				return mid
	if not unlocked_maps.is_empty():
		return str(unlocked_maps[0])
	return selected_map_id if selected_map_id != "" else "grassland"


func _apply_rescue_settlement(result: Dictionary) -> void:
	var map_id: String = str(result.get("map_id", selected_map_id))
	for raw_id in result.get("rescue_target_ids", []):
		var merc_id: String = str(raw_id)
		MorgueService.admit_corpse(self, merc_id, map_id)
	MorgueService.grant_rescue_progress(self, result)
	SquadFormationService.ensure_formation(self)
	formation_changed.emit()
	if SaveManager and is_instance_valid(SaveManager):
		SaveManager.save_game()


func _apply_recovery_settlement(result: Dictionary) -> void:
	last_run_level_up_log.clear()
	var unfrozen_total := 0
	result["recovery_unfrozen_exp"] = 0
	for raw_id in result.get("recovery_target_ids", []):
		var merc_id: String = str(raw_id)
		var merc := find_mercenary_by_id(merc_id)
		if merc == null:
			continue
		var attributable: int = get_frozen_exp_for_merc(merc_id)
		var ratio: float = MiaDeteriorationService.recovery_unfreeze_ratio(self, merc_id)
		var grant: int = int(floor(float(attributable) * ratio))
		_prune_frozen_exp_for_merc(merc_id)
		merc.clear_mia_state()
		if grant > 0:
			unfrozen_total += grant
			var level_before: int = merc.level
			var levels_gained: int = merc.add_exp(grant)
			if levels_gained > 0:
				last_run_level_up_log.append(
					"%s Lv.%d → Lv.%d (+%d，回收解冻)" % [
						merc.merc_name, level_before, merc.level, levels_gained
					]
				)
		merc.apply_near_death_state(0.4)
	result["recovery_unfrozen_exp"] = unfrozen_total
	SquadFormationService.ensure_formation(self)
	formation_changed.emit()
	if SaveManager and is_instance_valid(SaveManager):
		SaveManager.save_game()


func _prune_frozen_exp_for_merc(merc_id: String) -> void:
	account_meta = SaveSerializer.normalize_account_meta(account_meta)
	var pools: Array = account_meta.get("frozen_exp_pools", [])
	var kept: Array = []
	var legacy_pruned := false
	for raw in pools:
		if not raw is Dictionary:
			continue
		var p: Dictionary = raw.duplicate(true)
		var members: Array = p.get("member_ids", [])
		if members.size() > 0:
			if merc_id not in members:
				kept.append(p)
				continue
			members.erase(merc_id)
			if members.is_empty():
				continue
			var old_mc: int = maxi(1, int(p.get("mia_count", members.size() + 1)))
			var old_total: int = int(p.get("total", 0))
			p["member_ids"] = members
			p["mia_count"] = members.size()
			p["total"] = int(floor(float(old_total) * float(members.size()) / float(old_mc)))
			if int(p["total"]) > 0:
				kept.append(p)
			continue
		if legacy_pruned:
			kept.append(p)
			continue
		var mc: int = maxi(1, int(p.get("mia_count", 1)))
		if mc <= 1:
			legacy_pruned = true
			continue
		var total: int = int(p.get("total", 0))
		p["mia_count"] = mc - 1
		p["total"] = int(floor(float(total) * float(mc - 1) / float(mc)))
		p["mia_ratio"] = float(p["mia_count"]) / float(maxi(1, int(p.get("field_count", mc))))
		legacy_pruned = true
		if int(p["total"]) > 0:
			kept.append(p)
	account_meta["frozen_exp_pools"] = kept


func _annotate_mia_wipe_frozen_preview(result: Dictionary) -> void:
	if str(result.get("settlement_tier", "")) != "mia":
		return
	var map_id: String = str(result.get("map_id", ""))
	var md: Dictionary = DataLoader.map_data(map_id)
	if str(md.get("test_scenario", "")) != "mia_wipe":
		return
	var preview := 0
	for entry in get_mia_roster_entries():
		if entry is Dictionary:
			preview += int(entry.get("frozen_exp", 0))
	if preview <= 0:
		preview = get_total_frozen_exp()
	if preview > 0:
		result["frozen_exp_recorded"] = preview
		result["frozen_exp_mia_ratio"] = 1.0
		result["mia_wipe_recovery_hint"] = true


func _annotate_recovery_preview(result: Dictionary) -> void:
	if str(result.get("settlement_tier", "")) != "recovery":
		return
	var preview := 0
	for raw_id in result.get("recovery_target_ids", []):
		var attributable: int = get_frozen_exp_for_merc(str(raw_id))
		preview += int(floor(float(attributable) * RecoveryRunService.UNFREEZE_RATIO))
	result["recovery_unfrozen_exp"] = preview


func _annotate_frozen_exp_preview(result: Dictionary) -> void:
	if str(result.get("settlement_tier", "")) != "mia":
		return
	var entry: Dictionary = _compute_frozen_exp_entry(result)
	if entry.is_empty():
		return
	result["frozen_exp_recorded"] = entry.total
	result["frozen_exp_mia_ratio"] = entry.mia_ratio


## MIA 结算：按 B-6 写入 account_meta.frozen_exp_pools，本趟经验不入账（解冻留 T-MIA-P2）
func _record_frozen_exp_pool(result: Dictionary) -> void:
	last_run_level_up_log.clear()
	var entry: Dictionary = _compute_frozen_exp_entry(result)
	if entry.is_empty():
		return
	account_meta = SaveSerializer.normalize_account_meta(account_meta)
	var pools: Array = account_meta.get("frozen_exp_pools", [])
	pools.append(entry)
	account_meta["frozen_exp_pools"] = pools


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


func _apply_retreat_failure_mia_if_needed(result: Dictionary) -> void:
	if not RetreatFailureMiaService.should_settle(self, result):
		return
	RetreatFailureMiaService.apply_settlement(self, result)


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
		if merc and not TestScenarioService.test_merc_blocks_casualties(merc):
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
	var restore_test: bool = not _test_run_baseline.is_empty()
	if current_run:
		current_run.sync_stability_to_manager()
		if TestScenarioService.is_test_map(DataLoader.map_data(current_run.map_id)):
			restore_test = true
	_pending_run_result = {}
	_run_rewards_applied = false
	current_run = null
	selected_squad.clear()
	if restore_test:
		_finish_test_run_session()
	else:
		_sanitize_roster_for_base()
	state = GameState.BASE
	state_changed.emit(GameState.BASE)


## 结算或基地：不离开当前地图，领完奖后立刻再出征（非自动循环）
func redeploy_same_map() -> int:
	if selected_map_id == "" or not is_map_unlocked(selected_map_id):
		return -4
	var md: Dictionary = DataLoader.map_data(selected_map_id)
	if TestScenarioService.should_lock_roster(md):
		TestScenarioService.apply_on_prepare(self, selected_map_id)
	if is_recovery_lock_active():
		return -5
	if state == GameState.RESULT:
		if not _pending_run_result.is_empty():
			if TestScenarioService.is_ephemeral_test_result(_pending_run_result):
				_run_rewards_applied = true
			else:
				apply_run_rewards(_pending_run_result)
		_pending_run_result = {}
		current_run = null
	elif state != GameState.BASE:
		return -1
	if not TestScenarioService.should_lock_roster(md):
		TestScenarioService.apply_on_prepare(self, selected_map_id)
	SquadFormationService.rebuild_auto_squad(self)
	var code: int = start_run()
	if code != 0:
		run_start_failed.emit(code)
	return code


func return_to_base() -> void:
	var had_ephemeral_test: bool = (
		not _pending_run_result.is_empty()
		and TestScenarioService.is_ephemeral_test_result(_pending_run_result)
	)
	var restore_test: bool = had_ephemeral_test or not _test_run_baseline.is_empty()
	var pending: Dictionary = _pending_run_result.duplicate(true)
	if not pending.is_empty():
		if not had_ephemeral_test:
			apply_run_rewards(pending)
		else:
			_run_rewards_applied = true
	_pending_run_result = {}
	if restore_test and not TestScenarioService.should_skip_test_session_restore(pending):
		_finish_test_run_session()
	if current_run:
		current_run = null
	selected_squad.clear()
	var keep_test_mia: bool = (
		TestScenarioService.should_skip_test_session_restore(pending)
		or TestScenarioService.has_test_mia_casualties(self)
	)
	if not restore_test and not keep_test_mia:
		_sanitize_roster_for_base()
	SquadFormationService.ensure_formation(self)
	formation_changed.emit()
	state = GameState.BASE
	_base_heal_timer = RosterHealth.BASE_HEAL_TICK_SEC
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
		formation_changed.emit()


func _all_roster_mercs() -> Array[Mercenary]:
	var list: Array[Mercenary] = []
	if player:
		list.append(player)
	list.append_array(elite_roster)
	list.append_array(normal_roster)
	return list


func get_scar_treatment_cost(merc: Mercenary) -> int:
	return InfirmaryService.get_scar_treatment_cost(self, merc)


func treat_mercenary_scars(merc_id: String) -> int:
	return InfirmaryService.treat_mercenary_scars(self, merc_id)


func get_infirmary_heal_speed_multiplier() -> float:
	return InfirmaryService.get_heal_speed_multiplier(self)


func repair_roster_base_stats() -> void:
	for m in _all_roster_mercs():
		if m != null and m.is_alive:
			m.refresh_base_stats()
			m.try_clear_near_death_for_deploy()


func _sanitize_roster_for_base() -> void:
	## 回基地：修复基础属性镜像、清 Buff；濒死/MIA 不回满
	for m in _all_roster_mercs():
		m.buff_system.clear()
		m.refresh_base_stats()
		if m.is_test_stand_in and m.is_mia:
			continue
		if m.is_mia:
			m.is_near_death = false
			m.current_hp = maxi(1, m.current_hp)
			continue
		if m.is_alive:
			if m.is_near_death:
				var cap: int = StatResolver.get_max_hp(m)
				m.current_hp = clampi(m.current_hp, 1, cap)
			else:
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
	MorgueService.sync_rescue_unlock_meta(self)
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


## 读档后按 account_meta.seed_casualty_fixtures 补齐阵亡/遗留 fixture（防测试图注入冲掉）
func ensure_save_casualty_fixtures() -> void:
	account_meta = SaveSerializer.normalize_account_meta(account_meta)
	if not bool(account_meta.get("seed_casualty_fixtures", false)):
		return
	_ensure_fixture_mia_elite()
	_ensure_fixture_mia_normal()
	_ensure_fixture_dead_elite()
	_ensure_fixture_dead_normal()
	_ensure_fixture_frozen_pool()
	SquadFormationService.ensure_formation(self)
	formation_changed.emit()


func _ensure_fixture_mia_elite() -> void:
	var merc := find_mercenary_by_id("fixture_mia_elite")
	if merc == null:
		merc = _spawn_fixture_elite("fixture_mia_elite", "mage_elite", 12, "fixture·奥术遗留")
	if merc != null:
		merc.enter_mia_state()


func _ensure_fixture_mia_normal() -> void:
	var merc := find_mercenary_by_id("fixture_mia_normal")
	if merc == null:
		merc = _spawn_fixture_normal("fixture_mia_normal", "warrior_normal", 10, "fixture·新兵遗留")
	if merc != null:
		merc.enter_mia_state()


func _ensure_fixture_dead_elite() -> void:
	var merc := find_mercenary_by_id("fixture_dead_elite")
	if merc == null:
		merc = _spawn_fixture_elite("fixture_dead_elite", "ranger_elite", 15, "fixture·游侠阵亡")
	if merc is EliteMercenary:
		var e := merc as EliteMercenary
		e.is_dead_permanently = true
		e.mark_permanent_death()


func _ensure_fixture_dead_normal() -> void:
	var merc := find_mercenary_by_id("fixture_dead_normal")
	if merc == null:
		merc = _spawn_fixture_normal("fixture_dead_normal", "mage_normal", 8, "fixture·学徒阵亡")
	if merc is NormalMercenary:
		(merc as NormalMercenary).mark_dead()


func _spawn_fixture_elite(merc_id: String, template_id: String, lvl: int, display_name: String) -> EliteMercenary:
	var tpl: Dictionary = DataLoader.merc_template(template_id)
	if tpl.is_empty():
		return null
	var m := EliteMercenary.new()
	m.merc_id = merc_id
	m.merc_name = display_name
	m.init_from_template(tpl)
	m.level = lvl
	m.personal_stability = 100
	m.refresh_base_stats()
	m.clamp_hp_to_max()
	elite_roster.append(m)
	if player:
		player.add_to_roster(m)
	return m


func _spawn_fixture_normal(merc_id: String, template_id: String, lvl: int, display_name: String) -> NormalMercenary:
	var tpl: Dictionary = DataLoader.merc_template(template_id)
	if tpl.is_empty():
		return null
	var m := NormalMercenary.new()
	m.merc_id = merc_id
	m.merc_name = display_name
	m.init_from_template(tpl)
	m.level = lvl
	m.personal_stability = 100
	m.refresh_base_stats()
	m.clamp_hp_to_max()
	normal_roster.append(m)
	if player:
		player.add_to_roster(m)
	return m


func _ensure_fixture_frozen_pool() -> void:
	var pools: Array = account_meta.get("frozen_exp_pools", [])
	for raw in pools:
		if raw is Dictionary and str(raw.get("run_id", "")) == "fixture_mia_pool_1":
			return
	pools.append({
		"run_id": "fixture_mia_pool_1",
		"map_id": "grassland",
		"total": 1200,
		"mia_count": 2,
		"field_count": 4,
		"mia_ratio": 0.5,
		"timestamp": int(Time.get_unix_time_from_system()),
		"member_ids": ["fixture_mia_elite", "fixture_mia_normal"],
	})
	account_meta["frozen_exp_pools"] = pools


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
	account_meta = SaveSerializer.default_account_meta()
	rescue_squad = SaveSerializer.default_rescue_squad()
	
	print("  player 清空后: %s" % ("null" if player == null else player.merc_name))
	print("[GameManager] reset_game_state: 完成, state=%s" % state)


# ─── 序列化（委托 SaveSerializer）──────────────────────

func to_save_dict() -> Dictionary:
	return SaveSerializer.to_save_dict(self)


func from_save_dict(data: Dictionary) -> void:
	SaveSerializer.from_save_dict(self, data)
	purge_probe_mercenaries()
	dedupe_roster()


func dedupe_roster() -> void:
	var seen: Dictionary = {}
	var kept_elite: Array = []
	for e in elite_roster:
		if e == null or str(e.merc_id) == "":
			continue
		var eid: String = str(e.merc_id)
		if seen.has(eid):
			continue
		seen[eid] = true
		kept_elite.append(e)
	elite_roster.clear()
	for e in kept_elite:
		elite_roster.append(e)
	var kept_normal: Array = []
	for n in normal_roster:
		if n == null or str(n.merc_id) == "":
			continue
		var nid: String = str(n.merc_id)
		if seen.has(nid):
			continue
		seen[nid] = true
		kept_normal.append(n)
	normal_roster.clear()
	for n in kept_normal:
		normal_roster.append(n)


## 读档时剔除 headless 探针遗留的 probe_* 佣兵（勿写入玩家存档）
func purge_probe_mercenaries() -> void:
	var kept_elite: Array = []
	for e in elite_roster:
		if e != null and not str(e.merc_id).begins_with("probe_"):
			kept_elite.append(e)
	elite_roster.clear()
	for e in kept_elite:
		elite_roster.append(e)
	var kept_normal: Array = []
	for n in normal_roster:
		if n != null and not str(n.merc_id).begins_with("probe_"):
			kept_normal.append(n)
	normal_roster.clear()
	for n in kept_normal:
		normal_roster.append(n)


func get_max_normal_slots() -> int:
	return MercRecruitService.get_max_normal_slots(self)


func grant_starter_merc() -> bool:
	return MercRecruitService.grant_starter_merc(self)


func recruit_merc(merc_type: String) -> int:
	return MercRecruitService.recruit_merc(self, merc_type)


func dismiss_merc(merc_type: String, merc_id: String) -> bool:
	return MercRecruitService.dismiss_merc(self, merc_type, merc_id)


func can_go_next_frame() -> bool:
	return state == GameState.RUNNING
