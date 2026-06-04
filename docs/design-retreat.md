# 2/7 返程（Retreat）· 讨论定稿

> **状态：未实现**（现码仍为领队 HP 单池护盾、`total_loot` 扁平列表等）。实现时以本文档为准。

## 一、流程总览

```
进军 → 触发返程 → 向左撤回（可选撤离点）→ 抵营结算
         │                    │
         │                    ├ 可接战（与 world_run 并行）
         │                    ├ 双池护盾（装备层 → 物资层）
         │                    └ 盾破后仅外露可能丢失
         │
         ├ Boss/宝库胜 → 直接结算（无返程）
         ├ 战败/路上输 → 濒死 + 开盾 + 返程（优先撤离点）
         └ 手动撤 → 无返程，仅箱+随身，等同战败
```

---

## 二、返程触发源

| ID | 触发 | 路程 | 带回 / 货物 | 护盾 | 结算档 |
|----|------|------|-------------|------|--------|
| **manual** | 玩家手动 | **无** | **仅安全箱 + 随身**；外露 **舍弃** | 无 | **等同完全战败** |
| **forced** | 稳定 ≤30 | 是；优先 `extract_distance` | 箱+外露；外露可全丢 | 双池；常规 reason | 撤离抵营 |
| **auto_value** | 携带价值 ≥ 阈值 | 是 | 同上 | 双池；不绑濒死包 | 撤离抵营 |
| **auto_rule** | 规则勾选（箱满等） | 是 | 同上 | 双池 | 撤离抵营 |
| **combat_fail** | 进军时战败（小怪/精英/遭遇 Boss/ **区域 Boss 败**） | 是；**撤离点** | 箱+外露 | 双池 | 紧急/战败 |
| **extract_rare** | 撤离物 `retreat_chance` 命中 → 守卫战 | 见守卫战 | 见下 | 见下 | 见下 |
| **extract_clear** | 守卫战 **胜** / 区域 Boss **胜** | **无** | 按装箱规则进背包 | — | **通关结算** |

已在返程中重复 `begin_retreat` → 忽略。

### 价值 / 强制返程（途中战斗）

- 仍走返程；外露可能全丢。
- **未濒死前**：与正常返程相同（接战、`march_retreat_combat`）。
- **不触发「战败濒死护盾包」**（不在开局全员濒死+额外盾）；仅 `begin_retreat` 时双池满盾。
- **盾未破**：不掉物资；盾破后仅掉 **外露**。

### 智能撤离

- **carry_value** = 装备 `power_score` + 材料 `material_value`（默认 **箱+外露**；可设置仅安全箱）。
- 达标 → `begin_retreat("auto_value")`；地图 ID 不变。
- 可选：区域 Boss 未击败时不因价值撤；**撤离物线**可例外。

### 手动撤离

- 二次确认：放弃外露 N 件。
- 不 `begin_retreat`；`end_run` 战败档；**不**触发装备护盾 CD。

---

## 三、战斗结果

| 战斗 | 胜 | 败 |
|------|----|----|
| **区域终局 Boss** | **直接结算**（`extract_clear` / success） | 濒死 + 开盾 + 返程 → **撤离点** |
| **路上单位** | 继续 | 濒死 + 开盾 + 返程 |
| **宝库守卫**（概率触发） | 直接结算 + **额外奖励** | 濒死 + 返程（以小博大） |
| **返程途中** | 继续返程 | 不重复 `begin_retreat`；自然濒死/掉盾 |

### 守卫战 / 撤离物

| 项目 | 规则 |
|------|------|
| 触发 | 拾取 `retreat_chance`（**大概率**，非 100%） |
| 未命中 | 不强制 Boss/撤离；普货占格 |
| **胜** | 额外奖励 + **直接结算** |
| **败** | 濒死 + 返程；撤离物 **无封存特权**（战力+空格才进箱） |
| 进箱 | 不损毁装备；物资可消耗转盾 |

---

## 四、本趟战利品 · 网格

| 项目 | 定稿 |
|------|------|
| **安全箱** | S2 **小网格**（如 2×2），建筑升级扩格 |
| **外露** | **占格**；整趟负重 |
| **形状（首期）** | 1×1、1×2、2×1、2×2 |
| **类型** | 装备 + 材料（建筑/进阶/转生，`material_value`） |
| **自动入箱** | 按价值密度优先；满则 **挤掉密度最低整件** → 被挤出进外露 |
| **堆叠** | 材料可 1 格多数量 |

### 返程掉装

- **有护盾**（任一层 > 0）：不掉。
- **盾破**：`retreat_hit_drop_chance` 从 **外露** 随机丢 **整件**。
- **丢失上限**：外露 **可能全部丢失**（无固定 3 件顶）；养成调概率、盾、装箱。
- **直接结算**（Boss/宝库胜）：无返程掉装阶段。

### 外露满（待定默认）

- 建议：**不再拾取进网格** 或挤掉外露最低密度（实现时二选一）。

---

## 五、撤离点

- `extract_distance`：战败/强制/价值撤等 **第一程** 目标，避免 Boss 败后走全程。
- `retreat_final_destination`：通常 0（大营）。
- 抵达撤离点 → `extract_reached` → 可选第二程回大营。

---

## 六、返程刷怪

| 档 | 刷怪 |
|----|------|
| **正常返程** | **稀疏**（`retreat_spawn_interval_mult` 偏大、`retreat_spawn_pack` 偏小） |
| **Boss 追击** 或 **守卫追击** | **加密**（chase 专用倍率） |

护盾与刷怪独立；追击可 `shield_damage_mult` 加快扣盾。

---

## 七、返程护盾（双池）

### 7.1 结构

```
retreat_shield_total = equip_shield_current + material_shield_current

受击扣减：
  1) 先扣 equip_shield_current（装备护盾）
  2) 再扣 material_shield_current（物资护盾）
  3) 皆为 0 → 盾破 → 仅外露掉装
```

UI 建议：`装备 800 / 物资 400` 或双色条。

### 7.2 装备护盾

| 项目 | 规则 |
|------|------|
| 来源 | **穿着**且 **未在护盾 CD** 的装备 → `shield_contribution`（防护向属性/评分） |
| 损毁 | **不损毁** |
| **CD** | `begin_retreat` 时计入 `equip_shield_max` 的装备 → 本趟结束后 **`shield_cd_runs_left = N`（建议 2~3 场出征）** |
| CD 中 | 该件贡献为 0；物资/天赋仍可加盾 |
| 不触发 CD | 手动撤、Boss/宝库胜（无开盾） |

### 7.3 物资护盾

| 项目 | 规则 |
|------|------|
| 来源 | 材料 `material_value`；开撤时基础值 + **濒死烧材料加注** |
| 消耗 | 转入护盾的 **材料从网格删除**（默认 **优先安全箱**，不足再外露） |
| 转化率 | 调参 + 上限（防刷盾） |
| 装备 | **不**烧穿着装备转盾 |

### 7.4 上限公式（建议）

```text
equip_shield_max   = Σ 未 CD 装备贡献
material_shield_max = f(网格材料) + 濒死转化（有 cap）
shield_max = (equip + material) × (1 + 职业/天赋) × reason_mult
```

`reason_mult` 示例：`combat_fail` ≥ `forced`/`auto_value` ≥ 0；`manual` 无盾。

### 7.5 其它护盾原则

- **限制满盾 refresh**：已在返程时 emergency **不** 重置 100%（可改为补 30% 或本趟一次）。
- **稳定度**：大伤害盾吸收时可 **微量扣团队稳定**（震荡），避免只掉装不掉稳定。
- **锚点濒死**：领队倒后盾上限 ×0.7 或副队长接任（不重算满盾）。
- **慢回盾 / 消耗品**：可选后期内容。

---

## 八、结算语义（实现注意）

建议拆分标志，避免单一 `forced_withdraw` 包打天下：

| 标志 | 含义 |
|------|------|
| `boss_defeated` / `extract_clear` | 通关直接结算 |
| `completed_retreat` | 走过返程抵营 |
| `manual_withdraw` | 手动斩仓 |
| `run_success` | 文案用；与 forced 解耦 |

---

## 九、数据文件（计划）

| 文件 | 内容 |
|------|------|
| `map_templates.json` | `extract_distance`、`retreat_*`、chase 刷怪、`extract_boss` |
| `loot_materials.json` | 材料占格、`material_value` |
| `extract_items.json` | `retreat_chance`、`secure_power`、`boss_encounter` |
| `auto_retreat_rules.json` | 可选规则 |
| `base_data.json` | `safe_box_grid`、`inventory` 网格 |

---

## 十、现码差异摘要

- `total_loot` 扁平数组 → 需 `GridInventory`（箱/外露/基地）。
- `manual_withdraw` 仍 `begin_retreat` → 应改为斩仓结算。
- 掉装仍从 `total_loot` 抽 → 应仅 `exposed`。
- 护盾单池 + 领队 HP → 应双池 + 装备 CD。
- `refresh_retreat_shield` 满盾 → 应限制。

---

## 十一、建议实现顺序

1. 网格与安全箱 / 外露  
2. 战败 vs Boss 胜分支、撤离点  
3. 双池护盾 + 装备 CD + 仅外露掉装  
4. 智能撤离、撤离物守卫战  
5. 刷怪档位、UI 与结算标志  

参见 [design-near-death.md](design-near-death.md)、[design-expedition-meta.md](design-expedition-meta.md)。
