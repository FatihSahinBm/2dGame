extends SceneTree

## res://tools/test_comfort_settings.gd
## Story 2D-118: Erişilebilirlik ve oynanış konforu seçenekleri.
## Gerçek ayar dosyasına yazmamak için ayar değerleri doğrudan atanır (set_* çağrılmaz).
## Çalıştırma: godot --headless --path . --script res://tools/test_comfort_settings.gd

const Scaler = preload("res://scripts/ui/dialogue_text_scaler.gd")

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Erişilebilirlik Seçenekleri (2D-118) ===")
	var comfort: Node = root.get_node_or_null("ComfortSettings")
	var created: bool = false
	if comfort == null:
		comfort = (load("res://scripts/autoloads/comfort_settings.gd") as GDScript).new()
		comfort.name = "ComfortSettings"
		root.add_child(comfort)
		created = true
	var original: Dictionary = comfort.to_dictionary()

	# Doğrulama ve gidiş-dönüş
	_check(comfort.sanitize_text_scale(9.0) == comfort.DEFAULT_TEXT_SCALE and comfort.sanitize_text_scale(1.3) == 1.3, "Metin boyutu yalnızca tanımlı kademeleri kabul ediyor.")
	comfort.apply_dictionary({"dialogue_text_scale": "bozuk", "hold_to_attack": 1, "color_assist": true})
	_check(comfort.dialogue_text_scale == comfort.DEFAULT_TEXT_SCALE and comfort.hold_to_attack and comfort.color_assist, "Bozuk veri güvenle yükleniyor.")
	comfort.apply_dictionary({"dialogue_text_scale": 1.3, "hold_to_attack": false, "color_assist": false})
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(comfort.to_dictionary()))
	comfort.apply_dictionary({})
	comfort.apply_dictionary(round_trip)
	_check(is_equal_approx(comfort.dialogue_text_scale, 1.3) and not comfort.hold_to_attack, "Seçenekler JSON gidiş-dönüşünden kayıpsız geçiyor (kalıcılık biçimi).")

	# Diyalog metni boyutu: büyür, ama alana sığmayan metinde kesilmek yerine küçülür
	var box: Node = (load("res://scenes/ui/dialogue_box.tscn") as PackedScene).instantiate()
	root.add_child(box)
	await process_frame
	var label: Label = box.content_label
	comfort.dialogue_text_scale = 1.0
	box.start_dialogue([{"speaker": "A", "text": "Kısa satır.", "portrait": "none"}])
	var base_size: int = label.label_settings.font_size
	box.skip_dialogue()
	comfort.dialogue_text_scale = 1.3
	box.start_dialogue([{"speaker": "A", "text": "Kısa satır.", "portrait": "none"}])
	var big_size: int = label.label_settings.font_size
	box.skip_dialogue()
	_check(big_size > base_size, "Büyük boyut seçilince kısa metnin yazı boyutu artıyor (%d -> %d)." % [base_size, big_size])

	var long_text: String = "Bu çok uzun bir diyalog satırıdır ve kutuya sığması için gerekirse küçültülmelidir. ".repeat(4)
	box.start_dialogue([{"speaker": "A", "text": long_text, "portrait": "none"}])
	var fitted: int = label.label_settings.font_size
	var font: Font = label.label_settings.font if label.label_settings.font else label.get_theme_font("font")
	var needed: Vector2 = font.get_multiline_string_size(long_text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, fitted)
	box.skip_dialogue()
	_check(fitted >= base_size and fitted <= big_size, "Uzun metinde boyut taban ile istenen arasında seçiliyor (%d)." % fitted)
	_check(needed.y <= label.size.y or fitted == base_size, "Seçilen boyutta metin kutuya sığıyor; sığmıyorsa taban boyuta dönülüyor (kesilme büyütmeden kaynaklanmıyor).")
	comfort.dialogue_text_scale = 1.0
	box.start_dialogue([{"speaker": "A", "text": "Kısa satır.", "portrait": "none"}])
	_check(label.label_settings.font_size == base_size, "Normal boyuta dönülünce yazı boyutu eski hâline geliyor.")
	box.skip_dialogue()
	box.queue_free()

	# Renk yardımı: yalnızca açıkken simge verir, oynanış verisine dokunmaz
	comfort.color_assist = false
	_check(comfort.get_tier_symbol("dark").is_empty(), "Renk yardımı kapalıyken simge eklenmiyor.")
	comfort.color_assist = true
	var symbols: Dictionary = {}
	for tier: String in ["pure", "tainted", "corrupted", "dark"]:
		symbols[comfort.get_tier_symbol(tier)] = true
	_check(symbols.size() == 4 and not symbols.has(""), "Renk yardımı açıkken her yozlaşma kademesinin ayrı simgesi var.")

	# Basılı tutarak saldırı
	var player: CharacterBody2D = (load("res://scenes/combat/test_player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.has_sword = true
	player.is_armed = true
	var attacks: Array[int] = [0]
	player.attack_performed.connect(func(_type: String) -> void: attacks[0] += 1)
	Input.action_press("attack_light")
	comfort.hold_to_attack = false
	player._process_hold_to_attack(0.2)
	_check(attacks[0] == 0, "Seçenek kapalıyken basılı tutmak saldırı tekrarlamıyor.")
	comfort.hold_to_attack = true
	player._process_hold_to_attack(0.2)
	_check(attacks[0] == 1 and player.is_attacking, "Seçenek açıkken basılı tutulan tuş saldırı başlatıyor.")
	player.is_attacking = false
	player._process_hold_to_attack(0.001)
	_check(attacks[0] == 1, "İki tekrar arasında en kısa bekleme süresi uygulanıyor.")
	player._process_hold_to_attack(0.2)
	_check(attacks[0] == 2, "Bekleme dolunca saldırı tekrarlanıyor.")
	player._process_hold_to_attack(0.2)
	_check(attacks[0] == 2, "Saldırı sürerken yeni saldırı kuyruğa girmiyor.")
	Input.action_release("attack_light")
	player.is_attacking = false
	player._process_hold_to_attack(0.5)
	_check(attacks[0] == 2, "Tuş bırakılınca tekrar duruyor.")
	player.queue_free()

	# Ayarlar penceresi satırları
	var dialog: Control = (load("res://scenes/ui/settings_dialog.tscn") as PackedScene).instantiate()
	root.add_child(dialog)
	await process_frame
	var has_rows: bool = dialog.find_child("DialogueTextSizeOption", true, false) != null and dialog.find_child("HoldToAttackCheck", true, false) != null and dialog.find_child("ColorAssistCheck", true, false) != null
	_check(has_rows, "Ayarlar penceresinde metin boyutu, basılı tutarak saldırı ve renk yardımı satırları var.")
	var size_label: Label = dialog.find_child("DialogueTextSizeLabel", true, false) as Label
	_check(size_label != null and not size_label.text.begins_with("SETTINGS_") and not size_label.text.is_empty(), "Satır etiketleri çevrilmiş metin gösteriyor.")
	_check(dialog.find_child("ScreenShakeSlider", true, false) != null, "Ekran sarsıntısı yoğunluğu ayarı mevcut.")
	dialog.queue_free()

	comfort.apply_dictionary(original)
	if created:
		comfort.queue_free()
	if _failed:
		printerr("SONUÇ: ERİŞİLEBİLİRLİK TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: ERİŞİLEBİLİRLİK TESTİ BAŞARILI")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
