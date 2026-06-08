class_name FormationPoolDropZone
extends PanelContainer
## 横条备战席投放区：接收半组槽位拖回（移出至未编入）

var formation_ui: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 48)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.22, 0.34, 0.46, 0.75)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _is_slot_drag(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if formation_ui != null and formation_ui.has_method("_handle_pool_drop"):
		formation_ui.call_deferred("_handle_pool_drop", data)


static func _is_slot_drag(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if str(data.get("merc_id", "")) == "":
		return false
	if bool(data.get("from_pool", false)):
		return false
	return str(data.get("half", "")) != "" and str(data.get("kind", "")) != ""
