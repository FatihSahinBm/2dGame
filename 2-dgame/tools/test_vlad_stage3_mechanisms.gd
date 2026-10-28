extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

func _init() -> void:
	print("========================================================")
	print("--- VLAD STAGE 3 MECHANISMS TARGET REGRESSION TEST ---")
	print("========================================================")
	
	var packed: PackedScene = load(STAGE3_PATH) as PackedScene
	if not packed:
		_fail("Could not load stage 3 throne room scene: " + STAGE3_PATH)
		return
	
	var stage: Node = packed.instantiate()
	if not stage:
		_fail("Could not instantiate stage 3 throne room")
		return
	
	root.add_child(stage)
	
	var passed_checks: Array[int] = [0]
	var failed_checks: Array[int] = [0]
	var errors: Array[String] = []
	
	var assert_check = func(cond: bool, msg: String) -> void:
		if cond:
			print("  [PASS] ", msg)
			passed_checks[0] += 1
		else:
			printerr("  [FAIL] ", msg)
			failed_checks[0] += 1
			errors.append(msg)
	
	# -------------------------------------------------------------
	# 1. WEAK ARCHWAY TARGET BEHAVIORAL TESTS
	# -------------------------------------------------------------
	print("\n[SECTION 1: WeakArchway Geometry, Collision & Behavior]")
	var archway: WeakArchwayTrap = stage.get_node_or_null("Environment/Arena3_Ramparts/WeakArchway") as WeakArchwayTrap
	assert_check.call(archway != null, "WeakArchway instance exists and is WeakArchwayTrap")
	
	if archway:
		assert_check.call(archway.position == Vector2(3350, 490), "WeakArchway position preserved at Vector2(3350, 490)")
		
		# 1.1 Trigger Area & Shape
		var trigger: Area2D = archway.get_node_or_null("TriggerArea") as Area2D
		assert_check.call(trigger != null, "TriggerArea Area2D child exists")
		if trigger:
			assert_check.call(trigger.collision_layer == 0, "TriggerArea collision_layer == 0")
			assert_check.call(trigger.collision_mask == 7, "TriggerArea collision_mask == 7 (detects player, boss, enemies)")
			var col: CollisionShape2D = trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
			assert_check.call(col != null and col.shape is RectangleShape2D, "TriggerArea has RectangleShape2D")
			if col and col.shape is RectangleShape2D:
				var rshape: RectangleShape2D = col.shape as RectangleShape2D
				assert_check.call(rshape.size == Vector2(120, 90), "TriggerArea hitbox size strictly Vector2(120, 90)")
		
		# 1.2 ArchSprite Visual & Alignment
		var arch_sprite: Sprite2D = archway.get_node_or_null("ArchSprite") as Sprite2D
		assert_check.call(arch_sprite != null, "ArchSprite is Sprite2D")
		if arch_sprite:
			assert_check.call(arch_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "ArchSprite texture_filter is nearest (crisp)")
			assert_check.call(arch_sprite.texture != null and arch_sprite.texture.resource_path.ends_with("weak_gothic_archway.png"), "ArchSprite uses weak_gothic_archway.png")
			assert_check.call(arch_sprite.position == Vector2(0, 5), "ArchSprite local position == Vector2(0, 5)")
			var arch_bottom_y: float = archway.position.y + arch_sprite.position.y + (130.0 / 2.0)
			assert_check.call(arch_bottom_y == 560.0, "ArchSprite base line rests exactly on Arena 3 ground at world Y = 560.0")
		
		# 1.3 RubbleParticles Integration
		var particles: CPUParticles2D = archway.get_node_or_null("RubbleParticles") as CPUParticles2D
		assert_check.call(particles != null, "RubbleParticles CPUParticles2D wired to WeakArchway")
		if particles:
			assert_check.call(particles.emitting == false, "RubbleParticles initially dormant (emitting == false)")
			assert_check.call(particles.one_shot == true, "RubbleParticles is one_shot")
		
		# 1.4 Initial State & Selective Trigger Filtering
		assert_check.call(archway._collapsed == false, "WeakArchway initially not collapsed (_collapsed == false)")
		
		var arch_signal_count: Array[int] = [0]
		archway.archway_collapsed.connect(func(_trap):
			arch_signal_count[0] += 1
		)
		
		# Non-boss body entered test (should be ignored)
		var dummy_grunt: CharacterBody2D = CharacterBody2D.new()
		dummy_grunt.name = "NormalGrunt"
		archway._on_trigger_body_entered(dummy_grunt)
		assert_check.call(arch_signal_count[0] == 0, "Non-boss body does not trigger archway collapse")
		assert_check.call(archway._collapsed == false, "Archway remains intact after non-boss contact")
		dummy_grunt.free()
		
		# Boss body entered test (should trigger collapse)
		var dummy_vlad: CharacterBody2D = CharacterBody2D.new()
		dummy_vlad.name = "VladBoss"
		dummy_vlad.add_to_group("boss")
		archway._on_trigger_body_entered(dummy_vlad)
		assert_check.call(arch_signal_count[0] == 1, "Boss contact triggers archway_collapsed signal exactly once")
		assert_check.call(archway._collapsed == true, "Archway state transitioned to _collapsed == true")
		dummy_vlad.free()
		
		# Double-trigger prevention test
		archway.take_damage(50)
		assert_check.call(arch_signal_count[0] == 1, "Subsequent damage or contact does NOT re-trigger collapsed archway")
		
		# 1.5 Stage Hookup Check: boss stun on archway collapse
		var stage_script: Stage3ThroneRoom = stage as Stage3ThroneRoom
		assert_check.call(stage_script != null, "Stage3ThroneRoom stage script instance valid")
	
	# -------------------------------------------------------------
	# 2. GREAT BELL TARGET BEHAVIORAL TESTS
	# -------------------------------------------------------------
	print("\n[SECTION 2: GreatBell Geometry, Pivot, Timing & Signal Flow]")
	var bell: CastleBellMechanism = stage.get_node_or_null("Environment/Arena4_BellTower/GreatBell") as CastleBellMechanism
	assert_check.call(bell != null, "GreatBell instance exists and is CastleBellMechanism")
	
	if bell:
		assert_check.call(bell.position == Vector2(4850, 330), "GreatBell position preserved at Vector2(4850, 330)")
		assert_check.call(bell.cooldown_seconds == 6.0, "GreatBell cooldown_seconds == 6.0")
		assert_check.call(bell.stun_duration == 4.0, "GreatBell stun_duration == 4.0")
		
		# 2.1 Collision Shape & Detection Mask
		assert_check.call(bell.collision_layer == 0, "GreatBell collision_layer == 0")
		assert_check.call(bell.collision_mask == 2, "GreatBell collision_mask == 2 (detects player attacks)")
		var bell_col: CollisionShape2D = bell.get_node_or_null("CollisionShape2D") as CollisionShape2D
		assert_check.call(bell_col != null and bell_col.shape is RectangleShape2D, "GreatBell has RectangleShape2D")
		if bell_col and bell_col.shape is RectangleShape2D:
			var rshape: RectangleShape2D = bell_col.shape as RectangleShape2D
			assert_check.call(rshape.size == Vector2(50, 60), "GreatBell hitbox size strictly Vector2(50, 60)")
		
		# 2.2 Visual Pivot & Chain Alignment
		var bell_visual: Sprite2D = bell.get_node_or_null("BellVisual") as Sprite2D
		assert_check.call(bell_visual != null, "BellVisual is Sprite2D")
		if bell_visual:
			assert_check.call(bell_visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "BellVisual texture_filter is nearest")
			assert_check.call(bell_visual.texture != null and bell_visual.texture.resource_path.ends_with("great_castle_bell.png"), "BellVisual uses great_castle_bell.png")
			assert_check.call(bell_visual.position == Vector2(0, -25), "BellVisual origin anchored at Y = -25 (chain suspension pivot)")
			assert_check.call(bell_visual.offset == Vector2(0, 27), "BellVisual offset centered 27px below pivot")
		
		var chain: NinePatchRect = bell.get_node_or_null("Chain") as NinePatchRect
		assert_check.call(chain != null, "Chain NinePatchRect exists")
		if chain:
			assert_check.call(chain.texture != null and chain.texture.resource_path.ends_with("great_bell_chain.png"), "Chain uses great_bell_chain.png")
			assert_check.call(chain.offset_bottom == -25.0, "Chain terminates precisely at Y = -25 (meeting bell crown)")
			assert_check.call(chain.offset_top == -300.0, "Chain extends to ceiling Y = -300")
		
		# 2.3 Initial State & Selective Trigger
		assert_check.call(bell._is_on_cooldown == false, "GreatBell initially not on cooldown")
		assert_check.call(bell._cooldown_timer == 0.0, "GreatBell initial cooldown_timer == 0.0")
		
		var bell_signal_count: Array[int] = [0]
		bell.bell_rung.connect(func(_ringer):
			bell_signal_count[0] += 1
		)
		
		# Non-player body entered test (should be ignored)
		var dummy_enemy: CharacterBody2D = CharacterBody2D.new()
		dummy_enemy.name = "SkeletonEnemy"
		bell._on_body_entered(dummy_enemy)
		assert_check.call(bell_signal_count[0] == 0, "Non-player body does not ring bell")
		dummy_enemy.free()
		
		# Player weapon hitbox area_entered test (should ring bell)
		var dummy_sword_area: Area2D = Area2D.new()
		dummy_sword_area.name = "PlayerSwordAttackArea"
		dummy_sword_area.add_to_group("player_hitbox")
		bell._on_area_entered(dummy_sword_area)
		assert_check.call(bell_signal_count[0] == 1, "Player attack area triggers bell_rung signal exactly once")
		assert_check.call(bell._is_on_cooldown == true, "GreatBell is now on cooldown")
		assert_check.call(bell._cooldown_timer == 6.0, "GreatBell cooldown timer initialized to 6.0s")
		dummy_sword_area.free()
		
		# Double-trigger prevention test during cooldown
		bell.take_damage(20)
		bell.ring_bell()
		assert_check.call(bell_signal_count[0] == 1, "Additional strikes during cooldown do NOT re-trigger bell_rung")
		
		# Cooldown recovery simulation test
		bell._process(6.1)
		assert_check.call(bell._is_on_cooldown == false, "GreatBell cooldown resets after cooldown duration elapsed")
		assert_check.call(bell._cooldown_timer <= 0.0, "GreatBell cooldown_timer depleted")
		
		# Post-cooldown second ring test
		bell.ring_bell()
		assert_check.call(bell_signal_count[0] == 2, "GreatBell rings successfully after cooldown expires")
	
	# -------------------------------------------------------------
	# 3. BOSS COMBAT & PLATFORM REGRESSION CHECKS
	# -------------------------------------------------------------
	print("\n[SECTION 3: Boss Combat & Platform Regression Integrity]")
	var vlad: CharacterBody2D = stage.get_node_or_null("VladBoss") as CharacterBody2D
	assert_check.call(vlad != null, "VladBoss node present")
	if vlad:
		assert_check.call(vlad.has_method("trigger_archway_stun"), "VladBoss.trigger_archway_stun method exists")
		assert_check.call(vlad.has_method("trigger_bell_stun"), "VladBoss.trigger_bell_stun method exists")
		assert_check.call(vlad.has_signal("form_changed"), "VladBoss.form_changed signal exists")
	
	var plat_left: StaticBody2D = stage.get_node_or_null("Environment/Arena1_ThroneRoom/PlatformLeft") as StaticBody2D
	assert_check.call(plat_left != null and plat_left.position == Vector2(200, 430), "Arena 1 PlatformLeft intact")
	
	var ground1: StaticBody2D = stage.get_node_or_null("Environment/Arena1_ThroneRoom/Ground1") as StaticBody2D
	assert_check.call(ground1 != null and ground1.position == Vector2(600, 590), "Arena 1 Ground1 intact")
	
	print("\n========================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passed_checks[0], failed_checks[0]])
	print("========================================================")
	
	if failed_checks[0] > 0:
		print("FAILED CHECKS LIST:")
		for err in errors:
			print("  - ", err)
		quit(1)
	else:
		print("ALL TARGET REGRESSION CHECKS PASSED WITH ZERO ERRORS!")
		quit(0)

func _fail(msg: String) -> void:
	print("[FATAL ERROR] ", msg)
	quit(1)
