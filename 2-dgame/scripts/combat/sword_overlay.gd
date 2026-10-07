extends Sprite2D

## res://scripts/combat/sword_overlay.gd
## Çalışma zamanı kılıç overlay'i. Ebeveyn AnimatedSprite2D'nin her karesinde,
## res://tools/knight_hand_anchors.json tablosundaki el noktasına ve o kareye özel
## (yalnızca 0/45/90/135/-45/-90 derece) önceden çizilmiş kılıç dokusuna geçer.
## Döndürme yapılmaz; her açı ayrı PNG'dir. Sola dönüş, ebeveynin (Visual) scale.x = -1
## yansımasıyla otomatik ve piksel hizalı gelir.

const ANCHORS_PATH := "res://tools/knight_hand_anchors.json"
const SWORD_DIR := "res://assets/items/sword_overlay/"

## Bu animasyonlarda kılıç zaten karelerin içinde çizili; overlay gizlenir.
const HIDDEN_ANIMS: Array[StringName] = [
	&"attack", &"attack_combo", &"heavy_attack", &"crouch_attack", &"draw_sword",
]

var _drawn: bool = false
var _anims: Dictionary = {}       # anim adı -> Array[Dictionary]
var _textures: Dictionary = {}    # açı (int) -> Texture2D
var _pivots: Dictionary = {}      # açı (int) -> Vector2
var _sprite: AnimatedSprite2D


func _ready() -> void:
	centered = false
	visible = false
	_sprite = get_parent() as AnimatedSprite2D
	if _sprite == null:
		push_error("SwordOverlay bir AnimatedSprite2D'nin çocuğu olmalı.")
		return
	_load_table()
	_sprite.frame_changed.connect(_refresh)
	_sprite.animation_changed.connect(_refresh)
	_refresh()


## Oyuncu: kılıç elde VE çekili iken true.
func set_drawn(value: bool) -> void:
	_drawn = value
	_refresh()


func _load_table() -> void:
	var text := FileAccess.get_file_as_string(ANCHORS_PATH)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SwordOverlay: el noktası tablosu okunamadı: %s" % ANCHORS_PATH)
		return
	_anims = data.get("animations", {})
	var meta: Dictionary = data.get("sword_meta", {})
	for key: String in meta:
		var angle := int(key)
		var entry: Dictionary = meta[key]
		var tex := load(SWORD_DIR + String(entry["file"])) as Texture2D
		if tex == null:
			push_error("SwordOverlay: doku yüklenemedi: %s" % entry["file"])
			continue
		_textures[angle] = tex
		var piv: Array = entry["pivot"]
		_pivots[angle] = Vector2(piv[0], piv[1])


func _refresh() -> void:
	if _sprite == null:
		return
	var anim: StringName = _sprite.animation
	if not _drawn or anim in HIDDEN_ANIMS or not _anims.has(String(anim)):
		visible = false
		return
	var frames: Array = _anims[String(anim)]
	var idx := _sprite.frame
	if idx < 0 or idx >= frames.size():
		visible = false
		return
	var fr: Dictionary = frames[idx]
	var angle := int(fr["angle"])
	if not bool(fr.get("visible", true)) or not _textures.has(angle):
		visible = false
		return

	var frame_tex := _sprite.sprite_frames.get_frame_texture(anim, idx)
	var frame_size := frame_tex.get_size() if frame_tex else Vector2(120, 80)
	var hand := Vector2(fr["hand_x"], fr["hand_y"])
	if _sprite.flip_h:
		hand.x = frame_size.x - 1.0 - hand.x
	# Kare yerel koordinatı -> AnimatedSprite2D yerel koordinatı
	var origin := _sprite.offset - (frame_size * 0.5 if _sprite.centered else Vector2.ZERO)
	texture = _textures[angle]
	offset = -_pivots[angle]
	flip_h = _sprite.flip_h
	if flip_h:
		offset.x = -(texture.get_size().x - 1.0 - _pivots[angle].x)
	position = (origin + hand).round()
	visible = true
