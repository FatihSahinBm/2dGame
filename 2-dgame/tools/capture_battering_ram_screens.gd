extends SceneTree

const BRIDGE_SCENE_PATH = "res://scenes/levels/vlad/stage_1_bridge_assault.tscn"

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var scene_res = load(BRIDGE_SCENE_PATH)
	if not scene_res:
		quit(1)
		return

	var bridge = scene_res.instantiate()
	root.add_child(bridge)

	# Kamerayı ve oyuncuyu kapı hizasına taşıyalım
	var player = bridge.get_node_or_null("CombatPlayer")
	if player:
		player.global_position = Vector2(2180, 560)
		var cam = player.get_node_or_null("Camera2D")
		if cam:
			cam.global_position = Vector2(2260, 480)
			cam.zoom = Vector2(1.2, 1.2)

	# 1. Kare bekle ve kapı sağlamken ekran görüntüsü al
	await create_timer(0.3).timeout
	var viewport = root.get_viewport()
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("output/screenshots/gate_before_breach.png")
				print("[SCREENSHOT] gate_before_breach.png kaydedildi!")

	# Koçbaşı darbesi ve kapı kırılması
	var ram_crew = bridge.get_node_or_null("BatteringRamCrew")
	var exit_gate = bridge.get_node_or_null("ExitGate")
	if ram_crew and exit_gate:
		ram_crew._shatter_gate_visuals(exit_gate)
		ram_crew._spawn_splinters_explosion(exit_gate.global_position)

	# Kırılma sonrası kare bekle ve görüntü al
	await create_timer(0.4).timeout
	if viewport:
		var tex = viewport.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				img.save_png("output/screenshots/gate_after_breach.png")
				print("[SCREENSHOT] gate_after_breach.png kaydedildi!")

	await create_timer(0.2).timeout
	quit(0)
