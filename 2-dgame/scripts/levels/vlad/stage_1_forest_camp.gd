class_name Stage1ForestCamp
extends Node2D

## res://scripts/levels/vlad/stage_1_forest_camp.gd
## 1. Sahne: 1462 Târgovişte Gece Baskını & Kazıklı Orman Kuşatması
## 1. Aşama: Zaman yırtığından ormana düşüş ve temel kontroller.
## 2. Aşama: Pusuya düşen Yeniçeri Kumandanı'nı kurtarma (veya şehit fermanını alma).
## 3. Aşama: Kırık erzak yolu (güvenli/riskli yol, ok sadakları yan görevi).
## 4. Aşama: Fatih Sultan Mehmed'in otağında diyalog ve kuşatma hazırlığı.
## 5. Aşama: Kazıklı barikatlar ve köprü hücumuyla kaleye geçiş.

@export var next_scene_path: String = "res://scenes/levels/vlad/stage_2_castle_dungeon.tscn"

@onready var player: CharacterBody2D = $CombatPlayer
@onready var hud: CanvasLayer = $FantasyHUD
@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var commander: CharacterBody2D = get_node_or_null("AmbushZone/JanissaryCommander") as CharacterBody2D
@onready var ambush_enemies: Node2D = get_node_or_null("AmbushZone/Enemies") as Node2D
@onready var fatih_npc: CharacterBody2D = get_node_or_null("ImperialCamp/FatihNPC") as CharacterBody2D
@onready var vanguard_allies: Node2D = get_node_or_null("ImperialCamp/VanguardAllies") as Node2D
@onready var exit_gate: Area2D = $ExitGate
@onready var world_backdrop: WorldParallaxBackground = get_node_or_null("WorldBackdrop") as WorldParallaxBackground

const TEX_STAGE1_RIFT = preload("res://assets/backgrounds/stage_1_zone_1_time_rift.png")
const TEX_STAGE1_CAMP = preload("res://assets/backgrounds/stage_1_zone_2_camp.png")
const TEX_STAGE1_BRIDGE = preload("res://assets/backgrounds/stage_1_zone_4_bridge.png")
var _current_bg_zone: int = 1

var _ambush_cleared: bool = false
var _siege_active: bool = false
var _is_transitioning: bool = false
var _has_orders: bool = false
var _has_arrow_quiver: bool = false
var _archer_bonus_active: bool = false

const COMMANDER_ORDERS_SCENE = preload("res://scripts/objects/commander_orders_drop.gd")


func _ready() -> void:
	_setup_camera()
	_play_fade_in()
	_play_time_rift_intro()

	if player and hud:
		_setup_hud()

	if commander:
		if commander.has_signal("rescued"):
			commander.rescued.connect(_on_commander_rescued)
		if commander.has_signal("died"):
			commander.died.connect(_on_commander_died)

	if fatih_npc and fatih_npc.has_signal("siege_charge_ordered"):
		fatih_npc.siege_charge_ordered.connect(_on_siege_charge_ordered)

	if exit_gate:
		exit_gate.body_entered.connect(_on_exit_gate_entered)

	_setup_sidequest_items()


func _setup_camera() -> void:
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = 0
			cam.limit_right = 2600
			cam.limit_top = -140
			cam.limit_bottom = 630


func _play_time_rift_intro() -> void:
	# Açılış: Boyut yırtığı ve madeni kılıç feryadı
	if player:
		var tw: Tween = create_tween()
		tw.tween_property(player, "modulate", Color(2.0, 1.2, 0.4, 0.0), 0.0)
		tw.tween_property(player, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_QUAD)

	var label: Label = Label.new()
	label.text = "*Kılıç zemine sürtünerek tiz bir madeni feryat koparır...*"
	label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 12)
	label.global_position = Vector2(80.0, 490.0)
	add_child(label)

	var tw2: Tween = label.create_tween()
	tw2.tween_property(label, "global_position:y", label.global_position.y - 25.0, 3.0)
	tw2.parallel().tween_property(label, "modulate:a", 0.0, 3.0)
	tw2.tween_callback(label.queue_free)


func _setup_sidequest_items() -> void:
	var quiver = get_node_or_null("Environment/SplitRoad/ArrowQuiverItem")
	if quiver and quiver.has_signal("collected"):
		quiver.collected.connect(func():
			_has_arrow_quiver = true
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("Ok Sadakları Alındı", "Kemankeş'e Ulaştır", "Kamptaki Kemankeş okçusuna alevli ok sadaklarını teslim et.")
		)


func _process(_delta: float) -> void:
	if not _ambush_cleared and ambush_enemies:
		var alive_count: int = 0
		for enemy in ambush_enemies.get_children():
			if enemy is Node2D and not ("is_dead" in enemy and enemy.is_dead):
				alive_count += 1
		if alive_count == 0:
			_ambush_cleared = true
			if commander and is_instance_valid(commander) and commander.has_method("mark_rescued"):
				commander.mark_rescued()


func _setup_hud() -> void:
	if player.has_signal("weapon_state_changed"):
		player.weapon_state_changed.connect(func(has_w, is_a):
			if hud.has_method("update_weapon_slot"):
				hud.update_weapon_slot(has_w, is_a)
		)
	if player.has_signal("player_damaged"):
		player.player_damaged.connect(func(hp, max_hp):
			if hud.has_method("update_health"):
				hud.update_health(hp, max_hp)
		)
	if hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"1. Sahne: 1462 Gece Baskını",
			"Kumandanı Kurtar",
			"[A/D] Koş | [Space] Zıpla | [Sol Tık] Saldır. İlerideki Osmanlı kumandanını kurtar!"
		)


func _on_commander_rescued() -> void:
	if hud and hud.has_method("set_tutorial"):
		hud.set_tutorial(
			"Hünkarın Otağına İlerle",
			"Fatih ile Görüş [E]",
			"Kumandan seni Fatih Sultan Mehmet'in otağına götürüyor. İlerideki otağa git."
		)


func _on_commander_died(death_pos: Vector2) -> void:
	_ambush_cleared = true
	# Kumandan ölürse ferman düşer (Soft-lock önleme mekanizması)
	var drop = Area2D.new()
	drop.set_script(COMMANDER_ORDERS_SCENE)
	drop.global_position = death_pos
	add_child(drop)
	if drop.has_signal("collected"):
		drop.collected.connect(func():
			_has_orders = true
			if hud and hud.has_method("set_tutorial"):
				hud.set_tutorial("Ferman Alındı", "Fatih'in Otağına Git [E]", "Şehit kumandanın fermanını Fatih Sultan Mehmed Han'ın otağına ulaştır.")
		)


func _on_siege_charge_ordered() -> void:
	_siege_active = true

	# Kılıç bir anlığına Vlad'ın Kalp Parçası'nı sezip sarsılır
	if player and "visual_node" in player and player.visual_node:
		var tw: Tween = create_tween()
		tw.tween_property(player.visual_node, "modulate", Color(1.5, 0.4, 0.6, 1.0), 0.15)
		tw.tween_property(player.visual_node, "modulate", Color.WHITE, 0.25)

	# Eğer okçu yan görevi yapıldıysa okçu bonusu devreye girer
	if _has_arrow_quiver:
		_archer_bonus_active = true
		_start_archer_barricade_bombardment()

	if hud and hud.has_method("set_tutorial"):
		var extra_msg = " (Alevli ok desteği devrede!)" if _archer_bonus_active else ""
		hud.set_tutorial(
			"Kuşatma Hücumu!",
			"Barikatları Parçala",
			"Yeniçerilerle birlikte köprüdeki kazıklı barikatları parçala ve kale kapısına ulaş!" + extra_msg
		)

	if vanguard_allies:
		for child in vanguard_allies.get_children():
			if "speed" in child:
				child.speed = 115.0


func _start_archer_barricade_bombardment() -> void:
	# Kemankeş okçusunun barikatlara alevli ok yağdırması
	var timer: Timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func():
		if not is_inside_tree() or _is_transitioning:
			timer.stop()
			timer.queue_free()
			return
		var barricades = get_tree().get_nodes_in_group("barricades")
		for b in barricades:
			if b and is_instance_valid(b) and b.has_method("take_damage"):
				b.take_damage(25)
				_spawn_burning_hit_vfx(b.global_position)
				break
	)


func _spawn_burning_hit_vfx(pos: Vector2) -> void:
	var label: Label = Label.new()
	label.text = "🔥 -25 (Alevli Ok)"
	label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 11)
	label.global_position = pos + Vector2(-20.0, -40.0)
	add_child(label)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y - 20.0, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)

func _physics_process(_delta: float) -> void:
	if player and world_backdrop:
		var px: float = player.global_position.x
		if px < 1050.0 and _current_bg_zone != 1:
			_current_bg_zone = 1
			world_backdrop.set_background_texture(TEX_STAGE1_RIFT, Color(0.05, 0.02, 0.08, 0.18))
		elif px >= 1050.0 and px < 1650.0 and _current_bg_zone != 2:
			_current_bg_zone = 2
			world_backdrop.set_background_texture(TEX_STAGE1_CAMP, Color(0.15, 0.06, 0.04, 0.15))
		elif px >= 1650.0 and _current_bg_zone != 3:
			_current_bg_zone = 3
			world_backdrop.set_background_texture(TEX_STAGE1_BRIDGE, Color(0.2, 0.05, 0.03, 0.22))

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


func _on_exit_gate_entered(body: Node2D) -> void:
	if body == player and not _is_transitioning:
		_is_transitioning = true
		if player and "can_move" in player:
			player.can_move = false
		var fade_overlay: CanvasLayer = CanvasLayer.new()
		fade_overlay.layer = 100
		var rect: ColorRect = ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.color = Color.BLACK
		rect.modulate.a = 0.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_overlay.add_child(rect)
		add_child(fade_overlay)
		var tw: Tween = create_tween()
		tw.tween_property(rect, "modulate:a", 1.0, 0.6)
		tw.tween_callback(func():
			get_tree().change_scene_to_file(next_scene_path)
		)
