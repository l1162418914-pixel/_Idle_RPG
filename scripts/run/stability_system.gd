class_name StabilitySystem
extends RefCounted
## 出征中稳定度：T-STAB-POOL — 团队条 = 出战在编个人稳之和

signal team_stability_changed(new_value: int)
signal forced_withdraw()

const MAX_STABILITY: int = 100
## 团队/个人崩溃线：本趟上限的 30%
const BREAK_THRESHOLD_RATIO: float = 0.30
## T-STAB-POOL：受击扣个人稳，团队条随个人池同步
const APPLY_PERSONAL_LOSS_ON_HIT: bool = true
## 个人条耗尽时，其余在编各扣该员上限的 10%
const CASCADE_DEPLETION_RATIO: float = 0.10
const TEAM_HIT_SHARE: float = 0.45
const HIT_STABILITY_SCALE: float = 10.0
const HIT_STABILITY_MIN: int = 1
const HIT_STABILITY_MAX: int = 12
const LOW_HP_PRESSURE_RATIO: float = 0.50
const LOW_HP_COST_MULT: float = 1.5
const CRITICAL_HP_PRESSURE_RATIO: float = 0.30
const CRITICAL_HP_COST_MULT: float = 2.0
const LOW_PERSONAL_PRESSURE: int = 50
const LOW_PERSONAL_TEAM_MULT: float = 1.25
const CRITICAL_PERSONAL_PRESSURE: int = 30
const CRITICAL_PERSONAL_TEAM_MULT: float = 1.5

var team_stability: int = 100
var team_stability_max: int = 100
var base_decay_rate: float = 0.12
var _decay_timer: float = 0.0
var _player_influence: float = 0.0
var _squad: Squad = null
var _team_cost_multiplier: float = 1.0
var _stability_loss_mult: float = 1.0
var _disable_forced_retreat: bool = false
var _disable_stability_drain: bool = false


static func get_team_withdraw_threshold_for_max(max_value: int) -> int:
	return int(floor(float(maxi(1, max_value)) * BREAK_THRESHOLD_RATIO))


static func get_personal_break_threshold_for_max(max_value: int) -> int:
	return int(floor(float(maxi(1, max_value)) * BREAK_THRESHOLD_RATIO))


## 兼容旧调用（固定 100 刻度探针）
static func get_team_withdraw_threshold() -> int:
	return get_team_withdraw_threshold_for_max(MAX_STABILITY)


func get_run_withdraw_threshold() -> int:
	return get_team_withdraw_threshold_for_max(team_stability_max)


func init(
	player: Player,
	squad: Squad,
	starting_team: int = MAX_STABILITY,
	map_data: Dictionary = {},
	starting_team_max: int = -1,
) -> void:
	_squad = squad
	if player:
		_player_influence = player.squad_stability_influence
	team_stability_max = starting_team_max if starting_team_max > 0 else maxi(starting_team, MAX_STABILITY)
	base_decay_rate = 0.12 * float(map_data.get("stability_decay_mult", 1.0))
	_stability_loss_mult = float(map_data.get("stability_loss_mult", 1.0))
	_disable_forced_retreat = bool(map_data.get("disable_stability_forced_retreat", false))
	_disable_stability_drain = bool(map_data.get("disable_stability_drain", false))
	_decay_timer = 0.0
	_sync_team_from_squad()
	refresh_pressure_multipliers()


func refresh_pressure_multipliers() -> void:
	_team_cost_multiplier = 1.0
	if _squad == null:
		return
	var worst_hp: float = 1.0
	var worst_personal: int = MAX_STABILITY
	for m in _counted_squad_members():
		worst_hp = minf(worst_hp, m.get_hp_ratio())
		worst_personal = mini(worst_personal, m.personal_stability)
	if worst_hp <= CRITICAL_HP_PRESSURE_RATIO:
		_team_cost_multiplier = maxf(_team_cost_multiplier, CRITICAL_HP_COST_MULT)
	elif worst_hp <= LOW_HP_PRESSURE_RATIO:
		_team_cost_multiplier = maxf(_team_cost_multiplier, LOW_HP_COST_MULT)
	if worst_personal <= CRITICAL_PERSONAL_PRESSURE:
		_team_cost_multiplier = maxf(_team_cost_multiplier, CRITICAL_PERSONAL_TEAM_MULT)
	elif worst_personal <= LOW_PERSONAL_PRESSURE:
		_team_cost_multiplier = maxf(_team_cost_multiplier, LOW_PERSONAL_TEAM_MULT)


func get_team_cost_multiplier() -> float:
	return _team_cost_multiplier


func get_min_personal_stability() -> int:
	if _squad == null:
		return MAX_STABILITY
	var worst: int = MAX_STABILITY
	for m in _counted_squad_members():
		worst = mini(worst, m.personal_stability)
	return worst


func on_ally_hit(damage: int, victim: CombatEntity) -> void:
	if _disable_stability_drain or damage <= 0:
		return
	refresh_pressure_multipliers()
	var ratio: float = float(damage) / float(maxi(1, victim.max_hp))
	var loss: int = clampi(
		maxi(HIT_STABILITY_MIN, int(ratio * HIT_STABILITY_SCALE)),
		HIT_STABILITY_MIN,
		HIT_STABILITY_MAX
	)
	var team_loss: int = maxi(1, int(ceil(float(loss) * TEAM_HIT_SHARE * _stability_loss_mult)))
	if victim.source_merc != null:
		var merc: Mercenary = victim.source_merc as Mercenary
		var scar_mult: float = merc.get_scar_stability_loss_mult()
		var team_scar: float = 1.0 + (scar_mult - 1.0) * 0.35
		team_loss = maxi(1, int(ceil(float(team_loss) * team_scar)))
		var personal_loss: int = maxi(
			1, int(ceil(float(loss) * _stability_loss_mult * scar_mult))
		)
		_apply_personal_loss_with_cascade(merc, personal_loss)
		_distribute_personal_delta(-team_loss)
	else:
		_distribute_personal_delta(-team_loss)
	_sync_team_from_squad()


func tick(delta: float) -> void:
	if _disable_stability_drain or team_stability <= 0:
		return
	refresh_pressure_multipliers()
	var decay: float = base_decay_rate * (1.0 - _player_influence) * delta * _team_cost_multiplier
	_decay_timer += decay
	if _decay_timer >= 1.0:
		var points: int = maxi(1, int(_decay_timer))
		_decay_timer -= float(points)
		_distribute_personal_delta(-points)
		_sync_team_from_squad()


func on_member_down() -> void:
	if _disable_stability_drain:
		return
	refresh_pressure_multipliers()
	_distribute_personal_delta(-15)
	_sync_team_from_squad()


func on_member_retreat() -> void:
	refresh_pressure_multipliers()
	_distribute_personal_delta(-5)
	_sync_team_from_squad()


func on_boss_killed() -> void:
	_distribute_personal_delta(20)
	_sync_team_from_squad()


## 替补上阵 / 压力换人后刷新团队条（替补平时不计入总和）
func on_field_roster_changed() -> void:
	_recalc_team_stability_max()
	_sync_team_from_squad()


func modify_team_stability(amount: int) -> void:
	if amount == 0:
		return
	_distribute_personal_delta(amount)
	_sync_team_from_squad()


func _counted_squad_members() -> Array[Mercenary]:
	var out: Array[Mercenary] = []
	if _squad == null:
		return out
	for m in _squad.members:
		if m == null or not m.is_alive:
			continue
		if m is Player:
			continue
		out.append(m)
	return out


func _recalc_team_stability_max() -> void:
	var total: int = 0
	for m in _counted_squad_members():
		total += m.get_personal_stability_max()
	team_stability_max = maxi(1, total)


func _sync_team_from_squad() -> void:
	var prev: int = team_stability
	if not _counted_squad_members().is_empty():
		_recalc_team_stability_max()
		var sum: int = 0
		for m in _counted_squad_members():
			sum += m.personal_stability
		team_stability = sum
	else:
		team_stability = clampi(team_stability, 0, team_stability_max)
	if team_stability != prev:
		team_stability_changed.emit(team_stability)
	if (
		not _disable_forced_retreat
		and prev > get_run_withdraw_threshold()
		and team_stability <= get_run_withdraw_threshold()
	):
		forced_withdraw.emit()


func _distribute_personal_delta(amount: int) -> void:
	if _disable_stability_drain or amount == 0:
		return
	var members: Array[Mercenary] = _counted_squad_members()
	var n: int = members.size()
	if n == 0:
		return
	if amount > 0:
		var base_gain: int = amount / n
		var rem_gain: int = amount % n
		for i in range(n):
			var gain: int = base_gain + (1 if i < rem_gain else 0)
			if gain > 0:
				members[i].modify_personal_stability(gain)
		return
	var loss_total: int = -amount
	var base_loss: int = loss_total / n
	var rem_loss: int = loss_total % n
	for i in range(n):
		var loss: int = base_loss + (1 if i < rem_loss else 0)
		if loss > 0:
			_apply_personal_loss_with_cascade(members[i], loss)


func _apply_personal_loss_with_cascade(merc: Mercenary, amount: int) -> void:
	if merc == null or amount <= 0:
		return
	var was: int = merc.personal_stability
	merc.modify_personal_stability(-amount)
	if was > 0 and merc.personal_stability == 0:
		_cascade_personal_depletion(merc)


func _cascade_personal_depletion(victim: Mercenary) -> void:
	if victim == null:
		return
	var spill: int = maxi(
		1,
		int(floor(float(victim.get_personal_stability_max()) * CASCADE_DEPLETION_RATIO))
	)
	for m in _counted_squad_members():
		if m == victim:
			continue
		m.modify_personal_stability(-spill)


func should_withdraw() -> bool:
	if _disable_forced_retreat:
		return false
	return team_stability <= get_run_withdraw_threshold()


func get_danger_level() -> int:
	var withdraw: int = get_run_withdraw_threshold()
	if team_stability_max <= 0:
		return 0
	if team_stability > int(float(team_stability_max) * 0.70):
		return 0
	if team_stability > int(float(team_stability_max) * 0.50):
		return 1
	if team_stability > withdraw:
		return 2
	return 3
