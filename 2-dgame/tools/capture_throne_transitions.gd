class_name CaptureThroneTransitions
extends SceneTree

## tools/capture_throne_transitions.gd
## Captures sequential real-window render frames across the 3 arena boundaries:
## - Boundary 1-2 (X = 1250): Approach (1100), Threshold (1250), Exit (1400)
## - Boundary 2-3 (X = 2650): Approach (2500), Threshold (2650), Exit (2800)
## - Boundary 3-4 (X = 4050): Approach (3900), Threshold (4050), Exit (4200)

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage: Stage3ThroneRoom = null
var player: CharacterBody2D = null
var cam: Camera2D = null

var shots: Array[Dictionary] = [
	{ "filename": "transition_b12_approach_1100.png", "pos": Vector2(1100, 560), "desc": "Boundary 1-2 Approach (X=1100)" },
	{ "filename": "transition_b12_crossing_1250.png", "pos": Vector2(1250, 560), "desc": "Boundary 1-2 Crossing Threshold (X=1250)" },
	{ "filename": "transition_b12_entered_1400.png",  "pos": Vector2(1400, 560), "desc": "Boundary 1-2 Entered Arena 2 (X=1400)" },
	{ "filename": "transition_b23_approach_2500.png", "pos": Vector2(2500, 560), "desc": "Boundary 2-3 Approach (X=2500)" },
	{ "filename": "transition_b23_crossing_2650.png", "pos": Vector2(2650, 560), "desc": "Boundary 2-3 Crossing Threshold (X=2650)" },
	{ "filename": "transition_b23_entered_2800.png",  "pos": Vector2(2800, 560), "desc": "Boundary 2-3 Entered Arena 3 (X=2800)" },
	{ "filename": "transition_b34_approach_3900.png", "pos": Vector2(3900, 560), "desc": "Boundary 3-4 Approach (X=3900)" },
	{ "filename": "transition_b34_crossing_4050.png", "pos": Vector2(4050, 560), "desc": "Boundary 3-4 Crossing Threshold (X=4050)" },
	{ "filename": "transition_b34_entered_4200.png",  "pos": Vector2(4200, 560), "desc": "Boundary 3-4 Entered Arena 4 (X=4200)" }
]

var shot_idx: int = 0
var frame_counter: int = 0
var is_initialized: bool = false


func _init() -> void:
	print("--- STARTING THRONE ROOM ARENA TRANSITION CAPTURE TOOL ---")


func _process(_delta: float) -> bool:
	frame_counter += 1
	
	if not is_initialized:
		if frame_counter == 1:
			var packed: PackedScene = load(STAGE3_PATH) as PackedScene
			stage = packed.instantiate() as Stage3ThroneRoom
			root.add_child(stage)
			
			if stage.dialogue_box:
				stage.dialogue_box.queue_free()
				stage.dialogue_box = null
			if stage.flashback_overlay:
				stage.flashback_overlay.queue_free()
				stage.flashback_overlay = null
			if stage.hud:
				stage.hud.visible = false
			
			# Remove the fade-in black screen overlay created in _ready
			for child in stage.get_children():
				if child is CanvasLayer and child != stage.hud:
					child.queue_free()
			
			for tw in stage.get_tree().get_processed_tweens():
				tw.kill()
			
			player = stage.player
			player.can_move = false
			player.velocity = Vector2.ZERO
			
			cam = player.get_node_or_null("Camera2D") as Camera2D
			if cam:
				cam.offset = Vector2.ZERO
				cam.zoom = Vector2.ONE
				cam.position_smoothing_enabled = true
				cam.position_smoothing_speed = 8.0
				cam.limit_left = -10000000
				cam.limit_right = 10000000
				cam.limit_top = -10000000
				cam.limit_bottom = 10000000
				
			player.global_position = shots[0]["pos"]
			if cam:
				cam.reset_smoothing()
			
			print("Scene initialized. Preparing shots...")
		
		if frame_counter >= 15:
			is_initialized = true
			shot_idx = 0
			frame_counter = 0
		return false

	var shot: Dictionary = shots[shot_idx]
	player.global_position = shot["pos"]
	
	# Allow smoothing interpolation to settle (25 frames)
	if frame_counter >= 25:
		_save(shot["filename"], shot["desc"])
		shot_idx += 1
		frame_counter = 0
		
		if shot_idx >= shots.size():
			print("\nAll transition frames successfully captured to output directory.")
			stage.queue_free()
			quit(0)
			return true

	return false


func _save(filename: String, desc: String) -> void:
	var img: Image = root.get_texture().get_image()
	if not img:
		print("  [ERROR] Viewport texture was null for %s" % filename)
		return
	var dir: DirAccess = DirAccess.open("res://output")
	if not dir:
		DirAccess.make_dir_absolute("res://output")
	var path: String = "res://output/" + filename
	img.save_png(path)
	print("  [CAPTURED] %-42s -> %s" % [desc, path])
