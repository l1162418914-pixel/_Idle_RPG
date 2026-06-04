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
var total_gold_earned: int = 0
var total_loot: Array[Equipment] = []
var enemies_defeated: int = 0
var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var boss_spawned: bool = false
var boss_defeated: bool = false
var _enemy_pool: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_map_id: String, p_squad: Squad) -> void:
	map_id = p_map_id
	squad = p_squad
	map_data = DataLoader.map_data(map_id)
	if map_data.is_empty():
		push_error("WorldRun: 地图 %s 不存在" % map_id)
		return
	
	max_distance = map_data.get("boss_distance", 600.0)
	_rng.randomize()


func start() -> int:
	if squad == null or squad.members.is_empty():
		return -1
	if map_data.is_empty():
		return -2
	
	stability = StabilitySystem.new()
	stability.init(squad.get_player(), squad)
	stability.stability_changed.connect(_on_stability_changed)
	stability.forced_withdraw.connect(_on_forced_withdraw)
	
	_build_enemy_pool()
	
	for m in squad.members:
		m.reset_to_full_hp()
		m.run_kills = 0
		m.run_damage_dealt = 0
	
	is_active = true
	is_retreating = false
	distance_traveled = 0.0
	spawn_timer = 0.0
	boss_spawned = false
	boss_defeated = false
	total_gold_earned = 0
	total_loot.clear()
	enemies_defeated = 0
	
	return 0


func tick(delta: float) -> Dictionary:
	if not is_active:
		return {"status": "inactive"}
	
	stability.tick(delta)
	
	if stability.should_withdraw() and not is_retreating:
		is_retreating = true
	
	var result = {"status": "running", "events": []}
	
	# 移动
	distance_traveled += 80.0 * delta  # 默认移动速度
	
	# 检查 Boss
	if not boss_spawned and distance_traveled >= max_distance:
		boss_spawned = true
		var boss_data = _spawn_boss()
		boss_encountered.emit(boss_data)
		result.events.append({"type": "boss", "data": boss_data})
	
	# 随机刷怪
	if not boss_spawned and not is_retreating:
		spawn_timer += delta
		var interval = spawn_interval * _rng.randf_range(0.7, 1.3)
		if spawn_timer >= interval:
			spawn_timer = 0.0
			var enemy_data = _spawn_random_enemy()
			if not enemy_data.is_empty():
				enemy_spawned.emit(enemy_data)
				result.events.append({"type": "enemy_spawn", "data": enemy_data})
	
	result.distance = distance_traveled
	result.stability = stability.current_stability
	
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
	# 等级缩放
	instance.stats = _scale_enemy_stats(instance.stats, level, tpl.get("level", 1))
	return instance


func _spawn_boss() -> Dictionary:
	var boss_id = map_data.get("boss", "")
	var tpl = DataLoader.enemy_template(boss_id)
	if tpl.is_empty():
		return {}
	var instance = tpl.duplicate(true)
	instance.uid = "boss_%s" % boss_id
	return instance


func _scale_enemy_stats(stats: Dictionary, level: int, base_level: int) -> Dictionary:
	var s = stats.duplicate(true)
	var factor = 1.0 + (level - base_level) * 0.3
	for key in ["hp", "patk", "matk", "pdef", "mdef"]:
		if s.has(key):
			s[key] = int(s[key] * factor)
	return s


func register_enemy_defeat(enemy_data: Dictionary) -> void:
	enemies_defeated += 1
	var exp = enemy_data.get("exp_reward", 10)
	var gold = enemy_data.get("gold_reward", 5)
	total_gold_earned += gold
	
	# 掉落
	var drop = _roll_loot(enemy_data)
	if drop:
		total_loot.append(drop)
		loot_dropped.emit(drop, gold)
	
	if enemy_data.get("is_boss", false):
		boss_defeated = true
		stability.on_boss_killed()


func _roll_loot(enemy_data: Dictionary) -> Equipment:
	var drop_chance = 0.15
	if enemy_data.get("is_boss", false):
		drop_chance = 1.0
	
	if _rng.randf() < drop_chance:
		var slots = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]
		var slot = slots[_rng.randi() % slots.size()]
		var level = enemy_data.get("level", 1)
		return Equipment.generate(slot, -1, level)
	return null


func on_member_down() -> void:
	stability.on_member_down()


func manual_withdraw() -> void:
	is_retreating = true


func _on_stability_changed(new_val: int) -> void:
	if new_val <= 30:
		emit_signal("run_event", "withdraw_confirm", {"stability": new_val})


func _on_forced_withdraw() -> void:
	emit_signal("run_event", "forced_withdraw", {})


func end_run(forced: bool = false) -> Dictionary:
	is_active = false
	var result = {
		"map_id": map_id,
		"distance": distance_traveled,
		"enemies_defeated": enemies_defeated,
		"total_gold": total_gold_earned,
		"total_loot": total_loot.duplicate(),
		"squad_kills": squad.get_total_kills(),
		"forced_withdraw": forced,
		"boss_defeated": boss_defeated,
		"player_alive": squad.is_player_alive()
	}
	run_completed.emit(result)
	return result