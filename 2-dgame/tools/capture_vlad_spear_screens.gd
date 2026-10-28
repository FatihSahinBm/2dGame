extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage_inst: Stage3ThroneRoom = null
var player: Player = null
var boss: CharacterBody2D = null
var cam: Camera2D = null
var step: int = 0
var frame_counter: int = 0
var active_spear: Area2D = null

func _init() -> void:
	print("--- STARTING VLAD HUMAN FORM SPEAR THROW CAPTURE ---")

func _process(_delta: float) -> bool:
	frame_counter += 1
	match step:
		0:
			# Adım 0: Sahne Kurulumu ve Adım 1 Hazırlığı (Telegraph)
			if frame_counter == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage_inst = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage_inst)
				
				player = stage_inst.player as Player
				boss = stage_inst.vlad_boss
				
				if stage_inst.dialogue_box:
					stage_inst.dialogue_box.visible = false
				if stage_inst.flashback_overlay:
					stage_inst.flashback_overlay.visible = false
				
				boss.is_active = true
				boss._is_in_cinematic = false
				boss.set_form(0, false) # Normal Form
				
				# Kamera odağı PlatformLeft ile Boss arasındaki ortak görüş açısına ayarlanır
				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = -200
						cam.limit_right = 2000
						cam.limit_top = -200
						cam.limit_bottom = 800
						cam.zoom = Vector2(1.2, 1.2)
					player.global_position = Vector2(240, 418) # On PlatformLeft
					player.facing_dir = 1.0
					if player.visual_node: player.visual_node.scale.x = 1.0
				
				if boss:
					boss.global_position = Vector2(480, 560)
					boss.direction = -1
					boss._update_facing_direction()
					boss._target_node = player
					boss._execute_normal_spear_throw()
			
			# Kamerayı oyuncu ve boss'un tam ortasında tut
			if cam and player and boss:
				cam.global_position = Vector2(300, 460)
			
			if frame_counter >= 15:
				_save("vlad_spear_1_telegraph.png")
				step = 1
				frame_counter = 0

		1:
			# Adım 1: Mızrağın Havada Uçuşu (Active Attack / Flight)
			if frame_counter == 1:
				if boss:
					boss._clear_spear_throw_telegraph()
					if boss.spear_scene:
						active_spear = boss.spear_scene.instantiate() as Area2D
						stage_inst.add_child(active_spear)
						var spawn_pos: Vector2 = boss.global_position + Vector2(-25.0, -45.0)
						var target_pos: Vector2 = Vector2(240, 418)
						var shoot_dir: Vector2 = (target_pos - spawn_pos).normalized()
						active_spear.setup(spawn_pos + shoot_dir * 120.0, shoot_dir, 35, boss)
			
			if cam: cam.global_position = Vector2(300, 460)
			
			if frame_counter >= 15:
				_save("vlad_spear_2_thrown.png")
				step = 2
				frame_counter = 0

		2:
			# Adım 2: Oyuncunun Zıplayarak Mızraktan Kaçışı (Dodge / Jump Evade)
			if frame_counter == 1:
				if is_instance_valid(active_spear):
					active_spear.queue_free()
				
				if player:
					player.global_position = Vector2(240, 320) # Zıplamış
					player.facing_dir = 1.0
					if player.visual_node: player.visual_node.scale.x = 1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("jump"):
						player.anim_sprite.play("jump")
				
				if boss and boss.spear_scene:
					active_spear = boss.spear_scene.instantiate() as Area2D
					stage_inst.add_child(active_spear)
					var spawn_pos: Vector2 = boss.global_position + Vector2(-25.0, -45.0)
					var target_pos: Vector2 = Vector2(240, 418)
					var shoot_dir: Vector2 = (target_pos - spawn_pos).normalized()
					active_spear.setup(Vector2(240, 418), shoot_dir, 35, boss)
			
			if cam: cam.global_position = Vector2(300, 460)
			
			if frame_counter >= 15:
				_save("vlad_spear_3_dodge.png")
				step = 3
				frame_counter = 0

		3:
			# Adım 3: Oyuncunun Zemine İnmesi ve Normal Yakın Dövüşe Dönüş
			if frame_counter == 1:
				if is_instance_valid(active_spear):
					active_spear.queue_free()
				
				if player:
					player.global_position = Vector2(410, 560)
					player.facing_dir = 1.0
					if player.visual_node: player.visual_node.scale.x = 1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("combat_idle"):
						player.anim_sprite.play("combat_idle")
				
				if boss:
					boss.global_position = Vector2(490, 560)
					boss.direction = -1
					boss._update_facing_direction()
					boss._execute_normal_attack(true) # Thrust melee
			
			if cam: cam.global_position = Vector2(380, 480)
			
			if frame_counter >= 15:
				_save("vlad_spear_4_ground_combat.png")
				print("--- ALL 4 SPEAR THROW SCREENSHOTS CAPTURED SUCCESSFULLY ---")
				quit(0)
				return true

	return false

func _save(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var dir_path: String = "c:/Projects/2dgame/2-dgame/output"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var full_path: String = "%s/%s" % [dir_path, filename]
	img.save_png(full_path)
	print("Saved screenshot: ", full_path)
