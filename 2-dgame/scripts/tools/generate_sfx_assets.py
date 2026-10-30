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

def apply_loop_crossfade(audio, fade_duration=0.35, fs=SAMPLE_RATE):
    fade_len = int(fade_duration * fs)
    if len(audio) <= fade_len * 2:
        return audio
    # Blend end of audio into start of audio for seamless loop
    fade_out = np.linspace(1.0, 0.0, fade_len)
    fade_in = np.linspace(0.0, 1.0, fade_len)
    
    # Overlap-add the tail into the head
    head_tail_blend = audio[:fade_len] * fade_in + audio[-fade_len:] * fade_out
    result = np.copy(audio)
    result[:fade_len] = head_tail_blend
    result[-fade_len:] = head_tail_blend
    return result

# ---------------------------------------------------------------------------
# SFX GENERATORS
# ---------------------------------------------------------------------------

# 1. Sword Slash (Crisp physical steel blade slice through air - No retro beeps)
def gen_sword_slash():
    dur = 0.20
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    
    # Downward sweeping aero-acoustic resonance
    seg1 = bandpass(noise, 2200, 5200)
    seg2 = bandpass(noise, 900, 2800)
    seg3 = bandpass(noise, 350, 1100)
    w1 = np.clip(1.0 - t / (dur * 0.35), 0, 1)
    w2 = np.clip(np.sin(np.pi * t / dur), 0, 1)
    w3 = np.clip((t - dur * 0.35) / (dur * 0.65), 0, 1)
    swish = (seg1 * w1 + seg2 * w2 + seg3 * w3) * 0.85
    
    # Steel blade friction transient
    blade_ring = (np.sin(2 * np.pi * 1420 * t) * 0.12 + np.sin(2 * np.pi * 2840 * t) * 0.08) * np.exp(-32.0 * t)
    env = (np.sin(np.pi * (t / dur) ** 0.7) ** 2)
    audio = (swish + blade_ring) * env
    return normalize(audio, 0.88)

# 2. Sword Hit (Deep visceral cleave + steel resonance + flesh impact)
def gen_sword_hit():
    dur = 0.24
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    imp_env = np.exp(-55.0 * t)
    impact = np.sin(2 * np.pi * 95 * t) * 0.65 * imp_env
    noise_crack = bandpass(np.random.normal(0, 1, len(t)), 250, 3200) * imp_env * 0.5
    
    # Metallic blade vibration
    ring_env = np.exp(-16.0 * t)
    metal = (np.sin(2 * np.pi * 1480 * t) * 0.35 +
             np.sin(2 * np.pi * 2650 * t) * 0.22 +
             np.sin(2 * np.pi * 3980 * t) * 0.12) * ring_env
    audio = impact + noise_crack + metal
    return normalize(audio, 0.90)

# 3. Parry Clang (Sharp, crystal-clear harmonic sword deflection)
def gen_parry_clang():
    dur = 0.42
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    spark = bandpass(np.random.normal(0, 1, len(t)), 2200, 8500) * np.exp(-75.0 * t) * 0.45
    env = np.exp(-11.5 * t)
    m1 = np.sin(2 * np.pi * 1250 * t) * 0.35
    m2 = np.sin(2 * np.pi * 2500 * t) * 0.28
    m3 = np.sin(2 * np.pi * 3750 * t) * 0.18
    m4 = np.sin(2 * np.pi * 5320 * t) * 0.10
    audio = spark + (m1 + m2 + m3 + m4) * env
    return normalize(audio, 0.86)

# 4. Campfire (Rich, continuous crackling wood & warm hearth flame - Seamless Loop)
def gen_campfire():
    dur = 5.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    
    # Warm flame body and fluttering draft
    flame_rumble = lowpass(noise, 220) * 0.35
    flame_flutter = bandpass(noise, 180, 750) * 0.28 * (1.0 + 0.35 * np.sin(2 * np.pi * 2.8 * t))
    
    # Continuous natural wood pops and sparks
    pops = np.zeros(len(t))
    num_pops = int(dur * 24)
    pop_indices = np.random.randint(0, len(t) - 600, num_pops)
    for idx in pop_indices:
        p_len = min(500, len(t) - idx)
        p_t = np.linspace(0, p_len / SAMPLE_RATE, p_len, endpoint=False)
        decay = np.exp(-np.linspace(0, 9, p_len))
        freq = np.random.uniform(900, 3600)
        pop_wave = np.sin(2 * np.pi * freq * p_t) * decay
        pops[idx:idx+p_len] += pop_wave * np.random.uniform(0.35, 0.75)
        
    audio = flame_rumble + flame_flutter + pops
    audio = apply_loop_crossfade(audio, 0.3)
    return normalize(audio, 0.78)

# 5. Checkpoint Activated (Ascending Ottoman sacred chimes & crystalline resonance)
def gen_checkpoint_chime():
    dur = 1.8
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    notes = [440.0, 554.37, 659.25, 880.0, 1108.73, 1318.51] # A major sacred chord
    step_time = 0.11
    for i, freq in enumerate(notes):
        start_idx = int(i * step_time * SAMPLE_RATE)
        rem = len(t) - start_idx
        t_n = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        env = np.exp(-4.5 * t_n)
        chime = (np.sin(2 * np.pi * freq * t_n) * 0.38 +
                 np.sin(2 * np.pi * freq * 2.005 * t_n) * 0.22 +
                 np.sin(2 * np.pi * freq * 3.01 * t_n) * 0.10) * env
        audio[start_idx:] += chime
    return normalize(audio, 0.85)

# 6. Rest Melody (Ottoman acoustic Kanun & Tanbur arpeggio - Campfire healing)
def gen_rest_melody():
    dur = 3.6
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    arpeggio = [
        (0.00, 220.0), (0.16, 261.63), (0.32, 329.63), (0.48, 440.0),
        (0.85, 293.66), (1.01, 349.23), (1.17, 440.00), (1.33, 523.25),
        (1.70, 246.94), (1.86, 329.63), (2.02, 415.30), (2.22, 440.00),
        (2.60, 220.00), (2.60, 329.63), (2.60, 440.00), (2.60, 554.37)
    ]
    for start_sec, freq in arpeggio:
        start_idx = int(start_sec * SAMPLE_RATE)
        rem = len(t) - start_idx
        t_n = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        env = np.exp(-3.8 * t_n)
        string = (np.sin(2 * np.pi * freq * t_n) * 0.45 +
                  np.sin(2 * np.pi * freq * 2 * t_n) * 0.24 * np.exp(-2.2 * t_n) +
                  np.sin(2 * np.pi * freq * 3 * t_n) * 0.12 * np.exp(-4.5 * t_n)) * env
        audio[start_idx:] += string
    return normalize(audio, 0.82)

# 7. Spike Trap (Crisp high-tension spring release + mechanical latch snap + thrusting steel spikes)
def gen_spike_trap():
    dur = 0.38
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    # 1. High-tension latch release / spring snap
    spring_snap = np.sin(2 * np.pi * 1250 * t) * np.exp(-60.0 * t) * 0.65
    spring_twang = bandpass(np.random.normal(0, 1, len(t)), 900, 3800) * np.exp(-38.0 * t) * 0.55
    # 2. Steel blade extension and stone frame impact
    thud_t = np.clip(t - 0.035, 0, dur)
    thud_env = np.exp(-24.0 * thud_t) * (t > 0.035)
    blade_scrape = bandpass(np.random.normal(0, 1, len(t)), 2400, 6800) * thud_env * 0.45
    steel_ring = (np.sin(2 * np.pi * 940 * thud_t) * 0.4 + np.sin(2 * np.pi * 1880 * thud_t) * 0.28) * thud_env
    stone_thud = np.sin(2 * np.pi * 90 * thud_t) * 0.6 * thud_env
    audio = spring_snap + spring_twang + blade_scrape + steel_ring + stone_thud
    return normalize(audio, 0.88)

# 8. Guillotine Swing (Ultra-soft, faint smooth air displacement - Comfortable and never annoying)
def gen_guillotine_swing():
    dur = 0.36
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    env = np.sin(np.pi * (t / dur)) ** 2.2
    noise = np.random.normal(0, 1, len(t))
    whisper = lowpass(noise, 200) * 0.10 # soft low frequency air movement only
    audio = whisper * env
    return normalize(audio, 0.16) # faint, subtle ambient whoosh

# 9. Page Turn (Authentic parchment turning rustle for Codex & Books)
def gen_page_turn():
    dur = 0.32
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    paper_rustle = bandpass(noise, 700, 5200)
    env1 = np.sin(np.pi * (t / dur)) ** 1.6
    flap_t = np.clip(t - 0.16, 0, dur)
    flap_env = np.exp(-24.0 * flap_t) * (t > 0.16)
    flap = np.sin(2 * np.pi * 220 * flap_t) * flap_env * 0.28
    audio = paper_rustle * env1 * 0.65 + flap
    return normalize(audio, 0.72)

# 10. Codex Open / Close
def gen_codex_open():
    dur = 0.38
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    creak = bandpass(noise, 380, 2000) * np.exp(-9.0 * t) * 0.35
    thud = np.sin(2 * np.pi * 75 * t) * np.exp(-11.0 * t) * 0.4
    paper_raw = gen_page_turn()
    paper = np.zeros(len(t))
    copy_len = min(len(t), len(paper_raw))
    paper[:copy_len] = paper_raw[:copy_len] * 0.45
    audio = creak + thud + paper
    return normalize(audio, 0.74)

def gen_codex_close():
    dur = 0.30
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    env = np.exp(-15.0 * t)
    cover_thud = np.sin(2 * np.pi * 90 * t) * 0.55 * env
    air_puff = lowpass(np.random.normal(0, 1, len(t)), 380) * 0.28 * env
    leather_snap = np.sin(2 * np.pi * 520 * t) * 0.18 * np.exp(-36.0 * t)
    audio = cover_thud + air_puff + leather_snap
    return normalize(audio, 0.74)

# 11. Quest Complete (Heroic brass & bell chime triumphant fanfare)
def gen_quest_complete():
    dur = 2.4
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    motifs = [
        (0.00, 349.23, 0.28), # F4
        (0.24, 440.00, 0.28), # A4
        (0.48, 523.25, 0.35), # C5
        (0.82, 698.46, 1.40), # F5
    ]
    for start_sec, freq, note_dur in motifs:
        start_idx = int(start_sec * SAMPLE_RATE)
        length = min(int(note_dur * SAMPLE_RATE), len(t) - start_idx)
        t_n = np.linspace(0, length / SAMPLE_RATE, length, endpoint=False)
        env = np.sin(np.pi * np.clip(t_n / (note_dur * 0.15), 0, 1) * 0.5) * np.exp(-2.0 * t_n / note_dur)
        brass = (np.sin(2 * np.pi * freq * t_n) * 0.45 +
                 np.sin(2 * np.pi * freq * 2 * t_n) * 0.25 +
                 np.sin(2 * np.pi * freq * 3 * t_n) * 0.14) * env
        bell = (np.sin(2 * np.pi * freq * 2.01 * t_n) * 0.22 +
                np.sin(2 * np.pi * freq * 4.02 * t_n) * 0.12) * np.exp(-3.8 * t_n)
        audio[start_idx:start_idx+length] += brass + bell
    return normalize(audio, 0.85)

# 12. Inventory Open / Close
def gen_inventory_open():
    dur = 0.26
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    buckle = np.sin(2 * np.pi * 1420 * t) * np.exp(-42.0 * t) * 0.32
    leather = bandpass(np.random.normal(0, 1, len(t)), 420, 3000) * np.sin(np.pi * (t / dur)) * 0.38
    audio = buckle + leather
    return normalize(audio, 0.72)

def gen_inventory_close():
    dur = 0.22
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    env = np.exp(-20.0 * t)
    buckle = np.sin(2 * np.pi * 1180 * t) * env * 0.28
    pouch_thud = np.sin(2 * np.pi * 125 * t) * env * 0.42
    audio = buckle + pouch_thud
    return normalize(audio, 0.72)

# ---------------------------------------------------------------------------
# MUSIC & AMBIENT GENERATORS
# ---------------------------------------------------------------------------

# 13. Menu Theme (Epic Ottoman historical atmosphere - Ney drone, Tanbur, Kös heartbeat)
def gen_menu_theme():
    dur = 12.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    
    # Deep Root Drone: D2 (73.4Hz) + A2 (110Hz)
    bass = (np.sin(2 * np.pi * 73.42 * t) * 0.28 + np.sin(2 * np.pi * 110.0 * t) * 0.20)
    drone_motion = 0.85 + 0.15 * np.sin(2 * np.pi * 0.15 * t)
    audio += bass * drone_motion
    
    # Warm Wind / Breath texture (Ney flute breath)
    breath = lowpass(np.random.normal(0, 1, len(t)), 450) * 0.12 * (0.8 + 0.2 * np.sin(2 * np.pi * 0.3 * t))
    audio += breath
    
    # Plucked Oud / Tanbur Motif (Ottoman Rast / Nihavend modal phrase)
    # Notes: D4 (293.7), F4 (349.2), G4 (392.0), A4 (440.0), C5 (523.2), D5 (587.3)
    phrase = [
        (0.5, 293.66, 1.8), (2.0, 349.23, 1.5), (3.8, 392.00, 1.6),
        (5.5, 440.00, 2.2), (7.5, 523.25, 1.8), (9.2, 440.00, 1.5), (10.5, 349.23, 1.4)
    ]
    for start_sec, freq, note_dur in phrase:
        start_idx = int(start_sec * SAMPLE_RATE)
        rem = len(t) - start_idx
        t_n = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        env = np.exp(-2.5 * t_n)
        string = (np.sin(2 * np.pi * freq * t_n) * 0.22 +
                  np.sin(2 * np.pi * freq * 2 * t_n) * 0.12 * np.exp(-1.8 * t_n) +
                  np.sin(2 * np.pi * freq * 3 * t_n) * 0.06 * np.exp(-3.5 * t_n)) * env
        audio[start_idx:] += string
        
    # Kös / Frame Drum Heartbeat (Every 2 seconds)
    for beat_time in [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]:
        b_idx = int(beat_time * SAMPLE_RATE)
        rem = len(t) - b_idx
        t_b = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        drum_env = np.exp(-6.5 * t_b)
        drum = (np.sin(2 * np.pi * 55 * t_b) * 0.35 + np.sin(2 * np.pi * 110 * t_b) * 0.15) * drum_env
        audio[b_idx:] += drum
        
    audio = apply_loop_crossfade(audio, 0.45)
    return normalize(audio, 0.80)

# 14. Combat Theme (Driving historical Janissary battle rhythm - Kös drums, Bronze cymbals)
def gen_combat_theme():
    dur = 12.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    
    # Driving Cello / Bass Ostinato (130 BPM -> beat = 0.461s)
    beat_dur = 0.4615
    total_beats = int(dur / beat_dur)
    ostinato_notes = [73.42, 73.42, 87.31, 98.00, 73.42, 87.31, 110.0, 98.00] # D, D, F, G, D, F, A, G
    
    for i in range(total_beats):
        b_time = i * beat_dur
        b_idx = int(b_time * SAMPLE_RATE)
        rem = len(t) - b_idx
        t_b = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        
        # Heavy Kös bass drum on 1st & 3rd beat of 4
        if i % 2 == 0:
            k_env = np.exp(-9.0 * t_b)
            k_drum = (np.sin(2 * np.pi * 50 * t_b) * 0.45 + np.sin(2 * np.pi * 95 * t_b) * 0.2) * k_env
            audio[b_idx:] += k_drum
            
        # Copper percussion / davul rim on every beat
        rim_env = np.exp(-18.0 * t_b)
        rim = bandpass(np.random.normal(0, 1, rem), 900, 4500) * rim_env * 0.25
        audio[b_idx:] += rim
        
        # Ostinato bass tone
        freq = ostinato_notes[i % len(ostinato_notes)]
        bass_env = np.exp(-3.5 * t_b)
        bass = (np.sin(2 * np.pi * freq * t_b) * 0.30 + np.sin(2 * np.pi * freq * 2 * t_b) * 0.15) * bass_env
        audio[b_idx:] += bass
        
    # Bronze Cymbal Clash at bar starts (every 4 beats)
    for bar in range(int(total_beats / 4)):
        c_idx = int(bar * 4 * beat_dur * SAMPLE_RATE)
        rem = len(t) - c_idx
        t_c = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        c_env = np.exp(-3.0 * t_c)
        cymbal = bandpass(np.random.normal(0, 1, rem), 3000, 12000) * c_env * 0.32
        audio[c_idx:] += cymbal
        
    audio = apply_loop_crossfade(audio, 0.45)
    return normalize(audio, 0.85)

# 15. Camp Ambience (Night Ottoman camp with gentle wind, crickets, warm hearth fire)
def gen_camp_ambience():
    dur = 8.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    breeze = lowpass(noise, 320) * 0.25 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * t))
    cricket_mod = (np.sin(2 * np.pi * 22 * t) > 0.35).astype(float)
    crickets = np.sin(2 * np.pi * 4800 * t) * cricket_mod * 0.032
    drone = (np.sin(2 * np.pi * 110 * t) * 0.12 + np.sin(2 * np.pi * 164.8 * t) * 0.08) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.1 * t))
    audio = breeze + crickets + drone
    audio = apply_loop_crossfade(audio, 0.4)
    return normalize(audio, 0.72)

# 16. Vlad / Gothic Exploration Theme (Brooding D-minor cello, distant cathedral bells)
def gen_vlad_theme():
    dur = 10.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    bass = np.sin(2 * np.pi * 73.42 * t) * 0.25 + np.sin(2 * np.pi * 110.0 * t) * 0.18
    pad = (np.sin(2 * np.pi * 146.83 * t) * 0.15 + np.sin(2 * np.pi * 174.61 * t) * 0.12) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.2 * t))
    audio += bass + pad
    
    bell_times = [0.5, 4.0, 7.5]
    for b_time in bell_times:
        b_idx = int(b_time * SAMPLE_RATE)
        rem = len(t) - b_idx
        t_b = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        bell_env = np.exp(-1.4 * t_b)
        bell = (np.sin(2 * np.pi * 440 * t_b) * 0.22 +
                np.sin(2 * np.pi * 440 * 2.76 * t_b) * 0.12 +
                np.sin(2 * np.pi * 440 * 5.4 * t_b) * 0.06) * bell_env
        audio[b_idx:] += bell
        
    audio = apply_loop_crossfade(audio, 0.45)
    return normalize(audio, 0.76)

# 17. Prehistoric Valley Theme (Primeval subterranean drone, wooden tribal pulses)
def gen_prehistoric_theme():
    dur = 10.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    audio = np.zeros(len(t))
    # Deep primal Earth drone: 55Hz (A1) and 82.4Hz (E2)
    drone = (np.sin(2 * np.pi * 55.0 * t) * 0.32 + np.sin(2 * np.pi * 82.4 * t) * 0.20) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.2 * t))
    audio += drone
    
    # Primordial Cave Wind
    wind = lowpass(np.random.normal(0, 1, len(t)), 280) * 0.22 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.15 * t))
    audio += wind
    
    # Tribal hollow log thuds
    log_times = [0.0, 1.5, 3.0, 4.5, 6.0, 7.5, 9.0]
    for lt in log_times:
        l_idx = int(lt * SAMPLE_RATE)
        rem = len(t) - l_idx
        t_l = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        l_env = np.exp(-10.0 * t_l)
        log_thud = (np.sin(2 * np.pi * 90 * t_l) * 0.45 + np.sin(2 * np.pi * 180 * t_l) * 0.25) * l_env
        audio[l_idx:] += log_thud
        
    audio = apply_loop_crossfade(audio, 0.4)
    return normalize(audio, 0.78)

# 18. Prehistoric Ambience (Cave wind, water drops on stone)
def gen_prehistoric_ambience():
    dur = 8.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    cave_wind = lowpass(noise, 240) * 0.26 * (0.75 + 0.25 * np.sin(2 * np.pi * 0.12 * t))
    
    # Occasional water drips
    drips = np.zeros(len(t))
    drip_times = [0.8, 2.2, 3.9, 5.7, 7.1]
    for dt in drip_times:
        d_idx = int(dt * SAMPLE_RATE)
        rem = len(t) - d_idx
        t_d = np.linspace(0, rem / SAMPLE_RATE, rem, endpoint=False)
        d_env = np.exp(-22.0 * t_d)
        drip = (np.sin(2 * np.pi * 1650 * t_d) * 0.25 + np.sin(2 * np.pi * 3300 * t_d) * 0.12) * d_env
        drips[d_idx:] += drip
        
    audio = cave_wind + drips
    audio = apply_loop_crossfade(audio, 0.35)
    return normalize(audio, 0.70)

# 19. Vlad / Castle Dungeon Ambience (Cold dungeon wind, distant stone reverberation)
def gen_vlad_ambience():
    dur = 8.0
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    noise = np.random.normal(0, 1, len(t))
    dungeon_wind = bandpass(noise, 180, 680) * 0.22 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.2 * t))
    cold_hum = np.sin(2 * np.pi * 65.4 * t) * 0.18
    audio = dungeon_wind + cold_hum
    audio = apply_loop_crossfade(audio, 0.35)
    return normalize(audio, 0.70)

def main():
    base_dir = r"C:\Projects\2dgame\2-dgame\assets\audio"
    sfx_dir = os.path.join(base_dir, "sfx")
    music_dir = os.path.join(base_dir, "music")
    ensure_dir(sfx_dir)
    ensure_dir(music_dir)

    print("Generating High-Fidelity Studio Audio Assets via DSP...")
    # SFX
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
    
    # Music & Ambience
    save_wav(os.path.join(music_dir, "menu_theme.wav"), gen_menu_theme())
    save_wav(os.path.join(music_dir, "combat_theme.wav"), gen_combat_theme())
    save_wav(os.path.join(music_dir, "camp_ambience.wav"), gen_camp_ambience())
    save_wav(os.path.join(music_dir, "vlad_theme.wav"), gen_vlad_theme())
    save_wav(os.path.join(music_dir, "prehistoric_theme.wav"), gen_prehistoric_theme())
    save_wav(os.path.join(music_dir, "prehistoric_ambience.wav"), gen_prehistoric_ambience())
    save_wav(os.path.join(music_dir, "vlad_ambience.wav"), gen_vlad_ambience())
    print("All High-Fidelity Audio Assets Generated Successfully!")

if __name__ == "__main__":
    main()
