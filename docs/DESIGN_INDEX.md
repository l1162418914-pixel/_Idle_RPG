# 玩法设计文档索引

讨论定稿；核心玩法已实现，扩展以各分册「planned」为准。

> **设定总纲** → **[GAME_BIBLE.md](GAME_BIBLE.md) v0 初版**（单局远征壳子）  
> **局外成长 / 大营经营（占位）** → **[design-meta-base.md](design-meta-base.md)**（待填）

---

## 开工前必读（强制）

**先按会话角色选读（不要混用）：**

| 会话 | 必读 |
|------|------|
| **CTO** | [PM_RULES.md](session_rules/PM_RULES.md) → [CTO.md](CTO.md) → [PROJECT_STATUS.md](PROJECT_STATUS.md) → [ARCHITECTURE.md](ARCHITECTURE.md) → worklog |
| **开发 Agent** | [FEATURE_DEV_RULES.md](session_rules/FEATURE_DEV_RULES.md) → [PROJECT_STATUS.md](PROJECT_STATUS.md) → [ARCHITECTURE.md](ARCHITECTURE.md) → [TASK_PROTOCOL.md](TASK_PROTOCOL.md) → worklog |
| **Bug 修复** | [BUGFIX_RULES.md](session_rules/BUGFIX_RULES.md) → [BUG_FIX_WORKFLOW.md](BUG_FIX_WORKFLOW.md) → … |

全员基线：[ARCHITECTURE.md](ARCHITECTURE.md)。任务板：[PROJECT_STATUS.md](PROJECT_STATUS.md)。

再按当前 TASK 选读下方玩法分册。

**按会话类型追加（复制或 @ Cursor 规则）：**

| 会话 | 短规则 | Cursor 规则 |
|------|--------|-------------|
| PM / CTO | [session_rules/PM_RULES.md](session_rules/PM_RULES.md) | `.cursor/rules/cto-pm.mdc` |
| 功能开发 | [session_rules/FEATURE_DEV_RULES.md](session_rules/FEATURE_DEV_RULES.md) | `.cursor/rules/feature-dev.mdc` |
| Bug 修复 | [session_rules/BUGFIX_RULES.md](session_rules/BUGFIX_RULES.md) | `.cursor/rules/bug-fix.mdc` |

---

| 文档 | 主题 |
|------|------|
| **[GAME_BIBLE.md](GAME_BIBLE.md)** | **设定集 v0**：单局远征、壳子五源、现网清单 |
| **[EXTERNAL_AI_BRIEF.md](EXTERNAL_AI_BRIEF.md)** | **外部 AI 评审用项目简报**（整份复制即可） |
| [design-meta-base.md](design-meta-base.md) | **局外成长 + 大营经营**（初版占位，待填） |
| [design-retreat.md](design-retreat.md) | 2/7 返程、战利品网格、智能撤离、护盾双池 |
| [design-stability-lineage.md](design-stability-lineage.md) | **压力机制血统**（提灯向）+ 返程掉物（塔科夫/三角洲向） |
| [design-loot-lineage.md](design-loot-lineage.md) | **安全箱 vs 外露**（塔科夫 / 三角洲） |
| [design-failure-lineage.md](design-failure-lineage.md) | **失败掉人**（猎杀+鸭科夫；MIA/回收/救援队） |
| [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) | **失败掉人 · CTO 实现对照**（冲突、分期） |
| [design-near-death.md](design-near-death.md) | 5/7 濒死、搀扶、伤痕、绝境觉醒 |
| [design-expedition-meta.md](design-expedition-meta.md) | 1/7 挂机再战、双半组语义、养伤锁（**T-UI-FORM** 定案 2026-06-06） |
| [design-boss-chase.md](design-boss-chase.md) | 7/7 Boss 追击、压力缩放、击杀=通关结算、返程反击按钮 |
| [design-combat-stack.md](design-combat-stack.md) | **战斗子系统地图**：接战类型、tick 顺序、文件索引 |
| [design-march-visual.md](design-march-visual.md) | **CQ 式横版条**：同一跑道、接战停滚、返程向左可视化 |
| [design-march-events.md](design-march-events.md) | **跑图自动搜索 + 里程碑事件**（草案，未排 TASK） |
| [design-pc-shell.md](design-pc-shell.md) | **PC 主壳 THB 2.0**（T-11a/b 线框、Dock、四态槽位、开发工单） |
| [design-base-ui.md](design-base-ui.md) | **大营 UI 重构 T-UI-B**（B1 地图卡片、B2~B4 路线图） |

相关现网说明：[CTO.md](CTO.md)、[PROJECT_STATUS.md](PROJECT_STATUS.md)、[TASK_PROTOCOL.md](TASK_PROTOCOL.md)、[BUG_FIX_WORKFLOW.md](BUG_FIX_WORKFLOW.md)（缺陷修复）、[ARCHITECTURE.md](ARCHITECTURE.md)、[SAVE_FORMAT.md](SAVE_FORMAT.md)（存档字段）、[MAP_UNLOCK.md](MAP_UNLOCK.md)、[UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md)（UI/子系统连接审计）、[TEST_PLAYBOOK.md](TEST_PLAYBOOK.md)（QA 对照测试档案）、[TEST_SCENARIOS.md](TEST_SCENARIOS.md)（QA 简表）。
