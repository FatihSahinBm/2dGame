extends SceneTree

## res://tools/capture_ww2_screens.gd
## Bölüm 4 (2. Dünya Savaşı) görsel doğrulaması (Epic 2D-144): her sahnenin ekran görüntüsünü
## output/ww2/ altına kaydeder ve iki otomatik denetim yapar:
##   1. Hizalama — her karakterin sprite'ındaki en alt opak satır (ayak) gövde orijinine ±4 px
##      oturuyor mu (FEET_Y / ayak kayması denetimi).
##   2. UI çakışması — boss can çubuğu HUD panelleriyle üst üste biniyor mu.
## Pencere gerekir (--headless kullanmayın):
##   Godot --path . --script res://tools/capture_ww2_screens.gd
## Çıkış kodu: 0 = tüm denetimler geçti, 1 = hata var.

const OUT_DIR: String = "res://../output/ww2/"
const SHOTS: Array[Array] = [
	["res://scenes/levels/ww2/stage_1_bombed_trenches.tscn", Vector2(1150, 500), "ww2_01_trenches.png"],
	["res://scenes/levels/ww2/stage_1_bombed_trenches.tscn", Vector2(3000, 500), "ww2_01_officer_gate.png"],
	["res://scenes/levels/ww2/stage_2_ruined_city_viaduct.tscn", Vector2(700, 320), "ww2_02_ruined_city.png"],
	["res://scenes/levels/ww2/stage_2_ruined_city_viaduct.tscn", Vector2(1800, 340), "ww2_02_viaduct_train.png"],
	["res://scenes/levels/ww2/stage_3_occult_lab.tscn", Vector2(950, 500), "ww2_03_gas_relays.png"],
	["res://scenes/levels/ww2/stage_3_occult_lab.tscn", Vector2(3000, 500), "ww2_03_lab_core.png"],
	["res://scenes/levels/ww2/stage_4_command_bunker_boss.tscn", Vector2(700, 500), "ww2_04_bunker_boss.png"],
	["res://scenes/levels/ww2/stage_5_memory_rift.tscn", Vector2(600, 500), "ww2_05_memory_rift.png"],
]

var failures: int = 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for shot: Array in SHOTS:
		var level: Node = (load(str(shot[0])) as PackedScene).instantiate()
		if "autosave_on_complete" in level:
			level.autosave_on_complete = false
		root.add_child(level)
		await process_frame
		var player: Node2D = level.get_node_or_null("CombatPlayer") as Node2D
		var dlg: Node = level.get_node_or_null("DialogueBox")
		if player:
			player.global_position = shot[1]
		for i: int in 50:
			if dlg and dlg.has_method("skip_dialogue"):
				dlg.skip_dialogue()
			await process_frame
		var img: Image = root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + str(shot[2])))
		print("Saved ", shot[2])
		_check_feet(level, str(shot[2]))
		_check_ui_overlap(level, str(shot[2]))
		level.queue_free()
		await process_frame
	print("--- WW2 VISUAL AUDIT: %s ---" % ("OK" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)


## Karakter ayakları: sprite'ın en alt opak satırı gövde orijinine oturmalı
func _check_feet(level: Node, label: String) -> void:
	var worst: float = 0.0
	var count: int = 0
	for body: Node in level.find_children("*", "CharacterBody2D", true, false):
		if body.is_in_group("player"):
			continue
		var sprite: AnimatedSprite2D = body.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
		if sprite == null:
			sprite = body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"idle"):
			continue
		var tex: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle", 0)
		var image: Image = tex.get_image() if tex else null
		if image == null:
			continue
		var bottom: int = -1
		for y: int in range(image.get_height() - 1, -1, -1):
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.1:
					bottom = y
					break
			if bottom >= 0:
				break
		var scale_y: float = absf(sprite.global_scale.y)
		var feet_world: float = sprite.global_position.y + (float(bottom + 1) - float(image.get_height()) * 0.5) * scale_y
		worst = maxf(worst, absf(feet_world - (body as Node2D).global_position.y))
		count += 1
	_check(worst <= 4.0, "%s: %d karakterin ayağı zemine hizalı (en kötü sapma %.1f px)" % [label, count, worst])


## Boss can çubuğu HUD panelleriyle çakışmamalı
func _check_ui_overlap(level: Node, label: String) -> void:
	var hud: Node = level.get_node_or_null("FantasyHUD")
	var bars: Array[Control] = []
	for layer: Node in level.get_children():
		if layer is EgyptBossBar:
			for c: Node in layer.get_children():
				if c is Control and (c as Control).visible:
					bars.append(c as Control)
	if bars.is_empty() or hud == null:
		_check(true, "%s: boss çubuğu yok / UI çakışması denetlenecek öğe yok" % label)
		return
	var overlaps: Array[String] = []
	for c: Node in hud.find_children("*", "Panel", true, false) + hud.find_children("*", "PanelContainer", true, false):
		var ctrl: Control = c as Control
		if not ctrl.is_visible_in_tree():
			continue
		for bar: Control in bars:
			if bar.get_global_rect().intersects(ctrl.get_global_rect()):
				overlaps.append(str(ctrl.name))
	_check(overlaps.is_empty(), "%s: boss çubuğu HUD ile çakışmıyor %s" % [label, str(overlaps)])
