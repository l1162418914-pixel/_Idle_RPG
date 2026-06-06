class_name TestRosterLoader
extends RefCounted
## 从 data/test_map_rosters.json 加载测试图自带编队


static func roster_for_map(map_id: String) -> Dictionary:
	var data: Dictionary = DataLoader.test_map_rosters_data()
	var rosters: Dictionary = data.get("rosters", {})
	if rosters.has(map_id):
		return rosters[map_id]
	return {}


static func has_roster(map_id: String) -> bool:
	return not roster_for_map(map_id).is_empty()
