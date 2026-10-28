class_name CaptureThroneParallaxScreens
extends SceneTree

## tools/capture_throne_parallax_screens.gd
## Real-window capture tool for Vlad Stage 3 Throne Room Parallax & Depth Layers

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage: Stage3ThroneRoom = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null
var cam: Camera2D = null

var step: int = 0
var frame_counter: int = 0


func _init() -> void:
	print("--- STARTING THRONE ROOM PARALLAX REAL-WINDOW CAPTURE ---")


func _process(_delta: float) -> bool:
	frame_counter += 1
	match step:
		0:
			# Setup Scene and Arena 1 Wide View (Throne Room)
			if frame_counter == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage)
				
				player = stage.player
				boss = stage.vlad_boss
				
				if stage.dialogue_box:
					stage.dialogue_box.visible = false
				if stage.flashback_overlay:
					stage.flashback_overlay.visible = false
				
				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.limit_top = -2000
						cam.limit_bottom = 2000
						cam.zoom = Vector2(1.0, 1.0)
					player.global_position = Vector2(600, 560)
				if boss:
					boss.global_position = Vector2(920, 560)
			
			if frame_counter >= 15:
				_save("stage3_arena1_throne_wide.png")
				step = 1
				frame_counter = 0

		1:
			# Arena 1 Combat Framing Battle View (Player vs Vlad)
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(500, 560)
					if cam:
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.zoom = Vector2(1.15, 1.15)
				if boss:
					boss.global_position = Vector2(750, 560)
			
			if frame_counter >= 15:
				_save("stage3_combat_framing_battle.png")
				step = 2
				frame_counter = 0

		2:
			# Transition Boundary: Arena 1 to Arena 2 (X = 1250)
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(1250, 560)
					if cam:
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.zoom = Vector2(1.0, 1.0)
				if boss:
					boss.global_position = Vector2(1450, 560)
			
			if frame_counter >= 15:
				_save("stage3_transition_arena1_to_arena2.png")
				step = 3
				frame_counter = 0

		3:
			# Arena 2 Blood Hall View
			if frame_counter == 1:
				if boss and boss.has_method("set_form"):
					boss.set_form(1, false) # Vampire form
				if player:
					player.global_position = Vector2(1850, 560)
					if cam:
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.zoom = Vector2(1.0, 1.0)
				if boss:
					boss.global_position = Vector2(2150, 560)
			
			if frame_counter >= 15:
				_save("stage3_arena2_blood_hall.png")
				step = 4
				frame_counter = 0

		4:
			# Transition Boundary: Arena 2 to Arena 3 (X = 2650)
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(2650, 560)
					if cam:
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.zoom = Vector2(1.0, 1.0)
				if boss:
					boss.global_position = Vector2(2850, 560)
			
			if frame_counter >= 15:
				_save("stage3_transition_arena2_to_arena3.png")
				step = 5
				frame_counter = 0

		5:
			# Arena 3 Ramparts View
			if frame_counter == 1:
				if boss and boss.has_method("set_form"):
					boss.set_form(2, false) # Werewolf form
				if player:
					player.global_position = Vector2(3300, 560)
					if cam:
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.zoom = Vector2(1.0, 1.0)
				if boss:
					boss.global_position = Vector2(3650, 560)
			
			if frame_counter >= 15:
				_save("stage3_arena3_ramparts.png")
				step = 6
				frame_counter = 0

		6:
			# Arena 4 Bell Tower View
			if frame_counter == 1:
				if boss and boss.has_method("set_form"):
					boss.set_form(3, false) # Bat form
				if player:
					player.global_position = Vector2(4850, 560)
					if cam:
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.zoom = Vector2(1.0, 1.0)
				if boss:
					boss.global_position = Vector2(4850, 360)
			
			if frame_counter >= 15:
				_save("stage3_arena4_belltower.png")
				print("--- ALL 7 REAL-WINDOW SCREENSHOTS CAPTURED SUCCESSFULLY ---")
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
