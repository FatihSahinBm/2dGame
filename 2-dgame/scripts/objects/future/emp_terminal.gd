class_name EmpTerminal
extends EgyptInteractable

## res://scripts/objects/future/emp_terminal.gd
## EMP / kontrol terminali (Epic 2D-158) — güç yönlendirme ve hack bulmacaları.
##   mode "power_off": [E] ile hacklenir; bağlı tuzakların (lazer kapısı, tarama lazeri,
##                     plazma kanalı, pres) gücünü kalıcı keser. Hack durumu kalıcıdır.
##   mode "reverse":   [E] her kullanımda bağlı konveyör bantlarının yönünü çevirir.
## requires_terminals: hepsi hacklenmeden bu terminal çalışmaz (sıralı güç yönlendirme).

signal hacked(terminal: EmpTerminal)
signal toggled(terminal: EmpTerminal)

const FutureFx = preload("res://scripts/effects/future_fx.gd")
const TEX_ON: String = "res://assets/objects/future/obj_emp_terminal.png"
const TEX_OFF: String = "res://assets/objects/future/obj_emp_terminal_off.png"

@export_enum("power_off", "reverse") var mode: String = "power_off"
@export var linked_paths: Array[NodePath] = []
@export var requires_terminals: Array[NodePath] = []

var is_hacked: bool = false
var _sprite: Sprite2D = null


func _interactable_ready() -> void:
	prompt_key = "PROMPT_FUT_TERMINAL" if mode == "power_off" else "PROMPT_FUT_CONVEYOR"
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if mode == "power_off" and is_persisted("hacked"):
		call_deferred("_apply_hacked", false)


func _on_interact() -> void:
	if not prerequisites_met():
		interaction_requested.emit(self)
		return
	if mode == "reverse":
		for target: Node in get_linked():
			if target.has_method("reverse"):
				target.reverse()
		FutureFx.sfx(self, "item_equip", global_position)
		toggled.emit(self)
	elif not is_hacked:
		persist("hacked")
		_apply_hacked(true)
	interaction_requested.emit(self)


func prerequisites_met() -> bool:
	for path: NodePath in requires_terminals:
		var t: Node = get_node_or_null(path)
		if t is EmpTerminal and not (t as EmpTerminal).is_hacked:
			return false
	return true


func get_linked() -> Array[Node]:
	var out: Array[Node] = []
	for path: NodePath in linked_paths:
		var n: Node = get_node_or_null(path)
		if n:
			out.append(n)
	return out


func _apply_hacked(with_fx: bool) -> void:
	is_hacked = true
	set_interaction_enabled(false)
	for target: Node in get_linked():
		if target.has_method("set_powered"):
			target.set_powered(false)
	if _sprite and ResourceLoader.exists(TEX_OFF):
		_sprite.texture = load(TEX_OFF) as Texture2D
	if with_fx:
		FutureFx.play_vfx(get_parent(), FutureFx.VFX_EMP, global_position + Vector2(0.0, -30.0), 0.6)
		FutureFx.sfx(self, "sfx_emp_detonate", global_position, -6.0)
	hacked.emit(self)
