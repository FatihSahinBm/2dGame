extends CanvasLayer

## res://scripts/ui/combat_hud.gd
## Combat test sahnesi için bağımsız HUD

@onready var status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/WeaponStatus
@onready var hint_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ControlsHint

func _ready() -> void:
	update_weapon_status(false)

func update_weapon_status(has_weapon: bool) -> void:
	if not status_label:
		return

	if has_weapon:
		status_label.text = tr("COMBAT_HUD_ARMED")
		status_label.modulate = Color(0.4, 0.95, 0.55)
	else:
		status_label.text = tr("COMBAT_HUD_UNARMED")
		status_label.modulate = Color(1.0, 0.8, 0.3)
