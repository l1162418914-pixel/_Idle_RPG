class_name CombatSkillExecutor
extends RefCounted
## 主动技能施放（从 CombatController 迁出）


var _host: CombatController = null
var _projectiles: CombatProjectileSystem = null


func _init(host: CombatController, projectiles: CombatProjectileSystem) -> void:
	_host = host
	_projectiles = projectiles


func try_cast_active_skill(
	caster: CombatEntity,
	opponents: Array,
	ally_list: Array,
	events: Array,
	allow_buff_self: bool = true
) -> bool:
	if caster.source_merc == null or _host == null:
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
		if not allow_buff_self and skill_data.get("effect_type", "") == "buff_self":
			continue
		if not _can_cast_at_range(caster, skill_data, opponents, ally_list):
			continue
		if execute_active_skill(caster, sid, opponents, ally_list, events):
			return true
	return false


func _can_cast_at_range(
	caster: CombatEntity,
	skill_data: Dictionary,
	opponents: Array,
	ally_list: Array
) -> bool:
	var effect_type: String = skill_data.get("effect_type", "")
	match effect_type:
		"heal_ally", "buff_self":
			return true
		"damage_magic", "damage_multi":
			var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
			return _host.find_nearest_in_range(opponents, caster.position, cast_range) != null
		_:
			return false


func execute_active_skill(
	caster: CombatEntity,
	skill_id: String,
	opponents: Array,
	ally_list: Array,
	events: Array
) -> bool:
	var skill_data: Dictionary = DataLoader.skill_template(skill_id)
	if skill_data.is_empty() or _host == null:
		return false
	var merc = caster.source_merc
	var skill_name: String = skill_data.get("name", skill_id)
	var effect_type: String = skill_data.get("effect_type", "")
	var log_text := ""
	var did_something := false
	match effect_type:
		"damage_magic":
			return _cast_damage_magic(caster, skill_id, skill_data, skill_name, opponents, events, merc)
		"damage_multi":
			return _cast_damage_multi(caster, skill_id, skill_data, skill_name, opponents, events, merc)
		"heal_ally":
			var ally_target: CombatEntity = _host.find_lowest_hp_ally(ally_list)
			if ally_target == null:
				return false
			var heal_power: int = int(SkillSystem.compute_active_power(skill_data, merc.level))
			var healed: int = ally_target.heal_amount(heal_power)
			log_text = "%s 施放[%s] 治疗 %s +%d HP" % [
				_host.entity_short_name(caster), skill_name, _host.entity_short_name(ally_target), healed
			]
			events.append({
				"type": "skill_heal",
				"caster": caster.entity_id,
				"target": ally_target.entity_id,
				"amount": healed,
			})
			did_something = healed > 0
		"buff_self":
			var buff: Dictionary = skill_data.get("buff", {})
			var stat: String = buff.get("stat", "pdef")
			var value: float = float(buff.get("value", 5))
			var duration: float = float(buff.get("duration", 4.0))
			merc.buff_system.apply_buff(skill_id, stat, value, duration)
			caster.recalc_from_merc()
			log_text = "%s 施放[%s] %s+%.0f (%.0fs)" % [
				_host.entity_short_name(caster), skill_name, stat, value, duration
			]
			did_something = true
		_:
			return false
	if not did_something:
		return false
	caster.set_skill_cooldown(skill_id, SkillSystem.get_active_cooldown(skill_id))
	_host.emit_skill_cast(caster, skill_id, skill_name, log_text, events)
	return true


func _cast_damage_magic(
	caster: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	opponents: Array,
	events: Array,
	merc
) -> bool:
	var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
	var target: CombatEntity = _host.find_nearest_in_range(opponents, caster.position, cast_range)
	if target == null or _projectiles == null:
		return false
	caster.set_skill_cooldown(skill_id, SkillSystem.get_active_cooldown(skill_id))
	var log_text := "%s 施放[%s] → %s" % [
		_host.entity_short_name(caster), skill_name, _host.entity_short_name(target)
	]
	_host.emit_skill_cast(caster, skill_id, skill_name, log_text, events)
	_projectiles.fire_skill_magic(caster, target, skill_id, skill_data, skill_name, merc)
	return true


func _cast_damage_multi(
	caster: CombatEntity,
	skill_id: String,
	skill_data: Dictionary,
	skill_name: String,
	opponents: Array,
	events: Array,
	merc
) -> bool:
	var cast_range: float = SkillSystem.get_skill_cast_range(skill_data, caster.attack_range)
	var target: CombatEntity = _host.find_nearest_in_range(opponents, caster.position, cast_range)
	if target == null or _projectiles == null:
		return false
	var hits: int = maxi(1, int(skill_data.get("hits", 3)))
	var scale: float = float(skill_data.get("power_scale", 0.45))
	caster.set_skill_cooldown(skill_id, SkillSystem.get_active_cooldown(skill_id))
	var log_text := "%s 施放[%s] 连射 %d× → %s" % [
		_host.entity_short_name(caster), skill_name, hits, _host.entity_short_name(target)
	]
	_host.emit_skill_cast(caster, skill_id, skill_name, log_text, events)
	_projectiles.fire_skill_multi(caster, target, skill_id, skill_data, skill_name, hits, scale, merc)
	return true
