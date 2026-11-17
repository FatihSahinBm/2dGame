extends Node

## res://scripts/combat/poise_component.gd
## Duruş (poise) ve denge kırma bileşeni — Story 2D-128.
##
## - Düşmanın max_poise değeri 0'dan büyükse _ready'de attach_if_applicable ile eklenir.
## - Oyuncu saldırıları duruşu azaltır; miktar saldırı türüne göre data/combat/poise.json'dan gelir.
## - Duruş 0'a inince düşman break_duration boyunca sersemler (on_poise_broken / on_parried),
##   süre bitince duruş tamamen dolar. Sersemken gelen duruş hasarı yok sayılır: iki sersemleme
##   üst üste binmez.
## - Hasar almadan regen_delay geçerse duruş kendiliğinden dolar.
## - Boss ve mini-boss'lar bağışıktır (is_parry_immune() true veya "boss"/"mini_boss" grubu):
##   bileşen eklenmez. T-Rex kendi faz içi stagger sistemini kullanmaya devam eder.
## - Gösterge yalnızca duruşu eksilmiş veya kırılmış düşmanda görünür.

signal poise_changed(current: float, maximum: float)
signal poise_broken(duration: float)
signal poise_restored()

const CONFIG_PATH: String = "res://data/combat/poise.json"
const NODE_NAME: String = "PoiseComponent"
const SELF_PATH: String = "res://scripts/combat/poise_component.gd"

static var _config: Dictionary = {}

var max_poise: float = 0.0
var current_poise: float = 0.0
var is_broken: bool = false

var _break_timer: float = 0.0
var _regen_wait: float = 0.0
var _bar: ProgressBar = null


static func get_config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH)) if FileAccess.file_exists(CONFIG_PATH) else null
		_config = parsed as Dictionary if parsed is Dictionary else {}
	return _config


## Saldırı türünün duruş hasarı (tanımsız tür "default" değerini kullanır)
static func get_attack_poise(attack_type: String) -> float:
	var table: Dictionary = get_config().get("attack_poise", {}) as Dictionary
	return float(table.get(attack_type, table.get("default", 10)))


static func is_immune(enemy: Node) -> bool:
	if enemy.is_in_group("boss") or enemy.is_in_group("mini_boss"):
		return true
	return enemy.has_method("is_parry_immune") and bool(enemy.is_parry_immune())


## Düşmana, duruşu varsa ve bağışık değilse bileşeni ekler
static func attach_if_applicable(enemy: Node) -> Node:
	if not is_instance_valid(enemy) or not "max_poise" in enemy or float(enemy.max_poise) <= 0.0 or is_immune(enemy):
		return null
	var existing: Node = enemy.get_node_or_null(NODE_NAME)
	if existing:
		return existing
	var component: Node = (load(SELF_PATH) as GDScript).new()
	component.name = NODE_NAME
	component.max_poise = float(enemy.max_poise)
	component.current_poise = component.max_poise
	enemy.add_child(component)
	return component


## Oyuncunun vuruşunu hedefe duruş hasarı olarak işler (hedefte bileşen yoksa hiçbir şey yapmaz)
static func apply_player_hit(target: Variant, attack_type: String) -> bool:
	if not (target is Node) or not is_instance_valid(target):
		return false
	var component: Node = (target as Node).get_node_or_null(NODE_NAME)
	if component == null:
		return false
	return component.apply_poise_damage(get_attack_poise(attack_type))


func _ready() -> void:
	_create_bar()
	_refresh_bar()


## Duruş hasarı uygular. Duruş kırıldıysa true döner.
func apply_poise_damage(amount: float) -> bool:
	if amount <= 0.0 or is_broken or max_poise <= 0.0:
		return false
	var owner_node: Node = get_parent()
	if owner_node and "is_dead" in owner_node and owner_node.is_dead:
		return false
	current_poise = maxf(current_poise - amount, 0.0)
	_regen_wait = float(get_config().get("regen_delay", 2.5))
	poise_changed.emit(current_poise, max_poise)
	_refresh_bar()
	if current_poise <= 0.0:
		_break()
		return true
	return false


func _break() -> void:
	is_broken = true
	_break_timer = float(get_config().get("break_duration", 1.6))
	var owner_node: Node = get_parent()
	if owner_node:
		if owner_node.has_method("on_poise_broken"):
			owner_node.on_poise_broken(_break_timer)
		elif owner_node.has_method("on_parried"):
			owner_node.on_parried(_break_timer)
	poise_broken.emit(_break_timer)
	_refresh_bar()


func _process(delta: float) -> void:
	if is_broken:
		_break_timer -= delta
		if _break_timer <= 0.0:
			is_broken = false
			current_poise = max_poise
			poise_restored.emit()
			poise_changed.emit(current_poise, max_poise)
			_refresh_bar()
		return
	if current_poise < max_poise:
		if _regen_wait > 0.0:
			_regen_wait -= delta
		else:
			current_poise = minf(current_poise + float(get_config().get("regen_per_second", 20.0)) * delta, max_poise)
			poise_changed.emit(current_poise, max_poise)
			_refresh_bar()


func _create_bar() -> void:
	var owner_node: Node = get_parent()
	if owner_node == null:
		return
	_bar = ProgressBar.new()
	_bar.name = "PoiseBar"
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(36, 3)
	_bar.size = Vector2(36, 3)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.85, 0.3, 1.0)
	_bar.add_theme_stylebox_override("fill", fill)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	_bar.add_theme_stylebox_override("background", background)
	var health_bar: Control = owner_node.get_node_or_null("UI/HealthBar") as Control
	if health_bar and health_bar.get_parent():
		health_bar.get_parent().add_child(_bar)
		_bar.position = health_bar.position + Vector2(0, health_bar.size.y + 2.0)
		_bar.size.x = maxf(health_bar.size.x, 24.0)
	else:
		owner_node.add_child(_bar)
		_bar.position = Vector2(-18, -52)


func _refresh_bar() -> void:
	if _bar == null:
		return
	_bar.max_value = max_poise
	_bar.value = current_poise
	_bar.visible = is_broken or current_poise < max_poise
	_bar.modulate = Color(1.0, 0.35, 0.3, 1.0) if is_broken else Color.WHITE
