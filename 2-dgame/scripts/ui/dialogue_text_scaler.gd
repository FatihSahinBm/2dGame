extends RefCounted

## res://scripts/ui/dialogue_text_scaler.gd
## Diyalog metni boyutu ayarını etikete uygular (Story 2D-118).
## Metnin kesilmemesi için: istenen boyut etiketin alanına sığmıyorsa, sığan en büyük boyuta
## (taban boyutun altına inmeden) kademeli olarak düşülür.

const META_BASE_SIZE: StringName = &"dialogue_base_font_size"


## Etiketin yazı boyutunu ayarlar ve uygulanan boyutu döndürür.
static func apply(label: Label, text_scale: float, full_text: String) -> int:
	if label == null:
		return 0
	if label.label_settings == null:
		label.label_settings = LabelSettings.new()
	if not label.has_meta(META_BASE_SIZE):
		# Paylaşılan kaynağı değiştirmemek için kopyası kullanılır
		label.label_settings = label.label_settings.duplicate() as LabelSettings
		label.set_meta(META_BASE_SIZE, label.label_settings.font_size)
	var base_size: int = int(label.get_meta(META_BASE_SIZE))
	var wanted: int = maxi(base_size, int(round(float(base_size) * maxf(text_scale, 1.0))))
	var chosen: int = fit_font_size(label, base_size, wanted, full_text)
	label.label_settings.font_size = chosen
	return chosen


## wanted'dan base_size'a doğru inerek metnin etiket alanına sığdığı ilk boyutu bulur.
static func fit_font_size(label: Label, base_size: int, wanted: int, full_text: String) -> int:
	var font: Font = label.label_settings.font if label.label_settings and label.label_settings.font else label.get_theme_font("font")
	var area: Vector2 = label.size
	if font == null or area.x <= 0.0 or area.y <= 0.0 or full_text.is_empty():
		return wanted
	var size: int = wanted
	while size > base_size:
		var needed: Vector2 = font.get_multiline_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, area.x, size)
		if needed.y <= area.y:
			return size
		size -= 1
	return base_size
