class_name RunModeService
extends RefCounted
## 出征 RunMode 入口桩 — NORMAL / RECOVERY / RESCUE（MIA 扩展点）


static func apply_for_departure(gm: GameManager, run: WorldRun) -> void:
	if run == null:
		return
	if gm != null and not gm.recovery_run_target_ids.is_empty():
		RecoveryRunService.apply(gm, run)
		return
	if gm != null and not gm.rescue_run_target_ids.is_empty():
		RescueRunService.apply(gm, run)
		return
	if gm != null and gm.is_recovery_lock_active():
		run.run_mode = WorldRun.RunMode.RECOVERY
		return
	run.run_mode = WorldRun.RunMode.NORMAL
