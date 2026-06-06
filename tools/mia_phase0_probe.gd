extends Node
## T-MIA-0 存档桩核对 — godot --headless --path <根> --scene res://tools/MiaPhase0Probe.tscn

var _failed: Array[String] = []
var _passed: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DataLoader.load_all()
	_probe_0_2_new_save_fields()
	_probe_0_2_legacy_load()
	_probe_0_2_is_mia_roundtrip()
	_probe_0_3_run_mode_normal()
	_probe_0_4_settlement_tier_stubs()
	_print_report()
	get_tree().quit(1 if not _failed.is_empty() else 0)


func _probe_0_2_new_save_fields() -> void:
	GameManager.account_meta = SaveSerializer.default_account_meta()
	GameManager.rescue_squad = SaveSerializer.default_rescue_squad()
	var data: Dictionary = SaveSerializer.to_save_dict(GameManager)
	if not data.has("account_meta"):
		_fail("0-2a", "to_save_dict 缺 account_meta")
		return
	if not data.has("rescue_squad"):
		_fail("0-2a", "to_save_dict 缺 rescue_squad")
		return
	var meta: Dictionary = data["account_meta"]
	if not meta.has("frozen_exp_pools"):
		_fail("0-2a", "account_meta 缺 frozen_exp_pools")
		return
	var squad: Dictionary = data["rescue_squad"]
	if not squad.has("active") or not squad.has("bench"):
		_fail("0-2a", "rescue_squad 缺 active/bench")
		return
	_pass("0-2a", "新档含 account_meta + rescue_squad")


func _probe_0_2_legacy_load() -> void:
	var legacy := {
		"gold": 1000,
		"player": {},
		"roster": {"elite": [], "normal": []},
		"inventory": [],
		"buildings": {},
		"unlocked_maps": ["grassland"],
		"squad_formation": {},
	}
	SaveSerializer.from_save_dict(GameManager, legacy)
	var meta: Dictionary = GameManager.account_meta
	if not meta.has("frozen_exp_pools"):
		_fail("0-2b", "旧档读入后 account_meta 未 normalize")
		return
	if not GameManager.rescue_squad.has("active"):
		_fail("0-2b", "旧档读入后 rescue_squad 未 normalize")
		return
	_pass("0-2b", "旧档无 MIA 键读档不崩 + 补默认")


func _probe_0_2_is_mia_roundtrip() -> void:
	var merc := NormalMercenary.new()
	merc.merc_id = "phase0_mia"
	merc.merc_name = "桩"
	merc.template_id = "warrior_normal"
	merc.level = 1
	merc.refresh_base_stats()
	merc.enter_mia_state()
	var blob: Dictionary = SaveSerializer.serialize_merc(merc)
	if not bool(blob.get("is_mia", false)):
		_fail("0-2c", "serialize 应含 is_mia=true")
		return
	var restored := SaveSerializer.deserialize_normal(blob)
	if restored == null or not restored.is_mia:
		_fail("0-2c", "deserialize 后 is_mia 应保持 true")
		return
	var legacy_merc := {"merc_id": "legacy_m", "merc_name": "旧", "level": 1, "is_alive": true}
	var legacy_norm := SaveSerializer.deserialize_normal(legacy_merc)
	if legacy_norm.is_mia:
		_fail("0-2c", "缺 is_mia 键应默认 false")
		return
	_pass("0-2c", "Mercenary.is_mia 序列化往返 + 缺键默认 false")


func _probe_0_3_run_mode_normal() -> void:
	var run := WorldRun.new("grassland", null)
	if run.run_mode != WorldRun.RunMode.NORMAL:
		_fail("0-3", "默认 run_mode 应为 NORMAL (got %d)" % run.run_mode)
		return
	run.retreat_reason = ""
	run.squad_wiped = false
	if run._resolve_settlement_tier(false) != "success":
		_fail("0-3", "NORMAL 未灭团 tier 应为 success")
		return
	_pass("0-3", "WorldRun.run_mode 默认 NORMAL · 出征桩不变")


func _probe_0_4_settlement_tier_stubs() -> void:
	var run := WorldRun.new("grassland", null)
	run.squad_wiped = true
	if run._resolve_settlement_tier(false) != "mia":
		_fail("0-4", "灭团 tier 应为 mia")
		return
	run = WorldRun.new("grassland", null)
	run.retreat_reason = "manual"
	if run._resolve_settlement_tier(true) != "manual":
		_fail("0-4", "manual tier 应为 manual")
		return
	run = WorldRun.new("grassland", null)
	run.run_mode = WorldRun.RunMode.RECOVERY
	run.max_distance = 72.0
	run.distance_traveled = 72.0
	if run._resolve_settlement_tier(false) != "recovery":
		_fail("0-4", "回收抵点 tier 应为 recovery")
		return
	_pass("0-4", "settlement_tier 桩：success/mia/manual/recovery")


func _pass(id: String, detail: String) -> void:
	_passed.append("%s: %s" % [id, detail])
	print("[PASS] %s — %s" % [id, detail])


func _fail(id: String, detail: String) -> void:
	_failed.append("%s: %s" % [id, detail])
	push_error("[FAIL] %s — %s" % [id, detail])


func _print_report() -> void:
	print("—— T-MIA-0 存档桩探针 ——")
	print("PASS: %d" % _passed.size())
	for line in _passed:
		print("  ", line)
	if not _failed.is_empty():
		print("FAIL: %d" % _failed.size())
		for line in _failed:
			print("  ", line)
	else:
		print("ALL T-MIA-0 PROBES PASSED")
