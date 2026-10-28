extends SceneTree

const STAGE2_SCENE_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var scene_res = load(STAGE2_SCENE_PATH)
	if not scene_res:
		quit(1)
		return

	var dungeon = scene_res.instantiate() as Stage2CastleDungeon
	root.add_child(dungeon)

	var player = dungeon.get_node_or_null("CombatPlayer") as CharacterBody2D
	var relief = dungeon.get_node_or_null("Environment/BoneArchiveMural") as AncientHeartRelief
	var dialogue_box = dungeon.get_node_or_null("DialogueBox") as DialogueBox

	if player and relief:
		player.global_position = Vector2(1340, 545)
		relief._on_body_entered(player)

		var cam = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.global_position = Vector2(1380, 500)
			cam.zoom = Vector2(1.35, 1.35)

	# 1. KARE: Etkileşim Öncesi (Kabartma duvarda, [E] İpucu aktif)
	await create_timer(0.4).timeout
	var viewport = root.get_viewport()
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("output/screenshots/relief_before_interaction.png")
				print("[SCREENSHOT] relief_before_interaction.png kaydedildi!")

	# 2. KARE: 1. Replik (Çevresel Taş Kabartma Gözlemi)
	if relief:
		relief.examine_relief()

	await create_timer(0.4).timeout
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("output/screenshots/relief_during_interaction.png")
				print("[SCREENSHOT] relief_during_interaction.png kaydedildi!")

	# 2B. KARE: 2. Replik (Dilsiz Kılıç Tepkisi - Konuşmacısız ve Portresiz)
	if dialogue_box and dialogue_box.panel.visible:
		dialogue_box._advance_dialogue()

	await create_timer(0.4).timeout
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("output/screenshots/relief_sword_mute_reaction.png")
				print("[SCREENSHOT] relief_sword_mute_reaction.png kaydedildi!")

	# 3. KARE: Etkileşim Sonrası (Diyalog kapandı, etki sönümlendi, normal oyun durumu)
	if dialogue_box and dialogue_box.panel.visible:
		dialogue_box._close_dialogue()

	await create_timer(0.5).timeout
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("output/screenshots/relief_after_interaction.png")
				print("[SCREENSHOT] relief_after_interaction.png kaydedildi!")

	await create_timer(0.2).timeout
	quit(0)
