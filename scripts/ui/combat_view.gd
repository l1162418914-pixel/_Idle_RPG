extends VBoxContainer
class_name CombatView
## CombatView — 战斗可视化层。通过 CombatController 信号驱动，
## 不修改任何战斗逻辑。支持 1~6 佣兵 vs 1~6 敌人。

var _combat: CombatController = null
var _unit_views: Dictionary = {}  # entity_id → UnitView
var _log_lines: Array[String] = []
var _log_queue: Array[String] = []
var _log_flush_timer: float = 0.0
var _log_paused: bool = false

@onready var ally_container: HBoxContainer = $BattlefieldHBox/AllyContainer
@onready var enemy_container: HBoxContainer = $BattlefieldHBox/EnemyContainer
@onready var battle_log: RichTextLabel = $BattleLog
@onready var btn_speed_normal: Button = $DebugToolbar/BtnSpeedNormal
@onready var btn_speed_slow: Button = $DebugToolbar/BtnSpeedSlow
@onready var btn_speed_very_slow: Button = $DebugToolbar/BtnSpeedVerySlow
@onready var btn_pause_log: Button = $DebugToolbar/BtnPauseLog
@onready var btn_resume_log: Button = $DebugToolbar/BtnResumeLog
@onready var debug_mode_label: Label = $DebugToolbar/DebugModeLabel


func _ready() -> void:
	set_process(true)
	if btn_speed_normal:
		btn_speed_normal.pressed.connect(_on_speed_normal)
	if btn_speed_slow:
		btn_speed_slow.pressed.connect(_on_speed_slow)
	if btn_speed_very_slow:
		btn_speed_very_slow.pressed.connect(_on_speed_very_slow)
	if btn_pause_log:
		btn_pause_log.pressed.connect(_on_pause_log)
	if btn_resume_log:
		btn_resume_log.pressed.connect(_on_resume_log)
	_refresh_debug_label()
	_refresh_speed_buttons()


func _process(delta: float) -> void:
	if visible and _combat != null and _combat.is_active:
		_refresh_all_hp_bars()
	if not visible or _log_paused or _log_queue.is_empty():
		return
	_log_flush_timer -= delta
	if _log_flush_timer > 0.0:
		return
	_log_flush_timer = BattleDebug.log_line_interval()
	_flush_one_log_line()


# ── 初始化 ──────────────────────────────────────────────

func init_for_combat(combat: CombatController) -> void:
	_combat = combat
	_connect_signals()
	visible = true
	show()
	_refresh_debug_label()


## 战斗已开始时补建可视化（防止 combat_started 早于连接触发）
func sync_from_active_combat() -> void:
	if _combat == null or not _combat.is_active:
		return
	visible = true
	show()
	if _unit_views.is_empty():
		_on_combat_started()
	else:
		_refresh_all_hp_bars()


func _connect_signals() -> void:
	if _combat == null:
		return
	_disconnect_all()
	_combat.combat_started.connect(_on_combat_started)
	_combat.attack_started.connect(_on_attack_started)
	_combat.damage_dealt.connect(_on_damage_dealt)
	_combat.entity_dead.connect(_on_entity_dead)
	_combat.combat_ended.connect(_on_combat_ended)
	_combat.skill_cast.connect(_on_skill_cast)


func _disconnect_all() -> void:
	if _combat == null:
		return
	if _combat.combat_started.is_connected(_on_combat_started):
		_combat.combat_started.disconnect(_on_combat_started)
	if _combat.attack_started.is_connected(_on_attack_started):
		_combat.attack_started.disconnect(_on_attack_started)
	if _combat.damage_dealt.is_connected(_on_damage_dealt):
		_combat.damage_dealt.disconnect(_on_damage_dealt)
	if _combat.entity_dead.is_connected(_on_entity_dead):
		_combat.entity_dead.disconnect(_on_entity_dead)
	if _combat.combat_ended.is_connected(_on_combat_ended):
		_combat.combat_ended.disconnect(_on_combat_ended)
	if _combat.skill_cast.is_connected(_on_skill_cast):
		_combat.skill_cast.disconnect(_on_skill_cast)


# ── 调试工具栏 ──────────────────────────────────────────

func _on_speed_normal() -> void:
	BattleDebug.current_speed_mode = BattleDebug.SpeedMode.NORMAL
	_refresh_speed_buttons()


func _on_speed_slow() -> void:
	BattleDebug.current_speed_mode = BattleDebug.SpeedMode.SLOW
	_refresh_speed_buttons()


func _on_speed_very_slow() -> void:
	BattleDebug.current_speed_mode = BattleDebug.SpeedMode.VERY_SLOW
	_refresh_speed_buttons()


func _on_pause_log() -> void:
	_log_paused = true


func _on_resume_log() -> void:
	_log_paused = false


func _refresh_speed_buttons() -> void:
	var mode := BattleDebug.current_speed_mode
	if btn_speed_normal:
		btn_speed_normal.disabled = mode == BattleDebug.SpeedMode.NORMAL
	if btn_speed_slow:
		btn_speed_slow.disabled = mode == BattleDebug.SpeedMode.SLOW
	if btn_speed_very_slow:
		btn_speed_very_slow.disabled = mode == BattleDebug.SpeedMode.VERY_SLOW


func _refresh_debug_label() -> void:
	if debug_mode_label == null:
		return
	if BattleDebug.is_enabled():
		debug_mode_label.text = "测试模式 ON (HP×5 / 伤害×0.3)"
		debug_mode_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		debug_mode_label.text = "正式数值"
		debug_mode_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


# ── 信号处理 ────────────────────────────────────────────

func _on_combat_started() -> void:
	_build_unit_views()
	clear_log()
	_log_paused = false
	_enqueue_log("[color=orange]战斗开始![/color]")


func _on_skill_cast(_caster_id: String, _skill_id: String, skill_name: String, log_text: String) -> void:
	var caster_view: UnitView = _unit_views.get(_caster_id, null)
	if caster_view:
		caster_view.play_attack_flash()
	if log_text != "":
		_enqueue_log("[color=cyan]【%s】[/color] %s" % [skill_name, log_text])
	else:
		_enqueue_log("[color=cyan]【%s】[/color]" % skill_name)
	_refresh_all_hp_bars()


func _refresh_all_hp_bars() -> void:
	for eid in _unit_views:
		var entity := _find_entity(eid)
		if entity:
			_unit_views[eid].update_hp(entity.current_hp, entity.max_hp)


func _on_attack_started(attacker_id: String, target_id: String) -> void:
	var attacker_view: UnitView = _unit_views.get(attacker_id, null)
	if attacker_view:
		attacker_view.play_attack_flash()

	var a_name := _short_name(attacker_id)
	var t_name := _short_name(target_id)
	_enqueue_log("%s → %s" % [a_name, t_name])


func _on_damage_dealt(attacker_id: String, target_id: String, damage: int) -> void:
	var target_view: UnitView = _unit_views.get(target_id, null)
	if target_view:
		target_view.play_hit_flash()
		target_view.show_damage_number(damage)
		var entity := _find_entity(target_id)
		if entity:
			target_view.update_hp(entity.current_hp, entity.max_hp)
			if entity.is_downed():
				target_view.set_downed_visual()

	if damage == 0:
		_enqueue_log("[color=gray]%s 攻击 %s — 闪避/格挡[/color]" % [_short_name(attacker_id), _short_name(target_id)])
	else:
		_enqueue_log("[color=red]%s[/color] → [color=orange]%s[/color] [color=red]%d[/color]" % [_short_name(attacker_id), _short_name(target_id), damage])


func _on_entity_dead(entity: CombatEntity) -> void:
	if entity.is_downed():
		var downed_view: UnitView = _unit_views.get(entity.entity_id, null)
		if downed_view:
			downed_view.set_downed_visual()
		_enqueue_log("[color=gray]%s 陷入濒死[/color]" % _entity_display(entity))
		return
	var view: UnitView = _unit_views.get(entity.entity_id, null)
	if view:
		view.play_death()
		_unit_views.erase(entity.entity_id)
	_enqueue_log("[color=darkred]%s 阵亡![/color]" % _entity_display(entity))


func _on_combat_ended(victory: bool) -> void:
	if victory:
		_enqueue_log("[color=green]胜利![/color]")
	else:
		_enqueue_log("[color=red]全灭...[/color]")
	if _combat:
		for line in _combat.get_battle_stats_lines():
			_enqueue_log(line)


# ── 内部方法 ────────────────────────────────────────────

func _resolve_ally_container() -> HBoxContainer:
	if ally_container:
		return ally_container
	return get_node_or_null("BattlefieldHBox/AllyContainer") as HBoxContainer


func _resolve_enemy_container() -> HBoxContainer:
	if enemy_container:
		return enemy_container
	return get_node_or_null("BattlefieldHBox/EnemyContainer") as HBoxContainer


func _build_unit_views() -> void:
	var allies_box := _resolve_ally_container()
	var enemies_box := _resolve_enemy_container()
	if allies_box:
		for child in allies_box.get_children():
			child.queue_free()
	if enemies_box:
		for child in enemies_box.get_children():
			child.queue_free()
	_unit_views.clear()

	if _combat == null:
		return

	for entity in _combat.allies:
		var view := UnitView.new()
		view.setup(entity)
		if allies_box:
			allies_box.add_child(view)
		_unit_views[entity.entity_id] = view

	for entity in _combat.enemies:
		var view := UnitView.new()
		view.setup(entity)
		if enemies_box:
			enemies_box.add_child(view)
		_unit_views[entity.entity_id] = view


func _find_entity(entity_id: String) -> CombatEntity:
	if _combat == null:
		return null
	for e in _combat.allies:
		if e.entity_id == entity_id:
			return e
	for e in _combat.enemies:
		if e.entity_id == entity_id:
			return e
	return null


func _entity_display(entity: CombatEntity) -> String:
	if entity.display_name != "":
		return entity.display_name
	return _short_name(entity.entity_id)


func _short_name(entity_id: String) -> String:
	var entity := _find_entity(entity_id)
	if entity and entity.display_name != "":
		return entity.display_name
	if entity_id.begins_with("ally_player"):
		return "主角"
	if entity_id.begins_with("ally_"):
		return entity_id.replace("ally_", "")
	if "boss" in entity_id:
		return "[Boss]" + entity_id.replace("boss_", "")
	return entity_id.replace("enemy_", "").split("_")[0]


func _enqueue_log(text: String) -> void:
	_log_queue.append(text)


func _flush_one_log_line() -> void:
	if _log_queue.is_empty():
		return
	var line: String = _log_queue.pop_front()
	if _log_lines.size() >= 50:
		_log_lines.pop_front()
	_log_lines.append(line)
	if battle_log:
		battle_log.text = "\n".join(_log_lines)
		battle_log.scroll_to_line(battle_log.get_line_count() - 1)


func clear_log() -> void:
	_log_lines.clear()
	_log_queue.clear()
	_log_flush_timer = 0.0
	if battle_log:
		battle_log.clear()


# ── 清理 ────────────────────────────────────────────────

## 返程中战斗结束：保留面板可见，仅清单位，下一场接战会重建
func prepare_between_encounters() -> void:
	_disconnect_all()
	_combat = null
	for view in _unit_views.values():
		if is_instance_valid(view):
			view.queue_free()
	_unit_views.clear()
	visible = true
	show()


func cleanup() -> void:
	_disconnect_all()
	_combat = null
	for view in _unit_views.values():
		if is_instance_valid(view):
			view.queue_free()
	_unit_views.clear()
	visible = false
