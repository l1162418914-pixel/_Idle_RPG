class_name RunExtractItem
extends Resource
## 撤离物：占格；拾取后按 retreat_chance 可能触发守卫战（仅数据；生成见 ExtractItemService）

@export var item_id: String = ""
@export var item_name: String = ""
@export var retreat_chance: float = 0.7
@export var carry_value: int = 50
@export var grid_w: int = 1
@export var grid_h: int = 1
@export var bonus_gold: int = 0
@export var bonus_exp: int = 0
