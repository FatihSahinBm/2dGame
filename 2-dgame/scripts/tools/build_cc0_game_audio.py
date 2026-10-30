import os
import subprocess
import numpy as np
import scipy.io.wavfile as wav

SFX_DIR = r"c:\Projects\2dgame\2-dgame\assets\audio\sfx"
SCRATCH_DIR = r"c:\Projects\2dgame\2-dgame\scratch"
KENNEY_DIR = os.path.join(SCRATCH_DIR, "kenney_packs")
OGA_DIR = os.path.join(SCRATCH_DIR, "opengameart")
TEMP_DIR = os.path.join(SCRATCH_DIR, "temp_build")

os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

def run_ffmpeg(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"FFmpeg error: {res.stderr}")
    return res

def convert_to_temp_wav(src, name, sr=44100, channels=2):
    dst = os.path.join(TEMP_DIR, f"{name}.wav")
    run_ffmpeg([
        'ffmpeg', '-y', '-i', src,
        '-ar', str(sr), '-ac', str(channels),
        '-c:a', 'pcm_s16le', dst
    ])
    return dst

def normalize_audio(data, peak_target=0.88):
    data_float = data.astype(np.float32)
    current_peak = np.max(np.abs(data_float))
    if current_peak > 0:
        scale = (peak_target * 32767.0) / current_peak
        data_float = data_float * scale
    return np.clip(data_float, -32767, 32767).astype(np.int16)

def trim_silence(data, threshold_ratio=0.03, pre_roll=441, post_roll=2205):
    energy = np.max(np.abs(data), axis=1) if len(data.shape) > 1 else np.abs(data)
    peak = np.max(energy)
    if peak == 0:
        return data
    thresh = peak * threshold_ratio
    above = np.where(energy > thresh)[0]
    if len(above) == 0:
        return data
    start = max(0, above[0] - pre_roll)
    end = min(len(data), above[-1] + post_roll)
    return data[start:end]

def make_seamless_loop(wav_path, crossfade_seconds=0.45):
    sr, data = wav.read(wav_path)
    if len(data.shape) == 1:
        data = np.stack([data, data], axis=-1)
    
    cf_samples = int(sr * crossfade_seconds)
    total_samples = len(data)
    if total_samples <= cf_samples * 2:
        return data
    
    main_len = total_samples - cf_samples
    tail = data[main_len:total_samples].astype(np.float32)
    head = data[:cf_samples].astype(np.float32)
    
    weights = np.linspace(0.0, 1.0, cf_samples)[:, np.newaxis]
    blended_head = tail * (1.0 - weights) + head * weights
    
    out_data = np.zeros((main_len, data.shape[1]), dtype=np.int16)
    out_data[:cf_samples] = np.clip(blended_head, -32767, 32767).astype(np.int16)
    out_data[cf_samples:main_len] = data[cf_samples:main_len]
    return normalize_audio(out_data, peak_target=0.85)

def mix_tracks(track_list, output_wav, peak_target=0.88, trim=True):
    max_len = 0
    loaded = []
    sr = 44100
    for p, delay, gain in track_list:
        cur_sr, data = wav.read(p)
        sr = cur_sr
        if len(data.shape) == 1:
            data = np.stack([data, data], axis=-1)
        dur = len(data) + delay
        if dur > max_len:
            max_len = dur
        loaded.append((data, delay, gain))
        
    mixed = np.zeros((max_len, 2), dtype=np.float32)
    for data, delay, gain in loaded:
        end = delay + len(data)
        mixed[delay:end, :] += data.astype(np.float32) * gain
        
    if trim:
        mixed = trim_silence(mixed, threshold_ratio=0.02)
    norm = normalize_audio(mixed, peak_target=peak_target)
    wav.write(output_wav, sr, norm)
    print(f"Generated {os.path.basename(output_wav)}: {len(norm)/sr:.3f}s")

def build_all_sfx():
    print("--- 1. Building Campfire and Torch (CC0 Authentic Crackling Fire) ---")
    fire_src = os.path.join(OGA_DIR, "fire-1.wav")
    fire_loop = make_seamless_loop(fire_src, crossfade_seconds=0.4)
    campfire_wav = os.path.join(SFX_DIR, "campfire.wav")
    wav.write(campfire_wav, 44100, fire_loop)
    print(f"Generated campfire.wav (Seamless Loop, {len(fire_loop)/44100:.3f}s)")
    
    torch_wav = os.path.join(SFX_DIR, "torch.wav")
    wav.write(torch_wav, 44100, fire_loop)
    print(f"Generated torch.wav (Seamless Loop, {len(fire_loop)/44100:.3f}s)")
    
    # Also create torch_burn.wav
    torch_burn_wav = os.path.join(SFX_DIR, "torch_burn.wav")
    wav.write(torch_burn_wav, 44100, fire_loop)

    print("--- 2. Building Sword Slashes (StarNinjas & Swishes CC0) ---")
    # Slash 1: Quick Light Slash (sword.6 + swish-2)
    s6_wav = convert_to_temp_wav(os.path.join(OGA_DIR, "sword_attacks", "sword - StarNinjas", "sword.6.ogg"), "s6")
    swish2_wav = os.path.join(OGA_DIR, "swishes", "swishes", "swish-2.wav")
    mix_tracks([(swish2_wav, 0, 0.7), (s6_wav, int(44100 * 0.015), 1.0)], os.path.join(SFX_DIR, "sword_slash_1.wav"))

    # Slash 2: Combo Slash (sword.4 + swish-1)
    s4_wav = convert_to_temp_wav(os.path.join(OGA_DIR, "sword_attacks", "sword - StarNinjas", "sword.4.ogg"), "s4")
    swish1_wav = os.path.join(OGA_DIR, "swishes", "swishes", "swish-1.wav")
    mix_tracks([(swish1_wav, 0, 0.7), (s4_wav, int(44100 * 0.02), 1.0)], os.path.join(SFX_DIR, "sword_slash_2.wav"))

    # Slash 3: Heavy Cleave Slash (sword.3 + swish-8)
    s3_wav = convert_to_temp_wav(os.path.join(OGA_DIR, "sword_attacks", "sword - StarNinjas", "sword.3.ogg"), "s3")
    swish8_wav = os.path.join(OGA_DIR, "swishes", "swishes", "swish-8.wav")
    mix_tracks([(swish8_wav, 0, 0.8), (s3_wav, int(44100 * 0.025), 1.0)], os.path.join(SFX_DIR, "sword_slash_3.wav"))

    # Master sword_slash.wav
    s4_clean = convert_to_temp_wav(os.path.join(OGA_DIR, "sword_attacks", "sword - StarNinjas", "sword.4.ogg"), "s4_clean")
    mix_tracks([(swish1_wav, 0, 0.75), (s4_clean, int(44100 * 0.02), 1.0)], os.path.join(SFX_DIR, "sword_slash.wav"))

    print("--- 3. Building Sword Hits (Kenney Impact Sounds & RPG Audio CC0) ---")
    chop_wav = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "chop.ogg"), "chop")
    slice_wav = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "knifeSlice.ogg"), "slice")
    metal_h0 = convert_to_temp_wav(os.path.join(KENNEY_DIR, "impact-sounds", "Audio", "impactMetal_heavy_000.ogg"), "metal_h0")
    metal_m1 = convert_to_temp_wav(os.path.join(KENNEY_DIR, "impact-sounds", "Audio", "impactMetal_medium_001.ogg"), "metal_m1")
    metal_h2 = convert_to_temp_wav(os.path.join(KENNEY_DIR, "impact-sounds", "Audio", "impactMetal_heavy_002.ogg"), "metal_h2")
    punch_h1 = convert_to_temp_wav(os.path.join(KENNEY_DIR, "impact-sounds", "Audio", "impactPunch_heavy_001.ogg"), "punch_h1")

    # Hit 1: Sharp steel bite (knifeSlice + impactMetal_medium_001)
    mix_tracks([(slice_wav, 0, 0.85), (metal_m1, 0, 0.9)], os.path.join(SFX_DIR, "sword_hit_1.wav"))

    # Hit 2: Tok cleave thud (chop + impactMetal_heavy_000)
    mix_tracks([(chop_wav, 0, 0.9), (metal_h0, int(44100 * 0.01), 0.85)], os.path.join(SFX_DIR, "sword_hit_2.wav"))

    # Hit 3: Heavy crush / shatter (punch_h1 + impactMetal_heavy_002)
    mix_tracks([(punch_h1, 0, 0.95), (metal_h2, int(44100 * 0.015), 0.85)], os.path.join(SFX_DIR, "sword_hit_3.wav"))

    # Master sword_hit.wav
    mix_tracks([(chop_wav, 0, 0.85), (metal_h0, int(44100 * 0.01), 0.9)], os.path.join(SFX_DIR, "sword_hit.wav"))

    print("--- 4. Building Parry Clang (StarNinjas & Kenney Metal Clang CC0) ---")
    clash_wav = convert_to_temp_wav(os.path.join(OGA_DIR, "sword_clashes", "sword_clash.2.ogg"), "clash2")
    metal_h1 = convert_to_temp_wav(os.path.join(KENNEY_DIR, "impact-sounds", "Audio", "impactMetal_heavy_001.ogg"), "metal_h1")
    mix_tracks([(clash_wav, 0, 1.0), (metal_h1, 0, 0.6)], os.path.join(SFX_DIR, "parry_clang.wav"), peak_target=0.92)

    print("--- 5. Building Book & Codex Sounds (Kenney RPG Audio CC0) ---")
    # Codex Open
    b_open = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "bookOpen.ogg"), "b_open")
    mix_tracks([(b_open, 0, 1.0)], os.path.join(SFX_DIR, "codex_open.wav"))

    # Codex Close
    b_close = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "bookClose.ogg"), "b_close")
    mix_tracks([(b_close, 0, 1.0)], os.path.join(SFX_DIR, "codex_close.wav"))

    # Page Turn
    b_flip = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "bookFlip2.ogg"), "b_flip")
    mix_tracks([(b_flip, 0, 1.0)], os.path.join(SFX_DIR, "page_turn.wav"))

    print("--- 6. Building Inventory Sounds (Kenney RPG Audio CC0) ---")
    # Inventory Open: Small leather rustle & buckle
    inv_open = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "handleSmallLeather.ogg"), "inv_open")
    mix_tracks([(inv_open, 0, 1.0)], os.path.join(SFX_DIR, "inventory_open.wav"))

    # Inventory Close: Bag drop / latch
    inv_close = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "dropLeather.ogg"), "inv_close")
    mix_tracks([(inv_close, 0, 1.0)], os.path.join(SFX_DIR, "inventory_close.wav"))

    print("--- 7. Building Checkpoint & Campfire Bell (Kenney Impact Bell CC0) ---")
    bell_wav = convert_to_temp_wav(os.path.join(KENNEY_DIR, "impact-sounds", "Audio", "impactBell_heavy_000.ogg"), "bell")
    mix_tracks([(bell_wav, 0, 1.0)], os.path.join(SFX_DIR, "checkpoint_activated.wav"), peak_target=0.85)

    print("--- 8. Building Rest Heal (Kenney Interface Confirmation CC0) ---")
    heal_wav = convert_to_temp_wav(os.path.join(KENNEY_DIR, "interface-sounds", "Audio", "confirmation_002.ogg"), "heal")
    mix_tracks([(heal_wav, 0, 0.85)], os.path.join(SFX_DIR, "rest_heal.wav"))

    print("--- 9. Building Quest Complete (Kenney Interface CC0) ---")
    quest_wav = convert_to_temp_wav(os.path.join(KENNEY_DIR, "interface-sounds", "Audio", "confirmation_001.ogg"), "quest")
    mix_tracks([(quest_wav, 0, 0.9)], os.path.join(SFX_DIR, "quest_complete.wav"))

    print("--- 10. Building Traps (Spike Trap & Guillotine Swing CC0) ---")
    # Spike Trap: Mechanical release (metalLatch) + sharp impale (chop + knifeSlice)
    latch_wav = convert_to_temp_wav(os.path.join(KENNEY_DIR, "rpg-audio", "Audio", "metalLatch.ogg"), "latch")
    mix_tracks([
        (latch_wav, 0, 0.95),
        (chop_wav, int(44100 * 0.03), 0.85),
        (slice_wav, int(44100 * 0.04), 0.75)
    ], os.path.join(SFX_DIR, "spike_trap.wav"))

    # Guillotine Swing: Gentle, aerodynamic whoosh (swish-7) with mild high cut
    swish7_wav = os.path.join(OGA_DIR, "swishes", "swishes", "swish-7.wav")
    tmp_guillotine = os.path.join(TEMP_DIR, "guillotine_filt.wav")
    run_ffmpeg([
        'ffmpeg', '-y', '-i', swish7_wav,
        '-af', 'lowpass=f=2800,volume=0.65',
        '-c:a', 'pcm_s16le', tmp_guillotine
    ])
    mix_tracks([(tmp_guillotine, 0, 1.0)], os.path.join(SFX_DIR, "guillotine_swing.wav"), peak_target=0.75)

    print("--- 11. Cleanup Old Unused Files ---")
    for obsolete in ["sword_hit.mp3", "torch_burn.mp3"]:
        obs_path = os.path.join(SFX_DIR, obsolete)
        if os.path.exists(obs_path):
            os.remove(obs_path)
            print(f"Removed obsolete file: {obsolete}")
        import_path = obs_path + ".import"
        if os.path.exists(import_path):
            os.remove(import_path)

    print("\nALL CC0 PROFESSIONAL AUDIO ASSETS BUILT SUCCESSFULLY!")

if __name__ == "__main__":
    build_all_sfx()
