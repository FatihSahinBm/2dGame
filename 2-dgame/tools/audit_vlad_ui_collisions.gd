extends SceneTree

const STAGE2_PATH: String = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"
const STAGE3_PATH: String = "res://scenes/levels/vlad/stage_3_throne_room.tscn"
const OUT_DIR: String = "c:/Projects/2dgame/2-dgame/output/ui_audit"

var step: int = 0
var tick: int = 0

var stage2_inst: Stage2CastleDungeon = null
var stage3_inst: Stage3ThroneRoom = null

var audit_data: Dictionary = {}

func _init() -> void:
	print("==================================================================")
	print("--- GÖREV 18: VLAD HUD, DİYALOG & OYNANABİLİR ALAN ÇAKIŞMA DENETİMİ ---")
	print("==================================================================")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

func _process(_delta: float) -> bool:
	tick += 1
	
	match step:
		0:
			# ADIM 0: Stage 2 Kurulumu
			if tick == 1:
				var packed: PackedScene = load(STAGE2_PATH) as PackedScene
				stage2_inst = packed.instantiate() as Stage2CastleDungeon
				root.add_child(stage2_inst)
				
				# Fade overlay'leri temizle ki net görüntü alalım
				for c in stage2_inst.get_children():
					if c is CanvasLayer and c.layer >= 100:
						c.queue_free()
				
				var player = stage2_inst.player
				if player:
					player.global_position = Vector2(160, 520)
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
			
			if tick == 5:
				_audit_hud_nodes(stage2_inst.hud, "Stage2_NormalHUD")
				_save_screen("stage2_normal_gameplay.png")
				print("  [AUDIT] Stage 2 Normal HUD captured.")
				step = 1
				tick = 0

		1:
			# ADIM 1: Zincir Kolu [E] İstem Durumu
			if tick == 1:
				var player = stage2_inst.player
				var lever = stage2_inst.chain_lever
				if player and lever:
					player.global_position = Vector2(210, 520) # Tam kolun yanında
					lever._on_body_entered(player)
					_audit_interaction_prompt(lever, "EntranceMechanism/ChainLever")
			
			if tick == 5:
				_save_screen("stage2_chain_lever_prompt.png")
				print("  [AUDIT] Stage 2 Chain Lever prompt captured.")
				step = 2
				tick = 0

		2:
			# ADIM 2: Mangal [E] İstem Durumu
			if tick == 1:
				var player = stage2_inst.player
				var brazier = stage2_inst.get_node_or_null("PuzzleBraziers/Brazier1") as BloodAltarBrazier
				if player and brazier:
					player.global_position = Vector2(1520, 520) # Mangalın yanında
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam: cam.global_position = Vector2(1520, 480)
					brazier._on_body_entered(player)
					_audit_interaction_prompt(brazier, "PuzzleBraziers/Brazier1")
			
			if tick == 5:
				_save_screen("stage2_brazier_prompt.png")
				print("  [AUDIT] Stage 2 Brazier prompt captured.")
				step = 3
				tick = 0

		3:
			# ADIM 3: Kadim Kalp Kabartması Diyaloğu
			if tick == 1:
				var player = stage2_inst.player
				var mural = stage2_inst.bone_mural_area as AncientHeartRelief
				if player and mural:
					player.global_position = Vector2(1450, 480)
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam: cam.global_position = Vector2(1450, 480)
					mural._player_ref = player
					mural._player_nearby = true
					mural.examine_relief()
					_audit_dialogue_nodes(stage2_inst.dialogue_box, "AncientHeartRelief_Dialogue")
			
			if tick == 10:
				_save_screen("stage2_heart_relief_dialogue.png")
				print("  [AUDIT] Stage 2 Heart Relief dialogue captured.")
				
				# Stage 2'yi temizle
				stage2_inst.queue_free()
				stage2_inst = null
				step = 4
				tick = 0

		4:
			# ADIM 4: Stage 3 Taht Odası Kurulumu (Normal Boss Karşılaşması)
			if tick == 1:
				var packed: PackedScene = load(STAGE3_PATH) as PackedScene
				stage3_inst = packed.instantiate() as Stage3ThroneRoom
				root.add_child(stage3_inst)
				
				for c in stage3_inst.get_children():
					if c is CanvasLayer and c.layer >= 100:
						c.queue_free()
				
				# Giriş diyaloğunu kapatıp normal savaşı başlat
				if stage3_inst.dialogue_box:
					stage3_inst.dialogue_box.panel.visible = false
					stage3_inst.dialogue_box.set_letterbox(false)
				
				var boss = stage3_inst.vlad_boss
				var player = stage3_inst.player
				if boss:
					boss.is_active = true
					boss._is_in_cinematic = false
					boss.global_position = Vector2(400, 560)
					boss.direction = 1
					boss._update_facing_direction()
				if player:
					player.global_position = Vector2(700, 560)
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
						cam.global_position = Vector2(550, 480)
				
				# Mızrak telgrafını başlatarak görsel etkisini incele
				if boss:
					boss._execute_normal_spear_throw()
				
				_audit_boss_health_bar(boss, "VladBoss_OverheadBar")
			
			if tick == 15:
				_save_screen("stage3_boss_normal_combat.png")
				print("  [AUDIT] Stage 3 Normal Boss Combat captured.")
				step = 5
				tick = 0

		5:
			# ADIM 5: Boss Form Taunt / Değişim Diyaloğu Açıkken
			if tick == 1:
				var boss = stage3_inst.vlad_boss
				if boss:
					boss._clear_spear_throw_telegraph()
					# 1. Fazdan 2. Faza geçiş tauntunu tetikle
					stage3_inst._play_form_taunt("vlad_taunt_vampire")
					_audit_dialogue_nodes(stage3_inst.dialogue_box, "Vlad_Vampire_FormTaunt_Dialogue")
			
			if tick == 10:
				_save_screen("stage3_boss_form_taunt_dialogue.png")
				print("  [AUDIT] Stage 3 Boss Form Taunt Dialogue captured.")
				step = 6
				tick = 0

		6:
			# ADIM 6: Ekran & Aspect Ratio Analizi
			_run_aspect_ratio_and_resolution_audit()
			print("==================================================================")
			print("--- ALL UI AUDIT CAPTURES & CHECKS COMPLETED SUCCESSFULLY ---")
			print("==================================================================")
			quit(0)
			return true

	return false

func _save_screen(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var full_path: String = "%s/%s" % [OUT_DIR, filename]
	img.save_png(full_path)
	print("Saved UI Audit Screenshot: ", full_path)

func _audit_hud_nodes(hud: CanvasLayer, label: String) -> void:
	if not hud: return
	print("\n--- AUDITING HUD NODES [%s] ---" % label)
	print("  CanvasLayer Layer: ", hud.layer)
	var tl = hud.get_node_or_null("TopLeft") as Control
	var tr = hud.get_node_or_null("TopRight") as Control
	var bl = hud.get_node_or_null("BottomLeft") as Control
	var br = hud.get_node_or_null("BottomRight") as Control
	
	if tl: print("  TopLeft: rect=%s, anchor_preset=%d" % [tl.get_global_rect(), tl.anchors_preset])
	if tr: print("  TopRight: rect=%s, anchor_preset=%d" % [tr.get_global_rect(), tr.anchors_preset])
	if bl: print("  BottomLeft: rect=%s, anchor_preset=%d" % [bl.get_global_rect(), bl.anchors_preset])
	if br: print("  BottomRight: rect=%s, anchor_preset=%d" % [br.get_global_rect(), br.anchors_preset])

func _audit_interaction_prompt(obj: Node2D, obj_path: String) -> void:
	if not obj: return
	print("\n--- AUDITING INTERACTION PROMPT [%s] ---" % obj_path)
	var prompt = obj.get_node_or_null("PromptLabel") as Label
	if prompt:
		print("  Prompt text: '%s'" % prompt.text)
		print("  Prompt local offset: pos=%s, size=%s" % [prompt.position, prompt.size])
		print("  Prompt global_position: %s" % prompt.global_position)
		print("  Parent world position: %s" % obj.global_position)

func _audit_dialogue_nodes(dialogue: CanvasLayer, label: String) -> void:
	if not dialogue: return
	print("\n--- AUDITING DIALOGUE BOX [%s] ---" % label)
	print("  CanvasLayer Layer: ", dialogue.layer)
	var panel = dialogue.get_node_or_null("Panel") as Control
	var top_box = dialogue.get_node_or_null("LetterboxTop") as Control
	var btm_box = dialogue.get_node_or_null("LetterboxBottom") as Control
	if panel:
		print("  Panel: global_rect=%s, size=%s, visible=%s" % [panel.get_global_rect(), panel.size, panel.visible])
	if top_box:
		print("  LetterboxTop: offset_bottom=%s, visible=%s" % [top_box.offset_bottom, top_box.visible])
	if btm_box:
		print("  LetterboxBottom: offset_top=%s, visible=%s" % [btm_box.offset_top, btm_box.visible])

func _audit_boss_health_bar(boss: CharacterBody2D, label: String) -> void:
	if not boss: return
	print("\n--- AUDITING BOSS HEALTH BAR [%s] ---" % label)
	var hp_ui = boss.get_node_or_null("UI/HealthBar") as ProgressBar
	if hp_ui:
		print("  Boss HealthBar offset: pos=%s, size=%s" % [hp_ui.position, hp_ui.size])
		print("  Boss HealthBar global_position: %s" % hp_ui.global_position)
		print("  Boss global_position: %s (Head estimated at Y=%f)" % [boss.global_position, boss.global_position.y - 70.0])

func _run_aspect_ratio_and_resolution_audit() -> void:
	print("\n--- AUDITING ASPECT RATIO & RESOLUTION SCALING ---")
	var vp_size = root.get_viewport().get_visible_rect().size
	print("  Active Viewport Size: %s (Aspect: %.3f)" % [vp_size, vp_size.x / vp_size.y])
	var win_w = ProjectSettings.get_setting("display/window/size/viewport_width")
	var win_h = ProjectSettings.get_setting("display/window/size/viewport_height")
	var stretch_mode = ProjectSettings.get_setting("display/window/stretch/mode")
	var stretch_aspect = ProjectSettings.get_setting("display/window/stretch/aspect")
	var stretch_scale = ProjectSettings.get_setting("display/window/stretch/scale")
	print("  Project settings: %dx%d, mode='%s', aspect='%s', scale=%s" % [win_w, win_h, stretch_mode, stretch_aspect, str(stretch_scale)])
