extends Node
## SaveManager — 存档系统：多槽位 / 自动备份 / 加密 / 云预留

const SAVE_VERSION := 1
const AUTO_SAVE_INTERVAL := 30.0
const MAX_SLOTS := 3
const META_FILE := "user://save_meta.json"
const BACKUP_SUFFIX := ".bak"

# 简单 XOR 加密密钥（防随手改 JSON，非安全级加密）
const ENC_KEY := "TBH_Idle_RPG_Save_v1"

var current_slot: int = 1
var play_time: float = 0.0
var auto_save_timer: Timer = null
var _is_saving: bool = false

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)


func _ready() -> void:
	_load_meta()
	_setup_auto_save_timer()


func _process(delta: float) -> void:
	play_time += delta


# ─── 槽位管理 ──────────────────────────────────────────

func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


func _backup_path(slot: int) -> String:
	return _slot_path(slot) + BACKUP_SUFFIX


func _load_meta() -> void:
	if not FileAccess.file_exists(META_FILE):
		current_slot = 1
		return
	var f = FileAccess.open(META_FILE, FileAccess.READ)
	if f == null:
		return
	var text = f.get_as_text()
	f.close()
	var json = JSON.new()
	if json.parse(text) == OK:
		var data = json.data
		if data is Dictionary:
			current_slot = data.get("last_slot", 1)
			play_time = data.get("play_time", 0.0)


func _save_meta() -> void:
	var data = {
		"last_slot": current_slot,
		"play_time": play_time,
		"slots": _gather_slot_info()
	}
	var f = FileAccess.open(META_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func _gather_slot_info() -> Dictionary:
	var info = {}
	for i in range(1, MAX_SLOTS + 1):
		var path = _slot_path(i)
		if FileAccess.file_exists(path):
			var f = FileAccess.open(path, FileAccess.READ)
			if f:
				var text = f.get_as_text()
				f.close()
				var json = JSON.new()
				if json.parse(text) == OK and json.data is Dictionary:
					var h = json.data.get("header", {})
					info[str(i)] = {
						"timestamp": h.get("timestamp", ""),
						"version": h.get("version", 0),
						"play_time": h.get("play_time_seconds", 0)
					}
	return info


func get_slot_list() -> Array:
	var list = []
	for i in range(1, MAX_SLOTS + 1):
		var path = _slot_path(i)
		list.append({
			"slot": i,
			"exists": FileAccess.file_exists(path)
		})
	return list


func set_current_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, MAX_SLOTS)
	_save_meta()


# ─── 存档 ──────────────────────────────────────────────

func save_game(slot: int = -1) -> bool:
	if _is_saving:
		return false
	_is_saving = true
	
	if slot < 1:
		slot = current_slot
	
	var data = GameManager.to_save_dict()
	data["header"] = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"play_time_seconds": int(play_time)
	}
	
	var json_str = JSON.stringify(data, "\t")
	var encrypted = _encrypt(json_str)
	var path = _slot_path(slot)
	
	# 备份旧存档
	if FileAccess.file_exists(path):
		_backup_existing(path)
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_is_saving = false
		save_completed.emit(slot, false)
		return false
	
	f.store_string(encrypted)
	f.close()
	
	current_slot = slot
	_save_meta()
	_is_saving = false
	save_completed.emit(slot, true)
	return true


func load_game(slot: int = -1) -> bool:
	if slot < 1:
		slot = current_slot
	
	var path = _slot_path(slot)
	if not FileAccess.file_exists(path):
		load_completed.emit(slot, false)
		return false
	
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		load_completed.emit(slot, false)
		return false
	
	var encrypted = f.get_as_text()
	f.close()
	
	var json_str = _decrypt(encrypted)
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		# 尝试从备份恢复
		if _try_restore_backup(slot):
			return load_game(slot)
		load_completed.emit(slot, false)
		return false
	
	var data = json.data
	var header = data.get("header", {})
	if header.get("version", 0) > SAVE_VERSION:
		push_warning("SaveManager: 存档版本过新 (%d > %d)，可能不兼容" % [header.get("version"), SAVE_VERSION])
	
	GameManager.from_save_dict(data)
	play_time = float(header.get("play_time_seconds", 0))
	current_slot = slot
	_save_meta()
	load_completed.emit(slot, true)
	return true


func delete_save(slot: int) -> bool:
	print("[SaveManager] delete_save(%d): 开始彻底删除..." % slot)
	if auto_save_timer:
		auto_save_timer.stop()
	var path = _slot_path(slot)
	var backup = _backup_path(slot)
	var deleted_any = false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] delete_save: 已删除存档文件 %s" % path)
		deleted_any = true
	else:
		print("[SaveManager] delete_save: 存档文件不存在，跳过 %s" % path)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
		print("[SaveManager] delete_save: 已删除备份文件 %s" % backup)
		deleted_any = true
	if slot == current_slot:
		current_slot = 1
	_remove_slot_from_meta(slot)
	_save_meta()
	GameManager.reset_game_state()
	var verified = verify_save_deleted(slot)
	print("[SaveManager] delete_save: 完成, verified=%s, has_save=%s" % [verified, has_save(slot)])
	return deleted_any and verified


func verify_save_deleted(slot: int) -> bool:
	var main_exists = FileAccess.file_exists(_slot_path(slot))
	var backup_exists = FileAccess.file_exists(_backup_path(slot))
	print("[SaveManager] verify: 主文件=%s, 备份=%s → %s" % [
		"存在" if main_exists else "不存在",
		"存在" if backup_exists else "不存在",
		"通过" if (not main_exists and not backup_exists) else "失败"
	])
	return not main_exists and not backup_exists


func _remove_slot_from_meta(slot: int) -> void:
	if not FileAccess.file_exists(META_FILE):
		return
	var f = FileAccess.open(META_FILE, FileAccess.READ)
	if f == null:
		return
	var text = f.get_as_text()
	f.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if data is Dictionary and data.has("slots"):
		data["slots"].erase(str(slot))
		var fw = FileAccess.open(META_FILE, FileAccess.WRITE)
		if fw:
			fw.store_string(JSON.stringify(data, "\t"))
			fw.close()


func has_save(slot: int = -1) -> bool:
	if slot < 1:
		slot = current_slot
	return FileAccess.file_exists(_slot_path(slot))


# ─── 自动存档 ──────────────────────────────────────────

func _setup_auto_save_timer() -> void:
	auto_save_timer = Timer.new()
	auto_save_timer.name = "AutoSaveTimer"
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(_on_auto_save)
	add_child(auto_save_timer)


func _on_auto_save() -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		save_game()


func force_auto_save() -> void:
	save_game()


# ─── 数据收集 / 应用 ───────────────────────────────────
# 职权已移交 GameManager.to_save_dict() / GameManager.from_save_dict()
# SaveManager 仅负责文件 I/O、加密、备份恢复，不碰游戏数据结构


# ─── 备份与恢复 ────────────────────────────────────────

func _backup_existing(path: String) -> void:
	var backup_path = path + BACKUP_SUFFIX
	DirAccess.copy_absolute(path, backup_path)


func _try_restore_backup(slot: int) -> bool:
	var backup_path = _backup_path(slot)
	if not FileAccess.file_exists(backup_path):
		return false
	
	var main_path = _slot_path(slot)
	if FileAccess.file_exists(main_path):
		DirAccess.remove_absolute(main_path)
	DirAccess.copy_absolute(backup_path, main_path)
	push_warning("SaveManager: 存档损坏，已从备份恢复槽位 %d" % slot)
	return true


# ─── 加密 / 解密 ───────────────────────────────────────

func _encrypt(plain: String) -> String:
	var key_bytes = ENC_KEY.to_utf8_buffer()
	var data_bytes = plain.to_utf8_buffer()
	var result = PackedByteArray()
	result.resize(data_bytes.size())
	for i in range(data_bytes.size()):
		result[i] = data_bytes[i] ^ key_bytes[i % key_bytes.size()]
	return Marshalls.raw_to_base64(result)


func _decrypt(encoded: String) -> String:
	var data_bytes = Marshalls.base64_to_raw(encoded)
	var key_bytes = ENC_KEY.to_utf8_buffer()
	var plain = PackedByteArray()
	plain.resize(data_bytes.size())
	for i in range(data_bytes.size()):
		plain[i] = data_bytes[i] ^ key_bytes[i % key_bytes.size()]
	return plain.get_string_from_utf8()


# ─── 云存档预留 ────────────────────────────────────────

func get_cloud_payload() -> Dictionary:
	return GameManager.to_save_dict()


func apply_cloud_payload(payload: Dictionary) -> void:
	GameManager.from_save_dict(payload)
	save_game()
