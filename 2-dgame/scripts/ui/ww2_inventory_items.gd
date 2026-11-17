extends RefCounted

## res://scripts/ui/ww2_inventory_items.gd
## InventoryDialog için Bölüm 4 eşya bileşeni (Epic 2D-144). Envanterde adedi olan
## WW2 eşyalarını (Ww2Inventory + chapter_4_ww2.json tanımları) diyaloğun eşya listesine
## ekler ve "Kullan" eylemini işler. Metinler JSON'dan TR/EN olarak gelir.

const Inventory = preload("res://scripts/components/ww2_inventory.gd")
const ID_PREFIX: String = "ww2:"
const SHORTCUTS: Dictionary = { "stick_grenade": "[T]", "field_bandage": "[H]", "gas_filter": "[V]" }


## Adedi 0'dan büyük WW2 eşyalarını listeye ekler
static func append_items(host: Node, items: Array) -> void:
	for def: Variant in Inventory.get_definitions():
		if not (def is Dictionary):
			continue
		var d: Dictionary = def as Dictionary
		var item_id: String = str(d.get("id", ""))
		var count: int = Inventory.count(host, item_id)
		if count <= 0:
			continue
		var usable: bool = bool(d.get("usable", false))
		items.append({
			"id": ID_PREFIX + item_id,
			"category": "consumable" if usable else "key",
			"title": str(d.get("title", item_id)),
			"title_en": str(d.get("title_en", item_id)),
			"icon_path": str(d.get("icon_path", "")),
			"count": count,
			"description": str(d.get("description", "")),
			"description_en": str(d.get("description_en", "")),
			"effect": str(d.get("effect", "")),
			"effect_en": str(d.get("effect_en", "")),
			"shortcut": str(SHORTCUTS.get(item_id, "")),
			"can_use": usable,
			"action_text": "Kullan" if usable else "Görev Eşyası",
			"action_text_en": "Use" if usable else "Quest Item",
		})


## Seçili eşya bir WW2 eşyasıysa kullanır; işlendiyse true (kullanılamasa bile)
static func handle_action(host: Node, item_id: String, player: Node2D) -> bool:
	if not item_id.begins_with(ID_PREFIX):
		return false
	var used: bool = Inventory.use(host, item_id.trim_prefix(ID_PREFIX), player)
	var am: Node = host.get_node_or_null("/root/AudioManager") if host.is_inside_tree() else null
	if not used and am and am.has_method("play_sfx"):
		am.play_sfx("ui_error" if am.has_method("has_sound") and am.has_sound("ui_error") else "item_equip", -6.0)
	return true
