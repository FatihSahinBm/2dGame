extends SceneTree

# res://tools/capture_dungeon_platform_screens.gd
# Görev 9: Mahzen Platformları & Zeminleri Gerçek Render Ekran Görüntüsü Yakalayıcı

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var player: CharacterBody2D = null
var plat1: CollapsingPlatform = null
var cam: Camera2D = null

var init_done: bool = false
var step: int = 0
var timer: float = 0.0


func _init() -> void:
	print("--- GÖREV 9: MAHZEN PLATFORM VE ZEMİN EKRAN GÖRÜNTÜLERİ YAKALANIYOR ---")


func _process(delta: float) -> bool:
	timer += delta

	if not init_done:
		var packed = load(STAGE2_PATH) as PackedScene
		stage_instance = packed.instantiate()
		root.add_child(stage_instance)

		player = stage_instance.get_node_or_null("CombatPlayer") as CharacterBody2D
		plat1 = stage_instance.get_node_or_null("Platforms/CollapsingPlat1") as CollapsingPlatform

		# Dış kapıyı açık konuma getir
		var gate_col = stage_instance.get_node_or_null("EntranceMechanism/OuterGateStatic/CollisionShape2D") as CollisionShape2D
		if gate_col:
			gate_col.disabled = true
		var portcullis = stage_instance.get_node_or_null("EntranceMechanism/OuterPortcullis") as ColorRect
		if portcullis:
			portcullis.position.y -= 70.0

		if player:
			cam = player.get_node_or_null("Camera2D") as Camera2D
			if cam:
				cam.position_smoothing_enabled = false
				cam.limit_left = -1000
				cam.limit_right = 4000
				cam.limit_top = -1000
				cam.limit_bottom = 2000

		init_done = true
		timer = 0.0
		step = 0
		return false

	match step:
		0:
			# 1. Mahzenin Genel Görünümü (stage2_dungeon_overview.png)
			# Kamera geniş açı, tüm platform hattını ve zeminleri kapsayacak şekilde
			if timer > 0.4:
				if cam:
					cam.zoom = Vector2(0.8, 0.8)
					cam.global_position = Vector2(760, 480)
				if player:
					player.global_position = Vector2(340, 550)
				_save_screenshot("stage2_dungeon_overview.png")
				print("  [YAKALANDI] 1. stage2_dungeon_overview.png")
				step = 1
				timer = 0.0

		1:
			# 2. Ana Zemin ve Havadaki Platformlar (stage2_ledges_and_platforms.png)
			# Oyuncu EntranceLedge ucunda, CollapsingPlat1 ve MidLedge kadrajda
			if timer > 0.3:
				if cam:
					cam.zoom = Vector2(1.0, 1.0)
					cam.global_position = Vector2(620, 500)
				if player:
					player.global_position = Vector2(370, 550)
				_save_screenshot("stage2_ledges_and_platforms.png")
				print("  [YAKALANDI] 2. stage2_ledges_and_platforms.png")
				step = 2
				timer = 0.0

		2:
			# 3. Çöken Platformun Normal Görünümü (stage2_collapsing_normal.png)
			# CollapsingPlat1 yakın çekim (zoom 1.7)
			if timer > 0.3:
				if cam:
					cam.zoom = Vector2(1.7, 1.7)
					cam.global_position = Vector2(460, 520)
				if player:
					player.global_position = Vector2(370, 550)
				_save_screenshot("stage2_collapsing_normal.png")
				print("  [YAKALANDI] 3. stage2_collapsing_normal.png")
				step = 3
				timer = 0.0

		3:
			# 4. Çöken Platformun Titreşme / Çökme Anı (stage2_collapsing_shaking.png)
			# Oyuncuyu platform üzerine taşı ve çöküşü başlat
			if timer > 0.1:
				if player:
					player.global_position = Vector2(460, 510)
				if cam:
					cam.zoom = Vector2(1.5, 1.5)
					cam.global_position = Vector2(460, 515)
				if plat1:
					plat1.trigger_collapse()
				step = 4
				timer = 0.0

		4:
			# Titreşimin ortasında (1.0 saniye sonra) görüntüyü yakala
			if timer > 1.0:
				_save_screenshot("stage2_collapsing_shaking.png")
				print("  [YAKALANDI] 4. stage2_collapsing_shaking.png")
				step = 5
				timer = 0.0

		5:
			# Platform düştükten sonra bir kare daha (isteğe bağlı zenginlik)
			if timer > 1.8:
				_save_screenshot("stage2_collapsing_fallen.png")
				print("  [YAKALANDI] 5. stage2_collapsing_fallen.png (Düşüş anı)")
				print("--- TÜM GÖRÜNTÜLER BAŞARIYLA ALINDI! ---")
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
