class_name EncounterSession
extends RefCounted
## 单次接战会话 — 敌人表、移动策略、胜败分支


var kind: int = EncounterKind.MARCH_ADVANCE
var enemies: Array = []


static func infer_kind(enemy_list: Array, run: WorldRun) -> int:
	if enemy_list.is_empty():
		if run != null and run.is_retreating:
			return EncounterKind.MARCH_RETREAT
		return EncounterKind.MARCH_ADVANCE
	for e_data in enemy_list:
		if e_data.get("is_chase_encounter", false):
			return EncounterKind.CHASE_BOSS
		if e_data.get("is_extract_guard", false):
			return EncounterKind.EXTRACT_GUARD
	var has_lane_boss := false
	for e_data in enemy_list:
		if e_data.get("is_boss", false):
			has_lane_boss = true
			break
	if has_lane_boss and run != null and not run.is_retreating:
		return EncounterKind.BOSS_LANE
	if run != null and run.is_retreating:
		return EncounterKind.MARCH_RETREAT
	return EncounterKind.MARCH_ADVANCE


static func begin(kind: int, enemy_list: Array) -> EncounterSession:
	var session := EncounterSession.new()
	session.kind = kind
	session.enemies = enemy_list.duplicate()
	return session


func allows_pending_append() -> bool:
	return kind != EncounterKind.CHASE_BOSS


func movement_policy_for(_run: WorldRun) -> CombatMovementPolicy:
	match kind:
		EncounterKind.CHASE_BOSS:
			return CombatMovementPolicy.ChaseBossMovementPolicy.new()
		EncounterKind.MARCH_RETREAT:
			return CombatMovementPolicy.RetreatDriftMovementPolicy.new()
		_:
			return CombatMovementPolicy.AdvanceMovementPolicy.new()


func on_combat_begin(run: WorldRun) -> void:
	if kind == EncounterKind.CHASE_BOSS and run != null:
		run.chase_combat_in_progress = true


func on_combat_end(run: WorldRun) -> void:
	if kind == EncounterKind.CHASE_BOSS and run != null:
		run.chase_combat_in_progress = false


func is_chase_boss() -> bool:
	return kind == EncounterKind.CHASE_BOSS


func is_extract_guard() -> bool:
	return kind == EncounterKind.EXTRACT_GUARD


func is_boss_lane() -> bool:
	return kind == EncounterKind.BOSS_LANE


func primary_enemy() -> Dictionary:
	if enemies.is_empty():
		return {}
	return enemies[0]


func combat_fail_retreat_reason() -> String:
	for e_data in enemies:
		if e_data.get("is_boss", false) and not e_data.get("is_chase_encounter", false):
			return "combat_fail"
	return "emergency"


func resolve_victory(run: WorldRun) -> Dictionary:
	match kind:
		EncounterKind.EXTRACT_GUARD:
			return {
				"action": "end_run",
				"hint": "击退宝库守卫！直接结算…",
				"hint_color": Color.GREEN,
				"clear_extract_guard": true,
			}
		EncounterKind.CHASE_BOSS:
			if bool(run.map_data.get("chase_kill_continues_retreat", false)):
				return {
					"action": "chase_repel",
					"push_mult": float(run.map_data.get("chase_kill_repel_push_mult", 2.0)),
					"hint": "【测试图】击杀追击首领视为击退，继续返程…",
					"hint_color": Color.SKY_BLUE,
				}
			return {
				"action": "end_run",
				"hint": "击杀追击首领！本趟通关结算…",
				"hint_color": Color.GREEN,
				"register_chase_kill": true,
			}
		_:
			return {
				"action": "finish",
				"register_defeats": true,
				"store_resolved": true,
			}


func resolve_defeat(run: WorldRun) -> Dictionary:
	match kind:
		EncounterKind.EXTRACT_GUARD:
			return {
				"action": "emergency_retreat",
				"hint": "宝库守卫战失利！撤向撤离点…",
				"retreat_reason": "combat_fail",
				"clear_pending_guard": true,
			}
		EncounterKind.CHASE_BOSS:
			return {
				"action": "chase_defeat",
				"hint": "接战失利！稳定度大跌，首领仍在靠近",
				"hint_color": Color.ORANGE_RED,
			}
		_:
			var hint := "战斗失利，紧急撤离！"
			var reason := combat_fail_retreat_reason()
			if reason == "combat_fail":
				hint = "区域首领战失利！撤向撤离点…"
			elif run.squad != null and run.squad.has_any_member_near_death():
				hint = "队员濒死，紧急撤离！（返程移速减半）"
			return {
				"action": "emergency_retreat",
				"hint": hint,
				"retreat_reason": reason,
			}
