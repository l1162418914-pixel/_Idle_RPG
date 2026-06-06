class_name AdvanceSpawnService
extends RefCounted
## 进军阶段遇敌调度（Boss 线 + 小怪计时）


static func tick(run: WorldRun, delta: float) -> Array:
	var events: Array = []
	if run.is_retreating:
		return events
	if not run.boss_spawned and run.distance_traveled >= run.max_distance:
		if run.run_mode in [WorldRun.RunMode.RECOVERY, WorldRun.RunMode.RESCUE]:
			return events
		run.boss_spawned = true
		run.boss_zone_reached = true
		var boss_data: Dictionary = run.spawn_boss_lane()
		if not boss_data.is_empty():
			run.boss_encountered.emit(boss_data)
			events.append({"type": "boss", "data": boss_data})
			if (
				bool(run.map_data.get("auto_retreat_on_boss_spawn", false))
				and not run.is_retreating
			):
				run.emit_signal(
					"run_event",
					"test_auto_retreat",
					{"reason": "到达首领线，测试图自动返程以触发追击"}
				)
				run.begin_retreat("boss_auto")
	if run.boss_spawned or bool(run.map_data.get("disable_mob_spawns", false)):
		return events
	run.spawn_timer += delta
	var interval: float = run.spawn_interval * run.get_spawn_jitter()
	if run.spawn_timer >= interval:
		run.spawn_timer = 0.0
		var enemy_data: Dictionary = run.spawn_random_enemy()
		var ev: Dictionary = run.emit_enemy_spawn_event(enemy_data)
		if not ev.is_empty():
			events.append(ev)
	return events
