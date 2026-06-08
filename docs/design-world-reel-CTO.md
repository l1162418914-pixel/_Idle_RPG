# T-UI-WORLD-REEL · CQ 式世界卷轴定案（CTO 交接稿）

> **用途**：产品负责人与 CTO AI 对齐壳子布局与跑图主视觉；**开发前必读**。  
> **状态**：**产品定案（2026-06-09 讨论收口）** — 待 CTO 写入 `PROJECT_STATUS` 任务板并排期。  
> **取代**：`T-UI-CQ-SHELL-3`「下区左右 60/40 分栏接战」作为主方案；`T-UI-TWIN` 双 OS 窗降为过渡/可选。  
> **关联**：[GAME_BIBLE.md](GAME_BIBLE.md) §五、[design-pc-shell.md](design-pc-shell.md)、[design-base-ui.md](design-base-ui.md)、[design-march-visual.md](design-march-visual.md)、[design-art-checklist.md](design-art-checklist.md)

---

## 〇、给 CTO 的一句话

**底栏主视觉 = 一条横卷平面**：左侧 **固定营地** + 右侧 **随选图变化的出征地图（分块）**；平时看到 **营地 + 地图入口屏**；行军时每 **100m 换一整屏新景**（区块过渡）；过渡用 **并行双卷轴 + 雾带 + 双层视差** 叠加，且 **里程不停 tick**；接战在块内 **动态拼接战斗切片**（**不要** CQ 固定传送门）。

---

## 一、设计来源与边界

### 学什么（CQ）

| 学 | 不学 |
|----|------|
| 横卷主舞台在屏幕下方；滚轮/拖动可浏览营地 | 消块战斗 |
| 一屏一景的「走进世界」感 | 固定传送门进关卡 |
| 右下角 Hud 角标 + 资源条（与 SHELL-2 一致） | 全屏街景无限横滑大地图 |
| 接战在横轴同一世界感内发生 | 为贴图改伤害/里程公式 |

### 学什么（TBH 已定）

| 保留 | 说明 |
|------|------|
| **左营右深** | `distance_traveled` 增加=向右；返程减少=向左 |
| **进军接战停滚** | 见 [design-march-visual.md](design-march-visual.md) |
| **返程接战边撤边打** | 世界 tick 继续 |
| **CombatController 铁律** | View 不算伤害；不加 boss_chase 分支 |
| **里程碑/搜索/采集** | `march_events` 仍按**全局米**配置 |

### 废止/降级（相对旧壳子文档）

| 旧定案 | 新定案 |
|--------|--------|
| CQ-SHELL-3：左 60% 营地 / 右 40% `CombatView` | **全宽卷轴平面 + 块内 CombatSlice** |
| 52px `RunMarchLane` 窄条作主视觉 | 逻辑可保留；**表现迁到 WorldReel** |
| 默认双 OS 窗（TWIN）为主体验 | **单窗 1280×720** + `StageBand` 贴底；TWIN 仅过渡开关 |

---

## 二、空间模型：一平面、两段、分块

### 2.1 逻辑轴（不变）

```
左 ←──────── 大营 / 0m（Camp 右缘锚点）          深处 / max_distance ────────→ 右
```

- **0m** 锚在 **CampSegment 右缘**（营地内部不算出征里程）。
- 出征里程 `0 … max_distance` 映射在 **MapSegment** 上。

### 2.2 视觉平面（一条卷轴）

```
┌────────────────────────────────────────────────────────────────────────────┐
│◄── CampSegment 固定（建筑可点）──►│◄── MapSegment 随 map_template 变化 ──────►│
│ 医疗·营房·营火·仓库              │ 屏0入口 │ 屏1 │ 屏2 │ … │ 屏N-1 深处/Boss │
│                                 │ 里程碑/搜索/采集锚在全局米上              │
└────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 分块（避免单图过长）

| 概念 | 定案 |
|------|------|
| 逻辑总长 | 仍 `max_distance`（例 **600m**） |
| 分块 | **每图可配**；示例 **6 块 × 100m** |
| 块索引 | `chunk_index = floor(distance / chunk_distance_m)` |
| 块内局部 | `local_m = distance % chunk_distance_m` |
| 块视觉宽 | **≈ 1 屏**（`StageBand` 视口宽 `W`）；`pixel_x ≈ (local_m / chunk_distance_m) * W` |

**不是**一张 600m 连续美术；**是** N 张「一屏一景」横条 + 逻辑里程映射。

### 2.4 平时视口（默认镜头）

对准：

```
┌──────────────────┬─────────────────┐
│ Camp 全段可见     │ Map chunk[0]    │
│ 建筑可点          │ 入口前段         │
└──────────────────┴─────────────────┘
```

| 项 | 建议定案（待 CTO 勾选） |
|----|-------------------------|
| Camp 宽度 | **约 1.2 屏**（固定像素，不随地图变） |
| 未选图时右侧 | **雾锁占位条** + 文案「选地图」 |
| PREPARE | **锁在入口屏**，不滑进深处预览 |
| BASE 滚轮 | 可横滑逛营地（延续现 `BottomStage` 拖动/滚轮） |
| RUNNING 滚轮 | **禁用**；自动跟队换屏 |

---

## 三、与 CQ 的核心差异：无固定门，有区块过渡

| | Crusaders Quest | TBH WORLD-REEL |
|---|-----------------|----------------|
| 大营 | 横卷城镇 | **CampSegment** 固定 |
| 进战斗 | **固定传送门** → 独立战斗条 | **无固定门**；`enemy_spawn` 时在块内 **拼 CombatSlice** |
| 地图长度 | 关卡条 | 逻辑长、**视觉分块** |
| 换景 | 进门换关 | **区块过渡（Chunk Transition）** 跨 100m 边界 |

---

## 四、区块过渡（Chunk Transition）— 三手法叠加

**定案：三种一起做**，分工不同：

| 手法 | 层级职责 |
|------|----------|
| **并行卷轴（双 Host）** | 主运动：当前屏左移出画，下一屏从右顶进；`distance` 驱动 `scroll` |
| **雾带擦除** | 遮接缝：块右缘 `seam` 雾/树带，过渡时变浓再揭开 |
| **视差差速（v1：far+near）** | 块内纵深：远景快、近景慢；换块时两层随 Host 同动 |

### 4.1 里程仍 tick（产品硬定）

- 进军、返程、块边界：**均不冻结** `distance_traveled`（与「进军接战停滚」并存：接战时停的是**块内 scroll**，不是改 WorldRun 公式）。
- 返程跨块：下一块从**左侧**顶入，轴仍左营右深。

### 4.2 动态混合带（按速度，非固定 ±2m）

```
speed = advance_speed 或 retreat_speed（m/s）
blend_half_m = clamp(BASE + K * speed, MIN_M, MAX_M)

建议初值：BASE=1.5, K=8, MIN_M=2, MAX_M=12
boundary_m = chunk_index * chunk_distance_m
dist_to_boundary = distance - boundary_m   // 返程用减少方向对称处理
blend = smoothstep(-blend_half_m, +blend_half_m, dist_to_boundary)
```

| `blend` 驱动 | 行为 |
|--------------|------|
| 0 → 1 | `ActiveHost` 左移；`IncomingHost` 从右并入 |
| 雾带 alpha | 中间最浓，如 `sin(blend * PI)` |
| 预载 | 始终最多 **2 个 ChunkHost**（Active + Incoming） |

### 4.3 v1 视差层（先两层）

| 层 | factor 建议 | 资产 key 示例 |
|----|-------------|---------------|
| **far** | 0.15～0.22 | `march_reel/{map}/cN_far` |
| **near** | 0.80～0.95 | `march_reel/{map}/cN_near` |
| ~~mid~~ | v2 | 暂不实现 |

每块另需 **右缘 seam**：`march_reel/{map}/cN_seam`（32～64px 雾/树/暗角）。

### 4.4 节点树（实现参考）

```
WorldReelPlane (StageBand 全宽贴底，高 280–320px)
├─ CampSegment          // 固定；BottomStage 演进
├─ ChunkLayer
│   ├─ ActiveChunkHost
│   │   ├─ FarParallax
│   │   ├─ NearGround
│   │   ├─ FogSeamRight
│   │   └─ Decor/Milestone anchors
│   └─ IncomingChunkHost  // 双缓冲
├─ CombatSliceHost        // 接战时块内拼接
├─ MarchSearchToast / 事件 UI
└─ HudDock（屏幕空间右下，贴 StageBand 上沿）
```

---

## 五、接战与块边界

### 5.1 CombatSlice（图3 类战斗段）

- 宽度约 **480～640px**；脚线对齐现 `BattlefieldSlots` / `UNIT_BASELINE_Y`。
- 遭遇时挂在 **当前 ChunkHost** 上 `party_anchor` 位置；**不是**全宽盖住营地。
- 资产：`combat_slice/{set}/default`；Boss 可 `combat_slice/{set}/boss`。
- 逻辑仍 `EncounterSession` → `CombatController` → `CombatView`；仅 **布局父节点** 变更。

### 5.2 边界与接战优先级（建议定案）

| 场景 | 行为 |
|------|------|
| 遭遇在块中间 | 进军停滚 → 切片接战 → 胜后继续本块 |
| 遭遇在边界附近（如 99m） | **先接战，再换块**（避免人旧屏怪新屏） |
| 返程接战 | 里程减 + 块反向过渡；**背景随 chunk_index 变**，槽位锚队伍 |
| Boss | **末块专用屏** + 可选 **boss 战斗切片** |

### 5.3 与现 march 系统

| 系统 | 映射 |
|------|------|
| `march_events.at_distance` | 全局米 → 算 `chunk_index` + 块内像素 |
| `MarchSearchService` | 不变；飘字叠当前屏 |
| `MarchGatherView` | 块内短停；可复用 near 层道具锚点 |
| `RunMarchLane.scroll_x` | 演进输出 `chunk_index`、`local_m`、块内 scroll |

---

## 六、单窗壳 + Hud（与 SHELL 关系）

| 项 | 定案 |
|----|------|
| 窗口 | **单窗 1280×720**（`T-UI-CQ-SHELL-1` 仍有效：StageBand 贴底） |
| 上区 | 留白/天空；**非常驻** THB 三窗；点 **HudDock** 出地图/简表/背包面板 |
| HudDock | **右下**，贴 `StageBand` 上沿；资源条在角标左侧（SHELL-2） |
| 编组方案 B | 上/弹层 **简表**；**下窗（Camp/块0）点人** → FORM-LAYOUT（门禁 REEL-1） |

---

## 七、四态行为表

| 状态 | WorldReel 表现 |
|------|----------------|
| **BASE** | Camp + chunk[0]（或雾锁）；滚轮可逛营地 |
| **PREPARE** | 同上；高亮入口；不滑深处 |
| **RUNNING** | 离开 Camp；chunk0→…→chunkN；自动换屏；禁手滑 |
| **接战（进军）** | 块内停滚 + CombatSlice |
| **接战（返程）** | 块仍过渡 + 战斗锚队伍 |
| **RESULT** | 滚回默认锚点「Camp+入口」；抵营动画在 Camp 段 |

---

## 八、数据配置（`map_templates` 扩展草案）

```json
{
  "id": "grassland",
  "max_distance": 600,
  "world_reel": {
    "chunk_distance_m": 100,
    "chunks": [
      { "id": "grassland_c0", "label": "入口", "art": { "far": "march_reel/grassland/c0_far", "near": "march_reel/grassland/c0_near", "seam": "march_reel/grassland/c0_seam" } },
      { "id": "grassland_c1", "art": { "far": "...", "near": "...", "seam": "..." } },
      { "id": "grassland_c2", "art": { "..." } },
      { "id": "grassland_c3", "art": { "..." } },
      { "id": "grassland_c4", "art": { "..." } },
      { "id": "grassland_c5", "label": "深处", "boss": true, "art": { "..." } }
    ],
    "parallax": { "far_factor": 0.18, "near_factor": 0.88 },
    "transition": {
      "mode": "dual_host_fog_parallax",
      "blend_base_m": 1.5,
      "blend_k": 8,
      "blend_min_m": 2,
      "blend_max_m": 12
    },
    "combat_slice_set": "grassland"
  }
}
```

**CampSegment**：全局一份，不进 `map_templates`；`camp/reel` + 建筑热点 id 固定。

**选图**：仅 reload `MapSegment` 的 chunk 集；Camp 不重建。

---

## 九、美术交付（按图估算）

| 包 | 数量/图 | 说明 |
|----|---------|------|
| `camp/reel` | **1 套全局** | 营地横卷 + 建筑位 |
| `march_reel/{map}/cN_far` | N 块/图 | v1 远景 |
| `march_reel/{map}/cN_near` | N 块/图 | v1 地面/路 |
| `march_reel/{map}/cN_seam` | N 块/图 | 块右缘过渡带 |
| `combat_slice/{set}/*` | 1～2/生态 | 块内遭遇；Boss +1 |

示例 grassland 6 块：**6×(far+near+seam) + camp + 切片** ≈ 20 张量级（可 PSD 分层导出）。

舞台高建议：**StageBand 280～320px**；单屏宽 = 视口 `W`（随窗口缩放）。

详见 [design-art-checklist.md](design-art-checklist.md)（跑图条带章节待 CTO 合并增补）。

---

## 十、现网代码映射

| 现组件 | 演进方向 |
|--------|----------|
| `bottom_stage.gd` | → **CampSegment**（已有 `CampScrollLane`、滚轮、建筑点） |
| `run_march_lane.gd` | 逻辑/state 保留；窄条视差降级 |
| `parallax_backdrop.gd` | 逻辑并入 **ChunkHost** far/near |
| `stage_shell.gd` / `main.gd` | 单窗 StageBand；TWIN 可选 `USE_DUAL_WINDOW` |
| `hud_dock.gd` | 绑定 `StageBand` 顶边 |
| `combat_view.gd` | 父节点迁入 `CombatSliceHost` |
| `march_event_markers.gd` | 坐标改块内像素；仍建议接 VisualSlot |

**不动**：`WorldRun` 刷怪/里程公式、`CombatController`、`StatResolver`、`SAVE_FORMAT`。

---

## 十一、开发 TASK 建议（CTO 排期用）

| 顺序 | ID | 名称 | 交付 | 门禁 |
|------|-----|------|------|------|
| 1 | **T-UI-REEL-1** | 单窗 StageBand + CampSegment 拉满高度 | 营地卷轴=主视觉；默认视口 Camp+chunk0 | SHELL-1 |
| 2 | **T-UI-REEL-2a** | 单 ChunkHost + far/near 视差 + 块内 scroll | 选图换 chunk 集；local_m 映射 | REEL-1 |
| 3 | **T-UI-REEL-2b** | 双 Host 并行卷轴 + distance 同步 | 跨 100m 换屏 | REEL-2a |
| 4 | **T-UI-REEL-2c** | 动态 blend + FogSeam | 速度混合带 + 接缝雾 | REEL-2b |
| 5 | **T-UI-REEL-3** | CombatSlice 块内拼接 | 进军停滚/返程边打；边界先接战 | REEL-2c |
| 6 | **T-UI-REEL-4** | 里程碑/采集/搜索坐标迁移 | 全局米→块内像素 | REEL-3 |
| — | T-UI-CQ-SHELL-2 | HudDock 右下 | 与 REEL-1 并行可商量 | — |
| — | T-ART-REEL-1 | 1 图 6 块 far/near/seam 占位 | manifest | FW-3 |

**废止排期**：`T-UI-CQ-SHELL-3`（60/40 分栏）除非 CTO 明确保留为 fallback。

---

## 十二、验收探针（F5 + headless）

### F5

1. 单窗；`StageBand` 贴底，高约 280px+；默认见 **Camp 建筑 + 地图入口屏**。  
2. 选 `grassland`：右侧 chunk 换草原；Camp 不变。  
3. 出征：约每 **100m** 换一整屏；**距离数字持续增加**（过渡不暂停）。  
4. 块缝无明显穿帮（雾带有效）。  
5. 接战：战斗发生在 **当前屏条带内**，不全屏盖住 Camp 卷轴。  
6. 99m 遭遇：先打完再换块。  
7. 返程：屏从反方向过渡；接战时背景随块变。  
8. BASE 滚轮可滑营地；RUNNING 不能手滑改进度。  
9. `MiaPhase1Probe` **0 FAIL**。

### headless（开发补）

- REEL-2b：`chunk_index` 在 100m 边界正确翻转。  
- REEL-2c：`blend_half_m` 随 speed 单调增且 clamp。  
- REEL-3：进军接战 `world_run_ticked` 与现 M2c 一致。

---

## 十三、开发铁律（违反拒 PR）

1. 单会话一次一 TASK。  
2. **不改** `CombatController` 伤害/选目标/胜负。  
3. **不改** `WorldRun` 里程与刷怪公式（表现层可改 scroll 映射）。  
4. **左营右深** 不得反转。  
5. 不做 CQ 固定传送门作为主流程。  
6. 不做消块、不做无限街景单图。

---

## 十四、CTO 待办 checklist

- [x] 在 `PROJECT_STATUS.md` 新增 **§T-UI-WORLD-REEL**，指针取代 CQ-SHELL-3 / E 线 STAGE 右栏分栏描述  
- [x] 修订 `design-pc-shell.md` §二、`design-base-ui.md` §CQ-SHELL：注明 WORLD-REEL 优先（2026-06-09 CTO）  
- [ ] 合并 `design-art-checklist.md` 分块资产表（→ **T-ART-REEL-1**）  
- [x] 指派首 TASK：**T-UI-REEL-1**；**FORM-3R / SHELL-2 并行**；**SHELL-1 吸收进 REEL-1**  
- [x] Camp ≈1.2 屏、未选图雾锁、RUNNING 禁滚轮、边界先接战 → **CTO YES**（签字表 §十五）  

---

## 十五、产品定案签字表（讨论收口）

| # | 项 | 定案 |
|---|-----|------|
| 1 | 一平面 Camp + Map | ✅ |
| 2 | 地图分块（例 6×100m，每图可配） | ✅ |
| 3 | 每块 ≈ 1 屏宽 | ✅ |
| 4 | 区块过渡：并行卷轴 + 雾带 + 视差 | ✅ 三手法叠加 |
| 5 | 过渡时里程仍 tick | ✅ |
| 6 | 混合带按速度动态 | ✅ |
| 7 | v1 视差 far+near 两层 | ✅ |
| 8 | 无固定传送门；CombatSlice 动态拼接 | ✅ |
| 9 | 边界遭遇先接战再换块 | ✅ 建议 |
| 10 | RUNNING 禁滚轮 | ✅ 建议 |
| 11 | Camp ≈ 1.2 屏；未选图雾锁 | ✅ 建议 |
| 12 | Boss 末块专用屏 + boss 切片 | ✅ 建议 |
| 13 | 单窗 + HudDock 右下 | ✅ 与 SHELL-1/2 一致 |

---

*本文档由产品讨论整理，供 CTO AI 审计、拆 TASK、更新任务板。开发 Agent 以 `PROJECT_STATUS` 当前指针为准。*
