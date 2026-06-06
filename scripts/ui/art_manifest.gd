class_name ArtManifest
extends RefCounted
## T-ART-FW-3 · art_key → 纹理路径（缺文件或缺键时由 VisualSlot 回退占位）

static var _entries: Dictionary = {}
static var _cache: Dictionary = {}


static func configure(raw: Variant) -> void:
	_entries.clear()
	_cache.clear()
	if raw is Dictionary:
		var textures: Variant = raw.get("textures", {})
		if textures is Dictionary:
			for key in textures.keys():
				_entries[str(key)] = str(textures[key])


static func has_entry(art_key: String) -> bool:
	return _entries.has(art_key)


static func get_texture_path(art_key: String) -> String:
	return str(_entries.get(art_key, ""))


static func get_texture(art_key: String) -> Texture2D:
	if not _entries.has(art_key):
		return null
	if _cache.has(art_key):
		return _cache[art_key] as Texture2D
	var path: String = str(_entries[art_key])
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	var tex: Texture2D = loaded as Texture2D
	if tex != null:
		_cache[art_key] = tex
	return tex


static func reset() -> void:
	_entries.clear()
	_cache.clear()
