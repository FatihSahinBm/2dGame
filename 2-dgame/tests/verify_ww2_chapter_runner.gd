extends Node

## res://tests/verify_ww2_chapter_runner.gd
## Bölüm 4 (2. Dünya Savaşı) veri / entegrasyon / asset doğrulaması — Epic 2D-144.
## Hikâye JSON'u (TR+EN), görev & Codex & eşya kaydı, UI çevirileri (JSON+CSV), ses kaydı,
## asset hattı (sprite manifestleri, FEET_Y, Vlad paritesinde boss animasyon seti),
## bölüm seçimi / kilit, Bölüm 3 → 4 bağlantısı, sahne yükleme ve 300 satır sınırı.
## Çalıştırma: Godot --headless --path . res://tests/verify_ww2_chapter.tscn

const CH4: String = "res://data/story/chapter_4_ww2.json"
const LEVELS: Array[String] = [
	"res://scenes/levels/ww2/stage_1_bombed_trenches.tscn",
	"res://scenes/levels/ww2/stage_2_ruined_city_viaduct.tscn",
	"res://scenes/levels/ww2/stage_3_occult_lab.tscn",
	"res://scenes/levels/ww2/stage_4_command_bunker_boss.tscn",
	"res://scenes/levels/ww2/stage_5_memory_rift.tscn",
]
const NEW_SCRIPT_DIRS: Array[String] = [
	"res://scripts/levels/ww2", "res://scripts/objects/ww2", "res://scripts/hazards/ww2", "res://scripts/enemies/ww2",
]
const NEW_SCRIPTS: Array[String] = [
	"res://scripts/components/ww2_chapter_state.gd", "res://scripts/components/ww2_inventory.gd",
	"res://scripts/effects/sword_vow_aura_vfx.gd", "res://scripts/effects/ww2_alarm_light.gd", "res://scripts/ui/ww2_inventory_items.gd",
]
const CHARACTERS: Dictionary = {
	"trench_infantry": ["idle", "walk", "attack", "hurt", "death"],
	"flamethrower": ["idle", "walk", "attack", "hurt", "death"],
	"gas_sapper": ["idle", "walk", "attack", "hurt", "death"],
	"occult_remnant": ["idle", "walk", "attack", "hurt", "death", "rise"],
	"signal_scout": ["idle", "walk", "attack", "hurt", "death"],
	"trench_officer": ["idle", "walk", "telegraph", "flame_sweep", "groggy", "hurt", "death"],
	"occult_doctor": ["idle", "walk", "cast", "hurt", "death"],
	"failed_experiment": ["idle", "walk", "roar", "slam", "hurt", "death"],
	"wounded_soldier": ["idle", "cower", "walk", "cheer", "drained", "death"],
	"prisoner": ["idle", "cower", "walk", "cheer", "drained", "death"],
}
const COMMANDER_ANIMS: Array[String] = ["idle", "move", "telegraph", "attack_1", "attack_2", "attack_3", "phase_transition", "groggy", "hurt", "death"]

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
	print("--- WW2 CHAPTER (2D-144) DATA, ASSETS & INTEGRATION ---")
	_test_story_data()
	_test_quests_codex_items()
	_test_translations()
	_test_audio()
	_test_asset_pipeline()
	_test_chapter_flow_links()
	await _test_scenes_load()
	_test_script_limits()
	print("--- RESULT: %d passed, %d failed ---" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Kodda kullanılan tüm diyalog anahtarları (seviye ve nesne scriptlerinden taranır)
func _used_dialogue_keys() -> Array[String]:
	var keys: Array[String] = []
	var re: RegEx = RegEx.create_from_string("\"(ww2_[a-z0-9_]+)\"")
	var files: Array[String] = []
	for dir_path: String in NEW_SCRIPT_DIRS:
		for f: String in DirAccess.get_files_at(dir_path):
			if f.ends_with(".gd"):
				files.append(dir_path + "/" + f)
	for f: String in files:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(f)):
			var k: String = m.get_string(1)
			if not keys.has(k) and not k.begins_with("ww2_item") and not k.ends_with("_campfire"):
				keys.append(k)
	return keys


func _test_story_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CH4))
	check(parsed is Dictionary, "chapter_4_ww2.json geçerli JSON")
	var dialogues: Dictionary = (parsed as Dictionary).get("dialogues", {})
	var non_dialogue: Array[String] = ["ww2_battery_silenced", "ww2_backdoor_key", "ww2_reactor_sacrifices", "ww2_relays_solved",
		"ww2_officer_defeated", "ww2_lab_minibosses_defeated", "ww2_explosion", "ww2_experiment_slam", "ww2_commander_death",
		"ww2_shelters", "ww2_hazards", "ww2_gas", "ww2_flares", "ww2_enemies", "ww2_cover", "ww2_turrets", "ww2_energy_tubes",
		"ww2_searchlights", "ww2_train_cars", "ww2_future_blueprint", "ww2_broken_frequency", "ww2_knight_crest", "ww2_lore_iron_heart",
		"ww2_iron_heart", "ww2_wounded_in_trench", "ww2_silent_battery", "ww2_caged_subjects", "ww2_wounded_soldier", "ww2_prisoner",
		"ww2_wounded", "ww2_gas_immune_until", "ww2_adrenaline_base_speed", "ww2_adrenaline_until"]
	var used: Array[String] = _used_dialogue_keys()
	var missing: Array[String] = []
	for key: String in used:
		if non_dialogue.has(key):
			continue
		var seq: Variant = dialogues.get(key)
		var ok: bool = seq is Array and not (seq as Array).is_empty()
		if ok:
			for entry: Variant in seq as Array:
				var e: Dictionary = entry as Dictionary
				ok = ok and not str(e.get("text", "")).is_empty() and not str(e.get("text_en", "")).is_empty()
				if not str(e.get("speaker", "")).is_empty():
					ok = ok and not str(e.get("speaker_en", "")).is_empty()
				for c: Variant in e.get("choices", []) as Array:
					ok = ok and not str((c as Dictionary).get("text_en", "")).is_empty() and not str((c as Dictionary).get("action", "")).is_empty()
		if not ok:
			missing.append(key)
	check(used.size() >= 40 and missing.is_empty(), "koddaki %d diyalog anahtarı JSON'da TR/EN eksiksiz %s" % [used.size(), str(missing)])
	var loader: GDScript = load("res://scripts/autoloads/story_data_loader.gd") as GDScript
	check(loader.get_dialogue_sequence("ww2_commander_taunt").size() == 3, "StoryDataLoader Bölüm 4 diyaloğunu fallback ile buluyor")
	var actions: Array = []
	for key: String in ["ww2_wounded_plea", "ww2_prisoner_plea"]:
		for c: Variant in (loader.get_dialogue_sequence(key)[0] as Dictionary).get("choices", []):
			actions.append((c as Dictionary).get("action"))
	check(actions == ["rescue_wounded", "exploit_wounded", "free_prisoner", "sacrifice_prisoner"], "seçim eylemleri: kurtar/sömür ve kurtar/feda et")
	var memory_text: String = ""
	for e: Variant in loader.get_dialogue_sequence("ww2_memory_flashback"):
		memory_text += str((e as Dictionary).get("text", "")) + " "
	check(memory_text.contains("mühür") and memory_text.contains("Yemin") and memory_text.contains("kendi ellerinle"),
		"4. Anı Kırılması: ruhu kılıca kendi elleriyle hapsetme ve intikam yemini sahneleniyor")
	check(dialogues.has("ability_unlock_ww2") and str((dialogues["ability_unlock_ww2"] as Dictionary).get("id", "")) == "vengeance_vow_aura",
		"kılıç evrimi (ability_unlock_ww2) verisi var")


func _test_quests_codex_items() -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	var cm: Node = get_node_or_null("/root/CodexManager")
	for id: String in ["ww2_iron_heart", "ww2_wounded_in_trench", "ww2_silent_battery", "ww2_caged_subjects"]:
		check(qm != null and not qm.get_quest(id).is_empty(), "görev '%s' JSON'dan kaydedildi" % id)
	check(qm != null and (qm.get_quest("ww2_iron_heart").get("stages", []) as Array).size() == 5, "ana görevin 5 aşaması var")
	var codex_ids: Array[String] = ["trench_infantry", "flamethrower_trooper", "gas_sapper", "occult_remnant", "signal_scout",
		"trench_officer", "occult_doctor", "failed_experiment", "butcher_commander", "ww2_wounded_soldier", "ww2_prisoner",
		"ww2_future_blueprint", "ww2_broken_frequency", "ww2_knight_crest", "ww2_lore_iron_heart"]
	var codex_ok: bool = cm != null
	for id: String in codex_ids:
		var entry: Dictionary = cm.get_entry(id) if cm else {}
		var ok: bool = not entry.is_empty() and not str(entry.get("title_en", "")).is_empty() and ResourceLoader.exists(str(entry.get("icon_path", "")))
		if not ok:
			printerr("  Codex eksik: ", id)
		codex_ok = codex_ok and ok
	check(codex_ok, "%d Codex girişi (5 düşman, 3 mini-boss, boss, NPC'ler, 3 easter egg, lore) TR/EN + ikon" % codex_ids.size())
	var inv: GDScript = load("res://scripts/components/ww2_inventory.gd") as GDScript
	var defs: Array = inv.get_definitions()
	var items_ok: bool = defs.size() == 8
	for d: Variant in defs:
		var dd: Dictionary = d as Dictionary
		items_ok = items_ok and not str(dd.get("title_en", "")).is_empty() and not str(dd.get("description_en", "")).is_empty() \
			and ResourceLoader.exists(str(dd.get("icon_path", "")))
	check(items_ok, "8 eşya (sargı, adrenalin, filtre, el bombası, fişek, telsiz kodu, yetki kartı, künye) TR/EN + ikon")


func _test_translations() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/translations/translations.json")) as Dictionary
	var csv_text: String = FileAccess.get_file_as_string("res://data/translations/translations.csv")
	var re: RegEx = RegEx.create_from_string("\"((?:WW2|PROMPT_WW2|STAGE_WW2|CHAPTER_4|HUD_SEAL_VOW)[A-Z0-9_]*)\"")
	var needed: Array[String] = []
	var files: Array[String] = NEW_SCRIPTS.duplicate()
	for dir_path: String in NEW_SCRIPT_DIRS:
		for f: String in DirAccess.get_files_at(dir_path):
			if f.ends_with(".gd"):
				files.append(dir_path + "/" + f)
	for f: String in files:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(f)):
			if not needed.has(m.get_string(1)) and not m.get_string(1).ends_with("_"):
				needed.append(m.get_string(1))
	for i: int in range(1, 6):
		for part: String in ["TITLE", "SUB", "DESC"]:
			needed.append("WW2_TUT_%02d_%s" % [i, part])
		needed.append("STAGE_WW2_%d" % i)
	needed.append_array(["CHAPTER_4_TITLE", "CHAPTER_4_ERA", "HUD_SEAL_VOW"])
	var missing: Array[String] = []
	for key: String in needed:
		var e: Dictionary = data.get(key, {})
		if str(e.get("tr", "")).is_empty() or str(e.get("en", "")).is_empty() or not csv_text.contains("\n" + key + ","):
			missing.append(key)
	check(missing.is_empty(), "%d UI anahtarı JSON (TR+EN) ve CSV'de %s" % [needed.size(), str(missing)])
	var loc: Node = get_node_or_null("/root/LocalizationManager")
	if loc and loc.has_method("set_locale"):
		loc.set_locale("en")
		check(tr("WW2_BOSS_NAME") == "The Butcher Commander", "EN yerelleştirme çalışıyor")
		var en_seq: Array = (load("res://scripts/autoloads/story_data_loader.gd") as GDScript).get_dialogue_sequence("ww2_officer_intro")
		check(str((en_seq[0] as Dictionary).get("text")).begins_with("The Commander"), "EN diyalog metni seçiliyor")
		loc.set_locale("tr")
		check(tr("WW2_BOSS_NAME") == "Cani Komutan", "TR yerelleştirme çalışıyor")


func _test_audio() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	for key: String in ["ww2_theme", "ww2_ambience", "commander_phase_1", "commander_phase_2", "commander_phase_3",
			"artillery_whistle", "artillery_blast", "train_rail_loop", "train_car_clank", "radio_static", "flamethrower_burst",
			"gas_hiss", "relay_switch", "searchlight_alarm", "mine_click", "grenade_blast", "flare_ignite", "turret_fire",
			"sniper_shot", "shock_wave", "occult_beam", "mage_vengeance_whisper", "energy_tube_break"]:
		check(am != null and am.has_sound(key), "AudioManager '%s' sesini kaydetti" % key)
	if am:
		check(am.get_boss_phase_track_key("commander", 3) == "commander_phase_3", "Cani Komutan faz müziği çözümleniyor")


func _test_asset_pipeline() -> void:
	for name: String in CHARACTERS.keys():
		_check_character(name, "res://assets/characters/ww2/%s/%s" % [name, name], CHARACTERS[name])
	for form: int in [1, 2, 3]:
		_check_character("commander_form%d" % form, "res://assets/characters/ww2/commander/commander_form%d" % form, COMMANDER_ANIMS)
	_check_character("commander_aura", "res://assets/characters/ww2/commander/commander_aura", ["smoke", "occult", "core"])


## Sprite hattı standardı: RGBA sheet + .tres + manifest; FEET_Y kare tabanına hizalı; 10–16 FPS
func _check_character(label: String, base: String, anims: Array) -> void:
	var frames: SpriteFrames = load(base + "_frames.tres") as SpriteFrames
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + "_manifest.json"))
	var ok: bool = frames != null and manifest is Dictionary
	var total: int = 0
	if ok:
		var m: Dictionary = manifest as Dictionary
		var size: Array = m.get("frame_size", [0, 0])
		ok = int(m.get("feet_y", 0)) == int(size[1]) - 4 and str(m.get("background", "")) == "transparent_rgba"
		for a: Variant in anims:
			var an: StringName = StringName(str(a))
			ok = ok and frames.has_animation(an) and frames.get_frame_count(an) > 0
			if frames.has_animation(an):
				total += frames.get_frame_count(an)
				var fps: float = frames.get_animation_speed(an)
				ok = ok and fps >= 8.0 and fps <= 16.0
		var tex: Texture2D = frames.get_frame_texture(&"idle" if frames.has_animation(&"idle") else StringName(str(anims[0])), 0)
		ok = ok and tex != null and (tex.get_image() == null or tex.get_image().detect_alpha() != Image.ALPHA_NONE)
	check(ok and total >= 16, "asset hattı '%s': %d animasyon, %d kare, manifest + FEET_Y + RGBA" % [label, anims.size(), total])


func _test_chapter_flow_links() -> void:
	var select: GDScript = load("res://scripts/ui/chapter_select_dialog.gd") as GDScript
	var has_ch4: bool = false
	for ch: Dictionary in select.get_script_constant_map()["CHAPTERS"]:
		has_ch4 = has_ch4 or (int(ch["index"]) == 4 and str(ch["scene"]) == LEVELS[0] and ResourceLoader.exists(str(ch["scene"])))
	check(has_ch4, "bölüm seçiminde Bölüm 4 kartı ve geçerli sahne yolu")
	var gs: Node = get_node_or_null("/root/GameState")
	var sm: Node = get_node_or_null("/root/SaveManager")
	if gs and sm:
		gs.reset_state()
		gs.complete_chapter("chapter_3")
		check(sm.is_chapter_unlocked(4), "Bölüm 4, Bölüm 3 tamamlanınca açılıyor")
		check(sm.get_friendly_stage_name(LEVELS[3]) == tr("STAGE_WW2_4") and sm.get_friendly_stage_name(LEVELS[0]) == tr("STAGE_WW2_1"),
			"kayıt yuvası sahne adları yerelleştirilmiş")
		gs.reset_state()
	var egypt: PackedScene = load("res://scenes/levels/egypt/egypt_04_sun_throne.tscn") as PackedScene
	var state: SceneState = egypt.get_state()
	var linked: String = ""
	for i: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"next_chapter_scene":
			linked = str(state.get_node_property_value(0, i))
	check(linked == LEVELS[0], "Bölüm 3 taht odası zaman yırtığı Bölüm 4 Sahne 1'e bağlı")
	var host: Node = Node.new()
	add_child(host)
	var screen: CanvasLayer = (load("res://scripts/ui/results_screen.gd") as GDScript).show_for(host, linked)
	check(screen != null and screen.find_child("ContinueButton", true, false) != null, "Bölüm 3 sonuç ekranında 'Zaman Yırtığına Gir' düğmesi")
	host.queue_free()
	var parts: Array = []
	for path: String in LEVELS:
		var st: SceneState = (load(path) as PackedScene).get_state()
		for i: int in st.get_node_property_count(0):
			if st.get_node_property_name(0, i) == &"next_scene_path":
				parts.append(str(st.get_node_property_value(0, i)))
	check(parts.size() >= 4 and parts[0] == LEVELS[1] and parts[1] == LEVELS[2] and parts[2] == LEVELS[3] and parts[3] == LEVELS[4],
		"sahne zinciri 1 → 2 → 3 → 4 → 5 %s" % str(parts))


func _test_scenes_load() -> void:
	for path: String in LEVELS:
		var packed: PackedScene = load(path) as PackedScene
		check(packed != null, "sahne yüklendi: %s" % path.get_file())
		if packed == null:
			continue
		var level: Node = packed.instantiate()
		if "autosave_on_complete" in level:
			level.autosave_on_complete = false
		add_child(level)
		await get_tree().process_frame
		await get_tree().physics_frame
		var player: Node2D = level.get_node_or_null("CombatPlayer") as Node2D
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player else null
		check(player != null and level.get_node_or_null("FantasyHUD") != null and level.get_node_or_null("DialogueBox") != null,
			"%s: oyuncu, HUD ve diyalog kutusu" % path.get_file())
		check(cam != null and cam.limit_right == (level as Ww2LevelBase).camera_limits.end.x, "%s: kamera sınırları uygulandı" % path.get_file())
		check(level.get_node_or_null("DeathZone") != null and level.get_node_or_null("CampfireCheckpoint") != null,
			"%s: ölüm bölgesi ve kontrol noktası" % path.get_file())
		var layers: int = 0
		for n: String in ["WorldBackdrop", "MidLayer", "NearLayer", "AshParticles"]:
			if level.get_node_or_null(n):
				layers += 1
		var lights: int = level.find_children("*", "Ww2AlarmLight", true, false).size()
		check(layers >= (4 if path.contains("stage_1") or path.contains("stage_2") or path.contains("stage_3") else 2) and lights > 0,
			"%s: %d parallax/partikül katmanı, %d dinamik ışık" % [path.get_file(), layers, lights])
		var dlg: Node = level.get_node_or_null("DialogueBox")
		if dlg and dlg.has_method("skip_dialogue"):
			dlg.skip_dialogue()
		level.queue_free()
		await get_tree().process_frame
	var cm: Node = get_node_or_null("/root/CinematicManager")
	if cm and cm.has_method("force_reset"):
		cm.force_reset("test")


func _test_script_limits() -> void:
	var files: Array[String] = NEW_SCRIPTS.duplicate()
	for dir_path: String in NEW_SCRIPT_DIRS:
		for f: String in DirAccess.get_files_at(dir_path):
			if f.ends_with(".gd"):
				files.append(dir_path + "/" + f)
	var over: Array[String] = []
	var untyped: Array[String] = []
	var re_var: RegEx = RegEx.create_from_string("(?m)^\\s*var [a-z_0-9]+ = ")
	for f: String in files:
		var src: String = FileAccess.get_file_as_string(f)
		if src.split("\n").size() > 300:
			over.append("%s (%d)" % [f, src.split("\n").size()])
		if re_var.search(src) != null:
			untyped.append(f)
	check(over.is_empty(), "%d yeni script 300 satır sınırında %s" % [files.size(), str(over)])
	check(untyped.is_empty(), "yeni scriptlerde tipsiz 'var x = ' yok %s" % str(untyped))
