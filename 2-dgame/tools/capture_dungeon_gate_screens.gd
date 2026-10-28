extends SceneTree

# res://tools/capture_dungeon_gate_screens.gd
# Görev 11: Mahzen Kapıları ve Mekanizmaları Gerçek Render Ekran Görüntüsü Yakalayıcı (Frame-Delayed)

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var player: CharacterBody2D = null
var cam: Camera2D = null
var chain_lever: DungeonChainLever = null
var entrance_arch: Sprite2D = null
var outer_portcullis: Node2D = null
var blood_gate: Area2D = null
var gate_bars: Sprite2D = null

var step: int = 0
var frame_counter: int = 0


func _init() -> void:
	print("--- GÖREV 11: MAHZEN KAPILARI VE MEKANİZMALARI GERÇEK RENDER EKRANLARI YAKALANIYOR ---")


func _process(_delta: float) -> bool:
	frame_counter += 1

	match step:
		0:
			# Adım 0: Sahneyi Başlat ve Kapalı Giriş Kapısı Kurulumu
			if frame_counter == 1:
				var packed = load(STAGE2_PATH) as PackedScene
				stage_instance = packed.instantiate()
				root.add_child(stage_instance)

				player = stage_instance.get_node_or_null("CombatPlayer") as CharacterBody2D
				chain_lever = stage_instance.get_node_or_null("EntranceMechanism/ChainLever") as DungeonChainLever
				entrance_arch = stage_instance.get_node_or_null("EntranceMechanism/EntranceArch") as Sprite2D
				outer_portcullis = stage_instance.get_node_or_null("EntranceMechanism/OuterPortcullis") as Node2D
				blood_gate = stage_instance.get_node_or_null("BloodAltarGate") as Area2D
				if blood_gate:
					gate_bars = blood_gate.get_node_or_null("PortcullisBars") as Sprite2D

				# Düşmanları sakinleştir ki ekran temiz olsun
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
						cam.zoom = Vector2(1.5, 1.5)

					# Oyuncuyu giriş kapısı ile zincir arasına koy
					player.global_position = Vector2(270, 540)

			# 12 kare bekle, render otursun
			if frame_counter >= 15:
				_save_screenshot("stage2_entrance_gate_closed.png")
				print("  [YAKALANDI] 1. stage2_entrance_gate_closed.png (Kapalı giriş kapısı, taş kemer ve zincir mekanizması)")
				step = 1
				frame_counter = 0

		1:
			# Adım 1: Zincir Mekanizması Yakın Çekim ([E] Zinciri Çek promptu aktif)
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(240, 540)
					player.scale.x = -1.0 # Sol taraftaki zincire baksın
				if chain_lever:
					var prompt = chain_lever.get_node_or_null("PromptLabel") as Label
					if prompt:
						prompt.visible = true
				if cam:
					cam.zoom = Vector2(2.2, 2.2)

			if frame_counter >= 15:
				_save_screenshot("stage2_chain_lever_close.png")
				print("  [YAKALANDI] 2. stage2_chain_lever_close.png (Zincir kolu, makara kaidesi ve [E] etkileşim promptu)")
				step = 2
				frame_counter = 0

		2:
			# Adım 2: Zincir Çekilir -> Kapı Açılır Animasyonu
			if frame_counter == 1:
				if chain_lever:
					chain_lever.activate_lever()
				if player:
					player.global_position = Vector2(280, 540)
				if cam:
					cam.zoom = Vector2(1.5, 1.5)

			# 30 kare bekle (Tween animasyonunun tamamlanması için)
			if frame_counter >= 35:
				_save_screenshot("stage2_entrance_gate_opened.png")
				print("  [YAKALANDI] 3. stage2_entrance_gate_opened.png (Zincir çekildi, parmaklık kemer içine çekildi, kapı açıldı)")
				step = 3
				frame_counter = 0

		3:
			# Adım 3: Oyuncu Açık Kapıdan Geçer (Geçiş Alanı ve Açıklık Doğrulaması)
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(360, 540)

			if frame_counter >= 15:
				_save_screenshot("stage2_entrance_gate_passage.png")
				print("  [YAKALANDI] 4. stage2_entrance_gate_passage.png (Oyuncu açık kapının altından rahatça geçiyor)")
				step = 4
				frame_counter = 0

		4:
			# Adım 4: Taht Odası Kapısı (BloodAltarGate) Kapalı Görünüm
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(2120, 540)
				if cam:
					cam.zoom = Vector2(1.3, 1.3)

			if frame_counter >= 20:
				_save_screenshot("stage2_blood_gate_closed.png")
				print("  [YAKALANDI] 5. stage2_blood_gate_closed.png (Kapalı Taht Odası kapısı: Gotik kemer, kan rünleri ve demir parmaklık)")
				step = 5
				frame_counter = 0

		5:
			# Adım 5: Mangal Bulmacası Çözülür -> Taht Kapısı Açılır
			if frame_counter == 1:
				if stage_instance.has_method("_unlock_throne_gate"):
					stage_instance._unlock_throne_gate()
				if player:
					player.global_position = Vector2(2175, 540)

			# 45 kare bekle (Kapı yükselme tween'i 0.8s)
			if frame_counter >= 50:
				_save_screenshot("stage2_blood_gate_opened.png")
				print("  [YAKALANDI] 6. stage2_blood_gate_opened.png (Taht kapısı açıldı, oyuncu geçiş portalında)")
				print("--- TÜM GÖREV 11 EKRAN GÖRÜNTÜLERİ BAŞARIYLA ALINDI! ---")
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
