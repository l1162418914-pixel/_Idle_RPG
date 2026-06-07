# UI 与子系统连接完整性审计摘要

> **项目**：TBH Idle RPG（Godot 4.x）  
> **范围**：已有后端/数据 vs UI 显示、操作、反馈  
> **结论**：审计文档（实现修复时同步更新本文「状态」列）  
> **同步**：2026-06-06 — **B-2 Sprint**：觉醒/Buff/技能 CD、套装 StatResolver、战斗测试模式（见下表）

---

## 〇、2026-06-06 战斗/UI 接线状态（Dev Sprint B-2）

| ID | 模块 | 后端 | UI | 状态 | 探针 / 备注 |
|----|------|------|-----|------|-------------|
| **T-01** | 套装 → 战斗属性 | `StatResolver` + `EquipmentSetRegistry.calc_set_bonus` | `EquipmentUI` N/M 文案（`铁卫 2/3`） | ✅ **F5 YES** | 01a～01d · D1 铁卫 3/3 |
| **T-03** | 技能 CD | `CombatEntity` CD 槽 · `skill_templates` | `UnitView` 角标（火/疗/嘲/射；青=就绪·橙=秒） | ✅ **逻辑 YES** | 03a～03d · F5 延期 |
| **T-06** | Buff / 觉醒头标 | `buff_system` · `near_death_awakening_service` | `UnitView.sync_status_from_entity`；Buff chips + 觉醒徽章 | ✅ **CTO YES** | 06a～06d · F5 test_08 |
| **T-04** | 战斗测试模式 | `BattleDebug` 运行时开关 | `CombatView` Debug 工具栏「测试 ON/OFF」 | ✅ **逻辑 YES** | 04a～04d · 测试图自动 ON |
| **T-02** | 远程后排 | `CombatController` 走位/射程 | 弹道 `play_ranged_strike`；位置仍 HBox 映射 | ✅ **CTO YES** | 02-1～02-4 · 脚线统一归 T-02b |
| **T-02c** | 纯佣兵出征 | `SquadFormationService` 主角不占槽 | `FormationUI` 主角卡片 · `SquadUI` 留营文案 | ✅ **F5 YES** | 2c-1～2c-6 · D1 战略核心留营 |
| **T-02b** | 战场脚线/槽位 | `BattlefieldSlots` 60×48 常量 | `CombatView` 脚线 + `UnitView` sprite inset | ✅ **逻辑 YES** | 02b-1～02b-2 · F5 延期 |

**仍 OPEN（本文 §三 P0/P1 未勾）**：研究所/转生/云存档/多槽；出征网格战利品满格反馈；护盾 CD 显示。

---

## 一、架构速览

| UI | 职责 | 主要后端 |
|----|------|----------|
| `BaseUI` | 大营、地图、建筑、名册、编队入口 | `GameManager`, `DataLoader`, `SquadFormationService` |
| `FormationUI` | A/B 半组编队 + **主角留营卡片** | `GameManager.formation_*` |
| `SquadUI` | 出征前确认（编队只读预览） | `SquadFormationService` → `start_run` |
| `RunUI` | 行程、稳定度、追击、护盾、撤离提示 | `WorldRun.tick`, `run_event` → `main` |
| `CombatView` | 战斗色块、日志、**Debug 测试模式** | `CombatController` 信号 |
| `UnitView` | 单位 HP、**Buff/觉醒/技能 CD 角标** | `CombatEntity` + `sync_status_from_entity` |
| `ResultUI` | 结算、掉落对比、换装 | `GameManager.run_ended` |
| `EquipmentUI` | 背包、穿脱、**套装 N/M 文案** | `InventorySystem`, `EquipmentSetRegistry`, `StatResolver` |

**事件中枢**：`WorldRun.run_event` → 仅 `main.gd._on_world_run_event` → `RunUI.show_run_hint`  
**战斗可视化**：`CombatController` 信号 → `CombatView` / `UnitView`（不接 `run_event`）

---

## 二、优先级总表

| 级别 | 含义 | 数量级 |
|------|------|--------|
| **P0** | 系统在跑，玩家几乎感知不到或信息误导 | **0 项**（T-02b 脚线已接线 · F5 待补） |
| **P1** | 数据/建筑/存档有，玩法或入口未接 | 4 项 |
| **P2** | 逻辑在后台，反馈弱或分散 | 5 项 |
| **P3** | 预留、死代码、开发者向 | 若干 |

---

## 三、P0 — 优先处理

### 1. ~~套装：有展示，战斗未生效~~ → ✅ T-01 逻辑 YES（2026-06-06）

- **数据**：`data/equipment_sets.json`
- **战斗**：`StatResolver` 各 `get_*` 接入 `EquipmentSetRegistry.calc_set_bonus`
- **UI**：`EquipmentUI.get_active_bonus_lines()` 显示 `铁卫 2/3 ·物防+8` 等
- **待 F5**：穿脱铁卫 → 面板 DEF/HP 与文案同步肉眼确认

### 2. ~~远程攻击：战场站位 UI 弱~~ → ✅ T-02b 逻辑 YES（2026-06-06）

- **逻辑** ✅：`CombatController` 远程前排 cap、后排走位（T-02）
- **UI** ✅：`BattlefieldSlots` 60×48 · `CombatView` 脚线 `BattlefieldFootline` · `UnitView` sprite inset
- **待 F5**：接战时色块脚底对齐脚线、后排间距肉眼确认

### 3. ~~技能/Buff/觉醒：辨识度极低~~ → ✅ 大部分已接线（T-03 / T-06）

| 子项 | 状态 | 实现 |
|------|------|------|
| Buff 角标 | ✅ | `UnitView._refresh_buff_chips()` · `sync_status_from_entity` |
| 觉醒头标 | ✅ | `_awakening_badge` + 名称 `(觉醒·*)` 刷新 · F5 test_08 YES |
| 技能 CD 角标 | ✅ | `_skill_row` · `火4` / `疗` 样式 · `combat_view` 每帧刷新 |
| 技能专属闪效 | 🟡 | 仍有 `play_skill_flash()`；与普攻白闪区分度一般 |
| 日志排队 | 🟡 | `BattleDebug.log_line_interval()`；慢速/Debug 可缓解 |

---

## 四、P1 — 壳子在，玩法未接

| 系统 | 已有 | 缺失 |
|------|------|------|
| **研究所** | `base_data.json`（`unlock_rebirth`、`rebirth_bonus_rate`）；大营列表只读 | 无升级按钮（`main` 仅 4 建筑）；无任何代码读 rebirth 配置 |
| **转生** | 存档 `rebirth_count` / `rebirth_bonus` | 无触发流程、无加成应用、无 UI |
| **云存档** | `SaveManager.get_cloud_payload` / `apply_cloud_payload` | 无调用方；无云同步 UI |
| **多槽存档** | 3 槽 API | 仅 `character_create` 用槽 1 |
| **仓库容量** | ✅ `GameManager.get_inventory_capacity()`；`InventorySystem.can_add()`；`EquipmentUI` `背包 (n/max)` | 无（2026-06-05 已接线） |

---

## 五、P2 — 逻辑在跑，玩家难感知

| 系统 | 实现 | UI 现状 | 缺口 |
|------|------|---------|------|
| **自动撤离** | `auto_retreat_service.gd` + `auto_retreat_rules.json` | 携带价值行；「仅安全箱」勾选；触发 toast | 无填充率条；`safe_loot_fill` 已算未显示 |
| **搀扶** | `near_death_run_service` → `supported_by_id` | 无 | 出征中不显示谁搀谁 |
| **伤痕** | 濒死 `add_scar_stack()` | 大营/出征前有 `伤×N` | 战中无；新增伤痕无 toast |
| **觉醒** | `near_death_awakening_service` + `run_event` | ✅ RunHint + **UnitView 头标刷新**（T-06） | `team_shield` 变盾无专门提示 |
| **护盾 CD** | `retreat_shield_service` → `shield_cd_runs_left` | 无 | 装备 UI/结算均不显示 CD |
| **护盾每击** | `retreat_shield_hit` 事件 | 盾条每 tick 更新 | `main.gd` 无 match 分支，无吸收 toast |
| **追击** | `BossChaseService` + `RunUI` 较完整 | 距离/压力/三按钮/蓄力条 | 状态碎；返程间隙 `CombatView` 空白 |

---

## 六、已对齐较好的部分（供对照）

- **撤离物**：`ExtractItemService` + `RunUI` 撤离物行 + 守卫战 hint + Result 摘要
- **Boss 追击**：`RunUI` 距离/压力/按钮 + `main` 多种 chase toast
- **返程护盾**：盾条 + 数值行 + 破碎 hint
- **编队**：`FormationUI` 拖拽/半组/恢复锁；**T-02c** 主角留营 + 纯佣兵出征
- **仓库容量**：`InventorySystem` + `EquipmentUI` `背包 (已用/上限)`
- **套装战斗**：`StatResolver` + `EquipmentUI` N/M（**T-01**）
- **战中状态角标**：Buff / 觉醒 / 技能 CD（**T-06 / T-03**）
- **战斗 Debug**：`BattleDebug` + `CombatView` 工具栏（**T-04**）
- **地图解锁**：`BaseUI` 锁因 + Result 解锁提示

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

1. ~~套装进 `StatResolver` + UI N/M~~ — ✅ **T-01 逻辑 YES**（F5 延期）
2. ~~`CombatView` Buff/觉醒/技能 CD~~ — ✅ **T-06 / T-03 CTO/逻辑 YES**
3. ~~`CombatController` 远程走位~~ — ✅ **T-02 CTO YES**；脚线 → **T-02b**
4. ~~仓库容量~~ — ✅ 已完成
5. **F5 探针日**（A 线）：T-01 / T-02c / T-03 / T-04 + test_03 / grassland / test_09
6. 研究所升级钮 + 转生流程（冻结 T-07/T-08）
7. `RunUI` 安全箱填充率 + 自动撤规则说明
8. `EquipmentUI` 护盾 CD；搀扶/伤痕战中提示
9. 存档多槽选档、云同步（API 已就绪）

---

## 九、实机验证清单（5 分钟）

| 步骤 | 预期（2026-06-06） |
|------|---------------------|
| 凑 2 件铁卫套装 → `EquipmentUI` 文案 vs 面板 DEF | **应一致**（T-01；F5 待勾） |
| 法师/游侠接战 → 脚下技能角标 | **应有** 火/疗/射；橙=CD（T-03） |
| `test_08` 觉醒 → 单位头标与名称 | **应刷新** 觉醒徽章（T-06 ✅） |
| 远程接战 → 弹道 / 后排走位 | **有弹道**；站位脚线仍占位色块（T-02b） |
| 测试图接战 → Debug 栏「测试模式 ON」 | **应自动 ON**（T-04） |
| 主角留营 + A 组佣兵满血 → 出征 | **无养伤锁**（T-02c） |
| 大营 Actions → 研究所升级 | **仍无** |
| 返程护盾碎 → 回大营看装备 CD | **仍无显示** |

---

## 十、审计范围外刻意未动

- `bonus_exp` 不乘 `resource_yield`（与旧逻辑一致）
- `RunExtractItem` 架构文档按需再写（见 `SAVE_FORMAT` / 会话审查笔记）

---

## 相关文档

- [PROJECT_STATUS.md](PROJECT_STATUS.md) — Dev Sprint · B-2 交付
- [design-combat-stack.md](design-combat-stack.md) — 战斗专题地图
- [DESIGN_INDEX.md](DESIGN_INDEX.md)
- [TEST_PLAYBOOK.md](TEST_PLAYBOOK.md)
- [ACCEPTANCE_PROGRESS.md](ACCEPTANCE_PROGRESS.md)
