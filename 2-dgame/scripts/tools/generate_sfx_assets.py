import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SAMPLE_RATE = 44100

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def normalize(audio, peak=0.9):
    max_val = np.max(np.abs(audio))
    if max_val > 1e-6:
        return (audio / max_val) * peak
    return audio

def save_wav(filename, audio_data, sample_rate=SAMPLE_RATE):
    # Ensure float32 in [-1, 1] then convert to 16-bit PCM
    audio_data = np.clip(audio_data, -1.0, 1.0)
    pcm16 = (audio_data * 32767.0).astype(np.int16)
    wavfile.write(filename, sample_rate, pcm16)
    print(f"Generated: {filename} ({len(audio_data)/sample_rate:.2f}s)")

def bandpass(data, lowcut, highcut, fs=SAMPLE_RATE, order=3):
    nyq = 0.5 * fs
    low = max(20.0, lowcut) / nyq
    high = min(nyq - 50.0, highcut) / nyq
    if low >= high:
        return data
    b, a = butter(order, [low, high], btype='band')
    return lfilter(b, a, data)

def lowpass(data, cutoff, fs=SAMPLE_RATE, order=3):
    nyq = 0.5 * fs
    cut = min(nyq - 50.0, cutoff) / nyq
    b, a = butter(order, cut, btype='low')
    return lfilter(b, a, data)

def highpass(data, cutoff, fs=SAMPLE_RATE, order=3):
    nyq = 0.5 * fs
    cut = max(20.0, cutoff) / nyq
    b, a = butter(order, cut, btype='high')
    return lfilter(b, a, data)

# 1. Sword Slash (Acoustic blade slice through air)
def gen_sword_slash():
    dur = 0.22
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    # Filtered noise sweep from 2500Hz down to 600Hz
    noise = np.random.normal(0, 1, len(t))
    # Time-varying filter approximation via segmented blending
    seg1 = bandpass(noise, 1500, 4500)
    seg2 = bandpass(noise, 800, 2500)
    seg3 = bandpass(noise, 400, 1200)
    # Pitch drop blend
    w1 = np.clip(1.0 - t / (dur * 0.4), 0, 1)
    w2 = np.clip(np.sin(np.pi * t / dur), 0, 1)
    w3 = np.clip((t - dur * 0.4) / (dur * 0.6), 0, 1)
    swish = seg1 * w1 + seg2 * w2 + seg3 * w3
    # Steel blade friction ring
    blade_ring = np.sin(2 * np.pi * 1280 * t) * 0.15 + np.sin(2 * np.pi * 2340 * t) * 0.1
    env = np.sin(np.pi * (t / dur) ** 0.8) ** 2
    audio = (swish * 0.85 + blade_ring * 0.15) * env
    return normalize(audio, 0.85)

# 2. Sword Hit (Metallic impact + flesh thud)
def gen_sword_hit():
    dur = 0.25
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    # Impact transient
    imp_env = np.exp(-60.0 * t)
    impact = np.sin(2 * np.pi * 110 * t) * 0.6 * imp_env
    noise_crack = np.random.normal(0, 1, len(t)) * imp_env * 0.4
    noise_crack = bandpass(noise_crack, 300, 3500)
    # Metallic blade ring
    ring_env = np.exp(-14.0 * t)
    metal = (np.sin(2 * np.pi * 1650 * t) * 0.35 +
             np.sin(2 * np.pi * 2890 * t) * 0.25 +
             np.sin(2 * np.pi * 4420 * t) * 0.15) * ring_env
    audio = impact + noise_crack + metal
    return normalize(audio, 0.88)

# 3. Parry Clang (Sharp resonant deflection clang)
def gen_parry_clang():
    dur = 0.45
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    env = np.exp(-12.0 * t)
    spark = np.random.normal(0, 1, len(t)) * np.exp(-70.0 * t) * 0.4
    spark = bandpass(spark, 2000, 8000)
    # High harmonic metal chime
    m1 = np.sin(2 * np.pi * 1180 * t) * 0.35
    m2 = np.sin(2 * np.pi * 2360 * t) * 0.3
    m3 = np.sin(2 * np.pi * 3540 * t) * 0.2
    m4 = np.sin(2 * np.pi * 5120 * t) * 0.1
    audio = spark + (m1 + m2 + m3 + m4) * env
    return normalize(audio, 0.85)

# 4. Campfire (Warm wood crackling and soothing flame roar loop)
def gen_campfire():
    dur = 4.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    # Warm low flame rumble
    noise = np.random.normal(0, 1, len(t))
    flame_rumble = lowpass(noise, 180) * 0.35
    flame_flutter = bandpass(noise, 150, 600) * 0.25 * (1.0 + 0.3 * np.sin(2 * np.pi * 3.5 * t))
    # Poisson wood crackles and pops
    pops = np.zeros(len(t))
    num_pops = int(dur * 18)
    pop_indices = np.random.randint(0, len(t) - 500, num_pops)
    for idx in pop_indices:
        decay = np.exp(-np.linspace(0, 8, 400))
        freq = np.random.uniform(1200, 3200)
        pop_wave = np.sin(2 * np.pi * freq * np.linspace(0, 400/SAMPLE_RATE, 400)) * decay
        pops[idx:idx+400] += pop_wave * np.random.uniform(0.3, 0.7)
    audio = flame_rumble + flame_flutter + pops
    # Loop fade in/out slightly for seamless loop
    fade_len = int(SAMPLE_RATE * 0.1)
    audio[:fade_len] *= np.linspace(0, 1, fade_len)
    audio[-fade_len:] *= np.linspace(1, 0, fade_len)
    return normalize(audio, 0.75)

# 5. Checkpoint Activated (Ascending crystalline sacred chimes)
def gen_checkpoint_chime():
    dur = 1.6
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    # Arpeggio notes: C5 (523Hz), E5 (659Hz), G5 (784Hz), C6 (1046Hz), E6 (1318Hz)
    notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]
    step_time = 0.12
    for i, freq in enumerate(notes):
        start_idx = int(i * step_time * SAMPLE_RATE)
        note_len = len(t) - start_idx
        t_note = np.linspace(0, note_len / SAMPLE_RATE, note_len, endpoint=False)
        env = np.exp(-5.0 * t_note)
        # Bell chime with 2nd harmonic
        chime = (np.sin(2 * np.pi * freq * t_note) * 0.4 +
                 np.sin(2 * np.pi * freq * 2.01 * t_note) * 0.2 +
                 np.sin(2 * np.pi * freq * 3.02 * t_note) * 0.08) * env
        audio[start_idx:] += chime
    return normalize(audio, 0.85)

# 6. Rest Melody (Warm soothing acoustic harp/kanun chords for campfire rest)
def gen_rest_melody():
    dur = 3.2
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    # Medieval Ottoman modal lute/harp chords (A minor - D minor - G - A modal cadence)
    # A arpeggio: A3 (220), C4 (261.6), E4 (329.6), A4 (440)
    # D arpeggio: D4 (293.7), F4 (349.2), A4 (440)
    # E / A resolve: B3 (246.9), E4 (329.6), G#4 (415.3), A4 (440)
    arpeggio = [
        (0.00, 220.0), (0.15, 261.63), (0.30, 329.63), (0.45, 440.0),
        (0.80, 293.66), (0.95, 349.23), (1.10, 440.00), (1.25, 523.25),
        (1.60, 246.94), (1.75, 329.63), (1.90, 415.30), (2.10, 440.00),
        (2.40, 220.00), (2.40, 329.63), (2.40, 440.00), (2.40, 554.37)
    ]
    for start_sec, freq in arpeggio:
        start_idx = int(start_sec * SAMPLE_RATE)
        note_len = len(t) - start_idx
        t_note = np.linspace(0, note_len / SAMPLE_RATE, note_len, endpoint=False)
        env = np.exp(-4.2 * t_note)
        # Plucked string harmonics (decaying faster at high harmonics)
        string = (np.sin(2 * np.pi * freq * t_note) * 0.45 +
                  np.sin(2 * np.pi * freq * 2 * t_note) * 0.25 * np.exp(-2.0 * t_note) +
                  np.sin(2 * np.pi * freq * 3 * t_note) * 0.12 * np.exp(-4.0 * t_note)) * env
        audio[start_idx:] += string
    return normalize(audio, 0.82)

# 7. Spike Trap (Crisp mechanical release + thrusting steel spikes)
def gen_spike_trap():
    dur = 0.32
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    # Initial mechanical spring snap
    snap = np.sin(2 * np.pi * 950 * t) * np.exp(-50.0 * t) * 0.4
    spring_noise = np.random.normal(0, 1, len(t)) * np.exp(-35.0 * t) * 0.4
    spring_noise = bandpass(spring_noise, 800, 4500)
    # Heavy stone / metal impact scrape as spikes lock open
    lock_t = np.clip(t - 0.05, 0, dur)
    lock_env = np.exp(-18.0 * lock_t) * (t > 0.05)
    metal_ring = (np.sin(2 * np.pi * 620 * lock_t) * 0.35 +
                  np.sin(2 * np.pi * 1240 * lock_t) * 0.25) * lock_env
    stone_thud = np.sin(2 * np.pi * 85 * lock_t) * 0.5 * lock_env
    audio = snap + spring_noise + metal_ring + stone_thud
    return normalize(audio, 0.88)

# 8. Guillotine Swing (Very soft, subtle air whisper - NO loud harsh screech)
def gen_guillotine_swing():
    dur = 0.45
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    env = np.sin(np.pi * (t / dur)) ** 2
    # Very soft lowpass-filtered air whisper
    noise = np.random.normal(0, 1, len(t))
    whisper = lowpass(noise, 480) * 0.22
    # Subtle low frequency blade passing
    subtle_blade = np.sin(2 * np.pi * (140.0 - 40.0 * (t/dur)) * t) * 0.08
    audio = (whisper + subtle_blade) * env * 0.5 # keep very mild and gentle
    return normalize(audio, 0.45) # low peak volume

# 9. Page Turn (Authentic parchment paper turning rustle for Codex)
def gen_page_turn():
    dur = 0.35
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    # Multi-textured paper sliding and flap
    noise = np.random.normal(0, 1, len(t))
    paper_rustle = bandpass(noise, 600, 5500)
    env1 = np.sin(np.pi * (t / dur)) ** 1.5
    # Soft paper flap at end
    flap_t = np.clip(t - 0.18, 0, dur)
    flap_env = np.exp(-25.0 * flap_t) * (t > 0.18)
    flap = np.sin(2 * np.pi * 210 * flap_t) * flap_env * 0.3
    audio = paper_rustle * env1 * 0.6 + flap
    return normalize(audio, 0.70)

# 10. Codex Open (Heavy leather tome opening with creaking spine)
def gen_codex_open():
    dur = 0.42
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    # Leather creak + parchment flutter + heavy cover movement
    noise = np.random.normal(0, 1, len(t))
    creak = bandpass(noise, 400, 2200) * np.exp(-10.0 * t) * 0.4
    cover_thud = np.sin(2 * np.pi * 80 * t) * np.exp(-12.0 * t) * 0.4
    paper_raw = gen_page_turn()
    paper = np.zeros(len(t))
    copy_len = min(len(t), len(paper_raw))
    paper[:copy_len] = paper_raw[:copy_len] * 0.5
    audio = creak + cover_thud + paper
    return normalize(audio, 0.75)

# 11. Codex Close (Leather book closing with deep thud)
def gen_codex_close():
    dur = 0.32
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    env = np.exp(-16.0 * t)
    cover_thud = np.sin(2 * np.pi * 95 * t) * 0.6 * env
    air_puff = lowpass(np.random.normal(0, 1, len(t)), 400) * 0.3 * env
    leather_snap = np.sin(2 * np.pi * 550 * t) * 0.2 * np.exp(-40.0 * t)
    audio = cover_thud + air_puff + leather_snap
    return normalize(audio, 0.75)

# 12. Quest Complete (Heroic brass & bell chime fanfare)
def gen_quest_complete():
    dur = 2.2
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    # Majestic brass fanfare: F4 -> A4 -> C5 -> F5 with bell chime
    motifs = [
        (0.00, 349.23, 0.28), # F4
        (0.25, 440.00, 0.28), # A4
        (0.50, 523.25, 0.35), # C5
        (0.85, 698.46, 1.25), # F5 (held triumphant)
    ]
    for start_sec, freq, note_dur in motifs:
        start_idx = int(start_sec * SAMPLE_RATE)
        length = int(note_dur * SAMPLE_RATE)
        length = min(length, len(t) - start_idx)
        t_n = np.linspace(0, length / SAMPLE_RATE, length, endpoint=False)
        env = np.sin(np.pi * np.clip(t_n / (note_dur * 0.15), 0, 1) * 0.5) * np.exp(-2.2 * t_n / note_dur)
        # Warm brass richness (rich harmonics)
        brass = (np.sin(2 * np.pi * freq * t_n) * 0.45 +
                 np.sin(2 * np.pi * freq * 2 * t_n) * 0.25 +
                 np.sin(2 * np.pi * freq * 3 * t_n) * 0.15) * env
        # Bell shimmer
        bell = (np.sin(2 * np.pi * freq * 2.01 * t_n) * 0.2 +
                np.sin(2 * np.pi * freq * 4.02 * t_n) * 0.1) * np.exp(-4.0 * t_n)
        audio[start_idx:start_idx+length] += brass + bell
    return normalize(audio, 0.85)

# 13. Inventory Open / Close (Leather bag with brass buckle)
def gen_inventory_open():
    dur = 0.28
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    buckle = np.sin(2 * np.pi * 1450 * t) * np.exp(-45.0 * t) * 0.35
    leather = bandpass(np.random.normal(0, 1, len(t)), 400, 3200) * np.sin(np.pi * (t / dur)) * 0.4
    audio = buckle + leather
    return normalize(audio, 0.72)

def gen_inventory_close():
    dur = 0.22
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    env = np.exp(-22.0 * t)
    buckle = np.sin(2 * np.pi * 1200 * t) * env * 0.3
    pouch_thud = np.sin(2 * np.pi * 130 * t) * env * 0.45
    audio = buckle + pouch_thud
    return normalize(audio, 0.72)

# 14. Camp Ambience / Music (Night Ottoman camp with gentle wind, crickets, warm fire glow)
def gen_camp_ambience():
    dur = 8.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    # Night wind breeze
    breeze = lowpass(noise, 320) * 0.25 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * t))
    # Crickets in distance
    cricket_mod = (np.sin(2 * np.pi * 22 * t) > 0.3).astype(float)
    crickets = np.sin(2 * np.pi * 4600 * t) * cricket_mod * 0.035
    # Distant warm modal drone
    drone = (np.sin(2 * np.pi * 110 * t) * 0.12 + np.sin(2 * np.pi * 164.8 * t) * 0.08) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.1 * t))
    audio = breeze + crickets + drone
    # Loop crossfade
    fade_len = int(SAMPLE_RATE * 0.3)
    audio[:fade_len] *= np.linspace(0, 1, fade_len)
    audio[-fade_len:] *= np.linspace(1, 0, fade_len)
    return normalize(audio, 0.70)

# 15. Vlad / Gothic Exploration Theme (Eerie gothic drone, church bells, brooding pads)
def gen_vlad_theme():
    dur = 10.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    # Gothic D-minor brooding drone
    bass = np.sin(2 * np.pi * 73.42 * t) * 0.25 + np.sin(2 * np.pi * 110.0 * t) * 0.18 # D2, A2
    pad = (np.sin(2 * np.pi * 146.83 * t) * 0.15 + np.sin(2 * np.pi * 174.61 * t) * 0.12) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.2 * t))
    audio += bass + pad
    # Atmospheric mournful bells ringing periodically
    bell_times = [0.5, 4.0, 7.5]
    for b_time in bell_times:
        b_idx = int(b_time * SAMPLE_RATE)
        rem = len(t) - b_idx
        t_b = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        bell_env = np.exp(-1.4 * t_b)
        bell = (np.sin(2 * np.pi * 440 * t_b) * 0.2 +
                np.sin(2 * np.pi * 440 * 2.76 * t_b) * 0.1 +
                np.sin(2 * np.pi * 440 * 5.4 * t_b) * 0.05) * bell_env
        audio[b_idx:] += bell
    # Loop crossfade
    fade_len = int(SAMPLE_RATE * 0.4)
    audio[:fade_len] *= np.linspace(0, 1, fade_len)
    audio[-fade_len:] *= np.linspace(1, 0, fade_len)
    return normalize(audio, 0.75)

def main():
    base_dir = r"C:\Projects\2dgame\2-dgame\assets\audio"
    sfx_dir = os.path.join(base_dir, "sfx")
    music_dir = os.path.join(base_dir, "music")
    ensure_dir(sfx_dir)
    ensure_dir(music_dir)

    print("Generating High-Fidelity Studio Audio Assets via DSP...")
    save_wav(os.path.join(sfx_dir, "sword_slash.wav"), gen_sword_slash())
    save_wav(os.path.join(sfx_dir, "sword_hit.wav"), gen_sword_hit())
    save_wav(os.path.join(sfx_dir, "parry_clang.wav"), gen_parry_clang())
    save_wav(os.path.join(sfx_dir, "campfire.wav"), gen_campfire())
    save_wav(os.path.join(sfx_dir, "checkpoint_activated.wav"), gen_checkpoint_chime())
    save_wav(os.path.join(sfx_dir, "rest_heal.wav"), gen_rest_melody())
    save_wav(os.path.join(sfx_dir, "spike_trap.wav"), gen_spike_trap())
    save_wav(os.path.join(sfx_dir, "guillotine_swing.wav"), gen_guillotine_swing())
    save_wav(os.path.join(sfx_dir, "page_turn.wav"), gen_page_turn())
    save_wav(os.path.join(sfx_dir, "codex_open.wav"), gen_codex_open())
    save_wav(os.path.join(sfx_dir, "codex_close.wav"), gen_codex_close())
    save_wav(os.path.join(sfx_dir, "quest_complete.wav"), gen_quest_complete())
    save_wav(os.path.join(sfx_dir, "inventory_open.wav"), gen_inventory_open())
    save_wav(os.path.join(sfx_dir, "inventory_close.wav"), gen_inventory_close())
    save_wav(os.path.join(music_dir, "camp_ambience.wav"), gen_camp_ambience())
    save_wav(os.path.join(music_dir, "vlad_theme.wav"), gen_vlad_theme())
    print("All High-Fidelity Audio Assets Generated Successfully!")

if __name__ == "__main__":
    main()
