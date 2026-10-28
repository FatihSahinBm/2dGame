extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

var stage: Node
var player: Player
var vlad: CharacterBody2D
var frame_count: int = 0

func _init() -> void:
	var packed: PackedScene = load(STAGE3_PATH) as PackedScene
	stage = packed.instantiate()
	root.add_child(stage)
	player = stage.get_node_or_null("CombatPlayer") as Player
	vlad = stage.get_node_or_null("VladBoss") as CharacterBody2D

func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count < 3:
		return false
	
	run_simulation()
	return true

func run_simulation() -> void:
	print("==================================================================")
	print("WEREWOLF LEAP ONTO PLATFORM SIMULATION")
	print("==================================================================")
	
	vlad.set_form(2, false) # Werewolf Form
	vlad.is_active = true
	vlad._is_in_cinematic = false
	player.global_position = Vector2(2950, 418) # On Rampart1 (2950, 430)
	vlad.global_position = Vector2(2750, 560) # On ground 200px to the left
	vlad._target_node = player
	
	# Trigger werewolf leap
	vlad._execute_werewolf_leap()
	print("Initial Werewolf Pos: ", vlad.global_position)
	print("Target Leap Pos: ", vlad._leap_target_pos)
	
	# Simulate leap frames: 6 crouch frames, 9 flight frames, 1 slam frame
	for i in range(16):
		if vlad.anim_sprite:
			vlad.anim_sprite.frame = i
			vlad.anim_sprite.frame_progress = 0.0
		vlad._process_attack(0.01667)
		vlad._physics_process(0.01667)
	
	print("Werewolf Pos at Slam Impact (f15): ", vlad.global_position)
	print("Platform top Y is 418.0. Did Werewolf reach platform? ", absf(vlad.global_position.y - 418.0) < 15.0)
	
	# Check distance to player
	var dist_to_player = vlad.global_position.distance_to(player.global_position)
	print("Distance from Werewolf to Player at Slam: ", dist_to_player, " px")
	print("Impact Hitbox size Vector2(120, 65). Did it overlap player? ", dist_to_player < 80.0)
	
	print("\n==================================================================")
	print("SIMULATION COMPLETE")
	print("==================================================================")
	quit(0)
