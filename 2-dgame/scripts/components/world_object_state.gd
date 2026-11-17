extends RefCounted

## res://scripts/components/world_object_state.gd
## Dünya nesnelerinin kalıcı durumları (açık / kırık / toplanmış / incelenmiş) — Story 2D-156.
##
## Kimlik: "wo|<seviye sahne dosyası>|<seviye köküne göre düğüm yolu>|<durum>".
## Sahne dosyası + düğüm yolu aynı sahnede benzersizdir, bu yüzden iki nesne aynı kimliği
## paylaşamaz ve bir sahnenin verisi başka sahnedeki nesneye uygulanamaz.
## Durumlar GameState.persistent_events içinde tutulur; SaveManager bunları kayda yazar.
##
## Kullanım (nesnenin kendi scriptinde):
##   const WorldObjectState = preload("res://scripts/components/world_object_state.gd")
##   func _ready(): if WorldObjectState.is_set(self, "opened"): _apply_opened_instantly()
##   func open(): WorldObjectState.mark(self, "opened")
##
## Çalışma anında üretilen (otomatik "@..." adlı) düğümlerin yolu kararsızdır; böyle bir nesne
## kalıcı olacaksa "persistent_id" metası verilmelidir, aksi halde durumu kaydedilmez.

const KEY_PREFIX: String = "wo"
const META_EXPLICIT_ID: StringName = &"persistent_id"


## Nesnenin kalıcı kimliğini üretir; üretilemiyorsa boş döner (durum kaydedilmez).
static func make_id(node: Node) -> String:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return ""
	var level: Node = _find_level_root(node)
	if level == null:
		return ""
	var local_id: String = ""
	if node.has_meta(META_EXPLICIT_ID):
		local_id = str(node.get_meta(META_EXPLICIT_ID))
	else:
		local_id = str(level.get_path_to(node))
		if local_id.contains("@"):
			return ""
	if local_id.is_empty():
		return ""
	return "%s|%s|%s" % [KEY_PREFIX, level.scene_file_path, local_id]


static func is_set(node: Node, state: String) -> bool:
	var object_id: String = make_id(node)
	if object_id.is_empty():
		return false
	var game_state: Node = node.get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("is_event_completed"):
		return bool(game_state.is_event_completed(object_id + "|" + state))
	return false


static func mark(node: Node, state: String) -> void:
	var object_id: String = make_id(node)
	if object_id.is_empty():
		return
	var game_state: Node = node.get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("set_event_completed"):
		game_state.set_event_completed(object_id + "|" + state, true)


## Tüm dünya nesnesi durumlarını siler (tamamlanmış bir bölüm baştan oynanırken).
static func clear_all(game_state: Node) -> void:
	if game_state == null or not "persistent_events" in game_state:
		return
	var events: Dictionary = game_state.persistent_events
	for key: Variant in events.keys():
		if str(key).begins_with(KEY_PREFIX + "|"):
			events.erase(key)


## Nesnenin ait olduğu seviye kökü: sahne dosyasından gelen en üst ata.
static func _find_level_root(node: Node) -> Node:
	var level: Node = null
	var cursor: Node = node.get_parent()
	var tree_root: Node = node.get_tree().root
	while cursor != null and cursor != tree_root:
		if not cursor.scene_file_path.is_empty():
			level = cursor
		cursor = cursor.get_parent()
	return level
