class_name MarchEventService
extends RefCounted
## T-MARCH-M2 · 距离里程碑事件（接战/搜刮节拍由 RunDriver 暂停 tick）


static func tick(run: WorldRun, allowed: bool) -> Array:
	var out: Array = []
	if not allowed or run == null or not run.is_active:
		return out
	if run.is_retreating or run.chase_combat_in_progress:
		return out
	var milestones: Array = run.map_data.get("march_events", [])
	if milestones.is_empty():
		return out
	var dist: float = run.distance_traveled
	for i in range(milestones.size()):
		if i in run.march_events_fired:
			continue
		var entry: Dictionary = milestones[i] if milestones[i] is Dictionary else {}
		if entry.is_empty():
			continue
		var at_dist: float = float(entry.get("at_distance", -1.0))
		if at_dist < 0.0 or dist < at_dist - 0.001:
			continue
		var event_id: String = str(entry.get("event_id", ""))
		if event_id == "":
			continue
		var def: Dictionary = _event_def(event_id)
		if def.is_empty():
			push_warning("MarchEventService: 未知 event_id %s @ %.0fm" % [event_id, at_dist])
			continue
		run.march_events_fired.append(i)
		var payload: Dictionary = _resolve_hit(run, event_id, def, at_dist)
		if not payload.is_empty():
			out.append(payload)
	return out


static func milestone_distances(map_data: Dictionary) -> Array:
	var out: Array = []
	for item in milestone_entries(map_data):
		if item is Dictionary:
			out.append(float(item.get("at_distance", 0.0)))
	return out


static func milestone_entries(map_data: Dictionary) -> Array:
	var out: Array = []
	var raw: Array = map_data.get("march_events", [])
	for i in range(raw.size()):
		var entry: Dictionary = raw[i] if raw[i] is Dictionary else {}
		if entry.is_empty():
			continue
		var at_dist: float = float(entry.get("at_distance", -1.0))
		var event_id: String = str(entry.get("event_id", ""))
		if at_dist < 0.0 or event_id == "":
			continue
		out.append({
			"index": i,
			"at_distance": at_dist,
			"event_id": event_id,
		})
	out.sort_custom(func(a, b): return float(a.at_distance) < float(b.at_distance))
	return out


static func _resolve_hit(
	run: WorldRun, event_id: String, def: Dictionary, at_distance: float
) -> Dictionary:
	var log: String = str(def.get("log", "路旁事件。"))
	var data: Dictionary = {
		"event_id": event_id,
		"log": log,
		"at_distance": at_distance,
		"distance": run.distance_traveled,
		"auto": bool(def.get("auto", true)),
		"gather_beat": bool(def.get("gather_beat", false)),
		"effects_applied": [],
	}
	for fx in def.get("effects", []):
		if fx is not Dictionary:
			continue
		_apply_effect(run, data, fx)
	return {
		"event_name": "march_event",
		"data": data,
	}


static func _apply_effect(run: WorldRun, data: Dictionary, fx: Dictionary) -> void:
	var fx_type: String = str(fx.get("type", ""))
	match fx_type:
		"gold":
			var gmin: int = int(fx.get("gold_min", fx.get("amount", 1)))
			var gmax: int = int(fx.get("gold_max", gmin))
			var gold: int = run._rng.randi_range(mini(gmin, gmax), maxi(gmin, gmax))
			run.total_gold_earned += gold
			data["gold"] = int(data.get("gold", 0)) + gold
			data.effects_applied.append({"type": "gold", "gold": gold})
		"loot_material":
			var rolls: int = maxi(1, int(fx.get("rolls", 1)))
			var names: Array = []
			for _j in range(rolls):
				var fake_enemy: Dictionary = {"level": 1}
				var mat: RunMaterial = RunMaterial.roll_for_map(run.map_data, fake_enemy)
				if mat != null:
					run._add_run_material(mat)
					names.append(mat.item_name)
			if not names.is_empty():
				data["material_names"] = names
				data.effects_applied.append({"type": "loot_material", "names": names})
		"loot_equip":
			var fake_enemy: Dictionary = {"level": int(fx.get("level", 1))}
			var forge_drop: float = float(fx.get("forge_drop", 0.0))
			var shift: int = int(fx.get("quality_shift", 0))
			var eq: Equipment = LootSystem.roll_equipment(run.map_data, fake_enemy, forge_drop, shift)
			if eq != null:
				var placed: Dictionary = RunLootService.add_equipment_drop(run, eq)
				if placed.get("ok", false):
					data["equip_name"] = eq.item_name
					data.effects_applied.append({"type": "loot_equip", "name": eq.item_name})
		"stability":
			var delta: int = int(fx.get("team", fx.get("team_delta", 0)))
			if run.stability != null and delta != 0:
				run.stability.modify_team_stability(delta)
			data["team_delta"] = int(data.get("team_delta", 0)) + delta
			data.effects_applied.append({"type": "stability", "team": delta})
		"distance":
			var meters: float = float(fx.get("meters", fx.get("delta", 0.0)))
			if not run.is_retreating and meters != 0.0:
				run.distance_traveled = clampf(
					run.distance_traveled + meters, 0.0, run.max_distance
				)
				run.max_distance_reached = maxf(run.max_distance_reached, run.distance_traveled)
			data.effects_applied.append({"type": "distance", "meters": meters})
		"spawn_next":
			run.spawn_timer = maxf(0.0, run.spawn_interval - 0.05)
			data.effects_applied.append({"type": "spawn_next"})
		"log_only":
			data.effects_applied.append({"type": "log_only"})
		_:
			push_warning("MarchEventService: 未知效果 %s" % fx_type)


static func _event_def(event_id: String) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var dl = tree.root.get_node_or_null("/root/DataLoader")
		if dl != null and dl.has_method("march_event"):
			return dl.march_event(event_id)
	return {}
