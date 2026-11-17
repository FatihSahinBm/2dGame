extends SceneTree

## res://tools/test_dialogue_box_flow.gd
## Story 2D-120: Diyalog kutusu yazı efekti, anında tamamlama, ilerleme, atlama ve temizlik.
## Çalıştırma: godot --headless --path . --script res://tools/test_dialogue_box_flow.gd

const DialogueVoice = preload("res://scripts/ui/dialogue_voice.gd")

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Diyalog Kutusu Akışı (2D-120) ===")
	var box: Node = (load("res://scenes/ui/dialogue_box.tscn") as PackedScene).instantiate()
	root.add_child(box)
	await process_frame

	var long_text: String = "Bu, yazı efektini sınamak için yazılmış [b]uzun[/b] bir satırdır. ".repeat(6)
	var entries: Array = [
		{"speaker": "Fatih", "title": "", "text": long_text, "portrait": "fatih"},
		{"speaker": "", "title": "", "text": "*Kısa anlatım.*", "portrait": "none"},
	]
	var completed: Array[int] = [0]
	box.dialogue_completed.connect(func() -> void: completed[0] += 1)

	box.start_dialogue(entries)
	_check(box._dialogue_active and box._is_typing and box.content_label.text.is_empty(), "Diyalog boş metinle yazmaya başlıyor.")

	box.typewriter_speed = 0.01
	box._process(0.02)
	box._process(0.02)
	_check(box.content_label.text.length() == 2 and box._is_typing, "Yazı efekti karakterleri sırayla gösteriyor (hız ayarlanabilir).")

	# İlk ilerleme girdisi satırı tamamlar, ikincisi sonraki satıra geçer
	box._input(_advance_event())
	_check(not box._is_typing and box.content_label.text == long_text and box._current_index == 0, "İlerletme girdisi önce mevcut satırı anında tamamlıyor.")
	_check(box.content_label.text.contains("[b]"), "BBCode etiketleri yorumlanmadan düz metin olarak gösteriliyor (güvenli).")
	_check(box.content_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "Uzun metin satır kaydırmayla gösteriliyor.")
	box._input(_advance_event())
	_check(box._current_index == 1 and box._is_typing, "İkinci girdi sonraki satıra geçiyor.")

	# Atlama: yazma sürerken diyalog kapanır ve durum temizlenir
	box.skip_dialogue()
	_check(not box._dialogue_active and not box._is_typing and not box.panel.visible and completed[0] == 1, "Atlama diyaloğu kapatıp yazma durumunu temizliyor.")
	var cine: Node = root.get_node_or_null("CinematicManager")
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state:
		_check(not game_state.is_in_cinematic, "Diyalog kapanınca sinematik giriş kilidi kalkıyor.")
	elif cine == null:
		print("NOT: Autoload'lar ağaçta değil; giriş kilidi adımı atlandı.")

	# Karaktere özel ses kuralları
	_check(DialogueVoice.get_pitch("vlad") < DialogueVoice.get_pitch("player") and DialogueVoice.get_pitch("archer") > DialogueVoice.get_pitch("player"), "Karakterlerin konuşma perdesi birbirinden farklı.")
	_check(not DialogueVoice.should_blip("none", 3, "a"), "Anlatım satırları (portresiz) sessiz.")
	_check(DialogueVoice.should_blip("fatih", 3, "a") and not DialogueVoice.should_blip("fatih", 4, "a"), "Ses her karakterde değil, belirli aralıkla çalınıyor.")
	_check(not DialogueVoice.should_blip("fatih", 3, " ") and not DialogueVoice.should_blip("fatih", 3, "."), "Boşluk ve noktalama ses üretmiyor.")
	_check(DialogueVoice.get_pitch("bilinmeyen_portre") == DialogueVoice.DEFAULT_PITCH, "Tanımsız portre varsayılan perdeyle çalışıyor (çökmez).")

	box.queue_free()
	if _failed:
		printerr("SONUÇ: DİYALOG KUTUSU TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: DİYALOG KUTUSU TESTİ BAŞARILI")
		quit(0)


func _advance_event() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
