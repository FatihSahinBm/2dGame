extends SceneTree

## res://tools/test_scene_loading.gd
## Story 2D-152: Arka planda sahne yükleme ve yükleme ekranı.
## Çalıştırma: godot --headless --path . --script res://tools/test_scene_loading.gd

const VALID_SCENE: String = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"
const MISSING_SCENE: String = "res://scenes/levels/yok/olmayan_sahne.tscn"

var _failed: bool = false


func _initialize() -> void:
	await process_frame
	print("\n=== TEST: Asenkron Sahne Yükleme (2D-152) ===")
	var transition: Node = root.get_node_or_null("SceneTransition")
	var created: bool = false
	if transition == null:
		transition = (load("res://scenes/ui/scene_transition.tscn") as PackedScene).instantiate()
		root.add_child(transition)
		created = true
	await process_frame

	# 1. Geçerli sahne: ilerleme 0–1 arasında, geriye gitmeden, 1.0 ile biter
	var ratios: Array[float] = []
	var on_progress: Callable = func(ratio: float) -> void: ratios.append(ratio)
	transition.load_progress.connect(on_progress)
	var packed: PackedScene = await transition._load_scene_threaded(VALID_SCENE)
	_check(packed != null and packed.can_instantiate(), "Geçerli sahne arka planda yüklendi.")
	var monotonic: bool = not ratios.is_empty()
	for i: int in range(ratios.size()):
		if ratios[i] < 0.0 or ratios[i] > 1.0 or (i > 0 and ratios[i] < ratios[i - 1]):
			monotonic = false
	_check(monotonic and is_equal_approx(ratios[-1], 1.0), "İlerleme gerçek durumdan geliyor: 0–1 arasında, geriye gitmiyor ve %100 ile bitiyor.")
	_check(not transition.is_loading(), "Yükleme bitince yükleyici boşa çıkıyor.")
	var overlay: Control = transition._ensure_loading_overlay()
	_check(not overlay.visible and overlay.get_progress_percent() == 100, "Yükleme ekranı kapanmış ve son yüzde %100.")

	# 2. Yükleme ekranı içeriği
	overlay.begin()
	var first_tip: String = overlay.get_tip_text()
	_check(overlay.visible and overlay.get_progress_percent() == 0 and not first_tip.is_empty() and not first_tip.begins_with("LOADING_"), "Yükleme ekranı %0 ile açılıyor ve çevrilmiş bir ipucu gösteriyor.")
	overlay.set_progress(0.42)
	_check(overlay.get_progress_percent() == 42, "Yüzde göstergesi verilen oranı yansıtıyor.")
	overlay.begin()
	_check(overlay.get_tip_text() != first_tip, "Her yüklemede ipucu değişiyor.")
	overlay.finish()

	# 3. Geçersiz kaynak: çökmeden null döner
	var missing: PackedScene = await transition._load_scene_threaded(MISSING_SCENE)
	_check(missing == null and not transition.is_loading(), "Olmayan sahne çökmeden reddediliyor.")
	var empty: PackedScene = await transition._load_scene_threaded("")
	_check(empty == null, "Boş yol reddediliyor.")

	# 4. Eşzamanlı ikinci yükleme engellenir
	transition._loading_path = VALID_SCENE
	var second: PackedScene = await transition._load_scene_threaded(VALID_SCENE)
	transition._loading_path = ""
	_check(second == null, "Bir yükleme sürerken ikinci yükleme başlatılmıyor.")

	# 5. Tam akış: geçersiz hedefte güvenli geri dönüş (mevcut sahnede kalınır)
	var marker: Node = Node.new()
	marker.name = "CurrentSceneMarker"
	root.add_child(marker)
	var failures: Array[String] = []
	transition.load_failed.connect(func(path: String) -> void: failures.append(path))
	await transition.change_scene(MISSING_SCENE, 0.02)
	_check(failures == [MISSING_SCENE] and transition.last_error_path == MISSING_SCENE, "Başarısız yüklemede load_failed sinyali ve hata kaydı üretiliyor.")
	_check(not transition.is_transitioning and is_instance_valid(marker) and marker.is_inside_tree(), "Hata sonrası geçiş kilidi kalkıyor ve mevcut sahne yerinde duruyor.")
	_check(transition.color_rect.modulate.a < 0.05 and not overlay.visible, "Hata sonrası ekran yeniden açılıyor (siyah ekranda kalınmıyor).")

	# 6. Geçiş sürerken ikinci istek yok sayılır
	transition.is_transitioning = true
	var before: int = failures.size()
	await transition.change_scene(MISSING_SCENE, 0.02)
	transition.is_transitioning = false
	_check(failures.size() == before, "Geçiş sürerken gelen ikinci istek yok sayılıyor.")

	marker.queue_free()
	transition.load_progress.disconnect(on_progress)
	if created:
		transition.queue_free()
	if _failed:
		printerr("SONUÇ: SAHNE YÜKLEME TESTİ BAŞARISIZ")
		quit(1)
	else:
		print("SONUÇ: SAHNE YÜKLEME TESTİ BAŞARILI")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		_failed = true
		printerr("FAIL: " + message)
