# v2 双远程仓迁移手册

> **策略**：旧实现归档为 **TBH-Idle-RPG-legacy**；新工程 **TBH-Idle-RPG** 从壳子重写，域逻辑从 legacy 取经。  
> **产品定案**：新壳按 [design-world-reel-CTO.md](design-world-reel-CTO.md) 起步。

---

## 一、远程仓命名

| 仓库 | 用途 | 本地文件夹建议 |
|------|------|----------------|
| **TBH-Idle-RPG-legacy** | 冻结参考；只修致命 bug，不排新功能/新壳 | `TBH_Idle_RPG_legacy` 或保留现 `TBH_Idle_RPG` |
| **TBH-Idle-RPG** | v2 主开发 | `TBH_Idle_RPG` 或 `TBH_Idle_RPG_v2` |

现网远程（迁移前）：`https://github.com/l1162418914-pixel/_Idle_RPG.git`

---

## 二、GitHub 操作（推荐顺序）

### 步骤 1 · 固化 legacy

1. 在 GitHub 新建空仓 **`TBH-Idle-RPG-legacy`**（或把现有 `_Idle_RPG` **Rename** 为 `TBH-Idle-RPG-legacy`）。
2. 本地旧工程确保 `main` 已推送最新（含 `design-world-reel-CTO.md` 等定案文档）。
3. 打标签归档：

```bash
git tag -a archive/pre-world-reel -m "Archive before WORLD-REEL v2 shell rewrite"
git push origin main
git push origin archive/pre-world-reel
```

4. 若用**新仓**而非 rename：改 remote 后推送全历史：

```bash
git remote rename origin legacy
git remote add origin https://github.com/<you>/TBH-Idle-RPG-legacy.git
git push -u origin main --tags
```

5. legacy 仓 README 顶部加 **ARCHIVED**（见本文 §五）。

### 步骤 2 · 创建 v2 空仓

1. GitHub 新建 **`TBH-Idle-RPG`**（空仓，无 README 或仅 LICENSE）。
2. 本地**新文件夹**初始化（不要复制 `.godot/`）：

```powershell
mkdir C:\Users\19173\Desktop\TBH_Idle_RPG_v2
cd C:\Users\19173\Desktop\TBH_Idle_RPG_v2
git init
git remote add origin https://github.com/<you>/TBH-Idle-RPG.git
```

3. Godot 4.2 **新建项目** 指向该目录 → 生成 `project.godot`。
4. 按 §三 复制白名单后首次提交推送。

---

## 三、v2 复制白名单

### 必搬（域 + 数据 + 探针核心）

```
data/                    # 全目录（json 表）
docs/
  GAME_BIBLE.md
  ARCHITECTURE.md
  design-world-reel-CTO.md
  design-combat-stack.md
  design-march-visual.md
  design-expedition-meta.md
  design-art-checklist.md
  SAVE_FORMAT.md
  TASK_PROTOCOL.md
  CTO.md
  session_rules/
scripts/
  core/                  # GameManager, data_loader, StatResolver 等
  combat/                # 全目录（Controller/Session/Policy）
  run/                   # WorldRun, march_event, run_driver 等
  domain/                # 若有
  mercenary/             # 实体相关
  save/
  debug/run_probe_log.gd # 可选
tools/
  mia_phase1_probe.gd    # 先搬，再删壳子相关探针
  MiaPhase1Probe.tscn
```

### 勿搬（壳子债 · v2 重写）

```
scripts/main.gd
scripts/ui/main_shell.gd
scripts/ui/stage_shell.gd
scripts/ui/bottom_stage.gd   # 逻辑参考可留 legacy；v2 新写 CampSegment
scripts/ui/hud_dock.gd       # 可参考重写
scenes/main.tscn             # 全新入口
scenes/stage_window.tscn
docs/PROJECT_STATUS.md       # v2 写新板，勿整文件复制
```

### 选择性搬（表现层）

```
scripts/ui/visual_slot.gd
scripts/ui/visual_constants.gd
scripts/ui/art_manifest.gd
scripts/ui/combat_view.gd    # 后迁；父节点改为 CombatSliceHost
scripts/ui/run_march_lane.gd # 逻辑接口参考；表现迁 WorldReel
data/art_manifest.json
```

复制方式：从 legacy 路径 **逐文件** copy，不要整仓 `cp -r`（避免带入 `.godot`、壳场景）。

---

## 四、v2 第一周里程碑

| 天 | 目标 |
|----|------|
| D1 | 空壳：`WorldReelPlane` + `CampSegment` 色块 + 单窗 720p |
| D2 | `ChunkHost` far/near 占位 + 选图换 chunk 集 |
| D3 | 接 `WorldRun`：`chunk_index` / `local_m` |
| D4 | 搬 `CombatController` + 最小 `CombatSliceHost` |
| D5 | 探针子集 20 条 PASS；`test_01` 冒烟 |

`PROJECT_STATUS` v2 唯一指针：**T-UI-REEL-1**。

---

## 五、legacy README 顶部模板

```markdown
> **ARCHIVED** — 本仓库为 WORLD-REEL v2 之前的实现，仅供参考与抄域逻辑。  
> **主开发**：[TBH-Idle-RPG](https://github.com/<you>/TBH-Idle-RPG)  
> **归档标签**：`archive/pre-world-reel`
```

---

## 六、协作约定

1. **Issue / PR** 只开在 v2 仓；legacy 仅 security/存档致命修复。  
2. **Cursor 工作区** 默认打开 v2 文件夹。  
3. 从 legacy **抄代码** 须在 PR 注明源文件路径；禁止把 `main_shell` 整文件带回。  
4. 定案文档以 v2 `docs/` 为准；legacy 文档只读不改（除 ARCHIVED 说明）。

---

## 七、本地双仓目录示例

```
Desktop/
  TBH_Idle_RPG/              → remote: TBH-Idle-RPG-legacy (ARCHIVED)
  TBH_Idle_RPG_v2/           → remote: TBH-Idle-RPG (active) · 已脚手架 2026-06-09
```

旧文件夹可改名为 `TBH_Idle_RPG_legacy` 以免 Godot 开错工程。

### 本地已执行（2026-06-09）

| 步骤 | legacy `TBH_Idle_RPG` | v2 `TBH_Idle_RPG_v2` |
|------|----------------------|----------------------|
| 归档 commit | `8708998` + tag `archive/pre-world-reel` | — |
| push legacy | ✅ `TBH-Idle-RPG-legacy` main + tag | — |
| 白名单复制 | — | ✅ ~200 文件 |
| git init + 首 commit | — | ✅ `main` 本地（待 push v2） |

**legacy 远程**：`https://github.com/l1162418914-pixel/TBH-Idle-RPG-legacy`

**v2 推送（GitHub 建仓 `TBH-Idle-RPG` 后）：**

```powershell
cd C:\Users\19173\Desktop\TBH_Idle_RPG_v2
git remote add origin https://github.com/l1162418914-pixel/TBH-Idle-RPG.git
git push -u origin main
```
