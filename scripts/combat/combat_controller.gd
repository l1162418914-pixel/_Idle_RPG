class_name CombatController
extends RefCounted
## CombatController — 实时横版自动战斗逻辑

signal combat_started()
signal combat_ended(victory: bool)
signal entity_dead(entity: CombatEntity)
signal attack_started(attacker: String, target: String)
signal damage_dealt(attacker: String, target: String, damage: int)

const BATTLEFIELD_WIDTH: float = 600.0
const ALLY_SPAWN_X: float = 100.0
const ENEMY_SPAWN_X: float = 500.0

var allies: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []
var is_active: bool = false
var combat_time: float = 0.0
var ally_formation_gap: float = 30.0
var enemy_formation_gap: float = 30.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func init_combat(squad: Squad, enemy_data_list: Array, world_run: WorldRun) -> void:
	allies.clear()
	enemies.clear()
	
	# 生成友方实体
	for i in range(squad.members.size()):
		var m = squad.members[i]
		if m.is_alive:
			var e = CombatEntity.new()
			e.init_from_merc(m, "ally_")
			e.position = ALLY_SPAWN_X + i * ally_formation_gap
			e.on_death.connect(_on_ally_death)
			allies.append(e)
	
	# 生成敌方实体
	for i in range(enemy_data_list.size()):
		var data = enemy_data_list[i]
		var e = CombatEntity.new()
		e.init_from_enemy(data)
		e.position = ENEMY_SPAWN_X + i * enemy_formation_gap
		e.on_death.connect(_on_enemy_death)
		enemies.append(e)
	
	is_active = true
	combat_time = 0.0
	combat_started.emit()


func tick(delta: float) -> Dictionary:
	if not is_active:
		return {"status": "inactive"}
	
	combat_time += delta
	var events: Array[Dictionary] = []
	
	# Tick ally buffs and sync stats
	for entity in allies:
		if entity.source_merc:
			entity.source_merc.buff_system.tick(delta)
			entity.recalc_from_merc()
	
	# 更新所有实体
	for entity in allies:
		_entity_tick(entity, enemies, delta, events)
	
	for entity in enemies:
		_entity_tick(entity, allies, delta, events)
	
	# 检查胜负
	var ally_alive = _count_alive(allies)
	var enemy_alive = _count_alive(enemies)
	
	var result = {"status": "ongoing", "ally_alive": ally_alive, "enemy_alive": enemy_alive, "events": events}
	
	if ally_alive == 0:
		is_active = false
		result.status = "defeat"
		combat_ended.emit(false)
	elif enemy_alive == 0:
		is_active = false
		result.status = "victory"
		combat_ended.emit(true)
	
	return result


func _entity_tick(entity: CombatEntity, opponents: Array, delta: float, events: Array) -> void:
	if entity.is_dead():
		return
	
	match entity.action_state:
		CombatEntity.ActionState.IDLE, CombatEntity.ActionState.MOVING:
			var target = _find_nearest_alive(opponents, entity.position)
			entity.current_target = target
			
			if target == null:
				entity.action_state = CombatEntity.ActionState.IDLE
				return
			
			var dist = abs(entity.position - target.position)
			if dist <= entity.attack_range:
				# 进入攻击
				entity.action_state = CombatEntity.ActionState.ATTACKING
				entity.attack_timer = 0.0
				_do_attack(entity, target, events)
			else:
				# 移动
				entity.action_state = CombatEntity.ActionState.MOVING
				var dir = 1.0 if target.position > entity.position else -1.0
				entity.position += dir * entity.move_speed * delta
				entity.is_facing_right = dir > 0
				# 夹紧边界
				entity.position = clampf(entity.position, 0, BATTLEFIELD_WIDTH)
		
		CombatEntity.ActionState.ATTACKING:
			entity.attack_timer += delta
			var cooldown = 1.0 / entity.attack_speed
			if entity.attack_timer >= cooldown:
				entity.attack_timer = 0.0
				var target = _find_nearest_alive(opponents, entity.position)
				if target:
					_do_attack(entity, target, events)
				else:
					entity.action_state = CombatEntity.ActionState.IDLE


func _do_attack(attacker: CombatEntity, target: CombatEntity, events: Array) -> void:
	attack_started.emit(attacker.entity_id, target.entity_id)
	var dmg = attacker.deal_damage_to(target)
	events.append({
		"type": "damage",
		"attacker": attacker.entity_id,
		"target": target.entity_id,
		"damage": dmg,
		"target_hp": target.current_hp
	})
	damage_dealt.emit(attacker.entity_id, target.entity_id, dmg)
	
	# 更新佣兵伤害统计
	if attacker.source_merc:
		attacker.source_merc.run_damage_dealt += dmg
	
	if target.is_dead():
		events.append({
			"type": "death",
			"entity": target.entity_id,
			"team": target.team
		})
		# 击杀统计
		if attacker.source_merc:
			attacker.source_merc.run_kills += 1


func _find_nearest_alive(entities: Array, from_pos: float) -> CombatEntity:
	var best = null
	var best_dist = INF
	for e in entities:
		if e.is_dead():
			continue
		var d = abs(e.position - from_pos)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _count_alive(entities: Array) -> int:
	var c = 0
	for e in entities:
		if not e.is_dead():
			c += 1
	return c


func _on_ally_death(entity_id: String) -> void:
	for e in allies:
		if e.entity_id == entity_id and e.source_merc:
			e.source_merc.is_alive = false
			entity_dead.emit(e)
			break


func _on_enemy_death(entity_id: String) -> void:
	for e in enemies:
		if e.entity_id == entity_id:
			entity_dead.emit(e)
			break


func get_entity_map() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for e in allies:
		list.append(_entity_snapshot(e))
	for e in enemies:
		list.append(_entity_snapshot(e))
	return list


func _entity_snapshot(e: CombatEntity) -> Dictionary:
	return {
		"entity_id": e.entity_id,
		"team": e.team,
		"position": e.position,
		"action_state": e.action_state,
		"hp_ratio": e.hp_ratio(),
		"current_hp": e.current_hp,
		"max_hp": e.max_hp,
		"facing_right": e.is_facing_right
	}


func force_end() -> void:
	is_active = false
	combat_ended.emit(false)


## 战斗结束后将存活友方实体的 HP 写回源 Mercenary（阵亡者由 on_death 已处理）
func sync_allies_hp_to_mercs() -> void:
	for entity in allies:
		if entity.source_merc == null or entity.is_dead():
			continue
		entity.source_merc.current_hp = maxi(0, entity.current_hp)
		entity.source_merc.is_alive = true