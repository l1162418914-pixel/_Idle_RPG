# 存档格式说明

本文档与 `scripts/core/game_manager.gd`（`to_save_dict` / `from_save_dict`）及 `scripts/core/save_manager.gd` 一致。实现变更时请同步更新本文档。

## 文件位置与封装

| 项目 | 说明 |
|------|------|
| 槽位文件 | `user://save_slot_{1..3}.json` |
| 元数据 | `user://save_meta.json`（当前槽位、总游玩秒数、各槽摘要） |
| 备份 | 同路径 `.bak`，写入前覆盖旧档 |
| 编码 | 默认 **XOR + Base64**（密钥见 `SaveManager.ENC_KEY`）；若文件已是明文 JSON 也可读取 |
| 版本号 | `header.version`，当前 `SaveManager.SAVE_VERSION = 1` |

### 根对象结构

```json
{
  "header": {
    "version": 1,
    "timestamp": "2026-06-04T12:00:00",
    "play_time_seconds": 3600
  },
  "gold": 1000,
  "player": { },
  "roster": { "elite": [], "normal": [] },
  "inventory": [],
  "buildings": { },
  "team_stability": 100,
  "unlocked_maps": ["grassland"],
  "defeated_map_bosses": [],
  "squad_formation": { },
  "last_deploy_half": "A",
  "last_run_squad_snapshot": [],
  "selected_map_id": "grassland",
  "auto_run_preferred": false,
  "rebirth_count": 0,
  "rebirth_bonus": 0.0,
  "account_meta": {
    "frozen_exp_pools": [],
    "morgue_queue": [],
    "return_scrolls": [],
    "mutual_recovery_auto": true,
    "mia_last_deploy_half": "",
    "rescue_unlocked": false,
    "rescue_rank": 0,
    "rescue_reputation": 0
  },
  "rescue_squad": {
    "active": [],
    "bench": []
  },
  "cloud_reserved": {},
  "squad_stability": 100
}
```

读档时 `squad_stability` 仅作 **兼容旧档**；写入时与 `team_stability` 相同。新档请以 `team_stability` 为准。

> **T-MIA Phase 0（文档定案）**：`account_meta`、`rescue_squad`、`Mercenary.is_mia` 见下文；玩法实现见 [PROJECT_STATUS.md](PROJECT_STATUS.md) §T-MIA、`T-MIA-0` 起。草案对照 [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) §8.1。

---

## 全局字段（`GameManager.to_save_dict`）

| 字段 | 类型 | 说明 |
|------|------|------|
| `gold` | int | 大营金币 |
| `team_stability` | int | 团队稳定度 0~100（出征可继承） |
| `rebirth_count` | int | 转生次数（预留） |
| `rebirth_bonus` | float | 转生加成（预留） |
| `unlocked_maps` | string[] | 已解锁可出征的 `map_id` 列表 |
| `defeated_map_bosses` | string[] | 已击败区域 Boss 的地图 id（用于解锁下一图） |
| `selected_map_id` | string | 上次选择/出征的地图 |
| `auto_run_preferred` | bool | 大营「自动连续出征」勾选偏好 |
| `buildings` | object | 建筑 id → `{ "building_id", "level" }` |
| `inventory` | array | 大营背包装备，见下文 |
| `player` | object | 主角，见「佣兵对象」 |
| `roster.elite` | array | 精英佣兵列表 |
| `roster.normal` | array | 普通佣兵列表 |
| `squad_formation` | object | 双半组编队，见下文 |
| `last_deploy_half` | string | 上一趟出征半组 `"A"` / `"B"` |
| `last_run_squad_snapshot` | string[] | 自动再战 / `redeploy_same_map` 用的出战 id 快照 |
| `account_meta` | object | 槽位级账号 meta（非 `_pending_run_result`），见下文 |
| `rescue_squad` | object | 救援队编组占位（与 `squad_formation` 并列，**不**扩双半组），见下文 |
| `cloud_reserved` | object | 云存档预留，当前恒为 `{}` |

### 不写入存档（运行时）

| 状态 | 说明 |
|------|------|
| `auto_run_enabled` | 读档后恒为 `false`；仅当次勾选「自动连续」有效 |
| `auto_retreat_value_enabled` | 智能撤离开关，默认 `true`，未持久化 |
| `auto_retreat_safe_only` | 智能撤离仅计安全箱，默认 `false`，未持久化 |
| `current_run` / 出征中网格战利品 | 出征进行中 **不可存档**；关游戏时 `RUNNING` 会 `abort_run_to_base` |
| `pending` 结算 | `RESULT` 态未领奖励在 `return_to_base` 时写入；直接关窗会走 `persist_on_shutdown` 领奖 |
| `_pending_run_result` | 本趟结算字典，**不**写入槽位根存档；见「结算字段 `settlement_tier`」 |
| `settlement_tier` | 仅存在于 `_pending_run_result`，`end_run` 写入、`return_to_base` 消费后丢弃 |

允许存档的游戏状态：`BASE`、`PREPARE`（`is_save_allowed()`）。

---

## 账号 meta `account_meta`（T-MIA · 槽位级）

与 `gold` / `roster` 同级，由 `GameManager.to_save_dict` / `from_save_dict` 读写（**T-MIA-0** 起实现桩）。

```json
{
  "frozen_exp_pools": [
    {
      "run_id": "uuid-or-timestamp",
      "total": 1200,
      "mia_ratio": 0.5,
      "map_id": "grassland",
      "mia_count": 2,
      "field_count": 4,
      "timestamp": 1717654321,
      "member_ids": ["merc_id_a", "merc_id_b"]
    }
  ],
  "morgue_queue": [],
  "return_scrolls": [],
  "mutual_recovery_auto": true,
  "mia_last_deploy_half": "",
  "rescue_unlocked": false,
  "rescue_rank": 0,
  "rescue_reputation": 0
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `frozen_exp_pools` | array | MIA 结算时冻结的经验池；回收成功后再解冻入账（**T-MIA-3** / **T-MIA-P2**） |
| `frozen_exp_pools[].run_id` | string | 关联出征批次 id（实现可先用时间戳或 run 实例 id） |
| `frozen_exp_pools[].total` | int | 本批拟冻结经验总量 |
| `frozen_exp_pools[].mia_ratio` | float | MIA 人数占比 0~1，用于拆分冻结量 |
| `frozen_exp_pools[].map_id` | string | 出征地图 id |
| `frozen_exp_pools[].mia_count` | int | 本批 MIA 人数（拆分/展示用，**T-MIA-3**） |
| `frozen_exp_pools[].field_count` | int | 本趟上场人数（冻结比例分母） |
| `frozen_exp_pools[].timestamp` | int | 写入时间戳（展示/排序） |
| `frozen_exp_pools[].member_ids` | string[] | 本池关联佣兵 id；回收/放弃时按人 prune |
| `morgue_queue` | array | 停尸间待医疗队列（**T-MIA-P4**）；元素 `{ merc_id, map_id, admitted_at }` |
| `return_scrolls` | array | 回城卷轴绑定批（**T-MIA-P5**）；元素 `{ merc_id, batch_id, granted_at }` |
| `mutual_recovery_auto` | bool | A/B 互捞短程回收是否自动劫持 `start_run`（**B-10**） |
| `mia_last_deploy_half` | string | 最近一次 MIA 结算记录的出征半组 `"A"` / `"B"` / `""` |
| `rescue_unlocked` | bool | 救援队是否解锁（与 `rescue_station` 建筑等级同步，**B-12**） |
| `rescue_rank` | int | 救援队等级占位（**T-MIA-P4** 接） |
| `rescue_reputation` | int | 救援队声望占位（**T-MIA-P4** 接） |

- 经验冻结 **不得** 写入 `_pending_run_result` 后长期滞留；入账/解冻须经 `apply_run_rewards` 或回收 Run 专用 API。
- `mia_batches` 等同批元数据：**Phase 1 可选**；缺省时以各佣兵 `is_mia` + 地图点列表为准（见 CTO §8.1 说明）。

---

## 救援队编组 `rescue_squad`（占位）

与 `squad_formation`（A/B 双半组）**并列**的新根字段；**不**向 `squad_formation` 扩槽。

```json
{
  "active": ["merc_id_01", "merc_id_02"],
  "bench": []
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `active` | string[] | 救援队出战 merc_id 列表（**T-MIA-P4** 实装） |
| `bench` | string[] | 救援队替补 id 列表 |

Phase 0～1 可为空结构；读档缺键见「版本与兼容 · T-MIA 旧档」。

---

## 双半组编队 `squad_formation`

```json
{
  "active_half": "A",
  "A": {
    "active": ["player_01", "elite_01", "…最多 4 个出战 id"],
    "bench": ["…最多 2 个替补 id，可空位省略"]
  },
  "B": {
    "active": [],
    "bench": []
  }
}
```

- 同一名佣兵 **不能** 同时出现在 A、B 两半组。
- 主角必须在某一侧的 `active` 中，且 **不能** 在 `bench`。
- 读档后调用 `SquadFormationService.ensure_formation` + `rebalance_from_roster`，将未编入名册的佣兵补进空槽。

相关逻辑见 [design-expedition-meta.md](design-expedition-meta.md)。

---

## 佣兵对象（`player` / `roster.*[]`）

### 会保存

| 字段 | 类型 | 说明 |
|------|------|------|
| `merc_id` | string | 唯一 id |
| `merc_name` | string | 显示名 |
| `merc_type` | int | 枚举 `Mercenary.MercType` |
| `merc_class` | string | 职业 id |
| `template_id` | string | 模板 id |
| `level` | int | 等级 |
| `exp` | int | 经验 |
| `max_level` | int | 等级上限 |
| `current_hp` | int | 当前生命 |
| `is_alive` | bool | 是否存活（永久死亡为 false） |
| `is_mia` | bool | **失踪（MIA）**；`true` 时不可编入出征（`can_join_squad` 拦截，**T-MIA-1**）；**非** final 战斗属性 |
| `is_near_death` | bool | 濒死标记（回城 ≥70% max 可清） |
| `scar_stacks` | int | 伤痕层数（医疗室金币清除） |
| `is_retreated` | bool | 当次出征中是否已撤离 |
| `is_personal_break` | bool | 个人稳定度崩溃休整 |
| `personal_stability` | int | 个人稳定度 0~100 |
| `attack_range` | float | 基础攻击距离（非 final） |
| `attack_speed` | float | 基础攻速（非 final） |
| `equipment_slots` | object | 槽位名 → 装备 dict 或 `null` |
| `passive_skills` | string[] | 被动技能 id |
| `active_skills` | string[] | 主动技能 id |
| `growth_per_level` | object | 每级成长键值 |
| `buffs` | array | `BuffSystem.to_dict_array()` |

### 主角额外 `player_extra`（仅 `player`）

| 字段 | 说明 |
|------|------|
| `base_exp_multiplier` | 主角经验比例 |
| `squad_stability_influence` | 团队稳定度衰减减免 |
| `owned_elite_ids` | 历史拥有精英 id（展示/兼容） |
| `owned_normal_ids` | 历史拥有普通佣兵 id |

### 不保存（读档重算或仅本趟）

| 字段 | 处理 |
|------|------|
| `hp`, `max_hp`, `patk`, `matk`, `pdef`, `mdef`, `spd`, `crit_chance` 等 | **旧档忽略**；`refresh_base_stats()` + `StatResolver` + 装备重算 |
| `run_awaken_used`, `is_awakening`, `supported_by_id` | 仅本趟 `WorldRun` |
| `run_kills`, `run_damage_dealt` | 仅本趟统计 |
| `is_mia` 的 final 衍生属性 | **禁止**；MIA 仅布尔标记 + 名册/编队拦截，不持久化 `patk`/`max_hp` 等 |

读档流程要点：`_sanitize_active_skills` → `_restore_active_skills_if_missing` → `EquipmentSystem.apply_to` → `clamp_hp_to_max`。

**MIA 与 `is_alive`：** Phase 1 定案为佣兵进入 `is_mia=true` 时 **不** 等同 `is_alive=false`（非永久死亡档）；主角 **永不** 写入 `is_mia`（CTO §八-A）。具体 `enter_mia_state` 见 **T-MIA-2**。

---

## 装备 `inventory[]` / `equipment_slots.*`

每件装备为 `Equipment.to_dict()`：

| 字段 | 说明 |
|------|------|
| `item_id` | 实例 id |
| `item_name` | 名称 |
| `slot` | 装备部位 |
| `quality` / `quality_name` | 品质 |
| `prefix_name` | 词缀名 |
| `set_id` | 套装 id（可空） |
| `grid_w` / `grid_h` | 出征网格占格（大营背包可忽略） |
| `shield_cd_runs_left` | 返程护盾 CD 剩余出征次数（计入装备层） |
| `stats` | 属性字典（如 `patk`, `hp` 等） |

---

## 建筑 `buildings`

示例：

```json
{
  "barracks": { "building_id": "barracks", "level": 2 },
  "infirmary": { "building_id": "infirmary", "level": 1 },
  "forge": { "building_id": "forge", "level": 1 }
}
```

- **医疗室等级** 影响大营回血速度、伤痕治疗金币、安全箱格数（`safe_box_w/h` 效果表）。
- 基地总等级 = 各建筑 `level` 之和，用于 [MAP_UNLOCK.md](MAP_UNLOCK.md) 中的 `unlock_base_level`。

---

## 地图解锁

| 字段 | 说明 |
|------|------|
| `unlocked_maps` | 当前可进入的地图 id |
| `defeated_map_bosses` | 已击杀区域 Boss 的地图（含追击击杀等同 `boss_defeated` 的纪录） |

读档 / 热更新地图表后会执行 `sync_always_unlocked_maps()`：所有 `map_templates.json` 里 `always_unlocked: true` 的地图（草原、测试图、演练场等）并入 `unlocked_maps`。

**新游戏默认**（`reset_game_state`）：仅 `grassland` 在列表中，随后 `sync_always_unlocked_maps` 补全常开图。

击败 Boss 推进链见 [MAP_UNLOCK.md](MAP_UNLOCK.md)。

---

## 稳定度（双轨）

### 团队 `team_stability`

- 存档字段：`team_stability`（兼容读取 `squad_stability`）
- 出征继承；探索衰减、通关扣除、受击分摊、追击压力等影响
- ≤30 触发强制返程（本趟不中断行程）
- 回城后随时间恢复

### 个人 `personal_stability`（每名佣兵）

- 随佣兵对象保存
- 受击时该角色额外扣除；≤30 可触发 `is_personal_break` / 当次撤离
- 回城后与生命一起在医疗室恢复

---

## `active_skills` 迁移

- 无效技能 id 读档时剔除
- 若列表为空，按 `template_id` / 职业模板 / `player_classes` 恢复默认主动技

---

## 元数据 `save_meta.json`

| 字段 | 说明 |
|------|------|
| `last_slot` | 上次使用的槽位 1~3 |
| `play_time_seconds` | 累计游玩时间（与槽位 header 同步更新） |
| `slots` | 各槽 `timestamp` / `version` / `play_time` 摘要 |

---

## `WorldRun.RunMode`（运行时 · 非根存档）

`WorldRun` 实例字段，**不**写入槽位根 JSON；出征时由 `RunModeService.apply_for_departure` 设置。

| 枚举值 | 含义 |
|--------|------|
| `NORMAL` | 默认；现网正常远征 |
| `RECOVERY` | 短程回收 Run（**T-MIA-P2**） |
| `RESCUE` | 救援队避战 Run（**T-MIA-P4**） |

新构造 `WorldRun` 默认 `NORMAL`；`NORMAL` 出征行为与 MIA 前一致。

---

## 结算字段 `settlement_tier`（运行时 · 非根存档）

`GameManager.end_run()` 写入 **`_pending_run_result`**（`RESULT` 态展示与 `return_to_base` → `apply_run_rewards` 消费）。**不**作为槽位根 JSON 持久化字段。

| 值 | 含义 | 典型触发（实现 TASK） |
|----|------|----------------------|
| `success` | 成功结算档 | Boss 讨伐、宝库守卫、追击击杀等现网成功路径（**默认**） |
| `mia` | MIA 结算档 | 灭团 → `enter_mia_state`（**T-MIA-2/3**）；冻结经验、不全额入账 |
| `manual` | 手动斩仓 | `manual_withdraw`（**B-8**）；**不**触发 MIA、**不** `enter_mia_state` |
| `recovery` | 回收 Run 结算 | `WorldRun.run_mode=RECOVERY` 短 Run 回收成功（**T-MIA-P2**） |
| `recovery_fail` | 回收 Run 失败 | RECOVERY 途中灭团/失败；不发 MIA、捞人队濒死（**T-MIA-P2**） |
| `rescue` | 救援队成功 | `WorldRun.run_mode=RESCUE` 抵点成功（**T-MIA-P4**） |
| `rescue_fail` | 救援队失败 | RESCUE 途中失败；养伤 CD、原 MIA 仍在（**T-MIA-P4**） |

读档或新游戏 **无** `_pending_run_result`；缺 `settlement_tier` 时按现网逻辑视为无待领结算，**不**触发 MIA 分支。

---

## 版本与兼容

| `header.version` | 说明 |
|------------------|------|
| `0` / 缺失 | 按当前逻辑加载，字段缺失用默认值 |
| `1` | 当前格式 |
| `> SAVE_VERSION` | 加载时警告，可能不兼容 |

旧档中已删除的 final 战斗属性、无效技能 id 不会导致读档失败；缺失编队时会重建默认双半组结构。

### T-MIA 旧档兼容（缺键默认）

| 缺省键 | 读档默认 | 行为 |
|--------|----------|------|
| `account_meta` | `{}` | 不报错 |
| `account_meta.frozen_exp_pools` | `[]` | 无冻结经验 |
| `account_meta.morgue_queue` | `[]` | 无停尸间队列 |
| `account_meta.return_scrolls` | `[]` | 无回城卷轴 |
| `account_meta.mutual_recovery_auto` | `true` | 互捞默认开启 |
| `account_meta.mia_last_deploy_half` | `""` | 无半组记录 |
| `account_meta.rescue_unlocked` | `false` | 救援队未解锁 |
| `account_meta.rescue_rank` | `0` | 占位 |
| `account_meta.rescue_reputation` | `0` | 占位 |
| `rescue_squad` | `{ "active": [], "bench": [] }` | 无第三队 |
| 佣兵 `is_mia` | `false` | 不拦截编组、不显示 `[遗留]` |
| `_pending_run_result.settlement_tier` | （无 pending） | 不触发 MIA 结算逻辑 |

**原则：** 缺键 **仅补默认**，读档 **不得** 因缺 `is_mia` / `account_meta` 自动将佣兵标为 MIA 或写入 `frozen_exp_pools`。

---

## 相关文档

- [MAP_UNLOCK.md](MAP_UNLOCK.md) — 解锁条件与推进链  
- [design-expedition-meta.md](design-expedition-meta.md) — 编队、再战、养伤锁  
- [design-near-death.md](design-near-death.md) — 濒死、伤痕、觉醒（伤痕层数存档）  
- [design-retreat.md](design-retreat.md) — 返程护盾 CD（存在装备 `shield_cd_runs_left`）
- [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) — MIA 工程定案 §八、§8.1
- [design-failure-lineage.md](design-failure-lineage.md) — 失败掉人玩法定案
