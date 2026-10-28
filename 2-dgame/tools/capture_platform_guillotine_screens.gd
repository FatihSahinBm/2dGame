extends SceneTree

# res://tools/capture_platform_guillotine_screens.gd
# Görev 7: Mahzenler platform & giyotin dengesi görsel ekran görüntüsü yakalayıcı

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var capture_step: int = 0
var timer: float = 0.0
var plat1: CollapsingPlatform = null
var player: CharacterBody2D = null


func _init() -> void:
	print("--- GÖRSEL TEST: PLATFORM & GİYOTİN SAHNE GÖRÜNTÜLERİ YAKALANIYOR ---")


func _process(delta: float) -> bool:
	timer += delta

	match capture_step:
		0:
			var packed = load(STAGE2_PATH) as PackedScene
			stage_instance = packed.instantiate()
			root.add_child(stage_instance)

			plat1 = stage_instance.get_node_or_null("Platforms/CollapsingPlat1") as CollapsingPlatform
			player = stage_instance.get_node_or_null("CombatPlayer") as CharacterBody2D

			# Dış kapıyı ve kilit mekanizmasını aç
			var gate_col = stage_instance.get_node_or_null("EntranceMechanism/OuterGateStatic/CollisionShape2D") as CollisionShape2D
			if gate_col:
				gate_col.disabled = true
			var portcullis = stage_instance.get_node_or_null("EntranceMechanism/OuterPortcullis") as ColorRect
			if portcullis:
				portcullis.position.y -= 70.0

			# Oyuncuyu EntranceLedge gözlem noktasına (x = 370, y = 550) taşı
			if player:
				player.global_position = Vector2(370, 550)
				var cam = player.get_node_or_null("Camera2D") as Camera2D
				if cam:
					cam.position_smoothing_enabled = false
					cam.global_position = Vector2(580, 480)

			capture_step = 1
			timer = 0.0

		1:
			# 0.6s bekle, giyotin salınırken gözlem ekranını kaydet
			if timer > 0.6:
				_save_screenshot("stage2_trap_observation.png")
				# Oyuncuyu CollapsingPlat1 üzerine taşı ve platformu salla
				if player:
					player.global_position = Vector2(460, 510)
				if plat1:
					plat1.trigger_collapse()
				capture_step = 2
				timer = 0.0

		2:
			# Platform titrerken (collapse_delay devam ederken) ekran görüntüsü al
			if timer > 1.0:
				_save_screenshot("stage2_trap_shaking.png")
				capture_step = 3
				timer = 0.0

		3:
			# Platform çöktükten sonra ekran görüntüsü al
			if timer > 1.8: # 1.0s + 1.8s = 2.8s > 2.4s çökme
				_save_screenshot("stage2_trap_collapsed.png")
				print("--- EKRAN GÖRÜNTÜLERİ BAŞARIYLA KAYDEDİLDİ ---")
				quit(0)

	return false


func _save_screenshot(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var dir_path: String = "c:/Projects/2dgame/2-dgame/output"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var full_path: String = "%s/%s" % [dir_path, filename]
	var err: Error = img.save_png(full_path)
	if err == OK:
		print("Ekran görüntüsü kaydedildi: ", full_path)
	else:
		printerr("Ekran görüntüsü kaydedilemedi: ", err)
