# -*- coding: utf-8 -*-
"""Bölüm 3 (Antik Mısır) ses asset üreticisi — Epic 2D-143.

Prosedürel sentez ile müzik, ambiyans ve SFX WAV dosyaları üretir. AudioManager,
assets/audio/sfx ve assets/audio/music altındaki dosyaları adlarıyla otomatik kaydeder:
  müzik:  egypt_theme, egypt_ambience, pharaoh_phase_1..3
  sfx:    sun_beam_charge, sun_beam_fire, mummy_rise, mummy_groan, sarcophagus_open,
          sarcophagus_break, soul_drain, steel_scream, sand_trap, cage_open, seal_unlock,
          heart_piece_extract

Çalıştırma (2-dgame klasöründen):  python tools/generate_egypt_audio.py
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
RNG = random.Random(2143)
# Hicaz makamı benzeri (Mısır/Doğu Akdeniz renk) dizi — A tabanlı
HIJAZ = [0, 1, 4, 5, 7, 8, 10, 12]


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def write(rel, samples):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.89 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))


def buf(seconds):
    return [0.0] * int(seconds * SR)


def env(i, n, a=0.01, r=0.2):
    t = i / SR
    total = n / SR
    if t < a:
        return t / a
    if t > total - r:
        return max(0.0, (total - t) / r)
    return 1.0


def add_tone(out, start, dur, freq, vol, kind="saw", vib=0.0, a=0.01, r=0.15):
    s0 = int(start * SR)
    n = int(dur * SR)
    ph = 0.0
    for i in range(n):
        if s0 + i >= len(out):
            break
        f = freq * (1.0 + vib * math.sin(2 * math.pi * 5.2 * i / SR))
        ph += f / SR
        x = ph % 1.0
        if kind == "saw":
            v = 2.0 * x - 1.0
        elif kind == "square":
            v = 1.0 if x < 0.5 else -1.0
        elif kind == "tri":
            v = 4.0 * abs(x - 0.5) - 1.0
        else:
            v = math.sin(2 * math.pi * x)
        out[s0 + i] += v * vol * env(i, n, a, r)


def add_drum(out, start, freq, vol, decay=0.18, noise=0.2):
    s0 = int(start * SR)
    n = int(decay * 3 * SR)
    for i in range(n):
        if s0 + i >= len(out):
            break
        t = i / SR
        e = math.exp(-t / decay)
        f = freq * (1.0 + 1.5 * math.exp(-t / 0.03))
        out[s0 + i] += (math.sin(2 * math.pi * f * t) + noise * (RNG.random() * 2 - 1)) * e * vol


def lowpass(samples, alpha):
    y = 0.0
    res = []
    for s in samples:
        y += alpha * (s - y)
        res.append(y)
    return res


def noise(seconds, vol=1.0):
    return [(RNG.random() * 2 - 1) * vol for _ in range(int(seconds * SR))]


def mix(a, b, gb=1.0):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0.0) + (b[i] if i < len(b) else 0.0) * gb for i in range(n)]


def loop_fade(samples, fade=0.05):
    """Döngü ekleminde tıklamayı önlemek için baş/son yumuşatma."""
    n = int(fade * SR)
    for i in range(n):
        k = i / n
        samples[i] *= k
        samples[-1 - i] *= k
    return samples


# ---------------------------------------------------------------------------
# Müzik
# ---------------------------------------------------------------------------
def theme(bpm, bars, root, intensity, seed):
    rng = random.Random(seed)
    beat = 60.0 / bpm
    out = buf(bars * 4 * beat)
    # Dron (ney/ud benzeri bas)
    add_tone(out, 0, bars * 4 * beat, midi(root - 12), 0.18, "tri", a=0.5, r=0.5)
    add_tone(out, 0, bars * 4 * beat, midi(root - 5), 0.07, "sine", a=0.5, r=0.5)
    # Darbuka ritmi: Düm-Tek-Tek-Düm-Tek
    pattern = [(0.0, "dum"), (1.0, "tek"), (1.5, "tek"), (2.0, "dum"), (3.0, "tek")]
    if intensity > 1:
        pattern += [(2.5, "tek"), (3.5, "tek")]
    for bar in range(bars):
        for pos, kind in pattern:
            t = (bar * 4 + pos) * beat
            if kind == "dum":
                add_drum(out, t, 70, 0.55, 0.16, 0.05)
            else:
                add_drum(out, t, 320, 0.22, 0.05, 0.8)
    # Melodi
    t = 0.0
    total = bars * 4 * beat
    deg = 0
    while t < total - beat:
        dur = rng.choice([0.5, 0.5, 1.0, 1.5]) * beat
        deg = max(0, min(len(HIJAZ) - 1, deg + rng.choice([-2, -1, -1, 1, 1, 2])))
        note = root + HIJAZ[deg] + (12 if intensity > 2 and rng.random() < 0.3 else 0)
        add_tone(out, t, dur * 0.95, midi(note), 0.16 + 0.03 * intensity, "saw", vib=0.006, a=0.02, r=0.08)
        t += dur
    if intensity >= 2:
        for bar in range(bars):
            add_tone(out, bar * 4 * beat, 4 * beat, midi(root - 24 + (5 if bar % 2 else 0)), 0.16, "square", a=0.05, r=0.1)
    return loop_fade(lowpass(out, 0.45))


def gen_music():
    write("assets/audio/music/egypt_theme.wav", theme(92, 8, 57, 1, 1))
    write("assets/audio/music/pharaoh_phase_1.wav", theme(112, 8, 57, 2, 2))
    write("assets/audio/music/pharaoh_phase_2.wav", theme(124, 8, 58, 2, 3))
    write("assets/audio/music/pharaoh_phase_3.wav", theme(138, 8, 59, 3, 4))
    # Kum fırtınası ambiyansı: filtrelenmiş gürültü + dalgalanan rüzgâr
    n = noise(12.0)
    wind = lowpass(n, 0.04)
    gust = [wind[i] * (0.6 + 0.4 * math.sin(2 * math.pi * 0.17 * i / SR) + 0.2 * math.sin(2 * math.pi * 0.41 * i / SR)) for i in range(len(wind))]
    hiss = lowpass(noise(12.0, 0.15), 0.5)
    write("assets/audio/music/egypt_ambience.wav", loop_fade(mix(gust, hiss), 0.3))


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------
def sweep(seconds, f0, f1, kind="sine", vol=1.0):
    out = buf(seconds)
    ph = 0.0
    n = len(out)
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        ph += f / SR
        x = ph % 1.0
        v = math.sin(2 * math.pi * x) if kind == "sine" else (2 * x - 1)
        out[i] = v * vol * env(i, n, 0.01, 0.1)
    return out


def gen_sfx():
    base = "assets/audio/sfx/"
    write(base + "sun_beam_charge.wav", mix(sweep(1.0, 200, 900, "saw", 0.5), lowpass(noise(1.0, 0.3), 0.3)))
    fire = sweep(0.9, 900, 500, "saw", 0.6)
    write(base + "sun_beam_fire.wav", mix(fire, [s * math.exp(-i / SR / 0.4) for i, s in enumerate(noise(0.9, 0.8))]))
    groan = buf(1.2)
    add_tone(groan, 0, 1.2, 82, 0.6, "saw", vib=0.04, a=0.2, r=0.4)
    write(base + "mummy_groan.wav", lowpass(groan, 0.1))
    rise = mix(lowpass(noise(1.4, 0.7), 0.08), lowpass(groan, 0.1), 0.6)
    write(base + "mummy_rise.wav", rise)
    stone = lowpass(noise(0.8, 1.0), 0.12)
    write(base + "sarcophagus_open.wav", [s * env(i, len(stone), 0.05, 0.3) for i, s in enumerate(stone)])
    brk = buf(0.7)
    for k in range(6):
        add_drum(brk, k * 0.08, 140 + k * 30, 0.6, 0.07, 1.0)
    write(base + "sarcophagus_break.wav", brk)
    drain = mix(sweep(1.4, 900, 180, "sine", 0.5), lowpass(noise(1.4, 0.4), 0.2))
    write(base + "soul_drain.wav", drain)
    # Çeliğin çığlığı: metalik inharmonik kısmi sesler + tiz sürtünme
    scream = buf(1.6)
    for f, v in ((1320, 0.3), (1870, 0.22), (2610, 0.18), (3480, 0.12)):
        add_tone(scream, 0, 1.6, f, v, "sine", vib=0.02, a=0.005, r=0.9)
    write(base + "steel_scream.wav", mix(scream, lowpass(noise(1.6, 0.25), 0.7)))
    sand = lowpass(noise(1.0, 0.8), 0.06)
    write(base + "sand_trap.wav", [s * env(i, len(sand), 0.1, 0.4) for i, s in enumerate(sand)])
    cage = buf(0.6)
    add_tone(cage, 0, 0.6, 420, 0.4, "square", a=0.001, r=0.4)
    add_tone(cage, 0.12, 0.45, 640, 0.3, "square", a=0.001, r=0.3)
    write(base + "cage_open.wav", lowpass(cage, 0.3))
    seal = buf(1.2)
    for k, f in enumerate((523, 659, 784, 1046)):
        add_tone(seal, k * 0.12, 0.8, f, 0.3, "sine", a=0.005, r=0.5)
    write(base + "seal_unlock.wav", seal)
    heart = mix(sweep(2.0, 120, 1200, "sine", 0.5), seal, 0.8)
    write(base + "heart_piece_extract.wav", heart)


if __name__ == "__main__":
    gen_music()
    gen_sfx()
    print("Egypt audio generated.")
