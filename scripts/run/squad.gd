class_name Squad
extends RefCounted
## 出征小队 — 管理当前阵容，计算战斗力

var members: Array[Mercenary] = []
var player: Player = null
var total_power: int = 0
var formation_bonus: Dictionary = {}


func build(squad_members: Array) -> void:
	members.clear()
	total_power = 0
	for m in squad_members:
		if m is Player:
			player = m
		members.append(m)
		total_power += calc_power(m)


func calc_power(merc: Mercenary) -> int:
	var p = StatResolver.get_max_hp(merc) * 0.5
	p += (StatResolver.get_patk(merc) + StatResolver.get_matk(merc)) * 3
	p += (StatResolver.get_pdef(merc) + StatResolver.get_mdef(merc)) * 2
	p += StatResolver.get_spd(merc) * 1.5
	p += StatResolver.get_crit_chance(merc) * 100
	return int(p)


func get_alive_count() -> int:
	var c = 0
	for m in members:
		if m.is_alive:
			c += 1
	return c


func get_total_kills() -> int:
	var k = 0
	for m in members:
		k += m.run_kills
	return k


func is_player_alive() -> bool:
	return player != null and player.is_alive


## 小队中是否仍有人存活（含主角与佣兵，不限于可参战状态）
func has_anyone_alive() -> bool:
	return get_alive_count() > 0


## 返程护盾锚点：优先存活主角，否则取任意存活队员
func get_retreat_shield_anchor() -> Mercenary:
	if player != null and player.is_alive:
		return player
	for m in members:
		if m.is_alive:
			return m
	return player


func get_player() -> Player:
	return player


func all_dead() -> bool:
	for m in members:
		if m.is_alive:
			return false
	return true


## 当前可参战的成员（存活且未因低血量撤离）
func get_combat_ready_members() -> Array[Mercenary]:
	var list: Array[Mercenary] = []
	for m in members:
		if m.is_alive and not m.is_retreated:
			if m.is_awakening or not m.is_near_death:
				list.append(m)
	return list


## 战场显示用成员（含濒死，仅排除已撤离/阵亡）
func get_battlefield_members() -> Array[Mercenary]:
	var list: Array[Mercenary] = []
	for m in members:
		if m.is_alive and not m.is_retreated:
			list.append(m)
	return list


func count_near_death_on_field() -> int:
	var n := 0
	for m in get_battlefield_members():
		if m.is_near_death and not m.is_awakening:
			n += 1
	return n


func has_player_near_death() -> bool:
	return player != null and player.is_alive and player.is_near_death


func has_any_member_near_death() -> bool:
	for m in members:
		if m != null and m.is_alive and m.is_near_death:
			return true
	return false


func get_combat_ready_count() -> int:
	return get_combat_ready_members().size()