extends SceneTree

# res://tools/capture_braziers_screens.gd
# Görev 10: Mahzen Bulmaca Mangalları Gerçek Render Ekran Görüntüsü Yakalayıcı (Frame-Delayed)

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var player: CharacterBody2D = null
var cam: Camera2D = null
var b1: BloodAltarBrazier = null
var b2: BloodAltarBrazier = null
var b3: BloodAltarBrazier = null

var step: int = 0
var frame_counter: int = 0


func _init() -> void:
	print("--- GÖREV 10: BULMACA MANGALLARI GERÇEK RENDER EKRANLARI YAKALANIYOR ---")


func _process(_delta: float) -> bool:
	frame_counter += 1

	match step:
		0:
			# Başlangıç ve Sahne Kurulumu
			if frame_counter == 1:
				var packed = load(STAGE2_PATH) as PackedScene
				stage_instance = packed.instantiate()
				root.add_child(stage_instance)

				player = stage_instance.get_node_or_null("CombatPlayer") as CharacterBody2D
				b1 = stage_instance.get_node_or_null("PuzzleBraziers/Brazier1") as BloodAltarBrazier
				b2 = stage_instance.get_node_or_null("PuzzleBraziers/Brazier2") as BloodAltarBrazier
				b3 = stage_instance.get_node_or_null("PuzzleBraziers/Brazier3") as BloodAltarBrazier

				# Dış kapıyı açık konuma getir
				var gate_col = stage_instance.get_node_or_null("EntranceMechanism/OuterGateStatic/CollisionShape2D") as CollisionShape2D
				if gate_col:
					gate_col.disabled = true
				var portcullis = stage_instance.get_node_or_null("EntranceMechanism/OuterPortcullis") as ColorRect
				if portcullis:
					portcullis.position.y -= 70.0

				# Koridordaki düşmanları arka plana al/gizle ki mangallar net görünsün
				var enemies = stage_instance.get_node_or_null("Enemies")
				if enemies:
					for child in enemies.get_children():
						child.visible = false
						child.set_process(false)
						child.set_physics_process(false)

				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = 0
						cam.limit_right = 2400
						cam.limit_top = -200
						cam.limit_bottom = 700

					# Oyuncuyu koridorun ortasına konumlandır (X=1750, Y=540)
					player.global_position = Vector2(1750, 540)
					if cam:
						cam.zoom = Vector2(0.85, 0.85)

			# 10 kare bekle, kamera ve render otursun
			if frame_counter >= 12:
				_save_screenshot("stage2_braziers_overview.png")
				print("  [YAKALANDI] 1. stage2_braziers_overview.png (Üç mangalın sönük genel görünümü)")
				step = 1
				frame_counter = 0

		1:
			# 2. Bir mangalın sönük hâli yakın çekim
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(1485, 540)
				var prompt = b1.get_node_or_null("PromptLabel") as Label
				if prompt:
					prompt.visible = true
				if cam:
					cam.zoom = Vector2(1.7, 1.7)

			# 10 kare bekle
			if frame_counter >= 12:
				_save_screenshot("stage2_brazier_unlit.png")
				print("  [YAKALANDI] 2. stage2_brazier_unlit.png (Brazier1 sönük yakın çekim)")
				step = 2
				frame_counter = 0

		2:
			# 3. Brazier1'i yak ve alevli görüntüsünü yakala
			if frame_counter == 1:
				b1.ignite_brazier()

			# 15 kare bekle (alev animasyonunun oynaması için)
			if frame_counter >= 15:
				_save_screenshot("stage2_brazier_lit.png")
				print("  [YAKALANDI] 3. stage2_brazier_lit.png (Brazier1 alevli yakın çekim)")
				step = 3
				frame_counter = 0

		3:
			# 4. Brazier2 ve Brazier3'ü de yak -> Taht Odası kapısının açılması
			if frame_counter == 1:
				b2.ignite_brazier()
				b3.ignite_brazier()
				if player:
					player.global_position = Vector2(1780, 540)
				if cam:
					cam.zoom = Vector2(0.85, 0.85)

			# 40 kare bekle (kapı animasyonu ve bildirim tamamlanması için)
			if frame_counter >= 40:
				_save_screenshot("stage2_braziers_completed.png")
				print("  [YAKALANDI] 4. stage2_braziers_completed.png (Bulmaca tamamlandı, taht kapısı açık)")
				print("--- TÜM GÖREV 10 EKRAN GÖRÜNTÜLERİ BAŞARIYLA ALINDI! ---")
				quit(0)
				return true

	return false


func _save_screenshot(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var dir_path: String = "c:/Projects/2dgame/2-dgame/output"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var full_path: String = "%s/%s" % [dir_path, filename]
	var err: Error = img.save_png(full_path)
	if err == OK:
		print("Dosyaya kaydedildi: ", full_path)
	else:
		printerr("Hata: ", err)
