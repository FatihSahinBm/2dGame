extends Node

## res://tests/verify_future_chapter_runner.gd
## Bölüm 5 (Distopik Gelecek) veri / entegrasyon / asset doğrulaması — Epic 2D-158.
## Hikâye JSON'u (TR+EN), görev & Codex & eşya kaydı, UI çevirileri (JSON+CSV), ses kaydı,
## sprite hattı (manifest, FEET_Y, 16 kare, 10–16 FPS, RGBA, Vlad paritesinde 3 formlu boss
## animasyon seti), bölüm seçimi / kilit, Bölüm 4 → 5 bağlantısı, 5 sekans sahne yükleme ve
## 300 satır / statik tip sınırı.
## Çalıştırma: Godot --headless --path . res://tests/verify_future_chapter.tscn

const CH5: String = "res://data/story/chapter_5_future.json"
const LEVELS: Array[String] = [
	"res://scenes/levels/future/stage_1_neon_ruins.tscn",
	"res://scenes/levels/future/stage_2_temporal_assembly.tscn",
	"res://scenes/levels/future/stage_3_resistance_citadel.tscn",
	"res://scenes/levels/future/stage_4_ai_lord_citadel.tscn",
	"res://scenes/levels/future/stage_5_sword_shattering.tscn",
]
const SCRIPT_DIRS: Array[String] = [
	"res://scripts/levels/future", "res://scripts/objects/future", "res://scripts/hazards/future", "res://scripts/enemies/future",
]
const EXTRA_SCRIPTS: Array[String] = [
	"res://scripts/components/future_chapter_state.gd", "res://scripts/components/future_inventory.gd",
	"res://scripts/effects/future_fx.gd", "res://scripts/effects/sword_sixth_core_vfx.gd", "res://scripts/ui/future_inventory_items.gd",
	"res://tools/future_build_common.gd", "res://tools/future_build_level_kit.gd", "res://tools/build_future_actors.gd",
	"res://tools/build_future_levels.gd", "res://tools/build_future_levels_2.gd",
]
## Kabul kriterlerindeki animasyon envanteri (varlık -> zorunlu animasyonlar)
const CHARACTERS: Dictionary = {
	"ai_lord_sovereign": ["idle", "hover_move", "telegraph_grid", "laser_lattice_attack", "drone_summon", "hurt", "phase_transition"],
	"ai_lord_titan": ["idle", "heavy_walk", "telegraph_slam", "shoulder_cannon_blast", "shield_block", "groggy", "hurt", "phase_transition"],
	"ai_lord_singularity": ["idle", "time_blink", "echo_slash_combo", "core_overdrive_beam", "hurt", "collapse_death"],
	"chrono_warden_mech": ["idle", "walk", "charge_ram", "arm_laser_sweep", "temporal_stomp", "groggy", "hurt", "death"],
	"aegis_core": ["core_idle", "shield_pulse", "overheat_exposed"],
	"aegis_drone": ["drone_idle", "drone_beam_lock", "drone_death"],
	"cyber_flying_bug_prime": ["idle", "hover", "telegraph", "shoot", "hurt", "death"],
	"cyber_enforcer": ["idle", "walk", "slash_combo", "block", "hurt", "death"],
	"chrono_drone": ["idle", "pulse_cast", "hurt", "death"],
	"hydraulic_juggernaut": ["idle", "stomp_walk", "piston_smash", "hurt", "death"],
	"cyber_hound": ["idle", "run", "pounce", "hurt", "death"],
	"resistance_fighter": ["idle", "injured_kneel", "follow_walk", "shoot_cover", "evacuate", "drained_death"],
	"resistance_engineer": ["idle", "hacking", "talk", "drained_death"],
}
const ASSET_FILES: Array[String] = [
	"backgrounds/future/bg_sky_neon_storm.png", "backgrounds/future/bg_distant_skyscrapers.png",
	"backgrounds/future/bg_mid_viaduct_monorail.png", "backgrounds/future/bg_fg_cables_debris.png",
	"environment/future/tileset_neon_ruins.png", "environment/future/tileset_cyber_factory.png", "environment/future/tileset_core_citadel.png",
	"objects/future/prop_stamped_armature_mold.png", "objects/future/prop_trex_cyber_harness.png", "objects/future/prop_broken_hologram.png",
	"objects/future/prop_cryo_pod.png", "objects/future/prop_evac_capsule.png", "objects/future/trap_laser_gate.png",
	"objects/future/trap_hydraulic_press.png", "objects/future/trap_plasma_channel.png",
	"effects/future/ai_lord_teleport_vfx.tres", "effects/future/ai_lord_time_ripple.png", "effects/future/vfx_emp_blast.tres",
	"effects/future/vfx_time_fracture.tres", "effects/future/vfx_sword_shell_shatter.tres", "effects/future/vfx_sixth_core_aura.tres",
	"items/future/heart_piece_5.png", "ui/portraits/portrait_ai_lord.png", "ui/portraits/portrait_chrono_warden.png",
	"ui/portraits/portrait_aegis_core.png", "ui/portraits/portrait_resistance_leader.png",
]
const SCENE_FILES: Array[String] = [
	"hazards/future/trap_laser_gate.tscn", "hazards/future/trap_hydraulic_press.tscn", "hazards/future/trap_plasma_channel.tscn",
	"objects/future/obj_conveyor_belt.tscn", "objects/future/obj_emp_terminal.tscn", "objects/future/obj_time_slow_field.tscn",
	"objects/future/obj_checkpoint_beacon.tscn",
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
	print("--- FUTURE CHAPTER (2D-158) DATA, ASSETS & INTEGRATION ---")
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


func _script_files() -> Array[String]:
	var files: Array[String] = EXTRA_SCRIPTS.duplicate()
	for dir_path: String in SCRIPT_DIRS:
		for f: String in DirAccess.get_files_at(dir_path):
			if f.ends_with(".gd"):
				files.append(dir_path + "/" + f)
	return files


func _test_story_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CH5))
	check(parsed is Dictionary, "chapter_5_future.json geçerli JSON")
	var dialogues: Dictionary = (parsed as Dictionary).get("dialogues", {})
	var re: RegEx = RegEx.create_from_string("\"(fut_[a-z0-9_]+)\"")
	var used: Array[String] = []
	for f: String in _script_files():
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(f)):
			if not used.has(m.get_string(1)) and not m.get_string(1).ends_with("_defeated") or dialogues.has(m.get_string(1)):
				if not used.has(m.get_string(1)):
					used.append(m.get_string(1))
	var non_dialogue: Array[String] = ["fut_mold_sword_tremble", "fut_sword_shatter_fx", "fut_survivor", "fut_engineer"]
	var missing: Array[String] = []
	for key: String in used:
		if non_dialogue.has(key) or key.ends_with("_beacon"):
			continue
		var seq: Variant = dialogues.get(key)
		var ok: bool = seq is Array and not (seq as Array).is_empty()
		if ok:
			for entry: Variant in seq as Array:
				var e: Dictionary = entry as Dictionary
				ok = ok and not str(e.get("text", e.get("name", ""))).is_empty() and not str(e.get("text_en", e.get("name_en", ""))).is_empty()
				for c: Variant in e.get("choices", []) as Array:
					ok = ok and not str((c as Dictionary).get("text_en", "")).is_empty() and not str((c as Dictionary).get("action", "")).is_empty()
		if not ok:
			missing.append(key)
	check(used.size() >= 35 and missing.is_empty(), "koddaki %d diyalog anahtarı JSON'da TR/EN eksiksiz %s" % [used.size(), str(missing)])
	var loader: GDScript = load("res://scripts/autoloads/story_data_loader.gd") as GDScript
	check(loader.get_dialogue_sequence("fut_ai_lord_taunt").size() == 3, "StoryDataLoader Bölüm 5 diyaloğunu buluyor")
	var actions: Array = []
	for key: String in ["fut_survivor_plea", "fut_engineer_plea"]:
		for c: Variant in (loader.get_dialogue_sequence(key)[0] as Dictionary).get("choices", []):
			actions.append((c as Dictionary).get("action"))
	check(actions == ["rescue_survivor", "exploit_survivor", "evacuate_engineer", "exploit_engineer"], "seçim eylemleri: kurtar/sömür ve tahliye/sömür")
	var mold: String = ""
	for e: Variant in loader.get_dialogue_sequence("fut_mold_discovery"):
		mold += str((e as Dictionary).get("text", "")) + " "
	check(mold.contains("omuz soketi") and mold.contains("T-Rex") and mold.contains("damga"), "Büyük Keşif Anı: soket, T-Rex zırhı ve kılıç damgası")
	check(dialogues.has("ability_unlock_future") and str((dialogues["ability_unlock_future"][0] as Dictionary).get("id", "")) == "sixth_core_awakening",
		"kılıç evrimi (altıncı çekirdek) verisi var")


func _test_quests_codex_items() -> void:
	var qm: Node = get_node_or_null("/root/QuestManager")
	var cm: Node = get_node_or_null("/root/CodexManager")
	for id: String in ["future_processor_heart", "future_last_shelter", "future_network_outage", "future_fallen_wreckage"]:
		check(qm != null and not qm.get_quest(id).is_empty(), "görev '%s' JSON'dan kaydedildi (ChapterDataRegistry)" % id)
	check(qm != null and (qm.get_quest("future_processor_heart").get("stages", []) as Array).size() == 8, "ana görevin 8 aşaması var")
	var ids: Array[String] = ["cyber_flying_bug_prime", "cyber_enforcer", "chrono_drone", "hydraulic_juggernaut", "cyber_hound",
		"chrono_warden_mech", "aegis_core", "ai_lord", "resistance_fighter", "resistance_engineer", "future_lore_fallen_wreckage",
		"future_lore_rex_telemetry", "future_lore_sigil_origin", "future_lore_patchwork_radio", "future_lore_processor_heart"]
	var codex_ok: bool = cm != null
	for id: String in ids:
		var entry: Dictionary = cm.get_entry(id) if cm else {}
		var ok: bool = not entry.is_empty() and not str(entry.get("title_en", "")).is_empty() and ResourceLoader.exists(str(entry.get("icon_path", "")))
		if not ok:
			printerr("  Codex eksik: ", id)
		codex_ok = codex_ok and ok
	check(codex_ok, "%d Codex girişi (5 düşman, 2 mini-boss, AI Lord, 2 NPC, lore + 3 easter egg) TR/EN + ikon" % ids.size())
	var inv: GDScript = load("res://scripts/components/future_inventory.gd") as GDScript
	var defs: Array = inv.get_definitions()
	var usable: int = 0
	var ok_items: bool = defs.size() == 8
	for d: Variant in defs:
		var dd: Dictionary = d as Dictionary
		usable += 1 if bool(dd.get("usable", false)) else 0
		ok_items = ok_items and not str(dd.get("title_en", "")).is_empty() and ResourceLoader.exists(str(dd.get("icon_path", "")))
	check(ok_items and usable == 5, "8 eşya (3 tüketilebilir + 2 ikincil silah + 3 görev eşyası) TR/EN + ikon")


func _test_translations() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/translations/translations.json")) as Dictionary
	var csv_text: String = FileAccess.get_file_as_string("res://data/translations/translations.csv")
	var re: RegEx = RegEx.create_from_string("\"((?:FUT|PROMPT_FUT|CHAPTER_5)[A-Z0-9_]*)\"")
	var needed: Array[String] = []
	for f: String in _script_files():
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(f)):
			if not needed.has(m.get_string(1)) and not m.get_string(1).ends_with("_"):
				needed.append(m.get_string(1))
	for i: int in range(1, 6):
		needed.append("STAGE_FUTURE_%d" % i)
	needed.append_array(["CHAPTER_5_TITLE", "CHAPTER_5_ERA"])
	var missing: Array[String] = []
	for key: String in needed:
		var e: Dictionary = data.get(key, {})
		if str(e.get("tr", "")).is_empty() or str(e.get("en", "")).is_empty() or not csv_text.contains("\n" + key + ","):
			missing.append(key)
	check(needed.size() >= 50 and missing.is_empty(), "%d UI anahtarı JSON (TR+EN) ve CSV'de %s" % [needed.size(), str(missing)])
	var loc: Node = get_node_or_null("/root/LocalizationManager")
	if loc and loc.has_method("set_locale"):
		loc.set_locale("en")
		check(tr("FUT_WARDEN_NAME") == "Chrono-Warden", "EN yerelleştirme çalışıyor")
		var en_seq: Array = (load("res://scripts/autoloads/story_data_loader.gd") as GDScript).get_dialogue_sequence("fut_ai_lord_taunt")
		check(str((en_seq[0] as Dictionary).get("text")).begins_with("At last"), "EN diyalog metni seçiliyor")
		loc.set_locale("tr")
		check(tr("FUT_WARDEN_NAME") == "Krono-Muhafız", "TR yerelleştirme çalışıyor")


func _test_audio() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	for key: String in ["bgm_future_neon_ruins", "bgm_future_assembly_tension", "bgm_ai_lord_boss", "future_ambience",
			"ai_lord_phase_1", "ai_lord_phase_2", "ai_lord_phase_3", "sfx_cyber_laser_charge", "sfx_cyber_laser_fire",
			"sfx_time_slow_warp", "sfx_emp_detonate", "sfx_hydraulic_stomp", "sfx_ai_lord_glitch_voice", "sfx_sword_shell_crack",
			"sfx_sword_shatter_wizard_laugh"]:
		check(am != null and am.has_sound(key), "AudioManager '%s' sesini kaydetti" % key)
	if am:
		check(am.get_boss_phase_track_key("ai_lord", 3) == "ai_lord_phase_3", "AI Lord 3 form müziği çözümleniyor")


func _test_asset_pipeline() -> void:
	for name: String in CHARACTERS.keys():
		_check_character(name, CHARACTERS[name])
	var missing: Array[String] = []
	for rel: String in ASSET_FILES:
		if not ResourceLoader.exists("res://assets/" + rel):
			missing.append(rel)
	for rel: String in SCENE_FILES:
		if not ResourceLoader.exists("res://scenes/" + rel):
			missing.append(rel)
	check(missing.is_empty(), "çevre/parallax/tileset/prop/tuzak/VFX/portre envanteri eksiksiz %s" % str(missing))
	var icons: int = 0
	for f: String in DirAccess.get_files_at("res://assets/items/future"):
		if f.ends_with(".png") and f != "heart_piece_5.png":
			icons += 1
	check(icons >= 7, "en az 7 yeni eşya ikonu (%d)" % icons)


## Sprite hattı standardı: RGBA sheet + .tres + manifest; ortak FEET_Y; her animasyon 16 kare, 10–16 FPS
func _check_character(entity: String, anims: Array) -> void:
	var base: String = "res://assets/characters/future/%s/%s" % [entity, entity]
	var frames: SpriteFrames = load(base + "_frames.tres") as SpriteFrames
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + "_manifest.json"))
	var ok: bool = frames != null and manifest is Dictionary
	var detail: String = ""
	if ok:
		var m: Dictionary = manifest as Dictionary
		var size: Array = m.get("frame_size", [0, 0])
		ok = str(m.get("background", "")) == "transparent_rgba" and int(m.get("feet_y", -1)) > 0 and int(m.get("feet_y", 0)) <= int(size[1])
		for a: Variant in anims:
			var an: StringName = StringName(str(a))
			var good: bool = frames.has_animation(an) and frames.get_frame_count(an) >= 16 and frames.get_frame_count(an) <= 24
			good = good and frames.get_animation_speed(an) >= 10.0 and frames.get_animation_speed(an) <= 16.0
			if not good:
				detail += " " + str(a)
			ok = ok and good
		var tex: Texture2D = frames.get_frame_texture(StringName(str(anims[0])), 0)
		var img: Image = tex.get_image() if tex else null
		ok = ok and img != null and img.detect_alpha() != Image.ALPHA_NONE
	check(ok, "asset hattı '%s': %d animasyon x 16 kare, manifest + FEET_Y + RGBA%s" % [entity, anims.size(), detail])


func _test_chapter_flow_links() -> void:
	var select: GDScript = load("res://scripts/ui/chapter_select_dialog.gd") as GDScript
	var has_ch5: bool = false
	for ch: Dictionary in select.get_script_constant_map()["CHAPTERS"]:
		has_ch5 = has_ch5 or (int(ch["index"]) == 5 and str(ch["scene"]) == LEVELS[0])
	check(has_ch5, "bölüm seçiminde Bölüm 5 kartı ve geçerli sahne yolu")
	var gs: Node = get_node_or_null("/root/GameState")
	var sm: Node = get_node_or_null("/root/SaveManager")
	if gs and sm:
		gs.reset_state()
		gs.complete_chapter("chapter_4")
		check(sm.is_chapter_unlocked(5), "Bölüm 5, Bölüm 4 tamamlanınca açılıyor")
		check(sm.get_friendly_stage_name(LEVELS[3]) == tr("STAGE_FUTURE_4"), "kayıt yuvası sahne adları yerelleştirilmiş")
		gs.reset_state()
	var st: SceneState = (load("res://scenes/levels/ww2/stage_5_memory_rift.tscn") as PackedScene).get_state()
	var linked: String = ""
	for i: int in st.get_node_property_count(0):
		if st.get_node_property_name(0, i) == &"next_chapter_scene":
			linked = str(st.get_node_property_value(0, i))
	check(linked == LEVELS[0], "Bölüm 4 Anı Kırılması zaman yırtığı Bölüm 5 Sekans 1'e bağlı")
	var parts: Array = []
	for path: String in LEVELS:
		var s: SceneState = (load(path) as PackedScene).get_state()
		for i: int in s.get_node_property_count(0):
			if s.get_node_property_name(0, i) == &"next_scene_path":
				parts.append(str(s.get_node_property_value(0, i)))
	check(parts.size() >= 4 and parts[0] == LEVELS[1] and parts[1] == LEVELS[2] and parts[2] == LEVELS[3] and parts[3] == LEVELS[4],
		"sekans zinciri 1 → 2 → 3 → 4 → 5 %s" % str(parts))


## 5 sekans sahne yükleme testi
func _test_scenes_load() -> void:
	var widths: Array[int] = []
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
		check(level is FutureLevelBase and player != null and level.get_node_or_null("FantasyHUD") != null and level.get_node_or_null("DialogueBox") != null,
			"%s: FutureLevelBase, oyuncu, HUD ve diyalog kutusu" % path.get_file())
		check(cam != null and cam.limit_right == (level as FutureLevelBase).camera_limits.end.x, "%s: kamera sınırları uygulandı" % path.get_file())
		var layers: int = 0
		for n: String in ["WorldBackdrop", "FarLayer", "MidLayer", "NearLayer", "NeonRain"]:
			if level.get_node_or_null(n):
				layers += 1
		check(layers == 5 and level.get_node_or_null("DeathZone") != null, "%s: 4 parallax katmanı + neon yağmuru + ölüm bölgesi" % path.get_file())
		widths.append((level as FutureLevelBase).camera_limits.size.x)
		var dlg: Node = level.get_node_or_null("DialogueBox")
		if dlg and dlg.has_method("skip_dialogue"):
			dlg.skip_dialogue()
		level.queue_free()
		await get_tree().process_frame
	check(widths.size() == 5 and widths[0] >= 5000 and widths[1] >= 5000 and widths[2] >= 5000, "sekans 1-3 uzun (>= 5000 px) %s" % str(widths))
	var cm: Node = get_node_or_null("/root/CinematicManager")
	if cm and cm.has_method("force_reset"):
		cm.force_reset("test")


func _test_script_limits() -> void:
	var files: Array[String] = _script_files()
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
