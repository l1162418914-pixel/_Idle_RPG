extends VBoxContainer
class_name UnitView
## UnitView — 战斗场景中单个单位（佣兵/敌人）的视觉表现

const RANGED_ATTACK_RANGE: float = 75.0
const MAX_BUFF_BADGES := 3

const BUFF_STAT_SHORT := {
	"patk": "攻",
	"matk": "魔",
	"pdef": "防",
	"mdef": "盾",
	"hp": "血",
	"spd": "速",
	"crit_chance": "暴",
	"dodge": "闪",
	"block_chance": "格",
}

const MAX_SKILL_CHIPS := 3

const SKILL_SHORT := {
	"fireball": "火",
	"heal": "疗",
	"taunt": "嘲",
	"rapid_shot": "射",
}

const AWAKENING_VARIANT_LABEL := {
	"damage_burst": "爆发",
	"team_shield": "盾援",
	"taunt": "铁壁",
	"heal_snap": "回光",
}

var entity_id: String = ""
var unit_name: String = ""
var max_hp: int = 100
var current_hp: int = 100
var is_dead: bool = false
var is_ranged: bool = false

var _sprite_wrap: Control = null
var _sprite_rect: ColorRect = null
var _awakening_badge: Label = null
var _buff_row: HBoxContainer = null
var _skill_row: HBoxContainer = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null

const SPRITE_SIZE := Vector2(BattlefieldSlots.SPRITE_HEIGHT, BattlefieldSlots.SPRITE_HEIGHT)
## 固定块高：色块顶对齐脚线基准，避免 VBox 随角标行数上下错位
const UNIT_BLOCK_HEIGHT: float = 72.0

const COLOR_MAP := {
	"player": Color(0.25, 0.45, 0.85),
	"elite": Color(0.55, 0.25, 0.80),
	"normal": Color(0.25, 0.65, 0.35),
	"enemy": Color(0.85, 0.20, 0.20),
	"boss": Color(0.70, 0.08, 0.08),
}


func setup(entity) -> void:
	entity_id = entity.entity_id
	unit_name = _resolve_name(entity)
	max_hp = entity.max_hp
	current_hp = entity.current_hp
	is_dead = false
	is_ranged = entity.is_ranged_unit()

	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	custom_minimum_size = Vector2(BattlefieldSlots.UNIT_VISUAL_WIDTH, UNIT_BLOCK_HEIGHT)
	alignment = BoxContainer.ALIGNMENT_BEGIN

	_sprite_wrap = Control.new()
	_sprite_wrap.custom_minimum_size = Vector2(
		BattlefieldSlots.UNIT_VISUAL_WIDTH, BattlefieldSlots.SPRITE_HEIGHT
	)
	_sprite_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_sprite_rect = ColorRect.new()
	_sprite_rect.custom_minimum_size = SPRITE_SIZE
	_sprite_rect.size = SPRITE_SIZE
	_sprite_rect.position.x = BattlefieldSlots.unit_sprite_inset_x()
	_sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_rect.color = _pick_color(entity.entity_id, entity.team)
	if is_ranged:
		_sprite_rect.color = _sprite_rect.color.lerp(Color(0.95, 0.85, 0.35), 0.25)
	_sprite_wrap.add_child(_sprite_rect)

	_awakening_badge = Label.new()
	_awakening_badge.visible = false
	_awakening_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_awakening_badge.position = Vector2(30.0, -2.0)
	_awakening_badge.add_theme_font_size_override("font_size", 8)
	_awakening_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	_sprite_wrap.add_child(_awakening_badge)

	_buff_row = HBoxContainer.new()
	_buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_row.position = Vector2(2.0, 2.0)
	_buff_row.add_theme_constant_override("separation", 1)
	_sprite_wrap.add_child(_buff_row)

	add_child(_sprite_wrap)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.clip_text = true
	add_child(_name_label)

	_skill_row = HBoxContainer.new()
	_skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_skill_row.add_theme_constant_override("separation", 2)
	_skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skill_row)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 8)
	_hp_bar.size_flags_horizontal = Control.SIZE_FILL
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_bar.show_percentage = false
	_apply_bar_style(_hp_bar, entity.hp_ratio())
	add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.text = "%d/%d" % [current_hp, max_hp]
	_hp_label.add_theme_font_size_override("font_size", 8)
	add_child(_hp_label)

	sync_status_from_entity(entity)


func get_status_text() -> String:
	return _name_label.text if _name_label else ""


func get_buff_badge_count() -> int:
	return _buff_row.get_child_count() if _buff_row else 0


func is_awakening_badge_visible() -> bool:
	return _awakening_badge.visible if _awakening_badge else false


func get_skill_chip_count() -> int:
	return _skill_row.get_child_count() if _skill_row else 0


func get_skill_chip_text(skill_id: String) -> String:
	if _skill_row == null:
		return ""
	for child in _skill_row.get_children():
		if child.get_meta("skill_id", "") == skill_id:
			return (child as Label).text
	return ""


func _pick_color(eid: String, team: int) -> Color:
	if team == 0:
		if "player" in eid:
			return COLOR_MAP["player"]
		elif "elite" in eid:
			return COLOR_MAP["elite"]
		return COLOR_MAP["normal"]
	if "boss" in eid:
		return COLOR_MAP["boss"]
	return COLOR_MAP["enemy"]


func _resolve_name(entity) -> String:
	if entity.source_merc:
		return entity.source_merc.merc_name
	var name_str = entity.entity_id.replace("enemy_", "").replace("boss_", "")
	return name_str.split("_")[0].capitalize()


# ── 动态更新 ────────────────────────────────────────────

func sync_status_from_entity(entity) -> void:
	if is_dead or entity == null or _name_label == null:
		return
	is_ranged = entity.is_ranged_unit()
	var suffix := " [远]" if is_ranged else ""
	if entity.is_awakening():
		var v_label: String = _awakening_variant_label(entity)
		_name_label.text = "%s (觉醒·%s)%s" % [unit_name, v_label, suffix]
		modulate = Color(1.0, 0.82, 0.25)
		_set_awakening_badge(true, v_label)
	elif entity.is_downed():
		_name_label.text = "%s (濒死)%s" % [unit_name, suffix]
		modulate = Color(0.72, 0.72, 0.78)
		_set_awakening_badge(false)
	else:
		_name_label.text = unit_name + suffix
		modulate = Color.WHITE
		_set_awakening_badge(false)
	_refresh_buff_badges(entity)
	_refresh_skill_cooldown_chips(entity)


func sync_skill_cooldowns_from_entity(entity) -> void:
	_refresh_skill_cooldown_chips(entity)


func set_downed_visual() -> void:
	if is_dead:
		return
	modulate = Color(0.72, 0.72, 0.78)
	if _name_label and not "(濒死)" in _name_label.text:
		var suffix := " [远]" if is_ranged else ""
		_name_label.text = "%s (濒死)%s" % [unit_name, suffix]
	_set_awakening_badge(false)


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


func _awakening_variant_label(entity) -> String:
	if entity.source_merc != null:
		var vid: String = str(entity.source_merc.awakening_variant_id)
		if vid != "":
			return AWAKENING_VARIANT_LABEL.get(vid, vid)
	return "觉醒"


func _set_awakening_badge(show_badge: bool, label: String = "") -> void:
	if _awakening_badge == null:
		return
	_awakening_badge.visible = show_badge
	if show_badge:
		_awakening_badge.text = label if label != "" else "觉"


func _refresh_buff_badges(entity) -> void:
	if _buff_row == null:
		return
	for child in _buff_row.get_children():
		_buff_row.remove_child(child)
		child.free()
	if entity.source_merc == null:
		return
	var buffs: Array = entity.source_merc.buff_system.active_buffs
	if buffs.is_empty():
		return
	var shown := 0
	for buff in buffs:
		if not buff is Dictionary:
			continue
		if shown >= MAX_BUFF_BADGES:
			break
		var stat: String = str(buff.get("stat", ""))
		var chip := Label.new()
		chip.text = BUFF_STAT_SHORT.get(stat, stat.left(1) if stat.length() > 0 else "?")
		chip.add_theme_font_size_override("font_size", 7)
		chip.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buff_row.add_child(chip)
		shown += 1
	if buffs.size() > MAX_BUFF_BADGES:
		var more := Label.new()
		more.text = "+%d" % (buffs.size() - MAX_BUFF_BADGES)
		more.add_theme_font_size_override("font_size", 7)
		more.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buff_row.add_child(more)


func _refresh_skill_cooldown_chips(entity) -> void:
	if _skill_row == null:
		return
	for child in _skill_row.get_children():
		_skill_row.remove_child(child)
		child.free()
	if entity.source_merc == null:
		return
	var shown := 0
	for skill_id in entity.get_active_skill_ids():
		if shown >= MAX_SKILL_CHIPS:
			break
		var sid: String = str(skill_id)
		if not SkillSystem.is_active_skill(sid):
			continue
		var cd_left: float = entity.get_skill_cooldown_remaining(sid)
		var chip := Label.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_font_size_override("font_size", 7)
		chip.set_meta("skill_id", sid)
		var short: String = SKILL_SHORT.get(sid, sid.left(1) if sid.length() > 0 else "?")
		if cd_left > 0.05:
			chip.text = "%s%.0f" % [short, ceil(cd_left)]
			chip.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
		else:
			chip.text = short
			chip.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
		_skill_row.add_child(chip)
		shown += 1


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
