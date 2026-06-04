class_name BuffSystem
extends RefCounted
## BuffSystem — 管理单个佣兵身上的所有战斗 Buff
##
## 每个 Buff 是 {id, stat, value, duration, elapsed}
## stat 与 EquipmentSystem 内部统计名一致：
##   patk / matk / pdef / mdef / hp / spd / crit_chance / dodge / block_chance

var active_buffs: Array = []


func apply_buff(buff_id: String, stat: String, value: float, duration: float) -> void:
	active_buffs.append({
		"id": buff_id,
		"stat": stat,
		"value": value,
		"duration": duration,
		"elapsed": 0.0
	})


func remove_buff(buff_id: String) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i]["id"] == buff_id:
			active_buffs.remove_at(i)


func tick(delta: float) -> void:
	# 更新计时并收集到期索引
	var expired: Array = []
	for i in range(active_buffs.size()):
		active_buffs[i]["elapsed"] += delta
		if active_buffs[i]["elapsed"] >= active_buffs[i]["duration"]:
			expired.append(i)
	# 倒序移除
	for i in range(expired.size() - 1, -1, -1):
		active_buffs.remove_at(expired[i])


func get_bonus(stat: String) -> float:
	var total := 0.0
	for buff in active_buffs:
		if buff["stat"] == stat:
			total += buff["value"]
	return total


func has_buff(buff_id: String) -> bool:
	for buff in active_buffs:
		if buff["id"] == buff_id:
			return true
	return false


func clear() -> void:
	active_buffs.clear()


func to_dict_array() -> Array:
	var result: Array = []
	for buff in active_buffs:
		result.append(buff.duplicate())
	return result


func from_dict_array(data: Array) -> void:
	active_buffs.clear()
	for item in data:
		if item is Dictionary:
			active_buffs.append(item.duplicate())