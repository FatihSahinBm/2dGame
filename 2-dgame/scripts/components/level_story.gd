extends RefCounted

## res://scripts/components/level_story.gd
## Seviye scriptleri için hikâye anlatımı yardımcıları.
## Diyalog metinleri data/story altındaki JSON dosyalarından gelir; burada metin tutulmaz.
## Kullanım: const LevelStory = preload("res://scripts/components/level_story.gd")

const DIALOGUE_BOX_SCENE_PATH: String = "res://scenes/ui/dialogue_box.tscn"
const StoryLoader = preload("res://scripts/autoloads/story_data_loader.gd")


## Seviyenin diyalog kutusunu bulur; sahnede yoksa örnekleyip ekler.
static func find_dialogue_box(level: Node) -> Node:
	if not is_instance_valid(level) or not level.is_inside_tree():
		return null
	var box: Node = level.get_node_or_null("DialogueBox")
	if box == null and ResourceLoader.exists(DIALOGUE_BOX_SCENE_PATH):
		var packed: PackedScene = load(DIALOGUE_BOX_SCENE_PATH) as PackedScene
		if packed:
			box = packed.instantiate()
			box.name = "DialogueBox"
			level.add_child(box)
	return box


## Verilen anahtarların diyaloglarını art arda tek sekans olarak oynatır.
## Başka bir diyalog sürüyorsa veya metin bulunamazsa false döner.
static func play(level: Node, keys: Array[String], focus: Node2D = null) -> bool:
	var box: Node = find_dialogue_box(level)
	if box == null or not box.has_method("start_dialogue"):
		return false
	if "_dialogue_active" in box and box._dialogue_active:
		return false
	var entries: Array = []
	for key: String in keys:
		entries.append_array(StoryLoader.get_dialogue_sequence(key))
	if entries.is_empty():
		return false
	box.start_dialogue(entries, focus)
	return true


## Kısa bir gecikmeden sonra oynatır (seviye açılış ve olay anlatımları için).
## Tek seferliktir: oynatılan anlatım GameState.persistent_events içine "story|<ilk anahtar>"
## olarak işlenir; ölüm sonrası yeniden doğuşta veya kayıt yüklenince tekrar oynamaz.
static func play_delayed(level: Node, keys: Array[String], delay: float = 0.8, focus: Node2D = null) -> void:
	if keys.is_empty() or not is_instance_valid(level) or not level.is_inside_tree():
		return
	var once_id: String = "story|" + keys[0]
	if has_event(level, once_id):
		return
	level.get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(level) and level.is_inside_tree() and not has_event(level, once_id):
			if play(level, keys, focus):
				set_event(level, once_id)
	)


## Kalıcı hikâye olayı kaydeder (GameState.persistent_events).
static func set_event(level: Node, event_id: String) -> void:
	var game_state: Node = _game_state(level)
	if game_state and game_state.has_method("set_event_completed"):
		game_state.set_event_completed(event_id, true)


static func has_event(level: Node, event_id: String) -> bool:
	var game_state: Node = _game_state(level)
	if game_state and game_state.has_method("is_event_completed"):
		return bool(game_state.is_event_completed(event_id))
	return false


## Bölüm sonu eğilimi: "redemption" veya "god_king".
static func get_alignment(level: Node) -> String:
	var game_state: Node = _game_state(level)
	if game_state and game_state.has_method("get_ending_alignment"):
		return str(game_state.get_ending_alignment())
	return "redemption"


static func _game_state(level: Node) -> Node:
	if not is_instance_valid(level) or not level.is_inside_tree():
		return null
	return level.get_node_or_null("/root/GameState")
