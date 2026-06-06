# 项目状态（PROJECT_STATUS）

> **开工必读链：** [session_rules/README.md](session_rules/README.md)（按角色）→ [CTO.md](CTO.md) / [TASK_PROTOCOL.md](TASK_PROTOCOL.md) → **本文** → [ARCHITECTURE.md](ARCHITECTURE.md) → 最近 worklog。  
> 最后更新：2026-06-06（MARCH ✅ · ART-FW ✅ · 探针 **83 PASS** · 指针 **探针日 / T-ART-FW-3 可选**）

### CTO 结论（对齐版）

| 维度 | 状态 |
|------|------|
| **环 1 骨架** | ✅ M1～M3 YES |
| **大营 UI B 线** | ✅ 逻辑完成（B1～B4）；F5 肉眼 **探针日并行收** |
| **跑图 MARCH** | ✅ **M1～M3 + V1～V3** 逻辑 YES（77 PASS）；F5 探针日登记 |
| **美术** | **FW-1～2 ✅**（`VisualSlot` 已挂跑图五层）；纹理 manifest 可选 |
| **风险** | `origin/main` 待 push 最新 4 commit；**环 1 F5 未全员签字** |

---

## 开发交接（CTO → Dev，2026-06-06）

> **原则**：换骨架不换产品；单会话一次一 TASK；F5 与开发可并行，但 **环 1 探针未过不开新玩法**。

### 已完成（逻辑层 CTO YES，可依赖）

| 轨道 | 范围 | 探针 |
|------|------|------|
| **T-REFACTOR** | M1～M3 五层骨架 | worklog · M1 探针 1～5 |
| **T-RUN-V** | V1～V5 行军/接战/视差/追击剪影 | 65 PASS 含 V5 |
| **T-UI-B** | B1 / B1.5 / B2 / **B3 / B4** | 65 PASS 含 B3/B4 |
| **T-MARCH** | **M1～M3 + V1～V3** 搜索/里程碑/采集/返程池 | **77 PASS**（M2/MV2/MV3/M3）；F5 探针日 |
| **T-MIA** | 0～2 ✅；3/4 + P2～P5 逻辑齐 | MiaPhase1Probe；**待 F5** |

### 当前开发指针（唯一）

| 项 | 值 |
|----|-----|
| **ID** | **探针日（并行）** / **`T-ART-FW-3`（可选）** |
| **名称** | F5 验收清单 · 或 `art_manifest.json` 真图注册 |
| **门禁** | MARCH + ART-FW-2 ✅ |
| **不动** | `CombatController` 数值 · `StatResolver` · 存档字段 |

### 排队（可选）

1. **T-ART-FW-3** — `data/art_manifest.json` + `VisualSlot.apply_texture` 批量加载  
2. **T-UI-B5+** / 街景美术 — **后期**  
3. **T-MARCH-M4**（可选）— RunMarchView 事件点美术化（有美术资源后）

### 并行 CTO 验收（不占开发指针 · 建议半日「探针日」）

| 包 | 内容 |
|----|------|
| **环 1** | `test_03` M1 探针 1～5 + `run_probe.log` |
| **视差** | `test_01` / `test_03` 肉眼（V1～V5） |
| **大营 UI** | B1.5 零键盘 · B2 顶栏 · B3 编组卡 · B4 背包网格 |
| **MIA** | test_09 · 回收/压力/救援 F5 |
| **行军搜索** | `test_01` 每 10m 【搜索】飘字；接战期间不触发 |

### 运维

- MARCH 批次已 commit；**`main` 超前 `origin/main` 4 commit**（V2/V3/M3 + gitignore）→ **待 push**。  
- 日常冒烟：**`test_03` + `test_01`**；正式验收走 **探针日** 清单，不每日全跑 MiaPhase1Probe 全表。

---

## 当前阶段

**Sprint 重构环 1** — **M1 / M2 / M3 ✅ CTO YES**  
**Sprint 可视化** — **T-RUN-V1～V5 ✅**；**T-MARCH M1～M3 + V1～V3 ✅**（77 PASS）  
**Sprint 大营壳** — **T-UI-B1～B4 逻辑 ✅**；F5 肉眼并行验收  

- **下一开发**：**探针日 F5**（并行）或 **T-ART-FW-3**（有美术资源时）。  
- **并行**：**探针日**（半日 F5 + `run_probe.log`），不占开发指针。

---

## 当前任务

| 项 | 值 |
|----|-----|
| **ID** | **探针日** / **T-ART-FW-3** |
| **名称** | F5 全清单 · 可选纹理 manifest |
| **状态** | 🟡 **并行验收** |
| **优先级** | P1 |
| **门禁** | ART-FW-2 ✅ · 83 PASS |

### 并行验收（不占开发指针 · 探针日）

| ID | 名称 | 状态 |
|----|------|------|
| **探针日·环1** | `test_03` M1 探针 1～5 + `run_probe.log` | 🟡 headless **83 PASS** · F5 待收 |
| **探针日·视差** | `test_01` / `test_03` V1～V5 肉眼 | 🟡 待 F5 |
| **探针日·大营** | B1.5 / B2 / B3 / B4 零键盘与网格 | 🟡 待 F5 |
| **探针日·MARCH** | 搜索/里程碑/80m 采集 / 返程池 | 🟡 待 F5 |
| **T-MARCH-M1～M3 / V1～V3** | 跑图搜索与事件全线 | ✅ **逻辑 YES**（77 PASS） |
| **T-UI-B3 / B4** | 编组卡 + 大营背包网格 | ✅ **CTO YES**（63～65 PASS）；F5 待手测 |
| **T-UI-B1.5 / B2** | Dock + 顶栏稳定 | ✅ **CTO YES**；F5 待手测 |
| **T-RUN-V1～V5** | 行军视差 | ✅ **CTO YES**；F5 待手测 |
| **T-MIA-3 / T-MIA-4** | 冻结经验 + 回收 UI | 🟡 逻辑齐 · 待 F5 |
| **T-MIA-P2～P5** | 回收 / 压力 / 救援 | 🟡 逻辑齐 · 待 F5 |
| **T-02a / T-02e** | 濒死站位 + 测试编队 | 🟡 待 F5 |

---

## T-RUN-V 路线图（Sprint 可视化）

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-RUN-V1** | RunMarchLane + 停滚确认 + 状态字 | ✅ **CTO YES** | T-11a · M3 · 2026-06-06 |
| **T-RUN-V2** | ParallaxBackdrop + RunMarchView 占位 | ✅ **CTO YES** | V2a/V2b 探针 |
| **T-RUN-V3** | 接战锚点 + 敌从右入画 | ✅ **CTO YES** | V3a/V3b 探针 |
| **T-RUN-V4** | 返程行军与返程战背景同向 | ✅ **CTO YES** | V4a～V4c 探针 |
| **T-RUN-V5** | Boss 追击剪影 + 切换抛光 | ✅ **CTO YES** | V5a/V5b 探针 · 用户收 |

设计全文：[design-march-visual.md](design-march-visual.md) §一～§十二。

---

## T-MARCH · 跑图搜索与事件（CTO 定案 2026-06-06）

> 机制：[design-march-events.md](design-march-events.md)  
> 表现：[design-march-visual.md](design-march-visual.md) §十二

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-MARCH-M1** | `MarchSearchService` + 搜索池 JSON | ✅ **CTO YES** | T-RUN-V2 |
| **T-MARCH-V1** | `MarchSearchToast` + 顶栏/log 双通道 | ✅ **CTO YES** | M1 |
| **T-MARCH-M2** | 里程碑 `MarchEventService` + 事件表 | ✅ **CTO YES** | M2a/M2b |
| **T-MARCH-V2** | `MarchEventMarkers` 接地图数据 | ✅ **CTO YES** | MV2a/MV2b |
| **T-MARCH-V3** | `MarchGatherView` + `GATHER_BEAT` | ✅ **CTO YES** | MV3a～MV3d |
| **T-MARCH-M3** | 返程分池 + 稳定加权 | ✅ **CTO YES** | M3a～M3d |

**探针日 F5 清单（MARCH）**：

1. `test_01`：每 10m 【搜索】飘字；接战不触发。  
2. `grassland` 80m：【事件】遗弃箱 + 采集短演出 + 物资入箱。  
3. `grassland` 返程：搜索负面多于进军（M3）。  
4. `test_03`：环 1 探针 1～5 + `%APPDATA%/…/run_probe.log`。  
5. `CombatView` / 伤害公式 **无 diff**。

---

## T-REFACTOR · 整盘重构（CTO 定案 2026-06-06）

> **原则**：换骨架，不换产品。  
> **定案不变**：[GAME_BIBLE.md](GAME_BIBLE.md) 玩法、借鉴分工、双半组、箱与外露。  
> **目标形态**：[ARCHITECTURE.md](ARCHITECTURE.md) §三-B 五层架构。  
> **禁止**：推倒 StatResolver / JSON / 存档契约 / 新战斗场景从零写。

### 五层目标（摘要）

| 层 | 职责 | 现网主要文件 | 重构方向 |
|----|------|--------------|----------|
| ① 数据层 | `DataLoader` + `data/*.json` | `data_loader.gd` | **不动** |
| ② 领域层 | Mercenary / Squad / Equipment / StatResolver | `mercenary.gd`、`stat_resolver.gd`… | **薄改** |
| ③ 远征层 | 行程、稳定、刷怪、追击 **事件** | `world_run.gd` | 瘦身为调度；**不塞**战斗结局 |
| ④ 接战层 | EncounterSession + Policy + CombatController | `encounter_*.gd`、`combat_*.gd` | 胜败结局进 Session |
| ⑤ 壳子层 | 状态机 + Run 驱动 + UI 意图 | `game_manager.gd`、`main.gd`、UI | GM 瘦身；`RunDriver`；`RunEventPresenter` |

**GameManager 目标**：`BASE → PREPARE → RUNNING → RESULT` + 槽位/金币 API + 调 `SaveManager`。  
**SaveSerializer**：从 `GameManager` 剥 `to_save_dict` / `from_save_dict`（~300 行）。  
**RunDriver**（现 `main.gd` 瘦身）：只 `WorldRun.tick` + `EncounterSession`；`run_event` → `RunEventPresenter`。

### 路线图

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-REFACTOR-M1** | **可测**：接战门禁 + Encounter 收口 | ✅ **CTO YES** | 2026-06-06 · worklog |
| **T-REFACTOR-M2** | **可维护**：SaveSerializer + GM 瘦身 + RunEventPresenter | ✅ **CTO YES** | M1 YES |
| **T-REFACTOR-M3** | **可扩展**：WorldRun 调度化 + Combat 拆分 + legacy UI 移除 | ✅ **CTO YES** | M2 YES · 2026-06-06 |

### T-REFACTOR-M1 · 可测（明天 TASK）

| 项 | 值 |
|----|-----|
| **ID** | `T-REFACTOR-M1` |
| **名称** | 接战门禁 + EncounterSession 收口（编排可测） |
| **优先级** | **P0**（阻塞一切 F5 验收） |
| **预估影响** | `main.gd`、`world_run.gd`、`encounter_session.gd`、`retreat_spawn_service.gd`；必要时 `combat_movement_policy.gd` |

#### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **M1-1** | `CHASE_BOSS` 接战期间：**不 emit / 不消费** `enemy_spawn`（`EncounterSession.allows_pending_append` 收口） |
| **M1-2** | 首领接战 **开始/结束** 清 `_pending_enemies`；击退/击杀/失利后 **无 0.1s 链战** |
| **M1-3** | 首领接战期间 **冻结** `distance_traveled` 推进（与进军接战停滚、RunMarchLane 一致） |
| **M1-4** | 胜/败/击退/宝库/区域 Boss：**统一** 走 `EncounterSession.resolve_*`；删散落 `_chase_combat_active` 重复分支（若仍有） |
| **M1-5** | `CombatController` **不新增** `boss_chase` / `is_chase_encounter` 字符串；移动走 `CombatMovementPolicy` |

#### 不在范围

- `StatResolver`、伤害公式、技能 CD
- `SaveSerializer` / `GameManager` 大拆（**M2**）
- `RunEventPresenter` 新建（**M2**）
- T-MIA 玩法代码
- ~~T-RUN-V2～V5 视差~~（✅ 已交付占位实现）

#### 验收探针（CTO，F5）

1. **test_03** 首领接战：**全程无小怪插队**。  
2. 击退/击杀后 **不会立即再开战**（尊重 CD）。  
3. 首领接战时顶栏距离 **不继续掉**（冻结）。  
4. 进军接战停滚、返程小怪 `MARCH_RETREAT` **行为不退化**。  
5. `grep` `CombatController` 无 `boss_chase` / `is_chase_encounter`。

---

### T-REFACTOR-M2 · 可维护（M1 YES 后）

| 子项 | 要求 |
|------|------|
| **M2-1** | 新建 **`SaveSerializer`**：`to_save_dict` / `from_save_dict` 从 `GameManager` 迁出；GM 委托调用 |
| **M2-2** | **`GameManager` 瘦身**：仅状态机 + 槽位/金币/出征 API；编队/建筑/招募经现有或新 Service |
| **M2-3** | 新建 **`RunEventPresenter`**：吃掉 `main.gd` 内 `run_event` → 文案 switch |
| **M2-4** | **`RunDriver`**：从 `main.gd` 剥 `_process` 驱动（或 `main.gd` 瘦身为薄壳调 `RunDriver`） |
| **M2-5** | 旧档 **完全兼容**；`SAVE_FORMAT.md` 与序列化 **无字段删改** |

**探针**：`game_manager.gd` 行数 **< 900**；`main.gd` 行数 **< 500**；F5 读档/出征/结算 **不变**。

---

### T-REFACTOR-M3 · 可扩展（M2 YES 后）

| 子项 | 要求 |
|------|------|
| **M3-1** | `WorldRun.tick` 仅调度；刷怪/追击/护盾逻辑 **已在** `*Service`，删除内联重复 |
| **M3-2** | `CombatController` 拆：投射物 / 技能执行 可独立文件（移动已在 Policy） |
| **M3-3** | 移除 `main.gd` **legacy UI** 分支（`MainShell` 唯一路径） |
| **M3-4** | 为 `WorldRun.run_mode`（NORMAL/RECOVERY/RESCUE）留 **出征入口** 扩展点（桩即可） |

**探针**：T-MIA-0～2 ✅；T-MIA-3/4 及 P2～P5 逻辑齐；T-RUN-V1～V5 ✅（57 PASS）；T-02a 返程濒死 🟡 F5。

### 与其它工单门禁（M3 YES 后）

| 工单 | 门禁 / 状态 |
|------|-------------|
| **T-MIA-0～2** | ✅ **CTO YES** |
| **T-MIA-3 / T-MIA-4** | 🟡 逻辑已交付 · 待 F5 |
| **T-MIA-P2～P5** | 🟡 逻辑探针齐 · 待 F5 |
| T-02a / T-02e F5 | **已解禁** — 🟡 待 CTO 验收 |
| **T-RUN-V1～V5** | ✅ **CTO YES**（57 PASS） |

---

## T-MIA 失败掉人 · Phase 1 工单（CTO 定案 2026-06-05）

> **玩法定案**：[design-failure-lineage.md](design-failure-lineage.md)  
> **实现对照**：[design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) §四～§九  
> **工程定案**：`Mercenary.is_mia` · `WorldRun.run_mode` · `rescue_squad`（P4）· `account_meta` 冻经验 · 灭团→MIA

### CTO 方向评审（2026-06-05）

**结论：有条件 YES — Phase 1 可开工**

| # | 开工条件（缺一不可） |
|---|---------------------|
| 1 | **先 Phase 0 文档日**：`SAVE_FORMAT` + `ARCHITECTURE` 字段补丁说明；**可无玩法代码、单独合入** → **T-MIA-0D** |
| 2 | **Phase 1 范围锁死**（见下表）；救援队 / 压力二段 / 互捞短 Run / 停尸间 **不得** 混入 P1 TASK |
| 3 | **手动斩仓 B-8**：`manual_withdraw` → `settlement_tier=manual`，**不触发 MIA**（T-MIA-3 验收） |
| 4 | **主角**：Phase 1 保证永不 `enter_mia_state`；全灭回城可走现网 `end_run`，动画 **T-MIA-P3** |
| 5 | **P1 端到端回归**（§T-MIA 末）全过才称 Phase 1 完成 |

**Phase 1 范围锁（仅允许）**

`is_mia` · 灭团→MIA · `settlement_tier` · 冻结经验跳过全额入账 · 主城放弃搜寻/大价值占位 UI · 名册 `[遗留]`

**明确不含**：救援队、压力 V2、B-10 互捞短 Run、停尸间、读条一键实装、卷轴、大价值实扣资源

### 路线图

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-MIA-0D** | Phase 0 文档日（SAVE_FORMAT + ARCHITECTURE） | ✅ **CTO YES** | commit `e7f40b6` |
| **T-MIA-0** | 存档序列化桩 + RunMode + settlement_tier 桩 | ✅ **CTO YES** | 探针 0-2c · 2026-06-06 |
| **T-MIA-1** | `is_mia` + 序列化 + `can_join_squad` | ✅ **CTO YES** | 核对通过 |
| **T-MIA-2** | 灭团 → `enter_mia_state`（改 `_mark_squad_wiped`） | ✅ **CTO YES** | 用户收 · R1 探针 |
| **T-MIA-3** | `end_run` MIA 分支 + `account_meta` 冻结经验 | 🟡 **待 F5** | T-MIA-2 YES · R7 探针 |
| **T-MIA-4** | 主城回收 UI 占位 + 放弃搜寻 + 名册 `[遗留]` | 🟡 **待 F5** | T-MIA-3 逻辑齐 |
| **T-MIA-P2** | WorldRun `RECOVERY` 模式 + 短 Run 回收 | 🟡 **逻辑齐** | P2a～P2i 探针 |
| **T-MIA-P3** | 濒死二段 / 压力 / 撤离事件 | 🟡 **逻辑齐** | P3a～P3q 探针 |
| **T-MIA-P4** | `rescue_squad` + `RESCUE` 避战 + 停尸间 | 🟡 **逻辑齐** | P4a～P4e 探针 |

---

### T-MIA-0D · Phase 0 文档日（先于代码）

| 项 | 值 |
|----|-----|
| **ID** | `T-MIA-0D` |
| **名称** | SAVE_FORMAT + ARCHITECTURE 字段补丁（无玩法代码） |
| **状态** | ✅ **CTO YES** |
| **优先级** | P1 |
| **门禁** | [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) §八-B · commit `e7f40b6` |
| **预估影响** | `docs/SAVE_FORMAT.md`、`docs/ARCHITECTURE.md`（仅文档） |

#### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **0D-1** | `SAVE_FORMAT` 增：`account_meta.frozen_exp_pools[]`、`rescue_squad` 占位、`Mercenary.is_mia`、`settlement_tier` 结算字段说明 |
| **0D-2** | `ARCHITECTURE` §二/存档：允许上述 **账号 meta 字段补丁**；明确 MIA 状态 **不写 final 战斗属性** |
| **0D-3** | 注明旧档兼容：缺键默认空/false |

#### 不在范围

- 任何 `.gd` 代码改动

#### 验收探针（CTO）

1. 仅文档 diff，**无** `scripts/` 变更。  
2. 字段与 [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) §8.1 JSON 草案一致。  
3. ARCHITECTURE 铁律 **无矛盾** 表述。

---

### T-MIA-0 · 存档协议 + account_meta + RunMode 桩

| 项 | 值 |
|----|-----|
| **ID** | `T-MIA-0` |
| **名称** | 失败掉人 Phase 0：存档字段 + `account_meta` + `WorldRun.RunMode` 枚举桩 |
| **状态** | ✅ **CTO YES** |
| **优先级** | P1（机制地基） |
| **门禁** | **T-MIA-0D YES** ✅ · **T-REFACTOR-M3 YES** ✅ |
| **预估影响** | `save_serializer.gd`、`game_manager.gd`、`world_run.gd`、`run_mode_service.gd` |

#### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **0-1** | [SAVE_FORMAT.md](SAVE_FORMAT.md) 增：`account_meta`（含 `frozen_exp_pools[]` 结构草案）、`rescue_squad` 占位、`Mercenary.is_mia` |
| **0-2** | **`SaveSerializer`**（GM 委托）：`account_meta` / `rescue_squad` 默认 + 读写；旧档缺字段不报错 |
| **0-3** | `WorldRun`：`enum RunMode { NORMAL, RECOVERY, RESCUE }`，默认 `NORMAL`；本 TASK **不**接出征 UI |
| **0-4** | `end_run` result 增 **`settlement_tier`** 字符串桩：`success` \| `mia` \| `manual` \| `recovery`（默认仍 `success`，逻辑下 TASK 接） |

#### 不在范围

- `is_mia` 业务逻辑、灭团改 MIA、回收 UI、经验冻结公式

#### 验收探针（CTO）

1. 新档 `to_save_dict` 含 `account_meta`、`rescue_squad`（可空）。  
2. 旧档无上述键读档 **不崩**。  
3. `WorldRun.run_mode == NORMAL` 现网出征行为 **不变**。  
4. [SAVE_FORMAT.md](SAVE_FORMAT.md) 与序列化字段 **一致**。

---

### T-MIA-1 · Mercenary.is_mia 数据层

| 项 | 值 |
|----|-----|
| **ID** | `T-MIA-1` |
| **名称** | `is_mia` + `enter_mia_state` / 清 MIA + 序列化 + `can_join_squad` 拦截 |
| **状态** | ✅ **CTO YES** |
| **门禁** | **T-MIA-0 YES** ✅ |
| **预估影响** | `mercenary.gd`、`game_manager.gd`（`_serialize_merc`）、`squad_formation_service.gd`、`formation_ui.gd`、`squad_ui.gd`（仅拦截/灰显） |

#### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **1-1** | `Mercenary.is_mia: bool`；`enter_mia_state()` 清濒死、设 MIA；`clear_mia_state()` |
| **1-2** | `can_join_squad()` 增加 `not is_mia`；`mark_permanent_death()` 清 `is_mia` |
| **1-3** | 存档读写 `is_mia`；读档默认 `false` |
| **1-4** | 编组 UI：MIA 单位 **不可拖入出战槽**（toast 可选） |

#### 不在范围

- 灭团触发 MIA、结算冻经验、回收 UI

#### 验收探针（CTO）

1. 控制台或测试钩可令某 merc `enter_mia_state()` → `can_join_squad()==false`。  
2. 存读档后 `is_mia` 保持。  
3. `clear_mia_state()` 后可再编入（仍受濒死/养伤锁）。  
4. 现网无 MIA 时出征流程 **不回归**。

---

### T-MIA-2 · 灭团改 MIA（第一刀）

| 项 | 值 |
|----|-----|
| **ID** | `T-MIA-2` |
| **名称** | `_mark_squad_wiped` → 上场者 `enter_mia_state`（停用灭团即永久死亡） |
| **状态** | ✅ **CTO YES** |
| **门禁** | **T-MIA-1 YES** ✅ |
| **预估影响** | `main.gd`、`world_run.gd`（`end_run` / result 标记）、`result_ui.gd`（文案） |

#### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **2-1** | `main.gd` `_mark_squad_wiped`：对本趟 **实际上场** 成员 `enter_mia_state()`，**不**调用 `mark_permanent_death` |
| **2-2** | 灭团 `end_run`：`settlement_tier="mia"`；`player_alive` 等现网字段保持可结算 |
| **2-3** | RESULT 文案区分「战场遗留」vs「永久死亡」（永久死亡仅放弃搜寻，本 TASK 可先占位文案） |
| **2-4** | **主角**：永不 MIA（`Player` 跳过 `enter_mia_state`；灭团主角走现有濒死/回城桩，完整动画 **T-MIA-P3**） |

#### 不在范围

- 撤离失败比例 MIA、压力收场、经验冻结写入

#### 验收探针（CTO）

1. 测试图灭团（全队战场无活人且无人可返程）：参战 merc `is_mia==true` 且 `is_alive==true`。  
2. **无** `mark_permanent_death` 被灭团触发。  
3. 回 BASE 后名册可见 MIA 单位（不可编入）。  
4. 主角灭团场景不进 MIA。

---

### T-MIA-3 · account_meta 冻结经验

| 项 | 值 |
|----|-----|
| **ID** | `T-MIA-3` |
| **名称** | MIA 结算写 `account_meta.frozen_exp_pools`；成功过闸不冻结 |
| **状态** | 🟡 **待 F5**（R7 探针 PASS） |
| **门禁** | **T-MIA-2 YES** ✅ |
| **预估影响** | `game_manager.gd`、`world_run.gd`（`total_exp_earned`）、`apply_run_rewards` / `_apply_run_exp` |

#### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **3-1** | MIA 结算：`frozen_exp_pools` 追加条目 `{ run_id, map_id, total, mia_count, field_count, mia_ratio, timestamp }` |
| **3-2** | 冻结量 = 本趟 `total_exp` × **(MIA 人数 / 本趟上场人数)**（[B-6](design-failure-lineage.md)） |
| **3-3** | `settlement_tier=mia` 时 **`_apply_run_exp` 不发放**冻结部分（或未冻结部分按成功规则，本 Phase **可先整趟不发放**，回收解冻留 T-MIA-P2） |
| **3-4** | `settlement_tier=success` 行为 **不变** |
| **3-5** | **手动斩仓 B-8**：`manual_withdraw` → `settlement_tier=manual`；**不** `enter_mia_state`；`_apply_run_exp` 按现网战败档（不冻结、不永久没） |

#### 不在范围

- 回收成功 25% 解冻、救援额外经验

#### 验收探针（CTO）

1. 灭团结算后 `account_meta.frozen_exp_pools` 有记录且 `total>0`（若本趟有 exp）。  
2. 正常抵营成功：`frozen_exp_pools` **不增加**；经验仍入账。  
3. 存档后冻结池 **仍在**。  
4. **手动斩仓**：参战者 **无** `is_mia`；回大营仍可编入（仅养伤/战败惩罚若已有）。

---

### T-MIA-4 · 主城回收 UI 占位

| 项 | 值 |
|----|-----|
| **ID** | `T-MIA-4` |
| **名称** | 回收功能入口 + 放弃搜寻（永久没）+ 大价值复活占位 + 名册 `[遗留]` |
| **状态** | 🟡 **待 F5** |
| **门禁** | **T-MIA-3** 逻辑齐 |
| **预估影响** | `base_ui.gd` 或新 `recovery_ui.gd`、`main_shell.gd`（Dock/后勤入口）、`squad_ui.gd` / `formation_ui.gd` |

#### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **4-1** | 大营 **回收** 入口（后勤 Tab 或 Dock 子项）：列出 `is_mia` 单位 |
| **4-2** | **放弃搜寻**：二次确认 → `mark_permanent_death` + 清对应 `frozen_exp` 条目 + 文案 |
| **4-3** | **大价值复活** 按钮占位（可 toast「待接」或读条空壳）；**不**需真实扣资源（T-MIA-P2 接） |
| **4-4** | 名册/编组：`[遗留]` 标签；`get_display_class` 或等价 |

#### 不在范围

- 短 Run 回收、读条一键、卷轴、救援队

#### 验收探针（CTO）

1. BASE 可见至少 1 名 MIA 在回收列表。  
2. 放弃搜寻 → merc 永久死亡、移出 MIA 列表、冻结池对应项清除。  
3. 大价值按钮可点（占位反馈即可）。  
4. Phase 1 完成后 **无** 灭团即永久没路径（除放弃搜寻）。

---

### Phase 1 端到端回归（T-MIA-4 后 · CTO 总验收）

| # | 探针 |
|---|------|
| R1 | **灭团** → RESULT 文案为 **战场遗留 / MIA**，非「永久死亡」；参战 merc `is_mia` 且 `is_alive` |
| R2 | 回 **大营** → 回收列表 + 编组 **`[遗留]`** 可见；不可编入 |
| R3 | **放弃搜寻** → 仅此时名册 **`[死亡]`** + `mark_permanent_death` |
| R4 | **抵营全员濒死** → `run_success` / 养伤锁；**无** `is_mia` |
| R5 | **手动斩仓** → 无 MIA；`settlement_tier=manual` |
| R6 | **主角** 任意灭团/失败路径 → **永不** `is_mia` |
| R7 | MIA 结算趟 → `account_meta.frozen_exp_pools` 有记录；成功抵营趟 **不**增加 |

---

## T-UI-B1.5（大营 UI · 并行 / 可续）

| 项 | 值 |
|----|-----|
| **ID** | `T-UI-B1.5` |
| **名称** | 鼠标优先 · Dock 导航 + 地图选中/出征分离 + 后勤瘦身 |
| **状态** | ✅ **CTO YES**（B1.5a/b 探针 · 用户收；F5 零键盘待手测） |
| **优先级** | P1 |
| **预估影响** | `main_shell.gd`、`base_ui.gd`、`map_card_button.gd`、`squad_ui.gd` |

### 产品定案（2026-06-05）

**尽量只用鼠标完成大营→出征→回营**；F1～F5 保留为加速器，**不得**成为唯一入口。

### 背景（用户实测）

- Dock「编组」「地图」仅闪边框 → 鼠标点亦无效感。
- 地图卡片一点就进 PREPARE → 无法先「看一圈再决定」。
- 后勤弹窗按钮墙，与 Dock 重复。
- PREPARE 左窗长文占屏。

### 鼠标主链路（CTO 定案）

```
BASE：点卡片 → 仅选中（高亮+顶栏「已选」）
     → 点卡片上「出征」或 Dock「出征」→ PREPARE
     → 点 Dock「编组」→ 滚到中窗编组
     → 点 Dock「地图」→ 滚到左窗列表
     → 点 Dock「后勤」→ 弹窗（Tab/分节）
PREPARE：中窗点编组 / 点「出发」→ RUNNING
RESULT：点「返回基地」「再战」→ 回营或再开
```

### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **B1.5-1** | 卡片 **单击=仅选中**；选中卡显示 **「出征」按钮**（或卡片右侧主按钮）；Dock **「出征」** 同逻辑 → `start_prepare`；养伤锁正式图点出征仍 toast/原错误提示 |
| **B1.5-2** | Dock **「地图」**（鼠标/F4 同源）：BASE 滚左窗至列表顶 + 选中卡描边 ≥2s；PREPARE 滚左窗详情；RUNNING toast 一句 |
| **B1.5-3** | Dock **「编组」**（鼠标/F2 同源）：BASE/PREPARE 滚中窗编组区 + 描边 ≥2s |
| **B1.5-4** | Dock **「后勤」** 弹窗：建筑 / 招募 / 阵亡 **Tab 或折叠**；去掉「再战上次」「快速草原」等与 Dock 重复项 |
| **B1.5-5** | PREPARE 左窗：描述 **默认 2 行** + 可点「展开详情」 |
| **B1.5-6** | **零键盘探针**：全程不用 F 键完成 test_01 选图→出征→出发→回营；Dock 与卡片按钮 **min 点击区域 ≥36px 高** |

### 不在范围

- 中窗编组卡牌化（**T-UI-B3**）
- ~~顶栏稳定度条~~（**T-UI-B2** ✅）
- 右窗大营背包网格（**T-UI-B4**）
- `GameManager` 状态机 / 养伤锁判定重构
- RUNNING 底栏、战斗逻辑

### 验收探针（CTO，F5 · **仅用鼠标**）

1. BASE：点卡片 **不进 PREPARE**；再点卡片「出征」或 Dock「出征」才进准备页。  
2. 点 Dock「地图」「编组」：有滚动+描边，非空闪。  
3. 点 Dock「后勤」：Tab/分节清晰，无重复出征大按钮。  
4. PREPARE：左窗 ≤3 行+可展开；中窗 **「出发」** 可点进 RUNNING。  
5. RESULT：**「返回基地」** 可点回大营。  
6. **零键盘**：test_01 全流程鼠标走通；T-11 壳不回归。  
7. F1～F5 仍可用（加速器），与鼠标行为一致。

---

## T-UI-B2（顶栏稳定度 · 2026-06-06）

| 项 | 值 |
|----|-----|
| **ID** | `T-UI-B2` |
| **名称** | 顶栏稳定度进度条 + 养伤锁上移 |
| **状态** | ✅ **CTO YES**（B2a/b · 用户收；F5 肉眼待手测） |
| **交付** | 顶栏 `ProgressBar`；RUNNING 团队/个人稳定；养伤锁文案+ETA；底栏 `RunUI` 稳定行隐藏 |
| **探针** | B2a/B2b · 全量 **61 PASS** |

---

## T-UI-B1（上期 · 部分 YES 2026-06-05）

| 子项 | CTO |
|------|-----|
| B1-1 地图卡片 | ✅ 截图可见 `MapCardButton`、Boss/危险/用途行 |
| B1-2 QA 折叠 | ✅ 代码有 `▶ QA 测试` 默认折叠 |
| B1-3 status 迁出 | ✅ 左窗无大段 status；toast/dock_hint |
| B1-4 养伤锁灰显 | ⏳ 待养伤锁态截图 |
| B1-5 已选顶栏 | ✅ 「已选：测试④b…」 |
| **缺口** | ~~单击即出征、Dock F2/F4~~ → **B1.5 ✅ 已收口** |

### §BUG-地图卡点击无响应（2026-06-05 · P0 热修 · 已交代码）

| 项 | 内容 |
|----|------|
| **现象** | ① 出征钮无反应 ② 热修后**整卡无法选中** |
| **根因** | ① 全卡透明 `_select_btn` 盖住出征钮 ② `info_stack` 用裸 `Control` 父节点，热区 **0×0** |
| **修法** | `_select_btn` 最后叠在卡上，**底部 offset 让出征条露出**；信息区用 `HBox+VBox` 正常撑高 |
| **须改** | `scripts/ui/map_card_button.gd` |
| **探针** | 点草原→顶栏/高亮变；点出征→PREPARE；Dock 出征仍可用 |

---

## 并行验收队列（不占 T-05 开发 slot，F5 勾选即可）

| 项 | 值 |
|----|-----|
| **ID** | `T-02a` → `T-02e`（建议先 ②e 再 ②a） |
| **名称** | 濒死站位；测试图自带编队 + 平衡 |
| **状态** | 🟡 待 CTO 验收 |
| **优先级** | P0 / P1 |
| **预估影响** | `combat_controller.gd`；`game_manager` / 测试图（已交，见下节探针） |

## T-02a（并行验收 · 代码已交）

### 背景（根因）

1. 敌方 `_find_nearest_alive` / `_find_nearest_in_range` 只排除 `is_dead()`，**濒死 DOWNED 仍可选中**。
2. 濒死单位 `is_incapacitated()` → 不移动；返程时存活者 `_drift_homeward`，濒死者 **position 冻在倒下处**（常为前排）。
3. `supported_by_id` 仅影响世界层返程移速，**战斗内未用**。

### 交付范围（必须做）

| 子项 | 要求 |
|------|------|
| **2a-1 目标优先级** | 敌方选攻击目标时 **跳过** `not can_fight()` 的友方（含 DOWNED 濒死）；无其他可打目标时再 fallback（或无目标） |
| **2a-2 撤回复位** | 濒死进入 DOWNED 时，**一次性**将 `position` 置于友方后排（取 `min(友方 position)` 或 `ALLY_SPAWN_X`，不每 tick 移动） |
| **2a-3 返程入场** | 返程战斗开始（`_march_retreat_combat`）时，对 **已在场上濒死** 的友方再执行一次后排归位（覆盖「先濒死、后返程」） |

### 不在范围

- T-02 远程后排射程/走位大改
- T-02b CombatView 72/48 像素统一
- 搀扶跟随动画（`supported_by_id` 战斗内绑定）
- 套装 StatResolver（T-01 暂停，做完 T-02a 再开）
- 研究所 / 转生 / 云存档

### 设计对齐说明

`design-near-death.md`：濒死「不攻击、不移动」= **无自主 tick 移动**。  
2a-2/2a-3 的 position 快照视为 **搀扶拖至后排**，非违背铁律；无需改 ARCHITECTURE。

---

## 冻结项（本阶段禁止开发）

- T-01 套装（⏸ 暂停，非取消）
- T-07 研究所 / T-08 转生（P1）
- T-09 多槽 / T-10 云存档
- A3 属性管线重构（已封板）
- **无 CTO 授权的跨模块重构**（✅ **T-REFACTOR M1～M3 已授权**，见 §T-REFACTOR）
- **推倒重做**：新战斗引擎 / 新存档格式 / 废 GAME_BIBLE 定案

---

## 任务板

| ID | 任务 | 优先级 | 状态 | 门禁 |
|----|------|--------|------|------|
| T-00 | QA 基线验收 | Sprint 0 | 🟠 进行中 | 并行 |
| T-01 | 套装 → StatResolver + UI N/M | P0 | ⏸ **暂停** | T-02a YES 后恢复 |
| **T-02e** | **测试图自带编队 + 平衡** | **P1** | 🟡 **待 CTO 验收**（M3 后解禁） | test_01~08 已生成 |
| **T-02a** | **濒死撤退站位 + 目标优先级** | **P0** | 🟡 **待 CTO 验收**（M3 后解禁） | 代码已交付 |
| T-02 | 远程后排调参/站位 | P0 | ⏸ | T-02a YES |
| T-02c | 主角独立 + 纯佣兵可出征 | **P0** | 📋 **已登记** | T-02a YES 后 |
| T-02b | CombatView 位置映射统一 | P2 | ⏸ | T-02 后 |
| T-03 | 技能 CD + active_skills | P0 | ⏸ | T-02 YES |
| T-04 | 战斗测试模式 | P0 | ⏸ | — |
| **T-11a** | **PC 主壳 + 底栏 Run 条** | P0 | ✅ **CTO YES** | 2026-06-05 截图+代码 |
| **T-11b** | **三窗内容迁移 + Dock/F5 后勤** | P0 | ✅ **CTO YES** | 依赖 T-11a |
| **T-05** | **出征网格 UI** | P0 | ✅ **CTO YES** | 2026-06-05 test_04 RESULT 截图 |
| **T-UI-B1** | **大营左窗 · 地图卡片+测试折叠** | P1 | ✅ **CTO YES** | B1.5 收口 |
| **T-REFACTOR-M1** | **接战门禁 + Encounter 收口** | **P0** | ✅ **CTO YES** | 2026-06-06 |
| **T-REFACTOR-M2** | SaveSerializer + GM 瘦身 + Presenter | P0 | ✅ **CTO YES** | M1 YES |
| **T-REFACTOR-M3** | WorldRun 调度化 + Combat 拆分 | P1 | ✅ **CTO YES** | M2 YES · 2026-06-06 |
| **T-RUN-V1** | **RunMarchLane + 停滚 + 状态字** | **P1** | ✅ **CTO YES** | M3 · 2026-06-06 |
| **T-RUN-V2** | ParallaxBackdrop + RunMarchView | P1 | ✅ **CTO YES** | V2a/V2b |
| **T-RUN-V3** | 接战锚点 + 敌从右入画 | P1 | ✅ **CTO YES** | V3a/V3b |
| **T-RUN-V4** | 返程行军与返程战同向 | P1 | ✅ **CTO YES** | V4a～V4c |
| **T-RUN-V5** | Boss 追击剪影 + 切换抛光 | P1 | ✅ **CTO YES** | V5a/V5b · 用户收 |
| **T-UI-B1.5** | **Dock + 地图鼠标优先** | P1 | ✅ **CTO YES** | B1.5a/b · 用户收 |
| **T-UI-B2** | **顶栏稳定度/养伤锁上移** | P1 | ✅ **CTO YES** | B2a/b · 用户收 |
| **T-UI-B3** | **中窗编组视觉** | P1 | ✅ **CTO YES** | B3a/b · 63 PASS |
| **T-UI-B4** | **右窗大营背包网格** | P1 | ✅ **CTO YES** | B4a/b · 65 PASS |
| **T-MARCH-M1** | 自动搜索服务 | P1 | ✅ **已交付** | 待探针登记 |
| **T-MARCH-V1** | 搜索飘字 Toast | P1 | ✅ **已交付** | M1 |
| **T-MARCH-M2～M3 / V2～V3** | 里程碑 + 采集 + 返程池 | P1 | ✅ **CTO YES** | 77 PASS |
| **T-ART-FW-1** | 视觉常量 + VisualSlot | P1 | ✅ **CTO YES** | FW1a/b |
| **T-ART-FW-2** | 跑图五层挂 VisualSlot | P1 | ✅ **CTO YES** | FW2a～d · 83 PASS |
| **T-ART-FW-3** | art_manifest 真图 | P2 | 📋 可选 | 有美术资源时 |
| T-06 | Buff / 觉醒头标 | P0 | ⏸ 让位 B 线 | T-05 YES |
| T-07~T-10 | 研究所/转生/多槽/云存档 | P1~ | 🔒 冻结 | — |
| **T-MIA-0D** | **失败掉人 P0 文档日** | **P1** | ✅ **CTO YES** | `e7f40b6` |
| **T-MIA-0** | 存档序列化桩+RunMode | P1 | ✅ **CTO YES** | 0-2c 探针 |
| **T-MIA-1** | is_mia 数据层 | P1 | ✅ **CTO YES** | 核对 |
| **T-MIA-2** | 灭团→MIA | P1 | ✅ **CTO YES** | R1 探针 |
| **T-MIA-3** | 冻结经验 | P1 | 🟡 **待 F5** | R7 探针 |
| **T-MIA-4** | 回收 UI 占位 | P1 | 🟡 **待 F5** | — |
| **T-MIA-P2~P5** | 回收/压力/救援/卷轴 | P1~ | 🟡 **逻辑齐** | P2～P5 探针 |

---

## T-02a 验收探针（CTO）

1. 编队：使用 **测试⑥ `test_06_near_death_duo` 自带编队**（⑥·主角前排 + ⑥·前排铁卫）；选图后见 `[本图编队]`。  
2. 去程或 **返程战斗** 中让 A 进入濒死（显示 `(濒死)`）。  
3. 返程战斗继续时：  
   - [ ] A 的战场 position **位于友方最左/后排**（比存活战斗单位更靠后）  
   - [ ] 敌人 **优先攻击** 仍能战斗的友方，而非 A  
   - [ ] A 仍不攻击、不自主移动（觉醒窗口行为不变）  
4. 若全员濒死或仅 A 在场：敌人行为不崩溃（可无目标或仅收尾逻辑）。  
5. diff 仅 `combat_controller.gd`（及必要时 `combat_entity.gd`）；未改 StatResolver / 套装 / 转生。

**通过后**：恢复 **T-01** 为当前任务（或按 CTO 指示改 T-02）。

---

## T-02e backlog（测试图自带编队 + 平衡 · 已交付待验收）

**变更摘要**：删除旧 8 张测试图（`retreat_drill`、`test_near_death_duo` 等）→ 新 **`test_01`~`test_08`**；每张图 **点选时注入自带测试人物**（`data/test_map_rosters.json`）。测试档改为 **空 roster 占位**，避免与图内编队冲突。

| 新 `map_id` | 名称 | 自带编队要点 | 目标用时 |
|-------------|------|--------------|----------|
| `test_01_stability_retreat` | ①稳定返程 | 主角+铁卫+术士+游侠 | 3~4 min |
| `test_02_extract_line` | ②撤离物线 | 主角+斥候+铁卫 | 3~5 min |
| `test_03_boss_chase` | ③Boss追击 | 主角+盾卫+术士+游侠 | 4~5 min |
| `test_04_auto_value` | ④价值撤离 | 主角+拾荒+铁卫 | 3~5 min |
| `test_05_loot_full` | ④b网格满 | 同④ | 3~5 min |
| `test_06_near_death_duo` | ⑥双人濒死 **T-02a** | ⑥·主角 + ⑥·前排铁卫 | 3~5 min |
| `test_07_near_death_solo` | ⑦单人濒死 | 仅主角 | 3~4 min |
| `test_08_awakening` | ⑧觉醒 | 主角+奥术+铁卫 | 4~5 min |

**代码**：`TestScenarioService` + `GameManager.apply_map_test_roster` + `DataLoader.test_map_rosters_data`；生成器 `tools/generate_test_maps.py`。

**探针**：

1. `python tools/build_test_save.py` → F5 读档 → 点 **测试⑥** → 准备页见 `[本图编队] ⑥·主角+⑥·前排铁卫`。  
2. **测试⑥** 一趟 **3–5 min** 回营；返程 **≥2 波**。  
3. ①~⑧ 各点一次，编队名称与上表一致（无需大营手动编队）。  
4. 旧 `map_id` 在地图列表中 **不存在**。

---

## T-02c backlog（主角独立 + 纯佣兵可出征 · 用户定案 2026-06-05）

> **阻塞 QA（2026-06-05 截图）**：全员满血仍显示「全队养伤锁」无法出征 — 见下节 **§复现-BUG-养伤锁误报**。

### §复现-BUG-养伤锁误报（给开发）

| 项 | 内容 |
|----|------|
| **标题** | 佣兵 100% HP 仍触发养伤锁，无法出征 |
| **环境** | 测试档 `tools/seed_saves`；地图 `test_near_death_duo`；大营 `BaseUI` + `FormationUI` |
| **复现** | 双半组中主角被右键移出出战位（在「未编入」）或不在 A/B `active`；A/B 内佣兵均为 **100% HP · 可出战** |
| **实际** | 顶部/底部「全队养伤锁：两半组均无法出征，请恢复至 70% 并清濒死」；半组标题 **休整**；「预计 40 秒后可出征」；再战/出征不可用 |
| **预期（T-02c 后）** | 半组有 ≥1 可出战佣兵即可出征；主角留营；**不**显示养伤锁（或明示「主角留营·佣兵出征」） |
| **根因（现网代码）** | `half_can_deploy()` L54–57：要求 `player.merc_id in active` 且 `player.can_join_squad()` → 主角不在槽则 A/B 皆 `false` → `is_recovery_lock_active()` 为 true。佣兵条目 `_merc_recovery_entry` 仍显示「可出战」，与半组 `can_deploy` **不一致**。养伤锁文案 `get_formation_summary` / `formation_ui._refresh_recovery` **未区分**「真·养伤」与「主角未编入」。 |
| **临时绕过（测 T-02e 用）** | 未编入池点 **★测试指挥官** 填回任一半组 **战1–战4** → 锁消失 |
| **须改文件** | `squad_formation_service.gd`（`half_can_deploy`、`is_recovery_lock_active`、`resolve_deploy_squad`）、`game_manager.gd`（`start_run` L331–332、`redeploy_same_map`）、`formation_ui.gd`（养伤锁/休整文案）、`squad_ui.gd`、`base_ui.gd` |
| **验收** | 主角在未编入 + A 或 B 有 2 佣兵 100% → **可出征**，名单无主角；不再出现「70%/濒死」养伤锁文案 |

**现象（总述）**：主角占 A/B 槽位时另一半组无法出征；主角休整/濒死时佣兵组也无法单独出发。  
**根因**：`start_run` / `half_can_deploy` 强制主角在场且占槽。

**CTO 定案（用户确认）**：

| 规则 | 说明 |
|------|------|
| **主角不占 A/B 槽** | `squad_formation` A/B **仅存佣兵**；主角 UI 独立（战略核心），不进未编入/替补 |
| **纯佣兵可出征** | 任一半组 active 有 ≥1 `can_join_squad` **佣兵** 即可 `half_can_deploy`；**不要求**主角 `can_join_squad` |
| **出征名单** | `resolve_deploy_squad(half)` = 该半组可出战佣兵（最多 **4** 人上场）；**默认不追加主角** |
| **主角留营** | 纯佣兵趟：主角在大营继续慢回/医疗室治疗；**不获得**本趟 `run_kills` / `run_damage_dealt` |
| **养伤锁** | 仅当 A、B 两半组 **佣兵** 均无可出战成员时触发；主角状态**不**参与养伤锁 |
| **稳定度/护盾** | 已有 fallback：`stability.init(null)` 无主角加成；`get_retreat_shield_anchor` 用存活佣兵 |
| **读档迁移** | `ensure_formation` 从 A/B 移除 `player.merc_id` |

**交付范围（T-02a 通过后开）**：

| 子项 | 要求 |
|------|------|
| 2c-1 | 移除 `start_run` 对 `player.can_join_squad()` 的硬门禁（-3 仅保留主角已上阵但不可战等边缘，或废弃该路径） |
| 2c-2 | `half_can_deploy` / `pick_deploy_half` / `is_recovery_lock_active`：只判半组**佣兵** |
| 2c-3 | `resolve_deploy_squad`：仅佣兵；`rebalance` / `auto_fill` 排除 `player.merc_id` |
| 2c-4 | `FormationUI` / `SquadUI`：主角独立卡片 + 准备页明示「本趟佣兵出征，主角留营」；**养伤锁面板勿在「仅主角未编入」时显示 70%/濒死文案**（见 §复现-BUG） |
| 2c-5 | `base_ui` 再战/自动循环：主角不可战时仍允许佣兵半组出征（若半组就绪） |
| 2c-6 | 同步 `design-expedition-meta.md`、`SAVE_FORMAT.md` |

**不在范围（可后续 T-02d）**：「主角随行」勾选、战斗数值平衡、T-02a。

**探针**：

1. 主角**濒死/休整**，B 有 2+ 可出战佣兵 → **B 可出征**，场上无主角，主角留营回血。  
2. 主角满状态，A 可出战佣兵 ≥1 → **A 优先出征**，名单**无主角**（默认不带）。  
3. A、B 佣兵均不可出战 → 养伤锁，与主角状态无关。  
4. 纯佣兵趟结算：`player` HP/濒死不变；佣兵战果正常写入。  
5. 旧档：主角从 A/B 槽剥离后可按上规则出征。  
6. **（§复现-BUG）** 主角在「未编入」、A 组 3 佣兵 100% 可出战 → **无养伤锁**，可点地图出征。

---

## T-01 验收探针（暂停，待恢复）

（内容不变，见 git 历史或 TASK 文档。）

---

## T-11a 验收探针（CTO · 2026-06-05 YES）

- [x] 1280×720：顶栏 + 三窗 + 底栏 + Dock 同屏  
- [x] BASE：底栏待机，上区可见  
- [x] PREPARE：壳不变，底栏可见  
- [x] RUNNING：底栏战斗，上区可见  
- [x] RESULT → 回大营 → BASE  
- [x] T-11a diff 无 `game_manager` 出征/奖励/测试编队核心改动  

## T-05 验收探针（CTO · 2026-06-05 YES）

- [x] RESULT（`test_04`）：右窗 **安全箱 3×3 + 外露 4×3** 分区；占格块与 `2/9` 一致  
- [x] 携带价值 **292/140** 与返程原因「携带价值达标」一致  
- [x] T-11 壳层同屏（顶栏 + 三窗 + 底栏 log）未回归  
- [x] `RunGridUI` + `get_placement_snapshots()` 只读；`main_shell` RUNNING/RESULT 刷新链就绪  
- [x] T-05 文件集 **无** `game_manager` 改动（工作区其余 diff 属 T-02e，不记入本 TASK）  
- [ ] RUNNING 态占格 **实时变化** — 代码已挂 `refresh_running_panels()`；建议 F5 目视补勾（不挡 YES）

## T-11b 验收探针（CTO · 2026-06-05 YES）

- [x] 大营无需纵向滚完编队+地图+名册（三列同屏）  
- [x] Dock 可达编组/地图/后勤（F2/F4/F5）  
- [x] `test_01` 选图→出征→回营全流程 UI 可用  
- [x] 养伤锁、测试图重注入提示可见（非锁态见编队摘要；锁态见顶栏/FormationUI；测试图 tooltip 与 description 有小重叠，不挡验收）  

---

## 最近 TASK 完成记录

| ID | 完成日 | 是否进入下一任务 |
|----|--------|------------------|
| T-11a | 2026-06-05 | YES → T-11b |
| T-11b | 2026-06-05 | YES → T-05 |
| T-05 | 2026-06-05 | YES → T-06（已让位） |
| — | 2026-06-05 | CTO 插队 → **T-UI-B1** |
