class_name NearDeathRunService
extends RefCounted

const SUPPORT_SPEED_MULT: float = 0.88


static func assign_carry_support(squad: Squad) -> void:
	if squad == null:
		return
	for m in squad.members:
		if m != null:
			m.supported_by_id = ""
	var downed: Array[Mercenary] = []
	for m in squad.get_battlefield_members():
		if m != null and m.is_near_death:
			downed.append(m)
	var helpers: Array[Mercenary] = squad.get_combat_ready_members()
	var hi := 0
	for d in downed:
		if hi >= helpers.size():
			break
		d.supported_by_id = helpers[hi].merc_id
		hi += 1


static func count_supported_near_death(squad: Squad) -> int:
	if squad == null:
		return 0
	var n := 0
	for m in squad.get_battlefield_members():
		if m != null and m.is_near_death and m.supported_by_id != "":
			n += 1
	return n


static func get_retreat_speed_multiplier(run: WorldRun) -> float:
	if run == null or run.squad == null:
		return 1.0
	var mult: float = 1.0
	if run.squad.has_any_member_near_death():
		mult *= WorldRun.NEAR_DEATH_RETREAT_SPEED_MULT
	if count_supported_near_death(run.squad) > 0:
		mult *= SUPPORT_SPEED_MULT
	return mult
