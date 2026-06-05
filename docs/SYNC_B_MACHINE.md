# B 机为主开发（双机说明）

今后两个月在 **B 机** 上完成开发与验收；A 机可能长期不可用。以 **GitHub `main`** 为唯一真相源。

## 环境

| 项 | 建议 |
|----|------|
| Godot | 4.6.x（与 B 已装 4.6.3 一致即可） |
| Git | 2.x |
| 项目路径 | 任意，clone 后即用 |

```powershell
git clone https://github.com/l1162418914-pixel/_Idle_RPG.git
cd _Idle_RPG
git checkout main
git pull origin main
```

用 Godot 打开项目根目录；若脚本报错，执行 **项目 → 重新导入** 或 **重新加载当前项目**。

## 日常流程（B 机）

1. 开始工作前：`git pull origin main`
2. 改代码 → 编辑器 F5 或相关场景验证
3. 改过 `scripts/**/*.gd` 后：
   ```powershell
   powershell -NoProfile -File tools\check_gdscript_format.ps1
   ```
4. 提交并推送（B 机也要 push，否则换机丢失）：
   ```powershell
   git add -A
   git status
   git commit -m "说明本次改动目的"
   git push origin main
   ```

## 易错语法

见 `docs/GDSCRIPT_SYNTAX.md`（多行字符串与 `%`、全局类 `class_name` 自引用用 `preload` + `_SCRIPT.new()` 等）。

## 玩法验收

见 `docs/TEST_SCENARIOS.md`（测试图在大营「测试 / 演练地图」分区，①→⑦）。

## 注意

- **headless** 只能粗查解析，**F5 / 编辑器** 才是最终依据。
- 大改前确认 `git status` 干净或已 commit，避免丢改动。
- 若与旧文档写「仅 A push」：以本文为准，**B 机负责 push**。
