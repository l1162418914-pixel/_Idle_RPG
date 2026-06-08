# 大营 UI 重构（Base UI · T-UI-B 线）

> **状态：进行中** — **T-UI-B1** 部分交付；**T-UI-B1.5**（Dock/地图交互）当前任务。壳层见 [design-pc-shell.md](design-pc-shell.md)。  
> **平台：** PC 1280×720 三栏；**交互：鼠标优先**（F 键加速器）；不改 `GameManager` 四态与养伤锁**判定逻辑**。

---

## 背景

T-11b 已将地图/编组/名册拆入三窗，但左窗仍信息过载：地图行样式像调试列表、`StatusLabel` 堆在左窗底部、测试图与正式图混排。用户定案：**先动大营**，从 B1 开工。

---

## 路线图

| ID | 名称 | 状态 |
|----|------|------|
| **T-UI-B1** | 左窗 — 地图卡片 + 测试图折叠 | 🟡 **部分 YES** |
| **T-UI-B1.5** | Dock F2/F4 实功能 + 选中/出征分离 + 后勤瘦身 | 🟡 **当前** |
| T-UI-B2 | 顶栏 — 稳定度进度条 + 养伤锁上移 | 📋 待排 |
| T-UI-B3 | 中窗 — 编组视觉 | 📋 待排 |
| T-UI-B4 | 右窗 — 大营背包网格（与 T-05 出征网格区分） | 📋 待排 |

---

## T-UI-B1：左窗地图卡片

### 目标

1. 正式地图与 QA 测试图分组；测试区 **默认折叠**。
2. 地图行升级为卡片（名称、一行用途、Boss 距离、解锁态、选中高亮）。
3. `status_label` 迁出左窗 → 顶栏 toast 或 Dock `_dock_hint`（3～5 秒）。
4. 养伤锁：正式图灰显 + 锁；测试图规则不变。
5. BASE 选图后顶栏显示「已选：{地图名}」。

### 不在范围

见 `PROJECT_STATUS.md` §T-UI-B1。

### 实现提示

- 可选 `map_card_button.gd` 或 `base_ui` 内纯代码构建。
- 折叠：`CollapsibleSection` 或等效 `Button` + `visible` 容器。
- Toast：`main_shell` 顶栏下沿或 Dock 旁 `Label` + `Timer`；复用现有 `status_label` 文案来源，改 **展示位置** 即可。

---

---

## 零、鼠标优先原则（全 T-UI-B 线）

| 原则 | 说明 |
|------|------|
| **主操作=点击** | 选图、出征、编组、后勤、出发、回营均有 **可见按钮** |
| **F 键=加速** | Dock 可保留 `[F1]` 副文案，但探针不得依赖键盘 |
| **选中≠跳转** | 地图先选中再出征；减少误触进 PREPARE |
| **Dock=导航** | 「地图」「编组」须滚到对应窗区，非闪一下 |
| **点击目标** | 主按钮高度 ≥36px；卡片内「出征」在 **选中态** 出现 |

---

## T-UI-B1.5：Dock 与地图交互（用户反馈）

### 根因

| 现象 | 现网实现 | 用户感知 |
|------|----------|----------|
| F4 地图 / F2 编组 | `_focus_panel` 仅 0.35s 面板 modulate | 快捷键「没用」 |
| 点地图卡片 | 直接 `start_prepare` | 无法在大营「只选图」 |
| F5 后勤 | 单弹层堆建筑+招募+再战+探索 | 按钮墙、与 Dock 重复 |

### 目标

见 `PROJECT_STATUS.md` §T-UI-B1.5 交付 B1.5-1～5。

### 交互定案（CTO · 鼠标优先）

| 步骤 | 鼠标操作 |
|------|----------|
| 选图 | 点地图卡片 → 高亮 + 顶栏「已选」 |
| 出征 | 点卡片「出征」**或** Dock「出征」→ PREPARE |
| 看编组 | Dock「编组」→ 滚到中窗 |
| 看地图 | Dock「地图」→ 滚到左窗 |
| 后勤 | Dock「后勤」→ Tab 弹窗 |
| 出发 | PREPARE 中窗「出发」 |
| 回营 | RESULT「返回基地」 |

F1～F5 与上表 **同逻辑**（可选，非必须）。

---

---

## T-UI-WORLD-REEL（优先 · 2026-06-09 CTO）

> **主排期**：[design-world-reel-CTO.md](design-world-reel-CTO.md) · `PROJECT_STATUS` §T-UI-WORLD-REEL  
> 底栏 = 全宽 `WorldReelPlane`（Camp 固定 + Map 分块）；接战 = **REEL-3 CombatSlice**；**废止 SHELL-3 60/40**。

---

## T-UI-CQ-SHELL · CQ 单屏壳（用户定案 2026-06-09 · v2 · 壳子集）

> **相对 T-UI-TWIN 修订**：不再用「上窗大三窗 + 下 OS 副窗」为主体验；改为 **单窗口 1280×720**，**舞台贴屏幕底**，**CQ 角标 Dock**，**战斗占下窗右侧**。  
> TWIN 双窗降为过渡实现，**T-UI-CQ-SHELL-1** 验收后废止默认双窗启动。

### 目标布局（对照 CQ 截图）

```
┌──────────────────────────────────────────────────────────────┐
│ 上区：天空/留白；点图标才出面板（简表、选图、背包）              │
│                                    [资源紧凑条]               │
│                                    [⚔][👤][🎒][📖][⚙]…     │ ← CQ 式小方钮（**右下**，贴 StageBand 上沿）
├──────────────────────────────────────────────────────────────┤
│ ▼ 下区 StageBand（贴底固定高 ~280–320px，类似 CQ 主舞台）      │
│  ┌─────────────────────────┬──────────────────────────┐  │
│  │ 左：营地/行军/点人        │ 右：接战 CombatView       │  │
│  │ BottomStage / MarchLane  │ + Run 距离/状态条（接战时显）│  │
│  └─────────────────────────┴──────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

| CQ 截图要素 | 你们实现 |
|-------------|----------|
| 横版营地占主视野 | **下区左半** `BottomStage` + 建筑热点 |
| 底右小图标 Dock | **`HudDock` 右下**（`anchor` 右下，贴 `StageBand` 上沿；非整条 Dock 栏） |
| 资源数字 | 角标旁紧凑条（或顶栏一行）；可保留金币/稳定 |
| 点帐篷/人 | **下区左** 点人（FORM-LAYOUT-2）+ 建筑（STAGE-5） |
| 接战 | **下区右** 固定宽接战区（非全宽盖住营地） |
| 横滑整条街景 | ❌ 仍不做 |

### 与已定案关系

| 保留 | 调整 |
|------|------|
| 方案 B 下窗点人 + 上窗简表 | 简表改为 **点 Hud 图标弹出**，非常驻三窗 |
| 选图/策略 | 点地图图标 → 左滑面板 |
| 背包/装备 | 点背包图标 → 右滑/浮层 |
| STAGE-2/3/5 | 都在 **StageBand 左区** |
| CombatView | 迁至 **StageBand 右区**（接战时显示；大营时右区可空或显示路线预览） |

### 任务线

| ID | 内容 | 门禁 |
|----|------|------|
| **T-UI-CQ-SHELL-1** | 单窗 1280×720；`StageBand` 贴底；废止双窗为默认 | — |
| **T-UI-CQ-SHELL-2** | `HudDock` **右下**角标 + 资源条；点开面板 | SHELL-1 |
| **T-UI-CQ-SHELL-3** | `StageBand` 左右分栏：左营地/行军，右 `CombatView` | SHELL-1 |
| T-UI-FORM-LAYOUT-* | 简表/点人 | 接入 SHELL-2/3 左区 |

### 不做

- 默认启动双 OS 窗（TWIN 仅过渡）
- 上区常驻 THB 三窗分栏
- 接战全宽盖住整个下区（战斗必须在 **右侧槽**）

---

## T-UI-LAYOUT · 双窗功能分区（用户定案 2026-06-09 · v1，由 CQ-SHELL v2 取代默认）

> 壳层：**T-UI-TWIN-1**（PlanningWindow + StageWindow）  
> 原则：**上窗 TBH 办事；下窗 CQ 看戏+营地交互**。未列入下表者 **不做**。

### PlanningWindow（上窗 · TBH）

| 功能 | 落点 | 状态 |
|------|------|------|
| 选图、出征策略 | **左窗 + Dock** | ✅ 定案 |
| 背包、穿脱、套装 | **右窗 + 装备浮窗** | ✅ 定案 |
| 结算摘要 | **左窗 + 右窗** | ✅ 定案 |
| 编组、备战席、拖人 | **方案 B：上窗简表**（名单/半组状态/备战席行） | ✅ 定案 → **T-UI-FORM-LAYOUT** |

### StageWindow（下窗 · CQ）

| 功能 | 落点 | 状态 |
|------|------|------|
| 后勤：招募 / 医疗 / 建筑 | **下窗 CQ 建筑可点**（非上窗后勤大弹窗为主入口） | ✅ 定案 → **T-UI-STAGE-5** |
| 大营休息 | 营火 + 队伍 idle；**点选编入** | ✅ 定案 → STAGE-2 + FORM-LAYOUT |
| 养伤休整 | 包扎 / 躺卧动画变体 | ✅ 定案 → STAGE-3 |
| 行军、接战 | 跑图剪影 / 视差 + `CombatView` | ✅ 定案（现网） |
| 结算 | 抵营 / 清点动画 | ✅ 定案 → STAGE-4 |

### 明确不做

- CQ 全屏街景横滑大营  
- 上窗 Dock F5 **大块后勤弹窗**作为后勤主入口（改为下窗建筑；Dock F5 可 **聚焦下窗**）  
- 上窗中窗 **大槽位墙** 作为编组主入口（改为简表；槽位拖放非主路径）  
- 中窗 `CampStage` 替代下窗主舞台  
- 背包网格迁入下窗  
- 单窗 VSplit 回退  

### 开发顺序（布局线）

1. T-UI-TWIN-1 验收  
2. STAGE-2 营火 idle → STAGE-5 下窗后勤建筑 → STAGE-3 养伤变体 → STAGE-4 结算动画  
3. **T-UI-FORM-LAYOUT**（方案 B）— 下窗点人 + 上窗简表（门禁 STAGE-2 占位可点）  

---

## T-UI-FORM-LAYOUT · 编组方案 B（用户定案 2026-06-09）

> **方案 B**：**下窗点人 + 上窗简表**（CQ 选角 + TBH 读表）  
> 机制仍 `SquadFormationService`；**不**改存档结构。

### 分工

| 区域 | 编组 UX |
|------|---------|
| **StageWindow** | 营火场景中 **可点佣兵剪影**；点人 = 选中；点空位/半组区 = 编入目标；拖放可选（FORM-6 语义） |
| **PlanningWindow 中窗** | **简表**：半组 A/B 行列表、备战席行、编组优先/下趟出征文案；**无**大网格槽位墙为主界面 |
| **PlanningWindow 右窗** | 名册详情仍可看属性；与选中联动 |

### 交互定案

1. 下窗点在场佣兵 → 上窗简表高亮对应行；可开装备浮窗（右窗逻辑）。
2. 下窗点「半组 A 空位」或简表行「编入」→ `formation_assign`（走服务层，非 UI 直写）。
3. 备战席成员：简表「未编入」区展示；下窗不显示或显示为营外列表（**仅简表亦可**）。
4. Dock **F2 编组** → 上窗滚到中窗简表 + 下窗 `pulse_stage_focus`。
5. 现 `FormationUI` 槽位墙 **降级/折叠** 为「高级模式」或移除主视图（实现时最小 diff：简表为主，旧槽位 `visible=false` 或收进折叠）。

### 交付拆分

| ID | 内容 | 门禁 |
|----|------|------|
| **T-UI-FORM-LAYOUT-1** | 中窗 `FormationSummaryUI` 简表 + 半组/备战行 | FORM-3R 语义 YES |
| **T-UI-FORM-LAYOUT-2** | `BottomStage` 可点佣兵/槽位热点 → 服务层 assign | STAGE-2 + LAYOUT-1 |
| ~~T-UI-CAMP-1~~ | 中窗 `CampStage` 横排 | ❌ **废止主路径** | → 下窗点人 |

### 不在范围

- 下窗拖放整页编组网格
- 改 `squad_formation` JSON 结构
- 静默 A→B 搬人（仍禁，除用户明确拖/点）

### 验收（F5）

1. 编组主流程 **不用**中窗大槽位墙：下窗点人 + 上窗简表完成「进 A 槽」。
2. 招募进备战席后，简表「未编入」可见；下窗点选可编入。
3. Dock F2、编组优先/下趟文案与 FORM-4 一致。
4. headless **FORM-LAYOUT-1a**（可选）+ 122 PASS。

---

## T-UI-CAMP · CQ 营地舞台 + THB 交互（2026-06-07 定案 · 2026-06-08 修订）

> 壳层：[design-pc-shell.md](design-pc-shell.md) §九·二 · 编组语义：[design-expedition-meta.md](design-expedition-meta.md) · 美术：[design-art-checklist.md](design-art-checklist.md) §P3

### 目标（2026-06-08 用户反馈修订）

挂机游戏的 **主视觉必须在底栏**（CQ 铁律）：玩家始终能在屏幕下方看到 **战斗 / 行军 / 大营休息 / 养伤休整** 之一，且为 **动画舞台**，不是一行字。

| 区域 | 职责 |
|------|------|
| **PlanningWindow** | TBH：选图/策略（左）、背包/装备（右）、结算摘要；**编组 ⏸ 待定** |
| **StageWindow ~260px** | **CQ 动画舞台**（`StageShell` / `BottomStage`）：独立 OS 副窗，见 **T-UI-TWIN-1** |
| **中窗 CampStage** | 编组 **缩略预览**（可选）；**不得**替代底栏动画 |

**现网缺口（2026-06-08）**：`camp_stage.gd` 在中窗有占位色块，但 `MainShell` BASE 底栏仍仅 `StandbyLabel` 文字 → **未达 CQ 挂机观感**。

### 路线图

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-UI-STAGE-1** | **底栏 CQ 动画舞台**（`BottomStage` 状态机） | 📋 **E 线 P0** | T-RUN-V1（已有底栏宿主） |
| **T-UI-STAGE-2** | BASE 大营休息：营火 + 队伍 idle 动画 | 📋 待排 | STAGE-1 |
| **T-UI-STAGE-3** | 养伤/休整子态（半组休息、医疗名册联动） | 📋 待排 | STAGE-2 |
| **T-UI-STAGE-4** | PREPARE/RESULT 底栏预览态 | 📋 待排 | STAGE-1 |
| **T-UI-CAMP-1** | 中窗营地缩略预览（现 `camp_stage.gd` 打磨） | 🟡 部分交付 | 与 STAGE 并行，非主视觉 |
| **T-UI-STAGE-5** | **下窗 CQ 后勤建筑**（招募/医疗/仓库可点） | 📋 待排 | STAGE-2 |
| ~~T-UI-CAMP-2~~ | ~~建筑 → 上窗后勤 Tab~~ | ❌ **废止** | → STAGE-5 |
| **T-UI-CAMP-4** | 美术 manifest（`camp/*` + 底栏 idle 序列） | 📋 可并行 | — |
| ~~T-UI-CAMP-3~~ | ~~BASE 底栏营火~~ | ❌ **并入** | → **T-UI-STAGE-2** |

### CAMP-1 交付要点

- 中窗：`CampStage` 容器 + 暖色背景占位 + A/B 横排（读 `FormationUI` / `SquadFormationService` 快照，**不新写** `formation_assign`）。
- 点击横排成员 → 现有槽位选中 / 装备抽屉链路。
- 备战席、槽位拖拽、补满优先半组：**仍用现 `FormationUI`**，CAMP-1 只包一层视觉。
- Dock F2：滚中窗 + 描边 ≥2s（B1.5 不回归）。

### STAGE-5 交付要点（下窗 CQ 后勤）

- 下窗营地场景内 **建筑热点**（招募/医疗/仓库/兵营等）；点击打开 **轻量面板** 或上窗右窗联动（数据仍 `GameManager`）。
- Dock **F5 后勤** → 聚焦 StageWindow + 高亮建筑（非上窗全屏后勤墙）。
- **影响文件（预估）**：`bottom_stage.gd` 或 `camp_logistics_layer.gd`、`stage_shell.gd`、`main_shell.gd`（Dock 行为）

### STAGE-1 交付要点（底栏动画舞台 · P0）

- 新建 `BottomStage`：挂 `MainShell` `RunBar`，**替换** BASE/PREPARE/RESULT 时仅显示的 `StandbyLabel`。
- 状态机只读 `GameManager.state` + 编队/养伤快照，**不改**战斗数值：

| 底栏模式 | 触发 | 画面 |
|----------|------|------|
| `BASE_REST` | BASE | 营火 + 编组优先半组 idle |
| `BASE_RECOVERY` | BASE + 养伤非空 | 休整/包扎 idle |
| `PREPARE_MUSTER` | PREPARE | 本趟名单列队预览 |
| `RUNNING_MARCH` | RUNNING 未接战 | `RunMarchLane` |
| `RUNNING_COMBAT` | 接战 | `CombatView` |
| `RESULT_RETURN` | RESULT | 抵营/清点剪影 |

- BASE 时 `BottomStage` 占满底栏动画区（≥220px）；RUNNING 沿用现有层。

### STAGE-2 / STAGE-3

- STAGE-2：`camp/bonfire` + `party/silhouette_*` idle（可先 Tween 呼吸，后序列帧）。
- STAGE-3：养伤/半组休整变体；与养伤名册联动（可选）。

### 不在范围

- 全屏 CQ 街景 `ScrollContainer`
- 删除三窗 / Dock / 右窗网格
- 改 `GameManager` 四态、`squad_formation` 存档
- 重写 `BaseUI` 单页长滚

### 验收探针（CAMP-1 · F5 鼠标）

1. BASE：中窗见营地背景占位 + A/B 横排（有编组则显示剪影/色条，空槽可见空位）。
2. 点横排成员 → 对应槽位高亮或装备抽屉打开（与改前行为一致）。
3. Dock「编组」→ 滚中窗 + 描边；选图≠出征不回归。
4. headless：可选 **CAMP-1a**（舞台节点存在 + 横排子节点数 = A/B 出战槽有效人数）；`MiaPhase1Probe` 0 FAIL。

---

*维护：CTO 随 TASK 验收更新本节与 PROJECT_STATUS。*
