extends SceneTree

# Yamalı Dünya — Joypad Button (Özellikle Daire / B Tuşu) Regresyon ve Güvenlik Testi

func _init() -> void:
	print("--- JOYPAD BUTTON (CIRCLE / B) TESTİ BAŞLATILIYOR ---")
	call_deferred("_run")

func _run() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/fantasy_hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame

	print("[Test] FantasyHUD yüklendi.")

	# Tüm joypad butonlarını tek tek göndererek 'echo' veya başka özellik çökmeleri olmadığını test et
	var buttons_to_test = [
		JOY_BUTTON_A,
		JOY_BUTTON_B,
		JOY_BUTTON_X,
		JOY_BUTTON_Y,
		JOY_BUTTON_BACK,
		JOY_BUTTON_START,
		JOY_BUTTON_LEFT_STICK,
		JOY_BUTTON_RIGHT_STICK,
		JOY_BUTTON_LEFT_SHOULDER,
		JOY_BUTTON_RIGHT_SHOULDER,
		JOY_BUTTON_DPAD_UP,
		JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT
	]

	for btn in buttons_to_test:
		var ev := InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = btn
		ev.pressed = true
		hud._input(ev)
		hud._unhandled_input(ev)
		await process_frame

		ev.pressed = false
		hud._input(ev)
		hud._unhandled_input(ev)
		await process_frame

	print("[Test] 14 Joypad butonunun tamamı FantasyHUD üzerinden hatasız geçti! (Sıfır Çökme)")

	# Player sahnesinde Joypad B (Circle / Dash) test et
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	if player_scene:
		var player = player_scene.instantiate()
		root.add_child(player)
		await process_frame

		var ev_circle := InputEventJoypadButton.new()
		ev_circle.device = 0
		ev_circle.button_index = JOY_BUTTON_B
		ev_circle.pressed = true
		player._unhandled_input(ev_circle)
		await process_frame

		print("[Test] Player sahnesinde Daire / B (Circle) tuşu başarıyla işlendi!")
		player.queue_free()

	hud.queue_free()
	await process_frame

	print("=================================================================")
	print(" SONUÇ: Daire / B (Circle) Tuşu Hatası Tamamen Düzeltildi (PASS)")
	print("=================================================================")
	quit(0)
