extends SceneTree
## 生成测试用存档到 user://save_slot_1.json
## 运行: godot --headless --path <项目根> --script res://tools/generate_test_save.gd

const SLOT := 1


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	DataLoader.load_all()
	GameManager.reset_game_state()
	_populate_test_state()
	GameManager.state = GameManager.GameState.BASE
	SaveManager.current_slot = SLOT
	var ok: bool = SaveManager.save_game(SLOT)
	var user_path: String = ProjectSettings.globalize_path("user://")
	print("[generate_test_save] slot %d saved=%s" % [SLOT, ok])
	print("[generate_test_save] user dir: %s" % user_path)
	print("[generate_test_save] file: %ssave_slot_%d.json" % [user_path, SLOT])
	print("[generate_test_save] gold=%d elites=%d normals=%d inventory=%d maps=%d" % [
		GameManager.gold,
		GameManager.elite_roster.size(),
		GameManager.normal_roster.size(),
		GameManager.inventory.items.size(),
		GameManager.unlocked_maps.size(),
	])
	print("[generate_test_save] mia=%d dead=%d frozen_exp=%d" % [
		GameManager.get_mia_roster_entries().size(),
		_count_dead_fixtures(),
		GameManager.get_total_frozen_exp(),
	])
	quit(0 if ok else 1)


func _populate_test_state() -> void:
	GameManager.gold = 500000
	GameManager.team_stability = 100
	GameManager.selected_map_id = "grassland"
	GameManager.auto_run_preferred = false
	GameManager.last_deploy_half = "A"

	_set_buildings_for_test()
	_create_test_player()
	_spawn_test_roster()
	_seed_casualty_fixtures()
	_fill_test_inventory()
	_unlock_all_maps_for_test()
	_set_test_formation()
	SquadFormationService.ensure_formation(GameManager)


func _set_buildings_for_test() -> void:
	for bid in GameManager.buildings:
		GameManager.buildings[bid]["level"] = 5
	GameManager.refresh_map_unlocks()


func _create_test_player() -> void:
	var tpl: Dictionary = DataLoader.player_class("warrior")
	var p = Player.new()
	p.merc_name = "测试指挥官"
	p.init_from_template(tpl)
	p.level = 20
	p.exp = 0
	p.scar_stacks = 0
	p.is_near_death = false
	p.is_personal_break = false
	p.personal_stability = 100
	p.refresh_base_stats()
	_equip_generated(p, 4)
	p.clamp_hp_to_max()
	GameManager.player = p


func _spawn_test_roster() -> void:
	_spawn_elite("elite_01", "warrior_elite", 18)
	_spawn_elite("elite_02", "mage_elite", 18)
	_spawn_elite("elite_03", "ranger_elite", 18)
	_spawn_normal("normal_01", "warrior_normal", 15)
	_spawn_normal("normal_02", "mage_normal", 15)
	_spawn_normal("normal_03", "ranger_normal", 15)
	_spawn_normal("normal_04", "warrior_normal", 12)
	_spawn_normal("normal_05", "mage_normal", 12)


func _spawn_elite(merc_id: String, template_id: String, lvl: int) -> void:
	var tpl: Dictionary = DataLoader.merc_template(template_id)
	if tpl.is_empty():
		push_error("missing template %s" % template_id)
		return
	var m = EliteMercenary.new()
	m.merc_id = merc_id
	m.init_from_template(tpl)
	m.level = lvl
	m.scar_stacks = 0
	m.is_near_death = false
	m.is_personal_break = false
	m.personal_stability = 100
	m.refresh_base_stats()
	_equip_generated(m, 2)
	m.clamp_hp_to_max()
	GameManager.elite_roster.append(m)
	GameManager.player.add_to_roster(m)


func _spawn_normal(merc_id: String, template_id: String, lvl: int) -> void:
	var tpl: Dictionary = DataLoader.merc_template(template_id)
	if tpl.is_empty():
		push_error("missing template %s" % template_id)
		return
	var m = NormalMercenary.new()
	m.merc_id = merc_id
	m.init_from_template(tpl)
	m.level = lvl
	m.scar_stacks = 0
	m.is_near_death = false
	m.is_personal_break = false
	m.personal_stability = 100
	m.refresh_base_stats()
	_equip_generated(m, 1)
	m.clamp_hp_to_max()
	GameManager.normal_roster.append(m)
	GameManager.player.add_to_roster(m)


func _equip_generated(merc, count: int) -> void:
	var slots: Array[String] = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]
	var si := 0
	for i in range(count):
		if si >= slots.size():
			break
		var slot_name: String = slots[si]
		si += 1
		var q: int = 2 + (i % 3)
		var eq = Equipment.generate(slot_name, q, merc.level)
		if eq != null:
			merc.equipment_slots[slot_name] = eq
	EquipmentSystem.apply_to(merc)


func _fill_test_inventory() -> void:
	GameManager.inventory.clear()
	var slot_ids: Array[String] = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]
	for i in range(24):
		var slot_name: String = slot_ids[i % slot_ids.size()]
		var q: int = i % 6
		var eq = Equipment.generate(slot_name, q, 10 + i)
		if eq != null:
			GameManager.inventory.add(eq)


func _unlock_all_maps_for_test() -> void:
	GameManager.unlocked_maps.clear()
	for m in DataLoader.all_maps():
		var map_id: String = str(m.get("map_id", ""))
		if map_id != "" and map_id not in GameManager.unlocked_maps:
			GameManager.unlocked_maps.append(map_id)
	GameManager.sync_always_unlocked_maps()
	GameManager.defeated_map_bosses = ["grassland", "forest", "cave"]


func _seed_casualty_fixtures() -> void:
	## 正式佣兵 fixture：F5 回收 / 阵亡页手测（非 test_stand_in）
	_add_fixture_mia_elite(
		"fixture_mia_elite", "mage_elite", 12, "fixture·奥术遗留"
	)
	_add_fixture_mia_normal(
		"fixture_mia_normal", "warrior_normal", 10, "fixture·新兵遗留"
	)
	_add_fixture_dead_elite(
		"fixture_dead_elite", "ranger_elite", 15, "fixture·游侠阵亡"
	)
	_add_fixture_dead_normal(
		"fixture_dead_normal", "mage_normal", 8, "fixture·学徒阵亡"
	)
	GameManager.account_meta = SaveSerializer.normalize_account_meta(GameManager.account_meta)
	var pools: Array = GameManager.account_meta.get("frozen_exp_pools", [])
	pools.append({
		"run_id": "fixture_mia_pool_1",
		"map_id": "grassland",
		"total": 1200,
		"mia_count": 2,
		"field_count": 4,
		"mia_ratio": 0.5,
		"timestamp": int(Time.get_unix_time_from_system()),
		"member_ids": ["fixture_mia_elite", "fixture_mia_normal"],
	})
	GameManager.account_meta["frozen_exp_pools"] = pools
	GameManager.account_meta["seed_casualty_fixtures"] = true


func _add_fixture_mia_elite(merc_id: String, template_id: String, lvl: int, display_name: String) -> void:
	_spawn_elite(merc_id, template_id, lvl)
	var m := GameManager.find_mercenary_by_id(merc_id) as EliteMercenary
	if m == null:
		return
	m.merc_name = display_name
	m.enter_mia_state()


func _add_fixture_mia_normal(merc_id: String, template_id: String, lvl: int, display_name: String) -> void:
	_spawn_normal(merc_id, template_id, lvl)
	var m := GameManager.find_mercenary_by_id(merc_id) as NormalMercenary
	if m == null:
		return
	m.merc_name = display_name
	m.enter_mia_state()


func _add_fixture_dead_elite(merc_id: String, template_id: String, lvl: int, display_name: String) -> void:
	_spawn_elite(merc_id, template_id, lvl)
	var m := GameManager.find_mercenary_by_id(merc_id) as EliteMercenary
	if m == null:
		return
	m.merc_name = display_name
	m.is_dead_permanently = true
	m.mark_permanent_death()


func _add_fixture_dead_normal(merc_id: String, template_id: String, lvl: int, display_name: String) -> void:
	_spawn_normal(merc_id, template_id, lvl)
	var m := GameManager.find_mercenary_by_id(merc_id) as NormalMercenary
	if m == null:
		return
	m.merc_name = display_name
	m.mark_dead()


func _count_dead_fixtures() -> int:
	var n := 0
	for e in GameManager.elite_roster:
		if e != null and not e.is_alive and not e.is_test_stand_in:
			n += 1
	for m in GameManager.normal_roster:
		if m != null and not m.is_alive and not m.is_test_stand_in:
			n += 1
	return n


func _set_test_formation() -> void:
	GameManager.squad_formation = {
		"active_half": "A",
		"A": {
			"active": ["player_01", "elite_01", "elite_02", "elite_03"],
			"bench": ["normal_01", "normal_02"],
		},
		"B": {
			"active": ["normal_03", "normal_04"],
			"bench": ["normal_05"],
		},
	}
	GameManager.last_run_squad_snapshot = ["player_01", "elite_01", "elite_02", "elite_03"]
