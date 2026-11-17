# -*- coding: utf-8 -*-
"""Bölüm 4 (2. Dünya Savaşı) ses asset üreticisi — Epic 2D-144.

Prosedürel sentezle müzik, ambiyans ve SFX WAV dosyaları üretir. AudioManager,
assets/audio/sfx ve assets/audio/music altındaki dosyaları adlarıyla otomatik kaydeder:
  müzik:  ww2_theme, ww2_ambience, commander_phase_1..3 (endüstriyel/okült boss müziği)
  sfx:    artillery_whistle, artillery_blast, train_rail_loop, train_car_clank, radio_static,
          flamethrower_burst, gas_hiss, relay_switch, searchlight_alarm, mine_click,
          grenade_blast, flare_ignite, turret_fire, sniper_shot, shock_wave, occult_beam,
          mage_vengeance_whisper, energy_tube_break
Mısır üreticisinin sentez yardımcılarını yeniden kullanır.

Çalıştırma (2-dgame klasöründen):  python tools/generate_ww2_audio.py
"""
import math
import random

import generate_egypt_audio as ea
from generate_egypt_audio import SR, add_drum, add_tone, buf, loop_fade, lowpass, midi, mix, noise, write

RNG = random.Random(2144)
ea.RNG = RNG
# Frigya + kromatik renk: soğuk, endüstriyel minör
PHRYG = [0, 1, 3, 5, 7, 8, 10, 12]


def sweep(seconds, f0, f1, vol=1.0, kind="sine"):
    out = []
    ph = 0.0
    n = int(seconds * SR)
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        ph += f / SR
        x = ph % 1.0
        v = math.sin(2 * math.pi * x) if kind == "sine" else (2.0 * x - 1.0)
        out.append(v * vol)
    return out


def decay_env(samples, tau):
    return [s * math.exp(-(i / SR) / tau) for i, s in enumerate(samples)]


def anvil(out, start, vol):
    """Endüstriyel metal vuruşu (inharmonik kısmi tonlar)."""
    s0 = int(start * SR)
    n = int(0.5 * SR)
    for i in range(n):
        if s0 + i >= len(out):
            break
        t = i / SR
        e = math.exp(-t / 0.09)
        v = sum(math.sin(2 * math.pi * f * t) for f in (310.0, 523.0, 891.0, 1312.0)) / 4.0
        out[s0 + i] += v * e * vol


def theme(bpm, bars, root, intensity, seed, occult=False):
    rng = random.Random(seed)
    beat = 60.0 / bpm
    out = buf(bars * 4 * beat)
    for bar in range(bars):
        t0 = bar * 4 * beat
        chord_root = root + [0, 1, -2, 0][bar % 4]
        add_tone(out, t0, 4 * beat, midi(chord_root - 12), 0.22, "saw", a=0.3, r=0.6)
        add_tone(out, t0, 4 * beat, midi(chord_root - 5), 0.1, "square", a=0.4, r=0.6)
        for b in range(4):
            add_drum(out, t0 + b * beat, 55, 0.5 + 0.15 * intensity, decay=0.16, noise=0.25)
            if intensity >= 2 and b % 2 == 1:
                anvil(out, t0 + b * beat + beat * 0.5, 0.18 + 0.06 * intensity)
            if intensity >= 3:
                add_drum(out, t0 + b * beat + beat * 0.25, 80, 0.25, decay=0.07, noise=0.5)
        steps = 4 + intensity * 2
        for s in range(steps):
            deg = PHRYG[rng.randint(0, len(PHRYG) - 1)]
            add_tone(out, t0 + s * (4 * beat / steps), 4 * beat / steps * 0.9, midi(root + 12 + deg), 0.08 + 0.02 * intensity,
                     "sine" if occult else "tri", vib=0.012 if occult else 0.0, a=0.02, r=0.1)
        if occult:
            add_tone(out, t0, 4 * beat, midi(root + 24 + 1), 0.04, "sine", vib=0.03, a=1.0, r=1.0)
    return loop_fade(lowpass(out, 0.5))


def gen_music():
    write("assets/audio/music/ww2_theme.wav", theme(84, 8, 45, 1, 1))
    amb = lowpass(noise(12.0, 0.25), 0.03)
    for k in range(9):
        t = RNG.uniform(0.5, 11.0)
        add_drum(amb, t, 38, 0.6, decay=0.6, noise=0.6)  # uzak topçu gümbürtüsü
    for k in range(5):
        add_tone(amb, RNG.uniform(0, 11), 1.4, RNG.uniform(600, 900), 0.03, "sine", vib=0.05, a=0.4, r=0.6)  # uzak siren
    write("assets/audio/music/ww2_ambience.wav", loop_fade(amb, 0.3))
    write("assets/audio/music/commander_phase_1.wav", theme(108, 8, 43, 2, 11))
    write("assets/audio/music/commander_phase_2.wav", theme(122, 8, 44, 3, 12))
    write("assets/audio/music/commander_phase_3.wav", theme(136, 8, 45, 3, 13, occult=True))


def gen_sfx():
    sfx = "assets/audio/sfx/"
    write(sfx + "artillery_whistle.wav", [s * (0.3 + 0.7 * i / (1.4 * SR)) for i, s in enumerate(sweep(1.4, 1400, 500, 0.6))])
    blast = decay_env(lowpass(noise(1.4, 1.0), 0.12), 0.35)
    add_drum(blast, 0.0, 42, 1.2, decay=0.4, noise=0.5)
    write(sfx + "artillery_blast.wav", blast)
    rail = buf(2.0)
    for k in range(8):
        anvil(rail, k * 0.25, 0.25)
        add_drum(rail, k * 0.25 + 0.06, 70, 0.35, decay=0.05, noise=0.6)
    write(sfx + "train_rail_loop.wav", loop_fade(mix(rail, lowpass(noise(2.0, 0.3), 0.08))))
    clank = buf(0.6)
    anvil(clank, 0.0, 0.8)
    anvil(clank, 0.12, 0.5)
    write(sfx + "train_car_clank.wav", clank)
    static = [s * (0.6 + 0.4 * math.sin(i / SR * 2 * math.pi * 7.0)) for i, s in enumerate(noise(1.2, 0.7))]
    add_tone(static, 0.2, 0.6, 880, 0.12, "square", vib=0.2)
    write(sfx + "radio_static.wav", static)
    flame = mix(lowpass(noise(1.0, 1.0), 0.25), lowpass(noise(1.0, 0.6), 0.05))
    write(sfx + "flamethrower_burst.wav", [s * min(1.0, i / (0.05 * SR)) * (1.0 - i / len(flame)) ** 0.5 for i, s in enumerate(flame)])
    hiss = [s * (1.0 - i / (1.6 * SR)) for i, s in enumerate(noise(1.6, 0.6))]
    write(sfx + "gas_hiss.wav", hiss)
    sw = buf(0.35)
    add_drum(sw, 0.0, 400, 0.6, decay=0.02, noise=0.8)
    anvil(sw, 0.05, 0.4)
    add_tone(sw, 0.1, 0.2, 120, 0.3, "square")
    write(sfx + "relay_switch.wav", sw)
    alarm = buf(1.6)
    for k in range(4):
        add_tone(alarm, k * 0.4, 0.38, 760 if k % 2 == 0 else 620, 0.4, "square", a=0.01, r=0.05)
    write(sfx + "searchlight_alarm.wav", alarm)
    click = buf(0.25)
    add_drum(click, 0.0, 1800, 0.5, decay=0.01, noise=0.9)
    add_tone(click, 0.05, 0.15, 1500, 0.2, "square")
    write(sfx + "mine_click.wav", click)
    gb = decay_env(lowpass(noise(1.0, 1.0), 0.18), 0.25)
    add_drum(gb, 0.0, 55, 1.0, decay=0.3, noise=0.4)
    write(sfx + "grenade_blast.wav", gb)
    flare = mix(sweep(0.8, 300, 2400, 0.3), lowpass(noise(0.8, 0.6), 0.4))
    write(sfx + "flare_ignite.wav", [s * (1.0 - i / len(flare)) for i, s in enumerate(flare)])
    tf = buf(0.6)
    for k in range(5):
        add_drum(tf, k * 0.11, 160, 0.7, decay=0.04, noise=0.8)
    write(sfx + "turret_fire.wav", tf)
    sn = decay_env(lowpass(noise(0.9, 1.0), 0.5), 0.12)
    add_drum(sn, 0.0, 90, 0.9, decay=0.08, noise=0.3)
    write(sfx + "sniper_shot.wav", sn)
    sh = decay_env(mix(sweep(1.0, 90, 30, 0.9), lowpass(noise(1.0, 0.8), 0.06)), 0.4)
    write(sfx + "shock_wave.wav", sh)
    ob = buf(1.4)
    add_tone(ob, 0.0, 1.4, 220, 0.3, "saw", vib=0.04, a=0.3, r=0.3)
    add_tone(ob, 0.0, 1.4, 233, 0.25, "saw", vib=0.05, a=0.3, r=0.3)
    add_tone(ob, 0.2, 1.2, 880, 0.12, "sine", vib=0.08, a=0.3, r=0.3)
    write(sfx + "occult_beam.wav", ob)
    wh = mix(lowpass(noise(2.2, 0.5), 0.15), buf(2.2))
    add_tone(wh, 0.2, 1.8, 165, 0.12, "sine", vib=0.06, a=0.6, r=0.8)
    add_tone(wh, 0.4, 1.6, 196, 0.08, "sine", vib=0.07, a=0.6, r=0.8)
    write(sfx + "mage_vengeance_whisper.wav", [s * math.sin(math.pi * i / len(wh)) for i, s in enumerate(wh)])
    tb = decay_env(mix(noise(0.8, 0.8), sweep(0.8, 2400, 900, 0.3)), 0.2)
    anvil(tb, 0.0, 0.5)
    write(sfx + "energy_tube_break.wav", tb)


def main():
    gen_music()
    gen_sfx()
    print("2. Dünya Savaşı sesleri üretildi.")


if __name__ == "__main__":
    main()
