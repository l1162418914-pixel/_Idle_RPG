class_name VisualSlot
extends Control
## T-ART-FW-1 · 美术插槽（占位色块 ↔ 纹理；FW-2 挂到各表现层）

const _VisualConstantsLib = preload("res://scripts/ui/visual_constants.gd")


enum DisplayMode { HIDDEN, PLACEHOLDER, TEXTURE }

@export var slot_id: String = ""
@export var art_key: String = ""

var _placeholder: ColorRect = null
var _texture_rect: TextureRect = null
var _mode: DisplayMode = DisplayMode.HIDDEN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder = ColorRect.new()
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder.visible = false
	add_child(_placeholder)
	_texture_rect = TextureRect.new()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.visible = false
	add_child(_texture_rect)
	if art_key != "":
		apply_art_key(art_key)


func get_display_mode() -> DisplayMode:
	return _mode


func get_art_key() -> String:
	return art_key


func clear_slot() -> void:
	art_key = ""
	_mode = DisplayMode.HIDDEN
	if _texture_rect:
		_texture_rect.texture = null
	_sync_visibility()


func apply_placeholder(color: Color, pixel_size: Vector2) -> void:
	if _placeholder == null:
		return
	_placeholder.color = color
	_resize_placeholder(pixel_size)
	_mode = DisplayMode.PLACEHOLDER
	_sync_visibility()


func set_placeholder_color(color: Color) -> void:
	if _placeholder != null and _mode == DisplayMode.PLACEHOLDER:
		_placeholder.color = color


func resize_placeholder(pixel_size: Vector2) -> void:
	if _placeholder == null or _mode != DisplayMode.PLACEHOLDER:
		return
	_resize_placeholder(pixel_size)


func _resize_placeholder(pixel_size: Vector2) -> void:
	_placeholder.custom_minimum_size = pixel_size
	_placeholder.size = pixel_size
	custom_minimum_size = pixel_size
	size = pixel_size


func apply_texture(texture: Texture2D) -> void:
	if texture == null or _texture_rect == null:
		return
	_texture_rect.texture = texture
	if pixel_size_from_placeholder() != Vector2.ZERO:
		_texture_rect.custom_minimum_size = _placeholder.size
		_texture_rect.size = _placeholder.size
	_mode = DisplayMode.TEXTURE
	_sync_visibility()


func apply_art_key(key: String) -> void:
	art_key = key
	var spec: Dictionary = _VisualConstantsLib.placeholder_spec(key)
	if spec.is_empty():
		clear_slot()
		return
	apply_placeholder(spec.get("color", Color.MAGENTA), spec.get("size", Vector2(8, 8)))


func pixel_size_from_placeholder() -> Vector2:
	if _placeholder == null:
		return Vector2.ZERO
	return _placeholder.size


func _sync_visibility() -> void:
	visible = _mode != DisplayMode.HIDDEN
	if _placeholder:
		_placeholder.visible = _mode == DisplayMode.PLACEHOLDER
	if _texture_rect:
		_texture_rect.visible = _mode == DisplayMode.TEXTURE
