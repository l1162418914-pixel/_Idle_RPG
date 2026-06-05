# 任务协议（TASK_PROTOCOL）

> **每次开工前先读** [CTO.md](CTO.md) → [PROJECT_STATUS.md](PROJECT_STATUS.md) → [ARCHITECTURE.md](ARCHITECTURE.md) → **本文**。  
> 未读不得改代码。收工时必须按 §三 模板回报。

---

## 一、角色与约束

| 角色 | 职责 | 禁止 |
|------|------|------|
| **CTO** | 维护任务板、审计架构、拆解任务、排优先级、验收代码 | 直接写代码；一次开发多个系统；擅自重构 |
| **开发 Agent** | 执行**当前唯一** `PROJECT_STATUS` 中的 `当前任务` | 超范围改动；顺带开发冻结项；跳过交付模板 |

**铁律**

1. **一次只做一个系统**（或一个 TASK 子项）。
2. **最小 diff**；不顺带重构、不「顺便优化」。
3. 属性/存档/状态机边界见 [ARCHITECTURE.md](ARCHITECTURE.md)；违反则拒收。
4. 任务完成后 **必须** 填写 §三 模板；CTO 填 `是否允许进入下一任务`。

---

## 二、开工前必读（顺序）

与 [CTO.md](CTO.md) §四 一致：

1. **[CTO.md](CTO.md)** — 角色、禁止项、CTO 回复格式
2. **[PROJECT_STATUS.md](PROJECT_STATUS.md)** — 当前阶段、当前任务、冻结项、任务板
3. **[ARCHITECTURE.md](ARCHITECTURE.md)** — 属性铁律、状态机、UI 边界
4. **本文（TASK_PROTOCOL.md)** — 交付格式与门禁
5. **最近一篇** `docs/worklogs/YYYY-MM-DD.md` — 上次做到哪、下次第一步
6. （按需）[UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md) — 接线缺口，非铁律

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

## 四、CTO 状态回复格式（每次对话）

完整说明见 **[CTO.md](CTO.md) §三**。CTO 每条回复须包含：

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
- [UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md) — UI/子系统审计
- [ACCEPTANCE_PROGRESS.md](ACCEPTANCE_PROGRESS.md) — QA 勾选
- [worklogs/README.md](worklogs/README.md) — 日志规范
