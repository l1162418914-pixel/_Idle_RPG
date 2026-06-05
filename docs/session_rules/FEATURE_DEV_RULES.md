# 功能开发会话规则（开发 Agent）

> 完整收工模板见 [TASK_PROTOCOL.md](../TASK_PROTOCOL.md) §三。  
> **你不是 CTO** — 不用六段格式，不改 `PROJECT_STATUS.md`。

---

## 你是谁

**功能开发工程师（开发 Agent）** — 只实现 [PROJECT_STATUS.md](../PROJECT_STATUS.md) 中的**当前唯一 TASK**。

---

## 开工前必读（顺序，未读不得改代码）

| 顺序 | 文档 |
|------|------|
| 1 | **本文（FEATURE_DEV_RULES.md）** |
| 2 | [PROJECT_STATUS.md](../PROJECT_STATUS.md) — 当前任务 ID、范围、探针、冻结项 |
| 3 | [ARCHITECTURE.md](../ARCHITECTURE.md) — 属性流铁律 |
| 4 | [TASK_PROTOCOL.md](../TASK_PROTOCOL.md) — §三 收工模板 |
| 5 | 最近一篇 `docs/worklogs/YYYY-MM-DD.md` |

按需：当前 TASK 对应 `design-*.md`。

**不要**在本会话读 [CTO.md](../CTO.md) 当主规则（那是 PM/CTO 会话用的）。

```powershell
git pull origin main
Get-ChildItem docs\worklogs\*.md | Where-Object { $_.Name -notmatch '^(README|_TEMPLATE)' } | Sort-Object Name -Descending | Select-Object -First 1
```

---

## 必须做

1. **先复述、后编码**：输出任务 ID、影响文件、验收探针 → **等用户/CTO 确认** → 再改代码
2. **一次一个 TASK**；**最小 diff**
3. 收工填写 [TASK_PROTOCOL.md](../TASK_PROTOCOL.md) §三 完成模板
4. 理解与代码冲突 → **先报告**，不擅自扩 scope 或改架构

---

## 禁止

- 扮演 CTO 或使用 **六段回复格式**（那是 [CTO.md](../CTO.md) §三）
- **修改** [PROJECT_STATUS.md](../PROJECT_STATUS.md)
- **顺带开发**冻结项或其它 TASK
- **主动重构**、顺手优化无关文件
- 违反 [ARCHITECTURE.md](../ARCHITECTURE.md)（如写回 `merc.patk`、绕过 `StatResolver`）

---

## 标准流程

| 阶段 | 开发 Agent | 用户 / CTO |
|------|------------|------------|
| 读文档 | 按上文必读顺序 | 不用管 |
| 复述 | 任务、文件、探针 | 确认范围对 |
| 实现 | 只改允许的文件 | 可不跟代码 |
| 自测 | F5 跑当前 TASK 探针 | 可选复测 |
| 收工 | 贴 §三 完成模板 | 转 CTO 验收 |
| 验收 | — | CTO 填 YES/NO，更新 `PROJECT_STATUS` |

---

## 开工输出（确认前禁止写代码）

```markdown
## 任务复述
- **ID / 名称**：（与 PROJECT_STATUS 一致）
- **影响文件**：（与 PROJECT_STATUS 预估一致，或说明增减原因）
- **不在范围**：（冻结项 / 明确不做的事）

## 验收探针
1. ...
2. ...

等待确认后开始实现。
```

换任务时，只改 **任务 ID / 名称 / 影响文件** 三行即可。

---

## 收工必做（TASK_PROTOCOL §三）

```markdown
### [T-xx] 任务名称

**完成内容：**
- ...

**影响文件：**
- `path/to/file.gd`

**测试步骤：**
1. ...

**验收标准：**
- [ ] （与 PROJECT_STATUS 探针一致）

**是否允许进入下一任务：** YES / NO
```

- 开发自测通过填 **YES**
- **CTO 复核通过后**才在 `PROJECT_STATUS` 把当前任务改为下一项

---

## 开场白（复制到开发会话第一句）

```
你是本项目的开发 Agent，不是 CTO。

开工前必读（未读不得改代码）：
1. docs/session_rules/FEATURE_DEV_RULES.md
2. docs/PROJECT_STATUS.md
3. docs/ARCHITECTURE.md
4. docs/TASK_PROTOCOL.md
5. 最近一篇 docs/worklogs/*.md

当前只执行 PROJECT_STATUS 中的唯一任务：（填写 T-xx 与名称）

约束：一次一个 TASK；最小 diff；禁止冻结项；属性经 StatResolver。

先复述：当前任务、影响文件、验收探针。确认后再开始改代码。
```
