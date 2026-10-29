class_name Stage3ThroneRoom
extends Node2D

## res://scripts/levels/vlad/stage_3_throne_room.gd
## 3. Sahne: Vlad Boss Karşılaşması (4 Form, 4 Ayrı Savaş Alanı)
## 1. Taht Salonu: İnsan Voyvoda (Spear thrust, impale, melee combo)
## 2. Kan Salonu: Vampir Lord (Kan kalkanı, kan sisi atılması, 2 mühür)
## 3. Yıkılan Surlar: Kurt Adam (Pençe kombosu, zayıf kemer düzeneği)
## 4. Çan Kulesi: Dev Yarasa (Hava dalışı, akustik Ulu Çan mekaniği, Kalp Parçası)

@onready var player: CharacterBody2D = $CombatPlayer
@onready var vlad_boss: CharacterBody2D = $VladBoss
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var flashback_overlay: CanvasLayer = $FlashbackOverlay
@onready var heart_piece: Node2D = $HeartPieceVisual
@onready var world_backdrop: WorldParallaxBackground = get_node_or_null("WorldBackdrop") as WorldParallaxBackground

const StoryDataLoader = preload("res://scripts/autoloads/story_data_loader.gd")

const TEX_ARENA_1 = preload("res://assets/backgrounds/stage_3_arena_1_throne.png")
const TEX_ARENA_2 = preload("res://assets/backgrounds/stage_3_arena_2_balcony.png")
const TEX_ARENA_3 = preload("res://assets/backgrounds/stage_3_arena_3_ramparts.png")
const TEX_ARENA_4 = preload("res://assets/backgrounds/stage_3_arena_4_belltower.png")

# Arenalar ve Bariyerler
@onready var barrier_1: StaticBody2D = get_node_or_null("Environment/Arena1_ThroneRoom/Barrier1")
@onready var barrier_2: StaticBody2D = get_node_or_null("Environment/Arena2_BloodHall/Barrier2")
@onready var barrier_3: StaticBody2D = get_node_or_null("Environment/Arena3_Ramparts/Barrier3")

# İnteraktif Mekanikler
@onready var blood_sigil_1: Node = get_node_or_null("Environment/Arena2_BloodHall/BloodSigil1")
@onready var blood_sigil_2: Node = get_node_or_null("Environment/Arena2_BloodHall/BloodSigil2")
@onready var weak_archway: Node = get_node_or_null("Environment/Arena3_Ramparts/WeakArchway")
@onready var great_bell: Node = get_node_or_null("Environment/Arena4_BellTower/GreatBell")

var _boss_defeated: bool = false
var _is_intro_dialogue: bool = true
var _current_dialogue_state: String = "intro"
var _played_form_taunts: Dictionary = { 1: false, 2: false, 3: false }
var _player_camera: Camera2D = null

var _sigil_1_destroyed: bool = false
var _sigil_2_destroyed: bool = false

const FATIH_NPC_SCENE = preload("res://scenes/allies/fatih_npc.tscn")


func _ready() -> void:
	# Vlad bölümünde karakter kılıç kuşanmış olarak başlar
	if player:
		if not player.has_sword and player.has_method("pickup_sword"):
			player.pickup_sword()
		elif not player.is_armed:
			player.is_armed = true
			if player.has_method("_emit_weapon_state"):
				player._emit_weapon_state()

	_play_fade_in()
	
	if player:
		_player_camera = player.get_node_or_null("Camera2D") as Camera2D
		_set_camera_arena(0, 1280)
		if hud:
			_setup_hud()

	if dialogue_box:
		dialogue_box.dialogue_completed.connect(_on_dialogue_completed)
		_current_dialogue_state = "intro"
		dialogue_box.start_dialogue_from_data("vlad_taunt", vlad_boss)

	if vlad_boss:
		vlad_boss.tree_exiting.connect(_on_vlad_boss_tree_exiting)
		if vlad_boss.has_signal("form_changed"):
			vlad_boss.form_changed.connect(_on_vlad_form_changed)

	if flashback_overlay:
		flashback_overlay.flashback_finished.connect(_on_flashback_finished)

	_setup_arena_mechanics()


func _setup_arena_mechanics() -> void:
	if blood_sigil_1 and blood_sigil_1.has_signal("sigil_destroyed"):
		blood_sigil_1.sigil_destroyed.connect(func(_node):
			_sigil_1_destroyed = true
			_check_blood_shield()
		)
	if blood_sigil_2 and blood_sigil_2.has_signal("sigil_destroyed"):
		blood_sigil_2.sigil_destroyed.connect(func(_node):
			_sigil_2_destroyed = true
			_check_blood_shield()
		)
	if weak_archway and weak_archway.has_signal("archway_collapsed"):
		weak_archway.archway_collapsed.connect(func(_node):
			if vlad_boss and vlad_boss.has_method("trigger_archway_stun"):
				vlad_boss.trigger_archway_stun()
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("Kemer Yıkıldı!", "Taktik Başarılı", "Vlad molozların altında sersemledi!")
		)
	if great_bell and great_bell.has_signal("bell_rung"):
		great_bell.bell_rung.connect(func(_ringer):
			if vlad_boss and vlad_boss.has_method("trigger_bell_stun"):
				vlad_boss.trigger_bell_stun()
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("Ulu Çan Çalındı!", "Akustik Şok", "Yarasa Vlad ses dalgasıyla yere çakıldı!")
		)


func _check_blood_shield() -> void:
	if _sigil_1_destroyed and _sigil_2_destroyed:
		if vlad_boss and vlad_boss.has_method("break_blood_shield"):
			vlad_boss.break_blood_shield()
		if hud and hud.has_method("set_tutorial"):
			hud.set_tutorial("Kan Kalkanı Kırıldı!", "Savunma Düştü", "Vlad'ın mühürleri parçalandı, doğrudan saldır!")


func _set_camera_arena(limit_left: int, limit_right: int) -> void:
	if _player_camera:
		if _player_camera.has_method("enter_boss_arena"):
			_player_camera.enter_boss_arena(Rect2(limit_left, -140, limit_right - limit_left, 770), Vector2(0.85, 0.85))
		else:
			_player_camera.limit_left = limit_left
			_player_camera.limit_right = limit_right
			_player_camera.limit_top = -140
			_player_camera.limit_bottom = 630


func _on_vlad_form_changed(new_form: int) -> void:
	# VladForm: 0=NORMAL, 1=VAMPIRE, 2=WEREWOLF, 3=BAT
	match new_form:
		0:
			if world_backdrop:
				world_backdrop.set_background_texture(TEX_ARENA_1, Color(0.2, 0.02, 0.05, 0.15))
		1: # VAMPIRE -> Arena 2
			_open_barrier(barrier_1)
			_set_camera_arena(1150, 2750)
			if world_backdrop:
				world_backdrop.set_background_texture(TEX_ARENA_2, Color(0.35, 0.02, 0.06, 0.22))
			if vlad_boss:
				vlad_boss.global_position = Vector2(1850, 560)
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("2. Faz: Kan Salonu", "Kan Kalkanı Aktif", "Platformlardaki 2 kan mührünü parçalayarak kalkanı yok et!")
		2: # WEREWOLF -> Arena 3
			_open_barrier(barrier_2)
			_set_camera_arena(2550, 4150)
			if world_backdrop:
				world_backdrop.set_background_texture(TEX_ARENA_3, Color(0.04, 0.06, 0.12, 0.18))
			if vlad_boss:
				vlad_boss.global_position = Vector2(3300, 560)
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("3. Faz: Yıkılan Surlar", "Yırtıcı Av", "Zayıf kemer düzeneğini Vlad'ın üzerine yık veya karşı saldırı kolla!")
		3: # BAT -> Arena 4
			_open_barrier(barrier_3)
			_set_camera_arena(3950, 5700)
			if world_backdrop:
				world_backdrop.set_background_texture(TEX_ARENA_4, Color(0.12, 0.04, 0.08, 0.20))
			if vlad_boss:
				vlad_boss.global_position = Vector2(4850, 360)
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("4. Faz: Ulu Çan Kulesi", "Son Karşılaşma", "Hava dalışlarında Ulu Çan'ı çalarak Vlad'ı sersemlet!")

	# Form Taunt Diyalog Entegrasyonu:
	if new_form in [1, 2, 3] and not _played_form_taunts.get(new_form, false):
		_played_form_taunts[new_form] = true
		var taunt_key: String = ""
		match new_form:
			1: taunt_key = "vlad_taunt_vampire"
			2: taunt_key = "vlad_taunt_werewolf"
			3: taunt_key = "vlad_taunt_bat"
		
		# Dönüşüm efektinin (kan dumanı ve silüet) tamamlanıp yeni formun netleşmesi için 1.2s bekle
		get_tree().create_timer(1.2).timeout.connect(func():
			if not _boss_defeated and is_instance_valid(vlad_boss) and not vlad_boss.is_dead and _current_dialogue_state == "none":
				_play_form_taunt(taunt_key)
		)


func _open_barrier(barrier: StaticBody2D) -> void:
	if not barrier:
		return
	var col: CollisionShape2D = barrier.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	var tw: Tween = create_tween()
	tw.tween_property(barrier, "modulate:a", 0.0, 0.6)
	tw.tween_callback(barrier.hide)


func _play_fade_in() -> void:
	var fade_overlay: CanvasLayer = CanvasLayer.new()
	fade_overlay.layer = 100
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.add_child(rect)
	add_child(fade_overlay)
	var tw: Tween = create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.5)
	tw.tween_callback(fade_overlay.queue_free)


func _setup_hud() -> void:
	if player.has_signal("weapon_state_changed"):
		player.weapon_state_changed.connect(func(has_w, is_a):
			if hud.has_method("update_weapon_slot"):
				hud.update_weapon_slot(has_w, is_a)
		)
	if "has_sword" in player and hud.has_method("update_weapon_slot"):
		var is_armed = player.is_armed if "is_armed" in player else player.has_sword
		hud.update_weapon_slot(player.has_sword, is_armed)
	if player.has_signal("player_damaged"):
		player.player_damaged.connect(func(hp, max_hp):
			if hud.has_method("update_health"):
				hud.update_health(hp, max_hp)
		)
	if hud.has_method("set_tutorial"):
		hud.set_tutorial("3. Sahne: Kan Taht Odası", "1. Faz: Voyvoda", "Mızrak atılımlarını ve impale zemin saldırılarını atlatarak yaklaş!")


func _play_form_taunt(key: String) -> void:
	if not dialogue_box or _boss_defeated:
		return
	var list: Array = StoryDataLoader.get_dialogue_sequence(key)
	if list.is_empty():
		push_warning("Stage3ThroneRoom: No dialogue found for %s, skipping." % key)
		_resume_boss_after_dialogue()
		return

	_current_dialogue_state = "form_change"
	dialogue_box.start_dialogue(list, vlad_boss)


func _resume_boss_after_dialogue() -> void:
	if vlad_boss and is_instance_valid(vlad_boss) and not vlad_boss.is_dead:
		if vlad_boss.has_method("on_cinematic_ended"):
			vlad_boss.on_cinematic_ended()
		elif "is_active" in vlad_boss:
			vlad_boss.is_active = true


func _on_dialogue_completed() -> void:
	match _current_dialogue_state:
		"intro":
			_current_dialogue_state = "none"
			_is_intro_dialogue = false
			_resume_boss_after_dialogue()
		"form_change":
			_current_dialogue_state = "none"
			_resume_boss_after_dialogue()
		"outro":
			_current_dialogue_state = "none"
			var game_state: Node = get_node_or_null("/root/GameState")
			if game_state:
				game_state.current_heart_pieces += 1
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("Eflak Seferi Tamamlandı", "Boyut Yırtığı Açıldı", "Bir sonraki çağa açılan portala adım at...")
			get_tree().create_timer(2.0).timeout.connect(func():
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			)
		_:
			_current_dialogue_state = "none"
			_resume_boss_after_dialogue()


func _physics_process(_delta: float) -> void:
	if _boss_defeated:
		return

	if vlad_boss and is_instance_valid(vlad_boss) and "current_health" in vlad_boss:
		if vlad_boss.current_health <= 0:
			_on_vlad_boss_defeated()


func _on_vlad_boss_tree_exiting() -> void:
	if not _boss_defeated:
		_on_vlad_boss_defeated()


func _on_vlad_boss_defeated() -> void:
	_boss_defeated = true

	# Kalp parçası kılıca çekilir
	if heart_piece and player:
		heart_piece.global_position = vlad_boss.global_position if is_instance_valid(vlad_boss) else Vector2(4850, 480)
		var tw: Tween = create_tween()
		tw.tween_property(heart_piece, "global_position", player.global_position + Vector2(0, -25), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(heart_piece, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func():
			if flashback_overlay:
				flashback_overlay.play_vlad_memory_sequence()
		)
	elif flashback_overlay:
		flashback_overlay.play_vlad_memory_sequence()


func _on_flashback_finished() -> void:
	# Flashback bitti; Fatih Sultan Mehmet taht odasına girer ve outro başlar
	if FATIH_NPC_SCENE and player:
		var fatih_inst: Node2D = FATIH_NPC_SCENE.instantiate() as Node2D
		fatih_inst.global_position = Vector2(maxf(player.global_position.x - 140.0, 4100.0), 560.0)
		add_child(fatih_inst)

	if dialogue_box:
		_current_dialogue_state = "outro"
		dialogue_box.start_dialogue_from_data("fatih_outro")
