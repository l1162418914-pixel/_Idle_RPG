class_name FormationPoolButton
extends Button
## 未编入池：拖拽到半组槽位

var merc_id: String = ""
var formation_ui: Control = null


func _get_drag_data(_at_position: Vector2) -> Variant:
	if merc_id == "":
		return null
	var m := GameManager.find_mercenary_by_id(merc_id)
	var preview := Label.new()
	preview.text = m.merc_name if m else merc_id
	preview.modulate = Color(0.85, 0.95, 1.0)
	set_drag_preview(preview)
	return {"merc_id": merc_id, "from_pool": true}
