extends Node
## GameManager — 全局状态机，管理 Base → Run → Result 循环

enum GameState { BASE, PREPARE, RUNNING, RESULT }

var state: int = GameState.BASE
var base_level: int = 1
var base_data: Dictionary = {}
var player: Player = null
var elite_roster: Array[EliteMercenary] = []
var normal_roster: Array[NormalMercenary] = []
var inventory: InventorySystem = InventorySystem.new()
var gold: int = 1000
var current_run: WorldRun = null
var unlocked_maps: Array[String] = ["grassland"]
var selected_map_id: String = "grassland"
var selected_squad: Array[Mercenary] = []
var buildings: Dictionary = {}
var rebirth_count: int = 0
var rebirth_bonus: float = 0.0
## 待发放奖励（end_run 写入，return_to_base 时 apply_run_rewards 消费）
var _pending_run_result: Dictionary = {}
var _run_rewards_applied: bool = false

signal state_changed(new_state: int)
signal gold_changed(amount: int)
signal squad_ready()
signal run_started()
signal run_ended(result: Dictionary)


func _ready() -> void:
	DataLoader.load_all()
	_init_buildings()
	
	# 有存档则读档，无存档留给 CharacterCreate 场景处理
	if SaveManager.has_save():
		SaveManager.load_game()
	else:
		state = GameState.BASE
		state_changed.emit(GameState.BASE)


func _init_buildings() -> void:
	buildings = {
		"barracks": {"level": 1, "building_id": "barracks"},
		"forge": {"level": 1, "building_id": "forge"},
		"infirmary": {"level": 1, "building_id": "infirmary"},
		"research_lab": {"level": 0, "building_id": "research_lab"},
		"warehouse": {"level": 1, "building_id": "warehouse"}
	}


func _create_player(pclass: String) -> void:
	var template = DataLoader.player_class(pclass)
	if template.is_empty():
		return
	player = Player.new()
	player.merc_id = "player_01"
	player.merc_name = "主角"
	player.init_from_template(template)


func start_prepare(map_id: String) -> void:
	selected_map_id = map_id
	state = GameState.PREPARE
	state_changed.emit(GameState.PREPARE)


func start_run() -> int:
	if selected_squad.is_empty():
		return -1
	var squad = Squad.new()
	squad.build(selected_squad)
	current_run = WorldRun.new(selected_map_id, squad)
	var ok = current_run.start()
	if ok != 0:
		return -2
	state = GameState.RUNNING
	run_started.emit()
	state_changed.emit(GameState.RUNNING)
	return 0


func end_run(forced_withdraw: bool = false) -> void:
	var result = current_run.end_run(forced_withdraw)
	_pending_run_result = result
	_run_rewards_applied = false
	state = GameState.RESULT
	state_changed.emit(GameState.RESULT)
	run_ended.emit(result)


## 将本次出征累计的金币与掉落写入全局状态（仅在此处发放）
func apply_run_rewards(result: Dictionary) -> void:
	if _run_rewards_applied:
		return
	var gold_earned: int = result.get("total_gold", 0)
	if gold_earned > 0:
		add_gold(gold_earned)
	for item in result.get("total_loot", []):
		if item is Equipment:
			inventory.add(item)
	_run_rewards_applied = true


func return_to_base() -> void:
	if not _pending_run_result.is_empty():
		apply_run_rewards(_pending_run_result)
	_pending_run_result = {}
	state = GameState.BASE
	if current_run:
		current_run = null
	selected_squad.clear()
	
	# 重置所有佣兵状态（HP + 存活标记）
	if player:
		player.reset_to_full_hp()
	for e in elite_roster:
		e.reset_to_full_hp()
	for n in normal_roster:
		n.reset_to_full_hp()
	
	state_changed.emit(GameState.BASE)
	if SaveManager and is_instance_valid(SaveManager):
		SaveManager.force_auto_save()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func upgrade_building(building_id: String) -> bool:
	if not buildings.has(building_id):
		return false
	var bdata = DataLoader.building_data(building_id)
	if bdata.is_empty():
		return false
	var b = buildings[building_id]
	var next_level = b.level + 1
	if next_level > bdata.max_level:
		return false
	var cost = bdata.upgrade_costs.gold[next_level - 1]
	if not spend_gold(cost):
		return false
	b.level = next_level
	return true


func get_building_level(building_id: String) -> int:
	if buildings.has(building_id):
		return buildings[building_id].level
	return 0


func get_max_elite_slots() -> int:
	var bdata = DataLoader.building_data("barracks")
	var lv = get_building_level("barracks")
	if bdata.has("effects"):
		return bdata.effects.elite_slots[lv - 1]
	return 1


func reset_game_state() -> void:
	print("[GameManager] reset_game_state: 清空所有运行时数据...")
	print("  player 清空前: %s" % (player.merc_name if player else "null"))
	
	player = null
	elite_roster.clear()
	normal_roster.clear()
	inventory.clear()
	gold = 1000
	current_run = null
	selected_squad.clear()
	buildings.clear()
	unlocked_maps = ["grassland"]
	selected_map_id = "grassland"
	rebirth_count = 0
	rebirth_bonus = 0.0
	state = GameState.BASE
	
	_init_buildings()
	
	print("  player 清空后: %s" % ("null" if player == null else player.merc_name))
	print("[GameManager] reset_game_state: 完成, state=%s" % state)


# ─── 序列化（to_save_dict / from_save_dict）────────────
# 所有权归 GameManager，SaveManager 只负责文件 I/O

func to_save_dict() -> Dictionary:
	return {
		"gold": gold,
		"rebirth_count": rebirth_count,
		"rebirth_bonus": rebirth_bonus,
		"unlocked_maps": unlocked_maps.duplicate(),
		"buildings": buildings.duplicate(),
		"player": _serialize_merc(player),
		"roster": {
			"elite": _serialize_merc_array(elite_roster),
			"normal": _serialize_merc_array(normal_roster)
		},
		"inventory": inventory.to_dict_array(),
		"cloud_reserved": {}
	}


func from_save_dict(data: Dictionary) -> void:
	gold = data.get("gold", 1000)
	rebirth_count = data.get("rebirth_count", 0)
	rebirth_bonus = data.get("rebirth_bonus", 0.0)
	unlocked_maps.assign(data.get("unlocked_maps", ["grassland"]))
	buildings = data.get("buildings", {})
	
	var pdata = data.get("player", {})
	if not pdata.is_empty():
		player = _deserialize_player(pdata)
	
	var roster = data.get("roster", {})
	elite_roster.clear()
	for edata in roster.get("elite", []):
		var m = _deserialize_elite(edata)
		if m:
			elite_roster.append(m)
	normal_roster.clear()
	for ndata in roster.get("normal", []):
		var m = _deserialize_normal(ndata)
		if m:
			normal_roster.append(m)
	
	inventory.from_dict_array(data.get("inventory", []))
	
	current_run = null
	selected_squad.clear()
	state = GameState.BASE


# ─── 内部序列化辅助 ────────────────────────────────────

func _serialize_merc(merc: Mercenary) -> Dictionary:
	if merc == null:
		return {}
	return {
		"merc_id": merc.merc_id,
		"merc_name": merc.merc_name,
		"merc_type": merc.merc_type,
		"merc_class": merc.merc_class,
		"level": merc.level,
		"exp": merc.exp,
		"max_level": merc.max_level,
		"hp": merc.hp,
		"max_hp": merc.max_hp,
		"current_hp": merc.current_hp,
		"is_alive": merc.is_alive,
		"patk": merc.patk,
		"matk": merc.matk,
		"pdef": merc.pdef,
		"mdef": merc.mdef,
		"spd": merc.spd,
		"crit_chance": merc.crit_chance,
		"dodge": merc.dodge,
		"block_chance": merc.block_chance,
		"attack_range": merc.attack_range,
		"attack_speed": merc.attack_speed,
		"equipment_slots": _serialize_equipment_slots(merc.equipment_slots),
		"passive_skills": merc.passive_skills.duplicate(),
		"buffs": merc.buff_system.to_dict_array(),
		"active_skills": merc.active_skills.duplicate(),
		"growth_per_level": merc.growth_per_level.duplicate(),
		"template_id": merc.template_id,
		"player_extra": _serialize_player_extra(merc)
	}


func _serialize_player_extra(merc: Mercenary) -> Dictionary:
	if not (merc is Player):
		return {}
	var p = merc as Player
	return {
		"base_exp_multiplier": p.base_exp_multiplier,
		"squad_stability_influence": p.squad_stability_influence,
		"owned_elite_ids": _extract_ids(p.owned_elite_roster),
		"owned_normal_ids": _extract_ids(p.owned_normal_roster)
	}


func _extract_ids(list: Array) -> Array:
	var ids: Array = []
	for m in list:
		if m is Mercenary:
			ids.append(m.merc_id)
	return ids


func _serialize_equipment_slots(slots: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot in slots:
		var eq = slots[slot]
		if eq is Equipment:
			result[slot] = eq.to_dict()
		else:
			result[slot] = null
	return result


func _serialize_merc_array(list: Array) -> Array:
	var result: Array = []
	for m in list:
		if m is Mercenary:
			result.append(_serialize_merc(m))
	return result


func _deserialize_player(data: Dictionary) -> Player:
	var p = Player.new()
	_apply_merc_data(p, data)
	var extra = data.get("player_extra", {})
	if not extra.is_empty():
		p.base_exp_multiplier = extra.get("base_exp_multiplier", 0.25)
		p.squad_stability_influence = extra.get("squad_stability_influence", 0.0)
	return p


func _deserialize_elite(data: Dictionary) -> EliteMercenary:
	var m = EliteMercenary.new()
	_apply_merc_data(m, data)
	return m


func _deserialize_normal(data: Dictionary) -> NormalMercenary:
	var m = NormalMercenary.new()
	_apply_merc_data(m, data)
	return m


func _apply_merc_data(merc: Mercenary, data: Dictionary) -> void:
	merc.merc_id = data.get("merc_id", "")
	merc.merc_name = data.get("merc_name", "")
	merc.merc_type = data.get("merc_type", Mercenary.MercType.NORMAL)
	merc.merc_class = data.get("merc_class", "")
	merc.level = data.get("level", 1)
	merc.exp = data.get("exp", 0)
	merc.max_level = data.get("max_level", 60)
	merc.current_hp = data.get("current_hp", 100)
	merc.is_alive = data.get("is_alive", true)
	merc.attack_range = data.get("attack_range", 50.0)
	merc.attack_speed = data.get("attack_speed", 1.0)
	merc.passive_skills = data.get("passive_skills", [])
	merc.active_skills = data.get("active_skills", [])
	merc.growth_per_level = data.get("growth_per_level", {})
	merc.template_id = data.get("template_id", "")
	
	var eq_data = data.get("equipment_slots", {})
	for slot in eq_data:
		if eq_data[slot] is Dictionary:
			merc.equipment_slots[slot] = Equipment.from_dict(eq_data[slot])
		else:
			merc.equipment_slots[slot] = null
	
	merc.buff_system.from_dict_array(data.get("buffs", []))
	EquipmentSystem.apply_to(merc)


func get_max_normal_slots() -> int:
	var bdata = DataLoader.building_data("barracks")
	var lv = get_building_level("barracks")
	if bdata.has("effects"):
		return bdata.effects.normal_slots[lv - 1]
	return 2


## 招募佣兵。type: "normal" 或 "elite"
## 返回值: 0=成功, -1=金币不足, -2=槽位已满, -3=模板池为空
func recruit_merc(merc_type: String) -> int:
	const NORMAL_COST := 100
	const ELITE_COST := 500
	
	var cost := ELITE_COST if merc_type == "elite" else NORMAL_COST
	if gold < cost:
		return -1
	
	# 收集该类型模板
	var pool: Array = []
	var all := DataLoader.all_merc_templates()
	for tpl in all:
		if tpl.get("type", "") == merc_type:
			pool.append(tpl)
	if pool.is_empty():
		return -3
	
	# 检查槽位
	if merc_type == "elite":
		if elite_roster.size() >= get_max_elite_slots():
			return -2
	else:
		if normal_roster.size() >= get_max_normal_slots():
			return -2
	
	# 扣钱
	spend_gold(cost)
	
	# 随机抽取模板并实例化
	var tpl: Dictionary = pool[randi() % pool.size()]
	var id_seed: int = int(Time.get_unix_time_from_system())
	
	if merc_type == "elite":
		var m := EliteMercenary.new()
		m.merc_id = "elite_%d_%d" % [id_seed, randi()]
		m.init_from_template(tpl)
		elite_roster.append(m)
	else:
		var m := NormalMercenary.new()
		m.merc_id = "normal_%d_%d" % [id_seed, randi()]
		m.init_from_template(tpl)
		normal_roster.append(m)
	
	return 0


## 解雇佣兵。返回 true 表示成功移除
func dismiss_merc(merc_type: String, merc_id: String) -> bool:
	if merc_type == "elite":
		for i in range(elite_roster.size()):
			if elite_roster[i].merc_id == merc_id:
				elite_roster.remove_at(i)
				return true
	else:
		for i in range(normal_roster.size()):
			if normal_roster[i].merc_id == merc_id:
				normal_roster.remove_at(i)
				return true
	return false


func can_go_next_frame() -> bool:
	return state == GameState.RUNNING
