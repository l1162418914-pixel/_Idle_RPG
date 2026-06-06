# 失败掉人 · CTO 实现对照稿

> **用途**：给 CTO 评审「能不能做、先改什么、和现网冲突在哪」。  
> **玩法全文**：[design-failure-lineage.md](design-failure-lineage.md)（已定案，含救援队 §5.7）  
> **铁律**：[ARCHITECTURE.md](ARCHITECTURE.md)、[SAVE_FORMAT.md](SAVE_FORMAT.md)

---

## 一、一句话

把现网 **「灭团 = 永久死亡」** 改成 **「重大失败 = MIA → 主城多档回收」**；濒死扩成 **HP/压力二段式死亡**；新增 **救援队第三队（避战、重罚）** 与 **A/B 互捞（轻罚）** 并行。主角 **永不 MIA**，死亡走 **强制回城动画**。

---

## 二、定案摘要（给 CTO 扫读）

### 2.1 局内

| 主题 | 定案 |
|------|------|
| 濒死 | HP **或** 压力清零 → 锁 **1 HP + 1 压力 + 濒死护盾** |
| 死亡 | 濒死态 **护盾破 + HP 再清零** → 佣兵进 **MIA**（非 `mark_permanent_death`） |
| 抵营 | 全员濒死仍算 **完整探险过闸**，仅养伤锁 |
| 战场灭团 | 上过场者 **全员 MIA**（不分比例） |
| 撤离失败 | 团队压力撤离后 **未抵营** → 按濒死比例 **B-3a/b**（压力计入完好度） |
| 压力收场 | 单人：替补换人+3-2-3；团队：轻判→**撤离事件** |
| 手动斩仓 | **不进 MIA**；短程减轻惩罚 |
| 主角 | **永不 MIA**；佣兵全死立刻回城 / 有佣兵则随撤离成败同步回城 |

### 2.2 出 MIA（主城）

| 通道 | 要点 |
|------|------|
| **A/B 战斗短 Run**（轻罚） | 低难、可战；成功：25% 经验 + 部分遗物 + 濒死回营；失败：捞人队不留 MIA + **卷轴** |
| **救援队**（重罚） | 第三队、避战；只运尸体→**停尸间**；无 B-6 经验；地图点随清；失败：**养伤 CD**、无卷轴 |
| **读条一键** | 低价；卷轴减价 |
| **大价值复活** | 随时可用、最贵 |
| **放弃搜寻** | 唯一 **`mark_permanent_death`** |
| **拖捞恶化** | 过补给点计趟；1 趟遗物 50–70%、2 趟 20–30%；2 趟后地图点消失，主城仍可复活 |
| **回档** | v1 不做；以后研究所/道具 |

---

## 三、目标状态 vs 现网（核心差异）

```
【现网】
  HP→0 → is_near_death
  灭团 → mark_permanent_death()     # main.gd _mark_squad_wiped
  结算 → total_exp 全队平分入账     # GameManager._apply_run_exp
  编制 → 双半组 A/B only

【目标】
  HP/压力→0 → 濒死(1+1+护盾) → 护盾破+HP0 → is_mia
  灭团 → enter_mia_state()（上场者）
  MIA → 冻结经验(按人数比) / 回收成功 25% / 放弃才永久没
  编制 → A/B + 救援队(第三队) + 停尸间
```

---

## 四、与现网代码冲突矩阵

| 严重度 | 定案需求 | 现网行为 | 主要落点 |
|--------|----------|----------|----------|
| 🔴 **高** | 灭团 → MIA，非永久没 | `_mark_squad_wiped` → 全员 `mark_permanent_death` | `scripts/main.gd` L616–620 |
| 🔴 **高** | 新增 `is_mia` 状态 | 仅有 `is_near_death` / `is_alive` | `mercenary.gd`；`SAVE_FORMAT` 无字段 |
| 🔴 **高** | 死亡二段式（护盾→MIA） | HP→0 即濒死，无二段死亡 | `combat_controller.gd`、`mercenary.enter_near_death_state` |
| 🔴 **高** | 压力 = 副生命值 | 稳定度在 `StabilitySystem`，**个人压力**未接濒死 | `world_run.gd`、`stability_system`（待扩） |
| 🔴 **高** | 经验冻结 + 25% 取回 | `total_exp_earned` 结算时 **全额** `_apply_run_exp` 给参战者 | `game_manager.gd` L426–432、569+ |
| 🔴 **高** | 救援队第三队 | 仅 **双半组 A/B**（`SquadFormationService`） | `squad_formation_service.gd`、`SAVE_FORMAT` |
| 🟠 **中** | 回收 Run / 避战路径 | 仅标准 `WorldRun` + `begin_retreat` | 新 `run_type` 或 `WorldRun` 模式旗标 |
| 🟠 **中** | A/B 互捞自动带回收目标 | 无「下趟强制/默认回收」 | `GameManager.start_run`、出征 UI |
| 🟠 **中** | 主城三路回收 UI | 无回收建筑/停尸间/卷轴 | `base_ui` / 新 `recovery_ui` |
| 🟠 **中** | 团队压力 → 撤离事件 → 比例 MIA | 有 `forced` 返程，**无**撤离失败后 MIA 分支 | `world_run.end_run`、`main.gd` 结算 |
| 🟠 **中** | 主角强制回城、永不 MIA | 主角与佣兵同濒死逻辑（`player.gd` 注释写撤离失败可永久阵亡） | `player.gd`、`main.gd` 结算 |
| 🟠 **中** | 替补濒死/压力换人、3-2-3 | 编队在 `SquadFormationService`；**战中动态换人**未实现 | `combat_controller`、编队服务 |
| 🟡 **低** | 手动斩仓不进 MIA | `manual_withdraw` 已存在，走 `end_run` 战败档 | 需确认结算不触发 MIA |
| 🟡 **低** | 返程护盾、掉外露 | 已实现双池盾 | `design-retreat.md` 一致 |
| 🟡 **低** | 养伤锁 70% | 已实现 `can_join_squad` / `is_recovery_lock_active` | 与 L1 一致；**养伤 CD**（救援队失败）需新字段 |

### 4.1 不冲突 / 可复用

- `BASE→PREPARE→RUNNING→RESULT` 状态机（`GameManager`）
- `_pending_run_result` → `apply_run_rewards` 单向结算（ARCHITECTURE §二）
- 安全箱 / 外露（`RunLootService`、出征网格）
- 濒死、伤痕、搀扶、觉醒（`design-near-death.md`）— 需 **扩展** 非推翻
- 双半组存档 `squad_formation`（扩展第三队 / MIA 列表即可）

### 4.2 与 ARCHITECTURE 铁律

| 检查 | 结论 |
|------|------|
| CombatEntity 不写 base 战斗属性 | ✅ 新状态只写 `is_mia`、停尸标记、养伤 CD，合规 |
| 奖励只经 `apply_run_rewards` | ⚠️ 须扩 `result` 字典（`mia_freeze_exp`、`recovery_exp`），**不可** UI 直发经验 |
| RUNNING 不存档 | ⚠️ MIA 批次、地图遗物点须 **抵营/abort 时** 写入 `GameManager` 或 BASE 存档 |
| StatResolver 唯一 final | ✅ 无冲突 |

---

## 五、建议实现分期（供排 TASK）

### Phase 0 · 文档 / 协议（1–2d）

- [ ] `SAVE_FORMAT`：`Mercenary.is_mia`；根字段 `account_meta`、`rescue_squad`
- [ ] `WorldRun.RunMode`：`NORMAL` | `RECOVERY` | `RESCUE`（后两者 Phase 2/4）
- [ ] `result.settlement_tier`：`success` | `mia` | `manual` | `recovery`
- [ ] 与 [design-near-death.md](design-near-death.md) 联修：二段死亡、压力进濒死

### Phase 1 · MIA 最小闭环（CTO 第一刀已定）

- [ ] `Mercenary.is_mia` + `enter_mia_state()` / 清 MIA / `can_join_squad` 拦截
- [ ] **`_mark_squad_wiped` → `enter_mia_state`**（停用灭团即 `mark_permanent_death`）
- [ ] `end_run`：MIA 时写 **`account_meta.frozen_exp_pools`**（按 MIA 人数比）
- [ ] 主城 **回收 UI 占位**：大价值复活 + 放弃搜寻（放弃仍 `mark_permanent_death`）
- [ ] 名册 `[遗留]` 显示

### Phase 2 · 回收出征（轻罚）

- [ ] `WorldRun.run_mode = RECOVERY`：短里程、低难、抵点即胜
- [ ] B-10：A/B 下趟可选/默认回收目标
- [ ] 回收成功：25% 经验、部分遗物、清 MIA
- [ ] 回收失败：捞人队濒死+卷轴（绑批消耗品）

### Phase 3 · 压力 / 撤离 / 死亡二段

- [ ] 濒死护盾 + 二段死亡
- [ ] 个人/团队压力收场、撤离事件
- [ ] 撤离失败 → B-3a/b 比例 MIA
- [ ] 主角强制回城动画分支
- [ ] 补给点 + 恶化计趟（B-11）

### Phase 4 · 救援队（重罚）

- [ ] **`rescue_squad`** 编制 + 解锁建筑；`WorldRun.run_mode = RESCUE`
- [ ] 避战路径 AI / 节点权重
- [ ] 停尸间 + 医疗复活链
- [ ] 救援等级 + 救援声望
- [ ] 救援队失败 → 养伤 CD

---

## 六、新增系统清单（CTO 估模块）

| 模块 | 职责 |
|------|------|
| `MiaService` / `RecoveryService` | MIA 批次、地图点、恶化计趟、回收结算 |
| `RunSettlementService` | 过闸 / MIA / 手动斩仓 / 回收 分档 |
| `ExpPoolService` | 冻结、按人数比、25% 取回、救援额外经验 |
| `RescueSquadService` | 第三队编制、避战 Run、停尸间 |
| `NearDeathV2` | 1+1+护盾、二段死亡、压力清零 |
| 主城 `RecoveryUI` | 短 Run / 一键 / 大价值 / 放弃 / 停尸间 |

---

## 七、仍 open（不挡 Phase 1–2 开工）

| 项 | 状态 |
|----|------|
| 停尸间 TTL | 暂不设定 |
| 大价值/一键具体资源价 | 数值表 |
| 压力轻判定 / 二次判定公式 | 与 Stability 联调 |
| 50–70% / 20–30% 随机粒度 | 按件或按批 |
| 补给点地图配置 | KTC TASK |
| 天赋/科技例外带货 | Meta 后续 |
| 本趟快照回档 | v1 不做 |

---

## 八、CTO 工程定案（2026-06-05）

| # | 议题 | **定案** | 实现提示 |
|---|------|----------|----------|
| 1 | MIA 数据放哪 | **`Mercenary.is_mia`**（每人字段 + 存档序列化） | `mercenary.gd`；`_serialize_merc`；`can_join_squad()` 拦截 |
| 2 | 回收 Run 形态 | **`WorldRun` + `run_mode` 枚举**（如 `NORMAL` / `RECOVERY` / `RESCUE`） | 不新场景；`main.gd` 驱动不变 |
| 3 | 第三队存档 | **新根字段**（建议 `rescue_squad`），**不**扩 `squad_formation` | `GameManager.to_save_dict`；与 A/B 半组并列 |
| 4 | 经验冻结 | **账号 `account_meta`**（槽位级 meta，非 `_pending_run_result`） | 新结构如 `frozen_exp_pools[]`；回收成功再解冻入账 |
| 5 | Phase 1 第一刀 | **是** — `_mark_squad_wiped` → **`enter_mia_state`**，不再灭团即 `mark_permanent_death` | `main.gd` L616–620 |

### 8.1 Phase 0 存档草案（随 TASK 写入 SAVE_FORMAT）

```json
{
  "account_meta": {
    "frozen_exp_pools": [
      { "run_id": "...", "total": 1200, "mia_ratio": 0.5, "map_id": "grassland" }
    ],
    "rescue_rank": 0,
    "rescue_reputation": 0
  },
  "rescue_squad": { "active": [], "bench": [] },
  "roster": {
    "normal": [{ "...", "is_mia": false }]
  }
}
```

`mia_batch_id` 等批次元数据：Phase 1 可先用 **同行 `is_mia` + 地图点列表**；若多人同批需同步，再在 `account_meta` 补 `mia_batches`（可选 Phase 2）。

---

## 八-A、CTO 方向评审结论（2026-06-05）

**有条件 YES — Phase 1 可开工**

| 条件 | 要求 |
|------|------|
| 先文档日 | `SAVE_FORMAT` + `ARCHITECTURE` 字段补丁；可无玩法代码、单独合入 → **T-MIA-0D** |
| P1 范围锁 | 仅：`is_mia`、灭团→MIA、`settlement_tier`、冻经验跳过入账、放弃搜寻/大价值占位 UI、`[遗留]` |
| P1 禁止混入 | 救援队、压力二段、互捞短 Run、停尸间 |
| 手动斩仓 | `manual_withdraw` **不触发 MIA**（`settlement_tier=manual`） |
| 主角 | 永不 `enter_mia_state`；回城动画可 P3 |
| 总验收 | §PROJECT_STATUS **Phase 1 端到端回归** R1–R7 |

**方向**：YES — 与猎杀/鸭科夫合体、返程/网格/双半组可复用；救援队与压力 V2 为增量，不与 P1 绑同一 TASK。

---

## 八-B、原评审问题（已闭合）

~~1. Phase 1 先改灭团？~~ → **是**  
~~2. is_mia 放 Mercenary 还是批次表？~~ → **Mercenary**  
~~3. 回收 Run 形态？~~ → **WorldRun 模式**  
~~4. 第三队存档键？~~ → **新字段 `rescue_squad`**  
~~5. 经验冻结写哪？~~ → **`account_meta`**

---

## 九、相关文档

| 文档 | 关系 |
|------|------|
| [design-failure-lineage.md](design-failure-lineage.md) | 玩法定案全文 |
| [design-near-death.md](design-near-death.md) | 濒死 / 伤痕（需 V2 扩展） |
| [design-retreat.md](design-retreat.md) | 返程 / 护盾（撤离事件改版） |
| [design-meta-base.md](design-meta-base.md) §3.5–3.7 | 经验闸、失败掉人 |
| [design-expedition-meta.md](design-expedition-meta.md) | 双半组、养伤锁 |
| [PROJECT_STATUS.md](PROJECT_STATUS.md) | 排 TASK |

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-05 | 初稿：CTO 对照 + 冲突矩阵 + 分期 |
| 2026-06-05 | **CTO 工程定案 §八**：is_mia@Mercenary；WorldRun 模式；rescue_squad；account_meta 冻结；灭团→MIA |
| 2026-06-05 | **TASK**：PROJECT_STATUS §T-MIA · T-MIA-0～4 + P2～P4 |
