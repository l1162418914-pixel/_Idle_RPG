extends Mercenary
class_name NormalMercenary
## 普通佣兵 — 无成长记录，一次性消耗品，阵亡即消失

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
	is_alive = false