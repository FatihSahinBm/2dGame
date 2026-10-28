extends SceneTree

const STAGE3_PATH = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage_instance: Node = null
var player: CharacterBody2D = null
var cam: Camera2D = null
var step: int = 0
var frame_counter: int = 0

func _init() -> void:
	print("--- CAPTURING STAGE 3 THRONE ROOM BASELINE ---")

func _process(_delta: float) -> bool:
	frame_counter += 1
	match step:
		0:
			if frame_counter == 1:
				var packed = load(STAGE3_PATH) as PackedScene
				stage_instance = packed.instantiate()
				root.add_child(stage_instance)
				player = stage_instance.get_node_or_null("CombatPlayer") as CharacterBody2D
				# Disable dialogue box during capture
				var diag = stage_instance.get_node_or_null("DialogueBox")
				if diag:
					diag.visible = false
				if player:
					cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.limit_left = 0
						cam.limit_right = 6000
						cam.limit_top = -200
						cam.limit_bottom = 700
						cam.zoom = Vector2(1.0, 1.0)
					player.global_position = Vector2(600, 560)
			if frame_counter >= 15:
				_save("throne_arena1_baseline.png")
				step = 1
				frame_counter = 0
		1:
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(1950, 560)
			if frame_counter >= 15:
				_save("throne_arena2_baseline.png")
				step = 2
				frame_counter = 0
		2:
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(3350, 560)
			if frame_counter >= 15:
				_save("throne_arena3_baseline.png")
				step = 3
				frame_counter = 0
		3:
			if frame_counter == 1:
				if player:
					player.global_position = Vector2(4850, 560)
			if frame_counter >= 15:
				_save("throne_arena4_baseline.png")
				print("--- BASELINE CAPTURED ---")
				quit(0)
				return true
	return false

func _save(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var dir_path: String = "c:/Projects/2dgame/2-dgame/output"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var full_path: String = "%s/%s" % [dir_path, filename]
	img.save_png(full_path)
	print("Saved: ", full_path)
