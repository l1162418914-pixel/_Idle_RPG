# 双机同步说明

**GitHub `main`** 为唯一真相源。

## 当前策略（以你最新决定为准）

| 阶段 | 主开发机 | 说明 |
|------|----------|------|
| **现在** | **A 机** | 写代码、测玩法、push 均在 A |
| 暂不用 | B 机 | 已对齐、F5 通过；接手前 `git pull` 即可 |
| 曾计划 | B 两个月 | 若以后再切 B，见下文「B 机收工」与 `docs/worklogs/` |

**A 机路径（本机）**：`C:\Users\19173\Desktop\TBH_Idle_RPG`  
**B 机路径（备用）**：`C:\Users\l1162\Desktop\TBH_Idle_RPG`

### A 机日常（当前）

```powershell
cd C:\Users\19173\Desktop\TBH_Idle_RPG
git pull origin main
# 改代码 → Godot F5
.\tools\check_gdscript_format.ps1
git add -A
git commit -m "说明"
git push origin main
```

玩法验收：`docs/TEST_SCENARIOS.md`，进度勾选 `docs/ACCEPTANCE_PROGRESS.md`。  
收工可选：`docs/worklogs/YYYY-MM-DD.md`。

---

## B 机备用（暂不开工时跳过）

以下为 B 机就绪时的流程；**A 为主时不必每天 pull B**。

---

## 环境（已就绪）

| 项 | 状态 |
|----|------|
| Godot | 4.6.3.stable |
| Git | 2.x |
| 对齐 commit | `14b720d` 起 |
| 远程 | `https://github.com/l1162418914-pixel/_Idle_RPG.git` |
| 远程桌面 | Chrome RD（可选） |

---

## 每次开工（约 1 分钟）

```powershell
cd C:\Users\l1162\Desktop\TBH_Idle_RPG
git pull origin main
git log -1 --oneline
```

打开 **最近一篇** worklog：`docs/worklogs/` 下日期最大的 `.md`（见该目录 `README.md`）。

Godot 打开项目根目录；有脚本报错 → **项目 → 重新加载** 或 **重新导入**。

---

## 每次收工（必做，约 5 分钟）

### 1. 自检

   ```powershell
   cd C:\Users\l1162\Desktop\TBH_Idle_RPG
   .\tools\check_gdscript_format.ps1
   ```

改过玩法则在编辑器 **F5** 确认相关流程。

### 2. 写工作日志（防忘记）

1. 复制 `docs/worklogs/_TEMPLATE.md` → `docs/worklogs/YYYY-MM-DD.md`
2. 填写：今日改动、测了什么、未决、**下次第一步**
3. 可选：粘贴当天 Cursor **对话摘要**到「对话要点」

### 3. 提交并推送

```powershell
git add -A
git status
git commit -m "feat|fix|docs: 简短说明（可带日期）"
git push origin main
```

**代码与 worklog 同一 push**，换机或两个月后只看 Git 即可接上。

---

## 玩法验收

`docs/TEST_SCENARIOS.md` — 大营 **「测试 / 演练地图」**，建议顺序：编队 UI → ① → ② → ③ → ④ …

---

## 易错语法

`docs/GDSCRIPT_SYNTAX.md` — 多行字符串与 `%`、勿 `ClassName.new()` 在同类注册期自引用（用 `preload` + `_SCRIPT.new()`）。

---

## 若中途用别的电脑

任何机器都是：`clone` / `pull` → 改 → worklog → `push`。  
**不要**在多台机器各改各的不 push。

---

## 接手 / 久别后 checklist

```powershell
cd C:\Users\l1162\Desktop\TBH_Idle_RPG
git pull origin main
git log -3 --oneline
Get-ChildItem docs\worklogs\*.md | Where-Object { $_.Name -notmatch '^_' } | Sort-Object Name -Descending | Select-Object -First 1
powershell -NoProfile -File tools\check_gdscript_format.ps1
```

Godot 4.6.3 → 打开项目 → **F5** → 按 worklog「下次第一步」继续。

---

## headless 说明

`godot --headless --quit-after` 仅粗查解析；**最终以编辑器 F5 为准**。
