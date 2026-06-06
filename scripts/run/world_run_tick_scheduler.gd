class_name WorldRunTickScheduler
extends RefCounted
## WorldRun.tick 遇敌调度 — 刷怪/Boss 线委托 *Service，tick 本体只做行程与快照


static func collect_encounter_events(run: WorldRun, delta: float) -> Array:
	var events: Array = []
	if not run.chase_combat_in_progress:
		for ambush_data in run.consume_opening_spawns():
			events.append({"type": "enemy_spawn", "data": ambush_data})
	if run.is_retreating:
		events.append_array(RetreatSpawnService.tick_spawns(run, delta))
	else:
		events.append_array(AdvanceSpawnService.tick(run, delta))
	return events
