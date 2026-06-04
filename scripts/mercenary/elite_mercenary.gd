extends Mercenary
class_name EliteMercenary
## 精英佣兵 — 可成长记录，有技能槽，可装备

@export var total_kills: int = 0
@export var total_runs: int = 0
@export var is_dead_permanently: bool = false


func _init(p_id: String = "", p_name: String = "") -> void:
	merc_type = MercType.ELITE
	merc_id = p_id
	merc_name = p_name
	max_level = 60


func init_from_template(template: Dictionary) -> void:
	super(template)
	merc_type = MercType.ELITE


func record_run(kills: int, survived: bool) -> void:
	total_runs += 1
	total_kills += kills
	if not survived:
		is_dead_permanently = true


func is_dead() -> bool:
	return is_dead_permanently