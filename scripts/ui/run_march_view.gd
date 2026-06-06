class_name RunMarchView
extends Control
## T-RUN-V2 · 行军队列剪影（T-ART-FW-2 VisualSlot）


var _party_slots: Array[VisualSlot] = []
var _bob_phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in VisualConstants.PARTY_SILHOUETTE_COLORS.size():
		var slot := VisualSlot.new()
		slot.slot_id = "party_%d" % i
		add_child(slot)
		slot.apply_art_key("party/silhouette_%d" % i)
		_party_slots.append(slot)


func _process(delta: float) -> void:
	if visible and _party_slots.size() > 0:
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
	var count: int = clampi(party_count, 1, _party_slots.size())
	var base_x: float = size.x * 0.22
	var spacing: float = 14.0
	var dir_sign: float = -1.0 if retreating else 1.0
	for i in _party_slots.size():
		var slot: VisualSlot = _party_slots[i]
		if i >= count:
			slot.visible = false
			continue
		slot.visible = true
		var bob: float = sin(_bob_phase + float(i) * 0.7) * 2.0
		slot.position.x = base_x + float(i) * spacing * dir_sign
		slot.position.y = size.y * 0.35 + bob
		slot.scale.x = -1.0 if retreating else 1.0
