extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage_inst: Stage3ThroneRoom = null
var player: Player = null
var boss: CharacterBody2D = null
var cam: Camera2D = null
var active_spear: Area2D = null

var captures_done: Dictionary = {}
var frame_tick: int = 0
var saved_count: int = 0

func _init() -> void:
	print("==================================================================")
	print("--- TASK 17.1: CAPTURING IN-GAME VLAD SPEAR THROW AUDIT FRAMES ---")
	print("==================================================================")

func _process(_delta: float) -> bool:
	frame_tick += 1
	
	if frame_tick == 1:
		var packed: PackedScene = load(STAGE3_PATH) as PackedScene
		stage_inst = packed.instantiate() as Stage3ThroneRoom
		root.add_child(stage_inst)
		
		player = stage_inst.player as Player
		boss = stage_inst.vlad_boss
		
		if stage_inst.dialogue_box: stage_inst.dialogue_box.visible = false
		if stage_inst.flashback_overlay: stage_inst.flashback_overlay.visible = false
		
		boss.is_active = true
		boss._is_in_cinematic = false
		boss.set_form(0, false)
		
		player.global_position = Vector2(850, 418)
		boss.global_position = Vector2(400, 560)
		boss.direction = 1
		boss._update_facing_direction()
		boss._target_node = player
		
		if player:
			cam = player.get_node_or_null("Camera2D") as Camera2D
			if cam:
				cam.position_smoothing_enabled = false
				cam.zoom = Vector2(1.2, 1.2)
		return false

	if frame_tick == 4:
		# Frame 0 / Hazırlık duruşunu yakala
		boss._execute_normal_spear_throw()
		_save("vlad_throw_1_hazirlik.png")
		captures_done["1_hazirlik"] = true
		return false

	if not boss or not is_instance_valid(boss):
		return false

	# Kamerayı Boss ve fırlatma bölgesini net gösterecek şekilde ortala
	if cam:
		cam.global_position = Vector2(boss.global_position.x + 120.0, 480.0)

	var cur_anim: StringName = boss.anim_sprite.animation
	var cur_frame: int = boss.anim_sprite.frame

	# 1. Hazırlık (Ready stance - Frame 0..1)
	if cur_anim == &"attack_throw" and cur_frame <= 1 and not captures_done.has("1_hazirlik"):
		_save("vlad_throw_1_hazirlik.png")
		captures_done["1_hazirlik"] = true

	# 2. Mızrağın geriye çekilmesi (Windup - Frame 4..6)
	if cur_anim == &"attack_throw" and cur_frame >= 4 and cur_frame <= 6 and not captures_done.has("2_geriye_cekilme"):
		_save("vlad_throw_2_geriye_cekilme.png")
		captures_done["2_geriye_cekilme"] = true

	# 3. Fırlatma öncesi (Pre-throw aim - Frame 9..10)
	if cur_anim == &"attack_throw" and cur_frame >= 9 and cur_frame <= 10 and not captures_done.has("3_firlatma_oncesi"):
		_save("vlad_throw_3_firlatma_oncesi.png")
		captures_done["3_firlatma_oncesi"] = true

	# 4. Mızrağın elden ayrıldığı kare (Release frame - Frame 11)
	if cur_anim == &"attack_throw" and cur_frame == 11 and not captures_done.has("4_elden_ayrilma_f11"):
		_save("vlad_throw_4_elden_ayrilma_f11.png")
		captures_done["4_elden_ayrilma_f11"] = true

	# 4b. Frame 12 (Elden tamamen çıkış ve boş el anı)
	if cur_anim == &"attack_throw" and cur_frame == 12 and not captures_done.has("4b_bos_el_f12"):
		_save("vlad_throw_4b_bos_el_f12.png")
		captures_done["4b_bos_el_f12"] = true

	# 5. Projectile'ın Vlad'dan uzaklaştığı an (Frame 14..18 ve havada uçan mızrak)
	if cur_anim == &"attack_throw" and cur_frame >= 14 and cur_frame <= 18 and not captures_done.has("5_projectile_uzaklasma"):
		_save("vlad_throw_5_projectile_uzaklasma.png")
		captures_done["5_projectile_uzaklasma"] = true

	# 6. Boş elle toparlanma ve bekleme duruşu (Frame 21..23)
	if cur_anim == &"attack_throw" and cur_frame >= 21 and not captures_done.has("6_toparlanma_gard"):
		_save("vlad_throw_6_toparlanma_gard.png")
		captures_done["6_toparlanma_gard"] = true

	if captures_done.size() >= 7 and (cur_anim != &"attack_throw" or cur_frame >= 23):
		print("--- ALL AUDIT SCREENSHOTS CAPTURED (COUNT: ", captures_done.size(), ") ---")
		quit(0)
		return true

	# Güvenlik zaman aşımı (180 fizik adımı ~ 3 saniye)
	if frame_tick > 180:
		print("--- TIMEOUT REACHED, TOTAL CAPTURED: ", captures_done.size(), " ---")
		quit(0)
		return true

	return false

func _save(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var dir_path: String = "c:/Projects/2dgame/2-dgame/output"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var full_path: String = "%s/%s" % [dir_path, filename]
	img.save_png(full_path)
	print("Saved screenshot: ", filename)
