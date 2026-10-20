extends Node

func _ready() -> void:
	print("--- CAPTURING LEVEL 02 NOW ---")
	get_viewport().size = Vector2i(1280, 720)
	var scene = load("res://scenes/levels/stoneage/stoneage_02_silent_valley.tscn").instantiate()
	add_child(scene)
	
	var player = scene.get_node("CombatPlayer")
	
	# Positions to capture
	var positions = [
		{"name": "capture_trunk_x1120.png", "x": 1120.0},
		{"name": "capture_seam_x900.png", "x": 900.0},
		{"name": "capture_exploration_x1020.png", "x": 1020.0}
	]
	
	var cam = Camera2D.new()
	cam.name = "CaptureCam"
	scene.add_child(cam)
	
	for shot in positions:
		player.position.x = shot["x"]
		player.position.y = 530.0
		cam.global_position = Vector2(shot["x"], 480.0)
		
		for f in range(10):
			await get_tree().process_frame
			
		var img = get_viewport().get_texture().get_image()
		if img:
			img.save_png(shot["name"])
			print("SAVED: " + shot["name"])
			
	print("--- CAPTURE COMPLETE ---")
	get_tree().quit(0)
