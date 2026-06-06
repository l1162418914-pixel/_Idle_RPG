class_name RunMarchView
extends Control
## T-RUN-V2 · 行军队列剪影占位（朝向随进军/返程切换）


const PARTY_COLORS: Array[Color] = [
	Color(0.45, 0.72, 0.95),
	Color(0.55, 0.82, 0.65),
	Color(0.9, 0.72, 0.45),
	Color(0.75, 0.55, 0.9),
]

var _party_nodes: Array[ColorRect] = []
var _bob_phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in PARTY_COLORS.size():
		var block := ColorRect.new()
		block.color = PARTY_COLORS[i]
		block.custom_minimum_size = Vector2(10, 14)
		block.size = Vector2(10, 14)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(block)
		_party_nodes.append(block)


func _process(delta: float) -> void:
	if visible and _party_nodes.size() > 0:
		_bob_phase += delta * 8.0


func apply_lane(
	lane_state: RunMarchLane.LaneState,
	retreating: bool,
	in_combat: bool,
	party_count: int
) -> void:
	visible = (
		not in_combat
		and lane_state != RunMarchLane.LaneState.IDLE_STANDBY
		and lane_state != RunMarchLane.LaneState.COMBAT_ENGAGED
		and lane_state != RunMarchLane.LaneState.BOSS_ENGAGED
	)
	if not visible:
		return
	var count: int = clampi(party_count, 1, _party_nodes.size())
	var base_x: float = size.x * 0.22
	var spacing: float = 14.0
	var dir_sign: float = -1.0 if retreating else 1.0
	for i in _party_nodes.size():
		var node: ColorRect = _party_nodes[i]
		if i >= count:
			node.visible = false
			continue
		node.visible = true
		var bob: float = sin(_bob_phase + float(i) * 0.7) * 2.0
		node.position.x = base_x + float(i) * spacing * dir_sign
		node.position.y = size.y * 0.35 + bob
		node.scale.x = -1.0 if retreating else 1.0
