class_name InventoryService
extends RefCounted
## 背包整理、估价、出售

const SLOT_SORT_ORDER: Dictionary = {
	"weapon": 0, "armor": 1, "helmet": 2, "boots": 3, "ring": 4, "amulet": 5
}
const SELL_PRICE_BY_QUALITY: Array[int] = [6, 14, 28, 55, 110, 220, 450]


static func get_sell_price(item: Equipment) -> int:
	if item == null:
		return 0
	var q: int = clampi(item.quality, 0, SELL_PRICE_BY_QUALITY.size() - 1)
	var base: int = SELL_PRICE_BY_QUALITY[q]
	var stat_bonus: int = 0
	for key in item.stats:
		stat_bonus += int(item.stats[key]) / 8
	return maxi(1, base + stat_bonus)


static func sort_inventory(inv: InventorySystem) -> void:
	if inv == null:
		return
	inv.items.sort_custom(func(a: Equipment, b: Equipment) -> bool:
		var sa: int = int(SLOT_SORT_ORDER.get(a.slot, 99))
		var sb: int = int(SLOT_SORT_ORDER.get(b.slot, 99))
		if sa != sb:
			return sa < sb
		if a.quality != b.quality:
			return a.quality > b.quality
		if a.item_name != b.item_name:
			return a.item_name < b.item_name
		return a.item_id < b.item_id
	)


static func collect_sellable_junk(inv: InventorySystem, max_quality: int, equipped: Array[Equipment]) -> Array[Equipment]:
	var list: Array[Equipment] = []
	if inv == null:
		return list
	for item in inv.items:
		if item == null or not item is Equipment:
			continue
		if item.quality > max_quality:
			continue
		if item in equipped:
			continue
		list.append(item as Equipment)
	return list
