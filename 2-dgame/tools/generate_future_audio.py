# -*- coding: utf-8 -*-
"""Bölüm 5 (Distopik Gelecek) müzik ve ses efekti üreticisi — Epic 2D-158.

numpy ile sentezlenir (synthwave/distopik ambiyans, fabrika gerilimi, 3 fazlı elektronik-orkestral
boss müziği, 8 SFX). Müzikler ffmpeg ile .ogg (Vorbis) olarak kodlanır. AudioManager,
assets/audio/sfx ve assets/audio/music klasörlerini dosya adıyla otomatik kaydeder; ayrıca
boss fazları için ai_lord_phase_1..3 parçaları yazılır (get_boss_phase_track_key ile eşleşir).

Çalıştırma (repo kökünden):  py -3.10 2-dgame/tools/generate_future_audio.py
Gereksinim: numpy, ffmpeg (PATH).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MUSIC = os.path.join(ROOT, "assets", "audio", "music")
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
RNG = np.random.default_rng(158)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def osc(freq, sec, kind="saw", detune=0.0):
    t = t_axis(sec)
    ph = (freq * (1 + detune)) * t
    if kind == "saw":
        return 2 * (ph % 1) - 1
    if kind == "square":
        return np.sign(np.sin(2 * np.pi * ph))
    if kind == "tri":
        return 2 * np.abs(2 * (ph % 1) - 1) - 1
    return np.sin(2 * np.pi * ph)


def lp_fast(x, cutoff):
    """FFT tabanlı alçak geçiren filtre (uzun müzik tamponları için)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1.0 / (1.0 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def env(sec, a=0.01, d=0.1, s=0.7, r=0.1):
    n = int(SR * sec)
    e = np.full(n, s, np.float64)
    na, nd, nr = int(SR * a), int(SR * d), int(SR * r)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nd:
        e[na:na + nd] = np.linspace(1, s, len(e[na:na + nd]))
    if nr:
        e[-nr:] *= np.linspace(1, 0, len(e[-nr:]))
    return e


def place(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]


def noise(sec):
    return RNG.uniform(-1, 1, int(SR * sec))


def kick(sec=0.35):
    t = t_axis(sec)
    f = 50 + 120 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def snare(sec=0.25):
    t = t_axis(sec)
    return (lp_fast(noise(sec), 6000) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 18)


def hat(sec=0.06):
    t = t_axis(sec)
    n = noise(sec)
    return (n - lp_fast(n, 7000)) * np.exp(-t * 60)


def metal_hit(sec=0.6, base=310):
    t = t_axis(sec)
    s = sum(np.sin(2 * np.pi * base * r * t) for r in (1.0, 2.76, 5.4, 8.93)) * np.exp(-t * 7)
    return s * 0.3 + lp_fast(noise(sec), 3000) * np.exp(-t * 25) * 0.4


def pad(freqs, sec, cutoff=1800, det=0.006):
    s = sum(osc(f, sec, "saw", d) for f in freqs for d in (-det, 0, det))
    s = lp_fast(s / (3 * len(freqs)), cutoff)
    return s * env(sec, 0.6, 0.2, 0.8, 0.6)


def reverb(x, decay=0.45, taps=(0.031, 0.047, 0.071, 0.113, 0.167)):
    y = x.copy()
    for i, d in enumerate(taps):
        n = int(SR * d)
        y[n:] += x[:-n] * decay ** (i + 1)
    return y


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(normalize(x), -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, x):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "m.wav")
        write_wav(wav, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", path], check=True)


# ---------------------------------------------------------------------------
# Müzik
# ---------------------------------------------------------------------------
PROG = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]  # Am F C G


def track_neon_ruins(bars=16, bpm=88):
    beat = 60.0 / bpm
    bar = beat * 4
    out = np.zeros(int(SR * bar * bars) + SR)
    for b in range(bars):
        chord = PROG[b % 4]
        place(out, pad([note(n) for n in chord], bar + 0.4, 1400) * 0.5, b * bar)
        place(out, osc(note(chord[0] - 24), bar, "saw") * env(bar, 0.01, 0.3, 0.5, 0.1) * 0.35, b * bar)
        for k in range(16):  # arpej
            n = chord[k % 3] + 12 * (1 + (k // 3) % 2)
            sig = lp_fast(osc(note(n), beat / 4, "square"), 2600) * env(beat / 4, 0.002, 0.05, 0.3, 0.05) * 0.12
            place(out, sig, b * bar + k * beat / 4)
        if b >= 4:
            for k in range(4):
                place(out, kick() * 0.5, b * bar + k * beat)
                if k % 2:
                    place(out, snare() * 0.25, b * bar + k * beat)
    out += lp_fast(noise(len(out) / SR), 900) * 0.05  # neon yağmuru
    return reverb(out)


def track_assembly(bars=16, bpm=118):
    beat = 60.0 / bpm
    bar = beat * 4
    out = np.zeros(int(SR * bar * bars) + SR)
    seq = [45, 45, 48, 45, 52, 45, 50, 48]
    for b in range(bars):
        for k in range(8):
            n = seq[k] - (2 if b % 4 == 3 else 0)
            place(out, lp_fast(osc(note(n), beat / 2, "saw"), 900) * env(beat / 2, 0.005, 0.1, 0.4, 0.05) * 0.45, b * bar + k * beat / 2)
        for k in range(4):
            place(out, kick() * 0.6, b * bar + k * beat)
        for k in range(8):
            place(out, hat() * 0.25, b * bar + k * beat / 2 + beat / 4)
        place(out, metal_hit(0.6, 280 + 30 * (b % 3)) * 0.45, b * bar + beat * 1.5)
        if b % 2:
            place(out, metal_hit(0.8, 180) * 0.35, b * bar + beat * 3.25)
        if b >= 8:
            place(out, pad([note(57), note(60), note(63)], bar, 1100) * 0.3, b * bar)
    return reverb(out, 0.35)


def track_boss_phase(phase, bars=12):
    bpm = (128, 136, 150)[phase - 1]
    beat = 60.0 / bpm
    bar = beat * 4
    out = np.zeros(int(SR * bar * bars) + SR)
    roots = [45, 41, 43, 40]
    for b in range(bars):
        r = roots[b % 4]
        strings = pad([note(r + 12), note(r + 15), note(r + 19), note(r + 24)], bar + 0.3, 2400 + 600 * phase, 0.01)
        place(out, strings * (0.35 + 0.08 * phase), b * bar)
        bass_kind = "saw" if phase < 2 else "square"
        for k in range(8):
            sig = lp_fast(osc(note(r - 12), beat / 2, bass_kind), 600 + 300 * phase) * env(beat / 2, 0.003, 0.08, 0.5, 0.04)
            place(out, sig * 0.5, b * bar + k * beat / 2)
        for k in range(16 if phase < 3 else 24):
            step = beat / (4 if phase < 3 else 6)
            n = r + 24 + [0, 3, 7, 10, 12, 7][k % 6]
            place(out, lp_fast(osc(note(n), step, "square"), 3500) * env(step, 0.002, 0.03, 0.3, 0.02) * 0.1, b * bar + k * step)
        for k in range(4):
            place(out, kick() * (0.55 + 0.1 * phase), b * bar + k * beat)
            if k % 2:
                place(out, snare() * 0.4, b * bar + k * beat)
        if phase >= 2:
            place(out, metal_hit(0.5, 220) * 0.4, b * bar + beat * 2.5)
        if phase == 3 and b % 2:  # dijital kekeme (glitch)
            g = int(SR * beat / 8)
            seg = out[int(b * bar * SR):int(b * bar * SR) + g].copy()
            for k in range(4):
                place(out, seg * 0.6, b * bar + beat * 3 + k * beat / 8)
    choir = sum(np.sin(2 * np.pi * note(n) * t_axis(len(out) / SR)) for n in (57, 64, 69)) * 0.05
    return reverb(out + choir * (0.5 + 0.3 * phase), 0.4)


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------
def sweep(sec, f0, f1, kind="saw"):
    t = t_axis(sec)
    f = f0 + (f1 - f0) * (t / sec)
    ph = np.cumsum(f) / SR
    return 2 * (ph % 1) - 1 if kind == "saw" else np.sin(2 * np.pi * ph)


def gen_sfx():
    s = sweep(1.0, 200, 1800, "sine") * env(1.0, 0.8, 0.1, 0.9, 0.1) + lp_fast(noise(1.0), 4000) * 0.15 * np.linspace(0, 1, SR)
    write_wav(os.path.join(SFX, "sfx_cyber_laser_charge.wav"), s)
    f = (sweep(0.7, 1400, 300) * 0.6 + lp_fast(noise(0.7), 5000) * 0.4) * env(0.7, 0.005, 0.2, 0.5, 0.3)
    write_wav(os.path.join(SFX, "sfx_cyber_laser_fire.wav"), f)
    w = sweep(1.2, 900, 90, "sine") * env(1.2, 0.05, 0.4, 0.6, 0.5)
    w = reverb(w + lp_fast(noise(1.2), 600) * 0.3 * env(1.2, 0.3, 0.3, 0.5, 0.4), 0.6)
    write_wav(os.path.join(SFX, "sfx_time_slow_warp.wav"), w)
    e = kick(0.9) * 1.2 + lp_fast(noise(0.9), 2500) * np.exp(-t_axis(0.9) * 5) * 0.6
    crackle = (RNG.random(int(SR * 0.9)) > 0.985) * RNG.uniform(-1, 1, int(SR * 0.9)) * np.exp(-t_axis(0.9) * 3)
    write_wav(os.path.join(SFX, "sfx_emp_detonate.wav"), e + crackle * 0.8)
    st = kick(0.6) * 1.3 + metal_hit(0.6, 120) * 0.5
    hiss = (noise(0.8) - lp_fast(noise(0.8), 3000)) * env(0.8, 0.15, 0.2, 0.6, 0.4) * 0.4
    out = np.zeros(int(SR * 1.2)); place(out, st, 0.0); place(out, hiss, 0.25)
    write_wav(os.path.join(SFX, "sfx_hydraulic_stomp.wav"), out)
    v = np.zeros(int(SR * 1.6))
    for k, n in enumerate([50, 47, 52, 45, 48, 43]):  # bitcrush'lı formant konuşma
        seg = osc(note(n), 0.22, "saw") * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t_axis(0.22)))
        seg = np.round(lp_fast(seg, 1800) * 6) / 6 * env(0.22, 0.01, 0.05, 0.7, 0.05)
        place(v, seg, k * 0.25)
    write_wav(os.path.join(SFX, "sfx_ai_lord_glitch_voice.wav"), reverb(v, 0.3))
    c = np.zeros(int(SR * 0.9))
    for k in range(9):
        place(c, (noise(0.05) - lp_fast(noise(0.05), 5000)) * np.exp(-t_axis(0.05) * 70) * (1 - k / 10), k * 0.07 + RNG.uniform(0, 0.03))
    place(c, metal_hit(0.7, 1300) * 0.4, 0.0)
    write_wav(os.path.join(SFX, "sfx_sword_shell_crack.wav"), c)
    laugh = np.zeros(int(SR * 2.6))
    for k in range(6):
        f0 = note(40 - k)
        seg = lp_fast(osc(f0, 0.28, "saw") + osc(f0 * 1.5, 0.28, "saw") * 0.4, 900) * env(0.28, 0.02, 0.08, 0.6, 0.12)
        place(laugh, seg, 0.1 + k * 0.36)
    laugh += lp_fast(noise(2.6), 400) * 0.15
    write_wav(os.path.join(SFX, "sfx_sword_shatter_wizard_laugh.wav"), reverb(laugh, 0.65))
    amb = lp_fast(noise(12.0), 1200) * 0.5 + np.sin(2 * np.pi * 55 * t_axis(12.0)) * 0.15
    write_wav(os.path.join(MUSIC, "future_ambience.wav"), amb)


def main():
    os.makedirs(MUSIC, exist_ok=True)
    write_ogg(os.path.join(MUSIC, "bgm_future_neon_ruins.ogg"), track_neon_ruins())
    write_ogg(os.path.join(MUSIC, "bgm_future_assembly_tension.ogg"), track_assembly())
    phases = [track_boss_phase(p) for p in (1, 2, 3)]
    for p, x in enumerate(phases, 1):
        write_ogg(os.path.join(MUSIC, "ai_lord_phase_%d.ogg" % p), x)
    write_ogg(os.path.join(MUSIC, "bgm_ai_lord_boss.ogg"), np.concatenate(phases))
    gen_sfx()
    print("Bölüm 5 sesleri üretildi.")


if __name__ == "__main__":
    main()
