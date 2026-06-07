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
## T-02：远程前探时与最前近战的站位间隔（逻辑坐标）
const RANGED_MELEE_STANDOFF: float = 24.0
## 敌方远程相对 spawn 锚点最多前探
const ENEMY_RANGED_MAX_ADVANCE: float = 18.0
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
var _projectile_system: CombatProjectileSystem = null
var _skill_executor: CombatSkillExecutor = null
var _downed_execute_elapsed: float = 0.0
var _party_anchor_shift: float = 0.0


func _init() -> void:
	_rng.randomize()


func get_party_anchor_shift() -> float:
	return _party_anchor_shift


func init_combat(
	squad: Squad,
	enemy_data_list: Array,
	world_run: WorldRun,
	party_anchor_distance: float = -1.0
) -> void:
	_world_run = world_run
	_movement_policy = CombatMovementPolicy.AdvanceMovementPolicy.new()
	allies.clear()
	enemies.clear()
	var anchor_dist: float = party_anchor_distance
	if anchor_dist < 0.0:
		anchor_dist = world_run.distance_traveled if world_run != null else 0.0
	var max_dist: float = world_run.max_distance if world_run != null else BattlefieldSlots.BATTLEFIELD_WIDTH
	_party_anchor_shift = BattlefieldSlots.distance_to_anchor_shift(anchor_dist, max_dist)
	
	# 友方实体（含濒死 — 需可视化；濒死单位不攻击、不移动）
	# CQ 编队：远程后排（低 x）、近战前排（高 x）
	var battlefield: Array[Mercenary] = squad.get_battlefield_members()
	battlefield.sort_custom(_compare_battlefield_deploy_order)
	for i in range(battlefield.size()):
		var m: Mercenary = battlefield[i]
		# 返程/追击接战：保留濒死状态，避免倒地单位被当成可撤离战斗员
		if _world_run == null or not _world_run.is_retreating:
			m.try_clear_near_death_for_deploy()
		var e := CombatEntity.new()
		e.init_from_merc(m, "ally_")
		e.formation_slot = i
		e.position = BattlefieldSlots.ally_position_at_slot(i, _party_anchor_shift)
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
		e.position = BattlefieldSlots.enemy_position_at_slot(i, _party_anchor_shift)
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
	_projectile_system = CombatProjectileSystem.new(self)
	_skill_executor = CombatSkillExecutor.new(self, _projectile_system)
	_projectile_system.clear()
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
	_sync_pressure_downed_allies()
	
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
	
	if _projectile_system:
		_projectile_system.tick(delta, events)
	
	# 检查胜负
	var ally_alive = _count_fighting(allies)
	var enemy_alive = _count_alive(enemies)
	
	var result = {"status": "ongoing", "ally_alive": ally_alive, "enemy_alive": enemy_alive, "events": events}
	
	if _count_allies_still_on_field() == 0:
		is_active = false
		result.status = "defeat"
		combat_ended.emit(false)
	elif ally_alive == 0 or _should_force_chase_squad_execute_defeat():
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
			var attack_target: CombatEntity = find_nearest_in_range(
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
					entity.action_state = CombatEntity.ActionState.MOVING
					_advance_ranged_ally_toward_range(entity, move_target, delta)
				else:
					entity.action_state = CombatEntity.ActionState.MOVING
					_move_toward_attack_range(entity, move_target, delta)
				attack_target = find_nearest_in_range(
					opponents, entity.position, entity.attack_range, fighters_only
				)
			elif entity.is_ranged_unit() and is_ally:
				_hold_ranged_position(entity, delta)
			
			if attack_target:
				entity.action_state = CombatEntity.ActionState.ATTACKING
				entity.current_target = attack_target
			elif entity.is_ranged_unit():
				entity.action_state = CombatEntity.ActionState.IDLE
			else:
				entity.action_state = CombatEntity.ActionState.MOVING
		
		CombatEntity.ActionState.ATTACKING:
			if entity.is_ranged_unit() and is_ally:
				_hold_ranged_position(entity, delta)
			var attack_target: CombatEntity = find_nearest_in_range(
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
	if _skill_executor == null:
		return false
	return _skill_executor.try_cast_active_skill(caster, opponents, ally_list, events)


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
	if entity.is_dead():
		return
	if entity.is_downed():
		# 濒死：随队后撤（移速倍率见 _ally_retreat_speed_mult），不攻击
		_drift_homeward(entity, delta)
		return
	if entity.is_awakening():
		pass
	_drift_homeward(entity, delta)
	if _try_cast_active_skill(entity, opponents, ally_list, events):
		return
	var attack_target: CombatEntity = find_nearest_in_range(
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


func _opponent_target_fighters_only(is_attacker_ally: bool) -> bool:
	## T-02a：敌方在场上有可战友方时跳过 DOWNED；仅濒死剩场时才 fallback 打濒死
	if is_attacker_ally:
		return false
	return _any_ally_fighter_on_field()


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
	var chase_target: CombatEntity = _find_enemy_chase_move_target(allies, entity.position)
	if chase_target == null:
		entity.action_state = CombatEntity.ActionState.IDLE
		entity.current_target = null
		return
	_enemy_retreat_chase_step_toward(entity, chase_target, delta)
	var attack_target: CombatEntity = _find_enemy_attack_target(allies, entity.position, entity.attack_range)
	if attack_target == null:
		entity.action_state = CombatEntity.ActionState.MOVING
		entity.current_target = chase_target
		return
	entity.current_target = attack_target
	entity.action_state = CombatEntity.ActionState.ATTACKING
	entity.attack_timer += delta
	var cooldown: float = 1.0 / maxf(0.01, entity.attack_speed)
	if entity.attack_timer >= cooldown:
		entity.attack_timer = 0.0
		_do_attack(entity, attack_target, events)


## 返程/追击：向最近目标逼近至射程，避免盲向左冲越过友方导致永远打不到。
func _enemy_retreat_chase_step_toward(
	entity: CombatEntity, target: CombatEntity, delta: float
) -> void:
	var dist: float = abs(entity.position - target.position)
	if dist <= entity.attack_range + 0.01:
		entity.is_facing_right = target.position > entity.position
		return
	var dir: float = 1.0 if target.position > entity.position else -1.0
	var step: float = _enemy_chase_step(entity, delta)
	var ideal_pos: float = _melee_ideal_position(entity, target, dir)
	if dir > 0.0:
		entity.position = minf(entity.position + step, ideal_pos)
	else:
		entity.position = maxf(entity.position - step, ideal_pos)
	entity.position = clampf(entity.position, 0.0, BATTLEFIELD_WIDTH)
	entity.is_facing_right = target.position > entity.position


func _find_enemy_chase_move_target(ally_list: Array, from_pos: float) -> CombatEntity:
	return _find_nearest_alive(ally_list, from_pos, _any_ally_fighter_on_field())


## 近战接敌理想 X：前排贴射程；后排仅做细错位，且必须仍在 attack_range 内（1D 线战斗）。
func _melee_ideal_position(entity: CombatEntity, target: CombatEntity, dir: float) -> float:
	var contact: float = target.position - dir * entity.attack_range
	var depth: int = _melee_formation_depth(entity)
	if depth <= 0:
		return contact
	var row_gap: float = _melee_row_gap(entity)
	var ideal: float = contact - dir * float(depth) * row_gap
	if absf(target.position - ideal) > entity.attack_range + 0.01:
		return contact
	return ideal


static func _compare_battlefield_deploy_order(a: Mercenary, b: Mercenary) -> bool:
	var ra: float = StatResolver.get_attack_range(a)
	var rb: float = StatResolver.get_attack_range(b)
	var ranged_a: bool = ra >= CombatEntity.RANGED_ATTACK_THRESHOLD
	var ranged_b: bool = rb >= CombatEntity.RANGED_ATTACK_THRESHOLD
	if ranged_a != ranged_b:
		return ra > rb
	if ranged_a:
		return ra > rb
	var pa: int = StatResolver.get_pdef(a)
	var pb: int = StatResolver.get_pdef(b)
	if pa != pb:
		return pa < pb
	return ra < rb


func _melee_formation_depth(entity: CombatEntity) -> int:
	var depth: int = 0
	if entity.team == CombatEntity.Team.ALLY:
		for ally in allies:
			if ally == entity or not ally.can_fight() or ally.is_ranged_unit():
				continue
			if ally.formation_slot > entity.formation_slot:
				depth += 1
		return depth
	for foe in enemies:
		if foe == entity or not foe.can_fight() or foe.is_ranged_unit():
			continue
		if foe.formation_slot < entity.formation_slot:
			depth += 1
	return depth


func _melee_row_gap(entity: CombatEntity) -> float:
	var gap: float = ally_formation_gap if entity.team == CombatEntity.Team.ALLY else enemy_formation_gap
	return minf(gap, maxf(8.0, entity.attack_range * 0.35))


func _is_advance_lane_engagement() -> bool:
	return _movement_policy is CombatMovementPolicy.AdvanceMovementPolicy


func _set_entity_position_x(entity: CombatEntity, new_x: float) -> void:
	var x: float = clampf(new_x, 0.0, BATTLEFIELD_WIDTH)
	if entity.team == CombatEntity.Team.ENEMY and _is_advance_lane_engagement():
		x = minf(x, entity.position)
	entity.position = x


func _move_toward_attack_range(entity: CombatEntity, target: CombatEntity, delta: float) -> void:
	if entity.is_ranged_unit() and entity.team == CombatEntity.Team.ALLY:
		_advance_ranged_ally_toward_range(entity, target, delta)
		return
	var dist: float = abs(entity.position - target.position)
	if dist <= entity.attack_range:
		return
	var dir: float = 1.0 if target.position > entity.position else -1.0
	var ideal_pos: float = _melee_ideal_position(entity, target, dir)
	var step: float = entity.move_speed * delta
	if dir > 0.0:
		_set_entity_position_x(entity, minf(entity.position + step, ideal_pos))
	else:
		_set_entity_position_x(entity, maxf(entity.position - step, ideal_pos))
	entity.is_facing_right = dir > 0.0


## T-02 友方远程：前探至射程内，不越过最前近战；敌方仍守锚点带宽
func _foremost_fighting_melee_ally_x() -> float:
	var best: float = INF
	for ally in allies:
		if not ally.can_fight() or ally.is_ranged_unit():
			continue
		best = minf(best, ally.position)
	return best


func _ranged_forward_cap_x(entity: CombatEntity) -> float:
	var front_x: float = _foremost_fighting_melee_ally_x()
	var cap: float
	if front_x < INF:
		cap = front_x - RANGED_MELEE_STANDOFF
	else:
		cap = (
			BattlefieldSlots.ally_slot_x(mini(2, BattlefieldSlots.MAX_ALLY_SLOTS - 1))
			+ _party_anchor_shift
		)
	return maxf(entity.spawn_anchor_x, cap)


func _ranged_ideal_engagement_x(entity: CombatEntity, target: CombatEntity) -> float:
	if target == null:
		return entity.spawn_anchor_x
	var ideal: float = target.position - entity.attack_range
	return clampf(ideal, entity.spawn_anchor_x, _ranged_forward_cap_x(entity))


func _advance_ranged_ally_toward_range(
	entity: CombatEntity, target: CombatEntity, delta: float
) -> void:
	if target == null:
		_hold_ranged_position(entity, delta)
		return
	var ideal_x: float = _ranged_ideal_engagement_x(entity, target)
	var step: float = entity.move_speed * delta
	if entity.position < ideal_x - 0.5:
		entity.position = minf(entity.position + step, ideal_x)
	elif entity.position > ideal_x + 0.5:
		entity.position = maxf(entity.position - step, ideal_x)
	entity.position = clampf(
		entity.position, entity.spawn_anchor_x, _ranged_forward_cap_x(entity)
	)
	entity.is_facing_right = true


func _hold_ranged_position(entity: CombatEntity, delta: float) -> void:
	var step: float = entity.move_speed * delta
	if entity.team == CombatEntity.Team.ALLY:
		var cap_x: float = _ranged_forward_cap_x(entity)
		if entity.position > cap_x + 0.01:
			entity.position = maxf(cap_x, entity.position - step)
		entity.is_facing_right = true
		entity.position = clampf(entity.position, 0.0, BATTLEFIELD_WIDTH)
	else:
		var min_x: float = entity.spawn_anchor_x - ENEMY_RANGED_MAX_ADVANCE
		if entity.position < min_x:
			_set_entity_position_x(entity, minf(entity.spawn_anchor_x, entity.position + step))
		entity.is_facing_right = false


func emit_skill_cast(
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


func append_skill_damage_events(caster: CombatEntity, target: CombatEntity, dmg: int, events: Array, merc) -> void:
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


func find_lowest_hp_ally(ally_list: Array) -> CombatEntity:
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


func entity_short_name(entity: CombatEntity) -> String:
	if entity.source_merc:
		return entity.source_merc.merc_name
	return entity.entity_id


func _do_attack(attacker: CombatEntity, target: CombatEntity, events: Array) -> void:
	if attacker.is_ranged_unit():
		if _projectile_system:
			_projectile_system.fire_ranged_basic(attacker, target)
	else:
		_do_melee_attack(attacker, target, events)


func _do_melee_attack(attacker: CombatEntity, target: CombatEntity, events: Array) -> void:
	attack_started.emit(attacker.entity_id, target.entity_id, 0.0)
	apply_attack_hit(attacker, target, events)


func apply_attack_hit(attacker: CombatEntity, target: CombatEntity, events: Array) -> void:
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


func _should_force_chase_squad_execute_defeat() -> bool:
	if not _movement_policy.allows_downed_execute(self) or _world_run == null:
		return false
	var squad: Squad = _world_run.squad
	if squad == null or not squad.has_anyone_alive():
		return false
	return squad.get_combat_ready_count() == 0


func _any_ally_fighter_on_field() -> bool:
	for e in allies:
		if not e.is_dead() and e.can_fight():
			return true
	return false


## T-02a + 追击处决：有可战友方时优先打可战目标；仅濒死剩场时 fallback 打濒死。
func _find_enemy_attack_target(
	ally_list: Array, from_pos: float, max_range: float
) -> CombatEntity:
	return find_nearest_in_range(
		ally_list, from_pos, max_range, _any_ally_fighter_on_field()
	)


func find_nearest_in_range(
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
	var rear_x: float = ALLY_SPAWN_X + _party_anchor_shift
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
		downed.position = ALLY_SPAWN_X + _party_anchor_shift
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
	if target.source_merc and not TestScenarioService.test_merc_blocks_casualties(target.source_merc) and not target.source_merc.is_near_death:
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
			if not TestScenarioService.test_merc_blocks_casualties(merc) and not merc.is_near_death:
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
	if _projectile_system:
		_projectile_system.clear()
	is_active = false
	combat_ended.emit(false)


## 战斗结束后将存活友方实体的 HP 写回源 Mercenary（阵亡者由 on_death 已处理）
func _sync_pressure_downed_allies() -> void:
	for entity in allies:
		if entity.is_dead() or entity.is_downed():
			continue
		var merc: Mercenary = entity.source_merc as Mercenary
		if merc == null or merc.is_mia or not merc.is_near_death:
			continue
		entity.current_hp = maxi(1, int(float(entity.max_hp) * 0.05))
		entity.action_state = CombatEntity.ActionState.DOWNED


func eject_pressure_substitute(outgoing: Mercenary) -> bool:
	if outgoing == null:
		return false
	for entity in allies.duplicate():
		if entity.source_merc == outgoing:
			allies.erase(entity)
			return true
	return false


func deploy_pressure_substitute(incoming: Mercenary, preferred_slot: int = -1) -> bool:
	if incoming == null:
		return false
	for entity in allies:
		if entity.source_merc == incoming:
			return false
	var entity := CombatEntity.new()
	entity.init_from_merc(incoming, "ally_")
	var slot: int = preferred_slot
	if slot < 0:
		slot = 0
		for e in allies:
			slot = maxi(slot, e.formation_slot + 1)
	entity.formation_slot = maxi(0, slot)
	entity.position = BattlefieldSlots.ally_slot_x(entity.formation_slot)
	entity.spawn_anchor_x = entity.position
	entity.on_death.connect(_on_ally_death)
	allies.append(entity)
	_init_entity_stats(entity)
	BattleDebug.apply_entity_modifiers(entity)
	return true


func swap_pressure_substitute(outgoing: Mercenary, incoming: Mercenary) -> bool:
	if outgoing == null or incoming == null:
		return false
	var slot: int = -1
	var old_entity: CombatEntity = null
	for entity in allies:
		if entity.source_merc == outgoing:
			old_entity = entity
			slot = entity.formation_slot
			break
	if old_entity == null:
		return false
	allies.erase(old_entity)
	var entity := CombatEntity.new()
	entity.init_from_merc(incoming, "ally_")
	entity.formation_slot = maxi(0, slot)
	entity.position = BattlefieldSlots.ally_slot_x(entity.formation_slot)
	entity.spawn_anchor_x = entity.position
	entity.on_death.connect(_on_ally_death)
	allies.append(entity)
	_init_entity_stats(entity)
	BattleDebug.apply_entity_modifiers(entity)
	return true


func sync_allies_hp_to_mercs() -> void:
	for entity in allies:
		if entity.source_merc == null or entity.is_dead():
			continue
		var merc: Mercenary = entity.source_merc
		if TestScenarioService.test_merc_blocks_casualties(merc):
			merc.current_hp = merc.get_max_hp_value()
			merc.is_alive = true
			continue
		var floor_hp: int = 1 if entity.is_downed() or merc.is_near_death else 0
		merc.current_hp = maxi(floor_hp, entity.current_hp)
		merc.is_alive = true
		merc.clamp_hp_to_max()
		if entity.is_downed() and not TestScenarioService.test_merc_blocks_casualties(merc) and not merc.is_near_death:
			merc.enter_near_death_state(maxf(0.05, merc.get_hp_ratio()))
		elif not entity.is_downed() and not merc.is_near_death:
			merc.try_clear_near_death_for_deploy()
