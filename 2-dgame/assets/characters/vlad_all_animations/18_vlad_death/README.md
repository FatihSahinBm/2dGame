# 💀 Vlad Final Death & Multi-Form Defeat Architecture

Bu belge, oyun motorunda (Godot / Unity) Vlad the Impaler boss dövüşünde karakterin yenilgiye uğraması ve ölüm animasyonu akışını tanımlar.

---

## 🎮 Çoklu Formlarda Ölüm Akışı (Multi-Form Boss Death Sequence)

Boss herhangi bir formdayken (**Vampir Lordu**, **Kurt Adam** veya **Yarasa**) canı 0'a indiğinde doğrudan şu zincirleme akış tetiklenir:

1. **Kan Dumanı Patlaması (`vfx_blood_smoke_burst`):**
   - Boss'un mevcut konumunda (`x=640, y=680` zemin basamağında) `vfx_blood_smoke_burst` oynatılır (Z-Index = 10, karakterin üst katmanı).
2. **Karakter Formunun Sıfırlanması (Gizli Geçiş - Kare 42):**
   - Dumanın merkezi %100 örttüğü **42. karede**, boss'un aktif formu anında **Normal İnsan Formuna (Voivode Vlad)** çevrilir:
   ```gdscript
   # Godot Örneği:
   func _on_vfx_smoke_frame_changed():
       if vfx_smoke.frame == 42:
           boss_sprite.visible = true
           boss_sprite.play("vlad_death")
   ```
3. **Nihai Ölüm Sekansı (`18_vlad_death`):**
   - Duman dağılırken normal Voyvoda Vlad bedeni ortaya çıkar:
     - Mızrağını yere düşürür, göğsünü tutar.
     - Asil bir trajediyle zemin hattında (`y=680`) tek dizi üzerine çöker.
     - Zırhı akkor küllere ve minik karanlık yarasalara dönüşerek havaya dağılır.
     - Yerde yalnızca yere düşen mızrak ve taç kalır.

---

## 📂 İlgili Varlıklar (Assets)
- **Modüler Duman VFX:** `vlad_all_animations/vfx_blood_smoke_burst/`
- **Ölüm Animasyonu:** `vlad_all_animations/18_vlad_death/`
- **Tüm Form Hasar Alma:**
  - Normal Form: `17_vlad_hurt/`
  - Vampir Formu: `19_vampire_hurt/`
  - Kurt Adam Formu: `20_werewolf_hurt/`
  - Yarasa Formu: `21_bat_hurt/`
