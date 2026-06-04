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

击败 Boss 后会在结算页显示新解锁地图，回基地后可在「出征地图」列表进入。
