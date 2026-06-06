class_name SquadFormationService
extends RefCounted
## 双半组 4+2：基地换班、自动补员、养伤锁

const HALF_A := "A"
const HALF_B := "B"
const MAX_ACTIVE := 4
const MAX_BENCH := 2


static func ensure_formation(gm: Node) -> void:
	if gm == null or not gm is GameManager:
		return
	if gm.squad_formation.is_empty():
		gm.squad_formation = _default_formation()
		rebalance_from_roster(gm)
	_strip_player_from_halves(gm)
	for half in [HALF_A, HALF_B]:
		_refresh_half_slots(gm, half)
	_purge_mia_and_dead_from_halves(gm)


static func _merc_in_formation_pool(m: Mercenary) -> bool:
	return m != null and m.is_alive and not m.is_mia


static func _purge_mia_and_dead_from_halves(gm: GameManager) -> void:
	if gm == null:
		return
	for half in [HALF_A, HALF_B]:
		var active: Array[String] = get_active_ids(gm.squad_formation, half)
		var bench: Array[String] = get_bench_ids(gm.squad_formation, half)
		var kept_active: Array[String] = []
		var kept_bench: Array[String] = []
		for mid in active:
			if _merc_in_formation_pool(gm.find_mercenary_by_id(mid)):
				kept_active.append(mid)
		for mid in bench:
			if _merc_in_formation_pool(gm.find_mercenary_by_id(mid)):
				kept_bench.append(mid)
		gm.squad_formation[half] = {"active": kept_active, "bench": kept_bench}


static func rebalance_from_roster(gm: GameManager) -> void:
	ensure_formation(gm)
	var all_ids: Array[String] = _merc_roster_ids(gm)
	var in_a: Array[String] = _half_all_ids(gm.squad_formation, HALF_A)
	var in_b: Array[String] = _half_all_ids(gm.squad_formation, HALF_B)
	for mid in all_ids:
		var m := gm.find_mercenary_by_id(mid)
		if not _merc_in_formation_pool(m) or not _merc_deploy_ready(m):
			continue
		if mid in in_a or mid in in_b:
			continue
		if _half_active_count(gm.squad_formation, HALF_A) < MAX_ACTIVE:
			_add_to_active(gm.squad_formation, HALF_A, mid)
		elif _half_active_count(gm.squad_formation, HALF_B) < MAX_ACTIVE:
			_add_to_active(gm.squad_formation, HALF_B, mid)
		elif _half_bench_count(gm.squad_formation, HALF_B) < MAX_BENCH:
			_add_to_bench(gm.squad_formation, HALF_B, mid)
		elif _half_bench_count(gm.squad_formation, HALF_A) < MAX_BENCH:
			_add_to_bench(gm.squad_formation, HALF_A, mid)


static func pick_deploy_half(gm: GameManager) -> String:
	ensure_formation(gm)
	if half_can_deploy(gm, HALF_A):
		gm.squad_formation["active_half"] = HALF_A
		return HALF_A
	if half_can_deploy(gm, HALF_B):
		gm.squad_formation["active_half"] = HALF_B
		return HALF_B
	return ""


static func half_can_deploy(gm: GameManager, half: String) -> bool:
	if gm == null:
		return false
	return _count_deployable_in_half(gm, half) >= 1


static func is_recovery_lock_active(gm: GameManager) -> bool:
	ensure_formation(gm)
	return not half_can_deploy(gm, HALF_A) and not half_can_deploy(gm, HALF_B)


static func apply_default_deploy(gm: GameManager) -> void:
	ensure_formation(gm)
	var half := pick_deploy_half(gm)
	if half == "":
		gm.selected_squad.clear()
		return
	auto_fill_half(gm, half)
	gm.selected_squad = resolve_active_squad(gm, half)


static func rebuild_auto_squad(gm: GameManager) -> void:
	ensure_formation(gm)
	var half: String = str(gm.last_deploy_half)
	if half == "" or not half_can_deploy(gm, half):
		half = pick_deploy_half(gm)
	if half == "":
		gm.selected_squad.clear()
		return
	if not gm.last_run_squad_snapshot.is_empty():
		_restore_snapshot_to_half(gm, half, gm.last_run_squad_snapshot)
	auto_fill_half(gm, half)
	gm.selected_squad = resolve_active_squad(gm, half)
	gm.squad_formation["active_half"] = half


static func save_run_snapshot(gm: GameManager, result: Dictionary) -> void:
	gm.last_run_squad_snapshot.clear()
	for mid in result.get("squad_member_ids", []):
		gm.last_run_squad_snapshot.append(str(mid))
	gm.last_deploy_half = str(gm.squad_formation.get("active_half", HALF_A))


static func resolve_active_squad(gm: GameManager, half: String) -> Array[Mercenary]:
	var list: Array[Mercenary] = []
	for mid in get_active_ids(gm.squad_formation, half):
		if _is_player_id(gm, mid):
			continue
		var m := gm.find_mercenary_by_id(mid)
		if m != null and not (m is Player) and m.can_join_squad():
			list.append(m)
	return list


static func auto_fill_half(gm: GameManager, half: String) -> void:
	_refresh_half_slots(gm, half)
	var other: String = HALF_B if half == HALF_A else HALF_A
	var active: Array[String] = get_active_ids(gm.squad_formation, half)
	var bench: Array[String] = get_bench_ids(gm.squad_formation, half)
	active = _trim_slots(active, MAX_ACTIVE)
	bench = _trim_slots(bench, MAX_BENCH)
	var promote_scan := 0
	while active.size() < MAX_ACTIVE and promote_scan < bench.size():
		var promote_id: String = bench[promote_scan]
		if _merc_deploy_ready(gm.find_mercenary_by_id(promote_id)):
			active.append(promote_id)
			bench.remove_at(promote_scan)
		else:
			promote_scan += 1
	for mid in _merc_roster_ids(gm):
		if mid in active or mid in bench:
			continue
		if mid in _half_all_ids(gm.squad_formation, other):
			continue
		var m := gm.find_mercenary_by_id(mid)
		if not _merc_in_formation_pool(m) or not _merc_deploy_ready(m):
			continue
		if active.size() < MAX_ACTIVE:
			active.append(mid)
		elif bench.size() < MAX_BENCH:
			bench.append(mid)
	gm.squad_formation[half] = {"active": active, "bench": bench}


static func get_active_ids(formation: Dictionary, half: String) -> Array[String]:
	if not formation.has(half):
		return []
	var part: Dictionary = formation[half]
	var raw: Array = part.get("active", [])
	var out: Array[String] = []
	for id in raw:
		out.append(str(id))
	return out


static func get_bench_ids(formation: Dictionary, half: String) -> Array[String]:
	if not formation.has(half):
		return []
	var part: Dictionary = formation[half]
	var raw: Array = part.get("bench", [])
	var out: Array[String] = []
	for id in raw:
		out.append(str(id))
	return out


static func has_living_merc_roster(gm: GameManager) -> bool:
	if gm == null:
		return false
	for e in gm.elite_roster:
		if e.is_alive:
			return true
	for n in gm.normal_roster:
		if n.is_alive:
			return true
	return false


static func get_recovery_lock_message(gm: GameManager) -> String:
	if not has_living_merc_roster(gm):
		return "无法出征：请先在兵营招募至少 1 名佣兵，并在双半组编入出战位"
	return "全队养伤锁：两半组均无法出征，请在大营恢复至 70% 并清濒死"


static func get_formation_summary(gm: GameManager) -> String:
	ensure_formation(gm)
	var a_ok := half_can_deploy(gm, HALF_A)
	var b_ok := half_can_deploy(gm, HALF_B)
	var lock := is_recovery_lock_active(gm)
	if lock:
		return get_recovery_lock_message(gm)
	var half: String = str(gm.squad_formation.get("active_half", HALF_A))
	return "半组 %s 优先 | A:%s B:%s | 主角留营" % [
		half,
		"可出战" if a_ok else "休整",
		"可出战" if b_ok else "休整",
	]


static func load_bench_reserves(gm: GameManager, half: String) -> Array[Mercenary]:
	var list: Array[Mercenary] = []
	ensure_formation(gm)
	for mid in get_bench_ids(gm.squad_formation, half):
		if _is_player_id(gm, mid):
			continue
		var m := gm.find_mercenary_by_id(mid)
		if m != null and m.can_join_squad() and not (m is Player):
			list.append(m)
	return list


## 组内替补：出战位不足或双人濒死时从本半组替补席补人（仅出征中、战间）
static func try_bench_reinforcements(run: WorldRun) -> Array[String]:
	var added: Array[String] = []
	if run == null or run.squad == null or run.bench_reserves.is_empty():
		return added
	var field_count: int = run.squad.get_battlefield_members().size()
	var near_n: int = run.squad.count_near_death_on_field()
	# 场上已满员（含濒死）时不替补，避免全队濒死时无限补员
	var need: bool = field_count < MAX_ACTIVE or near_n >= 2
	if not need:
		return added
	while field_count < MAX_ACTIVE and run.squad.members.size() < MAX_ACTIVE and not run.bench_reserves.is_empty():
		var pick: Mercenary = null
		for i in range(run.bench_reserves.size()):
			var cand: Mercenary = run.bench_reserves[i]
			if cand != null and not (cand is Player) and cand.can_join_squad():
				pick = cand
				run.bench_reserves.remove_at(i)
				break
		if pick == null:
			break
		if pick in run.squad.members:
			continue
		run.squad.members.append(pick)
		added.append(pick.merc_name)
		field_count += 1
	return added


static func heal_priority_mercs(gm: GameManager) -> Array[Mercenary]:
	ensure_formation(gm)
	var ordered: Array[Mercenary] = []
	var half: String = HALF_A
	if not half_can_deploy(gm, HALF_A) and half_can_deploy(gm, HALF_B):
		half = HALF_B
	for mid in get_active_ids(gm.squad_formation, half):
		var m := gm.find_mercenary_by_id(mid)
		if m != null:
			ordered.append(m)
	for mid in get_bench_ids(gm.squad_formation, half):
		var m := gm.find_mercenary_by_id(mid)
		if m != null and m not in ordered:
			ordered.append(m)
	for m in gm._all_roster_mercs():
		if m != null and m.is_mia:
			continue
		if m not in ordered:
			ordered.append(m)
	return ordered


static func _restore_snapshot_to_half(gm: GameManager, half: String, snapshot: Array[String]) -> void:
	var active: Array[String] = []
	var bench: Array[String] = []
	for mid in snapshot:
		var s: String = str(mid)
		if _is_player_id(gm, s):
			continue
		if active.size() < MAX_ACTIVE:
			active.append(s)
		elif bench.size() < MAX_BENCH:
			bench.append(s)
	gm.squad_formation[half] = {"active": active, "bench": bench}


static func _default_formation() -> Dictionary:
	return {
		"active_half": HALF_A,
		HALF_A: {"active": [], "bench": []},
		HALF_B: {"active": [], "bench": []},
	}


static func _is_player_id(gm: GameManager, merc_id: String) -> bool:
	return gm != null and gm.player != null and merc_id == gm.player.merc_id


static func _count_deployable_in_half(gm: GameManager, half: String) -> int:
	var ready := 0
	for mid in get_active_ids(gm.squad_formation, half):
		ready += _deployable_merc_slot(gm, mid)
	for mid in get_bench_ids(gm.squad_formation, half):
		ready += _deployable_merc_slot(gm, mid)
	return ready


static func _merc_deploy_ready(m: Mercenary) -> bool:
	if m == null or not m.is_alive:
		return false
	if m.is_test_stand_in:
		return (
			m.is_alive
			and not m.is_mia
			and not m.is_retreated
			and not m.is_personal_break
			and m.is_personal_stability_ok()
		)
	m.try_clear_near_death_for_deploy()
	if m.is_mia or m.is_near_death or m.is_retreated or m.is_personal_break:
		return false
	if not m.is_personal_stability_ok():
		return false
	return m.get_hp_ratio() >= RosterHealth.DEPLOY_HP_RATIO


static func _deployable_merc_slot(gm: GameManager, merc_id: String) -> int:
	if _is_player_id(gm, merc_id):
		return 0
	var m := gm.find_mercenary_by_id(merc_id)
	if m != null and not (m is Player) and m.can_join_squad():
		return 1
	return 0


## 阵亡移出槽位；不可出战但存活下沉替补；替补满血补进出战位
static func _refresh_half_slots(gm: GameManager, half: String) -> void:
	if gm == null:
		return
	var active: Array[String] = get_active_ids(gm.squad_formation, half)
	var bench: Array[String] = get_bench_ids(gm.squad_formation, half)
	var ready_active: Array[String] = []
	var stalled_active: Array[String] = []
	var new_bench: Array[String] = []
	for mid in active:
		if _is_player_id(gm, mid):
			continue
		var m := gm.find_mercenary_by_id(mid)
		if not _merc_in_formation_pool(m):
			continue
		if _merc_deploy_ready(m):
			ready_active.append(mid)
		else:
			stalled_active.append(mid)
	for mid in bench:
		if _is_player_id(gm, mid):
			continue
		var m := gm.find_mercenary_by_id(mid)
		if not _merc_in_formation_pool(m):
			continue
		new_bench.append(mid)
	for mid in stalled_active:
		if new_bench.size() < MAX_BENCH and _merc_in_formation_pool(gm.find_mercenary_by_id(mid)):
			new_bench.append(mid)
	active = ready_active
	var scan := 0
	while active.size() < MAX_ACTIVE and scan < new_bench.size():
		var mid: String = new_bench[scan]
		var m := gm.find_mercenary_by_id(mid)
		if m != null and _merc_deploy_ready(m):
			active.append(mid)
			new_bench.remove_at(scan)
		else:
			scan += 1
	for mid in _merc_roster_ids(gm):
		if mid in active or mid in new_bench:
			continue
		if mid in _half_all_ids(gm.squad_formation, HALF_B if half == HALF_A else HALF_A):
			continue
		var m := gm.find_mercenary_by_id(mid)
		if not _merc_in_formation_pool(m) or not _merc_deploy_ready(m):
			continue
		if active.size() < MAX_ACTIVE:
			active.append(mid)
		elif new_bench.size() < MAX_BENCH:
			new_bench.append(mid)
	gm.squad_formation[half] = {"active": active, "bench": new_bench}


static func _strip_player_from_halves(gm: GameManager) -> void:
	if gm == null or gm.player == null:
		return
	var pid: String = gm.player.merc_id
	for half in [HALF_A, HALF_B]:
		var active: Array[String] = get_active_ids(gm.squad_formation, half)
		var bench: Array[String] = get_bench_ids(gm.squad_formation, half)
		active.erase(pid)
		bench.erase(pid)
		gm.squad_formation[half] = {"active": active, "bench": bench}


static func _merc_roster_ids(gm: GameManager) -> Array[String]:
	var ids: Array[String] = []
	for e in gm.elite_roster:
		ids.append(e.merc_id)
	for n in gm.normal_roster:
		ids.append(n.merc_id)
	return ids


static func _all_roster_ids(gm: GameManager) -> Array[String]:
	var ids: Array[String] = _merc_roster_ids(gm)
	if gm.player:
		ids.insert(0, gm.player.merc_id)
	return ids


static func _half_all_ids(formation: Dictionary, half: String) -> Array[String]:
	var all: Array[String] = []
	all.append_array(get_active_ids(formation, half))
	all.append_array(get_bench_ids(formation, half))
	return all


static func _half_active_count(formation: Dictionary, half: String) -> int:
	return get_active_ids(formation, half).size()


static func _half_bench_count(formation: Dictionary, half: String) -> int:
	return get_bench_ids(formation, half).size()


static func _add_to_active(formation: Dictionary, half: String, mid: String) -> void:
	var part: Dictionary = formation.get(half, {"active": [], "bench": []})
	var active: Array = part.get("active", [])
	if mid not in active and active.size() < MAX_ACTIVE:
		active.append(mid)
	formation[half] = {"active": active, "bench": part.get("bench", [])}


static func _add_to_bench(formation: Dictionary, half: String, mid: String) -> void:
	var part: Dictionary = formation.get(half, {"active": [], "bench": []})
	var bench: Array = part.get("bench", [])
	if mid not in bench and bench.size() < MAX_BENCH:
		bench.append(mid)
	formation[half] = {"active": part.get("active", []), "bench": bench}


static func _trim_slots(ids: Array[String], max_n: int) -> Array[String]:
	if ids.size() <= max_n:
		return ids
	return ids.slice(0, max_n)


static func remove_merc_from_formation(gm: GameManager, merc_id: String) -> void:
	if gm == null or merc_id == "":
		return
	for half in [HALF_A, HALF_B]:
		var active: Array[String] = get_active_ids(gm.squad_formation, half)
		var bench: Array[String] = get_bench_ids(gm.squad_formation, half)
		active.erase(merc_id)
		bench.erase(merc_id)
		gm.squad_formation[half] = {"active": active, "bench": bench}


static func assign_merc_to_slot(
	gm: GameManager, merc_id: String, half: String, slot_kind: String, slot_index: int
) -> int:
	if gm == null or merc_id == "" or half not in [HALF_A, HALF_B]:
		return -1
	if _is_player_id(gm, merc_id):
		return -3
	var merc := gm.find_mercenary_by_id(merc_id)
	if merc != null and not merc.can_join_squad():
		return -5
	if slot_kind not in ["active", "bench"]:
		return -1
	var max_idx: int = MAX_ACTIVE if slot_kind == "active" else MAX_BENCH
	if slot_index < 0 or slot_index >= max_idx:
		return -1
	ensure_formation(gm)
	var other: String = HALF_B if half == HALF_A else HALF_A
	if merc_id in _half_all_ids(gm.squad_formation, other):
		return -2
	remove_merc_from_formation(gm, merc_id)
	var active: Array[String] = get_active_ids(gm.squad_formation, half)
	var bench: Array[String] = get_bench_ids(gm.squad_formation, half)
	active = _pad_slots(active, MAX_ACTIVE)
	bench = _pad_slots(bench, MAX_BENCH)
	if slot_kind == "active":
		active[slot_index] = merc_id
	else:
		bench[slot_index] = merc_id
	active = _compact_ids(active)
	bench = _compact_ids(bench)
	gm.squad_formation[half] = {"active": active, "bench": bench}
	return _validate_player_placement(gm)


static func swap_formation_slots(
	gm: GameManager, half: String, kind_a: String, idx_a: int, kind_b: String, idx_b: int
) -> int:
	if gm == null or half not in [HALF_A, HALF_B]:
		return -1
	ensure_formation(gm)
	var active: Array[String] = _pad_slots(get_active_ids(gm.squad_formation, half), MAX_ACTIVE)
	var bench: Array[String] = _pad_slots(get_bench_ids(gm.squad_formation, half), MAX_BENCH)
	var id_a := _slot_id_at(active, bench, kind_a, idx_a)
	var id_b := _slot_id_at(active, bench, kind_b, idx_b)
	if gm.player != null:
		var pid: String = gm.player.merc_id
		if id_a == pid or id_b == pid:
			return -3
	_set_slot_id(active, bench, kind_a, idx_a, id_b)
	_set_slot_id(active, bench, kind_b, idx_b, id_a)
	gm.squad_formation[half] = {
		"active": _compact_ids(active),
		"bench": _compact_ids(bench),
	}
	return _validate_player_placement(gm)


static func clear_slot(gm: GameManager, half: String, slot_kind: String, slot_index: int) -> int:
	if gm == null:
		return -1
	ensure_formation(gm)
	var active: Array[String] = _pad_slots(get_active_ids(gm.squad_formation, half), MAX_ACTIVE)
	var bench: Array[String] = _pad_slots(get_bench_ids(gm.squad_formation, half), MAX_BENCH)
	_set_slot_id(active, bench, slot_kind, slot_index, "")
	gm.squad_formation[half] = {
		"active": _compact_ids(active),
		"bench": _compact_ids(bench),
	}
	return 0


static func set_preferred_half(gm: GameManager, half: String) -> void:
	ensure_formation(gm)
	if half in [HALF_A, HALF_B]:
		gm.squad_formation["active_half"] = half


static func get_recovery_status(gm: GameManager) -> Dictionary:
	ensure_formation(gm)
	var locked := is_recovery_lock_active(gm)
	var halves: Dictionary = {}
	for half in [HALF_A, HALF_B]:
		halves[half] = _half_recovery_detail(gm, half)
	var deployable: int = 0
	if halves[HALF_A].get("can_deploy", false):
		deployable += 1
	if halves[HALF_B].get("can_deploy", false):
		deployable += 1
	var eta: float = estimate_recovery_seconds(gm)
	var next_half: String = pick_deploy_half(gm)
	return {
		"locked": locked,
		"no_mercs": locked and not has_living_merc_roster(gm),
		"deployable_halves": deployable,
		"halves": halves,
		"heal_priority_count": heal_priority_mercs(gm).size(),
		"eta_seconds": eta,
		"next_deploy_half": next_half,
	}


static func estimate_recovery_seconds(gm: GameManager) -> float:
	if gm == null or not is_recovery_lock_active(gm):
		return 0.0
	var heal_mult: float = gm.get_infirmary_heal_speed_multiplier()
	if is_recovery_lock_active(gm):
		heal_mult *= 1.5
	var ratio_per_tick: float = RosterHealth.get_heal_ratio_per_tick(heal_mult)
	if ratio_per_tick <= 0.0001:
		return 9999.0
	var best: float = 999999.0
	for half in [HALF_A, HALF_B]:
		best = minf(best, _estimate_half_recovery_seconds(gm, half, ratio_per_tick))
	return best if best < 999999.0 else 0.0


static func _estimate_half_recovery_seconds(
	gm: GameManager, half: String, ratio_per_tick: float
) -> float:
	if half_can_deploy(gm, half):
		return 0.0
	var max_ticks: float = 0.0
	var slot_ids: Array[String] = []
	slot_ids.append_array(get_active_ids(gm.squad_formation, half))
	slot_ids.append_array(get_bench_ids(gm.squad_formation, half))
	for mid in slot_ids:
		if _is_player_id(gm, mid):
			continue
		var m := gm.find_mercenary_by_id(mid)
		if m == null or not m.is_alive:
			continue
		if _merc_deploy_ready(m):
			continue
		var max_hp: int = maxi(1, StatResolver.get_max_hp(m))
		var need_ratio: float = maxf(0.0, RosterHealth.DEPLOY_HP_RATIO - float(m.current_hp) / float(max_hp))
		if m.is_near_death:
			need_ratio = maxf(need_ratio, RosterHealth.DEPLOY_HP_RATIO)
		if not m.is_personal_stability_ok():
			need_ratio = maxf(need_ratio, 0.5)
		max_ticks = maxf(max_ticks, need_ratio / ratio_per_tick)
	return max_ticks * RosterHealth.BASE_HEAL_TICK_SEC


static func _half_recovery_detail(gm: GameManager, half: String) -> Dictionary:
	var members: Array[Dictionary] = []
	for kind in ["active", "bench"]:
		var ids: Array[String] = get_active_ids(gm.squad_formation, half) if kind == "active" else get_bench_ids(gm.squad_formation, half)
		for mid in ids:
			if _is_player_id(gm, mid):
				continue
			members.append(_merc_recovery_entry(gm, mid, kind))
	var can_dep := half_can_deploy(gm, half)
	return {
		"can_deploy": can_dep,
		"active_count": get_active_ids(gm.squad_formation, half).size(),
		"bench_count": get_bench_ids(gm.squad_formation, half).size(),
		"members": members,
	}


static func _merc_recovery_entry(gm: GameManager, merc_id: String, slot_kind: String) -> Dictionary:
	var m := gm.find_mercenary_by_id(merc_id)
	if m == null:
		return {"id": merc_id, "name": merc_id, "slot": slot_kind, "ready": false, "reason": "缺失"}
	var max_hp: int = maxi(1, StatResolver.get_max_hp(m))
	var hp_pct: float = float(m.current_hp) / float(max_hp)
	var reason := ""
	var ready: bool = _merc_deploy_ready(m)
	if m.is_test_stand_in:
		return {
			"id": merc_id,
			"name": m.merc_name,
			"slot": slot_kind,
			"hp_pct": 1.0,
			"current_hp": max_hp,
			"max_hp": max_hp,
			"ready": true,
			"reason": "测试·锁定",
			"is_player": gm.player != null and gm.player.merc_id == merc_id,
		}
	if not m.is_alive:
		reason = "阵亡"
	elif m.is_mia:
		reason = "战场遗留"
	elif m.is_near_death:
		reason = "濒死·需先恢复"
	elif m.is_retreated:
		reason = "休整中"
	elif not m.is_personal_stability_ok():
		reason = "个人稳定不足"
	elif hp_pct < RosterHealth.DEPLOY_HP_RATIO:
		reason = "生命未达七成"
	elif ready:
		reason = "可出战"
	return {
		"id": merc_id,
		"name": m.merc_name,
		"slot": slot_kind,
		"hp_pct": hp_pct,
		"current_hp": m.current_hp,
		"max_hp": max_hp,
		"ready": ready,
		"reason": reason,
		"is_player": gm.player != null and gm.player.merc_id == merc_id,
	}


static func _validate_player_placement(gm: GameManager) -> int:
	if gm.player == null:
		return 0
	var pid: String = gm.player.merc_id
	if pid in _half_all_ids(gm.squad_formation, HALF_A) or pid in _half_all_ids(gm.squad_formation, HALF_B):
		_strip_player_from_halves(gm)
		return -3
	return 0


static func _pad_slots(ids: Array[String], max_n: int) -> Array[String]:
	var out: Array[String] = []
	for i in range(max_n):
		out.append(ids[i] if i < ids.size() else "")
	return out


static func _compact_ids(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for mid in ids:
		if mid != "":
			out.append(mid)
	return out


static func _slot_id_at(active: Array[String], bench: Array[String], kind: String, index: int) -> String:
	if kind == "active" and index >= 0 and index < active.size():
		return active[index]
	if kind == "bench" and index >= 0 and index < bench.size():
		return bench[index]
	return ""


static func _set_slot_id(
	active: Array[String], bench: Array[String], kind: String, index: int, merc_id: String
) -> void:
	if kind == "active" and index >= 0 and index < active.size():
		active[index] = merc_id
	elif kind == "bench" and index >= 0 and index < bench.size():
		bench[index] = merc_id
