# 美术工作清单（Art Checklist）

> **状态**：程序框架 **T-ART-FW-1～3 ✅**；真图填充 **T-ART-C1 起**（内容向，非阻塞玩法）。  
> **程序约定**：`VisualSlot` + `data/art_manifest.json`；缺图自动回退色块。  
> **气质**：[GAME_BIBLE.md](GAME_BIBLE.md) §五 — KTC 跑图 + CQ 接战条 + **CQ 营地舞台** + THB 壳；**非**消块/全屏街景横滑。

---

## 一、谁做什么

| 角色 | 工作 | 不动 |
|------|------|------|
| **画师 / 外包** | 出 PNG（+ 可选序列帧）；按 `art_key` 命名 | 改坐标、滚动速度、战斗公式 |
| **你（策划）** | 定风格参考、色板、优先级 | — |
| **程序** | 把路径登记进 `art_manifest.json`；必要时扩 `art_key` | 替画师改构图 |
| **验收** | F5 看底栏/接战；headless 仍须 0 FAIL | — |

**程序已就绪**：`scripts/ui/visual_slot.gd`、`visual_constants.gd`、`art_manifest.gd`  
**资源目录建议**：`res://art/`（现网可空，manifest 指向即可）

---

## 二、阶段与优先级

### P0 · 首包真图（T-ART-C1 · 约 1 套草原气质）

| # | 类别 | art_key | 占位尺寸 | 张数 | 说明 |
|---|------|---------|----------|------|------|
| C1-1 | 行军剪影 | `party/silhouette_0`～`_3` | 10×14 | 4 | 侧面跑姿；返程水平翻转 |
| C1-2 | 视差远 | `parallax/layer_0` | 条带可横拼 | 1 | 最慢层；色相近 `VisualConstants` 远层 |
| C1-3 | 视差中 | `parallax/layer_1` | 条带可横拼 | 1 | |
| C1-4 | 视差近 | `parallax/layer_2` | 条带可横拼 | 1 | |
| C1-5 | 里程碑 | `milestone/marker` | 6×6 起 | 1 | 路旁点；可略放大 |
| C1-6 | 采集道具 | `gather/prop` | 28×20 | 1 | 箱/遗弃补给 |
| C1-7 | Boss 追击 | `boss_chase/body` + `boss_chase/crown` | 22×32 + 14×8 | 2 | 右侧剪影；可分层 |

**验收**：改 `art_manifest.json` 路径 → F5 `test_01` 行军/接战见贴图；删文件仍显示色块。

### P1 · 接战立绘（T-ART-C2 · 需程序扩 UnitView VisualSlot）

| # | 类别 | 规格 | 说明 |
|---|------|------|------|
| C2-1 | 佣兵接战 | **48×48**，脚点底边中心 | `UnitView` 现仍为色块 |
| C2-2 | 敌人/Boss | 同上或 64×64 Boss | 与槽位 `BattlefieldSlots` 不压叠 |
| C2-3 | 状态 | `combat_idle` / `attack` / `hit` / `die` | 可先单帧，后序列帧 |
| C2-4 | 弹道/受击 | 小图 8～16px | 可选后期 |

**脚线**：`UNIT_BASELINE_Y = 36`（见 `battlefield_slots.gd`）

### P2 · 事件与 UI 点缀

| # | art_key | 说明 |
|---|---------|------|
| C2-5 | `milestone/fired` / `milestone/flash` | 已触发/闪光 |
| C2-6 | `gather/party` | 采集时队伍（可选） |
| C2-7 | 搜索飘字图标 | 暂无 key；可新增 `search/toast_icon` |

### P3 · 大营营地舞台（T-UI-CAMP-4 · 与 CAMP-1 可并行）

| # | art_key | 占位尺寸 | 说明 |
|---|---------|----------|------|
| C3-1 | `camp/bg` | 中窗条带可横拼 | 暖色营地背景（**非**全屏街景） |
| C3-2 | `camp/bonfire` | 底栏居中 | BASE 待机营火 |
| C3-3 | `camp/building_recruit` | 32×32 | 建筑图标 → 后勤招募 Tab |
| C3-4 | `camp/building_medical` | 32×32 | → 医疗 Tab |
| C3-5 | `camp/building_warehouse` | 32×32 | → 仓库 Tab |
| C3-6 | `camp/party_row_*` | 复用 `party/silhouette_*` | 中窗横排与底栏剪影统一 |

| 项 | 状态 |
|----|------|
| 全屏 CQ 街景横滑背景 | 🔒 **不做** |
| 固定三窗内营地舞台 | ✅ **T-UI-CAMP** 定案 |
| 地图卡插画、Dock 图标 | T-ART-C4 按需 |

---

## 三、已登记的 art_key（程序现网）

| art_key | 用途 | 占位尺寸 | manifest 示例 |
|---------|------|----------|---------------|
| `party/silhouette_0`～`3` | 行军队伍 | 10×14 | 待填 |
| `parallax/layer_0`～`2` | 视差三层 | 高比见 `VisualConstants` | 待填 |
| `milestone/marker` | 里程碑未触发 | 6×6 | `icon.svg` 占位 |
| `milestone/fired` | 已触发 | 6×6 | 未登记 |
| `milestone/flash` | 经过闪光 | 10×10 | `icon.svg` 占位 |
| `gather/prop` | 采集道具 | 28×20 | 未登记 |
| `gather/party` | 采集队伍块 | 8×12 | 未登记 |
| `boss_chase/body` | 追击躯体 | 22×32 | 未登记 |
| `boss_chase/crown` | 追击冠 | 14×8 | 未登记 |

新增 key：与程序确认后写入 `visual_constants.gd` 的 `placeholder_spec` + manifest。

---

## 四、画师交付规范

### 格式

- **PNG** 透明底；像素风或手绘均可，**全项目统一一种**。
- **视差条带**：单层宽度建议 **512～1024px**，左右可无缝拼接。
- **不要**自带相机、不要留大面积透明边（脚点外扩 ≤2px）。

### 脚点与朝向

```
接战立绘：脚点在底边中心（接战 48×48 框内）
行军剪影：侧面向右（程序返程 scale.x = -1）
Boss 剪影：面向左（追击从右来）
```

### 色板（占位参考 · 可整体换皮）

| 用途 | 参考色 |
|------|--------|
| 友方行军 | 蓝系 `VisualConstants.PARTY_SILHOUETTE_COLORS` |
| 视差远→近 | 深蓝灰三层 |
| 里程碑 | 金黄 `#E6BF59` 系 |
| Boss 追击 | 红 `#B82E24` 系 |

### 命名与目录

```
res://art/march/party_silhouette_0.png
res://art/parallax/grassland_far.png
res://art/combat/merc_warrior_idle.png
```

登记：

```json
// data/art_manifest.json
{
  "version": 1,
  "textures": {
    "party/silhouette_0": "res://art/march/party_silhouette_0.png",
    "parallax/layer_0": "res://art/parallax/grassland_far.png"
  }
}
```

缺文件或路径错误 → **自动色块**，不崩。

---

## 五、程序配合清单（给 Dev · 非画师）

| ID | 何时做 | 内容 |
|----|--------|------|
| **T-ART-C1** | 画师交 P0 包 | 更新 manifest + F5 验收表 |
| **T-ART-C2** | 有接战立绘前 | `UnitView` 接 `VisualSlot`；扩 `combat/*` art_key |
| **T-ART-C3** | 可选 | `MarchEventMarkers` 全量改 VisualSlot（现部分 ColorRect） |
| **T-ART-C4** | 大营后期 | 地图卡 / Dock 图标 |
| **T-ART-CAMP** | CAMP-4 | `camp/*` manifest + F5 中窗/底栏验收 |

**禁止**：为贴图改 `CombatController` / `RunMarchLane` 滚动公式。

---

## 六、验收清单（F5）

### P0 跑图包（T-ART-C1）

- [ ] 进军 `test_01`：底栏行军剪影为真图（非纯色块）
- [ ] 视差三层可见纹理且滚动方向正确
- [ ] `grassland` 80m 附近见里程碑图标（真图）
- [ ] 触发采集事件见 `gather/prop` 图
- [ ] 返程 `test_03`：右侧 Boss 追击为剪影贴图
- [ ] 删掉一张 manifest 路径 → 该处回退色块
- [ ] `MiaPhase1Probe` 仍 **0 FAIL**

### P1 接战包（T-ART-C2 · 程序接好后）

- [ ] 接战友方/敌方为立绘，脚线对齐脚线参考
- [ ] 远程 `[远]` 单位不压叠
- [ ] 觉醒/Buff/技能角标不被立绘遮挡（可略上移立绘）

---

## 七、明确不做（本阶段）

- CQ 消块风、**全屏街景大营横滑**（固定三窗营地舞台除外）
- 3D、Spine 复杂骨骼（除非后续单独立项）
- 为美术改里程/接战停滚规则
- 每张地图一套独立 UI 皮肤（先 **草原 grassland** 一套）

---

## 八、相关文档

- [design-march-visual.md](design-march-visual.md) — 跑图/接战层 Z 序
- [design-combat-stack.md](design-combat-stack.md) — 接战脚线
- [PROJECT_STATUS.md](PROJECT_STATUS.md) — T-ART-FW / T-ART-C1
- [EXTERNAL_AI_BRIEF.md](EXTERNAL_AI_BRIEF.md) — 项目总览
