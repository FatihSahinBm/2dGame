class_name FutureResonanceDoor
extends OccultSeal

## res://scripts/objects/future/future_resonance_door.gd
## Zaman mühürlü güvenlik kapısı (Epic 2D-158): üzerinde kılıçtaki kadim damga vardır.
## Bölüm 1'de açılan Kalp Rezonansı (heart_resonance) yeteneği varsa [E] ile açılır ve bağlı
## bariyeri (kapı gövdesi) kaldırır; yoksa kilitli kalır. Açık durum kalıcıdır (OccultSeal kuralı).


func _interactable_ready() -> void:
	super._interactable_ready()
	prompt_key = "PROMPT_FUT_SEAL_DOOR"
