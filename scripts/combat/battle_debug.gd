class_name BattleDebug
extends RefCounted
## 战斗平衡测试模式 — 仅调试开关，不修改 JSON 数值表

enum SpeedMode { NORMAL, SLOW, VERY_SLOW }

const SPEED_NORMAL: float = 1.0
const SPEED_SLOW: float = 0.5
const SPEED_VERY_SLOW: float = 0.25

## 全体 HP / 伤害倍率（仅测试模式，不改 JSON）
const HP_MULT: float = 5.0
const DAMAGE_MULT: float = 0.3

## 战斗日志逐条显示间隔（秒，基准为 1.0x 战斗速度）
const LOG_LINE_INTERVAL: float = 0.25

static var current_speed_mode: int = SpeedMode.NORMAL
static var battle_mode_enabled: bool = false
static var _user_override: bool = false


static func reset_session() -> void:
	battle_mode_enabled = false
	_user_override = false
	current_speed_mode = SpeedMode.NORMAL


static func is_enabled() -> bool:
	return battle_mode_enabled


static func set_enabled(on: bool, from_user: bool = false) -> void:
	battle_mode_enabled = on
	if from_user:
		_user_override = true


static func toggle_from_user() -> void:
	set_enabled(not battle_mode_enabled, true)


static func prepare_for_combat(map_data: Dictionary) -> void:
	if _user_override:
		return
	battle_mode_enabled = TestScenarioService.is_test_map(map_data)


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
