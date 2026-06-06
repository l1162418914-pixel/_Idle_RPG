extends VBoxContainer
class_name UnitView
## UnitView — 战斗场景中单个单位（佣兵/敌人）的视觉表现

const RANGED_ATTACK_RANGE := CombatEntity.RANGED_ATTACK_THRESHOLD

var entity_id: String = ""
var unit_name: String = ""
var max_hp: int = 100
var current_hp: int = 100
var is_dead: bool = false
var is_ranged: bool = false

var _sprite_rect: ColorRect = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null

const SPRITE_SIZE := Vector2(48, 48)

const COLOR_MAP := {
	"player": Color(0.25, 0.45, 0.85),
	"elite":  Color(0.55, 0.25, 0.80),
	"normal": Color(0.25, 0.65, 0.35),
	"enemy":  Color(0.85, 0.20, 0.20),
	"boss":   Color(0.70, 0.08, 0.08),
}


func setup(entity: CombatEntity) -> void:
	entity_id = entity.entity_id
	unit_name = _resolve_name(entity)
	max_hp = entity.max_hp
	current_hp = entity.current_hp
	is_dead = false
	is_ranged = entity.is_ranged_unit()

	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	custom_minimum_size = Vector2(60, 0)
	alignment = BoxContainer.ALIGNMENT_CENTER

	# 色块占位
	_sprite_rect = ColorRect.new()
	_sprite_rect.custom_minimum_size = SPRITE_SIZE
	_sprite_rect.color = _pick_color(entity.entity_id, entity.team)
	if is_ranged:
		_sprite_rect.color = _sprite_rect.color.lerp(Color(0.95, 0.85, 0.35), 0.25)
	add_child(_sprite_rect)

	# 名称
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_suffix := " [远]" if is_ranged else ""
	if entity.is_awakening():
		_name_label.text = "%s (觉醒)%s" % [unit_name, name_suffix]
		modulate = Color(1.0, 0.82, 0.25)
	elif entity.is_downed():
		_name_label.text = "%s (濒死)%s" % [unit_name, name_suffix]
		modulate = Color(0.72, 0.72, 0.78)
	else:
		_name_label.text = unit_name + name_suffix
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.clip_text = true
	add_child(_name_label)

	# HP条
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 8)
	_hp_bar.size_flags_horizontal = Control.SIZE_FILL
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_bar.show_percentage = false
	_apply_bar_style(_hp_bar, entity.hp_ratio())
	add_child(_hp_bar)

	# HP数值
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.text = "%d/%d" % [current_hp, max_hp]
	_hp_label.add_theme_font_size_override("font_size", 8)
	add_child(_hp_label)


func _pick_color(eid: String, team: int) -> Color:
	if team == CombatEntity.Team.ALLY:
		if "player" in eid:
			return COLOR_MAP["player"]
		elif "elite" in eid:
			return COLOR_MAP["elite"]
		return COLOR_MAP["normal"]
	if "boss" in eid:
		return COLOR_MAP["boss"]
	return COLOR_MAP["enemy"]


func _resolve_name(entity: CombatEntity) -> String:
	if entity.source_merc:
		return entity.source_merc.merc_name
	var name_str = entity.entity_id.replace("enemy_", "").replace("boss_", "")
	return name_str.split("_")[0].capitalize()


# ── 动态更新 ────────────────────────────────────────────

func set_downed_visual() -> void:
	if is_dead:
		return
	modulate = Color(0.72, 0.72, 0.78)
	if _name_label and not "(濒死)" in _name_label.text:
		var suffix := " [远]" if is_ranged else ""
		_name_label.text = "%s (濒死)%s" % [unit_name, suffix]


func update_hp(new_current: int, new_max: int) -> void:
	if is_dead:
		return
	current_hp = new_current
	max_hp = new_max
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = current_hp
		_apply_bar_style(_hp_bar, float(current_hp) / float(max_hp) if max_hp > 0 else 0.0)
	if _hp_label:
		_hp_label.text = "%d/%d" % [current_hp, max_hp]


func _apply_bar_style(bar: ProgressBar, ratio: float) -> void:
	var style := StyleBoxFlat.new()
	if ratio > 0.6:
		style.bg_color = Color.GREEN
	elif ratio > 0.3:
		style.bg_color = Color.ORANGE
	else:
		style.bg_color = Color.RED
	bar.add_theme_stylebox_override("fill", style)


# ── 动画 ────────────────────────────────────────────────

func play_attack_flash() -> void:
	if is_dead or _sprite_rect == null:
		return
	var tween := create_tween()
	var original := _sprite_rect.color
	tween.tween_property(_sprite_rect, "color", Color.WHITE, 0.08)
	tween.tween_property(_sprite_rect, "color", original, 0.10)


func play_skill_flash() -> void:
	if is_dead or _sprite_rect == null:
		return
	var tween := create_tween()
	var original := _sprite_rect.color
	tween.tween_property(_sprite_rect, "color", Color(0.35, 0.95, 1.0), 0.10)
	tween.tween_property(_sprite_rect, "color", original, 0.14)


func play_ranged_strike(target: UnitView, projectile_layer: Control, travel_time: float = 0.14) -> void:
	play_projectile_strike(target, projectile_layer, travel_time, Color(1.0, 0.88, 0.25))


func play_projectile_strike(
	target: UnitView,
	projectile_layer: Control,
	travel_time: float,
	color: Color,
	bolt_size: Vector2 = Vector2(10, 4)
) -> void:
	if is_dead or _sprite_rect == null:
		return
	if target == null or target._sprite_rect == null or projectile_layer == null:
		play_attack_flash()
		return
	var duration: float = clampf(travel_time, 0.06, 0.55)
	var proj := ColorRect.new()
	proj.color = color
	proj.custom_minimum_size = bolt_size
	proj.size = bolt_size
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	projectile_layer.add_child(proj)
	var half := bolt_size * 0.5
	var start := _sprite_rect.global_position + SPRITE_SIZE * 0.5 - half
	var end := target._sprite_rect.global_position + SPRITE_SIZE * 0.5 - half
	proj.global_position = start
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", end, duration)
	tween.tween_callback(proj.queue_free)
	play_attack_flash()


func play_hit_flash() -> void:
	if is_dead or _sprite_rect == null:
		return
	var tween := create_tween()
	var original := _sprite_rect.color
	tween.tween_property(_sprite_rect, "color", Color.RED, 0.06)
	tween.tween_property(_sprite_rect, "color", original, 0.10)


func play_death() -> void:
	if is_dead:
		return
	is_dead = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "custom_minimum_size:y", 0, 0.5)
	tween.finished.connect(queue_free)


func show_damage_number(damage: int) -> void:
	var popup := Label.new()
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 14)
	popup.text = "-%d" % damage if damage > 0 else "MISS"
	popup.modulate = Color.RED if damage > 0 else Color.GRAY
	popup.z_index = 10
	add_child(popup)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", -30.0, 0.6).as_relative()
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.finished.connect(popup.queue_free)
