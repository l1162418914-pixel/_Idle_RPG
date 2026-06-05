# GDScript 易错语法（本项目）

编写或审查脚本时对照，避免 Godot 解析/类型检查失败。

## 1. 多行字符串 + `%` 格式化

**错误**（`%` 只作用最后一行，或解析报 `Expected closing ")"`）：

```gdscript
label.text = (
    "第一行 %s\n"
    "第二行"
    % args
)
```

**正确**：

```gdscript
label.text = (
    "第一行 %s\n"
    + "第二行"
) % args
# 或单行
label.text = "第一行 %s\n第二行" % args
```

## 2. `%` 与三元运算符 `if/else`

**错误**：

```gdscript
btn.text = "蓄力 %.0f%%" % (charge * 100.0) if charge < 0.92 else "松开"
```

**正确**：用 `if/else` 分支分别赋值，或先算字符串再赋。

## 3. 静态类型与 `is` 检查

变量已声明为 `Label` 时，不能写 `_pool_label is HBoxContainer`（类型系统报错）。

子节点请用父节点 `get_node_or_null("Name")` 或单独 `var _pool_row: HFlowContainer`。

## 4. API 名称

基地回血比例：`RosterHealth.get_heal_ratio_per_tick(mult)`（不是 `heal_ratio_per_tick`）。

## 5. 多行三元表达式

赋值建议写在一行，或整段包在括号内且勿与 `%` 混用：

```gdscript
var ids: Array[String] = get_a() if cond else get_b()
```
