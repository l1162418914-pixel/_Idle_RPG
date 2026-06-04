extends Resource
class_name Mercenary
## 佣兵基类 — 所有佣兵共享的属性、装备、技能接口

enum MercType { PLAYER, ELITE, NORMAL }

@export var merc_id: String = ""
@export var merc_name: String = ""
@export var merc_type: int = MercType.NORMAL
@export var merc_class: String = ""
@export var level: int = 1
@export var exp: int = 0
@export var max_level: int = 60

# 基础属性（仅模板 + 等级成长；最终值由 StatResolver 计算，勿写入装备/Buff 结果）
@export var hp: int = 0
@export var max_hp: int = 0  # 与 hp 同步的基础生命镜像，非战斗最终上限
@export var patk: int = 0
@export var matk: int = 0
@export var pdef: int = 0
@export var mdef: int = 0
@export var spd: int = 0
@export var crit_chance: float = 0.05
@export var dodge: float = 0.03
@export var block_chance: float = 0.05
@export var attack_range: float = 50.0
@export var attack_speed: float = 1.0

var equipment_slots: Dictionary = {
	"weapon": null, "armor": null, "helmet": null,
	"boots": null, "ring": null, "amulet": null
}

var passive_skills: Array = []
var active_skills: Array = []
var growth_per_level: Dictionary = {}
var template_id: String = ""
var buff_system: BuffSystem = BuffSystem.new()

# 出征临时状态
var current_hp: int = 0
var is_alive: bool = true
## 濒死：仍算存活、可触发撤离；无法攻击与移动；撤离失败才转为永久死亡
var is_near_death: bool = false
var is_retreated: bool = false
## 个人稳定度过低，无法出征直至基地恢复
var is_personal_break: bool = false
var personal_stability: int = 100
var run_kills: int = 0
var run_damage_dealt: int = 0


func init_from_template(template: Dictionary) -> void:
	merc_name = template.get("name", "")
	merc_class = template.get("class", "")
	template_id = template.get("template_id", "")
	level = 1
	
	if template.has("base_stats"):
		_apply_base(template.base_stats)
	if template.has("growth_per_level"):
		growth_per_level = template.growth_per_level.duplicate()
	if template.has("passive_skills"):
		passive_skills = template.passive_skills.duplicate()
	if template.has("active_skills"):
		active_skills = template.active_skills.duplicate()
	
	personal_stability = StabilitySystem.MAX_STABILITY
	reset_to_full_hp()


func _apply_base(stats: Dictionary) -> void:
	hp = stats.get("hp", 100)
	max_hp = hp
	patk = stats.get("patk", 10)
	matk = stats.get("matk", 5)
	pdef = stats.get("pdef", 5)
	mdef = stats.get("mdef", 5)
	spd = stats.get("spd", 5)
	crit_chance = stats.get("crit_chance", 0.05)
	dodge = stats.get("dodge", 0.03)
	block_chance = stats.get("block_chance", 0.05)
	attack_range = stats.get("attack_range", 50.0)
	attack_speed = stats.get("attack_speed", 1.0)


func reset_to_full_hp() -> void:
	current_hp = StatResolver.get_max_hp(self)
	is_alive = true
	is_near_death = false
	is_retreated = false


func get_max_hp_value() -> int:
	return StatResolver.get_max_hp(self)


func get_hp_ratio() -> float:
	var max_v: int = get_max_hp_value()
	if max_v <= 0:
		return 0.0
	return float(current_hp) / float(max_v)


func modify_personal_stability(delta: int) -> void:
	personal_stability = clampi(personal_stability + delta, 0, StabilitySystem.MAX_STABILITY)
	if personal_stability > StabilitySystem.PERSONAL_BREAK_THRESHOLD:
		try_clear_personal_break()


func is_personal_stability_ok() -> bool:
	return personal_stability > StabilitySystem.PERSONAL_BREAK_THRESHOLD


## 是否可编入出征队
func can_join_squad() -> bool:
	return is_alive and not is_near_death and not is_retreated and not is_personal_break and is_personal_stability_ok()


func mark_personal_break() -> void:
	is_personal_break = true


func try_clear_personal_break() -> void:
	if is_personal_stability_ok():
		is_personal_break = false


func should_personal_break() -> bool:
	if not is_alive or is_personal_break:
		return false
	if merc_type == MercType.PLAYER:
		return false
	return personal_stability <= StabilitySystem.PERSONAL_BREAK_THRESHOLD


## 非主角：战后血量过低则脱离队伍
func should_auto_retreat(threshold: float = RosterHealth.RETREAT_HP_RATIO) -> bool:
	if not is_alive or is_retreated or is_near_death:
		return false
	if merc_type == MercType.PLAYER:
		return false
	return get_hp_ratio() <= threshold


func mark_retreated() -> void:
	is_retreated = true


func try_clear_retreat_on_full_heal() -> void:
	if is_alive and get_hp_ratio() >= 1.0:
		is_retreated = false
		is_near_death = false


func clamp_hp_to_max() -> void:
	if not is_alive:
		current_hp = 0
		return
	current_hp = mini(current_hp, get_max_hp_value())


func level_up() -> bool:
	if level >= max_level:
		return false
	level += 1
	refresh_base_stats()
	current_hp = StatResolver.get_max_hp(self)
	return true


## 获得经验并自动升级，返回升级次数
func add_exp(amount: int) -> int:
	return ExpSystem.grant_exp(self, amount).get("levels_gained", 0)


func _apply_growth() -> void:
	for key in growth_per_level:
		match key:
			"hp": hp += int(growth_per_level.hp)
			"patk": patk += int(growth_per_level.patk)
			"matk": matk += int(growth_per_level.matk)
			"pdef": pdef += int(growth_per_level.pdef)
			"mdef": mdef += int(growth_per_level.mdef)
			"spd": spd += int(growth_per_level.spd)
			"crit_chance": crit_chance += growth_per_level.crit_chance
			"dodge": dodge += growth_per_level.dodge
			"block_chance": block_chance += growth_per_level.block_chance


func equip(item) -> void:
	if item == null:
		return
	equipment_slots[item.slot] = item
	refresh_base_stats()


func unequip(slot: String) -> void:
	if not equipment_slots.has(slot):
		return
	equipment_slots[slot] = null
	refresh_base_stats()


## 按 template + level 重算基础属性（不写 final）
func refresh_base_stats() -> void:
	_recalc_stats_from_base()


func _recalc_stats_from_base() -> void:
	var tpl = DataLoader.merc_template(template_id)
	if tpl.is_empty() and merc_type == MercType.PLAYER:
		tpl = DataLoader.player_class(merc_class)
	if not tpl.is_empty():
		_apply_base(tpl.base_stats)
		for _i in range(1, level):
			_apply_growth()
		max_hp = hp


func take_damage(amount: int) -> bool:
	current_hp = max(0, current_hp - amount)
	if current_hp <= 0:
		enter_near_death_state(0.05)
		return true
	return false


## 复活角色 — 从死亡状态恢复，HP 回满
func revive(full_heal: bool = true) -> void:
	is_alive = true
	is_near_death = false
	is_retreated = false
	if full_heal:
		current_hp = StatResolver.get_max_hp(self)
	else:
		current_hp = max(1, int(StatResolver.get_max_hp(self) * 0.3))


## 进入濒死（战中倒下或撤离成功惩罚）
func enter_near_death_state(hp_ratio: float = 0.08) -> void:
	is_alive = true
	is_near_death = true
	var max_hp_val := StatResolver.get_max_hp(self)
	current_hp = maxi(1, int(float(max_hp_val) * hp_ratio))
	hp = current_hp


## 紧急撤离成功后的濒死惩罚
func apply_near_death_state(hp_ratio: float = 0.08) -> void:
	enter_near_death_state(hp_ratio)


## 撤离失败：永久死亡
func mark_permanent_death() -> void:
	is_near_death = false
	is_alive = false
	current_hp = 0
	hp = 0


## 是否死亡（濒死仍视为未永久死亡）
func is_dead() -> bool:
	return not is_alive


## 死亡状态显示名
func get_status_label() -> String:
	if is_dead():
		return "[死亡] %s Lv.%d" % [merc_name, level]
	if is_near_death:
		return "[濒死] %s Lv.%d HP:%d/%d" % [merc_name, level, current_hp, StatResolver.get_max_hp(self)]
	return "[存活] %s Lv.%d HP:%d/%d" % [merc_name, level, current_hp, StatResolver.get_max_hp(self)]


func get_display_class() -> String:
	match merc_type:
		MercType.PLAYER: return "主角·" + merc_class
		MercType.ELITE: return "精英·" + merc_class
		_: return "佣兵·" + merc_class
