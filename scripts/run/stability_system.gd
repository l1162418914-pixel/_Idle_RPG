class_name StabilitySystem
extends RefCounted
## 队伍稳定度系统 — 0-100，≤30 强制撤离

signal stability_changed(new_value: int)
signal forced_withdraw()

const MAX_STABILITY: int = 100
const WITHDRAW_THRESHOLD: int = 30

var current_stability: int = 100
var base_decay_rate: float = 0.15  # 每秒衰减
var _decay_timer: float = 0.0
var _player_influence: float = 0.0


func init(player: Player, squad: Squad) -> void:
	if player:
		_player_influence = player.squad_stability_influence
	current_stability = MAX_STABILITY
	_decay_timer = 0.0


func tick(delta: float) -> void:
	if current_stability <= 0:
		return
	
	var decay = base_decay_rate * (1.0 - _player_influence) * delta
	_decay_timer += decay
	
	if _decay_timer >= 1.0:
		var points = int(_decay_timer)
		_decay_timer -= points
		modify_stability(-points)


func on_member_down() -> void:
	modify_stability(-15)


func on_boss_killed() -> void:
	modify_stability(20)


func modify_stability(amount: int) -> void:
	var prev = current_stability
	current_stability = clampi(current_stability + amount, 0, MAX_STABILITY)
	if current_stability != prev:
		stability_changed.emit(current_stability)
		if current_stability <= WITHDRAW_THRESHOLD:
			forced_withdraw.emit()


func should_withdraw() -> bool:
	return current_stability <= WITHDRAW_THRESHOLD


func get_danger_level() -> int:
	if current_stability > 70:
		return 0
	if current_stability > 50:
		return 1
	if current_stability > 30:
		return 2
	return 3