extends SceneTree

## res://tools/test_story_completeness.gd
## Hikâye verisi bütünlük testi:
## - Scriptlerin kullandığı tüm diyalog anahtarları JSON'da var mı?
## - Her replik ve seçenek hem Türkçe hem İngilizce metne sahip mi?
## - LevelStory yardımcısı sekansları birleştirip diyalog kutusunda oynatabiliyor mu?
## Çalıştırma: godot --headless --path . --script res://tools/test_story_completeness.gd

const StoryLoader = preload("res://scripts/autoloads/story_data_loader.gd")
const LevelStory = preload("res://scripts/components/level_story.gd")

const REQUIRED_KEYS: Array[String] = [
	# Bölüm 1 — Taş Devri
	"rift_fall_intro", "silent_valley_tracks", "broken_pass", "hunters_traces",
	"temporal_fragments", "beasts_domain", "intro_awakening", "barricade_hint",
	"caveman_encounter", "caveman_quest_accept", "caveman_fight_shout", "caveman_quest_active",
	"caveman_quest_complete", "caveman_fight_aftermath", "wood_cart_ambush",
	"trex_encounter", "trex_victory", "heart_fragment_awakening",
	"heart_echo_tribe_helped", "heart_echo_tribe_slain",
	# Bölüm 2 — Vlad
	"forest_arrival", "commander_rescue", "commander_orders_note", "soldier_campfire_rest",
	"archer_sidequest_callout", "archer_sidequest_accept", "archer_sidequest_decline",
	"archer_sidequest_waiting", "archer_sidequest_complete", "fatih_intro", "fatih_commander_fallen",
	"blood_knight_intro", "battering_ram_victory", "battering_ram_victory_sergeant",
	"dungeon_entry", "ancient_heart_relief", "blood_altar_unsealed",
	"vlad_taunt", "vlad_taunt_corrupted", "vlad_taunt_vampire", "vlad_taunt_werewolf", "vlad_taunt_bat",
	"vlad_last_words", "memory_flashback", "fatih_outro", "fatih_outro_god_king",
	"epilogue_redemption", "epilogue_god_king",
]

var _failed: bool = false


func _initialize() -> void:
	await process_frame # Autoload'lar ve kök ağaç hazır olsun
	print("\n=== TEST: Hikâye Verisi Bütünlüğü ===")
	_check_required_keys()
	_check_bilingual(StoryLoader.CHAPTER_1_PATH)
	_check_bilingual(StoryLoader.CHAPTER_2_PATH)
	_check_level_story_playback()
	if _failed:
		printerr("SONUÇ: HİKÂYE BÜTÜNLÜK TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: HİKÂYE BÜTÜNLÜK TESTİ BAŞARILI")
		quit(0)


func _fail(msg: String) -> void:
	_failed = true
	printerr("FAIL: " + msg)


func _check_required_keys() -> void:
	var missing: Array[String] = []
	for key: String in REQUIRED_KEYS:
		if StoryLoader.get_dialogue_sequence(key).is_empty():
			missing.append(key)
	if missing.is_empty():
		print("PASS: %d diyalog anahtarının tamamı veride mevcut." % REQUIRED_KEYS.size())
	else:
		_fail("Eksik diyalog anahtarları: %s" % str(missing))


func _check_bilingual(path: String) -> void:
	var data: Dictionary = StoryLoader.load_chapter_data(path)
	var dialogues: Dictionary = data.get("dialogues", {}) as Dictionary
	var problems: Array[String] = []
	var entry_count: int = 0
	for key: String in dialogues.keys():
		var value: Variant = dialogues[key]
		if not value is Array:
			continue
		var index: int = 0
		for item: Variant in value as Array:
			index += 1
			if not item is Dictionary:
				continue
			entry_count += 1
			var entry: Dictionary = item as Dictionary
			var where: String = "%s[%d]" % [key, index]
			if str(entry.get("text", "")).is_empty() or str(entry.get("text_en", "")).is_empty():
				problems.append(where + " text/text_en")
			if not str(entry.get("speaker", "")).is_empty() and str(entry.get("speaker_en", "")).is_empty():
				problems.append(where + " speaker_en")
			if not str(entry.get("title", "")).is_empty() and str(entry.get("title_en", "")).is_empty():
				problems.append(where + " title_en")
			for choice: Variant in entry.get("choices", []) as Array:
				var c: Dictionary = choice as Dictionary
				if str(c.get("text", "")).is_empty() or str(c.get("text_en", "")).is_empty() or str(c.get("action", "")).is_empty():
					problems.append(where + " choice")
	if problems.is_empty():
		print("PASS: %s — %d replik iki dilde eksiksiz." % [path.get_file(), entry_count])
	else:
		_fail("%s iki dilli alan eksikleri: %s" % [path.get_file(), str(problems)])


func _check_level_story_playback() -> void:
	var level: Node2D = Node2D.new()
	root.add_child(level)
	var keys: Array[String] = ["heart_fragment_awakening", "heart_echo_tribe_helped"]
	var expected: int = 0
	for key: String in keys:
		expected += StoryLoader.get_dialogue_sequence(key).size()
	var played: bool = LevelStory.play(level, keys)
	var box: Node = level.get_node_or_null("DialogueBox")
	if not played or box == null:
		_fail("LevelStory.play diyalog kutusunu oluşturup oynatamadı (played=%s, box=%s, in_tree=%s)." % [played, box, level.is_inside_tree()])
	elif (box._dialogue_queue as Array).size() != expected:
		_fail("LevelStory sekans birleştirme hatası: beklenen %d, bulunan %d" % [expected, (box._dialogue_queue as Array).size()])
	elif LevelStory.play(level, keys):
		_fail("LevelStory süren diyaloğu kesmemeliydi.")
	else:
		print("PASS: LevelStory %d repliği tek sekansta oynattı ve süren diyaloğu kesmedi." % expected)
	level.queue_free()
