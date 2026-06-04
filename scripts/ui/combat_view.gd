extends VBoxContainer
class_name CombatView
## CombatView — 战斗可视化层。通过 CombatController 信号驱动，
## 不修改任何战斗逻辑。支持 1~6 佣兵 vs 1~6 敌人。

var _combat: CombatController = null
var _unit_views: Dictionary = {}  # entity_id → UnitView
var _log_lines: Array[String] = []

@onready var ally_container: HBoxContainer = $BattlefieldHBox/AllyContainer
@onready var enemy_container: HBoxContainer = $BattlefieldHBox/EnemyContainer
@onready var battle_log: RichTextLabel = $BattleLog


# ── 初始化 ──────────────────────────────────────────────

func init_for_combat(combat: CombatController) -> void:
	_combat = combat
	_connect_signals()
	visible = true


func _connect_signals() -> void:
	if _combat == null:
		return
	# 使用 CONNECT_ONE_SHOT 或手动断开避免堆积
	_disconnect_all()
	_combat.combat_started.connect(_on_combat_started)
	_combat.attack_started.connect(_on_attack_started)
	_combat.damage_dealt.connect(_on_damage_dealt)
	_combat.entity_dead.connect(_on_entity_dead)
	_combat.combat_ended.connect(_on_combat_ended)


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


# ── 信号处理 ────────────────────────────────────────────

func _on_combat_started() -> void:
	_build_unit_views()
	clear_log()
	_add_log("[color=orange]战斗开始![/color]")


func _on_attack_started(attacker_id: String, target_id: String) -> void:
	var attacker_view: UnitView = _unit_views.get(attacker_id, null)
	if attacker_view:
		attacker_view.play_attack_flash()

	var a_name := _short_name(attacker_id)
	var t_name := _short_name(target_id)
	_add_log("%s → %s" % [a_name, t_name])


func _on_damage_dealt(attacker_id: String, target_id: String, damage: int) -> void:
	var target_view: UnitView = _unit_views.get(target_id, null)
	if target_view:
		target_view.play_hit_flash()
		target_view.show_damage_number(damage)
		# 从 CombatController 拉最新 HP
		var entity := _find_entity(target_id)
		if entity:
			target_view.update_hp(entity.current_hp, entity.max_hp)

	if damage == 0:
		_add_log("[color=gray]%s 攻击 %s — 闪避/格挡[/color]" % [_short_name(attacker_id), _short_name(target_id)])
	else:
		_add_log("[color=red]%s[/color] → [color=orange]%s[/color] [color=red]%d[/color]" % [_short_name(attacker_id), _short_name(target_id), damage])


func _on_entity_dead(entity: CombatEntity) -> void:
	var view: UnitView = _unit_views.get(entity.entity_id, null)
	if view:
		view.play_death()
		_unit_views.erase(entity.entity_id)
	_add_log("[color=darkred]%s 阵亡![/color]" % _short_name(entity.entity_id))


func _on_combat_ended(victory: bool) -> void:
	if victory:
		_add_log("[color=green]胜利![/color]")
	else:
		_add_log("[color=red]全灭...[/color]")


# ── 内部方法 ────────────────────────────────────────────

func _build_unit_views() -> void:
	# 清空旧视图
	if ally_container:
		for child in ally_container.get_children():
			child.queue_free()
	if enemy_container:
		for child in enemy_container.get_children():
			child.queue_free()
	_unit_views.clear()

	if _combat == null:
		return

	for entity in _combat.allies:
		var view := UnitView.new()
		view.setup(entity)
		if ally_container:
			ally_container.add_child(view)
		_unit_views[entity.entity_id] = view

	for entity in _combat.enemies:
		var view := UnitView.new()
		view.setup(entity)
		if enemy_container:
			enemy_container.add_child(view)
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


func _short_name(entity_id: String) -> String:
	if entity_id.begins_with("ally_player"):
		return "主角"
	if entity_id.begins_with("ally_"):
		return entity_id.replace("ally_", "")
	if "boss" in entity_id:
		return "[Boss]" + entity_id.replace("boss_", "")
	return entity_id.replace("enemy_", "").split("_")[0]


func _add_log(text: String) -> void:
	if _log_lines.size() >= 50:
		_log_lines.pop_front()
	_log_lines.append(text)
	if battle_log:
		battle_log.text = "\n".join(_log_lines)


func clear_log() -> void:
	_log_lines.clear()
	if battle_log:
		battle_log.clear()


# ── 清理 ────────────────────────────────────────────────

func cleanup() -> void:
	_disconnect_all()
	_combat = null
	for view in _unit_views.values():
		if is_instance_valid(view):
			view.queue_free()
	_unit_views.clear()
	visible = false
