class_name BattlefieldSlots
extends RefCounted
## CQ 横版槽位：逻辑坐标（0~WIDTH）与屏幕像素映射。
##
## 槽位表（逻辑 X，BATTLEFIELD_WIDTH=600）：
## | 侧   | slot | 角色     | logic_x | 约 pixel_x (lane=500) |
## |------|------|----------|---------|------------------------|
## | 友方 | 0    | 远程后排 | 80      | 35                     |
## | 友方 | 1    | 次后排   | 180     | 105                    |
## | 友方 | 2    | 次前排   | 280     | 175                    |
## | 友方 | 3    | 近战前排 | 380     | 245                    |
## | 敌方 | 0    | 接敌前排 | 520     | 385                    |
## | 敌方 | 1    | 次排     | 420     | 315                    |
## | 敌方 | 2    | 后排     | 320     | 245                    |
## | 敌方 | 3    | …        | 220     | 175                    |
## | 敌方 | 4    | …        | 120     | 105                    |
## | 敌方 | 5    | 末排     | 20      | 35                     |
##
## pixel_x ≈ logic_to_pixel(logic_x, lane_w) — 脚底对齐见 CombatView.UNIT_BASELINE_Y。

const BATTLEFIELD_WIDTH: float = 600.0
const MAX_ALLY_SLOTS: int = 4
const MAX_ENEMY_SLOTS: int = 6
const SLOT_GAP: float = 100.0
const ALLY_SLOT_ORIGIN: float = 80.0
const ENEMY_SLOT_ORIGIN: float = 520.0
const UNIT_VISUAL_WIDTH: float = 60.0
const SPRITE_HEIGHT: float = 48.0
## 接战层最小 lane 宽（低于此线性映射会压叠色块）
const LANE_MIN_WIDTH: float = 480.0
## T-RUN-V3：敌群接战初距（逻辑坐标，相对锚点右偏）
const ENEMY_ENTRY_OFFSET_RIGHT: float = 72.0
## 里程 → 战场锚点平移上限（逻辑坐标）
const ANCHOR_SHIFT_MAX: float = BATTLEFIELD_WIDTH * 0.38


static func ally_slot_x(slot_index: int) -> float:
	return ALLY_SLOT_ORIGIN + float(slot_index) * SLOT_GAP


static func enemy_slot_x(slot_index: int) -> float:
	return ENEMY_SLOT_ORIGIN - float(slot_index) * SLOT_GAP


static func distance_to_anchor_shift(distance: float, max_distance: float) -> float:
	if max_distance <= 0.0:
		return 0.0
	var t: float = clampf(distance / max_distance, 0.0, 1.0)
	return t * ANCHOR_SHIFT_MAX


static func ally_position_at_slot(slot_index: int, anchor_shift: float) -> float:
	return ally_slot_x(slot_index) + anchor_shift


static func enemy_position_at_slot(slot_index: int, anchor_shift: float) -> float:
	return enemy_slot_x(slot_index) + anchor_shift + ENEMY_ENTRY_OFFSET_RIGHT


static func logic_to_pixel(logic_x: float, lane_width: float) -> float:
	var lane_w: float = maxf(lane_width, LANE_MIN_WIDTH)
	var span: float = maxf(0.0, lane_w - UNIT_VISUAL_WIDTH)
	return (clampf(logic_x, 0.0, BATTLEFIELD_WIDTH) / BATTLEFIELD_WIDTH) * span


static func pixel_gap_for_slot_gap(lane_width: float) -> float:
	return (SLOT_GAP / BATTLEFIELD_WIDTH) * maxf(0.0, maxf(lane_width, LANE_MIN_WIDTH) - UNIT_VISUAL_WIDTH)


static func slot_gap_covers_visual(lane_width: float) -> bool:
	return pixel_gap_for_slot_gap(lane_width) >= UNIT_VISUAL_WIDTH - 0.5
