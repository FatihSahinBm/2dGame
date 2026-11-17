extends RefCounted

## res://scripts/enemies/future/ai_lord_attacks.gd
## AI Lord saldırı tehlikeleri (Epic 2D-158). Işınlar FutureAttacks.aim_beam ile kırmızı Line2D
## nişan çizgisiyle telegraph edilir ve dünya engelinde (siper) kesilir.
##   Form 1: lattice (lazer ağı), dron çağrısı sayısı, blink hedefi
##   Form 2: shoulder_cannon (CyberLaserSystem tarzı siper arkası bloklanabilir ışın), taret sayısı
##   Form 3: freeze_field (zaman dondurma), spawn_echo (dijital yankı), cross_beams (çapraz ışınlar)

const FutureAttacks = preload("res://scripts/enemies/future/future_attacks.gd")
const ChapterState = preload("res://scripts/components/future_chapter_state.gd")
const Phases = preload("res://scripts/enemies/future/ai_lord_phases.gd")
const EchoScript = preload("res://scripts/enemies/future/ai_lord_echo.gd")

const LATTICE_TELEGRAPH: float = 0.9
const LATTICE_HEIGHTS: Array[float] = [22.0, 78.0, 134.0]


## Lazer ağı: üç yükseklikten ikisi + bir çapraz ışın; her seferinde farklı bir boşluk kalır
static func lattice(host: Node2D, arena: Vector2, ground_y: float, damage: int, turn: int) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	var gap: int = turn % LATTICE_HEIGHTS.size()
	for i: int in LATTICE_HEIGHTS.size():
		if i == gap:
			continue
		var y: float = ground_y - LATTICE_HEIGHTS[i]
		lines.append(FutureAttacks.aim_beam(host, Vector2(arena.x, y), Vector2(arena.y, y), LATTICE_TELEGRAPH + 0.15 * float(i), damage))
	var from_left: bool = turn % 2 == 0
	var a: Vector2 = Vector2(arena.x if from_left else arena.y, ground_y - 220.0)
	var b: Vector2 = Vector2(arena.y if from_left else arena.x, ground_y - 4.0)
	lines.append(FutureAttacks.aim_beam(host, a, b, LATTICE_TELEGRAPH + 0.5, damage))
	return lines


## Siber-Ağ Kesintisi tamamlandıysa dron çağrısı %50 azalır
static func drone_count(host: Node) -> int:
	return ChapterState.scaled_count(host, Phases.BASE_DRONES)


static func turret_count(host: Node) -> int:
	return ChapterState.scaled_count(host, Phases.BASE_TURRETS)


## Oyuncunun arkasına/yanına ışınlanma hedefi (arena içinde)
static func blink_target(player_pos: Vector2, arena: Vector2, turn: int) -> float:
	var side: float = -1.0 if turn % 2 == 0 else 1.0
	return clampf(player_pos.x + side * 170.0, arena.x + 60.0, arena.y - 60.0)


## Omuz lazer topu: omuz yüksekliğinden arena boyunca yatay ışın (siper arkası güvenli)
static func shoulder_cannon(host: Node2D, origin: Vector2, facing: int, arena: Vector2, damage: int) -> Line2D:
	var end_x: float = arena.y if facing > 0 else arena.x
	return FutureAttacks.aim_beam(host, origin, Vector2(end_x, origin.y), 0.85, damage, Color(0.45, 0.6, 1.0, 1.0), 16.0)


## Zaman dondurma: oyuncunun etrafında kısa süreli güçlü yavaşlatma alanı
static func freeze_field(host: Node, player_pos: Vector2) -> Area2D:
	return FutureAttacks.slow_field(host, player_pos + Vector2(0.0, 4.0), "slow", Vector2(220.0, 170.0), 2.6, 0.25)


static func spawn_echo(host: Node, player: Node2D) -> Node2D:
	if not is_instance_valid(player):
		return null
	var echo: Node2D = EchoScript.new() as Node2D
	echo.set("player", player)
	var parent: Node = host.get_parent() if host.get_parent() else host
	parent.add_child(echo)
	echo.global_position = player.global_position
	return echo


## Çapraz çekirdek ışınları: çekirdekten zemine iki çapraz ışın (X)
static func cross_beams(host: Node2D, core: Vector2, arena: Vector2, ground_y: float, damage: int) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	var span: float = (arena.y - arena.x) * 0.45
	for dir: float in [-1.0, 1.0]:
		var a: Vector2 = core
		var b: Vector2 = Vector2(clampf(core.x + dir * span, arena.x, arena.y), ground_y - 2.0)
		lines.append(FutureAttacks.aim_beam(host, a, a + (b - a) * 1.15, 0.75, damage, Color(0.6, 0.85, 1.0, 1.0), 12.0))
	var top: Vector2 = Vector2(core.x, ground_y - 260.0)
	lines.append(FutureAttacks.aim_beam(host, top, Vector2(core.x, ground_y), 1.0, damage, Color(0.6, 0.85, 1.0, 1.0), 14.0))
	return lines
