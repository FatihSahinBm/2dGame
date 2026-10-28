extends SceneTree

# Real-window capture tool for Vlad Stage 3 Throne Room (Ground & Platforms Visual Renewal)
const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage_inst: Stage3ThroneRoom = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null
var cam: Camera2D = null
var step: int = 0
var frame_counter: int = 0

func _init() -> void:
	print("--- STARTING THRONE ROOM REAL-WINDOW CAPTURE ---")

func _process(_delta: float) -> bool:
	frame_counter += 1
	match step:
		0:
			# Setup Scene and Arena 1 Overview
			if frame_counter == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage_inst = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage_inst)
				
				player = stage_inst.player
				boss = stage_inst.vlad_boss
				
				# Hide dialogue box and flash overlay for clean view
				if stage_inst.dialogue_box:
					stage_inst.dialogue_box.visible = false
				if stage_inst.flashback_overlay:
					stage_inst.flashback_overlay.visible = false
				
				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.limit_top = -2000
						cam.limit_bottom = 2000
						cam.zoom = Vector2(1.0, 1.0)
					player.global_position = Vector2(400, 560)
				if boss:
					boss.global_position = Vector2(900, 560)
			
			if frame_counter >= 15:
				_save("stage3_throne_overview.png")
				step = 1
				frame_counter = 0

		1:
			# Arena 1 Combat Framing (Player & Boss facing each other)
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(550, 560)
					if cam:
						cam.zoom = Vector2(1.15, 1.15)
				if boss:
					boss.global_position = Vector2(800, 560)
			
			if frame_counter >= 15:
				_save("stage3_boss_battle_arena1.png")
				step = 2
				frame_counter = 0

		2:
			# Arena 3 Ramparts with Werewolf / Vampire form
			if frame_counter == 1:
				if boss and boss.has_method("set_form"):
					boss.set_form(2, false) # Werewolf form
				if player:
					player.global_position = Vector2(3250, 560)
					if cam:
						cam.zoom = Vector2(1.05, 1.05)
				if boss:
					boss.global_position = Vector2(3550, 560)
			
			if frame_counter >= 15:
				_save("stage3_boss_arena_form.png")
				step = 3
				frame_counter = 0

		3:
			# High-detail Platform and Ground Close-up
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(980, 500)
					if cam:
						cam.zoom = Vector2(2.0, 2.0)
			
			if frame_counter >= 15:
				_save("stage3_platform_closeup.png")
				print("--- ALL 4 SCREENSHOTS CAPTURED SUCCESSFULLY ---")
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
