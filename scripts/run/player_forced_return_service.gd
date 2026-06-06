class_name PlayerForcedReturnService
extends RefCounted
## 主角强制回城 B-3h/i — 永不 MIA；濒死护盾破后独自撤离，佣兵可留场


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("player_forced_return", {})


static func apply_combat_fall(
	run: WorldRun, player: Player, entity: CombatEntity = null
) -> Dictionary:
	if run == null or player == null:
		return {}
	if run.player_forced_return:
		return {"mercs_continue": mercs_continue_on_field(run), "solo": false, "already": true}
	run.player_forced_return = true
	player.is_alive = true
	player.is_mia = false
	var ratio: float = float(config().get("fall_hp_ratio", 0.05))
	if not player.is_near_death:
		player.enter_near_death_state(ratio)
	if run.squad != null and player in run.squad.members:
		run.squad.members.erase(player)
	var mercs_continue: bool = mercs_continue_on_field(run)
	if entity != null:
		entity.current_hp = 0
		entity.action_state = CombatEntity.ActionState.DEAD
	run.emit_signal(
		"run_event",
		"player_forced_return",
		{
			"mercs_continue": mercs_continue,
			"solo": not mercs_continue,
			"player_name": player.merc_name,
		}
	)
	return {"mercs_continue": mercs_continue, "solo": not mercs_continue}


static func mercs_continue_on_field(run: WorldRun) -> bool:
	if run == null or run.squad == null:
		return false
	for merc in run.squad.members:
		if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		if merc.is_alive and not merc.is_mia and not merc.is_retreated:
			return true
	return false


static func finalize_account_player(gm: GameManager, result: Dictionary) -> void:
	if gm == null or gm.player == null:
		return
	var p: Player = gm.player
	p.is_mia = false
	p.is_alive = true
	if bool(result.get("player_forced_return", false)):
		if not p.is_near_death:
			p.apply_near_death_state(float(config().get("fall_hp_ratio", 0.05)))
		result["player_alive"] = true
	elif not p.is_alive:
		p.is_alive = true
		p.apply_near_death_state(float(config().get("fall_hp_ratio", 0.05)))
		result["player_forced_return"] = true
		result["player_alive"] = true
