# 存档格式说明（A3 属性重构后）

## 当前版本会保存

- 身份：`merc_id`, `merc_name`, `merc_class`, `level`, `exp`, `template_id`
- 状态：`current_hp`, `is_alive`, `is_retreated`, `is_personal_break`, `personal_stability`, `attack_range`, `attack_speed`（基础值，非 final）
- 构筑：`equipment_slots`, `passive_skills`, `active_skills`, `buffs`, `growth_per_level`

## 不再保存（旧档中的多余字段会被忽略）

`hp`, `max_hp`, `patk`, `matk`, `pdef`, `mdef`, `spd`, `crit_chance` 等 **最终战斗属性**。

读档后通过 `refresh_base_stats()` + `StatResolver` 重算。

## active_skills 迁移

- 无效 ID（如旧示例 `盾击`）会在读档时剔除
- 若列表为空，则按模板 / 职业自动恢复（如 `fireball`, `taunt`）

## 稳定度（双轨）

### 团队稳定度 `team_stability`

- 存档字段：`team_stability`（旧档 `squad_stability` 兼容读取）
- 出征继承；探索衰减、通关扣除、阵亡/撤离惩罚、受击分摊（约 45%）影响团队条
- ≤30 强制全队撤离；回城后缓慢恢复

### 个人稳定度 `personal_stability`（每名角色）

- 受击时该角色全额扣除
- ≤30 时佣兵自动撤离当次队伍（主角不离队，但会拖累团队压力倍率）
- 回城后与生命一起在医疗室缓慢恢复；恢复至 >30 且解除 `is_personal_break` 后可再出征

## 地图解锁

- 默认解锁：`grassland`, `death_trial`（绝境试炼，用于死亡流程测试）
- 其余地图按建筑总等级与 `unlock_base_level` 自动解锁
