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

# 基础属性
@export var hp: int = 0
@export var max_hp: int = 0
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
var is_retreated: bool = false
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
	current_hp = max_hp
	is_alive = true
	is_retreated = false


func level_up() -> bool:
	if level >= max_level:
		return false
	level += 1
	EquipmentSystem.apply_to(self)
	return true


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
	EquipmentSystem.apply_to(self)


func unequip(slot: String) -> void:
	if not equipment_slots.has(slot):
		return
	equipment_slots[slot] = null
	EquipmentSystem.apply_to(self)


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
		is_alive = false
		return true
	return false


## 复活角色 — 从死亡状态恢复，HP 回满
func revive(full_heal: bool = true) -> void:
	is_alive = true
	if full_heal:
		current_hp = max_hp
	else:
		current_hp = max(1, int(max_hp * 0.3))


## 是否死亡（显式语义，等同 not is_alive）
func is_dead() -> bool:
	return not is_alive


## 死亡状态显示名
func get_status_label() -> String:
	if is_dead():
		return "[死亡] %s Lv.%d" % [merc_name, level]
	else:
		return "[存活] %s Lv.%d HP:%d/%d" % [merc_name, level, current_hp, max_hp]


func get_display_class() -> String:
	match merc_type:
		MercType.PLAYER: return "主角·" + merc_class
		MercType.ELITE: return "精英·" + merc_class
		_: return "佣兵·" + merc_class
