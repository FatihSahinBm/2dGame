extends SceneTree

## res://tools/test_ending_alignment.gd
## Story 2D-146: Yozlaşmaya bağlı alternatif son kuralı ve epilog verisi.
## Çalıştırma: godot --headless --path . --script res://tools/test_ending_alignment.gd

const StoryLoader = preload("res://scripts/autoloads/story_data_loader.gd")

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Alternatif Son Kuralı (2D-146) ===")
	var gs: Node = (load("res://scripts/autoloads/game_state.gd") as GDScript).new()
	root.add_child(gs)
	var corruption_limit: int = gs.ENDING_CORRUPTION_THRESHOLD
	var sacrifice_limit: int = gs.ENDING_SACRIFICE_THRESHOLD

	# [yozlaşma, kurban sayısı, beklenen son]
	var cases: Array = [
		[0, 0, gs.ENDING_REDEMPTION],
		[corruption_limit - 1, sacrifice_limit - 1, gs.ENDING_REDEMPTION],
		[corruption_limit, 0, gs.ENDING_GOD_KING],
		[100, 0, gs.ENDING_GOD_KING],
		[0, sacrifice_limit, gs.ENDING_GOD_KING],
		[corruption_limit - 1, sacrifice_limit, gs.ENDING_GOD_KING],
	]
	for case: Array in cases:
		gs.reset_state()
		gs.corruption_score = case[0]
		gs.allies_sacrificed_count = case[1]
		var first: String = gs.get_ending_alignment()
		var second: String = gs.get_ending_alignment()
		_check(first == case[2] and first == second, "yozlaşma=%d kurban=%d -> %s (kararlı)" % [case[0], case[1], case[2]])

	gs.reset_state()
	_check(gs.get_ending_alignment() == gs.ENDING_REDEMPTION and gs.get_recorded_ending().is_empty(), "Sıfırlanmış veri Kefaret verir, kayıtlı son yoktur.")

	# Oynanış yoluyla: 3 kurban (3 x 20 yozlaşma) Tanrı-Kral'a götürür ve karar kayda işlenir
	for i: int in range(sacrifice_limit):
		gs.register_ally_sacrifice("janissary")
	_check(gs.record_ending() == gs.ENDING_GOD_KING, "Üç kurban sonrası karar Tanrı-Kral.")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.persistent_events))
	gs.reset_state()
	gs.persistent_events = saved
	_check(gs.get_recorded_ending() == gs.ENDING_GOD_KING, "Son kararı kalıcı olaylarda (kayıt verisinde) korunuyor.")

	# Kılıç isyanı eşiği ile son eşiği aynı sabiti kullanır
	gs.reset_state()
	var rebellions: Array[int] = [0]
	gs.sword_rebellion_triggered.connect(func() -> void: rebellions[0] += 1)
	gs.add_corruption(corruption_limit - 1)
	var before: int = rebellions[0]
	gs.add_corruption(1)
	_check(before == 0 and rebellions[0] == 1, "Kılıç isyanı tam son eşiğinde tetikleniyor (tek kural).")

	# Her son için ayrı diyalog akışı veride mevcut
	for key: String in ["fatih_outro", "epilogue_redemption", "fatih_outro_god_king", "epilogue_god_king", "vlad_taunt_corrupted"]:
		_check(not StoryLoader.get_dialogue_sequence(key).is_empty(), "Diyalog akışı mevcut: " + key)

	gs.queue_free()
	if _failed:
		printerr("SONUÇ: ALTERNATİF SON TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: ALTERNATİF SON TESTİ BAŞARILI")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
