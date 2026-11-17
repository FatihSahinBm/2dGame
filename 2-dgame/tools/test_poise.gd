extends SceneTree

## res://tools/test_poise.gd
## Story 2D-128: Duruş (poise) ve denge kırma sistemi.
## Çalıştırma: godot --headless --path . --script res://tools/test_poise.gd

const PoiseComponent = preload("res://scripts/combat/poise_component.gd")

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Duruş ve Denge Kırma (2D-128) ===")

	# Veri: saldırı türüne göre duruş hasarı
	var light: float = PoiseComponent.get_attack_poise("light")
	var heavy: float = PoiseComponent.get_attack_poise("heavy")
	_check(light > 0.0 and heavy > light and PoiseComponent.get_attack_poise("plunge") >= heavy, "Duruş hasarları veriden okunuyor; ağır saldırı hafiften güçlü.")
	_check(PoiseComponent.get_attack_poise("bilinmeyen") == PoiseComponent.get_attack_poise("default"), "Tanımsız saldırı türü varsayılan değeri kullanıyor.")

	# Normal düşman: bileşen eklenir
	var skeleton: Node2D = (load("res://scenes/enemies/skeleton.tscn") as PackedScene).instantiate()
	root.add_child(skeleton)
	skeleton.set_physics_process(false)
	await process_frame
	var poise: Node = skeleton.get_node_or_null("PoiseComponent")
	_check(poise != null and poise.max_poise == skeleton.max_poise and poise.current_poise == poise.max_poise, "Normal düşmanda duruş bileşeni tam değerle başlıyor.")
	if poise == null:
		_finish()
		return
	var bar: ProgressBar = skeleton.find_child("PoiseBar", true, false) as ProgressBar
	_check(bar != null and not bar.visible, "Duruş göstergesi var ve duruş tamken gizli.")

	var broken: Array[float] = []
	var restored: Array[int] = [0]
	poise.poise_broken.connect(func(duration: float) -> void: broken.append(duration))
	poise.poise_restored.connect(func() -> void: restored[0] += 1)

	_check(not PoiseComponent.apply_player_hit(skeleton, "light") and is_equal_approx(poise.current_poise, poise.max_poise - light), "Hafif vuruş duruşu veri kadar azaltıyor, kırmıyor.")
	_check(bar.visible and is_equal_approx(bar.value, poise.current_poise), "Gösterge görünür oldu ve gerçek değerle eşleşiyor.")

	var was_broken: bool = false
	for i: int in range(10):
		if PoiseComponent.apply_player_hit(skeleton, "heavy"):
			was_broken = true
			break
	_check(was_broken and poise.is_broken and broken.size() == 1, "Duruş sıfırlanınca denge kırılıyor (tek olay).")
	_check(skeleton.current_state == skeleton.State.HURT and skeleton._hurt_timer >= broken[0] - 0.05, "Düşman belirlenen süre boyunca sersemleme durumunda.")

	# Sersemken gelen duruş hasarı ve can hasarı sersemlemeyi çakıştırmaz/kısaltmaz
	_check(not PoiseComponent.apply_player_hit(skeleton, "heavy") and broken.size() == 1, "Sersemken ikinci bir denge kırılması tetiklenmiyor.")
	var timer_before: float = skeleton._hurt_timer
	skeleton.take_damage(1)
	_check(skeleton._hurt_timer >= timer_before - 0.001, "Sersemken alınan hasar sersemleme süresini kısaltmıyor.")

	# Süre bitince duruş dolar ve düşman normale döner
	poise._process(broken[0] + 0.1)
	_check(not poise.is_broken and poise.current_poise == poise.max_poise and restored[0] == 1 and not bar.visible, "Süre bitince duruş doluyor, gösterge gizleniyor.")
	skeleton._hurt_timer = 0.0
	skeleton._process_hurt(0.016)
	_check(skeleton.current_state != skeleton.State.HURT, "Sersemleme bitince düşman normal durumuna dönüyor.")

	# Kendiliğinden dolma
	PoiseComponent.apply_player_hit(skeleton, "light")
	var regen_delay: float = float(PoiseComponent.get_config().get("regen_delay", 2.5))
	poise._process(regen_delay + 0.01)
	poise._process(10.0)
	_check(poise.current_poise == poise.max_poise, "Hasar almadan bekleyince duruş kendiliğinden doluyor.")

	# Ölü düşman duruş hasarı almaz
	skeleton.is_dead = true
	_check(not PoiseComponent.apply_player_hit(skeleton, "heavy") and poise.current_poise == poise.max_poise, "Ölü düşmana duruş hasarı işlenmiyor.")
	skeleton.queue_free()

	# Boss bağışıklığı: bileşen ve gösterge yok
	var ogre: Node2D = (load("res://scenes/enemies/ogre_boss.tscn") as PackedScene).instantiate()
	root.add_child(ogre)
	ogre.set_physics_process(false)
	await process_frame
	_check(ogre.get_node_or_null("PoiseComponent") == null and ogre.find_child("PoiseBar", true, false) == null, "Boss'ta duruş bileşeni ve göstergesi yok (bağışık).")
	_check(not PoiseComponent.apply_player_hit(ogre, "heavy"), "Boss'a duruş hasarı işlenmiyor.")
	ogre.queue_free()

	# Raptor da duruş sistemini kullanıyor
	var raptor: Node2D = (load("res://scenes/enemies/raptor.tscn") as PackedScene).instantiate()
	root.add_child(raptor)
	raptor.set_physics_process(false)
	await process_frame
	_check(raptor.get_node_or_null("PoiseComponent") != null, "Raptor'da duruş bileşeni var.")
	raptor.queue_free()
	_finish()


func _finish() -> void:
	if _failed:
		printerr("SONUÇ: DURUŞ TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: DURUŞ TESTİ BAŞARILI")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
