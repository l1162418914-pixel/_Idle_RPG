# 地图解锁规则

## 解锁条件（同时满足）

1. **基地总等级** = 所有建筑等级之和 ≥ `unlock_base_level`
2. **前置 Boss**：若配置了 `unlock_after_boss_on_map`，需曾击败该地图的 Boss

`always_unlocked: true` 的地图（草原）无视上述条件。

## 推进链

| 地图 | 基地等级 | 前置 Boss |
|------|----------|-----------|
| 草原·外围 | 1 | — |
| 密林·深处 | 3 | 草原 Boss |
| 暗影洞穴 | 5 | 密林 Boss |
| 绝境试炼 | 1 | 洞穴 Boss |

## 存档字段

- `unlocked_maps`：已解锁可出征列表
- `defeated_map_bosses`：已击败 Boss 的地图 id

字段含义、双半组编队、佣兵伤痕/濒死等完整说明见 [SAVE_FORMAT.md](SAVE_FORMAT.md)。

击败 Boss 后会在结算页显示新解锁地图，回基地后可在「出征地图」列表进入。

`always_unlocked: true` 的地图（含测试图、`retreat_drill` 等）在读档或刷新解锁时会自动并入 `unlocked_maps`。

## 撤离物线（草原 / 密林 / 洞穴）

三张正式图均已配置：

- `extract_distance`：首段返程目标（撤离点）
- `extract_drop_chance`：击杀小怪概率掉落撤离物（进安全箱/外露格）
- `extract_guard`：拾取后按 `retreat_chance` 可能触发的守卫战
- `auto_carry_value_threshold`：携带价值智能撤离阈值（密林/洞穴更高）
- 密林/洞穴另有专属撤离物条目，见 `data/extract_items.json` 的 `maps` 字段
