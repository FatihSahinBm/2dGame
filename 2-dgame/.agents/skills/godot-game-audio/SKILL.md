---
name: godot-game-audio
description: Comprehensive skill and toolkit for in-game sound design, procedural SFX generation, musical layering, dynamic audio mixing, and 2D positional audio in Godot 4. Use when designing, synthesizing, tuning, or debugging sound effects, procedural waveforms, and audio systems in Godot.
---

# Godot 4 Game Audio & Procedural Sound Design Skill

This skill provides complete guidelines, procedural synthesis algorithms, sound design patterns, and debugging strategies for Godot 4 games.

---

## 1. Core Principles of Game Audio

1. **Anti-Fatigue Variations**: Never play the exact same sample repeatedly. Always randomize pitch (`pitch_scale = randf_range(0.92, 1.08)`) and volume (`volume_db += randf_range(-1.5, 1.5)`).
2. **Audio Bus Hierarchy**:
   - `Master` -> `Music` (BGM, dynamic layers)
   - `Master` -> `SFX` (Combat, impacts, traps)
   - `Master` -> `Ambient` (Weather, wind, campfires)
   - `Master` -> `UI` (Menus, inventory, codex, notifications)
3. **Voice Pooling & Concurrency Capping**: Limit concurrent instances of identical sounds (e.g. max 3 bullet/slash sounds simultaneously) to avoid ear-fatigue and digital clipping.
4. **Zero-Clicking & Envelopes**: Every procedural sound must have attack and release ramps (minimum 2-5ms) to prevent DC offset clicks.

---

## 2. Procedural Audio Synthesis in Godot 4 (GDScript)

Godot can generate procedural audio samples into `AudioStreamWAV` buffers dynamically without external WAV/OGG files.

### 2.1 Waveform Generation Formulas
Given sample rate $R = 22050$ or $44100$, frequency $f$, time $t$:
- **Sine Wave**: $\sin(2\pi \cdot f \cdot t)$
- **Square Wave**: $\text{sign}(\sin(2\pi \cdot f \cdot t))$
- **Triangle Wave**: $\frac{2}{\pi} \arcsin(\sin(2\pi \cdot f \cdot t))$
- **Sawtooth Wave**: $2 (f \cdot t - \lfloor f \cdot t + 0.5 \rfloor)$
- **White Noise**: $\text{randf\_range}(-1.0, 1.0)$
- **Pink/Filtered Noise**: $y[n] = 0.8 \cdot y[n-1] + 0.2 \cdot \text{noise}$

### 2.2 Reusable Procedural Audio Generator Pattern

```gdscript
static func generate_procedural_wav(duration: float, sample_rate: int, sample_generator: Callable) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	
	var total_samples := int(duration * sample_rate)
	var byte_array := PackedByteArray()
	byte_array.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var norm_pos: float = float(i) / float(total_samples)
		var sample_val: float = sample_generator.call(t, norm_pos)
		sample_val = clampf(sample_val, -1.0, 1.0)
		var int_val: int = clampi(int(sample_val * 32767.0), -32768, 32767)
		byte_array.encode_s16(i * 2, int_val)
		
	wav.data = byte_array
	return wav
```

---

## 3. Procedural Sound Recipes

### 3.1 Sword Slash / Blade Whoosh (Combat)
- **Profile**: Modulated noise burst + downward pitch sweep.
- **Duration**: 0.15s – 0.22s.
- **Envelope**: Instant attack (2ms), quick exponential decay.
```gdscript
# Slash whoosh recipe
var noise = randf_range(-1.0, 1.0)
var sweep_freq = lerpf(800.0, 200.0, norm_pos * norm_pos)
var tone = sin(2.0 * PI * sweep_freq * t)
var env = (1.0 - norm_pos) * (1.0 - norm_pos)
return (noise * 0.7 + tone * 0.3) * env
```

### 3.2 Blunt Impact / Body Hit
- **Profile**: Low-frequency sine thud (120Hz -> 40Hz) + short high-frequency noise transient.
- **Duration**: 0.18s – 0.25s.
```gdscript
# Impact thud recipe
var freq = lerpf(120.0, 40.0, norm_pos)
var thud = sin(2.0 * PI * freq * t)
var click = randf_range(-1.0, 1.0) if norm_pos < 0.08 else 0.0
var env = exp(-norm_pos * 8.0)
return (thud * 0.8 + click * 0.4) * env
```

### 3.3 Boss Roar / Monstrous Scream (Vlad Vampire/Werewolf)
- **Profile**: Detuned sawtooth waves (55Hz and 58Hz) + distorted low-frequency noise rumble + tremolo modulation.
- **Duration**: 0.8s – 1.4s.
```gdscript
# Boss roar recipe
var tremolo = 0.7 + 0.3 * sin(2.0 * PI * 18.0 * t)
var saw1 = 2.0 * (fposmod(65.0 * t, 1.0) - 0.5)
var saw2 = 2.0 * (fposmod(68.5 * t, 1.0) - 0.5)
var roar = tanh((saw1 + saw2 + randf_range(-0.4, 0.4)) * 1.5)
var env = sin(norm_pos * PI) * tremolo
return roar * env
```

### 3.4 Church / Great Bell Toll (Acoustic Stun)
- **Profile**: Additive synthesis with inharmonic partials (fundamental, tierce, quint, octave) + long metallic decay.
- **Duration**: 2.5s – 4.0s.
```gdscript
# Bell toll recipe
var f0 = 220.0 # Fundamental (A3)
var partials = [1.0, 1.2, 1.5, 2.0, 2.76, 4.07]
var weights = [1.0, 0.6, 0.4, 0.3, 0.2, 0.1]
var decays = [3.0, 4.0, 4.5, 5.0, 6.0, 7.5]
var sample = 0.0
for p in range(partials.size()):
    sample += weights[p] * sin(2.0 * PI * f0 * partials[p] * t) * exp(-norm_pos * decays[p])
return sample * 0.5
```

### 3.5 UI Click / Codex / Inventory Page Turn
- **Profile**: High frequency delicate transient chirp or parchment friction.
```gdscript
# Codex page flip / parchment friction
var friction = randf_range(-0.6, 0.6) * exp(-norm_pos * 12.0)
var chirp = sin(2.0 * PI * lerpf(2400.0, 1200.0, norm_pos) * t) * exp(-norm_pos * 16.0)
return friction * 0.6 + chirp * 0.4
```

---

## 4. 2D Positional Audio Best Practices

1. Use `AudioStreamPlayer2D` with:
   - `attenuation = 1.0` (natural inverse distance falloff).
   - `max_distance = 600.0` (avoids processing off-screen sounds).
   - `bus = "SFX"` or `"Ambient"`.
2. Connect to node `tree_exited` to automatically stop playback and prevent memory leaks.
3. Keep positional emitters parented to their in-world source (e.g. traps, campfires, enemies).

---

## 5. Audio Verification & Testing Protocol

- Verify that procedural audio generation doesn't block the main thread.
- Test that all audio keys exist in `AudioManager` or return null gracefully.
- Test that multiple rapid triggers don't exceed pool limits or crash the sound bus.

