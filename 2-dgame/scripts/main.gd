extends Node2D

@onready var player: Node2D = $Player
@onready var sword_status_label: Label = $UI/MarginContainer/VBoxContainer/SwordStatus

func _ready() -> void:
	if player and sword_status_label:
		player.sword_state_changed.connect(_on_player_sword_state_changed)
		_on_player_sword_state_changed(player.has_sword)

func _on_player_sword_state_changed(has_sword: bool) -> void:
	if not sword_status_label:
		return
	if has_sword:
		sword_status_label.text = "🗡️ Kılıç Kuşanıldı: [Sol Tık] Savurma | [Sağ Tık] Güçlü Vuruş | [G] Kılıcı At"
		sword_status_label.modulate = Color(0.4, 0.95, 0.55)
	else:
		sword_status_label.text = "✋ Silahsız: Kılıcı almak için yanına gidip [E] tuşuna basın"
		sword_status_label.modulate = Color(0.95, 0.75, 0.35)
