class_name RunProbeLog
extends RefCounted
## F5 探针辅助日志 — 追加写入 user://run_probe.log（T-PROBE-LOG）
## 用于 test_03 等场验收 M1 探针 1/2/3，不改战斗数值与通过标准。

const LOG_PATH := "user://run_probe.log"
const CHASE_GAP_LOG_INTERVAL := 1.0
const DISTANCE_SAMPLE_INTERVAL := 2.0

static var _map_id: String = ""
static var _active_kind: int = -1
static var _encounter_index: int = 0
static var _last_encounter_end_ms: int = 0
static var _last_chase_gap_log: float = -999.0
static var _last_distance_sample: float = -999.0
static var _frozen_dist_value: float = -1.0
static var _last_logged_tick_dist: float = -1.0

static var _counts: Dictionary = {
	"spawn_blocked": 0,
	"encounter_begin": 0,
	"encounter_end": 0,
	"distance_frozen": 0,
	"distance_tick": 0,
	"spawn_blocked_chase": 0,
}


static func clear_on_run_start(map_id: String) -> void:
	_map_id = map_id
	_active_kind = -1
	_encounter_index = 0
	_last_encounter_end_ms = 0
	_last_chase_gap_log = -999.0
	_last_distance_sample = -999.0
	_frozen_dist_value = -1.0
	_last_logged_tick_dist = -1.0
	_counts = {
		"spawn_blocked": 0,
		"encounter_begin": 0,
		"encounter_end": 0,
		"distance_frozen": 0,
		"distance_tick": 0,
		"spawn_blocked_chase": 0,
	}
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_line(_line("RUN_START", {"map": map_id}))
		file.close()


static func log_spawn_blocked(reason: String, enemy_data: Dictionary = {}, encounter_kind: int = -1) -> void:
	_counts.spawn_blocked = int(_counts.spawn_blocked) + 1
	if _active_kind == EncounterKind.CHASE_BOSS:
		_counts.spawn_blocked_chase = int(_counts.spawn_blocked_chase) + 1
	var fields := {
		"reason": reason,
		"enemy": _enemy_tag(enemy_data),
		"enc": _kind_name(encounter_kind if encounter_kind >= 0 else _active_kind),
	}
	_write("SPAWN_BLOCKED", fields)


static func log_encounter_begin(kind: int, enemies: Array, distance: float) -> void:
	_encounter_index += 1
	_active_kind = kind
	_counts.encounter_begin = int(_counts.encounter_begin) + 1
	_frozen_dist_value = distance
	var tags: PackedStringArray = []
	for e in enemies:
		if e is Dictionary:
			tags.append(_enemy_tag(e))
	_write("ENCOUNTER_BEGIN", {
		"idx": _encounter_index,
		"kind": _kind_name(kind),
		"enemies": enemies.size(),
		"tags": ",".join(tags),
		"dist": _fmt(distance),
	})


static func log_encounter_end(kind: int, outcome: String = "", distance: float = -1.0) -> void:
	_counts.encounter_end = int(_counts.encounter_end) + 1
	var now_ms: int = Time.get_ticks_msec()
	var gap_since_end_ms: int = 0
	if _last_encounter_end_ms > 0:
		gap_since_end_ms = now_ms - _last_encounter_end_ms
	_last_encounter_end_ms = now_ms
	var fields := {
		"idx": _encounter_index,
		"kind": _kind_name(kind),
		"outcome": outcome if outcome != "" else "finish",
	}
	if distance >= 0.0:
		fields["dist"] = _fmt(distance)
	if gap_since_end_ms > 0 and int(_counts.encounter_end) > 1:
		fields["ms_since_prev_end"] = gap_since_end_ms
	_write("ENCOUNTER_END", fields)
	if kind == EncounterKind.CHASE_BOSS:
		_write_probe_hints()
	_active_kind = -1


static func log_distance_frozen(world_dist: float, display_dist: float, lane_state: String = "") -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_distance_sample < DISTANCE_SAMPLE_INTERVAL:
		return
	_last_distance_sample = now
	_counts.distance_frozen = int(_counts.distance_frozen) + 1
	_write("DISTANCE_FROZEN", {
		"world": _fmt(world_dist),
		"display": _fmt(display_dist),
		"lane": lane_state,
		"enc": _kind_name(_active_kind),
	})


static func log_distance_tick(distance: float, delta_dist: float = 0.0) -> void:
	if absf(distance - _last_logged_tick_dist) < 0.001:
		return
	_last_logged_tick_dist = distance
	_counts.distance_tick = int(_counts.distance_tick) + 1
	var fields := {"dist": _fmt(distance)}
	if absf(delta_dist) > 0.001:
		fields["delta"] = _fmt(delta_dist)
	_write("DISTANCE_TICK", fields)


static func log_chase_state(
	gap: float,
	counter_cd: float,
	chase_combat: bool,
	distance: float = -1.0
) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_chase_gap_log < CHASE_GAP_LOG_INTERVAL:
		return
	_last_chase_gap_log = now
	var fields := {
		"gap": _fmt(gap),
		"counter_cd": _fmt(counter_cd),
		"chase_combat": chase_combat,
	}
	if distance >= 0.0:
		fields["dist"] = _fmt(distance)
	_write("CHASE_STATE", fields)


static func log_run_end() -> void:
	_write("RUN_END", {
		"map": _map_id,
		"blocked": int(_counts.spawn_blocked),
		"blocked_chase": int(_counts.spawn_blocked_chase),
		"enc_beg": int(_counts.encounter_begin),
		"enc_end": int(_counts.encounter_end),
		"dist_frz": int(_counts.distance_frozen),
		"dist_tick": int(_counts.distance_tick),
	})
	_write_probe_hints()


static func get_summary_line() -> String:
	return (
		"PROBE blk=%d enc=%d/%d frz=%d tick=%d"
		% [
			int(_counts.spawn_blocked),
			int(_counts.encounter_end),
			int(_counts.encounter_begin),
			int(_counts.distance_frozen),
			int(_counts.distance_tick),
		]
	)


static func _write_probe_hints() -> void:
	var p1 := "UNKNOWN"
	if int(_counts.spawn_blocked_chase) > 0:
		p1 = "PASS"
	elif int(_counts.encounter_begin) > 0:
		p1 = "CHECK_LOG"
	var p2 := "CHECK_ENCOUNTER_END_GAP"
	if int(_counts.encounter_end) >= 1:
		p2 = "PASS_IF_ms_since_prev_end>500"
	var p3 := "UNKNOWN"
	if int(_counts.distance_frozen) > 0:
		p3 = "PASS"
	_write("PROBE_M1", {
		"p1_no_spawn_during_chase": p1,
		"p2_no_instant_refight": p2,
		"p3_distance_frozen": p3,
	})


static func _write(event: String, fields: Dictionary) -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(_line(event, fields))
	file.close()


static func _line(event: String, fields: Dictionary) -> String:
	var parts: PackedStringArray = [event]
	for key in fields.keys():
		parts.append("%s=%s" % [str(key), str(fields[key])])
	return " ".join(parts)


static func _fmt(v: float) -> String:
	return "%.1f" % v


static func _kind_name(kind: int) -> String:
	match kind:
		EncounterKind.MARCH_ADVANCE:
			return "MARCH_ADVANCE"
		EncounterKind.MARCH_RETREAT:
			return "MARCH_RETREAT"
		EncounterKind.CHASE_BOSS:
			return "CHASE_BOSS"
		EncounterKind.EXTRACT_GUARD:
			return "EXTRACT_GUARD"
		EncounterKind.BOSS_LANE:
			return "BOSS_LANE"
		_:
			return "NONE"


static func _enemy_tag(data: Dictionary) -> String:
	if data.is_empty():
		return "?"
	var boss := "B" if data.get("is_boss", false) else ""
	var chase := "C" if data.get("is_chase_encounter", false) else ""
	var id: String = str(data.get("enemy_id", data.get("template_id", "?")))
	return "%s%s:%s" % [boss, chase, id]
