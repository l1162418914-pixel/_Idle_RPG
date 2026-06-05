# 会话角色规则（session_rules）

> 各会话**只读与自己角色对应的一份**短规则；铁律与任务细节见 `docs/` 主文档。

## 哪个会话读哪个

| 会话 | 开场复制 | 必读短规则 | 必读主文档 |
|------|----------|------------|------------|
| **PM / CTO** | 见 `PM_RULES.md` 文末 | [PM_RULES.md](PM_RULES.md) | [CTO.md](../CTO.md)、[PROJECT_STATUS.md](../PROJECT_STATUS.md)、[ARCHITECTURE.md](../ARCHITECTURE.md) — **不用六段以外的开发 §三 模板** |
| **功能开发** | 见 `FEATURE_DEV_RULES.md` 文末 | [FEATURE_DEV_RULES.md](FEATURE_DEV_RULES.md) | [PROJECT_STATUS.md](../PROJECT_STATUS.md)、[ARCHITECTURE.md](../ARCHITECTURE.md)、[TASK_PROTOCOL.md](../TASK_PROTOCOL.md) — **不读 CTO.md 为主规则、不用六段格式** |
| **Bug 修复** | 见 `BUGFIX_RULES.md` 文末 | [BUGFIX_RULES.md](BUGFIX_RULES.md) | [BUG_FIX_WORKFLOW.md](../BUG_FIX_WORKFLOW.md)、[PROJECT_STATUS.md](../PROJECT_STATUS.md)、[ARCHITECTURE.md](../ARCHITECTURE.md) |

## Cursor 规则对应

| 文件 | 挂载方式 |
|------|----------|
| `.cursor/rules/project-baseline.mdc` | 全局（所有会话） |
| `.cursor/rules/cto-pm.mdc` | PM 会话 @ 或手动启用 |
| `.cursor/rules/feature-dev.mdc` | 开发会话 @ 或手动启用 |
| `.cursor/rules/bug-fix.mdc` | Bug 会话 @ 或手动启用 |

## 任务板位置

任务 ID 以 **`PROJECT_STATUS.md`** 为准（如 `T-02a`），不使用已废弃的 `TASK-xxx` / `BUG-xxx` 编号。
