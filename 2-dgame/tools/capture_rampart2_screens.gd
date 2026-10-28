extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage_inst: Stage3ThroneRoom = null
var player: Player = null
var boss: CharacterBody2D = null
var rampart2: StaticBody2D = null
var ground3: StaticBody2D = null
var cam: Camera2D = null

var step: int = 0
var frame_counter: int = 0

func _init() -> void:
	print("--- STARTING RAMPART2 JUMP ACCESSIBILITY SCREEN CAPTURE ---")

func _process(_delta: float) -> bool:
	frame_counter += 1
	match step:
		0:
			# State 1: Player on Ground3 below Rampart2
			if frame_counter == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage_inst = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage_inst)
				
				player = stage_inst.player as Player
				boss = stage_inst.vlad_boss
				rampart2 = stage_inst.get_node_or_null("Environment/Arena3_Ramparts/Rampart2") as StaticBody2D
				ground3 = stage_inst.get_node_or_null("Environment/Arena3_Ramparts/Ground3") as StaticBody2D
				
				if stage_inst.dialogue_box:
					stage_inst.dialogue_box.visible = false
				if stage_inst.flashback_overlay:
					stage_inst.flashback_overlay.visible = false
				
				if boss:
					boss.is_active = true
					boss._is_in_cinematic = false
					boss.global_position = Vector2(3400, 560)
				
				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = 2500
						cam.limit_right = 4500
						cam.limit_top = -200
						cam.limit_bottom = 800
						cam.zoom = Vector2(1.25, 1.25)
					player.global_position = Vector2(3750, 560)
					player.velocity = Vector2.ZERO
					player.facing_dir = 1.0
					if player.visual_node:
						player.visual_node.scale.x = 1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("combat_idle"):
						player.anim_sprite.play("combat_idle")

			if cam:
				cam.global_position = Vector2(3750, 480)
			
			if frame_counter >= 15:
				_save("rampart2_1_ground_before_jump.png")
				step = 1
				frame_counter = 0

		1:
			# State 2: Player landed on Rampart2 with Single Jump
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(3750, 418) # Landed firmly on Rampart2 surface
					player.velocity = Vector2.ZERO
					player.facing_dir = 1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("combat_idle"):
						player.anim_sprite.play("combat_idle")

			if cam:
				cam.global_position = Vector2(3750, 460)

			if frame_counter >= 15:
				_save("rampart2_2_single_jump_landed.png")
				step = 2
				frame_counter = 0

		2:
			# State 3: Player walking along Rampart2 surface
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(3820, 418) # Walking rightward along platform
					player.velocity = Vector2(120, 0)
					player.facing_dir = 1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("run"):
						player.anim_sprite.play("run")

			if cam:
				cam.global_position = Vector2(3750, 460)

			if frame_counter >= 15:
				_save("rampart2_3_walking_on_platform.png")
				step = 3
				frame_counter = 0

		3:
			# State 4: Player drop-through back to Ground3
			if frame_counter == 1:
				if player and rampart2:
					player._clear_drop_through_platform()
					player.global_position = Vector2(3750, 560) # Ground3 surface
					player.velocity = Vector2.ZERO
					player.facing_dir = -1.0
					if player.visual_node:
						player.visual_node.scale.x = -1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("combat_idle"):
						player.anim_sprite.play("combat_idle")

			if cam:
				cam.global_position = Vector2(3750, 480)

			if frame_counter >= 15:
				_save("rampart2_4_drop_through_ground.png")
				print("--- ALL 4 RAMPART2 SCREENSHOTS CAPTURED SUCCESSFULLY ---")
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
