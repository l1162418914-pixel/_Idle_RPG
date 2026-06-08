# 压力机制 · 物资丢失 — 设计血统说明

> **用途**：PM / 开发 / Bug 会话固定参考。  
> **壳子 v2**（[GAME_BIBLE.md](GAME_BIBLE.md) §五）：**压力 → 提灯向**；**箱/外露/返程掉物 → 塔科夫/三角洲向**；DD **已移出**壳子参考。  
> **状态**：稳定度核心已实现（机制目标向提灯调优）；掉物见 [design-loot-lineage.md](design-loot-lineage.md)。  
> **关联**：[design-retreat.md](design-retreat.md)、[TEST_SCENARIOS.md](TEST_SCENARIOS.md) ①。

---

## 一、总览：两层灵感（v2）

```
┌─────────────────────────────────────────────────────────────┐
│  提灯与地下城（压力机制 · 目标气质）                          │
│  远征风险、稳定消耗、贪险、≤30 强制撤、撤离 vs 灭团           │
└──────────────────────────┬──────────────────────────────────┘
                           │  同一趟 Run
┌──────────────────────────▼──────────────────────────────────┐
│  塔科夫 / 三角洲（物资层）                                    │
│  安全箱带出 · 外露可丢 · 返程盾破抽外露 · 带货撤             │
└─────────────────────────────────────────────────────────────┘
```

**现网说明**：`StabilitySystem` 实现期曾接近 DD 式「团队+个人稳定」结构；**数值与文案调优以提灯远征为准**，非 DD 城镇压力模拟。

**不借**：提灯重度丢光；塔科夫 FPS；KTC 掉金币走格。

---

## 二、提灯与地下城 → 团队/个人稳定（压力）

### 2.1 提灯在做什么（气质目标）

| 提灯机制 | 玩家感受 |
|----------|----------|
| 远征不确定性 | 越深越怕，怕的不是单战而是 **整趟回不来** |
| 风险决策 | 贪一波 vs 见好就收 |
| 失败代价 | 灭团/撤离失败沉重，但可有 **安全区** 减损 |

### 2.2 TBH 定稿（差异表）

| 维度 | 提灯 | TBH |
|------|------|-----|
| 计量 | 士气/风险（抽象） | **团队稳定度** + **个人稳定度**（0–100） |
| 作用域 | 整趟地下城远征 | **整趟 WorldRun**（进军 + 返程 + 接战） |
| 崩溃线 | 灭团/紧急撤 | 团队 ≤30 → `forced_withdraw`；个人 ≤30 → `personal_break` |
| 持续压力 | 探索、遭遇 | `tick` 衰减 + 受击 `on_ally_hit` + 低血/低个人放大 |
| 与物资 | 丢装备恐怖 | **箱内相对安全**（塔科夫层）；外露 + 返程掉物 |
| 回城 | 大营整备 | 基地慢回稳定；养伤锁；比提灯 **略轻** |
| 通关 | — | 通关地图额外扣稳定（长线压力） |

### 2.3 数值锚点（现网 · T-STAB-POOL + STAB-CLASS）

| 常量 / 字段 | 值 / 含义 | 文件 |
|-------------|-----------|------|
| `MAX_STABILITY` | 100（默认个人上限基准） | `stability_system.gd` |
| `BREAK_THRESHOLD_RATIO` | 0.30（团队强制返程 & 个人崩溃线） | 同上 |
| 团队强制返程 | `floor(team_stability_max × 0.30)`（本趟动态上限） | `StabilitySystem.get_run_withdraw_threshold()` |
| 个人崩溃线 | `floor(该佣兵 personal_max × 0.30)` | `Mercenary.get_personal_break_threshold()` |
| 职业个人上限 | 战士 110 · 法师 80 · 游侠 95（模板可覆盖） | `mercenary_templates.json` |
| `toughness` 被动 | 个人上限 +10 | `Mercenary.get_personal_stability_max()` |
| 半组 `half_sum` | `Σ 出战4槽 personal`；替补不计 | `squad_formation_service.gd` |
| 本趟 `team_stability` | 实时 = 在编个人稳之和 | `stability_system.gd` |
| `CASCADE_DEPLETION_RATIO` | 0.10（个人耗尽牵连队友） | 同上 |
| `APPLY_PERSONAL_LOSS_ON_HIT` | true（受击扣个人再同步团队条） | 同上 |
| 替补上阵 | 压力换人 / `try_bench_reinforcements` → `on_field_roster_changed` | `pressure_outcome_service.gd` |
| `TEAM_HIT_SHARE` | 0.45 | `stability_system.gd` |
| `HIT_STABILITY_SCALE` | 10（按伤害占 max_hp 比例） | 同上 |
| `on_member_down` | 团队 -15 | 同上 |
| `on_boss_killed` | 团队 +20 | 同上 |
| 根存档 `team_stability` | 废弃写入；UI 读编组半组聚合 | `save_serializer.gd` / `game_manager.gd` |
| 伤疤 | `get_scar_stability_loss_mult()` 放大个人/团队损失 | `Mercenary` + `on_ally_hit` |

### 2.4 信号与流程

```
战斗受击 → combat_controller 结算伤害
         → 若未 absorbed by shield 且 run.stability 存在
         → stability.on_ally_hit(damage, victim)

团队稳定 ≤30 → forced_withdraw
             → main / world_run → begin_retreat("forced")
             → 优先 extract_distance，再走返程掉物规则
```

### 2.5 验收 / 测试

- 测试图：`test_01_stability_retreat`（[TEST_SCENARIOS.md](TEST_SCENARIOS.md)）
- 观察：顶栏/Run 条稳定度、强制返程文案、`retreat_reason == "forced"`

### 2.6 可选增强（未排期）

- 稳定 **档位事件**（文案、微行为），不只阈值扣数
- 大营 **建筑** 对应团队恢复 vs 个人恢复（现偏统一 `team_stability` + 名册慢回）

---

## 三、塔科夫 / 三角洲 → 返程受击掉物

> 完整对照：[design-loot-lineage.md](design-loot-lineage.md)

### 3.1 撤离类在做什么

| 机制 | 玩家感受 |
|------|----------|
| 保险箱 vs 背包 | 箱里才是「真自己的」 |
| 路上交战 | 丢的是 **非保险箱** |
| 撤离成功 | 结算进仓库 |

### 3.2 TBH 定稿（差异表）

| 维度 | 塔科夫/三角洲 | TBH |
|------|---------------|-----|
| 丢什么 | 背包、胸挂内物品 | **外露格** 整件装备 |
| 何时丢 | 交战、撤失败 | **返程** + **双池盾皆破** 后概率抽外露 |
| 保护 | 保险箱 | **安全箱** + 装备盾/物资盾 |
| 主动弃货 | 丢包跑路 | `manual` 斩仓舍弃外露 |
| 概率 | 战局规则 | `retreat_hit_drop_chance` 按图配置 |

### 3.3 流程锚点

```
返程中受击 → apply_retreat_hit_damage（world_run）
            → 若 shield > 0：扣盾，emit retreat_shield_hit
            → 若盾破：try_drop_loot_on_retreat_hit
            → rand < retreat_hit_drop_chance
            → exposed_loot.remove_random_equipment()
            → emit loot_lost_on_retreat
```

### 3.4 关键文件

| 文件 | 职责 |
|------|------|
| `world_run.gd` | `try_drop_loot_on_retreat_hit`、`apply_retreat_hit`、双池盾 |
| `data/map_templates.json` | 每图 `retreat_hit_drop_chance` |
| `design-retreat.md` §四 | 安全箱 / 外露 / 掉装定稿 |

### 3.5 可选增强（未排期）

- 掉物 **可见反馈**（物品飞出外露格 / 日志外轻量动效）
- 离大营越近 `retreat_hit_drop_chance` 递减（「快到家了」）

---

## 四、两层如何同时作用（玩家视角）

| 阶段 | 压力（提灯线） | 物资（塔科夫/三角洲线） |
|------|----------------|-------------------------|
| 进军 | 衰减 + 接战受击扣分 | 一般不丢外露 |
| 稳定 ≤30 | 强制返程 | 返程开始，双池盾满 |
| 返程 | 仍可能因濒死等再扣 | 挨打先扣盾，盾破概率丢外露 |
| 抵营 | 团队稳定慢回；个人养 | 箱内 + 幸存外露进结算 |

**文案气质**：提灯式「撤成功 vs 灭团」+ 塔科夫式「外露不算稳」。

---

## 五、开发约束（勿破坏血统）

1. **稳定度**：战斗层只 **通知** `StabilitySystem`；不在 `CombatView` 改数值。
2. **掉物**：仅 **外露**；安全箱、已结算进背包的不可被 `retreat_hit` 抽走。
3. **有盾必不掉**：`is_retreat_shield_active()` 为 true 时 `try_drop_loot_on_retreat_hit` 早退。
4. **进军接战停距离、返程接战边撤边走**：与稳定/掉物独立；见 [design-march-visual.md](design-march-visual.md)。

---

## 六、相关文档

| 文档 | 内容 |
|------|------|
| [design-retreat.md](design-retreat.md) | 返程 reason、双池盾、网格、撤离点 |
| [design-near-death.md](design-near-death.md) | 濒死、伤痕对稳定损失倍率 |
| [design-expedition-meta.md](design-expedition-meta.md) | 养伤锁、再战、团队稳定跨趟 |
| [design-pc-shell.md](design-pc-shell.md) | 底栏稳定/价值条、设计来源表 |
