# TBH Idle RPG

Godot 4.2+ 挂机出征原型：双半组编队、返程战利品网格、Boss 追击、濒死/觉醒、撤离物线。

## 运行

1. 用 Godot 4.2 或更高版本打开本目录（`project.godot`）。
2. 主场景运行后从大营出征；存档在 `user://`（见 `docs/SAVE_FORMAT.md`）。

## 文档

| 文档 | 说明 |
|------|------|
| [docs/DESIGN_INDEX.md](docs/DESIGN_INDEX.md) | 玩法设计索引 |
| [docs/MAP_UNLOCK.md](docs/MAP_UNLOCK.md) | 地图解锁与撤离物 |
| [docs/TEST_SCENARIOS.md](docs/TEST_SCENARIOS.md) | QA 测试图（可延后测） |
| [docs/GDSCRIPT_SYNTAX.md](docs/GDSCRIPT_SYNTAX.md) | GDScript 格式注意 |

## 本地检查

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_gdscript_format.ps1
```
