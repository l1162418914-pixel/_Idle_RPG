# 玩法设计文档索引

讨论定稿；核心玩法已实现，扩展以各分册「planned」为准。

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
| [design-retreat.md](design-retreat.md) | 2/7 返程、战利品网格、智能撤离、护盾双池 |
| [design-near-death.md](design-near-death.md) | 5/7 濒死、搀扶、伤痕、绝境觉醒 |
| [design-expedition-meta.md](design-expedition-meta.md) | 1/7 挂机再战、双半组 4+2、养伤锁（交叉引用） |
| [design-boss-chase.md](design-boss-chase.md) | 7/7 Boss 追击、压力缩放、击杀=通关结算、返程反击按钮 |

相关现网说明：[CTO.md](CTO.md)、[PROJECT_STATUS.md](PROJECT_STATUS.md)、[TASK_PROTOCOL.md](TASK_PROTOCOL.md)、[BUG_FIX_WORKFLOW.md](BUG_FIX_WORKFLOW.md)（缺陷修复）、[ARCHITECTURE.md](ARCHITECTURE.md)、[SAVE_FORMAT.md](SAVE_FORMAT.md)（存档字段）、[MAP_UNLOCK.md](MAP_UNLOCK.md)、[UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md)（UI/子系统连接审计）、[TEST_PLAYBOOK.md](TEST_PLAYBOOK.md)（QA 对照测试档案）、[TEST_SCENARIOS.md](TEST_SCENARIOS.md)（QA 简表）。
