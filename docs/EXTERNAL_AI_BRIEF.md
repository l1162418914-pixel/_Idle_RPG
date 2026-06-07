# TBH Idle RPG · 项目简报（供外部 AI 评审）

> **用法**：给外部 AI 时 **整份复制本文件** 即可；细节任务板见 [PROJECT_STATUS.md](PROJECT_STATUS.md)。  
> 更新日期：2026-06-06  
> 引擎：Godot 4.2 · GDScript  
> 类型：2D 横版自动战斗 + 大营经营 + 佣兵撤退 RPG（PC 窗口，鼠标优先）

---

## 1. 一句话玩法

在大营整备 **双半组佣兵**（A/B 各 4+2），选图向深处推进里程；途中 **自动接战**（横版 CQ 式槽位战斗）；战利品进 **安全箱 + 外露网格**；团队稳定（提灯向压力）崩了或价值够了就 **返程**——返程挨打先掉外露，双池盾缓冲；Boss 可 **追击**。灭团/撤离失败可走 **MIA**（留场/回收）元进度。

**空间铁律**：左 = 大营/安全，右 = 深处/Boss。进军向右，返程向左，进军接战停滚。

---

## 2. 设计借鉴（壳子五源 v2 · 不可混用）

| 来源 | 负责什么 | 不借什么 |
|------|---------|---------|
| THB 原版 | PC 主壳：上三窗 + Dock + 底栏 | 消块、9合1 |
| Kingdom: Two Crowns | 跑图大地图：里程、视差、里程碑 | 国王走格战斗 |
| 克鲁赛德战记 CQ | 接战条：停滚、前后排、自动战斗、弹道 | 消块 |
| 提灯与地下城 | 压力/稳定：强制撤、贪险 | 重度丢光、房间探索 |
| 塔科夫/三角洲 | 安全箱 vs 外露、二维占格带货撤 | FPS 操作 |

**自研主轴**：双半组、双池盾、Boss 追击、濒死/伤痕/觉醒、跑图自动搜索与里程碑事件。

---

## 3. 技术架构（五层 · 2026-06 重构收口）

1. **数据层** — DataLoader + `data/*.json`（基本不动）
2. **领域层** — Mercenary / Squad / Equipment / StatResolver / BuffSystem
3. **远征层** — WorldRun — 行程、稳定、刷怪、追击、搜索/事件（不写战斗结局）
4. **接战层** — EncounterSession + CombatMovementPolicy + CombatController
5. **壳子层** — GameManager（四态）+ RunDriver + MainShell/UI（只发意图）

### 属性铁律

```
Mercenary(base) → 装备/被动/Buff 加成 → StatResolver → CombatStats → CombatEntity
```

- **禁止**：CombatEntity 写回 base 战斗属性；UI 手算面板；RUNNING 存档。
- **允许回写 Mercenary**：current_hp、濒死/觉醒、本趟统计、buff_system。

### 出征驱动（单循环）

```
RunDriver._process
  ├─ WorldRun.tick()        距离、稳定、刷怪、追击、MarchSearch/Event
  ├─ EncounterSession       接战类型、胜败出口、距离是否冻结
  ├─ CombatController.tick  移动策略、普攻、技能、Buff tick、濒死
  └─ run_event → RunEventPresenter → RunUI 提示
```

### 表现分层（底栏跑图）

| 层 | 主要组件 |
|----|---------|
| 世界状态 | RunMarchLane（scroll_x、party_anchor_x、停滚） |
| 视差/行军 | ParallaxBackdrop、RunMarchView |
| 搜索/事件/采集 | MarchSearchToast、MarchEventMarkers、MarchGatherView |
| 接战 | CombatView + BattlefieldSlots + UnitView |
| Boss 压力 | BossChaseSilhouette |

美术框架：`VisualSlot + art_manifest.json`（可挂真图，现网多为色块占位）。

---

## 4. 游戏状态机

```
BASE → PREPARE → RUNNING → RESULT → BASE
```

奖励只在 `return_to_base / apply_run_rewards` 进大营。  
结算分档：`success | mia | manual | recovery` 等（T-MIA）。

---

## 5. 核心机制清单（实现状态概览）

| 机制 | 要点 | 实现度 |
|------|------|--------|
| 距离推进 | max_distance、boss_distance、extract | ✅ |
| 稳定/压力 | 团队≤30 强制撤、个人崩溃 | ✅ |
| 接战自动战斗 | 近战前压、远程站桩、弹道 | ✅（远程大调参 T-02 已封/跳过） |
| 返程双池盾 | 装备盾 + 物资盾、盾破掉外露 | ✅ |
| 网格带货 | 安全箱绝对带出、外露可丢 | ✅ UI（T-05） |
| Boss 追击 | 压力、反击、蓄力击退、接战冻结距离 | ✅（环1 F5 test_03 延期） |
| 濒死/觉醒 | DOWNED、后排归位(T-02a)、觉醒变体 | ✅ 逻辑 + T-06 头标 |
| 技能/CD | active_skills、CD 角标 | ✅ T-03 逻辑 · F5 延期 |
| Buff | BuffSystem → StatResolver → UnitView 角标 | ✅ T-06 |
| 套装 | 进 StatResolver + UI N/M | ✅ T-01 逻辑 · F5 延期 |
| 跑图搜索 | 每 Δm 被动检定 | ✅ M1 |
| 里程碑事件/采集 | JSON 事件表、GATHER_BEAT 短演出 | ✅ M2/M3 + V2/V3 |
| MIA/回收/救援 | run_mode、冻结经验、救援队等 | 🟡 逻辑齐 · F5 延期 |
| 研究所/转生/云存档 | — | 🔒 冻结 |

---

## 6. 代码体量（约 101 个 .gd 脚本）

核心目录：

- `scripts/core/` — GameManager、DataLoader、SaveSerializer、SaveManager
- `scripts/run/` — WorldRun、RunDriver、Encounter*、\*Service（刷怪/追击/护盾/MIA/搜索事件）
- `scripts/combat/` — CombatController、CombatEntity、MovementPolicy、SkillExecutor、Projectile
- `scripts/ui/` — MainShell、RunUI、CombatView、UnitView、行军/事件表现、大营 UI
- `scripts/mercenary/`、`equipment/`、`stats/`、`buff/`、`inventory/`
- `data/*.json` — 地图、敌人、技能、掉落、事件、测试编队等
- `tools/mia_phase1_probe.gd` — headless 回归（**115 PASS**）

入口：`main.gd` 薄壳 → RunDriver；大营 MainShell 四态布局。

---

## 7. 开发进度（2026-06-06 CTO 板）

### ✅ 已完成（逻辑层可依赖）

| 轨道 | 内容 |
|------|------|
| T-REFACTOR M1～M3 | 接战门禁、SaveSerializer、WorldRun 调度化、Combat 拆分 |
| T-11a/b | PC 主壳三窗 + Dock + 底栏 |
| T-05 | 出征安全箱/外露网格 UI |
| T-RUN-V1～V5 | 行军视差、接战锚点、返程同向、Boss 剪影 |
| T-UI-B1～B4 | 地图卡、Dock 鼠标优先、顶栏稳定、编组卡、大营背包预览 |
| T-MARCH M1～M3 + V1～V3 | 自动搜索、里程碑事件、采集短演出、返程事件池 |
| T-ART-FW-1～3 | 视觉常量、VisualSlot、art_manifest |
| T-MIA 0～2 | 存档协议、is_mia、灭团→MIA |
| T-02a | 濒死不被优先打、拖后排 |
| T-01 | 套装进 StatResolver |
| T-06 | Buff/觉醒头标（headless + 用户 F5 test_08 ✅） |
| T-03 | 技能 CD + active_skills + 角标（headless ✅） |
| T-04 | 战斗测试模式（headless ✅） |
| T-02c | 主角留营 / 纯佣兵出征（headless ✅） |

### 🟡 当前指针

**开发排期**：见 [PROJECT_STATUS.md](PROJECT_STATUS.md) §**开发工作安排**（A 验收 / B 程序 / C 内容）。

**F5 探针日补测**（逻辑均已 YES，待肉眼/CTO）：

| ID | 内容 |
|----|------|
| T-01 | 套装穿脱与面板 N/M |
| T-03 | 技能角标（青=就绪 · 橙=CD 秒） |
| T-04 | 测试图自动 ON + 工具栏测试开关 |
| T-02c | 纯佣兵出征、主角留营、养伤锁不误报 |

### ⏸ 排队 / 冻结

| ID | 内容 | 状态 |
|----|------|------|
| T-02 | 远程后排大改 | 已封/让位 |
| T-02b | CombatView 像素统一 | P2 |
| T-07～T-10 | 研究所、转生、多槽、云存档 | 冻结 |
| — | 街景/CQ 大营美术 | 后期 |

### ⏸ F5 延期（逻辑已过 headless）

- test_03 Boss 追击肉眼
- grassland 80m 里程碑采集
- MIA 全线 test_09 等

---

## 8. 测试体系

- **日常冒烟**：test_03 + test_01
- **headless**：`godot --headless --scene res://tools/MiaPhase1Probe.tscn` → **115 PASS**
- **环 1 探针**：test_03 无小怪插队、首领接战距离冻结、CombatController 无 boss_chase 字符串等
- **运行时日志**：`run_probe.log`（接战/冻结/搜索等）
- **测试图**：test_01～test_09 + `data/test_map_rosters.json` 自带编队

---

## 9. 已知痛点 / 未决问题（欢迎外部 AI 给意见）

1. **战斗专题**：T-02～T-04 顺序刚收口；是否缺一份独立的 `design-combat-stack.md`（接战类型表 + tick 顺序）？
2. **表现 vs 逻辑**：大量色块占位；manifest 已就绪，美术未批量填入。
3. **UI 审计文**（`UI_SUBSYSTEM_AUDIT.md`）部分条目已过时（如觉醒头标已修）。
4. **MIA 元玩法**：逻辑探针齐，F5 与产品语气未全验收。
5. **跑图事件**：机制已上线，内容与数值池仍薄。
6. **git**：曾有多批量本地改动未 push 的情况；协作需分批 commit。
7. **产品方向**：局外成长 `design-meta-base.md` 仍为占位；研究所/转生冻结中。

---

## 10. 文档索引（仓库内）

| 文档 | 用途 |
|------|------|
| `docs/GAME_BIBLE.md` | 产品总纲、五源分工 |
| `docs/ARCHITECTURE.md` | 架构铁律 |
| `docs/PROJECT_STATUS.md` | 任务板、探针、当前指针 |
| `docs/design-march-visual.md` | 跑图/接战表现 |
| `docs/design-march-events.md` | 搜索与里程碑事件 |
| `docs/design-failure-lineage.md` | MIA/失败线 |
| `docs/design-near-death.md` | 濒死/觉醒 |
| `docs/design-retreat.md` | 返程/网格/护盾 |
| `docs/TEST_SCENARIOS.md` | QA 测试图说明 |

---

## 11. 可复制给对方的「请帮我想」提示语

> 你是游戏架构/玩法顾问。上面是 Godot 项目 TBH Idle RPG 的简报。  
> 请基于简报（不要假设我们有手游 UI 或消块战斗）回答：  
> 1. 五层架构 + CQ/KTC/提灯/塔科夫 分工是否合理？有无明显耦合风险？  
> 2. 当前进度下，T-04 战斗测试模式是否值得先做？还是应优先 MIA F5 / 跑图内容填充？  
> 3. 战斗子系统（Encounter → Policy → Controller → View）还缺什么「理清楚」的文档或边界？  
> 4. 跑图（搜索+事件+采集）与接战主轴会不会抢玩家注意力？如何调节奏？  
> 5. 给独立开发者团队：接下来 2 周最稳的 3 个优先级是什么？  
> 请具体、可执行；指出风险时说明触发场景。
