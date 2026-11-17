extends CanvasLayer

## res://scripts/autoloads/scene_transition.gd
## Pürüzsüz Ekran Karartma & Sahne Geçiş Yöneticisi

signal transition_started()
signal scene_changed()
signal transition_completed()
signal load_progress(ratio: float)
signal load_failed(target_path: String)

const LoadingOverlay = preload("res://scripts/ui/loading_overlay.gd")
## Yükleme bundan kısa sürerse yükleme ekranı hiç gösterilmez (kısa geçişlerde titreme olmasın)
const LOADING_SCREEN_DELAY: float = 0.12
const LOAD_ERROR_DISPLAY_TIME: float = 1.6

var last_error_path: String = ""
var _loading_overlay: Control = null
var _loading_path: String = ""

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

	# Sahne arka planda yüklenir; yükleme ekranı gerçek ilerlemeyi gösterir (Story 2D-152)
	var packed: PackedScene = await _load_scene_threaded(target_path)
	var err: Error = get_tree().change_scene_to_packed(packed) if packed else ERR_CANT_OPEN
	if err != OK:
		# Güvenli geri dönüş: mevcut sahnede kalınır, hata gösterilir, ekran yeniden açılır
		push_error("SceneTransition: Sahneye geçilemedi -> " + target_path)
		last_error_path = target_path
		load_failed.emit(target_path)
		_ensure_loading_overlay().show_error(tr("LOADING_FAILED_DESC"))
		await get_tree().create_timer(LOAD_ERROR_DISPLAY_TIME, true, false, true).timeout
		_loading_overlay.finish()
		await fade_in(duration)
		is_transitioning = false
		transition_completed.emit()
		return

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


## Sahneyi ResourceLoader ile arka planda yükler. Başarısızsa null döner.
## Aynı anda tek yükleme yapılır; yüzde ResourceLoader'ın bildirdiği gerçek ilerlemedir.
func _load_scene_threaded(target_path: String) -> PackedScene:
	if not _loading_path.is_empty() or target_path.is_empty() or not ResourceLoader.exists(target_path, "PackedScene"):
		return null
	if ResourceLoader.load_threaded_request(target_path, "PackedScene") != OK:
		return null
	_loading_path = target_path
	var overlay: Control = _ensure_loading_overlay()
	var progress: Array = []
	var elapsed: float = 0.0
	var result: PackedScene = null
	while true:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_path, progress)
		var ratio: float = float(progress[0]) if not progress.is_empty() else 0.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			overlay.set_progress(1.0)
			load_progress.emit(1.0)
			result = ResourceLoader.load_threaded_get(target_path) as PackedScene
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		if elapsed >= LOADING_SCREEN_DELAY and not overlay.visible:
			overlay.begin()
		overlay.set_progress(ratio)
		load_progress.emit(ratio)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	overlay.finish()
	_loading_path = ""
	return result


func is_loading() -> bool:
	return not _loading_path.is_empty()


func _ensure_loading_overlay() -> Control:
	if _loading_overlay == null or not is_instance_valid(_loading_overlay):
		_loading_overlay = LoadingOverlay.new()
		_loading_overlay.name = "LoadingOverlay"
		add_child(_loading_overlay)
	return _loading_overlay


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
