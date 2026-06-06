class_name CombatMovementPolicy
extends RefCounted
## 接战移动策略 — 从 CombatController 抽出的站位/行进差异


func tick_ally(
	host: CombatController,
	entity: CombatEntity,
	opponents: Array,
	ally_list: Array,
	delta: float,
	events: Array
) -> void:
	host.movement_tick_ally_advance(entity, opponents, delta, events)


func tick_enemy(
	host: CombatController,
	entity: CombatEntity,
	allies: Array,
	delta: float,
	events: Array
) -> void:
	host.movement_tick_enemy_advance(entity, allies, delta, events)


func allows_downed_execute(_host: CombatController) -> bool:
	return false


func uses_chase_pressure_slow() -> bool:
	return false


func uses_boss_pursuit_step() -> bool:
	return false


func uses_intense_chase_mult(host: CombatController) -> bool:
	return false


func reposition_downed_on_start() -> bool:
	return false


class AdvanceMovementPolicy extends CombatMovementPolicy:
	pass


class RetreatDriftMovementPolicy extends CombatMovementPolicy:
	func tick_ally(
		host: CombatController,
		entity: CombatEntity,
		opponents: Array,
		ally_list: Array,
		delta: float,
		events: Array
	) -> void:
		host.movement_tick_ally_retreat(entity, opponents, ally_list, delta, events)

	func tick_enemy(
		host: CombatController,
		entity: CombatEntity,
		allies: Array,
		delta: float,
		events: Array
	) -> void:
		host.movement_tick_enemy_retreat(entity, allies, delta, events)

	func allows_downed_execute(host: CombatController) -> bool:
		var run: WorldRun = host.get_world_run()
		if run == null:
			return false
		if not bool(run.map_data.get("chase_catch_executes_downed", false)):
			return false
		return host.count_allies_on_field() > 0

	func uses_intense_chase_mult(host: CombatController) -> bool:
		var run: WorldRun = host.get_world_run()
		return run != null and RetreatSpawnService.is_intense_chase(run)

	func reposition_downed_on_start() -> bool:
		return true


class ChaseBossMovementPolicy extends RetreatDriftMovementPolicy:
	func uses_chase_pressure_slow() -> bool:
		return true

	func uses_boss_pursuit_step() -> bool:
		return true

	func uses_intense_chase_mult(_host: CombatController) -> bool:
		return true
