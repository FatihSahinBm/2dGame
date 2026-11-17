extends Node

## res://tests/verify_egypt_chapter_runner.gd
## Bölüm 3 (Antik Mısır) veri / entegrasyon doğrulaması — Epic 2D-143.
## Hikâye JSON'u (TR+EN), görev & Codex kaydı, UI çevirileri (JSON+CSV), ses kaydı,
## bölüm seçimi / kilit, Bölüm 2 → 3 bağlantısı, sahnelerin yüklenmesi ve kod kalitesi sınırı.
## Çalıştırma: Godot --headless --path . res://tests/verify_egypt_chapter.tscn

const CH3: String = "res://data/story/chapter_3_egypt.json"
const LEVELS: Array[String] = [
	"res://scenes/levels/egypt/egypt_01_crimson_desert.tscn",
	"res://scenes/levels/egypt/egypt_02_monument_courtyard.tscn",
	"res://scenes/levels/egypt/egypt_03_cursed_tomb.tscn",
	"res://scenes/levels/egypt/egypt_04_sun_throne.tscn",
]
const NEW_SCRIPT_DIRS: Array[String] = [
	"res://scripts/levels/egypt", "res://scripts/objects/egypt", "res://scripts/hazards/egypt", "res://scripts/enemies/egypt",
]
const NEW_SCRIPTS: Array[String] = [
	"res://scripts/allies/egypt_slave.gd", "res://scripts/components/chapter_data_registry.gd",
	"res://scripts/components/egypt_chapter_state.gd", "res://scripts/effects/sword_seal_leak_vfx.gd",
	"res://scripts/effects/sandstorm_overlay.gd", "res://scripts/effects/floating_pyramid.gd", "res://scripts/ui/egypt_boss_bar.gd",
]
const USED_DIALOGUE_KEYS: Array[String] = [
	"egypt_arrival", "egypt_first_guard", "egypt_sand_trap_hint", "egypt_courtyard_intro", "egypt_slave_plea",
	"egypt_slave_freed", "egypt_slave_drained", "egypt_slave_killed", "egypt_sarcophagus_choice", "egypt_sarcophagus_drained",
	"egypt_sarcophagus_shattered", "egypt_courtyard_exit_redemption", "egypt_courtyard_exit_corrupted", "egypt_tomb_intro",
	"egypt_tablet_sun", "egypt_tablet_engine", "egypt_tablet_heart", "egypt_seal_key_found", "egypt_seal_door_open",
	"egypt_mummy_wave", "egypt_pharaoh_taunt", "egypt_pharaoh_taunt_corrupted", "egypt_pharaoh_phase_2",
	"egypt_pharaoh_phase_3", "egypt_pharaoh_last_words", "egypt_memory_flashback", "egypt_sword_evolution",
	"egypt_outro_redemption", "egypt_outro_god_king", "egypt_sword_scream_texts",
]

var failures: int = 0
var passes: int = 0


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)


func _ready() -> void:
	print("--- EGYPT CHAPTER (2D-143) DATA & INTEGRATION ---")
	_test_story_data()
	_test_quests_and_codex()
	_test_translations()
	_test_audio()
	_test_chapter_flow_links()
	await _test_scenes_load()
	_test_script_limits()
	print("--- RESULT: %d passed, %d failed ---" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_story_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CH3))
	check(parsed is Dictionary, "chapter_3_egypt.json geçerli JSON")
	var dialogues: Dictionary = (parsed as Dictionary).get("dialogues", {})
	for key: String in USED_DIALOGUE_KEYS:
		var seq: Variant = dialogues.get(key)
		var ok: bool = seq is Array and not (seq as Array).is_empty()
		if ok:
			for entry: Variant in seq as Array:
				var e: Dictionary = entry as Dictionary
				ok = ok and not str(e.get("text", "")).is_empty() and not str(e.get("text_en", "")).is_empty()
				if e.has("speaker") and not str(e["speaker"]).is_empty():
					ok = ok and not str(e.get("speaker_en", "")).is_empty()
				for c: Variant in e.get("choices", []) as Array:
					ok = ok and not str((c as Dictionary).get("text_en", "")).is_empty() and not str((c as Dictionary).get("action", "")).is_empty()
		check(ok, "diyalog '%s' var ve TR/EN eksiksiz" % key)
	var loader: GDScript = load("res://scripts/autoloads/story_data_loader.gd") as GDScript
	check(loader.get_dialogue_sequence("egypt_pharaoh_taunt").size() == 3, "StoryDataLoader bölüm 3 diyaloğunu fallback ile buluyor")
	var plea: Array = loader.get_dialogue_sequence("egypt_slave_plea")
	var actions: Array = []
	for c: Variant in (plea[0] as Dictionary).get("choices", []):
		actions.append((c as Dictionary).get("action"))
	check(actions == ["free_slave", "drain_slave"], "köle seçimi: kurtar / sömür eylemleri")
	var memory: Array = loader.get_dialogue_sequence("egypt_memory_flashback")
	var stab: bool = false
	for e: Variant in memory:
		stab = stab or str((e as Dictionary).get("text", "")).contains("sırtından")
	check(stab, "3. Anı Kırılması: Büyücü dostun sırtından vurulduğu anı sahneleniyor")
	check(dialogues.has("ability_unlock_egypt"), "kılıç evrimi (ability_unlock_egypt) verisi var")


func _test_quests_and_codex() -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	var cm: Node = get_node_or_null("/root/CodexManager")
	check(qm != null and not qm.get_quest("egypt_curse_of_the_sun").is_empty(), "ana görev JSON'dan kaydedildi")
	check(qm != null and not qm.get_quest("egypt_break_the_chains").is_empty(), "yan görev JSON'dan kaydedildi")
	var main_q: Dictionary = qm.get_quest("egypt_curse_of_the_sun") if qm else {}
	check((main_q.get("stages", []) as Array).size() == 5, "ana görevin 5 aşaması var")
	for id: String in ["pyramid_guard", "risen_mummy", "pharaoh_king", "egypt_slave", "egypt_tablet_sun", "egypt_tablet_engine", "egypt_tablet_heart"]:
		var entry: Dictionary = cm.get_entry(id) if cm else {}
		check(not entry.is_empty() and not str(entry.get("title_en", "")).is_empty(), "Codex girişi '%s' kayıtlı (TR/EN)" % id)
	if cm:
		cm.reset_codex()
		check(not cm.get_entry("pharaoh_king").is_empty(), "Codex sıfırlamada bölüm 3 girişleri korunuyor")
		check(cm.unlock_entry("egypt_tablet_heart") and cm.is_unlocked("egypt_tablet_heart"), "lore tableti Codex'te açılabiliyor")


func _test_translations() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/translations/translations.json")) as Dictionary
	var csv_text: String = FileAccess.get_file_as_string("res://data/translations/translations.csv")
	var needed: Array[String] = ["CHAPTER_3_TITLE", "CHAPTER_3_ERA", "RESULTS_CONTINUE", "HUD_SEAL_WEAKENED", "EGYPT_BOSS_NAME",
		"EGYPT_SEAL_PROGRESS", "PROMPT_EGYPT_SLAVE", "PROMPT_EGYPT_SARCOPHAGUS", "PROMPT_EGYPT_TABLET", "STAGE_EGYPT_4", "EGYPT_ABILITY_TAG"]
	for scene_tut: String in ["01", "02", "03", "04"]:
		for part: String in ["TITLE", "SUB", "DESC"]:
			needed.append("EGYPT_TUT_%s_%s" % [scene_tut, part])
	var all_ok: bool = true
	for key: String in needed:
		var e: Dictionary = data.get(key, {})
		var ok: bool = not str(e.get("tr", "")).is_empty() and not str(e.get("en", "")).is_empty() and csv_text.contains("\n" + key + ",")
		if not ok:
			printerr("  eksik çeviri: ", key)
		all_ok = all_ok and ok
	check(all_ok, "%d UI anahtarı JSON (TR+EN) ve CSV'de" % needed.size())
	var loc: Node = get_node_or_null("/root/LocalizationManager")
	if loc and loc.has_method("set_locale"):
		loc.set_locale("en")
		check(tr("EGYPT_BOSS_NAME") == "The Cursed Pharaoh King", "EN yerelleştirme çalışıyor")
		var en_seq: Array = (load("res://scripts/autoloads/story_data_loader.gd") as GDScript).get_dialogue_sequence("egypt_first_guard")
		check(str((en_seq[0] as Dictionary).get("text")).begins_with("Outsider"), "EN diyalog metni seçiliyor")
		loc.set_locale("tr")
		check(tr("EGYPT_BOSS_NAME") == "Lanetli Firavun Kral", "TR yerelleştirme çalışıyor")


func _test_audio() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	for key: String in ["egypt_theme", "egypt_ambience", "pharaoh_phase_1", "pharaoh_phase_2", "pharaoh_phase_3",
			"sun_beam_charge", "sun_beam_fire", "mummy_rise", "mummy_groan", "sarcophagus_open", "sarcophagus_break",
			"soul_drain", "steel_scream", "sand_trap", "cage_open", "seal_unlock", "heart_piece_extract"]:
		check(am != null and am.has_sound(key), "AudioManager '%s' sesini kaydetti" % key)
	if am:
		check(am.get_boss_phase_track_key("pharaoh", 3) == "pharaoh_phase_3", "Firavun faz müziği çözümleniyor")


func _test_chapter_flow_links() -> void:
	var select: GDScript = load("res://scripts/ui/chapter_select_dialog.gd") as GDScript
	var has_ch3: bool = false
	for ch: Dictionary in select.get_script_constant_map()["CHAPTERS"]:
		has_ch3 = has_ch3 or (int(ch["index"]) == 3 and ResourceLoader.exists(str(ch["scene"])))
	check(has_ch3, "bölüm seçiminde Bölüm 3 kartı ve geçerli sahne yolu")
	var gs: Node = get_node_or_null("/root/GameState")
	var sm: Node = get_node_or_null("/root/SaveManager")
	if gs and sm:
		gs.reset_state()
		var locked_before: bool = not sm.is_chapter_unlocked(3) or _any_slot_has_ch2(sm)
		gs.complete_chapter("chapter_2")
		check(locked_before and sm.is_chapter_unlocked(3), "Bölüm 3, Bölüm 2 tamamlanınca açılıyor")
		check(sm.get_friendly_stage_name(LEVELS[3]) == tr("STAGE_EGYPT_4"), "kayıt yuvası sahne adı yerelleştirilmiş")
		gs.reset_state()
	var throne: GDScript = load("res://scripts/levels/vlad/stage_3_throne_room.gd") as GDScript
	var next: String = str(throne.get_script_constant_map().get("NEXT_CHAPTER_SCENE", ""))
	check(next == LEVELS[0], "Bölüm 2 taht odası zaman yırtığı Bölüm 3 Sahne 1'e bağlı")
	var host: Node = Node.new()
	add_child(host)
	var screen: CanvasLayer = (load("res://scripts/ui/results_screen.gd") as GDScript).show_for(host, next)
	check(screen != null and screen.find_child("ContinueButton", true, false) != null, "sonuç ekranında 'Zaman Yırtığına Gir' düğmesi")
	host.queue_free()


func _any_slot_has_ch2(sm: Node) -> bool:
	for slot: int in range(1, 4):
		var info: Dictionary = sm.get_save_info(slot)
		if (info.get("completed_chapters", []) as Array).has("chapter_2") or str(info.get("current_stage_path", "")).contains("/egypt/"):
			return true
	return false


func _test_scenes_load() -> void:
	for path: String in LEVELS:
		var packed: PackedScene = load(path) as PackedScene
		check(packed != null, "sahne yüklendi: %s" % path.get_file())
		if packed == null:
			continue
		var level: Node = packed.instantiate()
		add_child(level)
		await get_tree().process_frame
		await get_tree().physics_frame
		var player: Node2D = level.get_node_or_null("CombatPlayer") as Node2D
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player else null
		check(player != null and level.get_node_or_null("FantasyHUD") != null and level.get_node_or_null("DialogueBox") != null,
			"%s: oyuncu, HUD ve diyalog kutusu" % path.get_file())
		check(cam != null and cam.limit_right == (level as EgyptLevelBase).camera_limits.end.x, "%s: kamera sınırları uygulandı" % path.get_file())
		check(level.get_node_or_null("DeathZone") != null, "%s: ölüm bölgesi (void) var" % path.get_file())
		check(level.get_node_or_null("CampfireCheckpoint") != null, "%s: kontrol noktası (kayıt) var" % path.get_file())
		var next_path: String = (level as EgyptLevelBase).next_scene_path
		check(next_path.is_empty() or ResourceLoader.exists(next_path), "%s: sonraki sahne yolu geçerli" % path.get_file())
		level.queue_free()
		await get_tree().process_frame


func _test_script_limits() -> void:
	var files: Array[String] = NEW_SCRIPTS.duplicate()
	for dir_path: String in NEW_SCRIPT_DIRS:
		for f: String in DirAccess.get_files_at(dir_path):
			if f.ends_with(".gd"):
				files.append(dir_path + "/" + f)
	var over: Array[String] = []
	for f: String in files:
		var lines: int = FileAccess.get_file_as_string(f).split("\n").size()
		if lines > 300:
			over.append("%s (%d)" % [f, lines])
	check(over.is_empty(), "%d yeni script 300 satır sınırında %s" % [files.size(), str(over)])
