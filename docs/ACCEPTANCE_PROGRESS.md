# 测试验收进度（B 机勾选）

对照 [TEST_SCENARIOS.md](TEST_SCENARIOS.md)。测完一项改 `[ ]` → `[x]`，收工与 worklog 一起 commit。

| 序 | 内容 | 状态 | 备注 / commit |
|----|------|------|----------------|
| — | 编队 UI（大营双半组） | [ ] | 拖放、右键清空、养伤锁 |
| ① | `retreat_drill` 稳定度返程 | [ ] | |
| ② | `test_extract` 撤离物线 | [ ] | |
| ③ | `test_boss_chase` Boss追击 | [ ] | 勿杀区域首领、深度反击≠通关 |
| ④ | `test_auto_value` 价值撤离 | [ ] | 阈值 140 |
| ④b | `test_loot_full` 网格满撤 | [ ] | 阈值 9999，靠格子满 |
| ⑤ | `test_near_death_solo` | [ ] | |
| ⑥ | `test_near_death_duo` | [ ] | |
| ⑦ | `test_awakening` | [ ] | |

## 记录模板（异常时）

- 地图：
- 现象：
- 期望（手册）：
- `git log -1 --oneline`：
