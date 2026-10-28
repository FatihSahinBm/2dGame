extends SceneTree

# Real-window capture tool for Vlad Stage 3 Mechanisms (Weak Archway & Great Bell)
const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage_inst: Stage3ThroneRoom = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null
var cam: Camera2D = null
var archway: WeakArchwayTrap = null
var bell: CastleBellMechanism = null

var step: int = 0
var frame_counter: int = 0

func _init() -> void:
	print("--- STARTING MECHANISM REAL-WINDOW CAPTURE ---")

func _process(_delta: float) -> bool:
	frame_counter += 1
	match step:
		0:
			# Setup Arena 3 - Weak Archway Close-up (Intact)
			if frame_counter == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage_inst = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage_inst)
				
				player = stage_inst.player
				boss = stage_inst.vlad_boss
				archway = stage_inst.get_node_or_null("Environment/Arena3_Ramparts/WeakArchway") as WeakArchwayTrap
				bell = stage_inst.get_node_or_null("Environment/Arena4_BellTower/GreatBell") as CastleBellMechanism
				
				if stage_inst.dialogue_box:
					stage_inst.dialogue_box.visible = false
				if stage_inst.flashback_overlay:
					stage_inst.flashback_overlay.visible = false
				
				if boss and boss.has_method("set_form"):
					boss.set_form(2, false) # Werewolf form in Arena 3
				
				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = -2000
						cam.limit_right = 10000
						cam.limit_top = -2000
						cam.limit_bottom = 2000
						cam.zoom = Vector2(1.7, 1.7)
					player.global_position = Vector2(3260, 560)
				if boss:
					boss.global_position = Vector2(3460, 560)
			
			if frame_counter >= 15:
				_save("stage3_archway_closeup.png")
				step = 1
				frame_counter = 0

		1:
			# Arena 3 - Weak Archway Collapsed State
			if frame_counter == 1:
				if archway:
					archway.collapse(boss)
			
			# Wait 25 frames for bounce tween and dust particles
			if frame_counter >= 25:
				_save("stage3_archway_collapsed.png")
				step = 2
				frame_counter = 0

		2:
			# Arena 4 - Great Bell Close-up (Tower view)
			if frame_counter == 1:
				if boss and boss.has_method("set_form"):
					boss.set_form(3, false) # Bat form in Arena 4
				if player:
					player.global_position = Vector2(4850, 410)
					if cam:
						cam.zoom = Vector2(1.8, 1.8)
				if boss:
					boss.global_position = Vector2(4950, 360)
			
			if frame_counter >= 15:
				_save("stage3_bell_closeup.png")
				step = 3
				frame_counter = 0

		3:
			# Arena 4 - Bell Rung & Battle Scene (Bell swinging + acoustic shock)
			if frame_counter == 1:
				if bell:
					bell.ring_bell(player)
				if player:
					player.global_position = Vector2(4760, 560)
					if cam:
						cam.zoom = Vector2(1.15, 1.15)
				if boss:
					boss.global_position = Vector2(5050, 480)
			
			if frame_counter >= 15:
				_save("stage3_mechanisms_battle_view.png")
				print("--- ALL 4 MECHANISM SCREENSHOTS CAPTURED ---")
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
