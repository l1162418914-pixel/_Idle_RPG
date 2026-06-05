class_name WorldRun
extends RefCounted
## WorldRun — 单次出征的顶层逻辑

const _EXTRACT_ITEM_SERVICE_PATH := "res://scripts/run/extract_item_service.gd"

signal enemy_spawned(enemy_data: Dictionary)
signal boss_encountered(boss_data: Dictionary)
signal loot_dropped(equipment: Equipment, gold: int)
signal run_completed(result: Dictionary)
signal run_event(event_name: String, data: Dictionary)

var map_id: String = ""
var map_data: Dictionary = {}
var squad: Squad = null
var stability: StabilitySystem = null
var combat: CombatController = null
var distance_traveled: float = 0.0
var max_distance: float = 600.0
var is_active: bool = false
var is_retreating: bool = false
## 下令撤离时的位置 C（返程起点）
var retreat_origin_distance: float = 0.0
## 当前返程段目标（撤离点或大营 0）
var retreat_destination: float = 0.0
var retreat_final_destination: float = 0.0
var retreat_reason: String = ""
## 世界行程速度（米/秒）— 偏低便于观察进军与撤离
const MOVE_SPEED_ADVANCE: float = 26.0
const MOVE_SPEED_RETREAT: float = 28.0
const NEAR_DEATH_RETREAT_SPEED_MULT: float = 0.5
const RETREAT_ARRIVE_EPSILON: float = 1.0
const CHASE_CATCH_GAP: float = 18.0
const CHASE_WARN_GAP: float = 120.0
const CHASE_DANGER_GAP: float = 60.0
var total_gold_earned: int = 0
var total_exp_earned: int = 0
## 兼容旧逻辑；结算以 safe_loot + exposed_loot 为准
var total_loot: Array[Equipment] = []
var safe_loot: GridInventory = null
var exposed_loot: GridInventory = null
var enemies_defeated: int = 0
var squad_member_ids: Array[String] = []
var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var boss_spawned: bool = false
var boss_defeated: bool = false
var boss_zone_reached: bool = false
var boss_chase_active: bool = false
var guard_chase_active: bool = false
var boss_chase_position: float = 0.0
var retreat_spawn_tier: String = ""
var chase_combat_in_progress: bool = false
var chase_pressure: float = 0.0
var chase_boss_repelled_count: int = 0
var chase_evade_eligible: bool = false
var chase_counter_uses: int = 0
var chase_stagger_charge: float = 0.0
var chase_stagger_holding: bool = false
var chase_stagger_repelled_count: int = 0
var chase_deep_counter_uses: int = 0
var _chase_combat_cooldown: float = 0.0
var _chase_counter_cooldown: float = 0.0
var _chase_deep_counter_cooldown: float = 0.0
var _chase_stability_tick: float = 0.0
var run_loot_lost_count: int = 0
var manual_loot_abandoned: int = 0
var retreat_shield_max: int = 0
var retreat_shield_current: int = 0
var equip_shield_max: int = 0
var equip_shield_current: int = 0
var material_shield_max: int = 0
var material_shield_current: int = 0
var _shield_cd_equipment_ids: Array[String] = []
var _shield_emergency_refresh_used: bool = false
var extract_guard_cleared: bool = false
var pending_extract_guard: RunExtractItem = null
var last_extract_item_name: String = ""
var bench_reserves: Array[Mercenary] = []
var deploy_half: String = "A"
var _enemy_pool: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 返程开始时立即注入 tick 的遇敌（避免等计时器）
var _retreat_opening_spawns: Array = []
var _pending_awakening_shield_bonus: int = 0


func _init(p_map_id: String, p_squad: Squad) -> void:
	map_id = p_map_id
	squad = p_squad
	map_data = DataLoader.map_data(map_id)
	if map_data.is_empty():
		push_error("WorldRun: 地图 %s 不存在" % map_id)
		return
	
	max_distance = map_data.get("boss_distance", 600.0)
	spawn_interval = float(map_data.get("spawn_interval", 3.0))
	_rng.randomize()


func start() -> int:
	if squad == null or squad.members.is_empty():
		return -1
	if map_data.is_empty():
		return -2
	
	stability = StabilitySystem.new()
	var start_team: int = StabilitySystem.MAX_STABILITY
	if GameManager:
		start_team = GameManager.get_team_stability()
	if map_data.has("run_start_team_stability"):
		start_team = int(map_data.run_start_team_stability)
	stability.init(squad.get_player(), squad, start_team, map_data)
	stability.team_stability_changed.connect(_on_team_stability_changed)
	stability.forced_withdraw.connect(_on_forced_withdraw)
	
	_build_enemy_pool()
	
	squad_member_ids.clear()
	for m in squad.members:
		squad_member_ids.append(m.merc_id)
	
	for m in squad.members:
		m.clamp_hp_to_max()
		m.run_kills = 0
		m.run_damage_dealt = 0
	NearDeathRunService.assign_carry_support(squad)
	NearDeathAwakeningService.reset_run_flags(self)
	is_active = true
	is_retreating = false
	retreat_origin_distance = 0.0
	retreat_destination = 0.0
	retreat_final_destination = 0.0
	retreat_reason = ""
	distance_traveled = 0.0
	spawn_timer = 0.0
	boss_spawned = false
	boss_defeated = false
	boss_zone_reached = false
	boss_chase_active = false
	guard_chase_active = false
	boss_chase_position = 0.0
	retreat_spawn_tier = ""
	chase_combat_in_progress = false
	chase_pressure = 0.0
	chase_boss_repelled_count = 0
	chase_evade_eligible = false
	chase_counter_uses = 0
	chase_stagger_charge = 0.0
	chase_stagger_holding = false
	chase_stagger_repelled_count = 0
	chase_deep_counter_uses = 0
	_chase_combat_cooldown = 0.0
	_chase_counter_cooldown = 0.0
	_chase_deep_counter_cooldown = 0.0
	_chase_stability_tick = 0.0
	run_loot_lost_count = 0
	manual_loot_abandoned = 0
	retreat_shield_max = 0
	retreat_shield_current = 0
	equip_shield_max = 0
	equip_shield_current = 0
	material_shield_max = 0
	material_shield_current = 0
	_shield_cd_equipment_ids.clear()
	_shield_emergency_refresh_used = false
	extract_guard_cleared = false
	pending_extract_guard = null
	last_extract_item_name = ""
	deploy_half = "A"
	_retreat_opening_spawns.clear()
	_pending_awakening_shield_bonus = 0
	if GameManager:
		deploy_half = str(GameManager.squad_formation.get("active_half", SquadFormationService.HALF_A))
		bench_reserves = SquadFormationService.load_bench_reserves(GameManager, deploy_half)
	else:
		bench_reserves.clear()
	total_gold_earned = 0
	total_exp_earned = 0
	total_loot.clear()
	RunLootService.init_run_grids(self)
	enemies_defeated = 0
	
	return 0


func tick(delta: float) -> Dictionary:
	if not is_active:
		return {"status": "inactive"}
	
	stability.tick(delta)
	
	if stability.should_withdraw() and not is_retreating:
		begin_retreat("forced")
	elif not is_retreating:
		AutoRetreatService.check(self)
	
	var result = {"status": "running", "events": []}
	for ambush_data in _retreat_opening_spawns:
		result.events.append({"type": "enemy_spawn", "data": ambush_data})
	_retreat_opening_spawns.clear()
	
	_advance_movement(delta)
	
	if is_retreating:
		_tick_retreat_leg()
		tick_boss_chase(delta)
	
	if not is_retreating:
		_update_boss_zone_flag()
	
	# 前进阶段：Boss 与刷怪
	if not is_retreating:
		if not boss_spawned and distance_traveled >= max_distance:
			boss_spawned = true
			boss_zone_reached = true
			var boss_data = _spawn_boss()
			boss_encountered.emit(boss_data)
			result.events.append({"type": "boss", "data": boss_data})
			if bool(map_data.get("auto_retreat_on_boss_spawn", false)) and not is_retreating:
				emit_signal(
					"run_event",
					"test_auto_retreat",
					{"reason": "到达首领线，测试图自动返程以触发追击"}
				)
				begin_retreat("forced")
		
		if not boss_spawned:
			spawn_timer += delta
			var interval := spawn_interval * _rng.randf_range(0.7, 1.3)
			if spawn_timer >= interval:
				spawn_timer = 0.0
				var enemy_data = _spawn_random_enemy()
				if not enemy_data.is_empty():
					enemy_spawned.emit(enemy_data)
					result.events.append({"type": "enemy_spawn", "data": enemy_data})
	else:
		spawn_timer += delta
		var profile: Dictionary = RetreatSpawnService.get_spawn_profile(self)
		retreat_spawn_tier = str(profile.get("tier", ""))
		var retreat_mult: float = float(profile.get("interval_mult", 1.15))
		var interval: float = spawn_interval * retreat_mult * _rng.randf_range(0.75, 1.05)
		if spawn_timer >= interval:
			spawn_timer = 0.0
			var pack: int = int(profile.get("pack", 1))
			for _pack_i in range(pack):
				var enemy_data: Dictionary = _spawn_random_enemy()
				if enemy_data.is_empty():
					break
				enemy_spawned.emit(enemy_data)
				result.events.append({"type": "enemy_spawn", "data": enemy_data})
	
	result.distance = distance_traveled
	result.is_retreating = is_retreating
	result.retreat_origin = retreat_origin_distance
	result.retreat_destination = retreat_destination
	result.retreat_final_destination = retreat_final_destination
	result.retreat_progress = get_retreat_progress()
	result.retreat_reason = retreat_reason
	result.team_stability = stability.team_stability
	result.stability = stability.team_stability
	result.min_personal_stability = stability.get_min_personal_stability()
	result.stability_pressure = stability.get_team_cost_multiplier()
	result.boss_chase_active = boss_chase_active
	result.guard_chase_active = guard_chase_active
	result.boss_chase_gap = get_boss_chase_gap()
	result.chase_pressure = chase_pressure
	result.chase_counter_ready = BossChaseService.can_counter_strike(self)
	result.chase_counter_cooldown = _chase_counter_cooldown
	result.chase_stagger_charge = chase_stagger_charge
	result.chase_stagger_ready = chase_stagger_charge >= 0.92 and chase_combat_in_progress
	result.chase_combat_in_progress = chase_combat_in_progress
	result.chase_deep_counter_ready = BossChaseService.can_deep_counter_strike(self)
	result.chase_deep_counter_cooldown = _chase_deep_counter_cooldown
	result.retreat_spawn_tier = retreat_spawn_tier
	result.retreat_spawn_label = RetreatSpawnService.get_spawn_profile(self).get("label", "")
	result.shield_damage_mult = RetreatSpawnService.get_shield_damage_mult(self)
	result.retreat_shield = retreat_shield_current
	result.retreat_shield_max = retreat_shield_max
	result.equip_shield = equip_shield_current
	result.equip_shield_max = equip_shield_max
	result.material_shield = material_shield_current
	result.material_shield_max = material_shield_max
	result.carry_value = CarryValueService.compute(self, GameManager.auto_retreat_safe_only if GameManager else false)
	result.carry_value_threshold = AutoRetreatService.get_value_threshold(self)
	result.extract_line_label = get_extract_line_label()
	result.has_extract_line = has_active_extract_line()
	_apply_loot_stats_to_dict(result)
	
	return result


func _apply_loot_stats_to_dict(result: Dictionary, manual_settle: bool = false) -> void:
	if manual_settle:
		total_loot = RunLootService.collect_loot_for_settlement(self, true)
	else:
		_sync_total_loot_cache()
	result.total_loot = total_loot.duplicate()
	result.safe_loot_count = safe_loot.item_count() if safe_loot else 0
	result.exposed_loot_count = exposed_loot.item_count() if exposed_loot else 0
	result.safe_loot_fill = safe_loot.get_fill_ratio() if safe_loot else 0.0
	result.exposed_loot_fill = exposed_loot.get_fill_ratio() if exposed_loot else 0.0


func _build_enemy_pool() -> void:
	_enemy_pool.clear()
	var pool = map_data.get("enemy_pool", [])
	for entry in pool:
		var weight = entry.get("weight", 10)
		for _i in range(weight):
			_enemy_pool.append(entry)


func _spawn_random_enemy() -> Dictionary:
	if _enemy_pool.is_empty():
		return {}
	var entry = _enemy_pool[_rng.randi() % _enemy_pool.size()]
	var tpl = DataLoader.enemy_template(entry.template)
	if tpl.is_empty():
		return {}
	var lvl_range = entry.get("level_range", [1, 3])
	var level = _rng.randi_range(lvl_range[0], lvl_range[1])
	var instance = tpl.duplicate(true)
	instance.level = level
	instance.uid = "enemy_%d_%d" % [level, randi()]
	if not instance.has("name"):
		instance.name = tpl.get("name", entry.get("template", "敌人"))
	# 等级缩放
	instance.stats = _scale_enemy_stats(instance.stats, level, tpl.get("level", 1))
	var map_mult: float = float(map_data.get("enemy_stat_mult", 1.0))
	if absf(map_mult - 1.0) > 0.001:
		instance.stats = _multiply_enemy_stats(instance.stats, map_mult)
	return instance


func _spawn_boss() -> Dictionary:
	return _spawn_boss_from_id(str(map_data.get("boss", "")), "boss")


func _spawn_boss_from_id(boss_id: String, uid_prefix: String) -> Dictionary:
	if boss_id == "":
		return {}
	var tpl = DataLoader.enemy_template(boss_id)
	if tpl.is_empty():
		return {}
	var instance = tpl.duplicate(true)
	instance.uid = "%s_%s" % [uid_prefix, boss_id]
	instance["is_boss"] = true
	var boss_level: int = int(tpl.get("level", 10))
	instance.stats = _scale_enemy_stats(instance.stats, boss_level + 2, tpl.get("level", 1))
	var map_mult: float = float(map_data.get("enemy_stat_mult", 1.0))
	if absf(map_mult - 1.0) > 0.001:
		instance.stats = _multiply_enemy_stats(instance.stats, map_mult)
	var chase_mult: float = float(map_data.get("chase_boss_stat_mult", 1.0))
	if uid_prefix == "chase" and absf(chase_mult - 1.0) > 0.001:
		instance.stats = _multiply_enemy_stats(instance.stats, chase_mult)
	return instance


func _scale_enemy_stats(stats: Dictionary, level: int, base_level: int) -> Dictionary:
	var s = stats.duplicate(true)
	var factor = 1.0 + (level - base_level) * 0.3
	for key in ["hp", "patk", "matk", "pdef", "mdef"]:
		if s.has(key):
			s[key] = int(s[key] * factor)
	return s


func _multiply_enemy_stats(stats: Dictionary, mult: float) -> Dictionary:
	var s = stats.duplicate(true)
	for key in ["hp", "patk", "matk", "pdef", "mdef"]:
		if s.has(key):
			s[key] = int(s[key] * mult)
	return s


func register_enemy_defeat(enemy_data: Dictionary) -> void:
	enemies_defeated += 1
	var exp_amount: int = int(enemy_data.get("exp_reward", 10))
	var gold = enemy_data.get("gold_reward", 5)
	total_exp_earned += exp_amount
	total_gold_earned += gold
	
	# 掉落
	var drop = _roll_loot(enemy_data)
	if drop is Equipment:
		_add_run_loot(drop)
		loot_dropped.emit(drop, gold)
	elif drop is RunMaterial:
		_add_run_material(drop)
		emit_signal("run_event", "material_dropped", {"name": drop.item_name, "value": drop.material_value})
	
	if (
		enemy_data.get("is_boss", false)
		and not enemy_data.get("is_chase_encounter", false)
		and not enemy_data.get("is_extract_guard", false)
	):
		boss_defeated = true
		stability.on_boss_killed()
	if not enemy_data.get("is_extract_guard", false):
		load(_EXTRACT_ITEM_SERVICE_PATH).try_drop_on_defeat(self, enemy_data)


func register_chase_deep_counter_repelled(enemy_data: Dictionary) -> void:
	var exp_amount: int = int(float(enemy_data.get("exp_reward", 10)) * 0.55)
	var gold: int = int(float(enemy_data.get("gold_reward", 5)) * 0.4)
	total_exp_earned += exp_amount
	total_gold_earned += gold
	emit_signal(
		"run_event",
		"chase_deep_counter_repelled",
		{"exp": exp_amount, "gold": gold, "bonus": true}
	)


func register_chase_stagger_repelled(enemy_data: Dictionary) -> void:
	var exp_amount: int = int(float(enemy_data.get("exp_reward", 10)) * 0.45)
	var gold: int = int(float(enemy_data.get("gold_reward", 5)) * 0.35)
	total_exp_earned += exp_amount
	total_gold_earned += gold
	chase_stagger_repelled_count += 1
	emit_signal("run_event", "chase_stagger_repelled", {"exp": exp_amount, "gold": gold})


func tick_chase_stagger_charge(delta: float) -> void:
	if not chase_combat_in_progress:
		chase_stagger_charge = 0.0
		chase_stagger_holding = false
		return
	if not chase_stagger_holding:
		chase_stagger_charge = maxf(0.0, chase_stagger_charge - delta * 0.35)
		return
	var rate: float = float(map_data.get("chase_stagger_charge_rate", 0.9))
	chase_stagger_charge = minf(1.0, chase_stagger_charge + delta * rate)


func register_chase_boss_kill(enemy_data: Dictionary) -> void:
	enemies_defeated += 1
	var table: Dictionary = _get_chase_drop_table()
	var exp_mult: float = float(table.get("exp_mult", 1.0)) if not table.is_empty() else 1.0
	var gold_mult: float = float(table.get("gold_mult", 1.0)) if not table.is_empty() else 1.0
	var exp_amount: int = int(float(enemy_data.get("exp_reward", 10)) * exp_mult)
	var gold: int = int(float(enemy_data.get("gold_reward", 5)) * gold_mult)
	total_exp_earned += exp_amount
	total_gold_earned += gold
	_roll_chase_kill_loot(enemy_data, table)
	boss_defeated = true
	boss_chase_active = false
	chase_combat_in_progress = false
	if stability != null:
		stability.on_boss_killed()
	emit_signal("run_event", "chase_boss_killed", {"name": enemy_data.get("name", "")})


func _get_chase_drop_table() -> Dictionary:
	var table_id: String = str(map_data.get("chase_drop_table", ""))
	if table_id == "":
		return {}
	return DataLoader.chase_drop_table(table_id)


func _roll_chase_kill_loot(enemy_data: Dictionary, table: Dictionary) -> void:
	var forge_drop: float = 0.0
	var forge_quality: int = 0
	if GameManager:
		forge_drop = GameManager.get_forge_drop_rate_bonus()
		forge_quality = GameManager.get_forge_quality_bonus()
	var fake_enemy: Dictionary = enemy_data.duplicate()
	fake_enemy["is_boss"] = true
	var got_loot: bool = false
	if not table.is_empty() and bool(table.get("guaranteed_equipment", false)):
		var shift: int = int(table.get("quality_shift", 0)) + forge_quality
		var eq: Equipment = LootSystem.roll_equipment(map_data, fake_enemy, forge_drop, shift)
		if eq != null:
			_add_run_loot(eq)
			loot_dropped.emit(eq, 0)
			got_loot = true
	if not got_loot:
		var drop = _roll_loot(fake_enemy)
		if drop is Equipment:
			_add_run_loot(drop)
			loot_dropped.emit(drop, 0)
		elif drop is RunMaterial:
			_add_run_material(drop)
			emit_signal("run_event", "material_dropped", {"name": drop.item_name, "value": drop.material_value})
	elif _rng.randf() < LootSystem.get_material_drop_chance(map_data, fake_enemy):
		var mat: RunMaterial = LootSystem.roll_material(map_data, fake_enemy)
		if mat != null:
			_add_run_material(mat)
			emit_signal("run_event", "material_dropped", {"name": mat.item_name, "value": mat.material_value})


func _add_run_loot(equip: Equipment) -> void:
	var placed: Dictionary = RunLootService.add_equipment_drop(self, equip)
	if placed.get("ok", false):
		_sync_total_loot_cache()
	else:
		push_warning("WorldRun: 掉落 %s 未能放入安全箱/外露网格" % equip.item_name)


func _sync_total_loot_cache() -> void:
	total_loot = RunLootService.collect_all_equipment(self)


func _roll_loot(enemy_data: Dictionary) -> Variant:
	var forge_drop: float = 0.0
	var forge_quality: int = 0
	if GameManager:
		forge_drop = GameManager.get_forge_drop_rate_bonus()
		forge_quality = GameManager.get_forge_quality_bonus()
	var drop_chance: float = LootSystem.get_drop_chance(map_data, enemy_data, forge_drop)
	if _rng.randf() >= drop_chance:
		return null
	if _rng.randf() < LootSystem.get_material_drop_chance(map_data, enemy_data):
		var mat: RunMaterial = LootSystem.roll_material(map_data, enemy_data)
		if mat != null:
			return mat
	return LootSystem.roll_equipment(map_data, enemy_data, forge_drop, forge_quality)


func get_extract_line_label() -> String:
	if pending_extract_guard != null:
		return "撤离物·待战守卫: %s" % pending_extract_guard.item_name
	var names: PackedStringArray = []
	if safe_loot:
		for it in safe_loot.get_all_extract_items():
			names.append(it.item_name)
	if exposed_loot:
		for it in exposed_loot.get_all_extract_items():
			if it.item_name not in names:
				names.append(it.item_name)
	if names.is_empty():
		return ""
	if last_extract_item_name != "" and last_extract_item_name not in names:
		names.append(last_extract_item_name)
	return "撤离物: %s" % ", ".join(names)


func has_active_extract_line() -> bool:
	if pending_extract_guard != null:
		return true
	if safe_loot:
		for _it in safe_loot.get_all_extract_items():
			return true
	if exposed_loot:
		for _it in exposed_loot.get_all_extract_items():
			return true
	return false


func build_extract_guard_encounter() -> Dictionary:
	var guard_id: String = str(map_data.get("extract_guard", map_data.get("boss", "")))
	var tpl = DataLoader.enemy_template(guard_id)
	if tpl.is_empty():
		return _spawn_boss()
	var instance = tpl.duplicate(true)
	instance.uid = "extract_guard_%s" % guard_id
	instance["is_boss"] = true
	instance["is_extract_guard"] = true
	instance["is_chase_encounter"] = false
	var lvl: int = int(tpl.get("level", 8)) + 1
	instance.stats = _scale_enemy_stats(instance.stats, lvl, tpl.get("level", 1))
	var mult: float = float(map_data.get("extract_guard_stat_mult", 1.1))
	if absf(mult - 1.0) > 0.001:
		instance.stats = _multiply_enemy_stats(instance.stats, mult)
	instance.name = "宝库守卫·" + str(instance.get("name", guard_id))
	return instance


func _add_run_material(mat: RunMaterial) -> void:
	var placed: Dictionary = RunLootService.add_material_drop(self, mat)
	if not placed.get("ok", false):
		push_warning("WorldRun: 物资 %s 未能放入网格" % mat.item_name)


func on_member_down() -> void:
	stability.on_member_down()
	if squad != null:
		NearDeathRunService.assign_carry_support(squad)


func on_member_retreat() -> void:
	stability.on_member_retreat()


func is_retreat_shield_active() -> bool:
	return RetreatShieldService.is_active(self)


## 返程受击：先扣装备盾再扣物资盾；皆破后可能掉外露装备
func on_retreat_ally_hit(damage: int) -> bool:
	if not is_retreating or damage <= 0:
		return false
	var shield_mult: float = RetreatSpawnService.get_shield_damage_mult(self)
	if shield_mult > 1.001:
		damage = maxi(1, int(float(damage) * shield_mult))
	if RetreatShieldService.is_active(self):
		var hit: Dictionary = RetreatShieldService.apply_damage(self, damage)
		emit_signal(
			"run_event",
			"retreat_shield_hit",
			{
				"absorbed": hit.get("absorbed", 0),
				"shield": retreat_shield_current,
				"shield_max": retreat_shield_max,
				"equip_shield": equip_shield_current,
				"material_shield": material_shield_current,
			}
		)
		if hit.get("broken", false):
			emit_signal(
				"run_event",
				"retreat_shield_broken",
				{
					"shield_max": retreat_shield_max,
					"equip_shield_max": equip_shield_max,
					"material_shield_max": material_shield_max,
				}
			)
		return true
	try_drop_loot_on_retreat_hit()
	return false


## 护盾破碎后：概率丢弃本次探险尚未结算的掉落
func try_drop_loot_on_retreat_hit() -> Dictionary:
	if not is_retreating:
		return {}
	if is_retreat_shield_active():
		return {}
	if exposed_loot == null or exposed_loot.is_empty():
		return {}
	var chance: float = float(map_data.get("retreat_hit_drop_chance", 0.14))
	if _rng.randf() >= chance:
		return {}
	var item: Equipment = exposed_loot.remove_random_equipment()
	if item == null:
		return {}
	run_loot_lost_count += 1
	_sync_total_loot_cache()
	var exposed_remaining: int = exposed_loot.item_count() if exposed_loot else 0
	emit_signal(
		"run_event",
		"loot_lost_on_retreat",
		{
			"item_name": item.item_name,
			"quality_name": item.quality_name,
			"remaining": exposed_remaining,
		}
	)
	return {"item": item, "item_name": item.item_name}


func _prime_retreat_spawn_timer() -> void:
	var profile: Dictionary = RetreatSpawnService.get_spawn_profile(self)
	var retreat_mult: float = float(profile.get("interval_mult", 1.15))
	spawn_timer = spawn_interval * retreat_mult * 0.45


func _queue_retreat_opening_ambush() -> void:
	_retreat_opening_spawns.clear()
	var opening: int = RetreatSpawnService.opening_ambush_count(self)
	for _i in range(opening):
		var enemy_data: Dictionary = _spawn_random_enemy()
		if not enemy_data.is_empty():
			_retreat_opening_spawns.append(enemy_data)


## 手动斩仓：不返程，仅安全箱进结算；外露已在调用前舍弃
func prepare_manual_withdraw() -> int:
	if not is_active or is_retreating:
		return 0
	retreat_reason = "manual"
	manual_loot_abandoned = RunLootService.abandon_exposed_loot(self)
	return manual_loot_abandoned


func begin_retreat(reason: String) -> void:
	if is_retreating:
		return
	retreat_reason = reason
	retreat_origin_distance = distance_traveled
	retreat_final_destination = float(map_data.get("retreat_destination", 0.0))
	retreat_destination = _resolve_first_retreat_leg(reason)
	is_retreating = true
	_prime_retreat_spawn_timer()
	_queue_retreat_opening_ambush()
	_init_retreat_shield(reason)
	guard_chase_active = RetreatSpawnService.should_activate_guard_chase(self, reason)
	_try_activate_boss_chase()
	if guard_chase_active and not boss_chase_active:
		emit_signal(
			"run_event",
			"guard_chase_started",
			{"reason": reason, "spawn_tier": RetreatSpawnService.TIER_CHASE}
		)
	emit_signal(
		"run_event",
		"retreat_started",
		{
			"reason": reason,
			"origin": retreat_origin_distance,
			"destination": retreat_destination,
			"final_destination": retreat_final_destination,
		}
	)


func refresh_retreat_shield(reason: String) -> void:
	RetreatShieldService.init_shields(self, reason, is_retreating)


func _init_retreat_shield(reason: String) -> void:
	RetreatShieldService.init_shields(self, reason, false)


func _resolve_first_retreat_leg(_reason: String) -> float:
	var base_dest: float = retreat_final_destination
	if not map_data.has("extract_distance"):
		return base_dest
	var extract: float = float(map_data.extract_distance)
	if distance_traveled > extract + RETREAT_ARRIVE_EPSILON:
		return maxf(base_dest, extract)
	return base_dest


func _update_boss_zone_flag() -> void:
	if boss_zone_reached or boss_spawned:
		return
	var ratio: float = float(map_data.get("boss_zone_ratio", 0.85))
	if distance_traveled >= max_distance * ratio:
		boss_zone_reached = true


func _try_activate_boss_chase() -> void:
	if not BossChaseService.should_start_chase(self):
		return
	chase_pressure = BossChaseService.compute_pressure(self)
	boss_chase_active = true
	var offset: float = float(map_data.get("boss_chase_start_offset", 90.0))
	boss_chase_position = maxf(distance_traveled + offset, max_distance * 0.92)
	_chase_combat_cooldown = 2.0 / BossChaseService.get_catch_cooldown_mult(self)
	emit_signal(
		"run_event",
		"boss_chase_started",
		{
			"gap": get_boss_chase_gap(),
			"position": boss_chase_position,
			"pressure": chase_pressure,
		}
	)


func get_boss_chase_gap() -> float:
	if not boss_chase_active:
		return 9999.0
	return maxf(0.0, boss_chase_position - distance_traveled)


func try_chase_counter_strike() -> Dictionary:
	var result: Dictionary = BossChaseService.try_counter_strike(self)
	if result.get("ok", false):
		emit_signal("run_event", "boss_chase_counter", result)
	return result


func tick_boss_chase(delta: float) -> void:
	if not boss_chase_active or not is_retreating:
		return
	BossChaseService.tick_counter_cooldown(self, delta)
	BossChaseService.tick_deep_counter_cooldown(self, delta)
	chase_pressure = BossChaseService.compute_pressure(self)
	if _chase_combat_cooldown > 0.0:
		_chase_combat_cooldown = maxf(0.0, _chase_combat_cooldown - delta)
	var speed: float = float(map_data.get("boss_chase_speed", 118.0))
	speed *= BossChaseService.get_chase_speed_mult(self)
	if chase_combat_in_progress:
		speed *= float(map_data.get("boss_chase_combat_mult", 1.4))
	boss_chase_position -= speed * delta
	boss_chase_position = maxf(boss_chase_position, distance_traveled)
	var gap: float = get_boss_chase_gap()
	if gap <= CHASE_DANGER_GAP:
		_chase_stability_tick += delta
		if _chase_stability_tick >= 1.0 and stability != null:
			_chase_stability_tick = 0.0
			var extra: int = 2 if gap <= CHASE_CATCH_GAP else 1
			extra = int(ceilf(float(extra) * BossChaseService.get_stability_penalty_mult(self)))
			stability.modify_team_stability(-extra)


func should_trigger_chase_combat() -> bool:
	if not boss_chase_active or not is_retreating or chase_combat_in_progress:
		return false
	if _chase_combat_cooldown > 0.0:
		return false
	return get_boss_chase_gap() <= CHASE_CATCH_GAP


func build_chase_boss_encounter() -> Dictionary:
	var chase_id: String = str(map_data.get("chase_boss_id", map_data.get("boss", "")))
	var data: Dictionary = _spawn_boss_from_id(chase_id, "chase")
	if data.is_empty():
		data = _spawn_boss()
	if data.is_empty():
		return {}
	data["is_boss"] = true
	data["is_chase_encounter"] = true
	var tpl_name: String = str(data.get("name", "首领"))
	data["name"] = "追击中·%s" % tpl_name
	return data


func on_chase_boss_repelled(push_mult: float = 1.0) -> Dictionary:
	chase_combat_in_progress = false
	var repel_loot: Dictionary = _try_roll_chase_repel_loot()
	var rewards: Dictionary = BossChaseService.grant_repelled_rewards(self)
	var push: float = float(map_data.get("boss_chase_pushback", 140.0)) * maxf(1.0, push_mult)
	boss_chase_position = distance_traveled + push
	boss_chase_position = minf(boss_chase_position, max_distance)
	_chase_combat_cooldown = 10.0 / BossChaseService.get_catch_cooldown_mult(self)
	emit_signal(
		"run_event",
		"boss_chase_repelled",
		{
			"gap": get_boss_chase_gap(),
			"pushback": push,
			"exp": rewards.get("exp", 0),
			"gold": rewards.get("gold", 0),
			"counter": push_mult > 1.01,
			"repel_loot": repel_loot,
		}
	)
	return rewards


func _try_roll_chase_repel_loot() -> Dictionary:
	if boss_defeated:
		return {}
	var table: Dictionary = _get_chase_drop_table()
	if table.is_empty():
		return {}
	var chance: float = float(table.get("repel_equipment_chance", 0.0))
	if chance <= 0.001 or _rng.randf() >= chance:
		return {}
	var forge_drop: float = 0.0
	var forge_quality: int = 0
	if GameManager:
		forge_drop = GameManager.get_forge_drop_rate_bonus()
		forge_quality = GameManager.get_forge_quality_bonus()
	var fake_enemy: Dictionary = {"is_boss": true, "exp_reward": 8, "gold_reward": 4}
	var shift: int = maxi(0, int(table.get("quality_shift", 0)) - 1) + forge_quality
	var eq: Equipment = LootSystem.roll_equipment(map_data, fake_enemy, forge_drop, shift)
	if eq == null:
		return {}
	var placed: Dictionary = RunLootService.add_equipment_drop(self, eq)
	if not placed.get("ok", false):
		return {}
	loot_dropped.emit(eq, 0)
	emit_signal(
		"run_event",
		"chase_repel_loot",
		{"item_name": eq.item_name, "quality": eq.quality_name, "where": placed.get("where", "")}
	)
	return {"item_name": eq.item_name, "where": placed.get("where", "")}


func on_chase_boss_catch_penalty() -> void:
	chase_combat_in_progress = false
	if stability != null:
		var pen: int = int(ceilf(22.0 * BossChaseService.get_stability_penalty_mult(self)))
		stability.modify_team_stability(-pen)
	boss_chase_position = distance_traveled + 35.0
	_chase_combat_cooldown = 14.0
	emit_signal("run_event", "boss_chase_penalty", {"gap": get_boss_chase_gap()})


func _advance_movement(delta: float) -> void:
	if is_retreating:
		var speed: float = MOVE_SPEED_RETREAT * float(map_data.get("retreat_speed_mult", 1.0))
		speed *= NearDeathRunService.get_retreat_speed_multiplier(self)
		distance_traveled = maxf(retreat_destination, distance_traveled - speed * delta)
	else:
		var adv: float = MOVE_SPEED_ADVANCE * float(map_data.get("advance_speed_mult", 1.0))
		distance_traveled += adv * delta


func _tick_retreat_leg() -> void:
	if distance_traveled > retreat_destination + RETREAT_ARRIVE_EPSILON:
		return
	if retreat_destination > retreat_final_destination + RETREAT_ARRIVE_EPSILON:
		retreat_origin_distance = retreat_destination
		retreat_destination = retreat_final_destination
		emit_signal(
			"run_event",
			"extract_reached",
			{"distance": retreat_origin_distance, "next_destination": retreat_destination}
		)


func has_completed_retreat() -> bool:
	return is_retreating and distance_traveled <= retreat_final_destination + RETREAT_ARRIVE_EPSILON


func get_retreat_progress() -> float:
	if not is_retreating:
		return 0.0
	var span: float = retreat_origin_distance - retreat_destination
	if span <= 0.01:
		return 1.0
	return clampf((retreat_origin_distance - distance_traveled) / span, 0.0, 1.0)


func get_retreat_destination_label() -> String:
	if retreat_destination <= RETREAT_ARRIVE_EPSILON:
		return "大营"
	if map_data.has("extract_distance") and absf(retreat_destination - float(map_data.extract_distance)) < 1.0:
		return "撤离点"
	return "返程点 %.0fm" % retreat_destination


func _on_team_stability_changed(new_val: int) -> void:
	if new_val <= StabilitySystem.TEAM_WITHDRAW_THRESHOLD:
		emit_signal("run_event", "withdraw_confirm", {"stability": new_val, "team_stability": new_val})


func _on_forced_withdraw() -> void:
	begin_retreat("forced")
	emit_signal("run_event", "forced_withdraw", {})


func sync_stability_to_manager() -> void:
	if stability != null and GameManager:
		GameManager.set_team_stability(stability.team_stability)


func end_run(forced: bool = false) -> Dictionary:
	sync_stability_to_manager()
	is_active = false
	var manual: bool = retreat_reason == "manual"
	var at_camp: bool = distance_traveled <= retreat_final_destination + RETREAT_ARRIVE_EPSILON
	var extract_clear: bool = (boss_defeated or extract_guard_cleared) and not manual
	var completed_retreat: bool = is_retreating and at_camp
	var evade_bonus: Dictionary = BossChaseService.grant_evade_bonus(self) if completed_retreat else {}
	var result = {
		"map_id": map_id,
		"distance": distance_traveled,
		"enemies_defeated": enemies_defeated,
		"total_gold": total_gold_earned,
		"total_exp": total_exp_earned,
		"squad_member_ids": squad_member_ids.duplicate(),
		"squad_kills": squad.get_total_kills(),
		"forced_withdraw": forced or manual,
		"manual_withdraw": manual,
		"extract_clear": extract_clear,
		"run_success": extract_clear or (completed_retreat and squad.has_anyone_alive() and not manual),
		"completed_retreat": completed_retreat,
		"retreat_origin": retreat_origin_distance,
		"retreat_final_destination": retreat_final_destination,
		"boss_defeated": boss_defeated,
		"chase_pressure": chase_pressure,
		"chase_boss_repelled": chase_boss_repelled_count,
		"chase_evade_exp": evade_bonus.get("exp", 0),
		"chase_counter_uses": chase_counter_uses,
		"chase_stagger_repelled": chase_stagger_repelled_count,
		"chase_deep_counter_uses": chase_deep_counter_uses,
		"extract_guard_cleared": extract_guard_cleared,
		"last_extract_item_name": last_extract_item_name,
		"retreat_spawn_tier": retreat_spawn_tier,
		"retreat_reason": retreat_reason,
		"loot_lost_on_retreat": run_loot_lost_count,
		"loot_abandoned_manual": manual_loot_abandoned,
		"emergency_retreat": retreat_reason in ["emergency", "combat_fail"],
		"equip_shield_max": equip_shield_max,
		"material_shield_max": material_shield_max,
		"squad_alive": squad.get_alive_count() > 0,
		"player_alive": squad.has_anyone_alive(),
		"level_up_log": []
	}
	_apply_loot_stats_to_dict(result, manual)
	run_completed.emit(result)
	return result
