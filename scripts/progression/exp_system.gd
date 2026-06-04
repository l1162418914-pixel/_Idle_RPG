class_name ExpSystem
extends RefCounted
## 经验曲线与升级计算（不改战斗公式）


static func exp_required_for_next_level(current_level: int) -> int:
	if current_level < 1:
		return 50
	return 40 + current_level * 25


static func get_exp_multiplier(merc: Mercenary) -> float:
	if merc is Player:
		return 1.0 + (merc as Player).base_exp_multiplier
	return 1.0


## 发放经验并自动升级。返回 { levels_gained, exp_applied }
static func grant_exp(merc: Mercenary, base_amount: int) -> Dictionary:
	var result := {"levels_gained": 0, "exp_applied": 0}
	if base_amount <= 0 or merc == null:
		return result
	var amount := int(base_amount * get_exp_multiplier(merc))
	result.exp_applied = amount
	merc.exp += amount
	while merc.level < merc.max_level:
		var need := exp_required_for_next_level(merc.level)
		if merc.exp < need:
			break
		merc.exp -= need
		if merc.level_up():
			result.levels_gained += 1
		else:
			break
	if merc.level >= merc.max_level:
		merc.exp = 0
	return result
