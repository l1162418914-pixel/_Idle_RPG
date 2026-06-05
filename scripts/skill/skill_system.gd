extends RefCounted
class_name SkillSystem
## 技能系统计算层 — 读取 merc.passive_skills，查询数据模板，计算加成


# ─── 被动技能总加成（按属性聚合）─────────────────────

static func get_passive_bonus(merc, stat: String):
	var total := 0.0
	for skill_id in merc.passive_skills:
		var skill_data = DataLoader.skill_template(skill_id)
		if skill_data.is_empty():
			continue
		var effect = skill_data.effects.get(stat, {})
		if effect.is_empty():
			continue
		var base = effect.get("base", 0)
		var per_level = effect.get("per_level", 0)
		total += base + per_level * (merc.level - 1)
	return total


# ─── 按技能 ID 查询单个技能的加成 ──────────────────────

static func get_skill_bonus(skill_id: String, merc_level: int, stat: String):
	var skill_data = DataLoader.skill_template(skill_id)
	if skill_data.is_empty():
		return 0.0
	var effect = skill_data.effects.get(stat, {})
	if effect.is_empty():
		return 0.0
	var base = effect.get("base", 0)
	var per_level = effect.get("per_level", 0)
	return base + per_level * (merc_level - 1)


# ─── 查询技能显示信息 ──────────────────────────────────

static func get_skill_info(skill_id: String) -> Dictionary:
	var skill_data = DataLoader.skill_template(skill_id)
	if skill_data.is_empty():
		return {}
	return {
		"id": skill_id,
		"name": skill_data.get("name", ""),
		"description": skill_data.get("description", ""),
		"effects": skill_data.get("effects", {}).duplicate()
	}


# ─── 主动技能 ───────────────────────────────────────────

static func is_active_skill(skill_id: String) -> bool:
	var skill_data := DataLoader.skill_template(skill_id)
	return skill_data.has("effect_type")


static func get_active_skill_name(skill_id: String) -> String:
	var skill_data := DataLoader.skill_template(skill_id)
	return skill_data.get("name", skill_id)


static func get_active_cooldown(skill_id: String) -> float:
	var skill_data := DataLoader.skill_template(skill_id)
	return float(skill_data.get("cooldown", 5.0))


## 技能施法距离（与普攻射程独立；缺省为 max(attack_range, 350)）
static func get_skill_cast_range(skill_data: Dictionary, attack_range: float) -> float:
	if skill_data.has("cast_range"):
		return float(skill_data.get("cast_range", 350.0))
	return maxf(attack_range, 350.0)


static func compute_active_power(skill_data: Dictionary, merc_level: int) -> float:
	var power: Dictionary = skill_data.get("power", {})
	return float(power.get("base", 0)) + float(power.get("per_level", 0)) * float(merc_level - 1)