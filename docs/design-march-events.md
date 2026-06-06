# 跑图 · 自动搜索与事件（草案）

> **状态：讨论定案（机制方向）— 未排 TASK**  
> **前置**：T-RUN-V2 底栏跑图可见（[design-march-visual.md](design-march-visual.md)）；事件逻辑不依赖美术成品。  
> **总纲**：[GAME_BIBLE.md](GAME_BIBLE.md) · 强化 **C 远征**，不替代接战主轴。

---

## 一、为什么要做

现网 `WorldRun.tick` 在**非接战**行军期 mostly：

- `distance_traveled` ±
- `spawn_timer` → **只有战斗**（`enemy_spawn`）
- 稳定衰减、智能撤离、返程/Boss 追击

**行军缝太大**：CQ 底栏在跑，玩家却长时间「等下一战」。  
**目标**：行军期自动产出 **情报/物资/风险/抉择**，让跑图本身有玩法，而不是空驶。

---

## 二、与壳子五源 v2 的关系

| 源 | 跑图 / 事件借什么 | 不借什么 |
|----|-------------------|----------|
| **KTC** | **大地图里程碑**、领地推进感、路旁「可搜」点位 | 国王走格、金币 UI |
| **CQ** | 接战前停滚；事件不替代战斗条逻辑 | 消块、手动走位 |
| **提灯** | 事件风险、稳定±、贪险文案 | 重度丢光、房间探索 UI |
| **塔科夫/三角洲** | 事件掉落进 **箱/外露** 规则 | FPS 搜刮操作 |
| **THB** | log / 右窗网格反馈 | — |

**自研主轴**：事件作用于 **里程、压力、箱/外露、撤离线**。

---

## 三、两层结构（定案方向）

### 3.1 自动搜索（Auto Search）— 背景层

**定义**：队伍在行军时 **持续被动检定**，玩家无按钮；结果以飘字/log/右窗增量呈现。

| 项目 | 建议 |
|------|------|
| 触发 | 每前进 Δ米（如 8–15m）或每 N 秒行军时间，掷 **搜索池** |
| 进军 / 返程 | 分池或同池不同权重（返程偏险、损稳定、催掉物压力） |
| 接战 / 停滚 | **暂停**搜索 tick（与 CQ 停滚一致） |
| 典型结果 | 小额金币/材料、情报（下一战预览）、+1 稳定（罕见）、空 |

**节奏**：高频、低幅度，填缝不抢戏。

### 3.2 跑图事件（March Events）— 离散层

**定义**：到达 **里程碑** 或搜索池 **稀有命中** 时，触发一条 **事件卡**（自动结算为主，少数二选一）。

| 类型 | 示例 | 与现系统 |
|------|------|----------|
| **物资** | 遗弃补给、破损军械 | → `GridInventory` / `material_dropped` |
| **风险** | 陷阱、瘴气 | → 稳定↓、小额 HP（或下战 debuff） |
| **机遇** | 捷径（+距离）、哨站（稳定↑） | → `distance_traveled` / `StabilitySystem` |
| **遭遇** | 精英先兆、宝库守卫预告 | → 下一 `spawn` 换表或 `extract` 线 |
| **叙事** | 一行文案 + 数值 | → `run_event` only |

**默认**：**自动结算**（挂机友好）；后期可对「高危/高收益」加二次确认。

---

## 四、架构边界（必须遵守 ARCHITECTURE §三）

```
WorldRun.tick()
    ├─ 现有：移动、刷怪、稳定、返程、追击
    └─ 新增：MarchSearchService.tick() / MarchEventService.tick()
              └─ emit run_event("march_search_hit" | "march_event", data)
main.gd._on_world_run_event → RunUI / RunMarchView 文案
```

| 必须 | 禁止 |
|------|------|
| 逻辑在 `WorldRun` 或独立 `RefCounted` 服务 | `CombatView` 改事件结果 |
| 配置在 `data/march_events.json` + 地图引用 | 硬编码事件奖励 |
| 发 `run_event` 或写入 `tick` 的 `events[]` | UI 内 `WorldRun.tick()` |
| 接战时 `_in_combat` 冻结搜索/里程碑 | 进军接战时偷偷加距离 |

**与战斗关系**：

- **战斗事件**（`enemy_spawn`）— 保持现链路。
- **非战斗事件**— 不启动 `CombatController`；极少数可「强制接战」作为事件效果。

---

## 五、数据草案

### 5.1 地图挂钩

```json
{
  "march_search": {
    "interval_m": 12,
    "pool_id": "grassland_search"
  },
  "march_events": [
    { "at_distance": 80, "event_id": "abandoned_crate" },
    { "at_distance": 200, "event_id": "fog_patch" }
  ]
}
```

### 5.2 事件表（全局）

```json
{
  "event_id": "abandoned_crate",
  "weight": 0,
  "auto": true,
  "effects": [
    { "type": "loot_material", "table": "march_misc", "rolls": 1 },
    { "type": "stability", "team": -2 }
  ],
  "log": "路旁遗弃箱，快速搜刮。"
}
```

效果类型（首期建议）：`gold` / `loot_material` / `loot_equip` / `stability` / `distance` / `spawn_next` / `log_only`。

---

## 六、UI / 表现（跑图壳子）

| 元素 | 行为 |
|------|------|
| Run 左 log | `【搜索】…` / `【事件】…`（与战斗 log 分区色） |
| RunMarchView | 里程碑小图标闪过（V2 后）；无美术时仅 log |
| 右网格 | 获得物即时入箱/外露规则与战斗掉落相同 |
| 接战 | 停滚；事件/搜索暂停 |

---

## 七、与返程 / 稳定的耦合

| 场景 | 规则 |
|------|------|
| 进军 | 搜索偏奖励；事件可贪（多外露压力） |
| 返程 | 搜索提高「险」权重；与 KTC 慌叠加 |
| 稳定 ≤50 | 事件池增负面权重（提灯气质，数值轻） |
| 盾破后 | 不再触发 **正面物资事件**（可选） |

---

## 八、分期建议（供 CTO 拆 TASK）

| 阶段 | 交付 | 依赖 |
|------|------|------|
| **M1** | `MarchSearchService` + 1 张测试图搜索池 + log | WorldRun 挂钩 |
| **M2** | 距离里程碑 `march_events` + JSON 表 | M1 |
| **M3** | 返程分池 + 稳定加权 | M2 |
| **M4** | RunMarchView 事件点表现 | T-RUN-V2 |

**不与 T-RUN-V1** 混：V1 只做状态机；搜索/事件单开 **T-MARCH-***。

---

## 九、明确不做（首期）

- 大段分支剧情树、多屏对话
- 玩家手动控队形搜点（KTC 走格）
- 事件直接改 `Mercenary` base 属性
- 取代战斗作为主内容（战斗仍是高潮）

---

## 十、验收探针（草案）

1. 进军非接战：每 ~12m 可见搜索 log，偶尔掉材料。  
2. 接战期间：搜索/里程碑 **不触发**。  
3. 里程碑 80m：触发配置事件，右窗或 log 可见结果。  
4. 返程：搜索池负面占比高于进军。  
5. `CombatView` / 伤害公式 diff 为空。
