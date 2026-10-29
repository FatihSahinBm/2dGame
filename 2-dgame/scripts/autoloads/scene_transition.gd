extends CanvasLayer

## res://scripts/autoloads/scene_transition.gd
## Pürüzsüz Ekran Karartma & Sahne Geçiş Yöneticisi

signal transition_started()
signal scene_changed()
signal transition_completed()

@onready var color_rect: ColorRect = $ColorRect

var is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	if not color_rect:
		color_rect = get_node_or_null("ColorRect") as ColorRect
	if not color_rect:
		color_rect = ColorRect.new()
		color_rect.name = "ColorRect"
		color_rect.anchors_preset = Control.PRESET_FULL_RECT
		color_rect.color = Color.BLACK
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
		add_child(color_rect)
	else:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)


## Karartarak hedef sahneye geçer ve geri açar
func change_scene(target_path: String, duration: float = 0.35) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	transition_started.emit()

	# Kararma (Fade out)
	await fade_out(duration)

	# Sahne Değişimi
	var err: Error = get_tree().change_scene_to_file(target_path)
	if err != OK:
		push_error("SceneTransition: Sahneye geçilemedi -> " + target_path)

	scene_changed.emit()

	# Kısa bekleme
	await get_tree().process_frame

	# Eğer yüklenen sahne bir oyun bölümüyse (ana menü değilse), GameState ve SaveManager'ı güncelle
	if not target_path.contains("main_menu.tscn"):
		var root_node = get_tree().root
		var game_state = root_node.get_node_or_null("GameState")
		if game_state:
			game_state.current_stage_path = target_path
		var save_mgr = root_node.get_node_or_null("SaveManager")
		if save_mgr:
			if save_mgr.get("cached_checkpoint_stage") != target_path:
				save_mgr.cached_checkpoint_position = Vector2.ZERO
				save_mgr.cached_checkpoint_id = ""
				save_mgr.cached_checkpoint_stage = target_path
			if save_mgr.has_method("apply_cached_stats_to_scene"):
				save_mgr.apply_cached_stats_to_scene()
		if save_mgr and save_mgr.has_method("save_game"):
			if save_mgr.get("autosave_enabled") != false:
				var active_slot = save_mgr.get("active_slot") if save_mgr.get("active_slot") != null else 1
				save_mgr.save_game(active_slot)

	# Açılma (Fade in)
	await fade_in(duration)

	is_transitioning = false
	transition_completed.emit()


## Ekranı siyahla kaplar (Fade out)
func fade_out(duration: float = 0.35) -> void:
	if not color_rect:
		return
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


## Siyahlığı kaldırır (Fade in)
func fade_in(duration: float = 0.35) -> void:
	if not color_rect:
		return
	var tween: Tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
