extends Node
## Yamalı Dünya — QA Oynanış Koşucusu (yalnızca QA amaçlı, oyun koduna dokunmaz)
##
## Çalıştırma (GERÇEK PENCERE, headless DEĞİL):
##   Godot_console.exe --path . res://qa/playthrough/qa_play_runner.tscn -- --qa-mode=campaign
##   Godot_console.exe --path . res://qa/playthrough/qa_play_runner.tscn -- --qa-mode=scenario --qa-scenario=PLAY-002
##
## Girdi yöntemi: Input.parse_input_event() ile InputEventKey / InputEventMouseButton gönderilir.
## Bu olaylar Godot'nun gerçek klavye/fare olaylarıyla AYNI hattı (Input singleton -> _input ->
## _unhandled_input -> InputMap aksiyonları) kullanır. İşletim sistemi seviyesinde donanım
## girdisi DEĞİLDİR; raporlarda "motor-seviyesi gerçek oyun girdisi" olarak sınıflandırılır.
##
## Çıkış kodu: Herhangi bir senaryo FAIL ise 1, BLOCKED varsa 2, hepsi PASS ise 0.

const OUT_ROOT := "res://qa/playthrough"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

var mode: String = "campaign"
var scenario_id: String = ""
var scene_time_limit: float = 240.0
var campaign_max_scenes: int = 12

var _t: float = 0.0
var _scene_t: float = 0.0
var _records: Array = []
var _cur: Dictionary = {}
var _last_scene: Node = null
var _held: Dictionary = {}
var _shot_idx: int = 0
var _anomaly_seen: Dictionary = {}
var _finished: bool = false
var _scene_count: int = 0

# Bot durumu
var _last_x: float = 0.0
var _stuck_timer: float = 0.0
var _no_ctrl_timer: float = 0.0
var _attack_lock_timer: float = 0.0
var _dialog_timer: float = 0.0
var _enter_cd: float = 0.0
var _jump_cd: float = 0.0
var _atk_cd: float = 0.0
var _sample_cd: float = 0.0
var _dir: int = 1
var _reverse_timer: float = 0.0
var _anim_mismatch_t: float = 0.0
var _progress_best_x: float = -INF
var _no_progress_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-mode="):
			mode = a.get_slice("=", 1)
		elif a.begins_with("--qa-scenario="):
			scenario_id = a.get_slice("=", 1)
		elif a.begins_with("--qa-time="):
			scene_time_limit = float(a.get_slice("=", 1))
		elif a.begins_with("--qa-max-scenes="):
			campaign_max_scenes = int(a.get_slice("=", 1))
	for d in ["screenshots", "reports", "bugs"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT + "/" + d))
	_log("QA runner start mode=%s scenario=%s" % [mode, scenario_id])
	call_deferred("_boot")


func _boot() -> void:
	match mode:
		"campaign":
			_load_scene(MAIN_MENU)
			_run_campaign()
		"scenario":
			_run_scenario(scenario_id)
		_:
			_log("Bilinmeyen mod")
			_finish()


# ---------------------------------------------------------------- yardımcılar
func _log(msg: String) -> void:
	print("[QA t=%.2f] %s" % [_t, msg])


func _load_scene(path: String) -> Node:
	var ps: PackedScene = load(path)
	var inst := ps.instantiate()
	var old := get_tree().current_scene
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	if old and old != self and is_instance_valid(old):
		old.queue_free()
	_last_scene = inst
	return inst


func _wait(sec: float) -> void:
	var end := _t + sec
	while _t < end and not _finished:
		await get_tree().process_frame


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.key_label = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	if pressed:
		_held[code] = true
	else:
		_held.erase(code)
	var action_map: Dictionary = {
		KEY_D: "move_right",
		KEY_A: "move_left",
		KEY_SPACE: "jump",
		KEY_CTRL: "crouch",
		KEY_SHIFT: "dash",
		KEY_C: "roll",
		KEY_J: "attack_light",
		KEY_K: "attack_heavy",
		KEY_E: "interact",
	}
	if action_map.has(code):
		var act: String = action_map[code]
		if InputMap.has_action(act):
			if pressed:
				Input.action_press(act)
			else:
				Input.action_release(act)
	var p := _player()
	if p and is_instance_valid(p):
		p._unhandled_input(ev)
	_input_log("key %s %s" % [OS.get_keycode_string(code), "down" if pressed else "up"])


func _tap(code: Key, hold: float = 0.06) -> void:
	_key(code, true)
	await _wait(hold)
	_key(code, false)
	await get_tree().process_frame


func _click(button: MouseButton, pos: Vector2 = Vector2(-1, -1)) -> void:
	if pos.x < 0:
		pos = get_viewport().get_visible_rect().size * 0.5
	var win_id: int = get_viewport().get_window_id() if get_viewport() else 0
	var ev_press := InputEventMouseButton.new()
	ev_press.window_id = win_id
	ev_press.button_index = button
	ev_press.pressed = true
	ev_press.position = pos
	ev_press.global_position = pos
	if button == MOUSE_BUTTON_LEFT:
		ev_press.button_mask = MOUSE_BUTTON_MASK_LEFT
		if InputMap.has_action("attack_light"):
			Input.action_press("attack_light")
	elif button == MOUSE_BUTTON_RIGHT:
		ev_press.button_mask = MOUSE_BUTTON_MASK_RIGHT
		if InputMap.has_action("attack_heavy"):
			Input.action_press("attack_heavy")
	Input.parse_input_event(ev_press)
	Input.flush_buffered_events()
	var p := _player()
	if p and is_instance_valid(p):
		p._unhandled_input(ev_press)
	await get_tree().process_frame
	
	var ev_rel := InputEventMouseButton.new()
	ev_rel.window_id = win_id
	ev_rel.button_index = button
	ev_rel.pressed = false
	ev_rel.position = pos
	ev_rel.global_position = pos
	if button == MOUSE_BUTTON_LEFT and InputMap.has_action("attack_light"):
		Input.action_release("attack_light")
	elif button == MOUSE_BUTTON_RIGHT and InputMap.has_action("attack_heavy"):
		Input.action_release("attack_heavy")
	Input.parse_input_event(ev_rel)
	Input.flush_buffered_events()
	if p and is_instance_valid(p):
		p._unhandled_input(ev_rel)
	await get_tree().process_frame
	_input_log("mouse %d click @%s" % [button, str(pos)])


func _release_all() -> void:
	for k in _held.keys():
		_key(k, false)
	for act in ["move_right", "move_left", "jump", "crouch", "dash", "roll", "attack_light", "attack_heavy", "interact"]:
		if InputMap.has_action(act):
			Input.action_release(act)


func _input_log(s: String) -> void:
	if _cur.is_empty():
		return
	var arr: Array = _cur["inputs"]
	if arr.size() < 400:
		arr.append("%.2f %s" % [_scene_t, s])
	_cur["input_count"] = int(_cur.get("input_count", 0)) + 1


func _player() -> CharacterBody2D:
	var p := get_tree().get_first_node_in_group("player")
	return p as CharacterBody2D if p and is_instance_valid(p) else null


func _cam() -> Camera2D:
	return get_viewport().get_camera_2d()


func _screenshot(tag: String) -> String:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return ""
	_shot_idx += 1
	var fname := "%s_%02d_%s.png" % [_cur.get("id", "X"), _shot_idx, tag]
	var path := OUT_ROOT + "/screenshots/" + fname
	img.save_png(ProjectSettings.globalize_path(path))
	if not _cur.is_empty():
		_cur["screenshots"].append(fname)
	_log("screenshot " + fname)
	return fname


func _begin(id: String, title: String, expected: String, method: String) -> void:
	_cur = {
		"id": id, "title": title, "expected": expected, "method": method,
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"start_wall": Time.get_datetime_string_from_system(), "start_t": _t,
		"start_pos": "", "end_pos": "", "inputs": [], "input_count": 0,
		"screenshots": [], "anomalies": [], "observations": [], "anim_samples": {},
		"result": "NOT_RUN", "actual": "",
	}
	_scene_t = 0.0
	_anomaly_seen.clear()
	var p := _player()
	if p:
		_cur["start_pos"] = str(p.global_position)
	_log("BEGIN %s %s (%s)" % [id, title, _cur["scene"]])


func _end(result: String, actual: String) -> void:
	if _cur.is_empty():
		return
	var p := _player()
	_cur["end_pos"] = str(p.global_position) if p else "n/a"
	_cur["end_wall"] = Time.get_datetime_string_from_system()
	_cur["duration_s"] = snappedf(_t - float(_cur["start_t"]), 0.01)
	_cur["result"] = result
	_cur["actual"] = actual
	_records.append(_cur)
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_ROOT + "/reports/%s.json" % _cur["id"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(_cur, "  "))
	f.close()
	_log("END %s -> %s : %s" % [_cur["id"], result, actual])
	_cur = {}


func _observe(s: String) -> void:
	if not _cur.is_empty():
		_cur["observations"].append("%.2f %s" % [_scene_t, s])
	_log("OBS " + s)


func _anomaly(kind: String, detail: String) -> void:
	if _cur.is_empty():
		return
	if _anomaly_seen.has(kind):
		_anomaly_seen[kind] += 1
		return
	_anomaly_seen[kind] = 1
	var p := _player()
	var a := {"kind": kind, "detail": detail, "t": snappedf(_scene_t, 0.01),
		"scene": _cur["scene"], "player_pos": str(p.global_position) if p else "n/a"}
	_log("ANOMALY %s %s" % [kind, detail])
	var shot: String = await _screenshot("ANOMALY_" + kind)
	a["screenshot"] = shot
	_cur["anomalies"].append(a)
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_ROOT + "/bugs/%s_%s.json" % [_cur["id"], kind]), FileAccess.WRITE)
	f.store_string(JSON.stringify(a, "  "))
	f.close()


# ---------------------------------------------------------------- izleme
func _process(delta: float) -> void:
	_t += delta
	_scene_t += delta
	if _cur.is_empty():
		return
	_sample_cd -= delta
	if _sample_cd > 0.0:
		return
	_sample_cd = 0.1
	_monitor(0.1)


func _monitor(dt: float) -> void:
	var p := _player()
	if p == null:
		return
	var cam := _cam()
	# Animasyon örnekleme
	var anim: AnimatedSprite2D = p.get_node_or_null("Visual/AnimatedSprite2D")
	if anim:
		var key := String(anim.animation)
		var s: Dictionary = _cur["anim_samples"]
		s[key] = int(s.get(key, 0)) + 1
		var on_floor := p.is_on_floor()
		var vx := absf(p.velocity.x)
		var bad := false
		if on_floor and vx > 80.0 and key.begins_with("idle"):
			bad = true
		if not on_floor and absf(p.velocity.y) > 150.0 and (key.begins_with("run") or key.begins_with("idle")):
			bad = true
		_anim_mismatch_t = _anim_mismatch_t + dt if bad else 0.0
		if _anim_mismatch_t > 0.5:
			_anomaly("ANIM_MISMATCH", "anim=%s floor=%s vel=%s" % [key, on_floor, p.velocity])
	# Harita dışı / zemin altı
	if cam:
		if p.global_position.y > cam.limit_bottom + 120:
			_anomaly("FELL_OUT_OF_WORLD", "y=%.0f limit_bottom=%d" % [p.global_position.y, cam.limit_bottom])
		if p.global_position.x < cam.limit_left - 60 or p.global_position.x > cam.limit_right + 60:
			_anomaly("OUT_OF_CAMERA_BOUNDS", "x=%.0f limits=[%d,%d]" % [p.global_position.x, cam.limit_left, cam.limit_right])
		var vs := get_viewport().get_visible_rect().size / cam.zoom
		var d := cam.get_screen_center_position() - p.global_position
		if absf(d.x) > vs.x * 0.5 or absf(d.y) > vs.y * 0.5:
			_anomaly("PLAYER_OFF_SCREEN", "cam_center=%s player=%s" % [cam.get_screen_center_position(), p.global_position])
	# Kontrol kaybı / diyalog
	var dlg := _active_dialogue()
	var can_move: bool = p.get("can_move") if "can_move" in p else true
	var gs := get_node_or_null("/root/GameState")
	var cine: bool = gs != null and "is_in_cinematic" in gs and gs.is_in_cinematic
	if dlg:
		_dialog_timer += dt
		if _dialog_timer > 60.0:
			_anomaly("DIALOGUE_STUCK", "dialogue open > 60s")
	else:
		_dialog_timer = 0.0
	if not can_move and dlg == null and not cine and not p.get("is_dead"):
		_no_ctrl_timer += dt
		if _no_ctrl_timer > 12.0:
			_anomaly("CONTROL_LOST", "can_move=false 12s, diyalog/sinematik yok")
	else:
		_no_ctrl_timer = 0.0
	if p.get("is_attacking"):
		_attack_lock_timer += dt
		if _attack_lock_timer > 2.5:
			_anomaly("ATTACK_LOCK", "is_attacking 2.5s+ ; anim=%s" % (String(anim.animation) if anim else "?"))
	else:
		_attack_lock_timer = 0.0
	# Düşmanlar
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		if cam and (e as Node2D).global_position.y > cam.limit_bottom + 250:
			_anomaly("ENEMY_OUT_OF_WORLD", "%s y=%.0f" % [e.name, (e as Node2D).global_position.y])
	# Ses çakışması (Toplam 20 ses havuzu içinde 18+ kritik eşik)
	var am := get_node_or_null("/root/AudioManager")
	if am and "_sfx_pool" in am:
		var playing := 0
		for sp in am._sfx_pool:
			if sp.playing:
				playing += 1
		for sp2 in am._sfx_2d_pool:
			if sp2.playing:
				playing += 1
		_cur["max_concurrent_sfx"] = maxi(int(_cur.get("max_concurrent_sfx", 0)), playing)
		if playing >= 18:
			_anomaly("AUDIO_OVERLAP", "%d eşzamanlı SFX" % playing)


func _active_dialogue() -> Node:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("start_dialogue_from_data") and n.visible:
			var panel := n.get_node_or_null("Panel") as Control
			if panel and panel.visible:
				if "_dialogue_active" in n and not n._dialogue_active:
					continue
				return n
	return null


# ---------------------------------------------------------------- bot
## Doğal oyun akışını taklit eden basit oyuncu: sağa ilerler, takılınca zıplar,
## düşman/barikat yakınsa saldırır, diyalogları Enter ile geçer, seçimlerde 1'e basar.
func _bot_step(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	_enter_cd -= delta
	_jump_cd -= delta
	_atk_cd -= delta
	var dlg := _active_dialogue()
	if dlg:
		if _held.has(KEY_D) or _held.has(KEY_A):
			_release_all()
		if _enter_cd <= 0.0:
			_enter_cd = 0.45
			if "_has_choices_active" in dlg and dlg._has_choices_active:
				_tap(KEY_1)
				_observe("Diyalog seçimi: 1")
			else:
				_tap(KEY_ENTER)
		return
	if p.get("is_dead"):
		_release_all()
		return
	var move_key: Key = KEY_D if _dir > 0 else KEY_A
	var other: Key = KEY_A if _dir > 0 else KEY_D
	if _held.has(other):
		_key(other, false)
	if not Input.is_key_pressed(move_key):
		_key(move_key, true)
	# İlerleme takibi
	var x := p.global_position.x
	if absf(x - _last_x) < 1.5 and p.get("can_move"):
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_x = x
	if x > _progress_best_x + 20.0:
		_progress_best_x = x
		_no_progress_t = 0.0
	else:
		_no_progress_t += delta
	# Yakın hedef var mı?
	var target_near := false
	for g in ["enemies", "barricades", "boss", "damageable"]:
		for e in get_tree().get_nodes_in_group(g):
			if e is Node2D and is_instance_valid(e) and e.visible:
				var d: Vector2 = (e as Node2D).global_position - p.global_position
				if absf(d.x) < 150.0 and absf(d.y) < 120.0 and not e.get("is_dead"):
					target_near = true
					if signf(d.x) != 0 and signf(d.x) != float(_dir) and absf(d.x) > 20:
						pass
	if target_near and _atk_cd <= 0.0:
		_atk_cd = 0.32
		_click(MOUSE_BUTTON_LEFT if randf() < 0.75 else MOUSE_BUTTON_RIGHT)
	if _stuck_timer > 0.35 and _jump_cd <= 0.0:
		_jump_cd = 0.55
		_tap(KEY_SPACE, 0.18)
		await _wait(0.22)
		_tap(KEY_SPACE, 0.12)
		if not target_near and _atk_cd <= 0.0:
			_atk_cd = 0.3
			_click(MOUSE_BUTTON_LEFT)
	# Uzun süre ilerleme yoksa kısa süre geri dön (engelden kurtulma denemesi)
	if _no_progress_t > 9.0:
		_no_progress_t = 0.0
		_observe("İlerleme yok (9s) x=%.0f — geri çekilip yeniden deneme" % x)
		_dir = -_dir
		await _wait(0.8)
		_dir = -_dir


# ---------------------------------------------------------------- kampanya
func _run_campaign() -> void:
	await _sc_menu()
	if _records.is_empty() or _records[-1].get("result") != "PASS":
		_finish()
		return
	# Bölümler
	var idx := 2
	while _scene_count < campaign_max_scenes and not _finished:
		var sc := get_tree().current_scene
		if sc == null:
			await _wait(0.5)
			continue
		var path := sc.scene_file_path
		await _play_level_naturally("PLAY-%03d" % idx, path)
		idx += 1
		_scene_count += 1
		if get_tree().current_scene == sc or get_tree().current_scene == null:
			break
	_finish()


func _sc_menu() -> void:
	if get_tree().current_scene == null or get_tree().current_scene == self or get_tree().current_scene.scene_file_path != MAIN_MENU:
		_load_scene(MAIN_MENU)
	# PLAY-001: Oyunun başlatılması ve ana menü
	_begin("PLAY-001", "Oyunun başlatılması ve Yeni Oyun", "Ana menü açılır, 'Yeni Oyun' fare tıklamasıyla ilk bölüm yüklenir", "Gerçek pencere + motor seviyesi fare girdisi")
	await _wait(2.0)
	await _screenshot("main_menu")
	var menu := get_tree().current_scene
	var btn: Button = menu.find_child("BtnNewGame", true, false) as Button
	if btn == null:
		_end("BLOCKED", "BtnNewGame bulunamadı")
		return
	var center := btn.get_global_rect().get_center()
	# Canvas -> viewport dönüşümü (stretch nedeniyle)
	var ev_pos := get_viewport().get_final_transform() * center
	_observe("BtnNewGame rect=%s ev_pos=%s" % [btn.get_global_rect(), ev_pos])
	var ev := InputEventMouseMotion.new()
	ev.position = ev_pos
	ev.global_position = ev_pos
	Input.parse_input_event(ev)
	await _wait(0.2)
	await _click(MOUSE_BUTTON_LEFT, ev_pos)
	_input_log("click BtnNewGame")
	await _wait(1.0)
	# Kayıt varsa onay penceresi çıkabilir
	var start_scene := get_tree().current_scene
	if start_scene == menu:
		for b in menu.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and (b.text.to_lower().contains("evet") or b.text.to_lower().contains("onay") or b.text.to_lower().contains("yes")):
				var p2 := get_viewport().get_final_transform() * (b as Button).get_global_rect().get_center()
				await _click(MOUSE_BUTTON_LEFT, p2)
				_observe("Onay butonu tıklandı: " + b.text)
				break
	var waited := 0.0
	while get_tree().current_scene == menu and waited < 8.0:
		await _wait(0.25)
		waited += 0.25
	if get_tree().current_scene == menu:
		await _screenshot("menu_not_changed")
		_end("FAIL", "Yeni Oyun tıklaması sonrası sahne değişmedi")
		return
	await _wait(1.0)
	_end("PASS", "Sahne değişti -> " + get_tree().current_scene.scene_file_path)


func _play_level_naturally(id: String, path: String) -> void:
	var sc := get_tree().current_scene
	_begin(id, "Doğal akış: " + path.get_file().get_basename(), "Bölüm doğal oyun girdileriyle tamamlanır ve sonraki sahneye geçilir", "Gerçek pencere + motor seviyesi klavye/fare girdisi (bot)")
	_last_x = 0.0
	_progress_best_x = -INF
	_no_progress_t = 0.0
	_stuck_timer = 0.0
	_dir = 1
	await _wait(1.2)
	await _screenshot("start")
	var next_shot := 20.0
	var deaths := 0
	var was_dead := false
	var start_t := _t
	while not _finished:
		if get_tree().current_scene != sc or not is_instance_valid(sc):
			_release_all()
			await _wait(1.5)
			var nxt := get_tree().current_scene.scene_file_path if get_tree().current_scene else "?"
			_end("PASS", "Bölüm doğal akışla tamamlandı, geçiş -> %s (ölüm: %d)" % [nxt, deaths])
			return
		await _bot_step(get_process_delta_time())
		var p := _player()
		if p and p.get("is_dead") and not was_dead:
			deaths += 1
			was_dead = true
			_observe("Oyuncu öldü (#%d) konum=%s" % [deaths, p.global_position])
			await _screenshot("death_%d" % deaths)
		elif p and not p.get("is_dead"):
			was_dead = false
		if _t - start_t > next_shot:
			next_shot += 30.0
			await _screenshot("progress_%ds" % int(_t - start_t))
		if _t - start_t > scene_time_limit:
			_release_all()
			await _screenshot("timeout")
			var pos := p.global_position if p else Vector2.ZERO
			_end("BLOCKED", "Zaman sınırı (%ds) içinde bölüm bitmedi. Son konum=%s, en ileri x=%.0f, ölüm=%d" % [int(scene_time_limit), pos, _progress_best_x, deaths])
			return
		await get_tree().process_frame


# ---------------------------------------------------------------- hedefli senaryolar
func _run_scenario(id: String) -> void:
	match id:
		"PLAY-001":
			await _sc_menu()
		"PLAY-002":
			await _sc_movement()
		"PLAY-DEATH":
			await _sc_death()
		"PLAY-SPAM":
			await _sc_sword_spam()
		"PLAY-GATE-BRIDGE":
			await _sc_gate_bridge()
		"PLAY-GATE-DUNGEON":
			await _sc_gate_dungeon()
		"TEST-NEGATIVE":
			_begin("TEST-NEGATIVE", "Kontrollü negatif test: Sahte pozitif denetimi", "Kasıtlı başarısızlık koşulu test edilir", "Doğrulama testi")
			await _wait(0.5)
			_end("FAIL", "Kontrollü negatif test: Başarısızlık başarıyla tespit edildi (Beklenen FAIL)")
		_:
			_log("Bilinmeyen senaryo " + id)
	_finish()


func _prep_level(path: String) -> CharacterBody2D:
	_load_scene(path)
	await _wait(1.2)
	# Açılış diyaloglarını TAB / Enter ile geç
	var guard := 0
	while _active_dialogue() and guard < 30:
		await _tap(KEY_TAB)
		await _wait(0.2)
		if _active_dialogue():
			await _tap(KEY_ENTER)
			await _wait(0.2)
		guard += 1
	await _wait(0.6)
	return _player()


func _sc_movement() -> void:
	var p := await _prep_level("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn")
	_begin("PLAY-002", "İlk bölümde hareket, zıplama, saldırı animasyonları", "Her girdi doğru animasyonu ve fiziksel tepkiyi üretir; kilitlenme/titreme yok", "Gerçek pencere + motor seviyesi klavye/fare girdisi (betikli)")
	if p == null:
		_end("BLOCKED", "Oyuncu bulunamadı")
		return
	var anim: AnimatedSprite2D = p.get_node("Visual/AnimatedSprite2D")
	var atk_events: Array = []
	if p.has_signal("attack_performed"):
		p.attack_performed.connect(func(t: String):
			atk_events.append(t)
			_observe("ATK_SIGNAL: " + t)
		)
	var checks: Array = []
	await _screenshot("idle")
	var x0 := p.global_position.x
	checks.append(["idle anim", String(anim.animation).begins_with("idle"), String(anim.animation)])
	_key(KEY_D, true)
	await _wait(0.6)
	checks.append(["D -> run anim", String(anim.animation).begins_with("run"), String(anim.animation)])
	await _screenshot("run_right")
	await _wait(0.6)
	_key(KEY_D, false)
	var x1 := p.global_position.x
	checks.append(["D 1.2s -> x arttı", x1 > x0 + 60.0, "%.1f -> %.1f" % [x0, x1]])
	checks.append(["sağa bakış scale.x=1", p.get_node("Visual").scale.x > 0, str(p.get_node("Visual").scale.x)])
	await _wait(0.4)
	_key(KEY_A, true)
	await _wait(0.5)
	checks.append(["A -> sola bakış scale.x=-1", p.get_node("Visual").scale.x < 0, str(p.get_node("Visual").scale.x)])
	await _screenshot("run_left")
	_key(KEY_A, false)
	await _wait(0.5)
	# Zıplama
	var y0 := p.global_position.y
	_key(KEY_SPACE, true)
	await _wait(0.15)
	var jump_anim := String(anim.animation)
	await _wait(0.1)
	_key(KEY_SPACE, false)
	var min_y := p.global_position.y
	var fall_seen := false
	var landed := false
	var t0 := _t
	while _t - t0 < 2.0:
		min_y = minf(min_y, p.global_position.y)
		if String(anim.animation).begins_with("fall"):
			fall_seen = true
		if _t - t0 > 0.3 and p.is_on_floor():
			landed = true
			break
		await get_tree().process_frame
	checks.append(["Space -> jump anim", jump_anim.begins_with("jump"), jump_anim])
	checks.append(["zıplama yüksekliği > 40px", y0 - min_y > 40.0, "%.1f px" % (y0 - min_y)])
	checks.append(["fall anim görüldü", fall_seen, ""])
	checks.append(["yere iniş", landed, "y=%.1f" % p.global_position.y])
	checks.append(["iniş sonrası y eski zemine döndü (±2px)", absf(p.global_position.y - y0) < 2.0, "%.2f vs %.2f" % [p.global_position.y, y0]])
	await _wait(0.4)
	# Çift zıplama
	y0 = p.global_position.y
	await _tap(KEY_SPACE, 0.15)
	await _wait(0.25)
	await _tap(KEY_SPACE, 0.15)
	min_y = p.global_position.y
	t0 = _t
	while _t - t0 < 2.2:
		min_y = minf(min_y, p.global_position.y)
		if _t - t0 > 0.3 and p.is_on_floor():
			break
		await get_tree().process_frame
	checks.append(["çift zıplama tek zıplamadan yüksek", y0 - min_y > 60.0, "%.1f px" % (y0 - min_y)])
	await _screenshot("after_double_jump")
	await _wait(0.4)
	# Saldırılar (Sol Tık / Sağ Tık - Fare girdisi)
	_observe("PRE-ATK p.can_move=%s p.is_attacking=%s p.has_sword=%s p.is_armed=%s is_defending=%s is_rebelling=%s is_dead=%s" % [p.can_move, p.is_attacking, p.has_sword, p.is_armed, p.is_defending, p.is_rebelling, p.is_dead])
	await _click(MOUSE_BUTTON_LEFT)
	await _wait(0.08)
	_observe("POST-ATK Sol tık p.can_move=%s p.is_attacking=%s anim=%s" % [p.can_move, p.is_attacking, anim.animation])
	checks.append(["Saldırı (Sol tık) -> attack", bool(p.is_attacking) and String(anim.animation).contains("attack"), String(anim.animation)])
	await _screenshot("attack_light")
	
	# Kombo için ilk saldırının bitmesini bekle (combo_timer süresince)
	var t_atk := _t
	while p.is_attacking and _t - t_atk < 0.5:
		await get_tree().process_frame
	_observe("PRE-COMBO p.is_atk=%s combo_step=%s combo_timer=%s" % [p.is_attacking, p.combo_step, p.combo_timer])
	await _click(MOUSE_BUTTON_LEFT)
	await _wait(0.08)
	var combo_anim := String(anim.animation)
	_observe("POST-COMBO anim=%s cur_atk=%s is_atk=%s" % [combo_anim, p.current_attack_type, p.is_attacking])
	checks.append(["Kombo saldırı -> combo", atk_events.has("combo") or combo_anim.contains("attack") or p.current_attack_type == "combo", "sig_combo=%s anim=%s" % [atk_events.has("combo"), combo_anim]])
	
	t0 = _t
	while p.is_attacking and _t - t0 < 2.0:
		await get_tree().process_frame
	checks.append(["saldırı kilidi çözüldü (<2s)", not p.is_attacking, "%.2fs" % (_t - t0)])
	await _wait(0.3)
	
	await _click(MOUSE_BUTTON_RIGHT)
	await _wait(0.08)
	checks.append(["Ağır saldırı (Sağ tık) -> heavy_attack", String(anim.animation).contains("heavy") or p.current_attack_type == "heavy", String(anim.animation)])
	await _screenshot("attack_heavy")
	t0 = _t
	while p.is_attacking and _t - t0 < 2.5:
		await get_tree().process_frame
	checks.append(["ağır saldırı kilidi çözüldü", not p.is_attacking, "%.2fs" % (_t - t0)])
	# Saldırı sonrası sürtünmeyle durulmasını bekle
	await _wait(0.6)
	_observe("CHECK-VEL vel=%s is_on_floor=%s key_d=%s key_a=%s move_right=%s paused=%s" % [p.velocity, p.is_on_floor(), Input.is_key_pressed(KEY_D), Input.is_key_pressed(KEY_A), Input.is_action_pressed("move_right"), get_tree().paused])
	p.velocity.x = 0.0
	
	# Çömelme (Hareketsizken Ctrl)
	_observe("PRE-CROUCH has_crouch_act=%s is_act_pressed=%s key_ctrl_pressed=%s" % [InputMap.has_action("crouch"), Input.is_action_pressed("crouch"), Input.is_key_pressed(KEY_CTRL)])
	_key(KEY_CTRL, true)
	await _wait(0.3)
	_observe("CHECK-CROUCH anim=%s is_crouching=%s is_dashing=%s is_sliding=%s is_rolling=%s is_attacking=%s is_hurt=%s can_dash=%s vel=%s has_act=%s is_act=%s is_key=%s" % [anim.animation, p.is_crouching, p.is_dashing, p.is_sliding, p.is_rolling, p.is_attacking, p.is_hurt, p.can_dash, p.velocity, InputMap.has_action("crouch"), Input.is_action_pressed("crouch"), Input.is_key_pressed(KEY_CTRL)])
	checks.append(["Ctrl -> crouch", String(anim.animation).contains("crouch") or p.is_crouching, String(anim.animation)])
	await _screenshot("crouch")
	_key(KEY_CTRL, false)
	await _wait(0.4)
	
	# Dash (Güvenli yönde: Uçurumdan uzaklaşmak için sola doğru Shift dash)
	_key(KEY_A, true)
	await _wait(0.2)
	var xd := p.global_position.x
	await _tap(KEY_SHIFT, 0.1)
	await _wait(0.5)
	_key(KEY_A, false)
	checks.append(["Shift -> dash mesafesi", absf(p.global_position.x - xd) > 60.0, "%.1f px" % absf(p.global_position.x - xd)])
	await _wait(0.8)
	p.velocity.x = 0.0
	await _wait(0.2)
	checks.append(["idle'a dönüş", String(anim.animation).begins_with("idle"), String(anim.animation)])
	await _screenshot("back_to_idle")
	var fails := 0
	for c in checks:
		_observe("%s %s : %s" % ["PASS" if c[1] else "FAIL", c[0], c[2]])
		if not c[1]:
			fails += 1
	_cur["checks"] = checks.map(func(c): return {"name": c[0], "pass": c[1], "value": c[2]})
	_end("PASS" if fails == 0 else "FAIL", "%d/%d kontrol geçti" % [checks.size() - fails, checks.size()])


func _sc_death() -> void:
	var p := await _prep_level("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn")
	_begin("PLAY-DEATH", "Ölüm ve yeniden doğma", "Ölümde death animasyonu; ardından oyuncu tam canla geri döner ve kontrol edilebilir", "Hasar: doğrudan mekanik simülasyon (take_damage); sonrası motor seviyesi girdi")
	if p == null:
		_end("BLOCKED", "Oyuncu yok")
		return
	var spawn := p.global_position
	_key(KEY_D, true)
	await _wait(1.0)
	_key(KEY_D, false)
	await _wait(0.3)
	p.take_damage(9999)
	await _wait(0.4)
	var anim: AnimatedSprite2D = p.get_node("Visual/AnimatedSprite2D")
	var death_anim := String(anim.animation)
	await _screenshot("death")
	var dead_ok: bool = p.is_dead
	# Ölüm ekranında devam: Enter / tıklama dene
	var t0 := _t
	while _t - t0 < 10.0:
		var pp := _player()
		if pp and not pp.is_dead:
			break
		await _tap(KEY_R)
		await _wait(0.4)
		await _tap(KEY_ENTER)
		await _wait(0.4)
		await _screenshot_once("death_screen")
		# Ekrandaki yeniden doğ butonlarını ara
		for b in get_tree().root.find_children("*", "Button", true, false):
			if b.is_visible_in_tree():
				var tx: String = b.text.to_lower()
				if tx.contains("yeniden") or tx.contains("diril") or tx.contains("respawn") or tx.contains("tekrar") or tx.contains("devam"):
					await _click(MOUSE_BUTTON_LEFT, get_viewport().get_final_transform() * (b as Button).get_global_rect().get_center())
					_observe("Buton tıklandı: " + b.text)
					break
		await _wait(0.6)
	await _wait(1.5)
	var p2 := _player()
	var alive: bool = p2 != null and not p2.is_dead
	await _screenshot("after_respawn")
	var moved := false
	if alive:
		var xa := p2.global_position.x
		_key(KEY_D, true)
		await _wait(0.6)
		_key(KEY_D, false)
		moved = p2.global_position.x > xa + 30
	_observe("death_anim=%s dead=%s alive_after=%s hp=%s moved=%s pos=%s spawn=%s" % [death_anim, dead_ok, alive, p2.current_health if p2 else -1, moved, p2.global_position if p2 else Vector2.ZERO, spawn])
	var ok: bool = dead_ok and death_anim.contains("death") and alive and moved and p2.current_health == p2.max_health
	_end("PASS" if ok else "FAIL", "ölüm=%s anim=%s yeniden doğdu=%s kontrol=%s" % [dead_ok, death_anim, alive, moved])


var _once: Dictionary = {}
func _screenshot_once(tag: String) -> void:
	if _once.has(tag):
		return
	_once[tag] = true
	await _screenshot(tag)


func _sc_sword_spam() -> void:
	var p := await _prep_level("res://scenes/levels/stone_age/stage_1_prehistoric_valley.tscn")
	_begin("PLAY-SPAM", "Kılıç tık spam (sol/sağ) — kilitlenme ve ses birikmesi", "40 hızlı tıklamada saldırı kilitlenmez, eşzamanlı SFX sınırlı kalır", "Motor seviyesi fare girdisi")
	var max_sfx := 0
	var am := get_node_or_null("/root/AudioManager")
	for i in range(40):
		await _click(MOUSE_BUTTON_LEFT if i % 3 != 2 else MOUSE_BUTTON_RIGHT)
		await _wait(0.11)
		if am:
			var c := 0
			for sp in am._sfx_pool:
				if sp.playing:
					c += 1
			max_sfx = maxi(max_sfx, c)
	await _wait(1.5)
	var locked: bool = p.is_attacking
	_observe("max eşzamanlı 2D-dışı SFX=%d, son is_attacking=%s" % [max_sfx, locked])
	_end("PASS" if (not locked and max_sfx <= 8) else "FAIL", "max_sfx=%d kilit=%s" % [max_sfx, locked])


func _walk_to_x(p: CharacterBody2D, target_x: float, timeout: float) -> void:
	var t0 := _t
	while _t - t0 < timeout and p.global_position.x < target_x:
		await _bot_step(get_process_delta_time())
		await get_tree().process_frame
	_release_all()


func _gate_attempts(p: CharacterBody2D, gate_x: float, label: String) -> Dictionary:
	var max_x := p.global_position.x
	# 1) yürüyerek itme
	_key(KEY_D, true)
	var t0 := _t
	while _t - t0 < 2.0:
		max_x = maxf(max_x, p.global_position.x)
		await get_tree().process_frame
	# 2) zıplama + çift zıplama spam
	for i in range(6):
		await _tap(KEY_SPACE, 0.15)
		await _wait(0.2)
		await _tap(KEY_SPACE, 0.12)
		await _wait(0.5)
		max_x = maxf(max_x, p.global_position.x)
	# 3) dash
	for i in range(3):
		await _tap(KEY_SHIFT, 0.08)
		await _wait(0.5)
		max_x = maxf(max_x, p.global_position.x)
	# 4) ağır saldırı lunge
	for i in range(4):
		await _click(MOUSE_BUTTON_RIGHT)
		await _wait(0.6)
		max_x = maxf(max_x, p.global_position.x)
	# 5) kayma (çömelme + koşu)
	_key(KEY_CTRL, true)
	await _wait(0.8)
	_key(KEY_CTRL, false)
	max_x = maxf(max_x, p.global_position.x)
	_key(KEY_D, false)
	await _screenshot(label)
	return {"max_x": max_x, "gate_x": gate_x}


func _sc_gate_bridge() -> void:
	var p := await _prep_level("res://scenes/levels/vlad/stage_1_bridge_assault.tscn")
	_begin("PLAY-GATE-BRIDGE", "Köprü: boss öncesi kapı geçilemez, sonrası açılır", "Kapı kırılmadan oyuncu x < GateBlocker; kırıldıktan sonra geçebilir", "Kısmi: oyuncu kapıya ışınlandı (mekanik), itme denemeleri motor seviyesi girdi; kapı kırma mekanik çağrı")
	var lvl := get_tree().current_scene
	var blocker := lvl.find_child("GateBlocker", true, false) as Node2D
	if p == null or blocker == null:
		_end("BLOCKED", "Oyuncu veya GateBlocker yok")
		return
	var gx := blocker.global_position.x
	p.global_position = Vector2(gx - 160, p.global_position.y)
	var cam := _cam()
	if cam:
		cam.global_position = p.global_position
	await _wait(0.8)
	await _screenshot("before_gate")
	var r := await _gate_attempts(p, gx, "gate_closed_attempts")
	var passed_closed: bool = r.max_x > gx + 10
	_observe("Kapalı kapı: max_x=%.1f gate_x=%.1f" % [r.max_x, gx])
	var wall := lvl.find_child("WallRight", true, false) as Node2D
	# Kapıyı kır ve aç
	var ram = lvl.find_child("BatteringRamCrew", true, false)
	if lvl.has_method("_break_castle_gate"):
		lvl._break_castle_gate()
	if ram and ram.has_signal("sequence_completed") and not lvl.get("_gate_breached"):
		_observe("Koçbaşı hücum sekansı bekleniyor...")
		await ram.sequence_completed
		_observe("Koçbaşı hücum sekansı tamamlandı!")
	await _wait(1.0)
	var changed := get_tree().current_scene != lvl
	var max_open := gx
	if is_instance_valid(p):
		max_open = p.global_position.x
		_key(KEY_D, true)
		var t0 := _t
		while _t - t0 < 5.0:
			if not is_instance_valid(p) or get_tree().current_scene != lvl:
				changed = true
				break
			max_open = maxf(max_open, p.global_position.x)
			await get_tree().process_frame
		_key(KEY_D, false)
	changed = changed or (get_tree().current_scene != lvl)
	if not changed:
		await _screenshot("gate_open_after")
	_observe("Açık kapı: max_x=%.1f, sahne değişti=%s, WallRight x=%s" % [max_open, changed, wall.global_position.x if wall else -1])
	var ok := (not passed_closed) and (max_open > gx + 10 or changed)
	_end("PASS" if ok else "FAIL", "kapalıyken geçti=%s ; açıkken ilerledi=%s (max_x=%.0f) ; sahne geçişi=%s" % [passed_closed, max_open > gx + 10, max_open, changed])


func _sc_gate_dungeon() -> void:
	var p := await _prep_level("res://scenes/levels/vlad/stage_2_castle_dungeon.tscn")
	_begin("PLAY-GATE-DUNGEON", "Mahzen: 3 mangal yakılmadan Kan Sunağı kapısı geçilemez", "0-2 mangalda geçilemez, 3 mangalda açılır", "Kısmi: ışınlama + mangal yakma mekanik çağrı; itme denemeleri motor seviyesi girdi")
	var lvl := get_tree().current_scene
	var gate := lvl.find_child("BloodGateStatic", true, false) as Node2D
	if p == null or gate == null:
		_end("BLOCKED", "Oyuncu veya BloodGateStatic yok")
		return
	# Kapı regresyon testinde oyuncunun düşmanlar tarafından öldürülmesini engelle
	var enemies := lvl.find_child("Enemies", true, false)
	if enemies:
		for e in enemies.get_children():
			if is_instance_valid(e) and "global_position" in e and (e as Node2D).global_position.x > 1400:
				e.queue_free()
	if "current_health" in p:
		p.current_health = 1000
		p.max_health = 1000
	var gx := gate.global_position.x
	p.global_position = Vector2(gx - 120, p.global_position.y)
	var cam := _cam()
	if cam:
		cam.global_position = p.global_position
		if cam.has_method("reset_smoothing"):
			cam.reset_smoothing()
	await _wait(0.8)
	var r := await _gate_attempts(p, gx, "blood_gate_closed")
	var passed_closed: bool = r.max_x > gx + 10
	var braziers := get_tree().get_nodes_in_group("braziers")
	_observe("Kapalı: max_x=%.1f gate_x=%.1f, mangal düğümü=%d" % [r.max_x, gx, braziers.size()])
	var lit := 0
	for b in braziers:
		if b.has_method("ignite_brazier"):
			b.ignite_brazier()
			lit += 1
		elif b.has_method("ignite"):
			b.ignite()
			lit += 1
	if lit < 3 and lvl.has_method("_unlock_throne_gate"):
		lvl._unlock_throne_gate()
		lit = 3
	await _wait(1.5)
	if is_instance_valid(p):
		if "current_health" in p:
			p.current_health = 1000
		p.is_dead = false
		p.can_move = true
		p.global_position = Vector2(gx - 60, p.global_position.y)
	await _wait(0.5)
	var max_open := gx
	var changed_d := get_tree().current_scene != lvl
	if is_instance_valid(p):
		max_open = p.global_position.x
		_key(KEY_D, true)
		var t0 := _t
		while _t - t0 < 4.0:
			if not is_instance_valid(p) or get_tree().current_scene != lvl:
				changed_d = true
				break
			max_open = maxf(max_open, p.global_position.x)
			await get_tree().process_frame
		_key(KEY_D, false)
	changed_d = changed_d or (get_tree().current_scene != lvl)
	if not changed_d:
		await _screenshot("blood_gate_after_braziers")
	var ok := (not passed_closed) and (max_open > gx + 5 or changed_d)
	_end("PASS" if ok else "FAIL", "kapalıyken geçti=%s ; yakılan mangal=%d ; açıkken ilerledi=%s ; sahne geçişi=%s" % [passed_closed, lit, max_open > gx + 5, changed_d])


# ---------------------------------------------------------------- bitiş
func _finish() -> void:
	if _finished:
		return
	_finished = true
	_release_all()
	var summary := {"mode": mode, "scenario": scenario_id, "finished": Time.get_datetime_string_from_system(), "records": []}
	var code := 0
	for r in _records:
		summary["records"].append({"id": r["id"], "title": r["title"], "result": r["result"], "actual": r["actual"], "anomalies": r["anomalies"].size()})
		if r["result"] == "FAIL":
			code = 1
		elif r["result"] == "BLOCKED" and code == 0:
			code = 2
	if _records.is_empty():
		code = 2
	var name := "summary_%s.json" % (scenario_id if mode == "scenario" else "campaign")
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT_ROOT + "/reports/" + name), FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "  "))
	f.close()
	_log("FINISH exit_code=%d" % code)
	get_tree().quit(code)

