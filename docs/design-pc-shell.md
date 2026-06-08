# PC 主壳 UI 设计（THB 2.0）

> **状态：T-11a/b、T-05 已验收** — 大营细化见 [design-base-ui.md](design-base-ui.md)（**T-UI-B1** 进行中）。见 `PROJECT_STATUS.md`。  
> **平台：PC 窗口**（最小 1280×720）。不做手游 Tab 大营。  
> **玩法不变**：`GameManager` 四态 `BASE → PREPARE → RUNNING → RESULT → BASE`；`ARCHITECTURE.md` 状态机与奖励边界不动。

---

## 一、设计来源（壳子五源 v2 · [GAME_BIBLE.md](GAME_BIBLE.md) §五）

| 来源 | 负责什么 | 不借什么 |
|------|----------|----------|
| **THB 原版** | 上三窗 + Dock + 底栏分区 + 右窗网格 | 2-7 关卡、9 合 1 合成 |
| **Kingdom: Two Crowns** | **跑图大地图**、里程/领地推进（改进） | 国王走格、金币主资源 |
| **克鲁赛德战记 CQ** | **接战条** + **大营营地舞台**（横排队伍、建筑图标、营火氛围） | 消块、**全屏街景横滑** |
| **提灯与地下城** | **压力机制**、撤离风险语气 | 重度丢光、房间探索 |
| **塔科夫 / 三角洲行动** | **安全箱 vs 外露**、带货撤 | FPS、硬核操作 |
| **现版 TBH 自研** | 双半组、双池盾、Boss 追击、测试图 | `BaseUI` 单页长滚动 |

主线：**C 远征 + D 撤离**。底栏 = **KTC 大地图层** + **CQ 接战层** 叠放；右窗 = **塔科夫向** 箱/外露。

---

## 二、总布局（单窗 + WORLD-REEL · 2026-06-09 CTO 优先）

> **现行定案**：[design-world-reel-CTO.md](design-world-reel-CTO.md) — 单窗 1280×720；`StageBand` 贴底全宽 **WorldReelPlane**（Camp+Map 分块）；`HudDock` 右下。  
> **废止主方案**：`T-UI-CQ-SHELL-3` 60/40 分栏；`T-UI-TWIN` 双 OS 窗仅过渡。  
> 下文双窗图为历史参考。

### 窗口 A · PlanningWindow（1280×460，min 高 360）

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 顶栏 ~40px：金币 | 团队稳定 | 养伤锁 | 当前地图名                          │
├────────────────────────────── UpperArea ────────────────────────────────┤
│  左窗 ~32%          │  中窗 ~36%          │  右窗 ~32%（可折叠）          │
│  地图/出征          │  编组/备战          │  名册/背包/装备               │
├─────────────────────────────────────────────────────────────────────────┤
│ Dock ~48px：[出征][编组][背包][地图][后勤]  提示区  [设置]                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 窗口 B · StageWindow（1280×260，贴主窗底）

```
┌─────────────────────────────────────────────────────────────────────────┐
│ StageBar（≥220px）：BottomStage（大营）/ RunMarchLane + CombatView（出征）│
└─────────────────────────────────────────────────────────────────────────┘
```

**合计可视高度** ≈ 720px（460+260），与旧单窗相当；**逻辑上彻底分离**计划与表演。

### 持久规则

1. **RUNNING 时 CombatView 仅在 StageWindow**；PlanningWindow 保持三窗可操（双窗版「上管下打」）。
2. 四态 **同一壳**，只切换槽位内容与底栏模式，不整场景切换。
3. **后勤**（建筑/医疗/阵亡）用 **浮动窗/模态**，不常开第四主窗。
4. 窗口宽 &lt; 1280：提示放大窗口（可选实现）。

### 底栏 Run 条语义

| 元素 | 内容 |
|------|------|
| 场景 | 横版；去程向右，返程向左；左=营/安全，右=深处 |
| 顶左 | `128m / 600m` 或 `返程 45m→0` |
| 顶右 | 推进中 / 返程中 / 接战中 |
| 中央 | 现有 `CombatView` 缩放嵌入 |
| 底一行 | 稳定度条；携带价值（有则显示）；追击压力（有则显示） |

**BASE 待机**：无战斗，**底栏 CQ 动画舞台**（营火 + 队伍 idle，T-UI-STAGE-2）— **禁止**仅一行 `StandbyLabel` 占位。

---

## 三、四态 × 三窗内容

| 状态 | 左窗 | 中窗 | 右窗 | 底栏 | Dock 高亮 |
|------|------|------|------|------|-----------|
| **BASE** | 地图列表（正式/测试分区） | 双半组编队 | 大营背包（网格占位可后补） | 待机 | 地图 |
| **PREPARE** | 地图详情 + 测试 Banner + 出征钮 | 本趟名单 + 半组状态 | 安全箱/外露格预览 | 预览路线 | 出征 |
| **RUNNING** | Run 提示 log（可收成窄条） | 本趟成员 HP（只读） | **出征网格**（T-05 前可占位） | **实况战斗** | 出征 |
| **RESULT** | 结算摘要（撤离类型） | 升级/经验 | 掉落→背包预览 | 定格最后一帧 | 背包 |

### 左窗要点

- 地图行：名、危险、解锁、**一行主目标**（带货撤/冲 Boss/测稳定…）。
- 养伤锁：灰正式图；测试图可点（现 `TestScenarioService` + `start_prepare` 规则）。
- RUNNING：斩仓返程（确认框）；log 接 `RunUI` / `run_event` 提示。

### 中窗要点

- 迁入现有 `FormationUI`（A/B 各 4+2），**固定槽位**，不再 `insert` 进 `BaseUI` Scroll。
- **T-UI-CAMP（2026-06-07）**：中窗上层为 **CQ 营地舞台**——暖色背景 + A/B 两队 **横排立绘/剪影**；编组逻辑仍走 `FormationUI` / `SquadFormationService`，不新写编制规则。
- 主角 **留营一行**，不占 A/B 槽（对齐 T-02c 方向）。
- RESULT：再战可用性 / 养伤锁原因。

### 右窗要点

- RUNNING：出征网格 + `携带价值 x/threshold` + 满格预警。
- T-11b 可用列表占位；**T-05** 做完整网格交互。

---

## 四、Dock 与快捷键（PC）

| 按钮 | 快捷键 | 行为 |
|------|--------|------|
| 出征 | F1 | `start_prepare` / 已选图则进 PREPARE 或 `start_run`（与现逻辑一致） |
| 编组 | F2 | 聚焦中窗 |
| 背包 | F3 | 聚焦右窗；RESULT 强调领取 |
| 地图 | F4 | 聚焦左窗 |
| 后勤 | F5 | 打开浮动窗：建筑、医疗、阵亡名册 |
| 再战 | — | `redeploy_same_map`（BASE/RESULT） |
| 设置 | — | 战斗速度、自动出征等 |

---

## 五、与现网组件迁移表

| 现组件 | 迁入位置 | 备注 |
|--------|----------|------|
| `BaseUI` 长滚动 | **拆没** → 左地图 + 中编组 + Dock | T-11b |
| `FormationUI` 动态插入 | **固定中窗** | T-11b |
| `SquadUI` 全屏 PREPARE | 左+中+右预览，**不独占屏** | T-11b |
| `RunUI` | 底栏状态条 + 左窗 log | T-11b |
| `CombatView` | **仅底栏 Run 条** | T-11a |
| `ResultUI` | 左结算 + 右掉落 | T-11b |
| `EquipmentUI` | 中窗选中佣兵后 **浮动抽屉** | 后期 |

**不改**：`GameManager` 出征/奖励/养伤锁/测试编队注入；`main.gd` 的 `WorldRun.tick` / `CombatController.tick` 驱动逻辑。

---

## 六、开发任务工单（复制给 Agent）

### 开工话术（用户粘贴）

```text
你是开发 Agent，不是 CTO。只做一个 TASK。
先读：FEATURE_DEV_RULES、PROJECT_STATUS、ARCHITECTURE、TASK_PROTOCOL、docs/design-pc-shell.md。
任务见本文 §七，先复述任务 ID、影响文件、验收探针，等我确认后再改代码。
```

---

## 七、T-11a：PC 主壳 + 底栏 Run 条（第一期）

### 目标

1. 新增 `MainShell`（或重构 `scenes/main.tscn`）：顶栏 + 上三窗占位 + HSplitter + 底栏 + Dock。
2. 底栏嵌入现有 `CombatView`；`RUNNING` 不全屏遮上区。
3. 四态仅改壳内 `visible`/挂载，不增 `GameState`。
4. 旧 UI 可暂保留逻辑，先能跑通 F5 全流程。

### 不在范围

- 出征网格完整 UI（T-05）
- 合成、新美术
- `WorldRun` / `CombatController` 战斗逻辑
- T-02a / T-02c / T-02e 规则改动
- 修改 `PROJECT_STATUS.md`

### 建议影响文件

- `scenes/main.tscn`
- `scripts/main.gd`（布局/可见性 only）
- `scripts/ui/main_shell.gd`（新建）
- `scripts/ui/base_ui.gd`（最小嵌入改动，若需要）

### 验收探针（F5）

- [ ] 1280×720：顶栏 + 三窗 + 底栏 + Dock 同屏
- [ ] BASE：底栏待机，上区可见
- [ ] 选测试图 → PREPARE：壳不变，底栏仍可见
- [ ] RUNNING：底栏战斗，**上区仍可见**
- [ ] RESULT → 回大营 → BASE
- [ ] `game_manager` 无出征/奖励/测试编队核心逻辑改动

### 收工

`TASK_PROTOCOL.md` §三 完成模板。

---

## 八、T-11b：三窗内容迁移（第二期，依赖 T-11a）

### 目标

1. 左窗：地图列表 + PREPARE 详情 + RUNNING log。
2. 中窗：固定 `FormationUI`。
3. 右窗：背包/网格占位 + RESULT 掉落。
4. Dock 绑定聚焦与后勤浮动窗。
5. 废弃 `BaseUI` 主 Scroll 路径。

### 不在范围

- T-05 网格拖拽完整交互
- 装备 UI 大改

### 验收探针

- [ ] 大营无需纵向滚完编队+地图+名册
- [ ] Dock 可达编组/地图/后勤
- [ ] `test_01` 选图→出征→回营全流程 UI 可用
- [ ] 养伤锁、测试图重注入提示可见

---

## 九、后续：T-05 与右窗

右窗出征网格见 `design-retreat.md`、`PROJECT_STATUS` T-05。在 T-11b 槽位就绪后实现。

---

## 九·二、CQ 营地舞台 + THB 交互（T-UI-CAMP · 2026-06-07 定案）

> 任务板：[PROJECT_STATUS.md](PROJECT_STATUS.md) §T-UI-CAMP · 细则：[design-base-ui.md](design-base-ui.md) §T-UI-CAMP

### 合体原则

| 层 | 借什么 | 铁律 |
|----|--------|------|
| **CQ 观感** | 营地背景、A/B 横排队伍、建筑图标条、BASE 底栏营火剪影 | **非**全屏街景 `ScrollContainer` |
| **THB 交互** | 1280 三窗 + Dock + 顶栏；鼠标优先；选图≠出征；右窗网格；后勤浮动窗 | 不删 Dock、不恢复 `BaseUI` 长滚 |

### 中窗（CAMP-1）

- 容器：`CampStage`（或等效）叠在 `FormationUI` 之上/外包一层。
- 视觉：暖色营地占位 + 两队横排（`party/silhouette_*` 或职业色条卡）。
- 交互：点横排成员 → 现有选中/编入/装备抽屉；Dock「编组」仍滚中窗 + 描边（B1.5 不回归）。

### 建筑图标（CAMP-2）

- 中窗或中窗顶沿：**招募 / 医疗 / 仓库** 等图标按钮。
- 点击 → 打开 TBH **后勤浮动窗** 对应 Tab（不新开第四主窗）。

### 底栏 CQ 动画舞台（T-UI-STAGE · 2026-06-08 修订）

- **挂机铁律**：底栏始终有 **动画**（大营休息 / 养伤休整 / 行军 / 接战 / 结算），对齐 CQ「画面在屏幕下方」。
- BASE/PREPARE/RESULT：`BottomStage` 替换纯文字待机；RUNNING：沿用 `RunMarchLane` + `CombatView`。
- 营火 + 队伍 idle 与 RUNNING 剪影共用 `party/silhouette_*` manifest。

### 冻结

- `GameManager` 四态、`squad_formation` 存档结构、双半组/备战席语义（FORM 线）。
- RUNNING 底栏战斗逻辑、CombatController 数值。

---

## 十、参考截图（项目内）

- THB 原版多窗：`assets/` 下用户提供的 THB 截图（三窗 + 底栏 2-7）
- CQ 横版大营/跑图：同目录克鲁赛德战记截图

---

## 相关文档

- [UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md)
- [design-expedition-meta.md](design-expedition-meta.md)
- [design-retreat.md](design-retreat.md)
- [ARCHITECTURE.md](ARCHITECTURE.md) §二 状态机、§三 出征分层
