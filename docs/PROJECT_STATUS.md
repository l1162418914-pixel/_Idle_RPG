# 项目状态（PROJECT_STATUS）

> **开工必读链：** [session_rules/README.md](session_rules/README.md)（按角色）→ [CTO.md](CTO.md) / [TASK_PROTOCOL.md](TASK_PROTOCOL.md) → **本文** → [ARCHITECTURE.md](ARCHITECTURE.md) → 最近 worklog。  
> 最后更新：2026-06-05（CTO：登记 T-02c 编队提示）

---

## 当前阶段

**Sprint 1 — P0 战斗体验修复（插队）**

用户实测：前排濒死单位返程仍顶在前面挨打。CTO 批准 **暂停 T-01**，优先 **T-02a**。

---

## 当前任务

| 项 | 值 |
|----|-----|
| **ID** | `T-02a` |
| **名称** | 濒死撤退站位 + 敌方目标优先级 |
| **状态** | 🟡 待 CTO 验收 |
| **优先级** | P0 bug（用户复现） |
| **预估影响** | `combat_controller.gd`（主改）；必要时 `combat_entity.gd` |

### 背景（根因）

1. 敌方 `_find_nearest_alive` / `_find_nearest_in_range` 只排除 `is_dead()`，**濒死 DOWNED 仍可选中**。
2. 濒死单位 `is_incapacitated()` → 不移动；返程时存活者 `_drift_homeward`，濒死者 **position 冻在倒下处**（常为前排）。
3. `supported_by_id` 仅影响世界层返程移速，**战斗内未用**。

### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **2a-1 目标优先级** | 敌方选攻击目标时 **跳过** `not can_fight()` 的友方（含 DOWNED 濒死）；无其他可打目标时再 fallback（或无目标） |
| **2a-2 撤回复位** | 濒死进入 DOWNED 时，**一次性**将 `position` 置于友方后排（取 `min(友方 position)` 或 `ALLY_SPAWN_X`，不每 tick 移动） |
| **2a-3 返程入场** | 返程战斗开始（`_march_retreat_combat`）时，对 **已在场上濒死** 的友方再执行一次后排归位（覆盖「先濒死、后返程」） |

### 不在范围

- T-02 远程后排射程/走位大改
- T-02b CombatView 72/48 像素统一
- 搀扶跟随动画（`supported_by_id` 战斗内绑定）
- 套装 StatResolver（T-01 暂停，做完 T-02a 再开）
- 研究所 / 转生 / 云存档

### 设计对齐说明

`design-near-death.md`：濒死「不攻击、不移动」= **无自主 tick 移动**。  
2a-2/2a-3 的 position 快照视为 **搀扶拖至后排**，非违背铁律；无需改 ARCHITECTURE。

---

## 冻结项（本阶段禁止开发）

- T-01 套装（⏸ 暂停，非取消）
- T-07 研究所 / T-08 转生（P1）
- T-09 多槽 / T-10 云存档
- A3 属性管线重构（已封板）
- 无 CTO 授权的跨模块重构

---

## 任务板

| ID | 任务 | 优先级 | 状态 | 门禁 |
|----|------|--------|------|------|
| T-00 | QA 基线验收 | Sprint 0 | 🟠 进行中 | 并行 |
| T-01 | 套装 → StatResolver + UI N/M | P0 | ⏸ **暂停** | T-02a YES 后恢复 |
| **T-02a** | **濒死撤退站位 + 目标优先级** | **P0** | 🟡 **待 CTO 验收** | 开发已交付 |
| T-02 | 远程后排调参/站位 | P0 | ⏸ | T-02a YES |
| T-02c | 主角独立 + 纯佣兵可出征 | **P0** | 📋 **已登记** | T-02a YES 后 |
| T-02b | CombatView 位置映射统一 | P2 | ⏸ | T-02 后 |
| T-03 | 技能 CD + active_skills | P0 | ⏸ | T-02 YES |
| T-04 | 战斗测试模式 | P0 | ⏸ | — |
| T-05 | 出征网格 UI | P0 | ⏸ | — |
| T-06 | Buff / 觉醒头标 | P0 | ⏸ | — |
| T-07~T-11 | 见上版 | — | 🔒/🟡 | — |

---

## T-02a 验收探针（CTO）

1. 编队：A 放 **前排槽**（靠近敌人的槽位），另 1 人可战斗。  
2. 去程或 **返程战斗** 中让 A 进入濒死（显示 `(濒死)`）。  
3. 返程战斗继续时：  
   - [ ] A 的战场 position **位于友方最左/后排**（比存活战斗单位更靠后）  
   - [ ] 敌人 **优先攻击** 仍能战斗的友方，而非 A  
   - [ ] A 仍不攻击、不自主移动（觉醒窗口行为不变）  
4. 若全员濒死或仅 A 在场：敌人行为不崩溃（可无目标或仅收尾逻辑）。  
5. diff 仅 `combat_controller.gd`（及必要时 `combat_entity.gd`）；未改 StatResolver / 套装 / 转生。

**通过后**：恢复 **T-01** 为当前任务（或按 CTO 指示改 T-02）。

---

## T-02c backlog（主角独立 + 纯佣兵可出征 · 用户定案 2026-06-05）

**现象**：主角占 A/B 槽位时另一半组无法出征；主角休整/濒死时佣兵组也无法单独出发。  
**根因**：`start_run` / `half_can_deploy` 强制主角在场且占槽。

**CTO 定案（用户确认）**：

| 规则 | 说明 |
|------|------|
| **主角不占 A/B 槽** | `squad_formation` A/B **仅存佣兵**；主角 UI 独立（战略核心），不进未编入/替补 |
| **纯佣兵可出征** | 任一半组 active 有 ≥1 `can_join_squad` **佣兵** 即可 `half_can_deploy`；**不要求**主角 `can_join_squad` |
| **出征名单** | `resolve_deploy_squad(half)` = 该半组可出战佣兵（最多 **4** 人上场）；**默认不追加主角** |
| **主角留营** | 纯佣兵趟：主角在大营继续慢回/医疗室治疗；**不获得**本趟 `run_kills` / `run_damage_dealt` |
| **养伤锁** | 仅当 A、B 两半组 **佣兵** 均无可出战成员时触发；主角状态**不**参与养伤锁 |
| **稳定度/护盾** | 已有 fallback：`stability.init(null)` 无主角加成；`get_retreat_shield_anchor` 用存活佣兵 |
| **读档迁移** | `ensure_formation` 从 A/B 移除 `player.merc_id` |

**交付范围（T-02a 通过后开）**：

| 子项 | 要求 |
|------|------|
| 2c-1 | 移除 `start_run` 对 `player.can_join_squad()` 的硬门禁（-3 仅保留主角已上阵但不可战等边缘，或废弃该路径） |
| 2c-2 | `half_can_deploy` / `pick_deploy_half` / `is_recovery_lock_active`：只判半组**佣兵** |
| 2c-3 | `resolve_deploy_squad`：仅佣兵；`rebalance` / `auto_fill` 排除 `player.merc_id` |
| 2c-4 | `FormationUI` / `SquadUI`：主角独立卡片 + 准备页明示「本趟佣兵出征，主角留营」 |
| 2c-5 | `base_ui` 再战/自动循环：主角不可战时仍允许佣兵半组出征（若半组就绪） |
| 2c-6 | 同步 `design-expedition-meta.md`、`SAVE_FORMAT.md` |

**不在范围（可后续 T-02d）**：「主角随行」勾选、战斗数值平衡、T-02a。

**探针**：

1. 主角**濒死/休整**，B 有 2+ 可出战佣兵 → **B 可出征**，场上无主角，主角留营回血。  
2. 主角满状态，A 可出战佣兵 ≥1 → **A 优先出征**，名单**无主角**（默认不带）。  
3. A、B 佣兵均不可出战 → 养伤锁，与主角状态无关。  
4. 纯佣兵趟结算：`player` HP/濒死不变；佣兵战果正常写入。  
5. 旧档：主角从 A/B 槽剥离后可按上规则出征。

---

## T-01 验收探针（暂停，待恢复）

（内容不变，见 git 历史或 TASK 文档。）

---

## 最近 TASK 完成记录

| ID | 完成日 | 是否进入下一任务 |
|----|--------|------------------|
| — | — | — |
