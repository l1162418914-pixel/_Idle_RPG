# 项目状态（PROJECT_STATUS）

> **开工必读链：** [session_rules/README.md](session_rules/README.md)（按角色）→ [CTO.md](CTO.md) / [TASK_PROTOCOL.md](TASK_PROTOCOL.md) → **本文** → [ARCHITECTURE.md](ARCHITECTURE.md) → [EXTERNAL_AI_BRIEF.md](EXTERNAL_AI_BRIEF.md)（外部评审用）→ 最近 worklog。  
> 最后更新：2026-06-09（**T-UI-LAYOUT 用户分区定案** · 后勤改下窗 CQ · 编组 ⏸ 待定）

### CTO 结论（对齐版）

| 维度 | 状态 |
|------|------|
| **环 1 骨架** | ✅ M1～M3 YES |
| **大营 UI B 线** | ✅ 逻辑 + **F5 冒烟 YES**（出征/网格/底栏随 test_01 验证） |
| **跑图 MARCH** | ✅ M1～M3 + V1～V3；**F5 test_01 搜索+接战冻结 YES** |
| **美术** | ✅ **FW-1～3**（manifest 可挂真图；战斗区仍占位色块属预期） |
| **UI 双窗** | 🟡 **T-UI-TWIN-1 开发交付 · 待 CTO F5**（上窗计划 / 下窗动画） |
| **探针日** | ✅ **冒烟收盘**（见下表）；**延期**：test_03 F5、grassland 80m、MIA、T-02a |

---

## 开发工作安排（Dev Sprint · 2026-06-06 起）

> **复制本节前四节即可发给开发。** 细则探针见本文 §当前任务、§T-06、§T-MARCH、[design-combat-stack.md](design-combat-stack.md)。

### Sprint 目标（约 2 周）

1. **收口 F5**：战斗包 + 环 1 + MIA 肉眼验收，CTO 可签字。  
2. **不新开玩法代码**：逻辑已 YES 的项只补测/修 bug，不扩 scope。  
3. **内容填充**：跑图事件表、manifest 真图（可与程序并行）。  
4. **日常**：`test_03` + `test_01` 冒烟；合码前 `MiaPhase1Probe` **122 PASS**。

### 三线分工

| 线 | 谁 | 做什么 | 产出 |
|----|-----|--------|------|
| **A · 验收** | 你 / QA | F5 探针日 + 延期包 | worklog 勾选 + CTO YES |
| **B · 程序** | Dev Agent | 探针缺口、headless 补探针、文档债、**不修已 YES 逻辑** | 小 PR / 单 TASK |
| **C · 内容** | 你 + 美术 | `march_events.json`、地图里程碑、`art/` 挂 manifest | 无需改 Combat 公式 |
| **D · 编队** | Dev Agent | **FORM 语义 3R/6** + **FORM-LAYOUT 方案 B** | 见 §T-UI-FORM / §T-UI-LAYOUT |
| **E · 大营观感** | Dev Agent + 美术 | **T-UI-TWIN-1**（双窗壳）→ **STAGE-2**（CQ 像素动画）+ CAMP-4 | 见 §T-UI-TWIN / §T-UI-STAGE |

### 当前程序指针（编队专题）

| 顺序 | ID | 状态 |
|------|-----|------|
| 1 | **T-UI-FORM-3R** | 📋 **下一开发** |
| 2 | T-UI-FORM-2 | 待排（门禁 FORM-1） |
| 3 | T-UI-FORM-6 | 待排（门禁 FORM-3R） |
| 4 | T-UI-FORM-4 | 待排（门禁 FORM-2） |
| — | T-UI-FORM-F5 | 🟡 条件通过（备战席热修暂过关） |
| — | T-UI-FORM-7 | ⏸ 可选（FORM-F5 后） |

产品定案：[design-expedition-meta.md](design-expedition-meta.md) §双半组语义。

### 当前程序指针（大营观感 · E 线）

| 顺序 | ID | 状态 |
|------|-----|------|
| 1 | **T-UI-TWIN-1** | 🟡 **开发交付 · 待 CTO F5** |
| 2 | **T-UI-STAGE-2** | 📋 **下一开发**（营火 idle 真图） |
| 3 | **T-UI-STAGE-5** | 📋 待排（**下窗 CQ 后勤建筑**） |
| 4 | T-UI-STAGE-3 | 待排（养伤包扎/躺卧） |
| 5 | T-UI-STAGE-4 | 待排（抵营/清点动画） |
| — | T-UI-STAGE-1 | 🟡 **并入 TWIN-1**（`StageShell`+`BottomStage`） |
| — | T-UI-CAMP-1 | 🟡 部分交付（中窗缩略；可折叠） |
| — | T-UI-CAMP-4 | 可与 STAGE-2 并行 |
| — | **T-UI-FORM-LAYOUT-1/2** | D 线 · 方案 B（下窗点人+上窗简表） |
| — | **T-UI-FORM-3R/6** | D 线语义（门禁 LAYOUT） |

产品定案：用户 2026-06-08 **动画与计划 UI 切成两个 OS 窗口** → [design-pc-shell.md](design-pc-shell.md) §二·双窗。

**复制给开发（E 线当前）**：T-UI-TWIN-1 已合码则转 CTO 验收；下一单 **T-UI-STAGE-2**（`camp/*` manifest + idle 序列帧）。

### 第 1 周（优先）

| 天 | A 线（F5） | B 线（程序，A 空档可做） |
|----|------------|---------------------------|
| **D1** | 批次 **AB**：T-02c 纯佣兵出征 + T-01 套装 N/M | ⏸ `git` push 待用户 · headless ✅ |
| **D2** | 批次 **AB**：T-04 测试开关 + T-03 技能角标 | ✅ **B-1 M2c** |
| **D3** | 批次 **C**：`test_03` 环 1 五探针 + `run_probe.log` | ✅ **B-2** UI 审计 |
| **D4** | `grassland` 推到 80m 里程碑/采集 | ✅ **B-3** 草原事件 |
| **D5** | `test_09` MIA 冒烟（不全线也可） | ✅ **B-5** worklog 登记（见 `worklogs/2026-06-06.md`） |

### 第 2 周（F5 收口后）

| 优先级 | ID | 名称 | 门禁 |
|--------|-----|------|------|
| P0 | **T-MIA-F5** | MIA 全线 F5（test_09 + 回收/压力） | T-MIA 逻辑齐 |
| P1 | **T-MARCH-C1** | 跑图事件内容池扩充 | ✅ C1-1～C1-3 · grassland + test_01～09 + forest/cave/death_trial |
| P1 | **T-ART-C1** | manifest 挂真图（P0 跑图包） | FW-3 YES · [design-art-checklist.md](design-art-checklist.md) |
| P2 | **T-02b** | CombatView 槽位/脚线统一 | ✅ 02b-1～02b-2 · F5 延期 |
| — | **design-meta-base** | 局外成长占位填初稿 | CTO 讨论，非代码 |

### 单 TASK 卡片（当前唯一程序指针 = 验收；B 线从下列选）

#### 【A-1】F5 · 战斗/大营包（P0 · 你或 QA）

| 项 | 内容 |
|----|------|
| **范围** | T-01 · T-02c · T-03 · T-04 |
| **步骤** | 见 [design-combat-stack.md](design-combat-stack.md) §八 + 本文 §当前任务 |
| **通过** | 四项 F5 勾选；不回归 T-06（已 YES） |
| **禁止** | 改 `combat_controller` 伤害/选目标 |

#### 【A-2】F5 · 环 1 + MARCH（P0 · 延期包）

| 项 | 内容 |
|----|------|
| **test_03** | 追击接战无小怪插队；顶栏距离冻结；胜后无链战 |
| **grassland 80m** | 里程碑标记 + 采集短停（可选 loot 事件） |
| **test_01** | 接战期间无【搜索】飘字（已冒烟可速验） |
| **日志** | 跑完 test_03 读 `%APPDATA%\Godot\app_userdata\TBH Idle RPG\run_probe.log` |

#### 【A-3】F5 · MIA（P1）

| 项 | 内容 |
|----|------|
| **图** | `test_09` 为主；辅以 test_07/灭团场景 |
| **文档** | [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) §验收 |
| **禁止** | 为通过 F5 改 MIA 数值铁律 |

#### 【B-1】headless · M2c 搜索冻结（P1 · Dev · ✅ 2026-06-06）

| 项 | 内容 |
|----|------|
| **交付** | `run_driver.gd`：`march_allowed = world_run_ticked && !接战`；探针 **M2c** PASS |
| **不动** | `WorldRun` 刷怪公式 · V4 返程接战视差仍 tick |

#### 【B-2】文档 · UI 审计同步（P2 · Dev · ✅ 2026-06-06）

| 项 | 内容 |
|----|------|
| **交付** | `UI_SUBSYSTEM_AUDIT.md` §〇 状态表 + §三/§六/§八/§九 同步 T-01/T-03/T-06/T-04/T-02c |
| **不动** | 玩法代码 |

#### 【B-3】内容 · 草原里程碑（P1 · Dev · ✅ 2026-06-06）

| 项 | 内容 |
|----|------|
| **交付** | `march_events.json` +3 条；grassland `80/120/165/200m`；探针 B3-1/B3-2 |
| **验收** | F5 grassland 80m 遗弃箱 + 120m 采集（A 线 D4） |

### 开发铁律（违反即拒 PR）

1. **单会话一次一 TASK** — 见 [TASK_PROTOCOL.md](TASK_PROTOCOL.md)。  
2. **属性只走 StatResolver**；RUNNING 不存档。  
3. **CombatController 不加** `boss_chase` / `is_chase_encounter`。  
4. **CombatView 不改** 伤害、CD、胜负。  
5. **环 1 test_03 五探针未 F5 YES 前**，不排新战斗机制（T-02 已 YES，勿再大改远程）。

### 每日节奏

```
开工 → test_03 或 test_01 冒烟（5 min）
     → 做当日 TASK 卡片一项
     → 若改 scripts → MiaPhase1Probe 全表
     → worklog 记一条（完成内容 / 探针 / 是否进入下一项）
```

### 合码检查清单

- [x] `MiaPhase1Probe` **117 PASS**（0 FAIL）  
- [ ] 未改 `SAVE_FORMAT` 字段（除非 T-MIA CTO 授权）  
- [ ] `PROJECT_STATUS` 当前指针已更新  
- [ ] F5 项在 worklog 有 `[ ]` → `[x]` 或明确延期原因  

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

### 接战分层（T-REFACTOR 已收口）

`EncounterSession` → `CombatMovementPolicy` → `CombatController` → `CombatView` / `UnitView`  
属性仍经 **StatResolver**（§一）；接战结局不进 Controller 分支（§三）。

### 当前开发指针（战斗专题 · 顺序固定）

| # | ID | 动作 | 范围 | 禁止 |
|---|-----|------|------|------|
| **1** | **T-01 / T-03 / T-04** | **F5 补测批次** | 套装 · 技能角标 · 战斗测试模式 | 逻辑均已 YES |

**T-02c**：2c-1～2c-6 headless ✅ · **F5 YES**（D1 战略核心留营 · 半组 A 可出战）

**T-04**：04a～04d headless ✅ · **待 F5/CTO**（测试图自动 ON；工具栏「测试 OFF/ON」切换）

**T-03**：03a～03d headless ✅ · **待 F5/CTO**（法师/游侠技能角标：青=就绪 · 橙=CD 秒）

**T-06**：06a～06d headless ✅ · **F5 `test_08` CTO YES** ✅（用户确认）

### 并行（不占指针）

- F5 补测：`test_03` · `grassland` 80m · MIA `test_09` · T-01 套装穿脱

### 并行 CTO 验收（不占开发指针 · 建议半日「探针日」）

| 包 | 内容 |
|----|------|
| **环 1** | `test_03` M1 探针 1～5 + `run_probe.log` |
| **视差** | `test_01` / `test_03` 肉眼（V1～V5） |
| **大营 UI** | B1.5 零键盘 · B2 顶栏 · B3 编组卡 · B4 背包网格 |
| **MIA** | test_09 · 回收/压力/救援 F5 |
| **行军搜索** | `test_01` 每 10m 【搜索】飘字；接战期间不触发 |

### 运维

- 日常冒烟：**`test_03` + `test_01`**；不必每日全跑 MiaPhase1Probe。  
- headless 回归：`MiaPhase1Probe.tscn` → **119 PASS**（含 C1 · B3 · M2c · 02a）。

---

## 当前阶段

**Sprint 重构环 1** — **M1 / M2 / M3 ✅ CTO YES**  
**Sprint 可视化** — **T-RUN-V1～V5 ✅**；**T-MARCH M1～M3 + V1～V3 ✅**  
**Sprint 大营壳** — **T-UI-B1～B4 ✅**（逻辑 + F5 冒烟）  
**探针日** — ✅ **冒烟收盘**（2026-06-06 · 用户 F5 test_01）

- **当前**：**F5 探针日补测**（T-02c / T-03 / T-04 / T-01 逻辑均已 YES）。战斗地图见 [design-combat-stack.md](design-combat-stack.md)。

---

## 当前任务

| 项 | 值 |
|----|-----|
| **ID** | **探针日 / F5** |
| **名称** | T-01 套装 · T-03 技能角标 · T-04 测试模式 · T-02c 纯佣兵出征 |
| **状态** | 🟡 **待 F5/CTO** |
| **优先级** | P0 验收 |
| **门禁** | headless **117 PASS** ✅ · B 线 W1 收工 |

### T-02c headless 验收（2c-1～2c-6）

| 探针 | 结论 | 备注 |
|------|------|------|
| 2c-1 主角濒死·B 可出征 | ✅ PASS | 名单无主角 |
| 2c-2 A 优先·无主角 | ✅ PASS | `resolve_active_squad` |
| 2c-3 养伤锁仅佣兵 | ✅ PASS | 与主角状态无关 |
| 2c-4 纯佣兵趟结算 | ✅ PASS | 主角 HP 不变 |
| 2c-5 旧档剥离主角槽 | ✅ PASS | `ensure_formation` |
| 2c-6 养伤锁误报修复 | ✅ PASS | 主角留营·佣兵满血可出征 |
| F5 肉眼 | ⏸ 延期 | 大营编队 + 准备页文案 |

### T-04 headless 验收（04a～04d）

| 探针 | 结论 | 备注 |
|------|------|------|
| 04-1 运行时开关 | ✅ PASS | set/toggle/reset |
| 04-2 HP×5 | ✅ PASS | `apply_entity_modifiers` |
| 04-3 伤害×0.3 | ✅ PASS | `scale_damage` |
| 04-4 测试图自动开 | ✅ PASS | test_01 ON · grassland OFF |
| F5 肉眼 | ⏸ 延期 | 工具栏标签 + 切换钮 |

### T-03 headless 验收（03a～03d）

| 探针 | 结论 | 备注 |
|------|------|------|
| 03-1 精英继承 class active_skills | ✅ PASS | `mage_elite` → fireball/heal |
| 03-2 UnitView CD 角标秒数 | ✅ PASS | 例 `火4` |
| 03-3 就绪角标无数字 | ✅ PASS | 例 `疗` |
| 03-4 CD 与 skill_templates | ✅ PASS | fireball = 5s |
| F5 肉眼 | ⏸ 延期 | 与 T-01 套装等一并补测 |

### T-06 F5 验收（用户 · test_08）

| 探针 | 结论 |
|------|------|
| 觉醒名/头标刷新 | ✅ YES |
| Buff 角标 | ✅ YES |
| 06a～06d headless | ✅ PASS |

### T-02a F5 验收（2026-06-06 · 用户 test_06）

| 探针 | 结论 | 备注 |
|------|------|------|
| 2a-1 敌方优先打可战 | ✅ YES | 狼主要打术士，非一直打铁卫 |
| 2a-2 濒死不攻击/不自主移动 | ✅ YES | 铁卫濒死至压力撤离前无自主行为 |
| 2a-3 后排归位 | ✅ headless | F5 中铁卫因 **个人压力过低强制退场**（P3 机制），不否定 T-02a |
| 02a-1～3 headless | ✅ PASS | 88 PASS 全表 |

### 探针日收盘表（2026-06-06）

| 包 | F5 / 探针 | 结论 | 备注 |
|----|-----------|------|------|
| **环 1·进军** | `test_01` 接战 | ✅ YES | 停滚、战斗日志、顶栏「接战中」 |
| **MARCH·搜索** | `test_01` | ✅ YES | 行程有搜索事件；**接战期间不刷搜索** |
| **视差·冒烟** | `test_01` 接战 | ✅ YES | 色块战斗区属 ART 占位预期 |
| **大营·冒烟** | 出征壳 + 网格 | ✅ YES | 安全箱/外露/底栏 Dock 可见可用 |
| **headless** | MiaPhase1Probe | ✅ **88 PASS** | 含 FW3 + 02a |
| **环 1·追击** | `test_03` F5 | ⏸ 延期 | headless 已过；F5 待补 |
| **MARCH·采集** | `grassland` 80m | ⏸ 延期 | 未专测 |
| **MIA 全线** | `test_09` 等 | ⏸ 延期 | 逻辑探针齐 |
| **T-02a** | `test_06` 濒死 | ✅ **CTO YES** | F5 test_06 · 用户 2026-06-06 |

### 仍 OPEN（不占探针日收盘）

| ID | 名称 | 状态 |
|----|------|------|
| **T-MARCH-M1～M3 / V1～V3** | 跑图搜索与事件 | ✅ **逻辑 + F5 冒烟 YES** |
| **T-UI-B1.5～B4** | 大营壳 | ✅ **CTO YES** + F5 冒烟 |
| **T-RUN-V1～V5** | 行军视差 | ✅ **CTO YES** + test_01 冒烟 |
| **T-ART-FW-3** | art_manifest | ✅ **CTO YES** · FW3 探针 |
| **T-MIA-3～P5** | MIA 玩法 | 🟡 逻辑齐 · **F5 延期** |
| **T-02a** | 濒死站位 | ✅ **CTO YES** | F5 + 02a headless |
| **T-02e** | 测试编队 | 🟡 待验收 | test_06 自带编队 |

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

## T-UI-FORM · 双半组与备战 UI（2026-06-06 定案 · 2026-06-07 修订）

> 产品：[design-expedition-meta.md](design-expedition-meta.md) §双半组语义  
> 问题汇总：备战 UI 技术 bug + A/B 三套语义脱节（见对话归档）  
> **FORM-3 修订（2026-06-07）**：原「rebalance 先填编组优先半组」废止 → **FORM-3R「招募默认进备战席」**（设 B 优先后招募不应默认进 A 槽）。

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-UI-FORM-1** | `start_run` 不写 `active_half` | 🟡 **开发 YES · 待 CTO** | FORM-1a PASS |
| **T-UI-FORM-3R** | 招募默认进备战席（未编入） | 📋 **下一开发** | FORM-1 |
| **T-UI-FORM-2** | 手动 -7 / 自动改派 toast | 📋 待排 | FORM-1 |
| **T-UI-FORM-6** | 跨半组槽位拖拽（A 槽→B 空槽） | 📋 待排 | FORM-3R |
| **T-UI-FORM-4** | 文案 + F1/F2 语义对齐 | 🟡 **开发 YES · 待 CTO** | FORM-4a |
| **T-UI-FORM-F5** | 备战席实机验收（§九清单） | 🟡 **条件通过** | 热修暂过关；polish→FORM-7 |
| **T-UI-FORM-7** | 备战席体验优化（增量刷新等） | ⏸ 可选 | FORM-F5 + FORM-6 |
| ~~T-UI-FORM-3~~ | ~~rebalance 先填编组优先~~ | ❌ **废止** | → FORM-3R |
| ~~T-UI-FORM-5~~ | ~~备战席增量刷新 / 拖拽~~ | ❌ **并入** | → FORM-6 + FORM-7 |

### FORM-1 交付 ✅（开发自测 2026-06-07）

- `game_manager.start_run`：成功后只写 `last_deploy_half`，**不写** `squad_formation["active_half"]`
- `_begin_recovery_run`：删除覆盖 `active_half`；成功写 `last_deploy_half`
- headless **FORM-1a PASS**：`active_half=B`、实际走 A 后，`active_half` 仍为 B，`last_deploy_half=A`

### FORM-3R 交付（下一开发）

- `rebalance_from_roster`：**不再**把未编入佣兵自动写入 A/B 槽（招募、读档、开局赠兵同理）
- 新佣兵仅出现在 F2 **备战席 / 未编入**；进半组须玩家点选/拖入或「补满优先半组」（`auto_fill_half` 仍只从备战席补 **编组优先** 半组）
- **逻辑唯一入口**：`squad_formation_service.gd`
- headless **FORM-3R**：`active_half=B` + 模拟 recruit → 新 `merc_id` 不在 A/B 槽、在备战席池

**影响文件（预估）**：`squad_formation_service.gd`、`merc_recruit_service.gd`、`save_serializer.gd`、`character_create.gd`、`mia_phase1_probe.gd`

### FORM-2 交付

- 手动 `start_run`：编组优先半组 `half_can_deploy` 为 false → 返回 **-7** + `get_run_start_error_message`
- 自动连续出征路径：fallback 时 toast 一次
- **不动** `WorldRun` / 战斗

### FORM-6 交付

- F2：长按 **A 组出战槽** 佣兵 → 拖到 **B 组空槽** → A 槽空、B 槽填入（走 `formation_assign`，非静默搬人）
- 顶栏成功/失败反馈；与「A↔B 互换」并存
- **影响文件（预估）**：`formation_slot_card.gd`、`formation_ui.gd`；探针 **FORM-6a**（逻辑层跨半组 assign，可选）

### FORM-4 交付 ✅（开发自测 2026-06-07）

- 「补满优先半组」tooltip + 操作提示：不跨半组搬人，请用 A↔B 互换或拖拽
- 备战席「可编入（满足出征条件）」≠ 出战条件；名册显示 `个人稳:当前/上限`
- F1 准备页半组按钮 **★编组** = `active_half`；标签行显示「下趟出征半组」（与编组优先可不同）
- headless **FORM-4a**：B 编组优先 + 仅 A 可出战时，`get_preferred_half=B`、`resolve_deploy_half=A`

### STAB-CLASS 交付 ✅（开发自测 2026-06-07）

- `mercenary_templates.json`：`player_classes` + 各模板 `personal_stability_max`；`toughness` +10
- `Mercenary.get_personal_stability_max()`；`roster_health.recover_personal_stability` 按 per-merc 上限
- headless **STAB-CLASS-a**：战105 / 法80 / 游侠92 / 精战125；崩溃线按 max×30%

### FORM-F5 交付（条件通过 2026-06-07）

- 备战席：黑框无字 / 点击无反馈 / 拖入无效 — **热修暂过关**（`formation_pool_button` + 回血不重建池）
- §九清单：显示佣兵名、单击编入、拖入半组、× 移出回备战席 — **待 QA 全勾**
- 遗留 polish → **FORM-7**

### FORM-7 交付（可选）

- 备战席增量刷新（避免全量 destroy 按钮）
- 备战席↔半组拖放与 `ScrollContainer` 手势冲突打磨
- 卡片悬停/按下态；池子拖回备战席（若产品要）

### 禁止

- 静默从 A 槽位搬到 B（除用户拖拽/点选/A↔B 互换）
- 改 `squad_formation` 存档结构
- F1/F2 合并

---

## T-UI-TWIN · 双窗壳层（CTO 定案 2026-06-08）

> 产品：用户定案 — **计划 UI 与动画场景切成两个 OS 窗口**，非单窗 VSplit。  
> 上窗只管事；下窗只表演。数据仍走 `GameManager` Autoload，**单进程单存档**。

### 窗口分工

| 窗口 | 节点 | 尺寸（默认） | 内容 |
|------|------|--------------|------|
| **PlanningWindow** | `Main` + `MainShell` | 1280×460（min 高 360） | 顶栏 + 左（选图/策略）+ 中（**编组 ⏸**）+ 右（背包/装备）+ Dock |
| **StageWindow** | `scenes/stage_window.tscn` + `StageShell` | 1280×260 | 营火/idle/养伤动画 + **CQ 后勤建筑** + 行军/接战 + 结算动画 |

### 行为定案

1. 启动：副窗贴在主窗正下方；**拖副窗则上窗跟随**（`main.gd` 以 StageWindow 为位置锚点）。
2. 关主窗或副窗关闭请求 → `_shutdown_all_windows()` 双窗一起退出。
3. `GameManager.state_changed` → `MainShell.apply_state` + `StageShell.apply_state` 同步。
4. `RunDriver` / `main` 从 **StageShell** 取 `combat_view`、`run_march_lane`。
5. 下窗可点：**CQ 后勤建筑**（STAGE-5）；编组/背包网格 **不得** 迁入下窗（编组落点 ⏸ 待定）。

### 任务状态

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-UI-TWIN-1** | PlanningWindow + StageWindow 拆分 | 🟡 **开发交付 · 待 CTO** | T-11 壳 |
| ~~T-UI-FRAME-1~~ | 单窗上下区分离 | ❌ **并入** | → TWIN-1 |

### TWIN-1 交付（现网 2026-06-08）

- `main.gd`：`STAGE_WINDOW_SCENE`、`PLANNING_HEIGHT=460`、`STAGE_HEIGHT=260`、双窗布局同步、关窗联动
- `main_shell.gd`：去掉 `VSplit`/`RunBar`；保留 `UpperArea` + `UpperOverlayHost` + Dock
- `stage_shell.gd`（新）：迁入原 `RunBar` 子树（`StageBar`）
- `scenes/stage_window.tscn`（新）
- `formation_ui.gd`：Dock 编组可 `pulse_stage_focus` 闪副窗
- headless **TWIN-1a** + **FRAME-1a**（`mia_phase1_probe.gd`）

### 不在范围

- 双进程 / 双实例 / 双存档
- 副窗内编组槽位、背包网格
- 改 `GameManager` 四态、战斗公式

### 验收探针（TWIN-1 · CTO F5）

1. 启动见 **两个窗口**；副窗在主窗下方，宽与主窗一致。
2. 上窗：选图、编组、后勤、装备穿脱正常；**无**底栏战斗条占位。
3. 下窗：BASE 见 `BottomStage`（营火+剪影 idle）；RUNNING 行军/接战。
4. 拖动**下窗**，上窗跟随贴顶（拖上窗则下窗不跟）。
5. 关任一窗，游戏退出，无残留副窗。
6. headless **TWIN-1a** PASS；`MiaPhase1Probe` **0 FAIL**。

### 下一单（TWIN YES 后）

**T-UI-STAGE-2** — 副窗换 `camp/*` 真图 + idle 序列帧（CQ 成品观感，非色块）。

---

## T-UI-LAYOUT · 双窗功能分区（用户定案 2026-06-09）

> 详见 [design-base-ui.md](design-base-ui.md) §T-UI-LAYOUT。摘要：

| 上窗 Planning（TBH） | 下窗 Stage（CQ） |
|----------------------|------------------|
| ✅ 选图、出征策略（左 + Dock） | ✅ 营火 + idle（STAGE-2） |
| ✅ 背包、穿脱、套装（右 + 浮窗） | ✅ 后勤招募/医疗/建筑（**STAGE-5**） |
| ✅ 结算摘要（左/右） | ✅ 养伤包扎/躺卧（STAGE-3） |
| ✅ **编组方案 B：上窗简表** | ✅ 行军/接战剪影视差 |
| | ✅ **下窗点人选角**（FORM-LAYOUT-2） |
| | ✅ 抵营/清点动画（STAGE-4） |

**不做**：CQ 街景横滑；上窗 F5 大块后勤弹窗为主入口；编组/背包塞下窗（编组未决前）。

| ID | 名称 | 状态 |
|----|------|------|
| **T-UI-STAGE-5** | 下窗 CQ 后勤建筑可点 | 📋 待排（门禁 STAGE-2） |
| **T-UI-FORM-LAYOUT-1** | 中窗编组 **简表**（半组/备战行） | 📋 待排 | FORM-3R YES |
| **T-UI-FORM-LAYOUT-2** | **下窗点人** → assign/选中 | 📋 待排 | STAGE-2 + LAYOUT-1 |
| ~~T-UI-CAMP-1~~ | 中窗 CampStage 主路径 | ❌ 废止 | → FORM-LAYOUT |

---

## T-UI-STAGE · 底栏 CQ 动画舞台（CTO 定案 2026-06-08）

> 产品：挂机游戏 **主视觉在屏幕下方**（战斗/行军/大营休息/养伤休整均有动画），对齐 CQ；上区仍 THB 三窗管理。  
> **用户反馈 2026-06-08**：现网中窗 `CampStage` 占位 + 底栏仅 `StandbyLabel` 文字 → **未达标**。  
> 设计：[design-base-ui.md](design-base-ui.md) · [design-pc-shell.md](design-pc-shell.md) §九·二

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-UI-STAGE-1** | `BottomStage` 状态机（在 `StageShell`） | 🟡 **开发交付 · 待 CTO** | T-UI-TWIN-1 |
| **T-UI-STAGE-2** | 营火/队伍 **真图+序列帧**（副窗） | 📋 **E 线下一开发** | TWIN-1 YES |
| **T-UI-STAGE-3** | 养伤/休整子态 | 📋 待排 | STAGE-2 |
| **T-UI-STAGE-4** | PREPARE/RESULT 底栏预览 | 📋 待排 | STAGE-1 |

### STAGE-1 交付（预估）

- `bottom_stage.gd` + `main_shell.gd`：BASE/PREPARE/RESULT 显示 `BottomStage`；RUNNING 切 `RunMarchLane`/`CombatView`（现逻辑）
- 隐藏 BASE 时纯文字 `_standby_label`（或仅作无障碍副文案）
- 状态：`BASE_REST` / `BASE_RECOVERY` / `PREPARE_MUSTER` / `RESULT_RETURN` + 复用 RUNNING 层
- **影响文件**：`stage_shell.gd`、`bottom_stage.gd`、`mia_phase1_probe.gd`（STAGE-1a）

### STAGE-2 交付（预估）

- 营火 `VisualSlot` + 编组优先半组 `party/silhouette_*`；idle 动画（Tween 呼吸 → 后接序列帧）
- **影响文件**：`bottom_stage.gd`、`visual_constants.gd`、`art_manifest.json`

### 冻结

- 全屏 CQ 街景横滑；RUNNING 全屏盖住上区；改 `CombatController` 数值
- 用中窗 `CampStage` **代替**底栏动画（中窗仅缩略预览）

### 验收探针（STAGE-1+2 · F5）

1. BASE：底栏见 **营火+队伍剪影**（非仅「营火边陲」一行字）；剪影有 **可见 idle 动效**（STAGE-2）。
2. 点出征进 RUNNING：底栏切行军/接战（不回归纯文字）。
3. RESULT：底栏结算剪影态（可先占位）。
4. 上区三窗/Dock 操作不回归；headless **STAGE-1a** + 122 PASS。

---

## T-UI-CAMP · 中窗缩略 + 建筑图标（CTO 定案 2026-06-07 · 2026-06-08 降级）

> **2026-06-08**：CAMP 从中窗主视觉 **降为缩略预览**；主视觉改 **T-UI-STAGE** 底栏。

| ID | 名称 | 状态 | 门禁 |
|----|------|------|------|
| **T-UI-CAMP-1** | 中窗 `camp_stage.gd` 缩略横排 | 🟡 **部分交付** | — |
| **T-UI-STAGE-5** | 下窗 CQ 后勤建筑可点 | 📋 待排 | STAGE-2 |
| ~~T-UI-CAMP-2~~ | 上窗后勤 Tab | ❌ 废止 | → STAGE-5 |
| **T-UI-CAMP-4** | 美术 manifest `camp/*` | 📋 可并行 | — |
| ~~T-UI-CAMP-3~~ | ~~底栏营火~~ | ❌ 并入 | → STAGE-2 |

### CAMP-1 交付（预估）

- 中窗 `CampStage`：暖色营地背景占位 + A/B 横排立绘/剪影（数据来自现 `FormationUI` / `SquadFormationService`）
- 点横排成员 → 现选中/编入/装备链路；**不新写**编制逻辑
- **影响文件（预估）**：`formation_ui.gd`、`main_shell.gd` 或 `scenes/MainShell.tscn`、新 `camp_stage.gd`（可选）、`mia_phase1_probe.gd`（CAMP-1a 可选）

### CAMP-2 交付（预估）

- 中窗顶沿或舞台内：招募/医疗/仓库图标 → 后勤浮窗 Tab
- **影响文件（预估）**：`camp_stage.gd`、`base_ui.gd` / 后勤弹窗宿主

### CAMP-3 交付（预估）

- BASE 底栏：营火 + `party/silhouette_*`；与 `RunMarchView` 剪影 manifest 统一
- **影响文件（预估）**：`main_shell.gd`、`run_march_view.gd` 或底栏待机层

### CAMP-4 交付（预估）

- `data/art_manifest.json` 登记 `camp/bg`、`camp/bonfire`、`camp/building_*`（见 design-art-checklist §P3）
- 缺图回退色块；可与 CAMP-1 占位并行

### 冻结

- 全屏 CQ 街景 `ScrollContainer`；删 Dock/三窗；`BaseUI` 长滚复活
- `GameManager` 四态、`squad_formation` 存档、FORM 语义（除非 FORM 专 TASK）
- RUNNING 战斗数值 / `CombatController` 公式

### 验收探针（CAMP-1 · CTO F5 鼠标）

1. BASE 中窗：营地背景 + A/B 横排可见（有编组显示成员，空槽可见空位）。
2. 点横排成员 → 槽位选中或装备抽屉（与 CAMP 前一致）。
3. Dock「编组」→ 滚中窗 + 描边；选图≠出征不回归。
4. headless **CAMP-1a**（可选）+ `MiaPhase1Probe` **0 FAIL**。

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
| **T-01** | **套装 → StatResolver + UI N/M** | **P0** | ✅ **F5 YES** | 01a～01d · D1 铁卫 3/3 穿脱 |
| **T-06** | **Buff / 觉醒头标** | **P0** | ✅ **CTO YES** | 06a～06d · F5 test_08 |
| **T-02** | **远程后排调参/站位** | **P0** | ✅ **CTO YES** | 02-1～02-4 · F5 |
| **T-03** | **技能 CD + active_skills** | **P0** | ✅ **逻辑 YES** | 03a～03d · F5 延期 |
| **T-02e** | **测试图自带编队 + 平衡** | **P1** | 🟡 **待 CTO 验收**（M3 后解禁） | test_01~08 已生成 |
| **T-02a** | **濒死撤退站位 + 目标优先级** | **P0** | ✅ **CTO YES** | F5 test_06 · 2026-06-06 |
| **T-02b** | **CombatView 位置映射统一** | **P2** | ✅ **逻辑 YES** | 02b-1～02b-2 · F5 延期 |
| **T-04** | **战斗测试模式** | **P0** | ✅ **逻辑 YES** | 04a～04d · F5 延期 |
| **T-02c** | **主角独立 + 纯佣兵出征** | **P0** | ✅ **F5 YES** | 2c-1～2c-6 · D1 战略核心留营 |
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
| **T-UI-FORM-1** | **start_run 不覆盖 active_half** | **P0** | 🟡 **开发 YES · 待 CTO** | FORM-1a |
| **T-UI-FORM-3R** | **招募默认进备战席** | **P0** | 📋 **下一开发** | FORM-1 |
| **T-UI-FORM-2** | 手动 -7 / 自动改派 toast | P0 | 📋 待排 | FORM-1 |
| **T-UI-FORM-6** | 跨半组槽位拖拽 A→B | P1 | 📋 待排 | FORM-3R |
| **T-UI-FORM-4** | 编队文案 + F1 语义 | P1 | 📋 待排 | FORM-2 |
| **T-UI-FORM-F5** | 备战席实机验收 | P0 QA | 🟡 条件通过 | 热修暂过关 |
| **T-UI-FORM-7** | 备战席体验优化 | P2 | ⏸ 可选 | FORM-F5 |
| **T-UI-TWIN-1** | **PlanningWindow + StageWindow 双窗** | **P0** | 🟡 **开发交付 · 待 CTO** | T-11 |
| **T-UI-STAGE-1** | **StageShell BottomStage 状态机** | **P0** | 🟡 **开发交付 · 待 CTO** | TWIN-1 |
| **T-UI-STAGE-2** | 副窗 CQ 真图 + idle 序列帧 | **P0** | 📋 **下一开发** | TWIN YES |
| **T-UI-STAGE-3** | 养伤/休整底栏子态 | P1 | 📋 待排 | STAGE-2 |
| **T-UI-STAGE-4** | PREPARE/RESULT 底栏 | P1 | 📋 待排 | STAGE-1 |
| **T-UI-FORM-LAYOUT-1** | 中窗编组简表 | P1 | 📋 待排 | FORM-3R |
| **T-UI-FORM-LAYOUT-2** | 下窗点人选角 | P1 | 📋 待排 | STAGE-2 |
| ~~T-UI-CAMP-1~~ | 中窗 CampStage | — | ❌ 废止主路径 | → LAYOUT |
| **T-UI-STAGE-5** | **下窗 CQ 后勤建筑** | P1 | 📋 待排 | STAGE-2 |
| ~~T-UI-CAMP-2~~ | ~~上窗后勤 Tab~~ | — | ❌ 废止 | → STAGE-5 |
| **T-UI-CAMP-4** | `camp/*` 美术 manifest | P2 | 📋 可并行 | — |
| **T-MARCH-M1** | 自动搜索服务 | P1 | ✅ **已交付** | 待探针登记 |
| **T-MARCH-V1** | 搜索飘字 Toast | P1 | ✅ **已交付** | M1 |
| **T-MARCH-M2～M3 / V2～V3** | 里程碑 + 采集 + 返程池 | P1 | ✅ **CTO YES** | 77 PASS |
| **T-ART-FW-1** | 视觉常量 + VisualSlot | P1 | ✅ **CTO YES** | FW1a/b |
| **T-ART-FW-2** | 跑图五层挂 VisualSlot | P1 | ✅ **CTO YES** | FW2a～d · 83 PASS |
| **T-ART-FW-3** | art_manifest 真图 | P2 | ✅ **CTO YES** | FW3a/b · 85 PASS |
| T-06 | Buff / 觉醒头标 | P0 | ✅ **CTO YES** | 06a～06d · F5 test_08 |
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

1. 编队：使用 **测试⑥ `test_06_near_death_duo` 自带编队**（**⑥·前排铁卫 + ①·术士**，主角留营）；选图后见 `[本图编队]`。  
2. 去程或 **返程战斗** 中让 A 进入濒死（显示 `(濒死)`）。  
3. 返程战斗继续时：  
   - [x] A 的战场 position **位于友方最左/后排**（headless 02a-2；F5 可因压力退场打断观察）  
   - [x] 敌人 **优先攻击** 仍能战斗的友方，而非 A（用户 F5：主要打术士）  
   - [x] A 仍不攻击、不自主移动（至个人压力过低强制退场前）  
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

## T-01 验收探针

| ID | 断言 | headless |
|----|------|----------|
| **01a** | 铁卫 `weapon+armor`（2/3）→ `StatResolver.get_pdef` **+8** | ✅ |
| **01b** | 铁卫 3 件 → `pdef+8` 且 `max_hp+40` | ✅ |
| **01c** | `get_active_bonus_lines` 含 **`铁卫 2/3`** + **`物防+8`** | ✅ |
| **01d** | 1 件：`calc_set_bonus==0`；UI **`铁卫 1/3`** 无 tier 描述 | ✅ |
| **F5** | `EquipmentUI` 穿脱铁卫 → 文案 N/M 与 DEF/HP 同步 | 手测延期 |

---

## T-06 验收探针

| ID | 断言 | headless |
|----|------|----------|
| **06a** | 濒死 → 觉醒：`UnitView` 名称从 `(濒死)` 刷新为 `(觉醒·爆发)` | ✅ |
| **06b** | `buff_system` 有 Buff 时显示角标（攻/防等） | ✅ |
| **06c** | 觉醒头标可见 + 变体文案（如 **盾援**） | ✅ |
| **06d** | Buff 清空后角标消失 | ✅ |
| **F5** | `test_08` 觉醒触发后单位头标/名称更新；技能 Buff 战中可见角标 | ✅ YES |

**不动**：`combat_controller.gd` 伤害/选目标 · T-02a 濒死站位。

---

## T-02 验收探针

| ID | 断言 | headless |
|----|------|----------|
| **02-1** | 射程外友方远程 **前探**（不再 IDLE 站桩） | ✅ |
| **02-2** | 前探后 `find_nearest_in_range` 命中 | ✅ |
| **02-3** | 远程 `position` 始终 **< 最前近战** | ✅ |
| **02-4** | 前探不超过 `前排 - RANGED_MELEE_STANDOFF` | ✅ |
| **F5** | `test_01` 术士/游侠 `[远]` 日志 + 投射物；后排不抢前排位 | ✅ YES |

**规则（T-02）**：`_advance_ranged_ally_toward_range` — 理想位 `target.x - range`，上限 `min(前排近战) - standoff`；未改伤害公式 / T-02a 濒死。

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
