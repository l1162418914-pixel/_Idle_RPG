class_name RecoveryRunService
extends RefCounted
## 回收出征（T-MIA-P2）：短里程 RECOVERY Run，低难、抵点即胜

const DEFAULT_RECOVERY_DISTANCE: float = 72.0
const UNFREEZE_RATIO: float = 0.25
const ENEMY_STAT_MULT: float = 0.55


static func apply(gm: GameManager, run: WorldRun) -> void:
	if run == null or gm == null:
		return
	run.run_mode = WorldRun.RunMode.RECOVERY
	run.recovery_target_ids.clear()
	for raw_id in gm.recovery_run_target_ids:
		run.recovery_target_ids.append(str(raw_id))
	run.map_data = run.map_data.duplicate(true)
	var dist: float = float(run.map_data.get("recovery_distance", DEFAULT_RECOVERY_DISTANCE))
	run.map_data["recovery_distance"] = dist
	run.max_distance = dist
	run.map_data["disable_mob_spawns"] = true
	run.map_data["disable_boss_chase"] = true
	run.map_data["enemy_stat_mult"] = float(run.map_data.get("enemy_stat_mult", 1.0)) * ENEMY_STAT_MULT
	run.spawn_interval = 999.0
