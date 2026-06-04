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
	var p = EquipmentSystem.get_max_hp(merc) * 0.5
	p += (EquipmentSystem.get_attack(merc) + EquipmentSystem.get_magic_attack(merc)) * 3
	p += (EquipmentSystem.get_defense(merc) + EquipmentSystem.get_magic_defense(merc)) * 2
	p += EquipmentSystem.get_speed(merc) * 1.5
	p += EquipmentSystem.get_crit_chance(merc) * 100
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


func get_player() -> Player:
	return player


func all_dead() -> bool:
	for m in members:
		if m.is_alive:
			return false
	return true