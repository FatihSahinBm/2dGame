extends SceneTree

## res://tools/capture_egypt_screens.gd
## Bölüm 3 (Antik Mısır) sahnelerinin ekran görüntülerini output/egypt/ altına kaydeder (Epic 2D-143).
## Pencere gerekir (--headless kullanmayın):
##   Godot --path . --script res://tools/capture_egypt_screens.gd

const SHOTS: Array[Array] = [
	["res://scenes/levels/egypt/egypt_01_crimson_desert.tscn", Vector2(1150, 500), "egypt_01_desert.png"],
	["res://scenes/levels/egypt/egypt_02_monument_courtyard.tscn", Vector2(1300, 500), "egypt_02_courtyard.png"],
	["res://scenes/levels/egypt/egypt_03_cursed_tomb.tscn", Vector2(950, 500), "egypt_03_tomb.png"],
	["res://scenes/levels/egypt/egypt_04_sun_throne.tscn", Vector2(800, 500), "egypt_04_throne.png"],
]


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/egypt"))
	for shot: Array in SHOTS:
		var level: Node = (load(str(shot[0])) as PackedScene).instantiate()
		root.add_child(level)
		await process_frame
		var player: Node2D = level.get_node_or_null("CombatPlayer") as Node2D
		var dlg: Node = level.get_node_or_null("DialogueBox")
		if player:
			player.global_position = shot[1]
		for i: int in 40:
			if dlg and dlg.has_method("skip_dialogue"):
				dlg.skip_dialogue()
			await process_frame
		var img: Image = root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://../output/egypt/" + str(shot[2])))
		print("Saved ", shot[2])
		level.queue_free()
		await process_frame
	quit(0)
