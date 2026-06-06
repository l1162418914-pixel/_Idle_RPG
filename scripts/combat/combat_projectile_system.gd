class_name CombatProjectileSystem
extends RefCounted
## 战斗投射物飞行与命中结算（从 CombatController 迁出）


var _host: CombatController = null
var _projectiles: Array[Dictionary] = []


func _init(host: CombatController) -> void:
	_host = host


func clear() -> void:
	_projectiles.clear()


func tick(delta: float, events: Array) -> void:
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
		if _host == null or not _host.is_active:
			continue
		var kind: String = str(shot.get("kind", "ranged_basic"))
		match kind:
			"skill_magic":
				_apply_skill_magic_hit(attacker, target, shot, events)
			"skill_multi":
				_apply_skill_multi_hit(attacker, target, shot, events)
			_:
				_host.apply_attack_hit(attacker, target, events)


func fire_ranged_basic(attacker: CombatEntity, target: CombatEntity) -> void:
	if target.is_dead() or _host == null:
		return
	var dist: float = abs(attacker.position - target.position)
	var travel: float = clampf(
		dist / CombatController.PROJECTILE_SPEED,
		CombatController.PROJECTILE_MIN_TRAVEL,
		CombatController.PROJECTILE_MAX_TRAVEL
	)
	_host.attack_started.emit(attacker.entity_id, target.entity_id, travel)
	_projectiles.append({
		"kind": "ranged_basic",
		"attacker": attacker,
		"target": target,
		"time_left": travel,
	})


func fire_skill_magic(
	caster: CombatEntity,
	target: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	merc
) -> void:
	if target.is_dead() or _host == null:
		return
	var travel: float = _calc_travel(caster, target)
	_projectiles.append({
		"kind": "skill_magic",
		"attacker": caster,
		"target": target,
		"time_left": travel,
		"skill_id": skill_id,
		"skill_data": skill_data,
		"merc": merc,
	})
	_host.skill_projectile_launched.emit(
		caster.entity_id, target.entity_id, skill_id, skill_name, travel, "magic"
	)


func fire_skill_multi(
	caster: CombatEntity,
	target: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	hits: int,
	scale: float,
	merc
) -> void:
	if target.is_dead() or _host == null:
		return
	var base_travel: float = _calc_travel(caster, target)
	var hit_dmg: int = maxi(1, int(caster.patk * scale))
	for i in range(hits):
		var travel: float = base_travel + float(i) * CombatController.SKILL_MULTI_HIT_STAGGER
		_projectiles.append({
			"kind": "skill_multi",
			"attacker": caster,
			"target": target,
			"time_left": travel,
			"damage": hit_dmg,
			"merc": merc,
		})
		_host.skill_projectile_launched.emit(
			caster.entity_id, target.entity_id, skill_id, skill_name, travel, "arrow"
		)


func _calc_travel(attacker: CombatEntity, target: CombatEntity) -> float:
	var dist: float = abs(attacker.position - target.position)
	return clampf(
		dist / CombatController.PROJECTILE_SPEED,
		CombatController.PROJECTILE_MIN_TRAVEL,
		CombatController.PROJECTILE_MAX_TRAVEL
	)


func _apply_skill_magic_hit(attacker: CombatEntity, target: CombatEntity, shot: Dictionary, events: Array) -> void:
	if target.is_dead() or _host == null:
		return
	var skill_data: Dictionary = shot.get("skill_data", {})
	var merc = shot.get("merc")
	var level: int = merc.level if merc else 1
	var power: int = int(SkillSystem.compute_active_power(skill_data, level))
	var dmg: int = target.apply_direct_damage(int(attacker.matk * 0.6) + power)
	_host.append_skill_damage_events(attacker, target, dmg, events, merc)


func _apply_skill_multi_hit(attacker: CombatEntity, target: CombatEntity, shot: Dictionary, events: Array) -> void:
	if target.is_dead() or _host == null:
		return
	var dmg: int = int(shot.get("damage", 1))
	dmg = target.apply_direct_damage(dmg)
	_host.append_skill_damage_events(attacker, target, dmg, events, shot.get("merc"))
