extends Control
class_name PauseMenu

## res://scripts/ui/pause_menu.gd
## Dark Fantasy Duraklatma Menüsü (Pause Menu)
## Oyun duraklatıldığında görünür; Devam Et, Yeniden Başlat ve Ana Menü seçenekleri sunar.

signal resumed()
signal restarted()
signal main_menu_requested()

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Center/PanelContainer
@onready var btn_resume: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnResume
@onready var btn_restart: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnRestart
@onready var btn_main_menu: Button = $Center/PanelContainer/Margin/VBox/Buttons/BtnMainMenu

var _signals_connected: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_nodes()
	_setup_signals()
	visible = false


func _resolve_nodes() -> void:
	if not backdrop:
		backdrop = find_child("Backdrop", true, false) as ColorRect
	if not panel:
		panel = find_child("PanelContainer", true, false) as PanelContainer
	if not btn_resume:
		btn_resume = find_child("BtnResume", true, false) as Button
	if not btn_restart:
		btn_restart = find_child("BtnRestart", true, false) as Button
	if not btn_main_menu:
		btn_main_menu = find_child("BtnMainMenu", true, false) as Button


func _setup_signals() -> void:
	if _signals_connected:
		return
	_resolve_nodes()
	if btn_resume and not btn_resume.pressed.is_connected(resume_game):
		btn_resume.pressed.connect(resume_game)
	if btn_restart and not btn_restart.pressed.is_connected(restart_stage):
		btn_restart.pressed.connect(restart_stage)
	if btn_main_menu and not btn_main_menu.pressed.is_connected(go_to_main_menu):
		btn_main_menu.pressed.connect(go_to_main_menu)
	_signals_connected = true


func _get_scene_tree() -> SceneTree:
	if is_inside_tree() and get_tree():
		return get_tree()
	elif Engine.get_main_loop() is SceneTree:
		return Engine.get_main_loop() as SceneTree
	var p: Node = get_parent()
	while p:
		if p.is_inside_tree() and p.get_tree():
			return p.get_tree()
		if p.has_method("get_tree") and p.get_tree():
			return p.get_tree()
		p = p.get_parent()
	return null


func open() -> void:
	_resolve_nodes()
	_setup_signals()
	visible = true
	var tree = _get_scene_tree()
	if tree:
		tree.paused = true
	if btn_resume and btn_resume.is_inside_tree():
		btn_resume.grab_focus()


func resume_game() -> void:
	visible = false
	var tree = _get_scene_tree()
	if tree:
		tree.paused = false
	resumed.emit()


func restart_stage() -> void:
	visible = false
	var tree = _get_scene_tree()
	if tree:
		tree.paused = false
		tree.reload_current_scene()
	restarted.emit()


func go_to_main_menu() -> void:
	visible = false
	var tree = _get_scene_tree()
	if tree:
		tree.paused = false
	main_menu_requested.emit()

	var root_node: Node = null
	if tree:
		root_node = tree.root

	var transition: Node = null
	if root_node:
		transition = root_node.get_node_or_null("SceneTransition")

	if transition and transition.has_method("change_scene"):
		transition.change_scene("res://scenes/ui/main_menu.tscn", 0.35)
	elif tree:
		tree.change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel") or event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			resume_game()
			get_viewport().set_input_as_handled()
