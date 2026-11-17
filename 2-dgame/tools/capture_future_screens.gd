extends SceneTree

## res://tools/capture_future_screens.gd
## Bölüm 5 (Distopik Gelecek) görsel doğrulaması (Epic 2D-158). Ekran görüntülerini output/future/
## altına kaydeder ve dört otomatik denetim yapar:
##   1. Hizalama — yerdeki her karakterin sprite'ındaki en alt opak satır (ayak) gövde orijinine
##      ±4 px oturuyor mu (FEET_Y / ayak kayması).
##   2. UI çakışması — boss / mini-boss can çubuğu HUD panelleriyle üst üste biniyor mu.
##   3. Vlad / Kan Şövalyesi görsel tutarlılığı — aynı zemin çizgisinde yan yana dizilim
##      (future_lineup.png): AI Lord formları Vlad'a göre 0.8–1.8x, mini-bosslar 0.6–1.6x,
##      standart düşman/NPC'ler Kan Şövalyesi'ne göre 0.35–1.3x dünya yüksekliğinde.
##   4. Temiz alfa — her yeni sprite karesinin köşeleri tamamen saydam (arka plan temizlenmiş).
## Pencere gerekir (--headless kullanmayın):
##   Godot --path . --script res://tools/capture_future_screens.gd
## Çıkış kodu: 0 = tüm denetimler geçti, 1 = hata var.

const OUT_DIR: String = "res://../output/future/"
const AiLordPhases = preload("res://scripts/enemies/future/ai_lord_phases.gd")
const LV: String = "res://scenes/levels/future/"
const SHOTS: Array[Array] = [
	[LV + "stage_1_neon_ruins.tscn", Vector2(1150, 470), "future_01_rooftops.png", ""],
	[LV + "stage_1_neon_ruins.tscn", Vector2(4150, 540), "future_01_metro_shelter.png", ""],
	[LV + "stage_2_temporal_assembly.tscn", Vector2(1300, 520), "future_02_conveyors.png", ""],
	[LV + "stage_2_temporal_assembly.tscn", Vector2(2950, 540), "future_02_presses.png", ""],
	[LV + "stage_2_temporal_assembly.tscn", Vector2(4150, 540), "future_02_stamped_mold.png", ""],
	[LV + "stage_2_temporal_assembly.tscn", Vector2(4950, 540), "future_02_chrono_warden.png", "start_warden_fight"],
	[LV + "stage_3_resistance_citadel.tscn", Vector2(1250, 540), "future_03_laser_corridor.png", ""],
	[LV + "stage_3_resistance_citadel.tscn", Vector2(3000, 540), "future_03_engineers.png", ""],
	[LV + "stage_3_resistance_citadel.tscn", Vector2(4850, 540), "future_03_aegis.png", "start_aegis_fight"],
	[LV + "stage_4_ai_lord_citadel.tscn", Vector2(860, -100), "future_04_tower_climb.png", ""],
	[LV + "stage_4_ai_lord_citadel.tscn", Vector2(700, -1360), "future_04_ai_lord_throne.png", "start_boss_fight"],
	[LV + "stage_5_sword_shattering.tscn", Vector2(700, 540), "future_05_sword_shattering.png", ""],
]
const LINEUP: Array[Array] = [
	# [sahne, etiket, grup: "ref_boss" | "ref_enemy" | "boss" | "mini" | "enemy"]
	["res://scenes/enemies/vlad_boss.tscn", "Vlad", "ref_boss"],
	["res://scenes/enemies/blood_knight.tscn", "BloodKnight", "ref_enemy"],
	["res://scenes/enemies/future/ai_lord.tscn", "AiLord_F1", "boss"],
	["res://scenes/enemies/future/ai_lord.tscn", "AiLord_F2", "boss"],
	["res://scenes/enemies/future/ai_lord.tscn", "AiLord_F3", "boss"],
	["res://scenes/enemies/future/chrono_warden_mech.tscn", "ChronoWarden", "mini"],
	["res://scenes/enemies/future/hydraulic_juggernaut.tscn", "Juggernaut", "enemy"],
	["res://scenes/enemies/future/cyber_enforcer.tscn", "Enforcer", "enemy"],
	["res://scenes/enemies/future/cyber_hound.tscn", "Hound", "enemy"],
	["res://scenes/allies/resistance_fighter.tscn", "Fighter", "enemy"],
	["res://scenes/allies/resistance_engineer.tscn", "Engineer", "enemy"],
]
const FORM_FRAMES: Dictionary = {
	"AiLord_F2": "res://assets/characters/future/ai_lord_titan/ai_lord_titan_frames.tres",
	"AiLord_F3": "res://assets/characters/future/ai_lord_singularity/ai_lord_singularity_frames.tres",
}

var failures: int = 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for shot: Array in SHOTS:
		await _shoot(shot)
	await _lineup()
	_check_alpha()
	print("--- FUTURE VISUAL AUDIT: %s ---" % ("OK" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)


func _shoot(shot: Array) -> void:
	var level: Node = (load(str(shot[0])) as PackedScene).instantiate()
	if "autosave_on_complete" in level:
		level.autosave_on_complete = false
	root.add_child(level)
	await process_frame
	var player: Node2D = level.get_node_or_null("CombatPlayer") as Node2D
	var dlg: Node = level.get_node_or_null("DialogueBox")
	if player:
		player.global_position = shot[1]
	if not str(shot[3]).is_empty() and level.has_method(str(shot[3])):
		level.call(str(shot[3]))
	for i: int in 60:
		if dlg and dlg.has_method("skip_dialogue"):
			dlg.skip_dialogue()
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + str(shot[2])))
	print("Saved ", shot[2])
	_check_feet(level, str(shot[2]))
	_check_ui_overlap(level, str(shot[2]))
	level.queue_free()
	await process_frame


func _sprite_of(body: Node) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = body.get_node_or_null("Visual/AnimatedSprite2D") as AnimatedSprite2D
	return sprite if sprite else body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


## Kare görüntüsünde en üst/alt opak satır
func _opaque_rows(image: Image) -> Vector2i:
	var top: int = -1
	var bottom: int = -1
	for y: int in image.get_height():
		for x: int in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a > 0.3:
				if top < 0:
					top = y
				bottom = y
				break
	return Vector2i(top, bottom)


## Karakter ayakları: sprite'ın en alt opak satırı gövde orijinine oturmalı (yerdeki birimler)
func _check_feet(level: Node, label: String) -> void:
	var worst: float = 0.0
	var count: int = 0
	for body: Node in level.find_children("*", "CharacterBody2D", true, false):
		if body.is_in_group("player") or ("is_flying" in body and bool(body.is_flying)) or ("hovering" in body and bool(body.hovering)):
			continue
		if body is CyberFlyingBug or body.is_in_group("aegis_drones"):
			continue
		var sprite: AnimatedSprite2D = _sprite_of(body)
		if sprite == null or sprite.sprite_frames == null:
			continue
		var anim: StringName = sprite.animation
		var tex: Texture2D = sprite.sprite_frames.get_frame_texture(anim, 0)
		var image: Image = tex.get_image() if tex else null
		if image == null:
			continue
		var rows: Vector2i = _opaque_rows(image)
		var feet_world: float = sprite.global_position.y + (float(rows.y + 1) - float(image.get_height()) * 0.5) * absf(sprite.global_scale.y)
		worst = maxf(worst, absf(feet_world - (body as Node2D).global_position.y))
		count += 1
	_check(worst <= 4.0, "%s: %d karakterin ayağı zemine hizalı (en kötü sapma %.1f px)" % [label, count, worst])


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


## Vlad / Kan Şövalyesi ile yan yana dizilim ve dünya yüksekliği oranları
func _lineup() -> void:
	var stage: Node2D = Node2D.new()
	root.add_child(stage)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.16)
	bg.position = Vector2(-200, -400)
	bg.size = Vector2(2600, 700)
	stage.add_child(bg)
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(860, -90)
	cam.zoom = Vector2(0.62, 0.62)
	stage.add_child(cam)
	cam.make_current()
	var heights: Dictionary = {}
	var x: float = 0.0
	for spec: Array in LINEUP:
		var n: Node2D = (load(str(spec[0])) as PackedScene).instantiate() as Node2D
		n.process_mode = Node.PROCESS_MODE_DISABLED
		stage.add_child(n)
		n.position = Vector2(x, 0)
		var sprite: AnimatedSprite2D = _sprite_of(n)
		if FORM_FRAMES.has(spec[1]) and sprite:
			sprite.sprite_frames = load(str(FORM_FRAMES[spec[1]])) as SpriteFrames
			sprite.position.y = AiLordPhases.sprite_offset_y(2 if spec[1] == "AiLord_F2" else 3, absf(sprite.scale.y))
		if sprite and sprite.sprite_frames:
			var anim: StringName = &"idle" if sprite.sprite_frames.has_animation(&"idle") else sprite.sprite_frames.get_animation_names()[0]
			if spec[1] == "AiLord_F2":
				anim = &"heavy_walk"
			sprite.animation = anim
			var image: Image = sprite.sprite_frames.get_frame_texture(anim, 0).get_image()
			var rows: Vector2i = _opaque_rows(image)
			heights[spec[1]] = float(rows.y - rows.x + 1) * absf(sprite.scale.y) * absf(sprite.get_parent().scale.y if sprite.get_parent() is Node2D else 1.0)
		var label: Label = Label.new()
		label.text = str(spec[1])
		label.position = Vector2(x - 40, 12)
		stage.add_child(label)
		x += 175.0
	for i: int in 10:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + "future_lineup.png"))
	print("Saved future_lineup.png ", heights)
	var vlad: float = float(heights.get("Vlad", 1.0))
	var knight: float = float(heights.get("BloodKnight", 1.0))
	for spec: Array in LINEUP:
		var h: float = float(heights.get(spec[1], 0.0))
		match str(spec[2]):
			"boss":
				_check(h / vlad >= 0.8 and h / vlad <= 1.8, "Vlad tutarlılığı: %s yüksekliği Vlad'ın %.2fx'i" % [spec[1], h / vlad])
			"mini":
				_check(h / vlad >= 0.6 and h / vlad <= 1.6, "Vlad tutarlılığı: %s yüksekliği Vlad'ın %.2fx'i" % [spec[1], h / vlad])
			"enemy":
				_check(h / knight >= 0.35 and h / knight <= 1.3, "Kan Şövalyesi tutarlılığı: %s yüksekliği şövalyenin %.2fx'i" % [spec[1], h / knight])
	stage.queue_free()
	await process_frame


## Her yeni sprite sheet'inin her hücre köşesi saydam (arka plan temizlenmiş, RGBA)
func _check_alpha() -> void:
	var bad: Array[String] = []
	var dir: String = "res://assets/characters/future"
	for entity: String in DirAccess.get_directories_at(dir):
		var sheet: Texture2D = load("%s/%s/%s_sheet.png" % [dir, entity, entity]) as Texture2D
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/%s_manifest.json" % [dir, entity, entity])) as Dictionary
		if sheet == null or manifest.is_empty():
			bad.append(entity)
			continue
		var img: Image = sheet.get_image()
		var cw: int = int(manifest["frame_size"][0])
		var ch: int = int(manifest["frame_size"][1])
		for row: int in (manifest["animations"] as Array).size():
			for col: int in 16:
				for c: Vector2i in [Vector2i(0, 0), Vector2i(cw - 1, 0)]:
					if img.get_pixel(col * cw + c.x, row * ch + c.y).a > 0.05:
						if not bad.has(entity):
							bad.append(entity)
	_check(bad.is_empty() and img_count(dir) >= 13, "13 sprite sheet'inin hücre köşeleri saydam (temiz alfa) %s" % str(bad))


func img_count(dir: String) -> int:
	return DirAccess.get_directories_at(dir).size()
