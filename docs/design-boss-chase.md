# 7/7 Boss 追击 · 讨论定稿

> **状态：已实现** — 核心追击、返程反击按钮、**接战蓄力僵持击退**（按住蓄力→松手推远，不击杀）；密林/洞穴已配 `chase_boss_id`。

## 一、与区域 Boss 的关系

| | **区域终局 Boss** | **追击 Boss** |
|--|-------------------|---------------|
| **触发** | 推到 `boss_distance` | 返程且满足追击条件（见 §二） |
| **模板** | `map.boss` | **`map.chase_boss_id`**（分地图独立） |
| **击杀** | **直接结算回营**（无返程） | **与区域 Boss 击杀相同**（见 §三） |
| **未击杀** | 战败 → 濒死 + 返程 + 撤离点 | 击退 / 接战失利等（见 §三、§五） |
| **解锁 / 掉落** | 区域通关掉落、解锁下一图 | **追击击杀同样算「击败本图区域 Boss」**，解锁下一区域；另可有 **追击专属** `chase_drop_table` |

---

## 二、追击开启与强度（A）

### 开启（现逻辑 + 建议保留）

- `begin_retreat` 且非 `disable_boss_chase`。
- 默认仍要求 **`boss_spawned` 或 `boss_zone_reached`**（进过 Boss 线才追）；低表现弱追见 `chase_pressure`。
- 测试图：`disable_boss_chase: true`。

### `chase_pressure`（0~1，建议）

```text
chase_pressure = clamp(
  w_dist × (distance_traveled / max_distance) +
  w_kill × (enemies_defeated / kill_scale) +
  w_boss × (boss_zone_reached ? 1 : 0)
  [+ w_loot × 携带价值],  // 可选
  0, 1
)
```

**压力越高**：追击速度越快、稳定惩罚越重、追击刷怪越密、护盾消耗倍率越高、可缩短接战 CD；低压力可不追或弱追。

### 返程刷怪（与 [design-retreat.md](design-retreat.md) 一致）

| 档 | 刷怪 |
|----|------|
| 正常返程 | 稀疏 |
| **Boss 追击** / 守卫追击 | 加密 |

---

## 三、追击战结局（含击杀 = 正常 Boss）

### 击杀追击 Boss（定稿）

**与正常击杀区域 Boss 相同**，包括但不限于：

- `boss_defeated = true`；`record_boss_defeat(map_id)` → **与区域 Boss 击杀相同，解锁下一图**
- 图鉴/统计可同时记 `chase_boss_id` 击败次数（与 `defeated_map_bosses` 并行，不挡解锁）
- **直接结算撤离**（`end_run` 成功档，**不**再继续返程路程）
- 正常 Boss 经验、金币、掉落进本趟网格（安全箱/外露规则照旧）
- **不**走「战败濒死 + 长途返程」线

即：返程途中接追击战 → **若击杀** → 本趟以 **通关式收工** 结束（与 [design-retreat.md](design-retreat.md) 区域 Boss 胜一致）。

### 未击杀（当前阶段）

| 结果 | 行为（在反击机制上线前可沿用现码方向） |
|------|----------------------------------------|
| **击退** | Boss 被推远、`on_chase_boss_repelled`；**继续返程**；可给 **逃脱/击退经验**（见 §四） |
| **接战失利** | `on_chase_boss_catch_penalty`；稳定大跌；Boss 再逼近；可进濒死/战败返程线 |

> **反击（已实现）**  
> - **返程反击**：距离在接战阈值外、警告距离内时点 **「追击反击」**（耗稳定、推远、击退经验、CD）。  
> - **僵持击退**：被追上**接战**时按住 **「蓄力击退」**，蓄满松手 → 首领存活被推远、部分经验、**继续返程**（非击杀）。  
> - **深度反击**：接战僵持中，僵持蓄力达 `chase_deep_counter_min_charge` 后可点 **「深度反击」** → 重创首领 HP（不低于 `chase_deep_counter_hp_floor`）、更高稳定消耗、推远、**继续返程**（非击杀）。  
> **击杀** 仍仅通过接战全灭追击首领触发直接通关。

---

## 四、分地图追击 Boss（C）

```json
"chase_boss_id": "grassland_stalker",
"boss": "grassland_king",
"chase_boss_skills": ["pounce", "enrage"],
"chase_drop_table": "chase_grassland"
```

- `build_chase_boss_encounter()` 读 **`chase_boss_id`**，不再默认等于区域 `boss`。
- **击杀** 走 `chase_drop_table`（可叠加区域 Boss 掉落或二选一，实现时定）+ 正常 Boss 结算 + **解锁下一图**；**刷特定追击首领** = 选图 → 深推 → 撤离 → 追击战 → **击杀**。
- **击退**：`chase_drop_tables` 的 `repel_equipment_chance`（草原 12% / 密林 14% / 洞穴 16%）可在击退时额外 roll 一件偏低品质装备；**击杀** 仍走 guaranteed 专属表。

### 逃脱 / 击退经验（建议 E3，待数值）

- **击退**：`repelled_exp × (1 + chase_pressure)`  
- **本趟曾击退且抵营时仍未被追上**：`evade_exp`  
- **接战失利**：无逃脱奖  

（若击杀已直接结算，**evade_exp** 仅适用于「击退后仍走完返程」分支。）

---

## 五、与其它系统

| 系统 | 衔接 |
|------|------|
| 宝库守卫 | 独立模板；胜=直接结算，败=濒死返程；**不是**追击 Boss |
| 双池护盾 | 追击未击杀前仍返程；**击杀** 则不进盾破掉装阶段 |
| 5/7 濒死 | 追击战 **败** 可进濒死 + 返程 |
| 手动撤 | 无追击 |

---

## 六、现码 → 目标差异

| 现码 | 目标 |
|------|------|
| 追击胜 = `on_chase_boss_repelled` 继续返程 | **击杀** → 等同区域 Boss 胜，**直接结算** |
| `register_chase_boss_defeat` 不设 `boss_defeated` | 击杀应设 defeat 纪录 + 结算 |
| `build_chase_boss_encounter` = `_spawn_boss()` | 用 `chase_boss_id` |
| 无 `chase_pressure` | 按 §二 缩放 |
| 无反击 | 返程反击 + 僵持击退 + 深度反击 |

---

## 七、实现顺序建议

1. `chase_boss_id` + 独立遭遇与掉落表  
2. 战斗胜负分支：**击杀 → 直接结算**；未击杀 → 击退/惩罚 + 继续返程  
3. `chase_pressure` 缩放速度与刷怪  
4. 逃脱/击退经验  
5. **反击机制**（返程 / 僵持 / 深度）

参见 [design-retreat.md](design-retreat.md)、[design-near-death.md](design-near-death.md)。
