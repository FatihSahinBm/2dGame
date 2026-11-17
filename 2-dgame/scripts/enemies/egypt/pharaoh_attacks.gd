extends RefCounted

## res://scripts/enemies/egypt/pharaoh_attacks.gd
## Firavun Kral saldırı kalıpları (Epic 2D-143). Saldırılar sahneye bağımsız tehlike düğümleri
## (SunBeam, SandTrap) olarak eklenir; boss yalnızca ne zaman ve nereye çağıracağına karar verir.

const SunBeamScript = preload("res://scripts/hazards/egypt/sun_beam.gd")
const SandTrapScript = preload("res://scripts/hazards/egypt/sand_trap.gd")

const BEAM_DAMAGE_BY_PHASE: Array[int] = [0, 20, 24, 28]
const BEAM_TELEGRAPH_BY_PHASE: Array[float] = [0.0, 1.0, 0.85, 0.75]


## Güneş Asası ışınları: verilen x konumlarına telegraph'lı tek atımlık ışınlar
static func cast_sun_beams(host: Node, xs: Array[float], ground_y: float, phase: int) -> Array[Node2D]:
	var beams: Array[Node2D] = []
	var p: int = clampi(phase, 1, 3)
	for i: int in xs.size():
		var beam: Node2D = SunBeamScript.new() as Node2D
		beam.set("one_shot", true)
		beam.set("damage", BEAM_DAMAGE_BY_PHASE[p])
		beam.set("telegraph_time", BEAM_TELEGRAPH_BY_PHASE[p] + 0.15 * float(i))
		beam.set("beam_height", 720.0)
		beam.position = Vector2(xs[i], ground_y)
		host.add_child(beam)
		beams.append(beam)
	return beams


## Kum tuzakları: oyuncunun çevresinde geçici tuzaklar açar (arena sınırları içinde)
static func spawn_sand_traps(host: Node, center_x: float, ground_y: float, count: int, arena: Vector2) -> Array[Node2D]:
	var traps: Array[Node2D] = []
	var spacing: float = 170.0
	var start: float = center_x - spacing * float(count - 1) * 0.5
	for i: int in count:
		var trap: Node2D = SandTrapScript.new() as Node2D
		trap.set("lifetime", 5.5)
		trap.set("width", 110.0)
		trap.set("damage_per_tick", 5)
		trap.position = Vector2(clampf(start + spacing * float(i), arena.x + 60.0, arena.y - 60.0), ground_y)
		host.add_child(trap)
		traps.append(trap)
	var am: Node = host.get_node_or_null("/root/AudioManager") if host.is_inside_tree() else null
	if am and am.has_method("play_sfx"):
		am.play_sfx("sand_trap", -2.0)
	return traps


## Faz bazında ışın hedefleri: 1. faz tek, 2. faz iki, 3. faz üç ışın (biri oyuncunun üstünde)
static func beam_targets(phase: int, player_x: float, arena: Vector2) -> Array[float]:
	var xs: Array[float] = [player_x]
	if phase >= 2:
		xs.append(clampf(player_x + (180.0 if randf() < 0.5 else -180.0), arena.x + 40.0, arena.y - 40.0))
	if phase >= 3:
		xs.append(clampf(player_x - (xs[1] - player_x), arena.x + 40.0, arena.y - 40.0))
	return xs


## Bir sonraki saldırı: faz ve mesafeye göre ağırlıklı seçim
static func choose_attack(phase: int, distance: float, alive_minions: int, since_summon: float) -> String:
	if distance < 70.0:
		return "staff"
	if phase >= 3 and alive_minions < 3 and since_summon > 9.0:
		return "summon"
	if phase >= 2 and randf() < 0.35:
		return "sand"
	return "beam"
