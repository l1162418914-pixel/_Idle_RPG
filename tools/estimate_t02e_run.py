#!/usr/bin/env python3
"""Rough T-02e run duration model (march + spawn cadence; combat time assumed)."""
from __future__ import annotations

ADVANCE = 26.0 * 0.8
RETREAT = 28.0 * 0.75
SPAWN = 3.0
DECAY_MULT = 2.5
LOSS_MULT = 1.75
BOSS_DIST = 480.0

# Forward: world only ticks between combats; assume avg combat + gap per wave
FORWARD_WAVES = 5
COMBAT_SEC = 32.0
GAP_SEC = SPAWN * 2.5
forward_sec = FORWARD_WAVES * (COMBAT_SEC + GAP_SEC)
forward_m = forward_sec * ADVANCE * 0.35  # partial march between fights

# Stability: decay ~0.12*DECAY_MULT*(1-0.1) ~0.238/s + hits ~8/wave
decay_to_30 = (100 - 30) / 0.24
hit_loss = FORWARD_WAVES * 8
retreat_trigger = min(decay_to_30, forward_sec + hit_loss * 0.5)

retreat_m = max(80.0, min(forward_m, BOSS_DIST * 0.45))
retreat_waves = 3
retreat_combat = retreat_waves * (COMBAT_SEC + SPAWN * 2.0)
retreat_march = retreat_m / (RETREAT * 0.85)

total = retreat_trigger + retreat_combat + retreat_march
print("T-02e estimate (test_near_death_duo, balanced params)")
print("  forward phase: %.0fs (%d waves @ %.0fs combat)" % (retreat_trigger, FORWARD_WAVES, COMBAT_SEC))
print("  retreat combat: %.0fs (%d waves)" % (retreat_combat, retreat_waves))
print("  retreat march: %.0fs (%.0fm)" % (retreat_march, retreat_m))
print("  TOTAL: %.0fs (%.1f min)" % (total, total / 60.0))
