extends "res://scripts/enemies/monster_enemy.gd"

## res://scripts/enemies/ww2/ww2_enemy.gd
## Bölüm 4 standart düşmanları (Epic 2D-144): MonsterEnemy yapay zekâsı + türe özgü davranış.
##   none         — Siper Piyadesi, Okült Deney Kalıntısı (süngü / pençe)
##   flamer       — Alev Makineci: saldırı anında önüne alev parçacığı ve ateş sesi
##   gas_on_death — Gaz Maskeli Lağımcı: ölünce geçici zehirli gaz bulutu bırakır
##   flare_caller — Keşif/Sinyal Gözcüsü: oyuncuyu görünce işaret fişeğiyle topçu çağırır

signal artillery_called(target_x: float)

const ShellScript = preload("res://scripts/hazards/ww2/artillery_shell.gd")
const GasScript = preload("res://scripts/hazards/ww2/toxic_gas.gd")
const ChapterState = preload("res://scripts/components/ww2_chapter_state.gd")
const FLAME_TEX: Texture2D = preload("res://assets/effects/ww2/flame_particle.png")

@export_enum("none", "flamer", "gas_on_death", "flare_caller") var behavior: String = "none"
@export var flare_cooldown: float = 7.0
@export var flare_shells: int = 2
@export var ground_y_offset: float = 0.0

var _flare_cd: float = 1.2
var _flame: CPUParticles2D = null


func _ready() -> void:
	super._ready()
	add_to_group("ww2_enemies")
	if behavior == "flamer":
		_flame = CPUParticles2D.new()
		_flame.texture = FLAME_TEX
		_flame.amount = 26
		_flame.lifetime = 0.45
		_flame.emitting = false
		_flame.direction = Vector2.RIGHT
		_flame.spread = 14.0
		_flame.initial_velocity_min = 160.0
		_flame.initial_velocity_max = 220.0
		_flame.gravity = Vector2(0.0, -40.0)
		_flame.position = Vector2(18.0, -26.0)
		visual_node.add_child(_flame)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead or behavior != "flare_caller":
		return
	_flare_cd -= delta
	if _flare_cd <= 0.0 and is_instance_valid(_target_node):
		_flare_cd = flare_cooldown
		call_artillery(_target_node.global_position.x)


func _start_attack() -> void:
	super._start_attack()
	if behavior == "flamer" and _flame:
		_flame.emitting = true
		var am: Node = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sound_2d"):
			am.play_sound_2d("flamethrower_burst", global_position, null, -4.0, 900.0)
		get_tree().create_timer(0.55).timeout.connect(func() -> void:
			if is_instance_valid(_flame):
				_flame.emitting = false
		)


## İşaret fişeği → oyuncunun x'ine topçu (Sessiz Batarya %50 azaltır)
func call_artillery(target_x: float) -> Array[Node2D]:
	var shells: Array[Node2D] = []
	if anim_sprite:
		anim_sprite.play(&"attack")
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("flare_ignite", global_position, null, -4.0, 900.0)
	var factor: float = ChapterState.artillery_factor(self)
	var count: int = maxi(1, int(ceil(float(flare_shells) * factor)))
	for i: int in count:
		var shell: Node2D = ShellScript.new() as Node2D
		shell.set("telegraph_time", 1.2 + 0.3 * float(i))
		shell.set("damage", int(round(20.0 * factor)))
		get_parent().add_child(shell)
		shell.global_position = Vector2(target_x + randf_range(-90.0, 90.0) * float(i), global_position.y + ground_y_offset)
		shells.append(shell)
	artillery_called.emit(target_x)
	return shells


func _die() -> void:
	var was_dead: bool = is_dead
	super._die()
	if was_dead or behavior != "gas_on_death" or not is_inside_tree():
		return
	var gas: Area2D = GasScript.new() as Area2D
	gas.set("size", Vector2(130.0, 70.0))
	gas.set("lifetime", 5.0)
	gas.set("damage_per_tick", 4)
	get_parent().call_deferred("add_child", gas)
	gas.position = position
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound_2d"):
		am.play_sound_2d("gas_hiss", global_position, null, -3.0, 900.0)
