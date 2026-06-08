extends VBoxContainer
class_name RunGridUI
## 出征网格只读可视化：安全箱 + 外露格（T-05）

const CELL_PX := 15

## 结算右窗快照：不纵向撑满，避免挤掉「返回基地」等底栏按钮
var compact_snapshot: bool = false

var _summary: Label = null
var _warning: Label = null
var _safe_title: Label = null
var _safe_host: Control = null
var _exposed_title: Label = null
var _exposed_host: Control = null


func _ready() -> void:
	_ensure_ui()


func _ensure_ui() -> void:
	if _summary != null:
		_apply_size_flags()
		return
	add_theme_constant_override("separation", 4)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 11)
	add_child(_summary)
	_warning = Label.new()
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.add_theme_font_size_override("font_size", 11)
	_warning.visible = false
	add_child(_warning)
	_safe_title = Label.new()
	_safe_title.add_theme_font_size_override("font_size", 10)
	_safe_title.modulate = Color(0.55, 0.85, 1.0)
	add_child(_safe_title)
	_safe_host = Control.new()
	_safe_host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_safe_host)
	_exposed_title = Label.new()
	_exposed_title.add_theme_font_size_override("font_size", 10)
	_exposed_title.modulate = Color(0.85, 0.75, 0.55)
	add_child(_exposed_title)
	_exposed_host = Control.new()
	_exposed_host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_exposed_host)
	_apply_size_flags()


func _apply_size_flags() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact_snapshot:
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		size_flags_vertical = Control.SIZE_EXPAND_FILL


func show_empty_preview(safe_size: Vector2i, exposed_size: Vector2i) -> void:
	_ensure_ui()
	var safe_inv := GridInventory.new(safe_size.x, safe_size.y)
	var exposed_inv := GridInventory.new(exposed_size.x, exposed_size.y)
	_summary.text = "出征前网格预览（空）"
	_warning.visible = false
	_render_pair(safe_inv, exposed_inv, 0, 0)


func refresh_from_run(run: WorldRun) -> void:
	_ensure_ui()
	if run == null:
		_clear_grids()
		_summary.text = "无出征数据"
		return
	var safe_inv: GridInventory = run.safe_loot
	var exposed_inv: GridInventory = run.exposed_loot
	if safe_inv == null or exposed_inv == null:
		RunLootService.init_run_grids(run)
		safe_inv = run.safe_loot
		exposed_inv = run.exposed_loot
	var carry: int = CarryValueService.compute(run, GameManager.auto_retreat_safe_only)
	var threshold: int = AutoRetreatService.get_value_threshold(run)
	var safe_only: bool = GameManager.auto_retreat_safe_only
	_summary.text = "携带价值 %d / %d%s · 箱 %d 外露 %d" % [
		carry,
		threshold,
		" (仅安全箱)" if safe_only else "",
		safe_inv.item_count() if safe_inv else 0,
		exposed_inv.item_count() if exposed_inv else 0,
	]
	_update_warning(safe_inv, exposed_inv)
	_render_pair(safe_inv, exposed_inv, carry, threshold)


func _update_warning(safe: GridInventory, exposed: GridInventory) -> void:
	if _warning == null:
		return
	var lines: PackedStringArray = []
	if exposed:
		var ratio: float = exposed.get_fill_ratio()
		if ratio >= 1.0:
			lines.append("外露格已满！新掉落可能无法入格")
		elif ratio >= 0.85:
			lines.append("外露格将满（%.0f%%）" % (ratio * 100.0))
	if safe and safe.get_fill_ratio() >= 1.0:
		lines.append("安全箱已满，新货将挤入外露")
	if lines.is_empty():
		_warning.visible = false
		_warning.text = ""
	else:
		_warning.visible = true
		_warning.text = "\n".join(lines)
		_warning.modulate = Color(1.0, 0.75, 0.35) if "已满" in _warning.text else Color(1.0, 0.9, 0.55)


func _render_pair(safe: GridInventory, exposed: GridInventory, _carry: int, _threshold: int) -> void:
	if _safe_title and safe:
		_safe_title.text = "安全箱 %dx%d · %d/%d 格" % [
			safe.width, safe.height, safe.get_used_cell_count(), safe.get_capacity_cells()
		]
	if _exposed_title and exposed:
		_exposed_title.text = "外露 %dx%d · %d/%d 格" % [
			exposed.width, exposed.height, exposed.get_used_cell_count(), exposed.get_capacity_cells()
		]
	_paint_grid(_safe_host, safe, Color(0.35, 0.55, 0.75, 0.92))
	_paint_grid(_exposed_host, exposed, Color(0.75, 0.6, 0.35, 0.92))


func _paint_grid(host: Control, grid: GridInventory, fill_color: Color) -> void:
	if host == null or grid == null:
		return
	for child in host.get_children():
		child.queue_free()
	var cw: int = grid.width * CELL_PX
	var ch: int = grid.height * CELL_PX
	host.custom_minimum_size = Vector2(cw, ch)
	for y in range(grid.height):
		for x in range(grid.width):
			var bg := ColorRect.new()
			bg.color = Color(0.12, 0.14, 0.2)
			bg.position = Vector2(x * CELL_PX, y * CELL_PX)
			bg.size = Vector2(CELL_PX - 1, CELL_PX - 1)
			host.add_child(bg)
	for entry in grid.get_placement_snapshots():
		var origin: Vector2i = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var size_cells: Vector2i = _entry_size(entry)
		var block := ColorRect.new()
		block.color = fill_color
		block.position = Vector2(origin.x * CELL_PX, origin.y * CELL_PX)
		block.size = Vector2(size_cells.x * CELL_PX - 1, size_cells.y * CELL_PX - 1)
		block.tooltip_text = _entry_label(entry)
		host.add_child(block)


func _entry_size(entry: Dictionary) -> Vector2i:
	if entry.has("equipment"):
		var eq: Equipment = entry.get("equipment")
		if eq:
			return Vector2i(maxi(1, eq.grid_w), maxi(1, eq.grid_h))
	if entry.has("material"):
		var mat = entry.get("material")
		if mat:
			return Vector2i(maxi(1, mat.grid_w), maxi(1, mat.grid_h))
	if entry.has("extract_item"):
		var item = entry.get("extract_item")
		if item:
			return Vector2i(maxi(1, item.grid_w), maxi(1, item.grid_h))
	return Vector2i(1, 1)


func _entry_label(entry: Dictionary) -> String:
	if entry.has("equipment"):
		var eq: Equipment = entry.get("equipment")
		if eq:
			return "[%s] %s" % [eq.quality_name, eq.item_name]
	if entry.has("material"):
		var mat = entry.get("material")
		if mat:
			if mat is RunMaterial:
				return "材料 %s" % mat.item_name
			return "材料"
	if entry.has("extract_item"):
		var item = entry.get("extract_item")
		if item:
			return "撤离物 %s" % str(item.item_name)
	return "物品"


func _clear_grids() -> void:
	if _safe_host:
		for c in _safe_host.get_children():
			c.queue_free()
	if _exposed_host:
		for c in _exposed_host.get_children():
			c.queue_free()
