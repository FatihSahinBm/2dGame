extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage_inst: Stage3ThroneRoom = null
var player: Player = null
var boss: CharacterBody2D = null
var platform_left: StaticBody2D = null
var platform_right: StaticBody2D = null
var ground1: StaticBody2D = null
var cam: Camera2D = null

var step: int = 0
var frame_counter: int = 0

func _init() -> void:
	print("--- STARTING PLAYER ONE-WAY PLATFORM DROP-DOWN SCREEN CAPTURE ---")

func _process(_delta: float) -> bool:
	frame_counter += 1
	match step:
		0:
			# Setup scene and state 1: Standing on PlatformLeft
			if frame_counter == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage_inst = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage_inst)
				
				player = stage_inst.player as Player
				boss = stage_inst.vlad_boss
				platform_left = stage_inst.get_node_or_null("Environment/Arena1_ThroneRoom/PlatformLeft") as StaticBody2D
				platform_right = stage_inst.get_node_or_null("Environment/Arena1_ThroneRoom/PlatformRight") as StaticBody2D
				ground1 = stage_inst.get_node_or_null("Environment/Arena1_ThroneRoom/Ground1") as StaticBody2D
				
				if stage_inst.dialogue_box:
					stage_inst.dialogue_box.visible = false
				if stage_inst.flashback_overlay:
					stage_inst.flashback_overlay.visible = false
				
				if boss:
					boss.is_active = true
					boss._is_in_cinematic = false
					boss.global_position = Vector2(600, 560)
				
				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = -200
						cam.limit_right = 2000
						cam.limit_top = -200
						cam.limit_bottom = 800
						cam.zoom = Vector2(1.25, 1.25)
					player.global_position = Vector2(200, 418)
					player.velocity = Vector2.ZERO
					player.facing_dir = 1.0
					if player.visual_node:
						player.visual_node.scale.x = 1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("combat_idle"):
						player.anim_sprite.play("combat_idle")

			if cam:
				cam.global_position = Vector2(280, 480)
			
			if frame_counter >= 15:
				_save("player_dropdown_1_standing_on_platform.png")
				step = 1
				frame_counter = 0

		1:
			# State 2: Dropping through PlatformLeft (mid-fall through platform body)
			if frame_counter == 1:
				if player and platform_left:
					player._start_drop_through_platform(platform_left)
					player.global_position = Vector2(200, 455) # Passing through platform bottom
					player.velocity.y = 220.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("jump"):
						player.anim_sprite.play("jump")

			if cam:
				cam.global_position = Vector2(280, 480)

			if frame_counter >= 15:
				_save("player_dropdown_2_passing_through.png")
				step = 2
				frame_counter = 0

		2:
			# State 3: Landed safely on Ground1 below PlatformLeft
			if frame_counter == 1:
				if player:
					player._clear_drop_through_platform()
					player.global_position = Vector2(200, 560) # Ground1 surface
					player.velocity = Vector2.ZERO
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("idle"):
						player.anim_sprite.play("idle")

			if cam:
				cam.global_position = Vector2(280, 510)

			if frame_counter >= 15:
				_save("player_dropdown_3_landed_on_ground.png")
				step = 3
				frame_counter = 0

		3:
			# State 4: Normal collision maintained with other platform (e.g. PlatformRight)
			if frame_counter == 1:
				if player and platform_right:
					player.global_position = Vector2(980, 418) # On PlatformRight
					player.velocity = Vector2.ZERO
					player.facing_dir = -1.0
					if player.visual_node:
						player.visual_node.scale.x = -1.0
					if player.anim_sprite and player.anim_sprite.sprite_frames.has_animation("combat_idle"):
						player.anim_sprite.play("combat_idle")

			if cam:
				cam.global_position = Vector2(900, 480)

			if frame_counter >= 15:
				_save("player_dropdown_4_other_platform_normal_collision.png")
				print("--- ALL 4 DROP-DOWN SCREENSHOTS CAPTURED SUCCESSFULLY ---")
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
