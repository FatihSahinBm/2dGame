extends SceneTree

const SCENES_TO_TEST: Array[String] = [
	"res://scenes/levels/vlad/stage_1_forest_camp.tscn",
	"res://scenes/levels/vlad/stage_1_camp.tscn",
	"res://scenes/levels/vlad/stage_1_fatih_tent.tscn",
	"res://scenes/levels/vlad/stage_1_bridge_assault.tscn",
	"res://scenes/levels/vlad/stage_2_castle_dungeon.tscn",
	"res://scenes/levels/vlad/stage_3_throne_room.tscn"
]

func _init() -> void:
	print("==================================================================")
	print("--- VLAD CHAPTER SCENE LOADING & INTEGRITY VERIFICATION ---")
	print("==================================================================")
	
	var passed: int = 0
	var failed: int = 0
	var error_list: Array[String] = []
	
	for sc_path in SCENES_TO_TEST:
		print("\n[LOADING SCENE] ", sc_path)
		if not ResourceLoader.exists(sc_path):
			printerr("  [FAIL] Scene file does not exist on disk: ", sc_path)
			failed += 1
			error_list.append("File missing: " + sc_path)
			continue
		
		var packed: PackedScene = load(sc_path) as PackedScene
		if not packed:
			printerr("  [FAIL] Could not load PackedScene: ", sc_path)
			failed += 1
			error_list.append("Load failure: " + sc_path)
			continue
		
		var instance: Node = packed.instantiate()
		if not instance:
			printerr("  [FAIL] Could not instantiate scene: ", sc_path)
			failed += 1
			error_list.append("Instantiation failure: " + sc_path)
			continue
		
		root.add_child(instance)
		
		print("  [PASS] Successfully loaded & instantiated: %s (Type: %s, Children: %d)" % [
			instance.name, instance.get_class(), instance.get_child_count()
		])
		passed += 1
		
		# Clean up instance
		instance.queue_free()
	
	print("\n==================================================================")
	print("SCENE LOAD RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================================")
	
	if failed == 0:
		print("ALL 6 VLAD CHAPTER SCENES LOADED & INSTANTIATED FLAWLESSLY!")
		quit(0)
	else:
		for err in error_list:
			printerr("  - ", err)
		quit(1)
