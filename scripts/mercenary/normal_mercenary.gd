extends Mercenary
class_name NormalMercenary
## 普通佣兵 — 无成长记录；战中倒下为濒死，撤离失败才永久消失

@export var is_dead_permanently: bool = false


func _init(p_id: String = "", p_name: String = "") -> void:
	merc_type = MercType.NORMAL
	merc_id = p_id
	merc_name = p_name
	max_level = 30


func init_from_template(template: Dictionary) -> void:
	super(template)
	merc_type = MercType.NORMAL


func mark_dead() -> void:
	is_dead_permanently = true
	mark_permanent_death()