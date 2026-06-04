class_name WorldRun
extends RefCounted
## WorldRun — 单次出征的顶层逻辑

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
var total_loot: Array[Equipment] = []
var enemies_defeated: int = 0
var squad_member_ids: Array[String] = []
var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var boss_spawned: bool = false
var boss_defeated: bool = false
var boss_zone_reached: bool = false
var boss_chase_active: bool = false
var boss_chase_position: float = 0.0
var chase_combat_in_progress: bool = false
var _chase_combat_cooldown: float = 0.0
var _chase_stability_tick: float = 0.0
var run_loot_lost_count: int = 0
var retreat_shield_max: int = 0
var retreat_shield_current: int = 0
var _enemy_pool: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 返程开始时立即注入 tick 的遇敌（避免等计时器）
var _retreat_opening_spawns: Array = []


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
	boss_chase_position = 0.0
	chase_combat_in_progress = false
	_chase_combat_cooldown = 0.0
	_chase_stability_tick = 0.0
	run_loot_lost_count = 0
	retreat_shield_max = 0
	retreat_shield_current = 0
	_retreat_opening_spawns.clear()
	total_gold_earned = 0
	total_exp_earned = 0
	total_loot.clear()
	enemies_defeated = 0
	
	return 0


func tick(delta: float) -> Dictionary:
	if not is_active:
		return {"status": "inactive"}
	
	stability.tick(delta)
	
	if stability.should_withdraw() and not is_retreating:
		begin_retreat("forced")
	
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
		# 倍率 <1 刷得更快，>1 更慢（测试图请填 0.5~0.8）
		var retreat_mult: float = float(map_data.get("retreat_spawn_interval_mult", 0.85))
		var interval: float = spawn_interval * retreat_mult * _rng.randf_range(0.75, 1.05)
		if spawn_timer >= interval:
			spawn_timer = 0.0
			var pack: int = maxi(1, int(map_data.get("retreat_spawn_pack", 2)))
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
	result.boss_chase_gap = get_boss_chase_gap()
	result.retreat_shield = retreat_shield_current
	result.retreat_shield_max = retreat_shield_max
	
	return result


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
	var boss_id = map_data.get("boss", "")
	var tpl = DataLoader.enemy_template(boss_id)
	if tpl.is_empty():
		return {}
	var instance = tpl.duplicate(true)
	instance.uid = "boss_%s" % boss_id
	instance["is_boss"] = true
	var boss_level: int = int(tpl.get("level", 10))
	instance.stats = _scale_enemy_stats(instance.stats, boss_level + 2, tpl.get("level", 1))
	var map_mult: float = float(map_data.get("enemy_stat_mult", 1.0))
	if absf(map_mult - 1.0) > 0.001:
		instance.stats = _multiply_enemy_stats(instance.stats, map_mult)
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
	if drop:
		total_loot.append(drop)
		loot_dropped.emit(drop, gold)
	
	if enemy_data.get("is_boss", false) and not enemy_data.get("is_chase_encounter", false):
		boss_defeated = true
		stability.on_boss_killed()


func register_chase_boss_defeat(enemy_data: Dictionary) -> void:
	enemies_defeated += 1
	var exp_amount: int = int(enemy_data.get("exp_reward", 10))
	var gold = enemy_data.get("gold_reward", 5)
	total_exp_earned += exp_amount
	total_gold_earned += gold
	var drop = _roll_loot(enemy_data)
	if drop:
		total_loot.append(drop)
		loot_dropped.emit(drop, gold)


func _roll_loot(enemy_data: Dictionary) -> Equipment:
	var forge_drop: float = 0.0
	var forge_quality: int = 0
	if GameManager:
		forge_drop = GameManager.get_forge_drop_rate_bonus()
		forge_quality = GameManager.get_forge_quality_bonus()
	var drop_chance: float = LootSystem.get_drop_chance(map_data, enemy_data, forge_drop)
	if _rng.randf() >= drop_chance:
		return null
	return LootSystem.roll_equipment(map_data, enemy_data, forge_drop, forge_quality)


func on_member_down() -> void:
	stability.on_member_down()


func on_member_retreat() -> void:
	stability.on_member_retreat()


func is_retreat_shield_active() -> bool:
	return is_retreating and retreat_shield_current > 0


## 返程受击：护盾存在时吸收伤害；护盾破碎后才可能掉战利品
func on_retreat_ally_hit(damage: int) -> bool:
	if not is_retreating or damage <= 0:
		return false
	if retreat_shield_current > 0:
		var before: int = retreat_shield_current
		retreat_shield_current = maxi(0, retreat_shield_current - damage)
		emit_signal(
			"run_event",
			"retreat_shield_hit",
			{
				"absorbed": mini(before, damage),
				"shield": retreat_shield_current,
				"shield_max": retreat_shield_max,
			}
		)
		if before > 0 and retreat_shield_current <= 0:
			emit_signal("run_event", "retreat_shield_broken", {"shield_max": retreat_shield_max})
		return true
	try_drop_loot_on_retreat_hit()
	return false


## 护盾破碎后：概率丢弃本次探险尚未结算的掉落
func try_drop_loot_on_retreat_hit() -> Dictionary:
	if not is_retreating or total_loot.is_empty():
		return {}
	if is_retreat_shield_active():
		return {}
	var chance: float = float(map_data.get("retreat_hit_drop_chance", 0.14))
	if _rng.randf() >= chance:
		return {}
	var idx: int = _rng.randi() % total_loot.size()
	var item: Equipment = total_loot[idx]
	total_loot.remove_at(idx)
	run_loot_lost_count += 1
	emit_signal(
		"run_event",
		"loot_lost_on_retreat",
		{"item_name": item.item_name, "quality_name": item.quality_name, "remaining": total_loot.size()}
	)
	return {"item": item, "item_name": item.item_name}


func _prime_retreat_spawn_timer() -> void:
	var retreat_mult: float = float(map_data.get("retreat_spawn_interval_mult", 0.85))
	spawn_timer = spawn_interval * retreat_mult * 0.45


func _queue_retreat_opening_ambush() -> void:
	_retreat_opening_spawns.clear()
	var opening: int = maxi(1, int(map_data.get("retreat_start_ambush", 1)))
	for _i in range(opening):
		var enemy_data: Dictionary = _spawn_random_enemy()
		if not enemy_data.is_empty():
			_retreat_opening_spawns.append(enemy_data)


func manual_withdraw() -> void:
	begin_retreat("manual")


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
	_try_activate_boss_chase()
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
	_init_retreat_shield(reason)


func _init_retreat_shield(reason: String) -> void:
	retreat_shield_max = 0
	retreat_shield_current = 0
	if squad == null:
		return
	var anchor: Mercenary = squad.get_retreat_shield_anchor()
	if anchor == null or not anchor.is_alive:
		return
	var mult: float = 1.0
	match reason:
		"manual":
			mult = float(map_data.get("retreat_shield_mult_manual", 0.6))
		"forced", "emergency":
			mult = float(map_data.get("retreat_shield_mult", 1.0))
		_:
			mult = float(map_data.get("retreat_shield_mult", 1.0))
	retreat_shield_max = maxi(1, int(float(StatResolver.get_max_hp(anchor)) * mult))
	retreat_shield_current = retreat_shield_max
	emit_signal(
		"run_event",
		"retreat_shield_started",
		{"shield": retreat_shield_current, "shield_max": retreat_shield_max, "reason": reason}
	)


func _resolve_first_retreat_leg(reason: String) -> float:
	var base_dest: float = retreat_final_destination
	if reason == "manual" and map_data.has("extract_distance"):
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
	if not _should_boss_chase_on_retreat():
		return
	boss_chase_active = true
	var offset: float = float(map_data.get("boss_chase_start_offset", 90.0))
	boss_chase_position = maxf(distance_traveled + offset, max_distance * 0.92)
	_chase_combat_cooldown = 2.0
	emit_signal(
		"run_event",
		"boss_chase_started",
		{"gap": get_boss_chase_gap(), "position": boss_chase_position}
	)


func _should_boss_chase_on_retreat() -> bool:
	if bool(map_data.get("disable_boss_chase", false)):
		return false
	return boss_spawned or boss_zone_reached


func get_boss_chase_gap() -> float:
	if not boss_chase_active:
		return 9999.0
	return maxf(0.0, boss_chase_position - distance_traveled)


func tick_boss_chase(delta: float) -> void:
	if not boss_chase_active or not is_retreating:
		return
	if _chase_combat_cooldown > 0.0:
		_chase_combat_cooldown = maxf(0.0, _chase_combat_cooldown - delta)
	var speed: float = float(map_data.get("boss_chase_speed", 118.0))
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
			stability.modify_team_stability(-extra)


func should_trigger_chase_combat() -> bool:
	if not boss_chase_active or not is_retreating or chase_combat_in_progress:
		return false
	if _chase_combat_cooldown > 0.0:
		return false
	return get_boss_chase_gap() <= CHASE_CATCH_GAP


func build_chase_boss_encounter() -> Dictionary:
	var data: Dictionary = _spawn_boss()
	data["is_boss"] = true
	data["is_chase_encounter"] = true
	data["name"] = "追击中·" + str(data.get("name", "首领"))
	return data


func on_chase_boss_repelled() -> void:
	chase_combat_in_progress = false
	var push: float = float(map_data.get("boss_chase_pushback", 140.0))
	boss_chase_position = distance_traveled + push
	boss_chase_position = minf(boss_chase_position, max_distance)
	_chase_combat_cooldown = 10.0
	emit_signal(
		"run_event",
		"boss_chase_repelled",
		{"gap": get_boss_chase_gap(), "pushback": push}
	)


func on_chase_boss_catch_penalty() -> void:
	chase_combat_in_progress = false
	if stability != null:
		stability.modify_team_stability(-22)
	boss_chase_position = distance_traveled + 35.0
	_chase_combat_cooldown = 14.0
	emit_signal("run_event", "boss_chase_penalty", {"gap": get_boss_chase_gap()})


func _advance_movement(delta: float) -> void:
	if is_retreating:
		var speed: float = MOVE_SPEED_RETREAT * float(map_data.get("retreat_speed_mult", 1.0))
		if squad != null and squad.has_any_member_near_death():
			speed *= NEAR_DEATH_RETREAT_SPEED_MULT
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
	var result = {
		"map_id": map_id,
		"distance": distance_traveled,
		"enemies_defeated": enemies_defeated,
		"total_gold": total_gold_earned,
		"total_exp": total_exp_earned,
		"squad_member_ids": squad_member_ids.duplicate(),
		"total_loot": total_loot.duplicate(),
		"squad_kills": squad.get_total_kills(),
		"forced_withdraw": forced,
		"completed_retreat": is_retreating or forced,
		"retreat_origin": retreat_origin_distance,
		"retreat_final_destination": retreat_final_destination,
		"boss_defeated": boss_defeated,
		"loot_lost_on_retreat": run_loot_lost_count,
		"retreat_reason": retreat_reason,
		"emergency_retreat": retreat_reason == "emergency",
		"squad_alive": squad.get_alive_count() > 0,
		"player_alive": squad.has_anyone_alive(),
		"level_up_log": []
	}
	run_completed.emit(result)
	return result