extends SceneTree

# res://tools/capture_guillotine_visual_screens.gd
# Görev 8: Giyotin Pixel-Art Görsel Yenilemesi Ekran Görüntüsü Yakalayıcı
# - Giyotin sol salınım ucundayken
# - Giyotin orta geçiş konumundayken
# - Giyotin sağ salınım ucundayken

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

var stage_instance: Node = null
var guil1: GuillotineTrap = null
var player: CharacterBody2D = null
var arm_node: Node2D = null

var captured_right: bool = false
var captured_center: bool = false
var captured_left: bool = false
var init_done: bool = false
var timer: float = 0.0


func _init() -> void:
	print("--- GÖREV 8 GÖRSEL TEST: GİYOTİN SALINIM EKRANLARI YAKALANIYOR ---")


func _process(delta: float) -> bool:
	timer += delta

	if not init_done:
		var packed = load(STAGE2_PATH) as PackedScene
		stage_instance = packed.instantiate()
		root.add_child(stage_instance)

		guil1 = stage_instance.get_node_or_null("Traps/Guillotine1") as GuillotineTrap
		player = stage_instance.get_node_or_null("CombatPlayer") as CharacterBody2D

		if guil1:
			arm_node = guil1.get_node_or_null("Arm") as Node2D

		# Dış kapıyı aç ve oyuncuyu EntranceLedge'de tut
		var gate_col = stage_instance.get_node_or_null("EntranceMechanism/OuterGateStatic/CollisionShape2D") as CollisionShape2D
		if gate_col:
			gate_col.disabled = true
		var portcullis = stage_instance.get_node_or_null("EntranceMechanism/OuterPortcullis") as ColorRect
		if portcullis:
			portcullis.position.y -= 70.0

		if player:
			player.global_position = Vector2(370, 550)
			var cam = player.get_node_or_null("Camera2D") as Camera2D
			if cam:
				cam.position_smoothing_enabled = false
				# Kamerayı tam tuzağın merkezine odakla
				cam.global_position = Vector2(575, 430)

		init_done = true
		return false

	# Sahne yüklendikten sonra salınım açılarına göre görüntüleri yakala
	if not arm_node:
		return false

	var angle_deg: float = rad_to_deg(arm_node.rotation)

	# 1. Sağ salınım ucu (angle_deg >= +63.5°)
	if not captured_right and angle_deg >= 63.5:
		_save_screenshot("guillotine_swing_right_apex.png")
		print("  [YAKALANDI] Sağ salınım ucu kaydedildi (açı: %.1f°)" % angle_deg)
		captured_right = true

	# 2. Orta geçiş konumu (|angle_deg| <= 1.5° ve sağdan sola geçerken)
	if captured_right and not captured_center and absf(angle_deg) <= 1.8:
		_save_screenshot("guillotine_swing_center.png")
		print("  [YAKALANDI] Orta dikey geçiş kaydedildi (açı: %.1f°)" % angle_deg)
		captured_center = true

	# 3. Sol salınım ucu (angle_deg <= -63.5°)
	if captured_center and not captured_left and angle_deg <= -63.5:
		_save_screenshot("guillotine_swing_left_apex.png")
		print("  [YAKALANDI] Sol salınım ucu kaydedildi (açı: %.1f°)" % angle_deg)
		captured_left = true

	# Tüm görüntüler alındıysa çık
	if captured_right and captured_center and captured_left:
		print("--- GÖREV 8: TÜM 3 SALINIM GÖRÜNTÜSÜ BAŞARIYLA ALINDI! ---")
		quit(0)
		return true

	# Güvenlik zaman aşımı (5 saniye)
	if timer > 5.0:
		print("Zaman aşımı kontrolü...")
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
