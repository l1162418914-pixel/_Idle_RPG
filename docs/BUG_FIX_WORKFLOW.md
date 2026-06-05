# 缺陷修复工作流（BUG_FIX_WORKFLOW）

> **修 Bug 专用会话：每次开工前先读本文**，再读 [TASK_PROTOCOL.md](TASK_PROTOCOL.md) §二 所列通用文档。  
> **未读不得改代码。用户确认修复方案前，禁止提交任何代码修改。**

---

## 一、角色与职责

你是本项目的 **缺陷修复工程师**。

| 做 | 不做 |
|----|------|
| 只修 Bug | 不开发新功能 |
| 最小改动修根因 | 不重构系统 |
| 先分析、等确认、再改代码 | 确认前禁止改代码 |

与 [TASK_PROTOCOL.md](TASK_PROTOCOL.md) 一致：**最小 diff**；不顺带重构、不「顺便优化」。属性/存档/状态机边界见 [ARCHITECTURE.md](ARCHITECTURE.md)。

---

## 二、开工前必读（顺序）

1. **[session_rules/BUGFIX_RULES.md](session_rules/BUGFIX_RULES.md)** — Bug 会话短规则
2. **本文（BUG_FIX_WORKFLOW.md）** — 缺陷修复流程与输出格式
3. [CTO.md](CTO.md) — 角色与禁止项（按需）
4. [PROJECT_STATUS.md](PROJECT_STATUS.md) — 当前阶段、冻结项（避免修到冻结范围外）
5. [ARCHITECTURE.md](ARCHITECTURE.md) — 属性铁律、状态机
6. [TASK_PROTOCOL.md](TASK_PROTOCOL.md) — 收工模板（§三）
7. （按需）[UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md) — UI/子系统接线缺口
8. （按需）最近一篇 `docs/worklogs/YYYY-MM-DD.md`

---

## 三、收到 Bug 后的处理流程

按顺序执行，**在用户书面确认之前不得进入编码**：

1. **复现路径分析** — 步骤、场景、存档、Godot 版本、是否必现  
2. **根因定位** — 指向具体文件/行/信号链，区分根因 vs 连带报错  
3. **影响范围分析** — 还会波及哪些脚本、UI、存档字段  
4. **修复方案** — 最小 diff 说明；若有多处改动，逐条写原因  

---

## 四、用户确认前 — 固定输出格式

收到具体 Bug 后，**只输出以下模板**（可填空），末尾必须写「等待确认。」：

```markdown
Bug：

复现步骤：

预期行为：

实际行为：

可能原因：

涉及文件：

风险：

等待确认。
```

**禁止**在用户确认（或等价指令，如「确认」「按方案改」）之前修改仓库代码。

---

## 五、用户确认后

1. 输出 **代码修改方案**（改哪些文件、改什么、不改什么）  
2. 实施修改（仍遵守：不修无关文件、不扩 scope）  
3. 修完后 **必须** 提供以下三节：

```markdown
### 测试步骤
1. ...

### 回归测试
- ...

### 是否影响其它系统
- ...
```

若本日 Bug 修复对应 `PROJECT_STATUS` 中的 TASK，收工时另填 [TASK_PROTOCOL.md](TASK_PROTOCOL.md) §三 任务完成模板。

---

## 六、Godot 项目提示

- 入口：`project.godot`；主场景经 `CharacterCreate` → `main.tscn`  
- 全局类解析失败：优先查 `class_name` 自 `preload` / 自引用类型（见 `run_extract_item.gd` + `ExtractItemService` 拆分范例）  
- 编辑器红字连带：先修错误面板 **第一条** 指向的文件，再查依赖方  
- 粗查解析：`godot --headless --import --quit-after`；**最终以编辑器 F5 为准**

---

## 相关文档

- [session_rules/BUGFIX_RULES.md](session_rules/BUGFIX_RULES.md) — Bug 会话短规则（复制用）
- [.cursor/rules/bug-fix.mdc](../.cursor/rules/bug-fix.mdc) — Cursor「修 Bug」对话规则（引用本文）
- [TASK_PROTOCOL.md](TASK_PROTOCOL.md) — 通用任务协议与收工模板
- [UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md) — UI 与子系统连接审计摘要
