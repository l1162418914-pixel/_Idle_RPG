class_name BaseCampBagUI
extends VBoxContainer
## T-UI-B4 · 大营背包网格预览（只读；与出征 RunGridUI 配色区分）

const CELL_PX := 14
const GRID_COLS := 6
const CAMP_ITEM_COLOR := Color(0.52, 0.58, 0.82, 0.92)
const CAMP_CELL_BG := Color(0.1, 0.11, 0.15)

var _summary: Label = null
var _overflow: Label = null
var _grid_host: Control = null
var _equip_btn: Button = null
var _open_equipment: Callable = Callable()


func _ready() -> void:
	_ensure_ui()


func bind_open_equipment(callback: Callable) -> void:
	_open_equipment = callback


func _ensure_ui() -> void:
	if _summary != null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "—— 大营背包 ——"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 11)
	_summary.modulate = Color(0.7, 0.78, 0.9)
	add_child(_summary)
	_overflow = Label.new()
	_overflow.visible = false
	_overflow.add_theme_font_size_override("font_size", 10)
	_overflow.modulate = Color(1.0, 0.75, 0.45)
	add_child(_overflow)
	_grid_host = Control.new()
	_grid_host.name = "CampBagGridHost"
	_grid_host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_grid_host)
	_equip_btn = Button.new()
	_equip_btn.text = "管理装备"
	_equip_btn.custom_minimum_size = Vector2(96, 36)
	_equip_btn.pressed.connect(_on_equip_pressed)
	add_child(_equip_btn)


func refresh() -> void:
	_ensure_ui()
	var cap: int = GameManager.get_inventory_capacity()
	var used: int = GameManager.inventory.size()
	var dims: Vector2i = _grid_dims_for_capacity(cap)
	var grid := GridInventory.new(dims.x, dims.y)
	var overflow: int = 0
	for eq in GameManager.inventory.items:
		if eq == null or not grid.place_auto(eq):
			overflow += 1
	_summary.text = "仓库格 %dx%d · %d/%d 件（出征网格见右窗 RUNNING）" % [
		dims.x, dims.y, used, cap
	]
	if overflow > 0:
		_overflow.visible = true
		_overflow.text = "+%d 件未入预览格（容量或占格不足）" % overflow
	else:
		_overflow.visible = false
		_overflow.text = ""
	_paint_grid(_grid_host, grid)


func _grid_dims_for_capacity(capacity: int) -> Vector2i:
	var rows: int = maxi(4, int(ceil(float(capacity) / float(GRID_COLS))) + 1)
	rows = mini(rows, 10)
	return Vector2i(GRID_COLS, rows)


func _paint_grid(host: Control, grid: GridInventory) -> void:
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
			bg.color = CAMP_CELL_BG
			bg.position = Vector2(x * CELL_PX, y * CELL_PX)
			bg.size = Vector2(CELL_PX - 1, CELL_PX - 1)
			host.add_child(bg)
	for entry in grid.get_placement_snapshots():
		var origin: Vector2i = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var eq: Equipment = entry.get("equipment")
		if eq == null:
			continue
		var size_cells := Vector2i(maxi(1, eq.grid_w), maxi(1, eq.grid_h))
		var block := ColorRect.new()
		block.color = CAMP_ITEM_COLOR
		block.position = Vector2(origin.x * CELL_PX, origin.y * CELL_PX)
		block.size = Vector2(size_cells.x * CELL_PX - 1, size_cells.y * CELL_PX - 1)
		block.tooltip_text = "[%s] %s" % [eq.quality_name, eq.item_name]
		host.add_child(block)


func _on_equip_pressed() -> void:
	if _open_equipment.is_valid():
		_open_equipment.call()
