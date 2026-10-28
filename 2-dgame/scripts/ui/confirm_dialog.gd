extends PanelContainer

## res://scripts/ui/confirm_dialog.gd
## Onay Penceresi (Yeni Oyun vb. durumlar için)

signal confirmed()
signal cancelled()

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var message_label: Label = $Margin/VBox/MessageLabel
@onready var confirm_button: Button = $Margin/VBox/BtnBox/ConfirmButton
@onready var cancel_button: Button = $Margin/VBox/BtnBox/CancelButton


func _ready() -> void:
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	hide()


func prompt(title_text: String, msg_text: String) -> void:
	if title_label:
		title_label.text = title_text
	if message_label:
		message_label.text = msg_text
	show()
	if cancel_button and cancel_button.is_inside_tree():
		cancel_button.grab_focus()


func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
