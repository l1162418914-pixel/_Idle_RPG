extends Resource
class_name Mercenary
## 佣兵基类 — 所有佣兵共享的属性、装备、技能接口

const _BuffSystemLib = preload("res://scripts/buff/buff_system.gd")
const _StatResolver = preload("res://scripts/stats/stat_resolver.gd")
const _StabilitySystem = preload("res://scripts/run/stability_system.gd")
const _RosterHealth = preload("res://scripts/roster/roster_health.gd")
const _ExpSystem = preload("res://scripts/progression/exp_system.gd")

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
var buff_system = _BuffSystemLib.new()

# 出征临时状态
var current_hp: int = 0
var is_alive: bool = true
## 濒死：仍算存活、可触发撤离；无法攻击与移动；撤离失败才转为永久死亡
var is_near_death: bool = false
## 失踪（MIA / 战场遗留）；名册可见，不可编入出征
var is_mia: bool = false
## 测试图注入佣兵：锁定，不受伤/濒死/MIA/永久死亡（不写入存档）
var is_test_stand_in: bool = false
var is_retreated: bool = false
## 个人稳定度过低，无法出征直至基地恢复
var is_personal_break: bool = false
var personal_stability: int = 100
var run_kills: int = 0
var run_damage_dealt: int = 0
## 伤痕层数（每次进入濒死 +1）
var scar_stacks: int = 0
## 濒死护盾（本趟临时，不写入存档；T-MIA-P3 二段死亡）
var near_death_shield: int = 0
## 搀扶者 merc_id（本趟临时）
var supported_by_id: String = ""
## 本趟是否已触发绝境觉醒
var run_awaken_used: bool = false
var is_awakening: bool = false
var awakening_time_left: float = 0.0
var awakening_variant_id: String = ""


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
	
	personal_stability = _StabilitySystem.MAX_STABILITY
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
	current_hp = _StatResolver.get_max_hp(self)
	is_alive = true
	is_near_death = false
	is_retreated = false


func get_max_hp_value() -> int:
	return _StatResolver.get_max_hp(self)


func get_hp_ratio() -> float:
	var max_v: int = get_max_hp_value()
	if max_v <= 0:
		return 0.0
	return float(current_hp) / float(max_v)


func modify_personal_stability(delta: int) -> void:
	var was: int = personal_stability
	personal_stability = clampi(personal_stability + delta, 0, _StabilitySystem.MAX_STABILITY)
	if personal_stability > _StabilitySystem.PERSONAL_BREAK_THRESHOLD:
		try_clear_personal_break()
	elif was > 0 and personal_stability == 0:
		_try_pressure_zero_near_death()


func _try_pressure_zero_near_death() -> void:
	if not is_alive or is_near_death or is_mia or is_test_stand_in:
		return
	if GameManager.state == GameManager.GameState.RUNNING and GameManager.current_run != null:
		if PressureOutcomeService.try_single_pressure_substitute(GameManager.current_run, self):
			return
		enter_near_death_state(0.05)
	elif personal_stability <= _StabilitySystem.PERSONAL_BREAK_THRESHOLD:
		is_personal_break = true


func is_personal_stability_ok() -> bool:
	return personal_stability > _StabilitySystem.PERSONAL_BREAK_THRESHOLD


func is_test_roster_locked() -> bool:
	return is_test_stand_in


## 是否可编入出征队
## 停尸间待医疗（救援队运回，非 MIA）
var is_morgue_pending: bool = false
## 救援队失败养伤 CD 截止 unix 时间戳（B-12f）
var rescue_injury_cd_until: int = 0


func is_on_rescue_injury_cd() -> bool:
	return rescue_injury_cd_until > Time.get_unix_time_from_system()


func apply_rescue_injury_cd(duration_sec: int) -> void:
	rescue_injury_cd_until = Time.get_unix_time_from_system() + maxi(1, duration_sec)
	is_alive = true
	is_mia = false
	is_near_death = false
	current_hp = maxi(1, int(float(get_max_hp_value()) * 0.35))


func enter_morgue_pending() -> void:
	if merc_type == MercType.PLAYER:
		return
	is_morgue_pending = true
	is_mia = false
	is_near_death = false
	is_alive = false
	current_hp = 0


func clear_morgue_pending() -> void:
	is_morgue_pending = false


func can_join_squad() -> bool:
	if is_test_stand_in:
		return (
			is_alive
			and not is_mia
			and not is_retreated
			and not is_personal_break
			and is_personal_stability_ok()
		)
	if is_morgue_pending or is_on_rescue_injury_cd():
		return false
	try_clear_near_death_for_deploy()
	return is_alive and not is_mia and not is_near_death and not is_retreated and not is_personal_break and is_personal_stability_ok()


func try_clear_near_death_for_deploy() -> void:
	if not is_alive or not is_near_death:
		return
	if get_hp_ratio() >= _RosterHealth.DEPLOY_HP_RATIO:
		is_near_death = false


func _scars_cfg() -> Dictionary:
	return DataLoader.near_death_config().get("scars", {})


func get_scar_stack_cap() -> int:
	return maxi(1, int(_scars_cfg().get("max_stacks", 8)))


func _effective_scar_stacks() -> int:
	return mini(scar_stacks, get_scar_stack_cap())


func get_scar_hp_mult() -> float:
	var cfg: Dictionary = _scars_cfg()
	var per: float = float(cfg.get("hp_penalty_per_stack", 0.03))
	var floor_m: float = float(cfg.get("min_mult", 0.7))
	return maxf(floor_m, 1.0 - per * float(_effective_scar_stacks()))


func get_scar_atk_mult() -> float:
	var cfg: Dictionary = _scars_cfg()
	var per: float = float(cfg.get("atk_penalty_per_stack", 0.02))
	var floor_m: float = float(cfg.get("min_mult", 0.7))
	return maxf(floor_m, 1.0 - per * float(_effective_scar_stacks()))


## 稳定度受伤额外倍率（≥1，层数越高掉得越快）
func get_scar_stability_loss_mult() -> float:
	var cfg: Dictionary = _scars_cfg()
	var per: float = float(cfg.get("stability_loss_per_stack", 0.04))
	return 1.0 + per * float(_effective_scar_stacks())


func get_scar_stat_mult() -> float:
	return get_scar_hp_mult()


func get_scar_effect_summary() -> String:
	if scar_stacks <= 0:
		return ""
	var hp_pct: int = int((1.0 - get_scar_hp_mult()) * 100.0)
	var atk_pct: int = int((1.0 - get_scar_atk_mult()) * 100.0)
	return "生命-%d%% 攻-%d%% 易损稳定" % [hp_pct, atk_pct]


func add_scar_stack() -> void:
	scar_stacks = mini(get_scar_stack_cap(), scar_stacks + 1)


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
	return personal_stability <= _StabilitySystem.PERSONAL_BREAK_THRESHOLD


## 非主角：战后血量过低则脱离队伍
func should_auto_retreat(threshold: float = _RosterHealth.RETREAT_HP_RATIO) -> bool:
	if not is_alive or is_retreated or is_near_death:
		return false
	if merc_type == MercType.PLAYER:
		return false
	return get_hp_ratio() <= threshold


func mark_retreated() -> void:
	if is_test_stand_in:
		return
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
	current_hp = _StatResolver.get_max_hp(self)
	return true


## 获得经验并自动升级，返回升级次数
func add_exp(amount: int) -> int:
	return _ExpSystem.grant_exp(self, amount).get("levels_gained", 0)


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
		current_hp = _StatResolver.get_max_hp(self)
	else:
		current_hp = max(1, int(_StatResolver.get_max_hp(self) * 0.3))


## 进入濒死（战中倒下或撤离成功惩罚）
func enter_near_death_state(hp_ratio: float = 0.08) -> void:
	var was_near: bool = is_near_death
	is_alive = true
	is_near_death = true
	is_mia = false
	if not was_near:
		add_scar_stack()
		_grant_near_death_shield()
	var max_hp_val := _StatResolver.get_max_hp(self)
	current_hp = maxi(1, int(float(max_hp_val) * hp_ratio))
	personal_stability = _near_death_pressure_lock()


func _near_death_pressure_lock() -> int:
	var cfg: Dictionary = DataLoader.near_death_config().get("downed_shield", {})
	return maxi(1, int(cfg.get("pressure_lock", 1)))


func _grant_near_death_shield() -> void:
	var cfg: Dictionary = DataLoader.near_death_config().get("downed_shield", {})
	if not bool(cfg.get("enabled", true)):
		near_death_shield = 0
		return
	near_death_shield = maxi(0, int(cfg.get("base_amount", 80)))


func absorb_near_death_shield_damage(amount: int) -> int:
	if amount <= 0 or near_death_shield <= 0:
		return amount
	var absorbed: int = mini(near_death_shield, amount)
	near_death_shield -= absorbed
	return amount - absorbed


func is_near_death_shield_broken() -> bool:
	var cfg: Dictionary = DataLoader.near_death_config().get("downed_shield", {})
	if not bool(cfg.get("enabled", true)):
		return true
	return near_death_shield <= 0


## 濒死护盾击破后再受击 → 进 MIA（主角永不 MIA）
func try_enter_mia_from_downed_kill() -> bool:
	if merc_type == MercType.PLAYER or is_mia or is_test_stand_in:
		return false
	if not is_near_death or not is_near_death_shield_broken():
		return false
	enter_mia_state()
	return true


## 紧急撤离成功后的濒死惩罚
func apply_near_death_state(hp_ratio: float = 0.08) -> void:
	enter_near_death_state(hp_ratio)


## 进入 MIA（战场遗留）；与濒死互斥，非永久死亡
func enter_mia_state() -> void:
	if merc_type == MercType.PLAYER:
		return
	is_alive = true
	is_near_death = false
	is_mia = true
	near_death_shield = 0
	current_hp = 1


func clear_mia_state() -> void:
	is_mia = false


## 撤离失败：永久死亡
func mark_permanent_death() -> void:
	if is_test_stand_in:
		return
	is_near_death = false
	is_mia = false
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
	if is_mia:
		return "[遗留] %s Lv.%d" % [merc_name, level]
	if is_near_death:
		var scar_hint := " 伤×%d" % scar_stacks if scar_stacks > 0 else ""
		return "[濒死] %s Lv.%d HP:%d/%d%s" % [
			merc_name, level, current_hp, _StatResolver.get_max_hp(self), scar_hint
		]
	return "[存活] %s Lv.%d HP:%d/%d" % [merc_name, level, current_hp, _StatResolver.get_max_hp(self)]


func get_display_class() -> String:
	match merc_type:
		MercType.PLAYER: return "主角·" + merc_class
		MercType.ELITE: return "精英·" + merc_class
		_: return "佣兵·" + merc_class
