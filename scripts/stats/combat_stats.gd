class_name CombatStats
extends RefCounted
## 战斗最终属性快照 — 仅用于 CombatEntity / UI 查询，不写回 Mercenary

var max_hp: int = 0
var patk: int = 0
var matk: int = 0
var pdef: int = 0
var mdef: int = 0
var spd: int = 0
var crit_chance: float = 0.05
var dodge: float = 0.03
var block_chance: float = 0.05
var attack_range: float = 50.0
var attack_speed: float = 1.0
