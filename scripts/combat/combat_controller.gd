class_name CombatController
extends RefCounted
## CombatController — 实时横版自动战斗逻辑

signal combat_started()
signal combat_ended(victory: bool)
signal entity_dead(entity: CombatEntity)
signal attack_started(attacker: String, target: String, travel_time: float)
signal damage_dealt(attacker: String, target: String, damage: int)
signal skill_cast(caster_id: String, skill_id: String, skill_name: String, log_text: String)
signal skill_projectile_launched(
	caster_id: String,
	target_id: String,
	skill_id: String,
	skill_name: String,
	travel_time: float,
	style: String
)

const BATTLEFIELD_WIDTH: float = BattlefieldSlots.BATTLEFIELD_WIDTH
const ALLY_SPAWN_X: float = BattlefieldSlots.ALLY_SLOT_ORIGIN
const ENEMY_SPAWN_X: float = BattlefieldSlots.ENEMY_SLOT_ORIGIN
## 逻辑坐标内投射物飞行速度（米/秒）；伤害在命中时结算
const PROJECTILE_SPEED: float = 320.0
const PROJECTILE_MIN_TRAVEL: float = 0.08
const PROJECTILE_MAX_TRAVEL: float = 0.55
const SKILL_MULTI_HIT_STAGGER: float = 0.12
## 远程相对 spawn 锚点最多前探（近战无此限）
const RANGED_MAX_ADVANCE: float = 18.0
## 追击处决：全员失能后留给首领造成伤害再结算战败的宽限（秒）
const CHASE_DOWNED_EXECUTE_GRACE: float = 2.5

var allies: Array[CombatEntity] = []
var enemies: Array[CombatEntity] = []
var is_active: bool = false
var combat_time: float = 0.0
var ally_formation_gap: float = BattlefieldSlots.SLOT_GAP
var enemy_formation_gap: float = BattlefieldSlots.SLOT_GAP

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _world_run: WorldRun = null
var _movement_policy: CombatMovementPolicy = CombatMovementPolicy.AdvanceMovementPolicy.new()
var _projectiles: Array[Dictionary] = []
var _downed_execute_elapsed: float = 0.0


func _init() -> void:
	_rng.randomize()


func init_combat(squad: Squad, enemy_data_list: Array, world_run: WorldRun) -> void:
	_world_run = world_run
	_movement_policy = CombatMovementPolicy.AdvanceMovementPolicy.new()
	allies.clear()
	enemies.clear()
	
	# 友方实体（含濒死 — 需可视化；濒死单位不攻击、不移动）
	# CQ 编队：远程后排（低 x）、近战前排（高 x）
	var battlefield: Array[Mercenary] = squad.get_battlefield_members()
	battlefield.sort_custom(func(a: Mercenary, b: Mercenary) -> bool:
		return StatResolver.get_attack_range(a) > StatResolver.get_attack_range(b)
	)
	for i in range(battlefield.size()):
		var m: Mercenary = battlefield[i]
		m.try_clear_near_death_for_deploy()
		var e := CombatEntity.new()
		e.init_from_merc(m, "ally_")
		e.formation_slot = i
		e.position = BattlefieldSlots.ally_slot_x(i)
		e.spawn_anchor_x = e.position
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
		e.formation_slot = i
		e.position = BattlefieldSlots.enemy_slot_x(i)
		e.spawn_anchor_x = e.position
		e.on_death.connect(_on_enemy_death)
		enemies.append(e)
	
	for e in allies:
		_init_entity_stats(e)
		BattleDebug.apply_entity_modifiers(e)
	for e in enemies:
		_init_entity_stats(e)
		BattleDebug.apply_entity_modifiers(e)
	
	if _movement_policy.reposition_downed_on_start():
		_reposition_all_downed_allies()
	_projectiles.clear()
	_downed_execute_elapsed = 0.0
	
	is_active = true
	combat_time = 0.0
	combat_started.emit()


func get_world_run() -> WorldRun:
	return _world_run


func set_movement_policy(policy: CombatMovementPolicy) -> void:
	_movement_policy = policy if policy != null else CombatMovementPolicy.AdvanceMovementPolicy.new()


## 兼容旧 benchmark / 外部调用
func set_march_retreat_combat(enabled: bool) -> void:
	if enabled:
		set_movement_policy(CombatMovementPolicy.RetreatDriftMovementPolicy.new())
	else:
		set_movement_policy(CombatMovementPolicy.AdvanceMovementPolicy.new())
	if _movement_policy.reposition_downed_on_start():
		_reposition_all_downed_allies()


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
		_movement_policy.tick_ally(self, entity, enemies, allies, delta, events)
	
	for entity in enemies:
		_movement_policy.tick_enemy(self, entity, allies, delta, events)
	
	_tick_projectiles(delta, events)
	
	# 检查胜负
	var ally_alive = _count_fighting(allies)
	var enemy_alive = _count_alive(enemies)
	
	var result = {"status": "ongoing", "ally_alive": ally_alive, "enemy_alive": enemy_alive, "events": events}
	
	if _count_allies_still_on_field() == 0:
		is_active = false
		result.status = "defeat"
		combat_ended.emit(false)
	elif ally_alive == 0:
		if _movement_policy.allows_downed_execute(self):
			_downed_execute_elapsed += delta
			if _downed_execute_elapsed >= CHASE_DOWNED_EXECUTE_GRACE:
				is_active = false
				result.status = "defeat"
				combat_ended.emit(false)
		else:
			# 全员濒死/失能但仍留在场上 — 无法再战，结束战斗走战败/紧急撤离
			is_active = false
			result.status = "defeat"
			combat_ended.emit(false)
	else:
		_downed_execute_elapsed = 0.0
	
	if result.status == "ongoing" and enemy_alive == 0:
		is_active = false
		result.status = "victory"
		combat_ended.emit(true)
	
	return result


func _entity_tick(entity: CombatEntity, opponents: Array, delta: float, events: Array, is_ally: bool) -> void:
	if entity.is_incapacitated():
		return
	
	# 友方：射程外也可尝试施法（治疗/自保/远程技能）
	if is_ally and _try_cast_active_skill(entity, opponents, allies, events):
		return
	
	var fighters_only: bool = _opponent_target_fighters_only(is_ally)
	
	match entity.action_state:
		CombatEntity.ActionState.IDLE, CombatEntity.ActionState.MOVING:
			var attack_target: CombatEntity = _find_nearest_in_range(
				opponents, entity.position, entity.attack_range, fighters_only
			)
			var move_target: CombatEntity = _find_nearest_alive(opponents, entity.position, fighters_only)
			entity.current_target = attack_target if attack_target else move_target
			
			if move_target == null:
				entity.action_state = CombatEntity.ActionState.IDLE
				return
			
			var gap: float = abs(entity.position - move_target.position)
			if gap > entity.attack_range + 0.01:
				if entity.is_ranged_unit() and is_ally:
					entity.action_state = CombatEntity.ActionState.IDLE
					_hold_ranged_position(entity, delta)
				else:
					entity.action_state = CombatEntity.ActionState.MOVING
					_move_toward_attack_range(entity, move_target, delta)
				attack_target = _find_nearest_in_range(
					opponents, entity.position, entity.attack_range, fighters_only
				)
			elif entity.is_ranged_unit():
				_hold_ranged_position(entity, delta)
			
			if attack_target:
				entity.action_state = CombatEntity.ActionState.ATTACKING
				entity.current_target = attack_target
			elif entity.is_ranged_unit():
				entity.action_state = CombatEntity.ActionState.IDLE
			else:
				entity.action_state = CombatEntity.ActionState.MOVING
		
		CombatEntity.ActionState.ATTACKING:
			if entity.is_ranged_unit():
				_hold_ranged_position(entity, delta)
			var attack_target: CombatEntity = _find_nearest_in_range(
				opponents, entity.position, entity.attack_range, fighters_only
			)
			if attack_target == null:
				var move_target: CombatEntity = _find_nearest_alive(
					opponents, entity.position, fighters_only
				)
				if move_target == null:
					entity.action_state = CombatEntity.ActionState.IDLE
					return
				if entity.is_ranged_unit() and is_ally:
					entity.action_state = CombatEntity.ActionState.IDLE
				else:
					entity.action_state = CombatEntity.ActionState.MOVING
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


func movement_tick_ally_advance(
	entity: CombatEntity,
	opponents: Array,
	delta: float,
	events: Array
) -> void:
	_entity_tick(entity, opponents, delta, events, true)


func movement_tick_enemy_advance(
	entity: CombatEntity,
	allies: Array,
	delta: float,
	events: Array
) -> void:
	_entity_tick(entity, allies, delta, events, false)


func movement_tick_ally_retreat(
	entity: CombatEntity,
	opponents: Array,
	ally_list: Array,
	delta: float,
	events: Array
) -> void:
	if entity.is_awakening():
		pass
	elif entity.is_downed():
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
	var step: float = entity.move_speed * _ally_retreat_speed_mult() * delta
	entity.position = maxf(0.0, entity.position - step)
	entity.is_facing_right = false


func _opponent_target_fighters_only(is_ally: bool) -> bool:
	## 敌方需能打到濒死单位（追击处决/前排倒地）；友方仍只寻敌
	return false


func _ally_retreat_speed_mult() -> float:
	if _world_run == null:
		return 1.0
	if _movement_policy != null and _movement_policy.uses_chase_pressure_slow():
		return WorldRun.NEAR_DEATH_RETREAT_SPEED_MULT
	if _world_run.squad != null and _world_run.squad.has_any_member_near_death():
		return WorldRun.NEAR_DEATH_RETREAT_SPEED_MULT
	return 1.0


func _max_ally_retreat_speed() -> float:
	var peak: float = 0.0
	for entity in allies:
		if entity.is_incapacitated():
			continue
		peak = maxf(peak, entity.move_speed * _ally_retreat_speed_mult())
	return peak


func _enemy_chase_step(entity: CombatEntity, delta: float) -> float:
	var step: float = entity.move_speed * _get_retreat_chase_move_mult() * delta
	if entity.is_boss and _movement_policy != null and _movement_policy.uses_boss_pursuit_step():
		if _world_run != null:
			var map_move: float = float(_world_run.map_data.get("chase_boss_move_speed", 0.0))
			if map_move > 0.01:
				step = maxf(step, map_move * delta)
	var min_step: float = _max_ally_retreat_speed() * 1.18 * delta
	return maxf(step, min_step)


func _get_retreat_chase_move_mult() -> float:
	if _world_run == null:
		return 1.1
	if _movement_policy != null and _movement_policy.uses_intense_chase_mult(self):
		return float(_world_run.map_data.get("chase_enemy_move_speed_mult", 1.35))
	return 1.1


func movement_tick_enemy_retreat(
	entity: CombatEntity,
	allies: Array,
	delta: float,
	events: Array
) -> void:
	if entity.is_incapacitated():
		return
	var step: float = _enemy_chase_step(entity, delta)
	entity.position = maxf(0.0, entity.position - step)
	entity.is_facing_right = false
	var attack_target: CombatEntity = _find_nearest_in_range(
		allies, entity.position, entity.attack_range
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
		_do_attack(entity, attack_target, events)


## 近战接敌理想 X：前排贴射程，后排按 formation_slot 逐级后撤，避免共抢同一点。
func _melee_ideal_position(entity: CombatEntity, target: CombatEntity, dir: float) -> float:
	var contact: float = target.position - dir * entity.attack_range
	if entity.team == CombatEntity.Team.ALLY:
		var depth: int = 0
		for ally in allies:
			if ally == entity or not ally.can_fight() or ally.is_ranged_unit():
				continue
			if ally.formation_slot > entity.formation_slot:
				depth += 1
		return contact - dir * float(depth) * ally_formation_gap
	var depth_enemy: int = 0
	for foe in enemies:
		if foe == entity or not foe.can_fight() or foe.is_ranged_unit():
			continue
		if foe.formation_slot < entity.formation_slot:
			depth_enemy += 1
	return contact - dir * float(depth_enemy) * enemy_formation_gap


func _move_toward_attack_range(entity: CombatEntity, target: CombatEntity, delta: float) -> void:
	if entity.is_ranged_unit():
		_hold_ranged_position(entity, delta)
		return
	var dist: float = abs(entity.position - target.position)
	if dist <= entity.attack_range:
		return
	var dir: float = 1.0 if target.position > entity.position else -1.0
	var ideal_pos: float = _melee_ideal_position(entity, target, dir)
	var step: float = entity.move_speed * delta
	if dir > 0.0:
		entity.position = minf(entity.position + step, ideal_pos)
	else:
		entity.position = maxf(entity.position - step, ideal_pos)
	entity.position = clampf(entity.position, 0.0, BATTLEFIELD_WIDTH)
	entity.is_facing_right = dir > 0.0


## CQ 远程：守后排锚点，射程外不前压
func _hold_ranged_position(entity: CombatEntity, delta: float) -> void:
	var step: float = entity.move_speed * delta
	if entity.team == CombatEntity.Team.ALLY:
		var max_x: float = entity.spawn_anchor_x + RANGED_MAX_ADVANCE
		if entity.position > max_x:
			entity.position = maxf(entity.spawn_anchor_x, entity.position - step)
		entity.is_facing_right = true
	else:
		var min_x: float = entity.spawn_anchor_x - RANGED_MAX_ADVANCE
		if entity.position < min_x:
			entity.position = minf(entity.spawn_anchor_x, entity.position + step)
		entity.is_facing_right = false
	entity.position = clampf(entity.position, 0.0, BATTLEFIELD_WIDTH)


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
			return _cast_damage_magic_skill(caster, skill_id, skill_data, skill_name, opponents, events, merc)
		
		"damage_multi":
			return _cast_damage_multi_skill(caster, skill_id, skill_data, skill_name, opponents, events, merc)
		
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


func _cast_damage_magic_skill(
	caster: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	opponents: Array,
	events: Array,
	merc
) -> bool:
	var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
	var target: CombatEntity = _find_nearest_in_range(opponents, caster.position, cast_range)
	if target == null:
		return false
	caster.set_skill_cooldown(skill_id, SkillSystem.get_active_cooldown(skill_id))
	var log_text := "%s 施放[%s] → %s" % [
		_entity_short_name(caster), skill_name, _entity_short_name(target)
	]
	_emit_skill_cast(caster, skill_id, skill_name, log_text, events)
	_fire_skill_magic_projectile(caster, target, skill_id, skill_data, skill_name, merc)
	return true


func _cast_damage_multi_skill(
	caster: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	opponents: Array,
	events: Array,
	merc
) -> bool:
	var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
	var target: CombatEntity = _find_nearest_in_range(opponents, caster.position, cast_range)
	if target == null:
		return false
	var hits: int = maxi(1, int(skill_data.get("hits", 3)))
	var scale: float = float(skill_data.get("power_scale", 0.45))
	caster.set_skill_cooldown(skill_id, SkillSystem.get_active_cooldown(skill_id))
	var log_text := "%s 施放[%s] 连射 %d× → %s" % [
		_entity_short_name(caster), skill_name, hits, _entity_short_name(target)
	]
	_emit_skill_cast(caster, skill_id, skill_name, log_text, events)
	_fire_skill_multi_projectiles(caster, target, skill_id, skill_data, skill_name, hits, scale, merc)
	return true


func _emit_skill_cast(
	caster: CombatEntity,
	skill_id: String,
	skill_name: String,
	log_text: String,
	events: Array
) -> void:
	skill_cast.emit(caster.entity_id, skill_id, skill_name, log_text)
	events.append({
		"type": "skill_cast",
		"caster": caster.entity_id,
		"skill_id": skill_id,
		"text": log_text,
	})


func _calc_projectile_travel(attacker: CombatEntity, target: CombatEntity) -> float:
	var dist: float = abs(attacker.position - target.position)
	return clampf(dist / PROJECTILE_SPEED, PROJECTILE_MIN_TRAVEL, PROJECTILE_MAX_TRAVEL)


func _fire_skill_magic_projectile(
	caster: CombatEntity,
	target: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	merc
) -> void:
	if target.is_dead():
		return
	var travel: float = _calc_projectile_travel(caster, target)
	_projectiles.append({
		"kind": "skill_magic",
		"attacker": caster,
		"target": target,
		"time_left": travel,
		"skill_id": skill_id,
		"skill_data": skill_data,
		"merc": merc,
	})
	skill_projectile_launched.emit(
		caster.entity_id, target.entity_id, skill_id, skill_name, travel, "magic"
	)


func _fire_skill_multi_projectiles(
	caster: CombatEntity,
	target: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	hits: int,
	scale: float,
	merc
) -> void:
	if target.is_dead():
		return
	var base_travel: float = _calc_projectile_travel(caster, target)
	var hit_dmg: int = maxi(1, int(caster.patk * scale))
	for i in range(hits):
		var travel: float = base_travel + float(i) * SKILL_MULTI_HIT_STAGGER
		_projectiles.append({
			"kind": "skill_multi",
			"attacker": caster,
			"target": target,
			"time_left": travel,
			"damage": hit_dmg,
			"merc": merc,
		})
		skill_projectile_launched.emit(
			caster.entity_id, target.entity_id, skill_id, skill_name, travel, "arrow"
		)


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
		_reposition_downed_to_rear(target)
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
	if attacker.is_ranged_unit():
		_fire_projectile_attack(attacker, target)
	else:
		_do_melee_attack(attacker, target, events)


func _do_melee_attack(attacker: CombatEntity, target: CombatEntity, events: Array) -> void:
	attack_started.emit(attacker.entity_id, target.entity_id, 0.0)
	_apply_attack_hit(attacker, target, events)


func _fire_projectile_attack(attacker: CombatEntity, target: CombatEntity) -> void:
	if target.is_dead():
		return
	var dist: float = abs(attacker.position - target.position)
	var travel: float = clampf(
		dist / PROJECTILE_SPEED, PROJECTILE_MIN_TRAVEL, PROJECTILE_MAX_TRAVEL
	)
	attack_started.emit(attacker.entity_id, target.entity_id, travel)
	_projectiles.append({
		"kind": "ranged_basic",
		"attacker": attacker,
		"target": target,
		"time_left": travel,
	})


func _tick_projectiles(delta: float, events: Array) -> void:
	var i: int = 0
	while i < _projectiles.size():
		var shot: Dictionary = _projectiles[i]
		var attacker: CombatEntity = shot.get("attacker") as CombatEntity
		var target: CombatEntity = shot.get("target") as CombatEntity
		shot["time_left"] = float(shot.get("time_left", 0.0)) - delta
		if shot["time_left"] > 0.0:
			i += 1
			continue
		_projectiles.remove_at(i)
		if attacker == null or target == null or attacker.is_dead() or target.is_dead():
			continue
		if not is_active:
			continue
		var kind: String = str(shot.get("kind", "ranged_basic"))
		match kind:
			"skill_magic":
				_apply_skill_magic_hit(attacker, target, shot, events)
			"skill_multi":
				_apply_skill_multi_hit(attacker, target, shot, events)
			_:
				_apply_attack_hit(attacker, target, events)


func _apply_skill_magic_hit(attacker: CombatEntity, target: CombatEntity, shot: Dictionary, events: Array) -> void:
	if target.is_dead():
		return
	var skill_data: Dictionary = shot.get("skill_data", {})
	var merc = shot.get("merc")
	var level: int = merc.level if merc else 1
	var power: int = int(SkillSystem.compute_active_power(skill_data, level))
	var dmg: int = target.apply_direct_damage(int(attacker.matk * 0.6) + power)
	_append_skill_damage_events(attacker, target, dmg, events, merc)


func _apply_skill_multi_hit(attacker: CombatEntity, target: CombatEntity, shot: Dictionary, events: Array) -> void:
	if target.is_dead():
		return
	var dmg: int = int(shot.get("damage", 1))
	dmg = target.apply_direct_damage(dmg)
	_append_skill_damage_events(attacker, target, dmg, events, shot.get("merc"))


func _apply_attack_hit(attacker: CombatEntity, target: CombatEntity, events: Array) -> void:
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
	
	if attacker.source_merc:
		attacker.source_merc.run_damage_dealt += dmg
	
	if target.is_downed() and target.team == CombatEntity.Team.ALLY:
		_reposition_downed_to_rear(target)
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


func _find_nearest_alive(entities: Array, from_pos: float, fighters_only: bool = false) -> CombatEntity:
	var best: CombatEntity = null
	var best_dist: float = INF
	for e in entities:
		if not e is CombatEntity:
			continue
		var unit: CombatEntity = e as CombatEntity
		if unit.is_dead():
			continue
		if fighters_only and not unit.can_fight():
			continue
		var d: float = abs(unit.position - from_pos)
		if d < best_dist:
			best_dist = d
			best = unit
	return best


func _find_nearest_in_range(
	entities: Array, from_pos: float, max_range: float, fighters_only: bool = false
) -> CombatEntity:
	var best: CombatEntity = null
	var best_dist: float = INF
	for e in entities:
		if not e is CombatEntity:
			continue
		var unit: CombatEntity = e as CombatEntity
		if unit.is_dead():
			continue
		if fighters_only and not unit.can_fight():
			continue
		var d: float = abs(unit.position - from_pos)
		if d <= max_range and d < best_dist:
			best_dist = d
			best = unit
	return best


## 搀扶拖至后排：一次性 position 快照，非濒死自主移动
func _reposition_downed_to_rear(downed: CombatEntity) -> void:
	if downed.team != CombatEntity.Team.ALLY or not downed.is_downed():
		return
	var rear_x: float = ALLY_SPAWN_X
	var has_fighter := false
	for e in allies:
		if e.is_dead() or e == downed:
			continue
		if e.can_fight():
			has_fighter = true
			rear_x = minf(rear_x, e.position)
	if has_fighter:
		downed.position = maxf(0.0, rear_x - ally_formation_gap)
	else:
		downed.position = ALLY_SPAWN_X
	downed.is_facing_right = false


func _reposition_all_downed_allies() -> void:
	for e in allies:
		if e.is_downed():
			_reposition_downed_to_rear(e)


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
	_projectiles.clear()
	is_active = false
	combat_ended.emit(false)


## 战斗结束后将存活友方实体的 HP 写回源 Mercenary（阵亡者由 on_death 已处理）
func sync_allies_hp_to_mercs() -> void:
	for entity in allies:
		if entity.source_merc == null or entity.is_dead():
			continue
		var merc: Mercenary = entity.source_merc
		var floor_hp: int = 1 if entity.is_downed() or merc.is_near_death else 0
		merc.current_hp = maxi(floor_hp, entity.current_hp)
		merc.is_alive = true
		merc.clamp_hp_to_max()
		if entity.is_downed() and not merc.is_near_death:
			merc.enter_near_death_state(maxf(0.05, merc.get_hp_ratio()))
		elif not entity.is_downed() and not merc.is_near_death:
			merc.try_clear_near_death_for_deploy()
