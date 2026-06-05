class_name CombatEntity
extends RefCounted
## CombatEntity — 横版战斗中单个实体的运行时数据

enum Team { ALLY, ENEMY }
enum ActionState { IDLE, MOVING, ATTACKING, DEAD, DOWNED, AWAKENING }

var entity_id: String = ""
var team: int = Team.ALLY
var source_merc = null  # 源 Mercenary 引用
var current_target = null

# 战斗属性
var max_hp: int = 100
var current_hp: int = 100
var patk: int = 10
var matk: int = 5
var pdef: int = 5
var mdef: int = 5
var spd: int = 5
var crit_chance: float = 0.05
var dodge: float = 0.03
var block_chance: float = 0.05
var attack_range: float = 50.0
var attack_speed: float = 1.0
var move_speed: float = 60.0

# 战斗状态
var action_state: int = ActionState.IDLE
var attack_timer: float = 0.0
var position: float = 0.0
var is_facing_right: bool = true
## 主动技能冷却 skill_id -> 剩余秒数
var skill_cooldowns: Dictionary = {}

# 本场战斗统计（测试用）
var display_name: String = ""
var combat_damage_dealt: int = 0
var combat_damage_taken: int = 0
var combat_kills: int = 0
var awakening_timer: float = 0.0
var is_boss: bool = false
var is_chase_encounter: bool = false

signal on_death(entity_id: String)


func init_from_merc(merc, prefix: String = "") -> void:
	source_merc = merc
	team = Team.ALLY
	entity_id = prefix + merc.merc_id
	display_name = merc.merc_name
	recalc_from_merc()
	current_hp = merc.current_hp
	is_facing_right = true
	_init_skill_cooldowns(merc)


func _init_skill_cooldowns(merc) -> void:
	skill_cooldowns.clear()
	if merc == null:
		return
	for skill_id in merc.active_skills:
		skill_cooldowns[str(skill_id)] = 0.0


func tick_skill_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns:
		if skill_cooldowns[skill_id] > 0.0:
			skill_cooldowns[skill_id] = maxf(0.0, skill_cooldowns[skill_id] - delta)


func is_skill_ready(skill_id: String) -> bool:
	return skill_cooldowns.get(skill_id, 0.0) <= 0.0


func set_skill_cooldown(skill_id: String, seconds: float) -> void:
	skill_cooldowns[skill_id] = seconds


func recalc_from_merc() -> void:
	## 从 StatResolver 读取 final 快照；不写回 Mercenary
	if source_merc == null:
		return
	_apply_combat_stats(StatResolver.compute(source_merc))


func _apply_combat_stats(stats: CombatStats) -> void:
	max_hp = stats.max_hp
	patk = maxi(stats.patk, stats.matk)
	matk = stats.matk
	pdef = stats.pdef
	mdef = stats.mdef
	spd = stats.spd
	crit_chance = stats.crit_chance
	dodge = stats.dodge
	block_chance = stats.block_chance
	attack_range = stats.attack_range
	attack_speed = stats.attack_speed
	move_speed = 22.0 + spd * 0.85
	current_hp = mini(current_hp, max_hp)


func init_from_enemy(data: Dictionary) -> void:
	team = Team.ENEMY
	entity_id = data.get("uid", "enemy_%d" % randi())
	display_name = data.get("name", entity_id)
	
	var stats = data.get("stats", {})
	max_hp = int(stats.get("hp", 80))
	current_hp = max_hp
	patk = int(stats.get("patk", 8))
	matk = int(stats.get("matk", 3))
	pdef = int(stats.get("pdef", 3))
	mdef = int(stats.get("mdef", 3))
	spd = int(stats.get("spd", 5))
	crit_chance = 0.05
	dodge = 0.03
	block_chance = float(stats.get("block_chance", 0.05))
	attack_range = float(stats.get("attack_range", 50))
	attack_speed = 1.0 + spd * 0.05
	move_speed = 18.0 + spd * 0.85
	
	is_facing_right = false
	is_boss = bool(data.get("is_boss", false))
	is_chase_encounter = bool(data.get("is_chase_encounter", false))


## 技能直接伤害（简化，不走普攻闪避公式）
func apply_direct_damage(amount: int) -> int:
	if is_incapacitated():
		return 0
	var dmg := BattleDebug.scale_damage(maxi(1, amount))
	current_hp -= dmg
	if current_hp <= 0:
		if _try_enter_downed_instead_of_death():
			return dmg
		current_hp = 0
		action_state = ActionState.DEAD
		on_death.emit(entity_id)
	return dmg


func heal_amount(amount: int) -> int:
	if is_dead():
		return 0
	var healed := mini(amount, max_hp - current_hp)
	current_hp += healed
	return healed


func deal_damage_to(target) -> int:
	var raw_damage = max(1, patk - int(target.pdef * 0.5))
	
	# 暴击
	if randf() < crit_chance:
		raw_damage = int(raw_damage * 1.5)
	
	# 闪避
	if randf() < target.dodge:
		return 0
	
	# 格挡
	if randf() < target.block_chance:
		raw_damage = int(raw_damage * 0.5)
	
	raw_damage = max(1, raw_damage)
	raw_damage = BattleDebug.scale_damage(raw_damage)
	target.current_hp -= raw_damage
	
	if target.current_hp <= 0:
		if not target._try_enter_downed_instead_of_death():
			target.current_hp = 0
			target.action_state = ActionState.DEAD
			target.on_death.emit(target.entity_id)
	
	return raw_damage


func is_downed() -> bool:
	return action_state == ActionState.DOWNED


func is_awakening() -> bool:
	return action_state == ActionState.AWAKENING


func is_incapacitated() -> bool:
	if is_dead():
		return true
	if is_awakening():
		return false
	return is_downed()


func can_fight() -> bool:
	return not is_incapacitated()


func _try_enter_downed_instead_of_death() -> bool:
	if team != Team.ALLY or source_merc == null:
		return false
	current_hp = 1
	action_state = ActionState.DOWNED
	if source_merc != null:
		source_merc.enter_near_death_state(0.05)
		if GameManager.current_run != null:
			NearDeathAwakeningService.try_trigger_on_downed(source_merc, self)
	# 濒死不算战斗实体死亡，不 emit on_death（否则会清掉 CombatView）
	return true


func is_dead() -> bool:
	return action_state == ActionState.DEAD or (current_hp <= 0 and not is_downed())


func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)