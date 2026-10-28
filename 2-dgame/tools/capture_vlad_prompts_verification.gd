extends SceneTree

# res://tools/capture_vlad_prompts_verification.gd
# Görev 18.1: Mahzen Etkileşim İstemleri (Chain Lever & 3 Braziers) Konum ve Okunabilirlik Doğrulama Aracı

const STAGE2_PATH = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"
const OUT_DIR = "res://output/ui_audit"

var stage_inst: Stage2CastleDungeon = null
var step: int = 0
var tick: int = 0

func _init() -> void:
	print("==================================================================")
	print("--- GÖREV 18.1: ETKİLEŞİM İSTEMLERİ GÖRSEL DOĞRULAMA TESTİ ---")
	print("==================================================================")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

func _process(_delta: float) -> bool:
	tick += 1
	
	match step:
		0:
			# ADIM 0: Sahneyi yükle ve hazırla
			if tick == 1:
				var packed: PackedScene = load(STAGE2_PATH) as PackedScene
				stage_inst = packed.instantiate() as Stage2CastleDungeon
				root.add_child(stage_inst)
				
				# Fade overlay'leri kaldır (net render için)
				for c in stage_inst.get_children():
					if c is CanvasLayer and c.layer >= 100:
						c.queue_free()
				
				# Kamera ayarlarını sabitle
				var player = stage_inst.player
				if player:
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam:
						cam.position_smoothing_enabled = false
				
				print("[ADIM 0] Mahzen sahnesi yüklendi.")
				step = 1
				tick = 0
				
		1:
			# ADIM 1: Zincir Kolu İstem Konumu Doğrulama
			if tick == 1:
				_hide_all_prompts()
				var player = stage_inst.player
				var lever = stage_inst.chain_lever
				if player and lever:
					player.global_position = Vector2(210, 520)
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam: cam.global_position = Vector2(260, 480)
					lever.prompt.visible = true
					_audit_prompt(lever, "ChainLever")
			
			if tick == 5:
				_save_screen("stage2_chain_lever_prompt_fixed.png")
				print("  [KONTROL 1] Zincir Kolu güncel istemi kaydedildi: stage2_chain_lever_prompt_fixed.png")
				step = 2
				tick = 0
				
		2:
			# ADIM 2: 1. Mangal İstem Konumu & Düşman Can Göstergesi Doğrulama
			if tick == 1:
				_hide_all_prompts()
				var player = stage_inst.player
				var b1 = stage_inst.get_node_or_null("PuzzleBraziers/Brazier1") as BloodAltarBrazier
				if player and b1:
					player.global_position = Vector2(1520, 520)
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam: cam.global_position = Vector2(1520, 480)
					b1.prompt.visible = true
					_audit_prompt(b1, "PuzzleBraziers/Brazier1")
					
					var skel = stage_inst.get_node_or_null("Enemies/CorridorSkeleton")
					if skel:
						print("  İskelet Düşman Global Pozisyon: %s" % skel.global_position)
			
			if tick == 5:
				_save_screen("stage2_brazier1_prompt_fixed.png")
				print("  [KONTROL 2] 1. Mangal güncel istemi kaydedildi: stage2_brazier1_prompt_fixed.png")
				step = 3
				tick = 0
				
		3:
			# ADIM 3: 2. Mangal İstem Konumu Doğrulama
			if tick == 1:
				_hide_all_prompts()
				var player = stage_inst.player
				var b2 = stage_inst.get_node_or_null("PuzzleBraziers/Brazier2") as BloodAltarBrazier
				if player and b2:
					player.global_position = Vector2(1780, 520)
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam: cam.global_position = Vector2(1780, 480)
					b2.prompt.visible = true
					_audit_prompt(b2, "PuzzleBraziers/Brazier2")
			
			if tick == 5:
				_save_screen("stage2_brazier2_prompt_fixed.png")
				print("  [KONTROL 3] 2. Mangal güncel istemi kaydedildi: stage2_brazier2_prompt_fixed.png")
				step = 4
				tick = 0
				
		4:
			# ADIM 4: 3. Mangal İstem Konumu Doğrulama
			if tick == 1:
				_hide_all_prompts()
				var player = stage_inst.player
				var b3 = stage_inst.get_node_or_null("PuzzleBraziers/Brazier3") as BloodAltarBrazier
				if player and b3:
					player.global_position = Vector2(2040, 520)
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					if cam: cam.global_position = Vector2(2040, 480)
					b3.prompt.visible = true
					_audit_prompt(b3, "PuzzleBraziers/Brazier3")
			
			if tick == 5:
				_save_screen("stage2_brazier3_prompt_fixed.png")
				print("  [KONTROL 4] 3. Mangal güncel istemi kaydedildi: stage2_brazier3_prompt_fixed.png")
				step = 5
				tick = 0
				
		5:
			# ADIM 5: Kamera Hareketi / Kayma Testi (Y-Kayması altında istem yerleşimi)
			if tick == 1:
				var player = stage_inst.player
				var b1 = stage_inst.get_node_or_null("PuzzleBraziers/Brazier1") as BloodAltarBrazier
				if player and b1:
					var cam = player.get_node_or_null("Camera2D") as Camera2D
					# Kamerayı biraz yukarı ve sağa kaydır
					if cam: cam.global_position = Vector2(1550, 450)
			
			if tick == 5:
				_save_screen("stage2_brazier_camera_offset_fixed.png")
				print("  [KONTROL 5] Kamera kayması altında istem kaydedildi: stage2_brazier_camera_offset_fixed.png")
				print("==================================================================")
				print("--- TÜM GÖRSEL DOĞRULAMA ÇEKİMLERİ TAMAMLANDI ---")
				print("==================================================================")
				quit(0)
				return true

	return false

func _save_screen(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var full_path: String = "%s/%s" % [OUT_DIR, filename]
	img.save_png(full_path)
	print("  Görüntü kaydedildi: ", full_path)

func _audit_prompt(obj: Node2D, label: String) -> void:
	var prompt = obj.get_node_or_null("PromptLabel") as Label
	if prompt:
		var global_top_left = obj.global_position + prompt.position
		var global_rect = Rect2(global_top_left, prompt.size)
		print("\n--- DENETİM: %s ---" % label)
		print("  Prompt Metni: '%s'" % prompt.text)
		print("  Parent Global Pozisyon: %s" % obj.global_position)
		print("  Prompt Yerel Offset: %s (Boyut: %s, MinBoyut: %s)" % [prompt.position, prompt.size, prompt.get_minimum_size()])
		print("  Prompt Global Rect: %s (Y aralığı: %.1f - %.1f)" % [global_rect, global_rect.position.y, global_rect.position.y + global_rect.size.y])

func _hide_all_prompts() -> void:
	if not stage_inst: return
	if stage_inst.chain_lever and stage_inst.chain_lever.prompt:
		stage_inst.chain_lever.prompt.visible = false
	for i in range(1, 4):
		var b = stage_inst.get_node_or_null("PuzzleBraziers/Brazier%d" % i) as BloodAltarBrazier
		if b and b.prompt:
			b.prompt.visible = false
