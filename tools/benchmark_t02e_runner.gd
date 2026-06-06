extends Node
## godot --headless --path <项目根> --scene res://tools/BenchmarkT02e.tscn

const MAP_ID := "test_06_near_death_duo"
const MAX_SIM_SEC := 420.0
const DT := 1.0 / 60.0

var _combat: CombatController = null
var _in_combat := false
var _pending_enemies: Array = []
var _sim_time := 0.0
var _combat_count := 0
var _retreat_combat_count := 0
var _combat_start := 0.0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DataLoader.load_all()
	_setup_t02e_state()
	TestScenarioService.apply_on_prepare(GameManager, MAP_ID)
	GameManager.selected_map_id = MAP_ID
	var err: int = GameManager.start_run()
	if err != 0:
		push_error("start_run failed: %d" % err)
		get_tree().quit(1)
		return
	var run: WorldRun = GameManager.current_run
	print("[T-02e benchmark] map mult=%s decay=%s squad=%d" % [
		run.map_data.get("enemy_stat_mult"),
		run.map_data.get("stability_decay_mult"),
		run.squad.members.size(),
	])
	while _sim_time < MAX_SIM_SEC and run != null and run.is_active:
		var world_tick: bool = run.is_retreating or not _in_combat
		if world_tick:
			_tick_world(run)
		if _in_combat:
			_tick_combat(run, world_tick)
		_sim_time += DT
	if GameManager.state != GameManager.GameState.RESULT:
		GameManager.end_run(false)
	var ok: bool = _sim_time >= 180.0 and _sim_time <= 300.0
	print("[T-02e benchmark] sim_sec=%.1f (%.1f min) combats=%d retreat_combats=%d ok_3_5min=%s" % [
		_sim_time,
		_sim_time / 60.0,
		_combat_count,
		_retreat_combat_count,
		ok,
	])
	get_tree().quit(0 if ok else 2)


func _setup_t02e_state() -> void:
	GameManager.reset_game_state()
	GameManager.gold = 500000
	GameManager.team_stability = 100
	GameManager.auto_run_preferred = false
	for bid in GameManager.buildings:
		GameManager.buildings[bid]["level"] = 5
	GameManager.refresh_map_unlocks()
	var p := Player.new()
	p.merc_id = "player_01"
	GameManager.player = p
	_create_merc(p, "warrior", "", 15, 2, 2)
	p.merc_name = "测试指挥官"
	p.passive_skills = ["toughness"]
	p.active_skills = ["taunt"]
	GameManager.elite_roster.clear()
	GameManager.normal_roster.clear()
	_add_elite("elite_01", "warrior_elite", 15)
	_add_elite("elite_02", "mage_elite", 15)
	_add_elite("elite_03", "ranger_elite", 15)
	GameManager.unlocked_maps.clear()
	for m in DataLoader.all_maps():
		var id: String = str(m.get("map_id", ""))
		if id != "":
			GameManager.unlocked_maps.append(id)
	SquadFormationService.ensure_formation(GameManager)


func _create_merc(merc: Mercenary, cls: String, tpl: String, lvl: int, eq_n: int, eq_q: int) -> void:
	if merc is Player:
		var pt: Dictionary = DataLoader.player_class(cls)
		(merc as Player).init_from_template(pt)
	else:
		var mt: Dictionary = DataLoader.merc_template(tpl)
		merc.init_from_template(mt)
	merc.level = lvl
	merc.refresh_base_stats()
	var slots: Array[String] = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]
	for i in range(mini(eq_n, slots.size())):
		var eq: Equipment = Equipment.generate(slots[i], eq_q, lvl)
		if eq != null:
			merc.equipment_slots[slots[i]] = eq
	EquipmentSystem.apply_to(merc)
	merc.clamp_hp_to_max()


func _add_elite(merc_id: String, tpl: String, lvl: int) -> void:
	var m := EliteMercenary.new()
	m.merc_id = merc_id
	_create_merc(m, "", tpl, lvl, 2, 2)
	GameManager.elite_roster.append(m)
	GameManager.player.add_to_roster(m)


func _tick_world(run: WorldRun) -> void:
	var result: Dictionary = run.tick(DT)
	for ev in result.get("events", []):
		if ev.type == "enemy_spawn" or ev.type == "boss":
			_pending_enemies.append(ev.data)
			var min_n := 1 if run.is_retreating or GameManager.auto_run_enabled else 2
			if _pending_enemies.size() >= min_n or ev.data.get("is_boss", false):
				_start_combat(run)
	if run.is_retreating and run.has_completed_retreat():
		GameManager.end_run(true)
		return
	if run.stability and run.stability.should_withdraw() and not run.is_retreating:
		print("[T-02e benchmark] forced_retreat dist=%.0f stab=%d" % [
			run.distance_traveled, run.stability.team_stability
		])
		run.begin_retreat("forced")


func _start_combat(run: WorldRun) -> void:
	if _pending_enemies.is_empty() or _in_combat:
		return
	_combat = CombatController.new()
	_combat.init_combat(run.squad, _pending_enemies, run)
	_combat_start = _sim_time
	if _combat_count == 0:
		for a in _combat.allies:
			print("[T-02e benchmark] ally %s hp=%d/%d patk=%d downed=%s" % [
				a.entity_id, a.current_hp, a.max_hp, a.patk, a.is_downed()
			])
		if not _combat.enemies.is_empty():
			var e0 = _combat.enemies[0]
			print("[T-02e benchmark] first_enemy hp=%d patk=%d n=%d" % [
				e0.max_hp, e0.patk, _combat.enemies.size()
			])
	_in_combat = true
	_combat_count += 1
	if run.is_retreating:
		_retreat_combat_count += 1


func _tick_combat(run: WorldRun, world_already: bool) -> void:
	if _combat == null:
		_in_combat = false
		return
	if run.is_retreating:
		_combat.set_march_retreat_combat(true)
	var cd: float = DT * BattleDebug.get_time_scale()
	if not world_already and run.stability:
		run.stability.tick(cd)
	var result: Dictionary = _combat.tick(cd)
	if result.status == "victory":
		print("[T-02e benchmark] combat_win dur=%.1fs retreat=%s" % [
			_sim_time - _combat_start, run.is_retreating
		])
		_in_combat = false
		for e_data in _pending_enemies:
			run.register_enemy_defeat(e_data)
		_pending_enemies.clear()
		_combat.sync_allies_hp_to_mercs()
		_combat = null
	elif result.status == "defeat":
		print("[T-02e benchmark] combat_defeat dur=%.1fs" % (_sim_time - _combat_start))
		_in_combat = false
		_pending_enemies.clear()
		if _combat:
			_combat.sync_allies_hp_to_mercs()
			_combat.force_end()
			_combat = null
		if run.squad and run.squad.has_anyone_alive():
			if not run.is_retreating:
				run.begin_retreat("emergency")
		else:
			GameManager.end_run(false)
