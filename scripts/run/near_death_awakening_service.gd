class_name NearDeathAwakeningService
extends RefCounted


static func reset_run_flags(run: WorldRun) -> void:
	if run == null or run.squad == null:
		return
	for m in run.squad.members:
		_reset_merc(m)
	for m in run.bench_reserves:
		_reset_merc(m)


static func try_trigger_on_downed(merc: Mercenary, entity: CombatEntity) -> bool:
	if merc == null or entity == null:
		return false
	if merc.run_awaken_used or merc.is_awakening:
		return false
	var cfg: Dictionary = _awakening_cfg()
	var chance: float = float(cfg.get("base_chance", 0.04))
	if GameManager.current_run != null and GameManager.current_run.map_data.has("awakening_chance"):
		chance = float(GameManager.current_run.map_data.awakening_chance)
	if randf() >= chance:
		return false
	var variant: Dictionary = _roll_variant(cfg)
	_start_awakening(merc, entity, cfg, variant)
	if GameManager.current_run != null:
		GameManager.current_run.emit_signal(
			"run_event",
			"awakening_started",
			{
				"name": merc.merc_name,
				"duration": merc.awakening_time_left,
				"variant": merc.awakening_variant_id,
			}
		)
	return true


static func tick_combat(entity: CombatEntity, delta: float) -> bool:
	if entity == null or not entity.is_awakening():
		return false
	entity.awakening_timer -= delta
	if entity.awakening_timer > 0.0:
		return true
	_end_awakening(entity)
	return false


static func _roll_variant(cfg: Dictionary) -> Dictionary:
	var variants: Array = cfg.get("variants", [])
	if variants.is_empty():
		return {"id": "damage_burst", "damage_mult": 1.75, "attack_speed_mult": 1.25}
	var total: int = 0
	for v in variants:
		total += int(v.get("weight", 1))
	if total <= 0:
		return variants[0]
	var roll: int = randi() % total
	var acc: int = 0
	for v in variants:
		acc += int(v.get("weight", 1))
		if roll < acc:
			return v
	return variants[0]


static func _start_awakening(
	merc: Mercenary, entity: CombatEntity, cfg: Dictionary, variant: Dictionary
) -> void:
	merc.run_awaken_used = true
	merc.is_awakening = true
	merc.awakening_variant_id = str(variant.get("id", "damage_burst"))
	merc.awakening_time_left = float(variant.get("duration_sec", cfg.get("duration_sec", 5.0)))
	entity.action_state = CombatEntity.ActionState.AWAKENING
	entity.awakening_timer = merc.awakening_time_left
	match merc.awakening_variant_id:
		"team_shield":
			_apply_team_shield_variant(variant)
			entity.current_hp = maxi(1, int(float(entity.max_hp) * 0.15))
		"taunt":
			var def_mult: float = float(variant.get("defense_mult", 1.6))
			entity.pdef = maxi(1, int(float(entity.pdef) * def_mult))
			entity.mdef = maxi(0, int(float(entity.mdef) * def_mult))
			var dmg: float = float(variant.get("damage_mult", 1.15))
			entity.patk = maxi(1, int(float(entity.patk) * dmg))
			entity.current_hp = maxi(1, int(float(entity.max_hp) * 0.12))
		"heal_snap":
			var heal_r: float = float(variant.get("heal_hp_ratio", 0.38))
			entity.current_hp = maxi(1, int(float(entity.max_hp) * heal_r))
		_:
			var dmg_mult: float = float(variant.get("damage_mult", cfg.get("damage_mult", 1.75)))
			var spd_mult: float = float(variant.get("attack_speed_mult", cfg.get("attack_speed_mult", 1.25)))
			entity.patk = maxi(1, int(float(entity.patk) * dmg_mult))
			entity.attack_speed *= spd_mult
			entity.current_hp = maxi(1, int(float(entity.max_hp) * 0.12))
	merc.current_hp = entity.current_hp
	merc.supported_by_id = ""


static func _apply_team_shield_variant(variant: Dictionary) -> void:
	var run: WorldRun = GameManager.current_run
	if run == null:
		return
	var ratio: float = float(variant.get("material_shield_ratio", 0.18))
	if run.is_retreating and run.material_shield_max > 0:
		var add: int = maxi(8, int(float(run.material_shield_max) * ratio))
		run.material_shield_current = mini(run.material_shield_max, run.material_shield_current + add)
		run.retreat_shield_current = run.equip_shield_current + run.material_shield_current
	else:
		run._pending_awakening_shield_bonus = maxi(
			run._pending_awakening_shield_bonus,
			int(40.0 * ratio * 5.0)
		)


static func _end_awakening(entity: CombatEntity) -> void:
	if entity.source_merc == null:
		return
	var merc: Mercenary = entity.source_merc
	merc.is_awakening = false
	merc.awakening_time_left = 0.0
	merc.awakening_variant_id = ""
	merc.enter_near_death_state(0.08)
	entity.recalc_from_merc()
	entity.current_hp = merc.current_hp
	entity.action_state = CombatEntity.ActionState.DOWNED


static func _reset_merc(merc: Mercenary) -> void:
	if merc == null:
		return
	merc.run_awaken_used = false
	merc.is_awakening = false
	merc.awakening_time_left = 0.0
	merc.awakening_variant_id = ""


static func _awakening_cfg() -> Dictionary:
	return DataLoader.near_death_config().get("awakening", {})
