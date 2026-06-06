class_name PressureOutcomeService
extends RefCounted
## 压力收场 B-3c/d + 撤离事件（T-MIA-P3）


static func config() -> Dictionary:
	return DataLoader.near_death_config().get("pressure_outcome", {})


static func is_intact(merc: Mercenary) -> bool:
	if merc == null or not merc.is_alive or merc.is_mia:
		return false
	return not RetreatFailureMiaService.is_distressed(merc)


static func light_judgment(run: WorldRun) -> Dictionary:
	var field: Array[Mercenary] = _field_mercs(run)
	var intact_n := 0
	var distressed_n := 0
	for merc in field:
		if RetreatFailureMiaService.is_distressed(merc):
			distressed_n += 1
		elif is_intact(merc):
			intact_n += 1
	var total: int = field.size()
	var cfg: Dictionary = config()
	var ratio: float = float(intact_n) / float(maxi(1, total))
	var quota: int = distressed_n
	if ratio <= float(cfg.get("intact_ratio_threshold", 0.34)):
		quota = maxi(quota, total - intact_n)
	quota = clampi(quota, int(cfg.get("mia_quota_min", 1)), total)
	return {
		"intact_count": intact_n,
		"distressed_count": distressed_n,
		"field_count": total,
		"mia_quota": quota,
		"intact_ratio": ratio,
	}


static func trigger_team_pressure_retreat(run: WorldRun) -> void:
	if run == null or run.is_retreating:
		return
	var judgment: Dictionary = light_judgment(run)
	run.pressure_retreat_event = true
	run.pressure_mia_quota = int(judgment.get("mia_quota", 0))
	_apply_pressure_snap(run)
	run.try_pressure_outcome_loot_loss()
	run.begin_retreat("pressure")
	run.emit_signal("run_event", "pressure_retreat_event", judgment)


static func _apply_pressure_snap(run: WorldRun) -> void:
	if run == null or run.squad == null:
		return
	var snap: int = int(config().get("team_break_personal_snap", 8))
	for merc in run.squad.get_battlefield_members():
		if merc == null or not merc.is_alive or TestScenarioService.test_merc_blocks_casualties(merc):
			continue
		merc.modify_personal_stability(-snap)


## 单人压力触顶：替补换人（B-3c-单人），失败则回退濒死
static func try_single_pressure_substitute(run: WorldRun, merc: Mercenary) -> bool:
	if run == null or merc == null or merc.is_mia or merc.is_near_death:
		return false
	if merc.merc_type == Mercenary.MercType.PLAYER or TestScenarioService.test_merc_blocks_casualties(merc):
		return false
	if run.bench_reserves.is_empty():
		return false
	var replacement: Mercenary = null
	for i in range(run.bench_reserves.size()):
		var cand: Mercenary = run.bench_reserves[i]
		if cand != null and not (cand is Player) and cand.can_join_squad():
			replacement = cand
			run.bench_reserves.remove_at(i)
			break
	if replacement == null:
		return false
	run.bench_reserves.append(merc)
	var recovery: int = int(config().get("substitute_recovery_stability", 20))
	merc.personal_stability = clampi(recovery, 1, StabilitySystem.MAX_STABILITY)
	var idx: int = run.squad.members.find(merc)
	if idx >= 0:
		run.squad.members[idx] = replacement
	elif replacement not in run.squad.members:
		run.squad.members.append(replacement)
	run.emit_signal(
		"run_event",
		"pressure_substitute",
		{
			"out_merc_id": merc.merc_id,
			"out_name": merc.merc_name,
			"in_merc_id": replacement.merc_id,
			"in_name": replacement.merc_name,
		}
	)
	return true


## 压力抵营（B-3c 二阶段）：轻判定 quota → 按状态加权二次 roll 点名 MIA
static func apply_camp_pressure_settlement(gm: GameManager, result: Dictionary) -> void:
	if gm == null:
		return
	if not bool(result.get("pressure_retreat_event", false)):
		return
	if not bool(result.get("completed_retreat", false)):
		return
	var quota: int = int(result.get("pressure_mia_quota", 0))
	if quota <= 0:
		return
	var field: Array[Mercenary] = []
	for mid in result.get("squad_member_ids", []):
		var merc := gm.find_mercenary_by_id(str(mid))
		if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		if TestScenarioService.test_merc_blocks_casualties(merc):
			continue
		field.append(merc)
	if field.is_empty():
		return
	var cfg: Dictionary = config()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var picks: Array[Mercenary] = _pick_weighted_mercs(field, quota, rng)
	var mia_n := 0
	var base_chance: float = float(cfg.get("stage2_base_chance", 0.52))
	var distressed_bonus: float = float(cfg.get("stage2_distressed_bonus", 0.28))
	var miss_ratio: float = float(cfg.get("stage2_miss_near_death_ratio", 0.1))
	for merc in picks:
		var chance: float = base_chance
		if RetreatFailureMiaService.is_distressed(merc):
			chance += distressed_bonus
		chance = clampf(chance, 0.05, 0.95)
		if rng.randf() < chance:
			merc.enter_mia_state()
			mia_n += 1
		elif not merc.is_mia:
			merc.apply_near_death_state(miss_ratio)
	result["pressure_mia_applied"] = mia_n
	result["pressure_mia_rolled"] = picks.size()
	if mia_n > 0:
		result["mia_count"] = mia_n
		result["settlement_tier"] = "mia"
		result["mia_wipe_recovery_hint"] = true


static func merc_mia_weight(merc: Mercenary) -> float:
	if merc == null or not merc.is_alive or merc.is_mia:
		return 0.0
	var w: float = 1.0
	if RetreatFailureMiaService.is_distressed(merc):
		w += 2.0
	if merc.is_near_death:
		w += 3.0
	w += float(StabilitySystem.MAX_STABILITY - merc.personal_stability) / 25.0
	w += (1.0 - merc.get_hp_ratio()) * 2.0
	return maxf(0.1, w)


static func _pick_weighted_mercs(
	field: Array[Mercenary], quota: int, rng: RandomNumberGenerator
) -> Array[Mercenary]:
	var pool: Array[Mercenary] = field.duplicate()
	var picks: Array[Mercenary] = []
	var n: int = clampi(quota, 1, pool.size())
	while picks.size() < n and not pool.is_empty():
		var total_w: float = 0.0
		for merc in pool:
			total_w += merc_mia_weight(merc)
		if total_w <= 0.0:
			break
		var roll: float = rng.randf() * total_w
		var acc: float = 0.0
		var chosen_idx: int = 0
		for i in range(pool.size()):
			acc += merc_mia_weight(pool[i])
			if roll <= acc:
				chosen_idx = i
				break
		picks.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)
	return picks


static func _field_mercs(run: WorldRun) -> Array[Mercenary]:
	var out: Array[Mercenary] = []
	if run == null or run.squad == null:
		return out
	for merc in run.squad.get_battlefield_members():
		if merc == null or merc.merc_type == Mercenary.MercType.PLAYER:
			continue
		out.append(merc)
	return out
