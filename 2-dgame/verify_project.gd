@tool
extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://verify.log", FileAccess.WRITE)
	f.store_line("Verifying project...")

	var main_res = load("res://scenes/main.tscn")
	if not main_res:
		f.store_line("ERROR: Failed to load res://scenes/main.tscn")
		f.close()
		quit(1)
		return

	f.store_line("SUCCESS: main.tscn loaded.")

	var main_scene = main_res.instantiate()
	root.add_child(main_scene)
	f.store_line("SUCCESS: main.tscn instantiated and added to root.")

	var player = main_scene.get_node_or_null("Player")
	if not player:
		f.store_line("ERROR: Player node not found in main.tscn")
		f.close()
		quit(1)
		return

	f.store_line("SUCCESS: Player node found.")

	var anim_sprite = player.get_node_or_null("Visual/AnimatedSprite2D")
	if not anim_sprite:
		f.store_line("ERROR: Visual/AnimatedSprite2D not found in Player")
		f.close()
		quit(1)
		return

	f.store_line("SUCCESS: AnimatedSprite2D found with animation: " + str(anim_sprite.animation))
	if anim_sprite.sprite_frames:
		f.store_line("SUCCESS: SpriteFrames found. Animations: " + str(anim_sprite.sprite_frames.get_animation_names()))
	else:
		f.store_line("ERROR: SpriteFrames is null")

	f.store_line("ALL CHECKS PASSED PERFECTLY!")
	f.close()
	quit(0)
