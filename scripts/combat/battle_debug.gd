class_name BattleDebug
extends RefCounted
## 战斗平衡测试模式 — 仅调试开关，不修改 JSON 数值表

## 设为 false 即完全恢复正式战斗数值
const DEBUG_BATTLE_MODE: bool = false

enum SpeedMode { NORMAL, SLOW, VERY_SLOW }

const SPEED_NORMAL: float = 1.0
const SPEED_SLOW: float = 0.5
const SPEED_VERY_SLOW: float = 0.25

## 全体 HP / 伤害倍率（仅 DEBUG_BATTLE_MODE，不改 JSON）
const HP_MULT: float = 5.0
const DAMAGE_MULT: float = 0.3

## 战斗日志逐条显示间隔（秒，基准为 1.0x 战斗速度）
const LOG_LINE_INTERVAL: float = 0.25

static var current_speed_mode: int = SpeedMode.NORMAL


static func is_enabled() -> bool:
	return DEBUG_BATTLE_MODE


static func get_time_scale() -> float:
	match current_speed_mode:
		SpeedMode.SLOW:
			return SPEED_SLOW
		SpeedMode.VERY_SLOW:
			return SPEED_VERY_SLOW
		_:
			return SPEED_NORMAL


static func log_line_interval() -> float:
	return LOG_LINE_INTERVAL / maxf(0.25, get_time_scale())


static func apply_entity_modifiers(entity: CombatEntity) -> void:
	if not is_enabled():
		return
	entity.max_hp = maxi(1, int(entity.max_hp * HP_MULT))
	entity.current_hp = entity.max_hp


static func scale_damage(raw: int) -> int:
	if not is_enabled():
		return raw
	return maxi(1, int(raw * DAMAGE_MULT))


static func speed_mode_label(mode: int) -> String:
	match mode:
		SpeedMode.SLOW:
			return "0.5x"
		SpeedMode.VERY_SLOW:
			return "0.25x"
		_:
			return "1.0x"
