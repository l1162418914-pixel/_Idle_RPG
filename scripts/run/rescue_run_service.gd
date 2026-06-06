class_name RescueRunService
extends RefCounted
## 救援队避战出征（T-MIA-P4）：短程抵点、不接战、运尸入停尸间

const DEFAULT_RESCUE_DISTANCE: float = 96.0


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("rescue", {})


static func apply(gm: GameManager, run: WorldRun) -> void:
	if run == null or gm == null:
		return
	run.run_mode = WorldRun.RunMode.RESCUE
	run.rescue_target_ids.clear()
	for raw_id in gm.rescue_run_target_ids:
		run.rescue_target_ids.append(str(raw_id))
	run.map_data = run.map_data.duplicate(true)
	var dist: float = float(run.map_data.get("rescue_distance", config().get("distance", DEFAULT_RESCUE_DISTANCE)))
	run.map_data["rescue_distance"] = dist
	run.max_distance = dist
	run.map_data["disable_mob_spawns"] = true
	run.map_data["disable_boss_chase"] = true
	run.map_data["disable_stability_drain"] = true
	run.spawn_interval = 999.0
