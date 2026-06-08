class_name RosterHealth
extends RefCounted
## 编队生命规则：低血量撤离阈值、基地自动回血

## 非主角血量 ≤ 此比例时自动脱离当前出征队伍
const RETREAT_HP_RATIO: float = 0.25
## 回城后 ≥ 此比例可清除濒死、再次出征
const DEPLOY_HP_RATIO: float = 0.70
## 基地回血结算间隔（秒）
const BASE_HEAL_TICK_SEC: float = 1.0
## 每 tick 恢复最大生命的比例（医疗室等级再乘倍率）
const BASE_HEAL_RATIO_PER_TICK: float = 0.05


static func get_heal_ratio_per_tick(infirmary_speed_mult: float) -> float:
	return BASE_HEAL_RATIO_PER_TICK * maxf(0.1, infirmary_speed_mult)


static func heal_mercenary(merc: Mercenary, heal_ratio: float) -> int:
	if merc == null or not merc.is_alive or merc.is_mia:
		return 0
	var max_hp: int = StatResolver.get_max_hp(merc)
	if merc.current_hp >= max_hp:
		merc.try_clear_retreat_on_full_heal()
		merc.try_clear_near_death_for_deploy()
		return 0
	var amount: int = maxi(1, int(float(max_hp) * heal_ratio))
	var before: int = merc.current_hp
	merc.current_hp = mini(max_hp, merc.current_hp + amount)
	merc.try_clear_retreat_on_full_heal()
	merc.try_clear_near_death_for_deploy()
	return merc.current_hp - before


static func recover_personal_stability(merc: Mercenary, heal_ratio: float) -> int:
	if merc == null or not merc.is_alive or merc.is_mia:
		return 0
	var cap: int = merc.get_personal_stability_max()
	if merc.personal_stability >= cap:
		merc.try_clear_personal_break()
		return 0
	var amount: int = maxi(1, int(float(cap) * heal_ratio * 0.8))
	var before: int = merc.personal_stability
	merc.modify_personal_stability(amount)
	merc.try_clear_personal_break()
	return merc.personal_stability - before
