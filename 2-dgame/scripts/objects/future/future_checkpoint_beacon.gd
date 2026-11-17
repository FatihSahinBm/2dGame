class_name FutureCheckpointBeacon
extends CampfireCheckpoint

## res://scripts/objects/future/future_checkpoint_beacon.gd
## Bölüm 5 kontrol noktası işareti (Epic 2D-158): kamp ateşi kontrol noktasının tüm davranışı
## (dinlenme, can/iksir tazeleme, SaveManager.set_checkpoint, düşman yeniden doğuşu) aynen
## kullanılır; yalnızca görsel (neon işaret direği) ve istem metinleri gelecek çağına uyarlanır.


func _update_prompt_text() -> void:
	if not prompt_label:
		return
	var raw_txt: String = tr("PROMPT_FUT_BEACON_REST") if is_lit else tr("PROMPT_FUT_BEACON_ACTIVATE")
	var input_mgr: Node = get_node_or_null("/root/InputControllerManager")
	if input_mgr and input_mgr.has_method("format_prompt"):
		prompt_label.text = input_mgr.format_prompt(raw_txt)
	else:
		prompt_label.text = raw_txt
	prompt_label.visible = (_player_in_range != null)


## Ateş sesi yerine kısa bir neon uğultusu
func _start_fire_audio() -> void:
	pass
