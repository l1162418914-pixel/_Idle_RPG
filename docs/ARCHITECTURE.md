# ARCHITECTURE.md

> **本文仅列架构铁律**（必须 / 禁止 / 单向数据流）。  
> **开工前先读** [PROJECT_STATUS.md](PROJECT_STATUS.md)（任务板、冻结项、当前 TASK）。  
> 实现细节、排期、审计见 [UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md)、[SAVE_FORMAT.md](SAVE_FORMAT.md)。

---

## 一、属性流

```
Mercenary（base：模板 + 等级成长）
    ↓ refresh_base_stats()
EquipmentSystem.calc_equipment_bonus()   ← 只产出加成项，不写 final
SkillSystem.get_passive_bonus()
BuffSystem.get_bonus()
    ↓
StatResolver（唯一 final 计算入口）
    ↓
CombatStats（只读快照）
    ↓
CombatEntity（战斗副本）
```

### 必须

- 面板、战斗、UI 查询 **最终战斗属性** → 只经 `StatResolver`（或 `CombatEntity.recalc_from_merc()` 间接调用）。
- `Mercenary` 上的 `hp/patk/pdef/...` 字段语义为 **base**，不含装备/Buff/套装 final 结果。
- 装备穿脱后调用 `EquipmentSystem.apply_to(merc)` → 仅 `refresh_base_stats()`，不直接改战斗 final。
- **`Mercenary.is_mia`**（T-MIA）：仅为名册/编队/结算 **状态标记**；进入或清除 MIA **不得** 写入或持久化 `patk`/`max_hp`/`pdef` 等 final 战斗属性（与下文 §七 一致）。

### 禁止

- **CombatEntity 写回 Mercenary 的 base/final 战斗属性**（`patk`、`pdef`、`attack_range` 等 StatResolver 产出项）。
- **EquipmentSystem 修改或持久化 final 属性**（只提供 `calc_equipment_bonus`）。
- **存档保存 final 属性**（`patk`/`pdef`/`crit_chance` 等读档后由 `refresh_base_stats` + `StatResolver` 重算；见 SAVE_FORMAT「不保存」表）。
- 在 UI、`CombatController`、建筑逻辑中 **手算** `base + 装备` 替代 `StatResolver`。

### 允许（本趟运行时回写）

战斗结束或同步时，`CombatEntity` → `Mercenary` **仅可**写：

- `current_hp`、`is_alive`、`is_near_death`、觉醒相关字段
- 本趟统计：`run_kills`、`run_damage_dealt`
- Buff 由技能写入 `merc.buff_system`，经 `recalc_from_merc()` 反映到 `CombatEntity`

---

## 二、游戏状态机

```
BASE → PREPARE → RUNNING → RESULT → BASE
```

### 必须

- 状态切换由 **`GameManager`** 统一持有；UI 只发意图（按钮/信号），不私自改 `state`。
- 出征生命周期：`start_run()` → `WorldRun` + `RUNNING` → `end_run()` 写 `_pending_run_result` → `return_to_base()` 时 **`apply_run_rewards()`** 发放金币/经验/掉落。
- **`_pending_run_result.settlement_tier`**（T-MIA）：`end_run` 写入的运行时结算分档（`success` | `mia` | `manual` | `recovery`）；**不**写入槽位根存档；`apply_run_rewards` 按 tier 分支（如 `mia` 冻结经验、`manual` 不触发 MIA）。

### 禁止

- **`RUNNING` 期间存档**（`is_save_allowed()` 仅 `BASE` / `PREPARE`）。
- UI 或子系统 **绕过 `GameManager` 直接改金币**（须 `add_gold` / `apply_run_rewards` / 明确的经济 API）。
- 在 `RESULT` 之前把大营背包掉落 **提前写入** `InventorySystem`（结算前奖励只存在于 `_pending_run_result` / 出征网格）。

---

## 三、出征与战斗分层

```
main.gd（唯一驱动循环）
    ├─ WorldRun.tick()          行程、稳定度、撤离、追击
    └─ CombatController.tick()  接战时的横版战斗
```

### 必须

- **`WorldRun.run_event`** 由 `main.gd._on_world_run_event` 集中消费 → 再转 `RunUI` 提示；子系统只 `emit`，不直接操作 UI 节点。
- **`CombatController` 信号** → `CombatView` 做可视化；`CombatView` **不接** `run_event`。
- 战斗逻辑只改 `CombatEntity`；**禁止** `CombatView` / `UnitView` 修改伤害、冷却、胜负。

### 禁止

- UI 层调用 `WorldRun.tick()` 或 `CombatController.tick()`（仅 `main.gd` 在 `_process` 驱动）。
- 在 `CombatView` 内实现命中、闪避、技能效果（属 `CombatController` / `CombatEntity` 职责）。

---

## 四、背包与战利品

| 容器 | 作用域 | 铁律 |
|------|--------|------|
| `InventorySystem` | 大营 | 容量受 `GameManager.get_inventory_capacity()` 约束；`add()` 满仓失败 |
| `GridInventory` | 单次出征 | 二维占格；装备 + 材料 + 撤离物字典项 |

### 禁止

- 出征中网格战利品 **直接 merge 进大营 `InventorySystem`**（须经结算 `apply_run_rewards`）。
- `GridInventory` 与 `InventorySystem` **共用同一数组引用**。

---

## 五、数据与配置

### 必须

- 静态配置只读 **`DataLoader`**（`data/*.json`）；运行时 **不修改** JSON 源文件。
- 数值表、模板、地图、技能定义以 JSON 为单一数据源；代码侧只做解释与聚合。

### 禁止

- 在业务脚本中 **硬编码** 可配置数值以替代 JSON（测试常量 `BattleDebug` 除外，且不得进存档逻辑）。
- 各模块各自 `load("res://data/...")` 绕过 `DataLoader`（新增配置须走 DataLoader API）。

---

## 六、全局类与循环依赖

### 必须

- `RunExtractItem`：**仅数据**（`@export` / 字段），无工厂、无 `WorldRun` 引用。
- 撤离物生成、掉落逻辑在 **`ExtractItemService`**（**无 `class_name`**）；调用方用 **`load()` 运行时加载**，避免与 `WorldRun` 的 `preload` 环。

### 禁止

- 在 `class_name` 脚本同文件内 **自引用** `preload(自身)`、`-> 自身类型` 工厂（曾导致编辑器解析失败）。
- 为消环随意 **`is not Type`**（GDScript 非法）；用 `not (x is Type)`。

---

## 七、存档

### 必须

- 序列化入口：**`GameManager.to_save_dict` / `from_save_dict`** + `SaveManager`。
- 佣兵存档：模板 id、等级、经验、**base 向字段**、`equipment_slots`、`buffs`、运行时状态（`current_hp`、`is_mia` 等）；final 战斗属性 **读档重算**。
- **T-MIA 账号 meta 补丁（允许新增根字段）**：
  - `account_meta`：`frozen_exp_pools[]`、`rescue_rank`、`rescue_reputation` 等槽位级 meta
  - `rescue_squad`：与 `squad_formation` **并列**的第三队占位 `{ active[], bench[] }`
  - 字段语义与缺键默认见 [SAVE_FORMAT.md](SAVE_FORMAT.md) §`account_meta`、§`rescue_squad`、§「T-MIA 旧档兼容」
- 读档缺 `account_meta` / `rescue_squad` / `is_mia` 时 **只补默认**，**不得** 因缺键触发 MIA 或写入冻结经验。

### 禁止

- 把 `CombatEntity`、`CombatController`、`WorldRun` 运行时对象 **原样写入存档**。
- 把 `CombatStats` 快照、final `patk`/`max_hp`（含装备加成后的值） **持久化**。
- **`is_mia` 或 MIA 结算写入 final 战斗属性**（MIA 仅布尔标记 + `account_meta.frozen_exp_pools` 经验冻结，见 [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) §八）。
- 将 `settlement_tier`、`_pending_run_result` 整体 **持久化进槽位根存档**（仅 `RESULT` 态内存，领完后丢弃）。

---

## 八、UI 边界

### 必须

- UI **展示**用 `StatResolver` / `CombatEntity` / `GameManager` 查询；**操作**用 `GameManager`、各 `*Service` 公开 API。
- 战斗反馈（色块、日志、速度）与战斗规则 **严格分离**（`CombatView` 注释为准）。

### 禁止

- UI 为省事 **复制一套** 业务规则（套装加成、撤离判定、技能 CD 等）。
- 未经过 `GameManager` 状态检查 **打开会改存档的面板**（如大营外打开 `EquipmentUI` 改背包）。

---

## 九、改动本文件的条件

- 新增 **跨模块数据流** 或 **打破上述单向边界** 时，须先改本文档再改代码。
- 纯 UI 文案、单文件 bugfix **不必** 改本文档。
- 与 [SAVE_FORMAT.md](SAVE_FORMAT.md) 冲突时，**存档相关以 SAVE_FORMAT 为准**，并同步修订本节。

---

## 相关文档

- [CTO.md](CTO.md) — 开工必读链入口、角色与回复格式
- [PROJECT_STATUS.md](PROJECT_STATUS.md) — 任务板
- [TASK_PROTOCOL.md](TASK_PROTOCOL.md) — 交付模板与门禁
- [DESIGN_INDEX.md](DESIGN_INDEX.md) — 玩法分册索引
- [SAVE_FORMAT.md](SAVE_FORMAT.md) — 存档字段铁律
- [design-failure-lineage-CTO.md](design-failure-lineage-CTO.md) — MIA 工程定案（T-MIA）
- [UI_SUBSYSTEM_AUDIT.md](UI_SUBSYSTEM_AUDIT.md) — 接线缺口（非铁律）
