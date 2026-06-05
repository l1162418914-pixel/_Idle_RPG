class_name FormationSlotButton
extends Button
## 编队槽：拖拽换位、右键移出至未编入

var slot_half: String = ""
var slot_kind: String = ""
var slot_index: int = 0
var formation_ui: Control = null


func _get_drag_data(_at_position: Vector2) -> Variant:
	if formation_ui == null or not formation_ui.has_method("_get_slot_merc_id"):
		return null
	var merc_id: String = formation_ui._get_slot_merc_id(slot_half, slot_kind, slot_index)
	if merc_id == "":
		return null
	var m := GameManager.find_mercenary_by_id(merc_id)
	var preview := Label.new()
	preview.text = m.merc_name if m else merc_id
	preview.modulate = Color(0.7, 1.0, 0.85)
	set_drag_preview(preview)
	return {
		"merc_id": merc_id,
		"half": slot_half,
		"kind": slot_kind,
		"index": slot_index,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and str(data.get("merc_id", "")) != ""


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if formation_ui != null and formation_ui.has_method("_handle_slot_drop"):
		formation_ui._handle_slot_drop(slot_half, slot_kind, slot_index, data)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if formation_ui != null and formation_ui.has_method("_clear_slot"):
			formation_ui._clear_slot(slot_half, slot_kind, slot_index)
		accept_event()
