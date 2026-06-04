class_name CombatEntity
extends RefCounted
## CombatEntity — 横版战斗中单个实体的运行时数据

enum Team { ALLY, ENEMY }
enum ActionState { IDLE, MOVING, ATTACKING, DEAD }

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

signal on_death(entity_id: String)


func init_from_merc(merc, prefix: String = "") -> void:
	source_merc = merc
	team = Team.ALLY
	entity_id = prefix + merc.merc_id
	recalc_from_merc()
	current_hp = merc.current_hp
	attack_range = merc.attack_range
	attack_speed = merc.attack_speed
	is_facing_right = true


func recalc_from_merc() -> void:
	## 从 EquipmentSystem 四层聚合重新读取属性
	## 战斗中 buff 变化后调用此方法保持 CombatEntity 与 Mercenary 同步
	if source_merc == null:
		return
	max_hp = EquipmentSystem.get_max_hp(source_merc)
	patk = max(EquipmentSystem.get_attack(source_merc), EquipmentSystem.get_magic_attack(source_merc))
	matk = EquipmentSystem.get_magic_attack(source_merc)
	pdef = EquipmentSystem.get_defense(source_merc)
	mdef = EquipmentSystem.get_magic_defense(source_merc)
	spd = EquipmentSystem.get_speed(source_merc)
	crit_chance = EquipmentSystem.get_crit_chance(source_merc)
	dodge = EquipmentSystem.get_dodge(source_merc)
	block_chance = EquipmentSystem.get_block_chance(source_merc)
	move_speed = 40.0 + spd * 2.0
	# 防止 buff 消退后 HP 溢出
	current_hp = min(current_hp, max_hp)


func init_from_enemy(data: Dictionary) -> void:
	team = Team.ENEMY
	entity_id = data.get("uid", "enemy_%d" % randi())
	
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
	move_speed = 30.0 + spd * 2.0
	
	is_facing_right = false


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
	target.current_hp -= raw_damage
	
	if target.current_hp <= 0:
		target.current_hp = 0
		target.action_state = ActionState.DEAD
		target.on_death.emit(target.entity_id)
	
	return raw_damage


func is_dead() -> bool:
	return current_hp <= 0


func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)