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
  "cloud_reserved": {},
  "squad_stability": 100
}
```

读档时 `squad_stability` 仅作 **兼容旧档**；写入时与 `team_stability` 相同。新档请以 `team_stability` 为准。

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
| `cloud_reserved` | object | 云存档预留，当前恒为 `{}` |

### 不写入存档（运行时）

| 状态 | 说明 |
|------|------|
| `auto_run_enabled` | 读档后恒为 `false`；仅当次勾选「自动连续」有效 |
| `auto_retreat_value_enabled` | 智能撤离开关，默认 `true`，未持久化 |
| `auto_retreat_safe_only` | 智能撤离仅计安全箱，默认 `false`，未持久化 |
| `current_run` / 出征中网格战利品 | 出征进行中 **不可存档**；关游戏时 `RUNNING` 会 `abort_run_to_base` |
| `pending` 结算 | `RESULT` 态未领奖励在 `return_to_base` 时写入；直接关窗会走 `persist_on_shutdown` 领奖 |

允许存档的游戏状态：`BASE`、`PREPARE`（`is_save_allowed()`）。

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

读档流程要点：`_sanitize_active_skills` → `_restore_active_skills_if_missing` → `EquipmentSystem.apply_to` → `clamp_hp_to_max`。

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

## 版本与兼容

| `header.version` | 说明 |
|------------------|------|
| `0` / 缺失 | 按当前逻辑加载，字段缺失用默认值 |
| `1` | 当前格式 |
| `> SAVE_VERSION` | 加载时警告，可能不兼容 |

旧档中已删除的 final 战斗属性、无效技能 id 不会导致读档失败；缺失编队时会重建默认双半组结构。

---

## 相关文档

- [MAP_UNLOCK.md](MAP_UNLOCK.md) — 解锁条件与推进链  
- [design-expedition-meta.md](design-expedition-meta.md) — 编队、再战、养伤锁  
- [design-near-death.md](design-near-death.md) — 濒死、伤痕、觉醒（伤痕层数存档）  
- [design-retreat.md](design-retreat.md) — 返程护盾 CD（存在装备 `shield_cd_runs_left`）
