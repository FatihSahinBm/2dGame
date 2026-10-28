extends SceneTree

const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"

func _init() -> void:
	print("==================================================")
	print("TEST: VLAD STAGE 3 THRONE ROOM PLATFORMS & GROUNDS")
	print("==================================================")
	
	var packed: PackedScene = load(STAGE3_PATH) as PackedScene
	if not packed:
		_fail("Could not load stage 3 throne room scene: " + STAGE3_PATH)
		return
	
	var stage: Node = packed.instantiate()
	if not stage:
		_fail("Could not instantiate stage 3 throne room")
		return
	
	root.add_child(stage)
	
	var errors: Array[String] = []
	
	# 1. Check Player & Boss initial positions and foot alignment
	var player: CharacterBody2D = stage.get_node_or_null("CombatPlayer") as CharacterBody2D
	if not player:
		errors.append("CombatPlayer node not found in Stage3ThroneRoom")
	else:
		if player.position != Vector2(180, 560):
			errors.append("Player initial position changed: expected (180, 560), got " + str(player.position))
		else:
			print("[PASS] CombatPlayer at expected position: Vector2(180, 560)")
	
	var vlad: CharacterBody2D = stage.get_node_or_null("VladBoss") as CharacterBody2D
	if not vlad:
		errors.append("VladBoss node not found in Stage3ThroneRoom")
	else:
		if vlad.position != Vector2(850, 560):
			errors.append("VladBoss initial position changed: expected (850, 560), got " + str(vlad.position))
		else:
			print("[PASS] VladBoss at expected position: Vector2(850, 560)")
	
	# 2. Check Ground 1..4 geometry, positions, and NinePatchRect textures
	var expected_grounds: Array[Dictionary] = [
		{
			"path": "Environment/Arena1_ThroneRoom/Ground1",
			"pos": Vector2(600, 590),
			"size": Vector2(1300, 60),
			"tex": "throne_gothic_floor.png",
			"offset_top": -30.0,
			"width": 1300.0
		},
		{
			"path": "Environment/Arena2_BloodHall/Ground2",
			"pos": Vector2(1950, 590),
			"size": Vector2(1400, 60),
			"tex": "throne_gothic_floor.png",
			"offset_top": -30.0,
			"width": 1400.0
		},
		{
			"path": "Environment/Arena3_Ramparts/Ground3",
			"pos": Vector2(3350, 590),
			"size": Vector2(1400, 60),
			"tex": "ramparts_stone_floor.png",
			"offset_top": -30.0,
			"width": 1400.0
		},
		{
			"path": "Environment/Arena4_BellTower/Ground4",
			"pos": Vector2(4850, 590),
			"size": Vector2(1600, 60),
			"tex": "ramparts_stone_floor.png",
			"offset_top": -30.0,
			"width": 1600.0
		}
	]
	
	for g in expected_grounds:
		var g_node: StaticBody2D = stage.get_node_or_null(g["path"]) as StaticBody2D
		if not g_node:
			errors.append("Ground node not found: " + g["path"])
			continue
		
		if g_node.position != g["pos"]:
			errors.append("Ground position mismatch at %s: expected %s, got %s" % [g["path"], str(g["pos"]), str(g_node.position)])
		
		var col: CollisionShape2D = g_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if not col or not col.shape is RectangleShape2D:
			errors.append("Missing RectangleShape2D on ground: " + g["path"])
		else:
			var rshape: RectangleShape2D = col.shape as RectangleShape2D
			if rshape.size != g["size"]:
				errors.append("Ground collision size mismatch at %s: expected %s, got %s" % [g["path"], str(g["size"]), str(rshape.size)])
		
		# Check NinePatchRect visual
		var visual: NinePatchRect = g_node.get_node_or_null("GroundVisual") as NinePatchRect
		if not visual:
			errors.append("Missing GroundVisual NinePatchRect on " + g["path"])
		else:
			if not visual.texture:
				errors.append("Missing texture on GroundVisual: " + g["path"])
			elif not visual.texture.resource_path.ends_with(g["tex"]):
				errors.append("Texture mismatch on %s: expected %s, got %s" % [g["path"], g["tex"], visual.texture.resource_path])
			
			if visual.offset_top != g["offset_top"]:
				errors.append("Ground visual offset_top mismatch: expected %s, got %s" % [str(g["offset_top"]), str(visual.offset_top)])
			
			var visual_width: float = visual.offset_right - visual.offset_left
			if visual_width != g["width"]:
				errors.append("Ground visual width mismatch: expected %s, got %s" % [str(g["width"]), str(visual_width)])
			
			var surface_y: float = g_node.position.y + visual.offset_top
			if surface_y != 560.0:
				errors.append("Ground walkable surface Y mismatch at %s: expected 560.0, got %s" % [g["path"], str(surface_y)])
			else:
				print("[PASS] %s walkable surface matches Y = 560.0 (texture: %s)" % [g["path"], g["tex"]])
	
	# 3. Check All 8 Elevated Platforms
	var expected_platforms: Array[Dictionary] = [
		{"path": "Environment/Arena1_ThroneRoom/PlatformLeft", "pos": Vector2(200, 430)},
		{"path": "Environment/Arena1_ThroneRoom/PlatformRight", "pos": Vector2(980, 430)},
		{"path": "Environment/Arena2_BloodHall/PlatformL", "pos": Vector2(1580, 430)},
		{"path": "Environment/Arena2_BloodHall/PlatformR", "pos": Vector2(2320, 430)},
		{"path": "Environment/Arena3_Ramparts/Rampart1", "pos": Vector2(2950, 430)},
		{"path": "Environment/Arena3_Ramparts/Rampart2", "pos": Vector2(3750, 430)},
		{"path": "Environment/Arena4_BellTower/TowerPlatform1", "pos": Vector2(4500, 430)},
		{"path": "Environment/Arena4_BellTower/TowerPlatform2", "pos": Vector2(5200, 430)}
	]
	
	for p in expected_platforms:
		var p_node: StaticBody2D = stage.get_node_or_null(p["path"]) as StaticBody2D
		if not p_node:
			errors.append("Platform node not found: " + p["path"])
			continue
		
		if p_node.position != p["pos"]:
			errors.append("Platform position mismatch at %s: expected %s, got %s" % [p["path"], str(p["pos"]), str(p_node.position)])
		
		var col: CollisionShape2D = p_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if not col or not col.shape is RectangleShape2D:
			errors.append("Missing RectangleShape2D on platform: " + p["path"])
		else:
			var rshape: RectangleShape2D = col.shape as RectangleShape2D
			if rshape.size != Vector2(240, 24):
				errors.append("Platform collision size mismatch at %s: expected (240, 24), got %s" % [p["path"], str(rshape.size)])
			if not col.one_way_collision:
				errors.append("Platform one_way_collision disabled at: " + p["path"])
		
		var visual: Sprite2D = p_node.get_node_or_null("PlatformVisual") as Sprite2D
		if not visual:
			errors.append("Missing PlatformVisual Sprite2D on: " + p["path"])
		else:
			if not visual.texture:
				errors.append("Missing texture on PlatformVisual: " + p["path"])
			elif not visual.texture.resource_path.ends_with("gothic_castle_platform.png"):
				errors.append("Platform texture mismatch at %s: expected gothic_castle_platform.png, got %s" % [p["path"], visual.texture.resource_path])
			
			if visual.texture:
				var tex_size: Vector2 = visual.texture.get_size()
				if tex_size != Vector2(240, 24):
					errors.append("Platform texture size mismatch: expected (240, 24), got " + str(tex_size))
				else:
					print("[PASS] %s valid platform visual (240x24, one-way collision, position: %s)" % [p["path"], str(p["pos"])])
	
	# 4. Boss Script & Forms Integrity Check
	if vlad:
		var has_phases: bool = vlad.has_method("take_damage") and vlad.has_signal("form_changed")
		if not has_phases:
			errors.append("VladBoss missing essential combat methods or signals")
		else:
			print("[PASS] VladBoss combat API and signals intact")
	
	if errors.size() > 0:
		print("\n--- TEST FAILED WITH %d ERRORS ---" % errors.size())
		for e in errors:
			print("  [ERROR] ", e)
		quit(1)
	else:
		print("\n==================================================")
		print("ALL 12 PLATFORMS AND GROUNDS VALIDATED SUCCESSFULLY!")
		print("==================================================")
		quit(0)

func _fail(msg: String) -> void:
	print("[FATAL ERROR] ", msg)
	quit(1)
