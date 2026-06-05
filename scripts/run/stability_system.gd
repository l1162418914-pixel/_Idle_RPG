class_name StabilitySystem
extends RefCounted
## 出征中稳定度：团队（全队）+ 受击单位的个人稳定度

signal team_stability_changed(new_value: int)
signal forced_withdraw()

const MAX_STABILITY: int = 100
const TEAM_WITHDRAW_THRESHOLD: int = 30
const PERSONAL_BREAK_THRESHOLD: int = 30
## 受击扣稳定：个人全额 + 团队分摊比例
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
var base_decay_rate: float = 0.12
var _decay_timer: float = 0.0
var _player_influence: float = 0.0
var _squad: Squad = null
var _team_cost_multiplier: float = 1.0
var _stability_loss_mult: float = 1.0


func init(player: Player, squad: Squad, starting_team: int = MAX_STABILITY, map_data: Dictionary = {}) -> void:
	_squad = squad
	if player:
		_player_influence = player.squad_stability_influence
	team_stability = clampi(starting_team, 0, MAX_STABILITY)
	base_decay_rate = 0.12 * float(map_data.get("stability_decay_mult", 1.0))
	_stability_loss_mult = float(map_data.get("stability_loss_mult", 1.0))
	_decay_timer = 0.0
	refresh_pressure_multipliers()


func refresh_pressure_multipliers() -> void:
	_team_cost_multiplier = 1.0
	if _squad == null:
		return
	var worst_hp: float = 1.0
	var worst_personal: int = MAX_STABILITY
	for m in _squad.members:
		if m == null or not m.is_alive:
			continue
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
	for m in _squad.members:
		if m == null or not m.is_alive:
			continue
		worst = mini(worst, m.personal_stability)
	return worst


func on_ally_hit(damage: int, victim: CombatEntity) -> void:
	if damage <= 0:
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
		_apply_team_loss(team_loss)
		_apply_personal_loss(merc, personal_loss)
	else:
		_apply_team_loss(team_loss)


func tick(delta: float) -> void:
	if team_stability <= 0:
		return
	refresh_pressure_multipliers()
	var decay: float = base_decay_rate * (1.0 - _player_influence) * delta * _team_cost_multiplier
	_decay_timer += decay
	if _decay_timer >= 1.0:
		var points: int = maxi(1, int(_decay_timer))
		_decay_timer -= float(points)
		_apply_team_loss(points)


func on_member_down() -> void:
	refresh_pressure_multipliers()
	_apply_team_loss(15)


func on_member_retreat() -> void:
	refresh_pressure_multipliers()
	_apply_team_loss(5)


func on_boss_killed() -> void:
	modify_team_stability(20)


func _apply_team_loss(base_amount: int) -> void:
	if base_amount <= 0:
		return
	var scaled: int = maxi(1, int(ceil(float(base_amount) * _team_cost_multiplier)))
	modify_team_stability(-scaled)


func _apply_personal_loss(merc: Mercenary, base_amount: int) -> void:
	if merc == null or base_amount <= 0:
		return
	merc.modify_personal_stability(-base_amount)


func modify_team_stability(amount: int) -> void:
	var prev: int = team_stability
	team_stability = clampi(team_stability + amount, 0, MAX_STABILITY)
	if team_stability != prev:
		team_stability_changed.emit(team_stability)
		if team_stability <= TEAM_WITHDRAW_THRESHOLD:
			forced_withdraw.emit()


func should_withdraw() -> bool:
	return team_stability <= TEAM_WITHDRAW_THRESHOLD


func get_danger_level() -> int:
	if team_stability > 70:
		return 0
	if team_stability > 50:
		return 1
	if team_stability > 30:
		return 2
	return 3
