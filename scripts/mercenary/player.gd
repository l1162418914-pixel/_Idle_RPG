extends Mercenary
class_name Player
## 主角 — 战略核心，不可阵亡，经验倍率25%，队伍力量总控

@export var base_exp_multiplier: float = 0.25
@export var squad_stability_influence: float = 0.0
var owned_elite_roster: Array[EliteMercenary] = []
var owned_normal_roster: Array[NormalMercenary] = []


func _init() -> void:
	merc_type = MercType.PLAYER
	max_level = 60
	merc_id = "player_01"


func init_from_template(template: Dictionary) -> void:
	super(template)
	merc_type = MercType.PLAYER
	squad_stability_influence = template.get("squad_bonus", {}).get("defense_rate", 10) / 100.0


func get_exp_multiplier() -> float:
	return base_exp_multiplier


func add_to_roster(merc: Mercenary) -> void:
	if merc is EliteMercenary:
		owned_elite_roster.append(merc)
	elif merc is NormalMercenary:
		owned_normal_roster.append(merc)


func remove_from_roster(merc_id: String) -> void:
	for i in range(owned_elite_roster.size() - 1, -1, -1):
		if owned_elite_roster[i].merc_id == merc_id:
			owned_elite_roster.remove_at(i)
			return
	for i in range(owned_normal_roster.size() - 1, -1, -1):
		if owned_normal_roster[i].merc_id == merc_id:
			owned_normal_roster.remove_at(i)
			return


func elite_count() -> int:
	return owned_elite_roster.size()


func normal_count() -> int:
	return owned_normal_roster.size()