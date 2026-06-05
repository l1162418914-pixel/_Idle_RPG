# 任务协议（TASK_PROTOCOL）

> **开发 Agent 收工模板与门禁。**  
> CTO 章程见 [CTO.md](CTO.md)；开发开工见 [session_rules/FEATURE_DEV_RULES.md](session_rules/FEATURE_DEV_RULES.md)。

---

## 一、角色分工（勿混用）

| 角色 | 主规则 | 收工 / 回复格式 |
|------|--------|-----------------|
| **CTO** | [CTO.md](CTO.md) + [PM_RULES.md](session_rules/PM_RULES.md) | 每条回复 **六段格式**（§四） |
| **开发 Agent** | [FEATURE_DEV_RULES.md](session_rules/FEATURE_DEV_RULES.md) | **§三 完成模板** |
| **Bug 修复** | [BUGFIX_RULES.md](session_rules/BUGFIX_RULES.md) | [BUG_FIX_WORKFLOW.md](BUG_FIX_WORKFLOW.md) §四 |

**开发铁律**

1. 一次只做一个 TASK；最小 diff
2. 属性/存档边界见 [ARCHITECTURE.md](ARCHITECTURE.md)
3. 完工 **必须** 填 §三；`是否允许进入下一任务` 由 **CTO 复核** 后生效

---

## 二、开发 Agent 开工前必读

与 [FEATURE_DEV_RULES.md](session_rules/FEATURE_DEV_RULES.md) 一致：

1. [session_rules/FEATURE_DEV_RULES.md](session_rules/FEATURE_DEV_RULES.md)
2. [PROJECT_STATUS.md](PROJECT_STATUS.md)
3. [ARCHITECTURE.md](ARCHITECTURE.md)
4. **本文（TASK_PROTOCOL.md)** — §三 模板
5. 最近一篇 `docs/worklogs/YYYY-MM-DD.md`
6. （Bug 会话）[BUG_FIX_WORKFLOW.md](BUG_FIX_WORKFLOW.md)
7. （按需）[UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md)

```powershell
git pull origin main
Get-ChildItem docs\worklogs\*.md | Sort-Object Name -Descending | Select-Object -First 1
```

---

## 三、任务完成交付模板（强制）

每完成一个 TASK，在对话 / worklog / PR 说明中 **原样填写**：

```markdown
### [任务ID] 任务名称

**完成内容：**
- （做了什么）

**影响文件：**
- `path/to/file.gd`
- ...

**测试步骤：**
1. ...
2. ...

**验收标准：**
- [ ] ...

**是否允许进入下一任务：** YES / NO
```

### 填写说明

| 字段 | 要求 |
|------|------|
| **任务ID** | 与 `PROJECT_STATUS.md` 任务板一致，如 `T-01` |
| **完成内容** | 事实描述，不写计划 |
| **影响文件** | 仅列出实际 diff 文件；无变更写「无」 |
| **测试步骤** | 可 F5 复现的操作步骤 |
| **验收标准** | 可勾选；与 CTO 探针一致 |
| **是否允许进入下一任务** | 开发填 `YES` 表自测通过；**CTO 复核后**在 `PROJECT_STATUS` 改状态并写最终 YES/NO |

### 门禁

- **NO** → 不得开工下一 TASK；修复后重新提交 §三 模板。
- **YES** → CTO 更新 `PROJECT_STATUS.md`（当前任务指针 + 任务板状态），再指派下一项。

---

## 四、CTO 六段回复格式（仅 CTO 会话）

**开发 Agent 不用本节。** 完整说明见 **[CTO.md](CTO.md) §三**。CTO 每条回复须包含：

```
当前阶段：
当前任务：
影响文件：
风险：
测试方法：
下一步：
```

开发 Agent 收工须用 §三 模板；CTO 验收后用 §四 / CTO.md §三 格式指派下一项。

---

## 五、收工清单（与 worklog 并行）

1. 填写 §三 任务完成模板（若本日有 TASK 完工）
2. 复制 `docs/worklogs/_TEMPLATE.md` → `docs/worklogs/YYYY-MM-DD.md`
3. 更新 [PROJECT_STATUS.md](PROJECT_STATUS.md) 任务状态（CTO 或授权人）
4. `git commit`（代码 + worklog + PROJECT_STATUS 变更）

---

## 相关文档

- [PROJECT_STATUS.md](PROJECT_STATUS.md) — 任务板（开工第一读）
- [ARCHITECTURE.md](ARCHITECTURE.md) — 架构铁律
- [BUG_FIX_WORKFLOW.md](BUG_FIX_WORKFLOW.md) — 缺陷修复工作流（修 Bug 专用）
- [UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md) — UI/子系统审计
- [ACCEPTANCE_PROGRESS.md](ACCEPTANCE_PROGRESS.md) — QA 勾选
- [worklogs/README.md](worklogs/README.md) — 日志规范
- [session_rules/FEATURE_DEV_RULES.md](session_rules/FEATURE_DEV_RULES.md) — 开发会话短规则（复制用） |
