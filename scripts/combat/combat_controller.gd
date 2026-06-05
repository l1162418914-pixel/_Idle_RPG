class_name CombatController
extends RefCounted
## CombatController — 实时横版自动战斗逻辑

signal combat_started()
signal combat_ended(victory: bool)
signal entity_dead(entity: CombatEntity)
signal attack_started(attacker: String, target: String)
signal damage_dealt(attacker: String, target: String, damage: int)
signal skill_cast(caster_id: String, skill_id: String, skill_name: String, log_text: String)

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
var _world_run: WorldRun = null
## 返程接战：友方不追击敌人，持续向左侧行进，射程内照常攻击
var _march_retreat_combat: bool = false


func _init() -> void:
	_rng.randomize()


func init_combat(squad: Squad, enemy_data_list: Array, world_run: WorldRun) -> void:
	_world_run = world_run
	_march_retreat_combat = world_run != null and world_run.is_retreating
	allies.clear()
	enemies.clear()
	
	# 友方实体（含濒死 — 需可视化；濒死单位不攻击、不移动）
	var battlefield: Array[Mercenary] = squad.get_battlefield_members()
	for i in range(battlefield.size()):
		var m: Mercenary = battlefield[i]
		var e := CombatEntity.new()
		e.init_from_merc(m, "ally_")
		e.position = ALLY_SPAWN_X + i * ally_formation_gap
		if m.is_awakening:
			e.current_hp = maxi(1, m.current_hp)
			e.action_state = CombatEntity.ActionState.AWAKENING
			var cfg: Dictionary = DataLoader.near_death_config().get("awakening", {})
			e.awakening_timer = m.awakening_time_left
			e.patk = maxi(1, int(float(e.patk) * float(cfg.get("damage_mult", 1.75))))
			e.attack_speed *= float(cfg.get("attack_speed_mult", 1.25))
		elif m.is_near_death:
			e.current_hp = maxi(1, m.current_hp)
			e.action_state = CombatEntity.ActionState.DOWNED
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
	
	for e in allies:
		_init_entity_stats(e)
		BattleDebug.apply_entity_modifiers(e)
	for e in enemies:
		_init_entity_stats(e)
		BattleDebug.apply_entity_modifiers(e)
	
	is_active = true
	combat_time = 0.0
	combat_started.emit()


func set_march_retreat_combat(enabled: bool) -> void:
	_march_retreat_combat = enabled


func tick(delta: float) -> Dictionary:
	if not is_active:
		return {"status": "inactive"}
	
	combat_time += delta
	var events: Array[Dictionary] = []
	
	# Tick ally buffs / 技能冷却 and sync stats
	for entity in allies:
		if entity.is_incapacitated():
			continue
		entity.tick_skill_cooldowns(delta)
		if entity.source_merc:
			entity.source_merc.buff_system.tick(delta)
			entity.recalc_from_merc()
	
	# 更新所有实体
	for entity in allies:
		if entity.is_awakening():
			if NearDeathAwakeningService.tick_combat(entity, delta):
				_entity_tick(entity, enemies, delta, events, true)
			continue
		_entity_tick(entity, enemies, delta, events, true)
	
	for entity in enemies:
		_entity_tick(entity, allies, delta, events, false)
	
	# 检查胜负
	var ally_alive = _count_fighting(allies)
	var enemy_alive = _count_alive(enemies)
	
	var result = {"status": "ongoing", "ally_alive": ally_alive, "enemy_alive": enemy_alive, "events": events}
	
	if _count_allies_still_on_field() == 0:
		is_active = false
		result.status = "defeat"
		combat_ended.emit(false)
	elif ally_alive == 0:
		# 全员濒死/失能但仍留在场上 — 无法再战，结束战斗走战败/紧急撤离
		is_active = false
		result.status = "defeat"
		combat_ended.emit(false)
	elif enemy_alive == 0:
		is_active = false
		result.status = "victory"
		combat_ended.emit(true)
	
	return result


func _entity_tick(entity: CombatEntity, opponents: Array, delta: float, events: Array, is_ally: bool) -> void:
	if entity.is_incapacitated():
		return
	
	if is_ally and _march_retreat_combat:
		_ally_retreat_march_tick(entity, opponents, allies, delta, events)
		return
	
	# 友方：射程外也可尝试施法（治疗/自保/远程技能）
	if is_ally and _try_cast_active_skill(entity, opponents, allies, events):
		return
	
	match entity.action_state:
		CombatEntity.ActionState.IDLE, CombatEntity.ActionState.MOVING:
			var attack_target: CombatEntity = _find_nearest_in_range(opponents, entity.position, entity.attack_range)
			var move_target: CombatEntity = _find_nearest_alive(opponents, entity.position)
			entity.current_target = attack_target if attack_target else move_target
			
			if move_target == null:
				entity.action_state = CombatEntity.ActionState.IDLE
				return
			
			if attack_target:
				entity.action_state = CombatEntity.ActionState.ATTACKING
				entity.attack_timer = 0.0
				_do_attack(entity, attack_target, events)
			else:
				entity.action_state = CombatEntity.ActionState.MOVING
				_move_toward_attack_range(entity, move_target, delta)
		
		CombatEntity.ActionState.ATTACKING:
			var attack_target: CombatEntity = _find_nearest_in_range(opponents, entity.position, entity.attack_range)
			if attack_target == null:
				entity.action_state = CombatEntity.ActionState.MOVING
				var move_target: CombatEntity = _find_nearest_alive(opponents, entity.position)
				if move_target:
					_move_toward_attack_range(entity, move_target, delta)
				return
			
			entity.current_target = attack_target
			entity.attack_timer += delta
			var cooldown: float = 1.0 / maxf(0.01, entity.attack_speed)
			if entity.attack_timer >= cooldown:
				entity.attack_timer = 0.0
				if is_ally and _try_cast_active_skill(entity, opponents, allies, events):
					return
				_do_attack(entity, attack_target, events)


func _try_cast_active_skill(caster: CombatEntity, opponents: Array, ally_list: Array, events: Array) -> bool:
	if caster.source_merc == null:
		return false
	for skill_id in caster.source_merc.active_skills:
		var sid: String = str(skill_id)
		if not caster.is_skill_ready(sid):
			continue
		if not SkillSystem.is_active_skill(sid):
			continue
		var skill_data: Dictionary = DataLoader.skill_template(sid)
		if skill_data.is_empty():
			continue
		if not _can_cast_skill_at_range(caster, skill_data, opponents, ally_list):
			continue
		if _execute_active_skill(caster, sid, opponents, ally_list, events):
			return true
	return false


func _can_cast_skill_at_range(caster: CombatEntity, skill_data: Dictionary, opponents: Array, ally_list: Array) -> bool:
	var effect_type: String = skill_data.get("effect_type", "")
	match effect_type:
		"heal_ally", "buff_self":
			return true
		"damage_magic", "damage_multi":
			var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
			return _find_nearest_in_range(opponents, caster.position, cast_range) != null
		_:
			return false


func _ally_retreat_march_tick(
	entity: CombatEntity,
	opponents: Array,
	ally_list: Array,
	delta: float,
	events: Array
) -> void:
	if entity.is_awakening():
		pass
	elif entity.is_downed() or (entity.source_merc != null and entity.source_merc.is_near_death):
		return
	_drift_homeward(entity, delta)
	if _try_cast_active_skill(entity, opponents, ally_list, events):
		return
	var attack_target: CombatEntity = _find_nearest_in_range(
		opponents, entity.position, entity.attack_range
	)
	if attack_target == null:
		entity.action_state = CombatEntity.ActionState.MOVING
		entity.current_target = null
		return
	entity.current_target = attack_target
	entity.action_state = CombatEntity.ActionState.ATTACKING
	entity.attack_timer += delta
	var cooldown: float = 1.0 / maxf(0.01, entity.attack_speed)
	if entity.attack_timer >= cooldown:
		entity.attack_timer = 0.0
		if _try_cast_active_skill(entity, opponents, ally_list, events):
			return
		_do_attack(entity, attack_target, events)


func _drift_homeward(entity: CombatEntity, delta: float) -> void:
	var step: float = entity.move_speed * delta
	entity.position = maxf(0.0, entity.position - step)
	entity.is_facing_right = false


func _move_toward_attack_range(entity: CombatEntity, target: CombatEntity, delta: float) -> void:
	var dist: float = abs(entity.position - target.position)
	if dist <= entity.attack_range:
		return
	var dir: float = 1.0 if target.position > entity.position else -1.0
	var ideal_pos: float = target.position - dir * entity.attack_range
	var step: float = entity.move_speed * delta
	if dir > 0.0:
		entity.position = minf(entity.position + step, ideal_pos)
	else:
		entity.position = maxf(entity.position - step, ideal_pos)
	entity.position = clampf(entity.position, 0.0, BATTLEFIELD_WIDTH)
	entity.is_facing_right = dir > 0.0


func _execute_active_skill(caster: CombatEntity, skill_id: String, opponents: Array, ally_list: Array, events: Array) -> bool:
	var skill_data: Dictionary = DataLoader.skill_template(skill_id)
	if skill_data.is_empty():
		return false
	var merc = caster.source_merc
	var skill_name: String = skill_data.get("name", skill_id)
	var effect_type: String = skill_data.get("effect_type", "")
	var log_text := ""
	var did_something := false
	
	match effect_type:
		"damage_magic":
			var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
			var target: CombatEntity = _find_nearest_in_range(opponents, caster.position, cast_range)
			if target == null:
				return false
			var power: int = int(SkillSystem.compute_active_power(skill_data, merc.level))
			var dmg: int = target.apply_direct_damage(int(caster.matk * 0.6) + power)
			log_text = "%s 对 %s 施放[%s] %d伤害" % [_entity_short_name(caster), _entity_short_name(target), skill_name, dmg]
			_append_skill_damage_events(caster, target, dmg, events, merc)
			did_something = true
		
		"damage_multi":
			var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
			var target: CombatEntity = _find_nearest_in_range(opponents, caster.position, cast_range)
			if target == null:
				return false
			var hits: int = int(skill_data.get("hits", 3))
			var scale: float = float(skill_data.get("power_scale", 0.45))
			var total: int = 0
			for _i in range(hits):
				if target.is_dead():
					break
				var hit_dmg: int = target.apply_direct_damage(maxi(1, int(caster.patk * scale)))
				total += hit_dmg
				_append_skill_damage_events(caster, target, hit_dmg, events, merc)
			log_text = "%s 施放[%s] 连击 %d× 共%d伤害" % [_entity_short_name(caster), skill_name, hits, total]
			did_something = total > 0
		
		"heal_ally":
			var ally_target: CombatEntity = _find_lowest_hp_ally(ally_list)
			if ally_target == null:
				return false
			var heal_power: int = int(SkillSystem.compute_active_power(skill_data, merc.level))
			var healed: int = ally_target.heal_amount(heal_power)
			log_text = "%s 施放[%s] 治疗 %s +%d HP" % [
				_entity_short_name(caster), skill_name, _entity_short_name(ally_target), healed
			]
			events.append({"type": "skill_heal", "caster": caster.entity_id, "target": ally_target.entity_id, "amount": healed})
			did_something = healed > 0
		
		"buff_self":
			var buff: Dictionary = skill_data.get("buff", {})
			var stat: String = buff.get("stat", "pdef")
			var value: float = float(buff.get("value", 5))
			var duration: float = float(buff.get("duration", 4.0))
			merc.buff_system.apply_buff(skill_id, stat, value, duration)
			caster.recalc_from_merc()
			log_text = "%s 施放[%s] %s+%.0f (%.0fs)" % [_entity_short_name(caster), skill_name, stat, value, duration]
			did_something = true
		
		_:
			return false
	
	if not did_something:
		return false
	
	caster.set_skill_cooldown(skill_id, SkillSystem.get_active_cooldown(skill_id))
	skill_cast.emit(caster.entity_id, skill_id, skill_name, log_text)
	events.append({
		"type": "skill_cast",
		"caster": caster.entity_id,
		"skill_id": skill_id,
		"text": log_text
	})
	return true


func _append_skill_damage_events(caster: CombatEntity, target: CombatEntity, dmg: int, events: Array, merc) -> void:
	if dmg <= 0:
		return
	_record_damage(caster, target, dmg)
	damage_dealt.emit(caster.entity_id, target.entity_id, dmg)
	events.append({
		"type": "damage",
		"attacker": caster.entity_id,
		"target": target.entity_id,
		"damage": dmg,
		"target_hp": target.current_hp
	})
	if merc:
		merc.run_damage_dealt += dmg
	if target.is_downed() and target.team == CombatEntity.Team.ALLY:
		_handle_ally_incapacitated(target)
	elif target.is_dead():
		events.append({"type": "death", "entity": target.entity_id, "team": target.team})
		_record_kill(caster)
		if merc:
			merc.run_kills += 1


func _find_lowest_hp_ally(ally_list: Array) -> CombatEntity:
	var best: CombatEntity = null
	var best_ratio := 2.0
	for e in ally_list:
		if e.is_dead():
			continue
		var r: float = e.hp_ratio()
		if r < best_ratio:
			best_ratio = r
			best = e
	return best


func _entity_short_name(entity: CombatEntity) -> String:
	if entity.source_merc:
		return entity.source_merc.merc_name
	return entity.entity_id


func _do_attack(attacker: CombatEntity, target: CombatEntity, events: Array) -> void:
	attack_started.emit(attacker.entity_id, target.entity_id)
	var dmg: int = attacker.deal_damage_to(target)
	_record_damage(attacker, target, dmg)
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
	
	if target.is_downed() and target.team == CombatEntity.Team.ALLY:
		_handle_ally_incapacitated(target)
	elif target.is_dead():
		events.append({
			"type": "death",
			"entity": target.entity_id,
			"team": target.team
		})
		_record_kill(attacker)
		if attacker.source_merc:
			attacker.source_merc.run_kills += 1


func _init_entity_stats(entity: CombatEntity) -> void:
	entity.combat_damage_dealt = 0
	entity.combat_damage_taken = 0
	entity.combat_kills = 0
	if entity.display_name == "":
		entity.display_name = entity.entity_id


func _record_damage(attacker: CombatEntity, target: CombatEntity, amount: int) -> void:
	if amount <= 0:
		return
	attacker.combat_damage_dealt += amount
	target.combat_damage_taken += amount
	if target.team == CombatEntity.Team.ALLY and _world_run != null:
		var shield_absorbed := false
		if _world_run.is_retreating:
			shield_absorbed = _world_run.on_retreat_ally_hit(amount)
		if not shield_absorbed and _world_run.stability != null:
			_world_run.stability.on_ally_hit(amount, target)


func _record_kill(attacker: CombatEntity) -> void:
	attacker.combat_kills += 1


func get_battle_stats_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("[color=yellow]—— 战斗统计 ——[/color]")
	var all: Array[CombatEntity] = []
	all.append_array(allies)
	all.append_array(enemies)
	all.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool:
		return a.combat_damage_dealt > b.combat_damage_dealt
	)
	for e in all:
		if e.combat_damage_dealt == 0 and e.combat_damage_taken == 0 and e.combat_kills == 0:
			continue
		lines.append("%s  %d dmg dealt  %d taken  %d kills" % [
			e.display_name, e.combat_damage_dealt, e.combat_damage_taken, e.combat_kills
		])
	if lines.size() == 1:
		lines.append("(无伤害记录)")
	return lines


func _find_nearest_alive(entities: Array, from_pos: float) -> CombatEntity:
	var best: CombatEntity = null
	var best_dist: float = INF
	for e in entities:
		if not e is CombatEntity:
			continue
		var unit: CombatEntity = e as CombatEntity
		if unit.is_dead():
			continue
		var d: float = abs(unit.position - from_pos)
		if d < best_dist:
			best_dist = d
			best = unit
	return best


func _find_nearest_in_range(entities: Array, from_pos: float, max_range: float) -> CombatEntity:
	var best: CombatEntity = null
	var best_dist: float = INF
	for e in entities:
		if not e is CombatEntity:
			continue
		var unit: CombatEntity = e as CombatEntity
		if unit.is_dead():
			continue
		var d: float = abs(unit.position - from_pos)
		if d <= max_range and d < best_dist:
			best_dist = d
			best = unit
	return best


func _count_alive(entities: Array) -> int:
	var c = 0
	for e in entities:
		if not e.is_dead():
			c += 1
	return c


func _count_fighting(entities: Array) -> int:
	var c = 0
	for e in entities:
		if e.can_fight():
			c += 1
	return c


func count_active_allies() -> int:
	return _count_fighting(allies)


func count_allies_on_field() -> int:
	return _count_allies_still_on_field()


func _handle_ally_incapacitated(target: CombatEntity) -> void:
	if target.source_merc and not target.source_merc.is_near_death:
		target.source_merc.enter_near_death_state(0.05)
	entity_dead.emit(target)


func _count_allies_still_on_field() -> int:
	var c := 0
	for e in allies:
		if not e.is_dead():
			c += 1
	return c


func _on_ally_death(entity_id: String) -> void:
	for e in allies:
		if e.entity_id == entity_id and e.source_merc:
			var merc: Mercenary = e.source_merc as Mercenary
			if not merc.is_near_death:
				merc.enter_near_death_state(0.05)
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
		if entity.is_downed() or entity.source_merc.is_near_death:
			continue
		entity.source_merc.current_hp = maxi(0, entity.current_hp)
		entity.source_merc.is_alive = true
