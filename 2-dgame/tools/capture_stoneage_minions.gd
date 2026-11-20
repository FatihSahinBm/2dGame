extends SceneTree

## res://tools/capture_stoneage_minions.gd
## Raptor / siber böcek / mağara adamı sprite'larının oyun içi görüntüsünü alır.
## Gerçek pencerede çalıştırılır (headless modda görüntü üretilmez):
##   godot --path . --script res://tools/capture_stoneage_minions.gd

const LEVEL: String = "res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn"
const OUT_DIR: String = "../output/stoneage_minions"
const SETTLE_SEC: float = 1.5
const CAMERA_ZOOM: Vector2 = Vector2(2.0, 2.0)
const CAMERA_LIFT: Vector2 = Vector2(0.0, -40.0)
## çıktı dosyası -> karakterin script dosyası
const SHOTS: Dictionary = {
	"ingame_caveman": "caveman.gd",
	"ingame_raptor": "raptor.gd",
	"ingame_cyber_bug": "cyber_flying_bug.gd",
}


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await create_timer(SETTLE_SEC).timeout

	var box: Node = get_first_node_in_group("dialogue_box")
	if box and box.has_method("skip_dialogue"):
		box.skip_dialogue()

	var cam: Camera2D = Camera2D.new()
	cam.zoom = CAMERA_ZOOM
	level.add_child(cam)
	cam.make_current()

	var failed: int = 0
	for shot: String in SHOTS:
		var target: Node2D = _find_by_script(level, SHOTS[shot])
		if target == null:
			push_error("Sahnede bulunamadı: %s" % SHOTS[shot])
			failed += 1
			continue
		cam.global_position = target.global_position + CAMERA_LIFT
		cam.reset_smoothing()
		for i: int in range(20):
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, shot])
		print("Kaydedildi: %s/%s.png" % [OUT_DIR, shot])
	quit(1 if failed > 0 else 0)


func _find_by_script(node: Node, script_file: String) -> Node2D:
	var script: Script = node.get_script() as Script
	if node is Node2D and script and script.resource_path.ends_with(script_file):
		return node as Node2D
	for child: Node in node.get_children():
		var found: Node2D = _find_by_script(child, script_file)
		if found:
			return found
	return null
