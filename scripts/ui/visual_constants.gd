class_name VisualConstants
extends RefCounted
## T-ART-FW-1 · 占位美术常量（无资源时统一色块；FW-2 接 VisualSlot + 真图）


const PARTY_SILHOUETTE_COLORS: Array[Color] = [
	Color(0.45, 0.72, 0.95),
	Color(0.55, 0.82, 0.65),
	Color(0.9, 0.72, 0.45),
	Color(0.75, 0.55, 0.9),
]

const PARTY_BLOCK_SIZE: Vector2 = Vector2(10, 14)
const GATHER_PARTY_SIZE: Vector2 = Vector2(8, 12)

const MILESTONE_MARKER_COLOR: Color = Color(0.9, 0.75, 0.35, 0.85)
const MILESTONE_FIRED_COLOR: Color = Color(0.55, 0.5, 0.4, 0.42)
const MILESTONE_FLASH_COLOR: Color = Color(1.0, 0.9, 0.5, 0.95)
const MILESTONE_MARKER_SIZE: Vector2 = Vector2(6, 6)
const MILESTONE_FLASH_SIZE: Vector2 = Vector2(10, 10)

const GATHER_PROP_COLOR: Color = Color(0.55, 0.42, 0.28, 0.92)
const GATHER_PROP_SIZE: Vector2 = Vector2(28, 20)

const BOSS_CHASE_BODY_COLOR: Color = Color(0.72, 0.18, 0.14, 0.92)
const BOSS_CHASE_CROWN_COLOR: Color = Color(0.9, 0.35, 0.2, 0.95)
const BOSS_CHASE_BODY_SIZE: Vector2 = Vector2(22, 32)
const BOSS_CHASE_CROWN_SIZE: Vector2 = Vector2(14, 8)

const PARALLAX_LAYER_SPECS: Array[Dictionary] = [
	{"color": Color(0.12, 0.16, 0.22, 1.0), "factor": 0.15, "h": 1.0},
	{"color": Color(0.18, 0.24, 0.32, 1.0), "factor": 0.35, "h": 0.55},
	{"color": Color(0.28, 0.36, 0.46, 1.0), "factor": 0.65, "h": 0.28},
]

const LANE_HORIZON_START: float = 0.12
const LANE_HORIZON_SPAN: float = 0.76


static func party_color(index: int) -> Color:
	if PARTY_SILHOUETTE_COLORS.is_empty():
		return Color.WHITE
	var i: int = clampi(index, 0, PARTY_SILHOUETTE_COLORS.size() - 1)
	return PARTY_SILHOUETTE_COLORS[i]


static func placeholder_spec(art_key: String) -> Dictionary:
	match art_key:
		"milestone/marker":
			return {"color": MILESTONE_MARKER_COLOR, "size": MILESTONE_MARKER_SIZE}
		"milestone/fired":
			return {"color": MILESTONE_FIRED_COLOR, "size": MILESTONE_MARKER_SIZE}
		"milestone/flash":
			return {"color": MILESTONE_FLASH_COLOR, "size": MILESTONE_FLASH_SIZE}
		"gather/prop":
			return {"color": GATHER_PROP_COLOR, "size": GATHER_PROP_SIZE}
		"gather/party":
			return {"color": party_color(0), "size": GATHER_PARTY_SIZE}
		"boss_chase/body":
			return {"color": BOSS_CHASE_BODY_COLOR, "size": BOSS_CHASE_BODY_SIZE}
		"boss_chase/crown":
			return {"color": BOSS_CHASE_CROWN_COLOR, "size": BOSS_CHASE_CROWN_SIZE}
		_:
			if art_key.begins_with("party/silhouette"):
				var tail: String = art_key.substr(art_key.rfind("_") + 1)
				var idx: int = int(tail) if tail.is_valid_int() else 0
				return {"color": party_color(idx), "size": PARTY_BLOCK_SIZE}
			if art_key.begins_with("parallax/layer_"):
				var layer_i: int = int(art_key.get_slice("layer_", 1))
				if layer_i >= 0 and layer_i < PARALLAX_LAYER_SPECS.size():
					var spec: Dictionary = PARALLAX_LAYER_SPECS[layer_i]
					return {
						"color": spec.get("color", Color.GRAY),
						"size": Vector2(64, 48),
					}
			return {}
