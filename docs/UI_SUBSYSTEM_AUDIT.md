# UI 与子系统连接完整性审计摘要

> **项目**：TBH Idle RPG（Godot 4.x）  
> **范围**：已有后端/数据 vs UI 显示、操作、反馈  
> **结论**：审计文档（实现修复时同步更新本文「状态」列）  
> **同步**：2026-06-05 — 仓库容量已接线（见 §四、§六、§八）

---

## 一、架构速览

| UI | 职责 | 主要后端 |
|----|------|----------|
| `BaseUI` | 大营、地图、建筑、名册、编队入口 | `GameManager`, `DataLoader`, `SquadFormationService` |
| `FormationUI` | A/B 半组编队 | `GameManager.formation_*` |
| `SquadUI` | 出征前确认（编队只读预览） | `SquadFormationService` → `start_run` |
| `RunUI` | 行程、稳定度、追击、护盾、撤离提示 | `WorldRun.tick`, `run_event` → `main` |
| `CombatView` | 战斗色块、日志、调试条 | `CombatController` 信号 |
| `ResultUI` | 结算、掉落对比、换装 | `GameManager.run_ended` |
| `EquipmentUI` | 背包、穿脱、套装文案 | `InventorySystem`, `EquipmentSetRegistry` |

**事件中枢**：`WorldRun.run_event` → 仅 `main.gd._on_world_run_event` → `RunUI.show_run_hint`  
**战斗可视化**：`CombatController` 信号 → `CombatView`（不接 `run_event`）

---

## 二、优先级总表

| 级别 | 含义 | 数量级 |
|------|------|--------|
| **P0** | 系统在跑，玩家几乎感知不到或信息误导 | 3 项 |
| **P1** | 数据/建筑/存档有，玩法或入口未接 | 4 项 |
| **P2** | 逻辑在后台，反馈弱或分散 | 6 项 |
| **P3** | 预留、死代码、开发者向 | 若干 |

---

## 三、P0 — 优先处理

### 1. 套装：有展示，战斗未生效（信任问题）

- **数据**：`data/equipment_sets.json`
- **注册**：`equipment_set_registry.gd`（注释：「加成计算预留，当前仅展示」）
- **UI 已有**：`equipment_ui.gd` 显示激活套装文案；`result_ui.gd` 显示套装名
- **缺口**：
  - `equipment_system.gd` / `StatResolver` 不算套装 stats
  - 无 2/3 件进度（`count_equipped_pieces` 未用于 UI）
  - 玩家看到「物防+8」但面板数值可能不变
- **建议**：`StatResolver` 接入套装；`EquipmentUI` 显示 `铁卫 2/3`

### 2. 远程攻击：逻辑有射程，UI 无表现

- **逻辑**：`CombatEntity.position` + `attack_range`（模板 80–120 等）
- **UI**：`CombatView` 静态左右 HBox，不用 `position`，无走位/弹道
- **表现**：远程与近战同为色块白闪 + 飘字 + 日志 `A → B`
- **建议**：`UnitView` 增加射程/弹道/日志 `[远程]` 区分

### 3. 技能/Buff：有日志，辨识度极低

- **链路**：`CombatController.skill_cast` → `CombatView._on_skill_cast`（白闪 + 青色日志）
- **缺口**：
  - `buff_self` 只写 `buff_system`，UI 无 Buff 图标/条
  - 技能与普攻同款 `play_attack_flash()`
  - 日志经 `BattleDebug.log_line_interval()` 排队，快战易被淹没
  - 战中觉醒：`awakening_started` 有 RunHint，但 `UnitView` 只在 `setup()` 标 `(觉醒)`，触发后不刷新（可能仍显示 `(濒死)`）
- **建议**：技能专属 VFX；Buff 角标；觉醒时刷新 `UnitView`

---

## 四、P1 — 壳子在，玩法未接

| 系统 | 已有 | 缺失 |
|------|------|------|
| **研究所** | `base_data.json`（`unlock_rebirth`、`rebirth_bonus_rate`）；大营列表只读 | 无升级按钮（`main` 仅 4 建筑）；无任何代码读 rebirth 配置 |
| **转生** | 存档 `rebirth_count` / `rebirth_bonus` | 无触发流程、无加成应用、无 UI |
| **云存档** | `SaveManager.get_cloud_payload` / `apply_cloud_payload` | 无调用方；无云同步 UI |
| **多槽存档** | 3 槽 API | 仅 `character_create` 用槽 1 |
| **仓库容量** | ✅ `GameManager.get_inventory_capacity()`（仓库建筑等级 → `inventory_slots`）；`InventorySystem.can_add()` / `add()` 满仓失败；`EquipmentUI` 标题 `背包 (n/max)` | 无（2026-06-05 已接线；勿重复开发） |

**模式**：按钮/建筑/存档字段有 → 玩法或反馈没接。

---

## 五、P2 — 逻辑在跑，玩家难感知

| 系统 | 实现 | UI 现状 | 缺口 |
|------|------|---------|------|
| **自动撤离** | `auto_retreat_service.gd` + `auto_retreat_rules.json` | 携带价值行；「仅安全箱」勾选；触发 toast | 无填充率条；`safe_loot_fill` 已算未显示；`auto_retreat_value_enabled` 无开关且未存档；`block_auto_retreat_until_boss` 静默 |
| **搀扶** | `near_death_run_service` → `supported_by_id` | 无 | 出征中不显示谁搀谁 |
| **伤痕** | 濒死 `add_scar_stack()` | 大营/出征前有 `伤×N` | 战中无；新增伤痕无 toast |
| **觉醒** | `near_death_awakening_service` + `run_event` | RunHint 金色 toast | 单位头标不更新；`team_shield` 变盾无专门提示 |
| **护盾 CD** | `retreat_shield_service` → `shield_cd_runs_left` | 无 | 装备 UI/结算均不显示 CD |
| **护盾每击** | `retreat_shield_hit` 事件 | 盾条每 tick 更新 | `main.gd` 无 match 分支，无吸收 toast |
| **追击** | `BossChaseService` + `RunUI` 较完整 | 距离/压力/三按钮/蓄力条 | 状态碎（世界追击 vs 接战僵持 vs 撤离物线）；返程间隙 `CombatView` 空白 |

**追击说明**：不是「没 UI」，而是信息分散、难读 — 建议降 P0，归 P2 体验优化。

---

## 六、已对齐较好的部分（供对照）

- **撤离物**：`ExtractItemService` + `RunUI` 撤离物行 + 守卫战 hint + Result 摘要
- **Boss 追击**：`RunUI` 距离/压力/按钮 + `main` 多种 chase toast
- **返程护盾**：盾条 + 数值行 + 破碎 hint
- **编队**：`FormationUI` 拖拽/半组/恢复锁 — 后端与 UI 一致
- **仓库容量**：`InventorySystem._capacity()` → `GameManager.get_inventory_capacity()`；`EquipmentUI` 显示 `背包 (已用/上限)`；满仓 `add()` 返回 false
- **手动斩仓**：Withdraw 对话框 + Result 标题/舍弃件数
- **地图解锁**：`BaseUI` 锁因 + Result 解锁提示
- **RunExtractItem 架构**：数据脚本 + `ExtractItemService` 工厂 — 解析问题已解

---

## 七、死代码 / 弱连接（清理或接线时参考）

| 位置 | 说明 |
|------|------|
| `base_ui._on_upgrade_pressed` | 未连接；升级走 `main.gd` 四按钮 |
| `squad_ui._on_merc_selected` | 未连接；佣兵按钮 `disabled=true` |
| `main._on_map_selected` | 死代码；地图在 `BaseUI` |
| `GameManager.get_available_maps` 等 | 无外部调用 |
| `save_completed` / `load_completed` | 无 UI 监听 |
| `upgrade_building()` 返回值 | 失败时无「金币不足」toast |

---

## 八、建议修复顺序（给开发排期）

1. 套装进 `StatResolver` + UI 显示 N/M 件（消除展示/战斗不一致）— 对应 `PROJECT_STATUS` **T-01**
2. `CombatView` 远程/技能/Buff/觉醒头标（战斗可读性）— 对应 **T-02** / **T-03**
3. ~~仓库容量接入 `InventorySystem` + `EquipmentUI` n/max~~ — **✅ 已完成**（勿重复）
4. 研究所升级钮 + 转生流程（读 `unlock_rebirth` / `rebirth_bonus_rate`）
5. `RunUI` 安全箱格子填充率 + 自动撤规则说明
6. `EquipmentUI` 护盾 CD；搀扶/伤痕战中提示
7. 存档多槽选档、云同步（API 已就绪）

---

## 九、实机验证清单（5 分钟）

| 步骤 | 预期（当前） |
|------|----------------|
| 凑 2 件同套装 → 看 `EquipmentUI` 文案 vs 面板 DEF | **不变**（套装未进战斗） |
| 远程职业出征 → `CombatView` 距离/弹道差异 | **无** |
| 大营 Actions → 研究所升级 | **无** |
| 返程护盾碎 → 回大营看装备 CD | **无显示** |
| 战中触发觉醒 → 单位名是否仍 `(濒死)` | **可能仍是** |

---

## 十、审计范围外刻意未动

- `bonus_exp` 不乘 `resource_yield`（与旧逻辑一致）
- `RunExtractItem` 架构文档按需再写（见 `SAVE_FORMAT` / 会话审查笔记）

---

## 相关文档

- [DESIGN_INDEX.md](DESIGN_INDEX.md)
- [TEST_PLAYBOOK.md](TEST_PLAYBOOK.md)
- [ACCEPTANCE_PROGRESS.md](ACCEPTANCE_PROGRESS.md)
