@tool
extends SceneTree

func _init() -> void:
	print("--- GODOT VERIFICATION START ---")
	var main_res = load("res://scenes/main.tscn")
	if not main_res:
		push_error("FAIL: Failed to load res://scenes/main.tscn")
		quit(1)
		return
	print("OK: main.tscn loaded.")

	var main_scene = main_res.instantiate()
	root.add_child(main_scene)
	print("OK: main.tscn instantiated and added to tree.")

	var player = main_scene.get_node_or_null("Player")
	if not player:
		push_error("FAIL: Player node not found.")
		quit(1)
		return
	print("OK: Player node found.")

	var anim_sprite = player.get_node_or_null("Visual/AnimatedSprite2D")
	if not anim_sprite or not anim_sprite.sprite_frames:
		push_error("FAIL: AnimatedSprite2D or SpriteFrames not found.")
		quit(1)
		return

	var anims = anim_sprite.sprite_frames.get_animation_names()
	print("OK: Animations available: ", anims)

	for req in ["attack", "heavy_attack", "draw_sword", "idle", "run", "jump", "fall"]:
		if not anim_sprite.sprite_frames.has_animation(req):
			push_error("FAIL: Missing required animation: " + req)
			quit(1)
			return
	print("OK: All required animations confirmed.")

	var sword_pickup = main_scene.get_node_or_null("SwordPickup")
	if not sword_pickup:
		push_error("FAIL: SwordPickup node not found in main.tscn")
		quit(1)
		return
	print("OK: SwordPickup node found.")

	# Simulate pickup
	print("Simulating sword pickup...")
	player.pickup_sword()
	if not player.has_sword:
		push_error("FAIL: player.has_sword should be true after pickup")
		quit(1)
		return
	print("OK: player.has_sword is true.")

	# Simulate light attack
	print("Simulating light attack...")
	player.perform_light_attack()
	if not player.is_attacking or player.current_attack_type != "light":
		push_error("FAIL: Light attack state not set")
		quit(1)
		return
	print("OK: Light attack executed.")

	# Simulate heavy attack
	print("Simulating heavy attack...")
	player.perform_heavy_attack()
	if not player.is_attacking or player.current_attack_type != "heavy":
		push_error("FAIL: Heavy attack state not set")
		quit(1)
		return
	print("OK: Heavy attack executed.")

	# Reset attack and drop sword
	player.is_attacking = false
	print("Simulating sword drop...")
	player.drop_sword()
	if player.has_sword:
		push_error("FAIL: player.has_sword should be false after drop")
		quit(1)
		return
	print("OK: Sword dropped successfully.")

	print("--- ALL TESTS PASSED WITH 100% SUCCESS ---")
	quit(0)
