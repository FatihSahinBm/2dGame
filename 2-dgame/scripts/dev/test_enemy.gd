extends Node2D

@onready var status_label: Label = $UI/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var btn_damage_25: Button = $UI/PanelContainer/MarginContainer/VBoxContainer/HBoxButtons/BtnDamage25
@onready var btn_damage_100: Button = $UI/PanelContainer/MarginContainer/VBoxContainer/HBoxButtons/BtnDamage100
@onready var btn_reset: Button = $UI/PanelContainer/MarginContainer/VBoxContainer/HBoxButtons/BtnReset

func _ready() -> void:
	if btn_damage_25:
		btn_damage_25.pressed.connect(_on_btn_damage_25_pressed)
	if btn_damage_100:
		btn_damage_100.pressed.connect(_on_btn_damage_100_pressed)
	if btn_reset:
		btn_reset.pressed.connect(_on_btn_reset_pressed)

func _process(_delta: float) -> void:
	_update_debug_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_damage_all_damageables(25)
		elif event.keycode == KEY_K:
			_damage_all_damageables(100)
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _on_btn_damage_25_pressed() -> void:
	_damage_all_damageables(25)

func _on_btn_damage_100_pressed() -> void:
	_damage_all_damageables(100)

func _on_btn_reset_pressed() -> void:
	get_tree().reload_current_scene()

func _damage_all_damageables(amount: int) -> void:
	var damageable_nodes: Array[Node] = get_tree().get_nodes_in_group("damageable")
	var hit_count: int = 0
	for node in damageable_nodes:
		if node.has_method("take_damage") and not (node.get("is_dead") == true):
			node.take_damage(amount)
			hit_count += 1

func _update_debug_status() -> void:
	if not status_label:
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var text: String = "Aktif Düşman Sayısı: %d\n" % enemies.size()
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		var hp: int = enemy.get("current_health") if "current_health" in enemy else 0
		var max_hp: int = enemy.get("max_health") if "max_health" in enemy else 0
		var dir: int = enemy.get("direction") if "direction" in enemy else 0
		var is_dead_val: bool = enemy.get("is_dead") if "is_dead" in enemy else false
		var dir_str: String = "Sağa" if dir > 0 else "Sola"
		var state_str: String = "ÖLÜ" if is_dead_val else ("Devriyede (%s)" % dir_str)
		text += "• %s: Can %d/%d | Durum: %s\n" % [enemy.name, hp, max_hp, state_str]

	status_label.text = text.strip_edges()
