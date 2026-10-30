import os
import subprocess
import numpy as np
import scipy.io.wavfile as wav

SFX_DIR = r"c:\Projects\2dgame\2-dgame\assets\audio\sfx"
TEMP_DIR = r"C:\Users\bokeg\AppData\Local\Temp\game_audio_build"
os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

def run_ffmpeg(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"FFmpeg error: {res.stderr}")
    return res

def build_all_sfx():
    print("--- 1. Building Campfire and Torch (CC0 Authentic Warm Fireplace Loop) ---")
    fire_src = os.path.join(TEMP_DIR, 'fire_fireplace.wav')
    if os.path.exists(fire_src):
        tmp_fire = os.path.join(TEMP_DIR, 'fire_master.wav')
        run_ffmpeg([
            'ffmpeg', '-y', '-ss', '2.0', '-t', '12.0', '-i', fire_src,
            '-af', 'highpass=f=80,equalizer=f=3200:t=q:w=1.2:g=4,volume=2.2',
            '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', tmp_fire
        ])
        sr, data = wav.read(tmp_fire)
        cf_samples = int(sr * 0.5)
        total = len(data)
        main_len = total - cf_samples
        head = data[:cf_samples].astype(np.float32)
        tail = data[main_len:total].astype(np.float32)
        w = np.linspace(0.0, 1.0, cf_samples)[:, np.newaxis]
        blended = (tail * (1.0 - w) + head * w).astype(np.int16)

        out_fire = np.zeros((main_len, 2), dtype=np.int16)
        out_fire[:cf_samples] = blended
        out_fire[cf_samples:] = data[cf_samples:main_len]

        f_fire = out_fire.astype(np.float32) / 32768.0
        boosted = f_fire * 5.6
        clipped = np.tanh(boosted * 0.95) / 0.95
        out_fire = np.clip(clipped * 32767.0, -32767.0, 32767.0).astype(np.int16)

        for fn in ['campfire.wav', 'torch.wav', 'torch_burn.wav']:
            wav.write(os.path.join(SFX_DIR, fn), sr, out_fire)
            print(f"Generated {fn}: {len(out_fire)/sr:.2f}s, rms={np.sqrt(np.mean(out_fire.astype(np.float32)**2)):.1f}")

    print("--- 2. Building Professional Sword Slashes (Blade Zing + Air Slice) ---")
    blade_dir = os.path.join(TEMP_DIR, '80_rpg_sfx')
    swish_dir = os.path.join(TEMP_DIR, 'swishes', 'swishes')
    rpg_dir = os.path.join(TEMP_DIR, 'rpg_sound_pack', 'RPG Sound Pack', 'battle')

    def mix_slash(whoosh_path, blade_path, delay_ms, whoosh_vol, blade_vol, out_name):
        tmp_w = os.path.join(TEMP_DIR, 'w.wav')
        tmp_b = os.path.join(TEMP_DIR, 'b.wav')
        run_ffmpeg(['ffmpeg', '-y', '-i', whoosh_path, '-af', f'highpass=f=220,lowpass=f=5500,volume={whoosh_vol}', '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', tmp_w])
        run_ffmpeg(['ffmpeg', '-y', '-i', blade_path, '-af', f'highpass=f=1800,equalizer=f=3800:t=q:w=1.5:g=3,volume={blade_vol}', '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', tmp_b])
        sr_w, data_w = wav.read(tmp_w)
        _, data_b = wav.read(tmp_b)
        delay_samples = int(sr_w * delay_ms / 1000.0)
        total_len = max(len(data_w), delay_samples + len(data_b))
        mixed = np.zeros((total_len, 2), dtype=np.float32)
        mixed[:len(data_w)] += data_w.astype(np.float32)
        mixed[delay_samples:delay_samples + len(data_b)] += data_b.astype(np.float32)

        energy = np.max(np.abs(mixed), axis=1)
        thresh = np.max(energy) * 0.015
        above = np.where(energy > thresh)[0]
        start = max(0, above[0] - int(sr_w * 0.01))
        end = min(total_len, above[-1] + int(sr_w * 0.08))
        trimmed = mixed[start:end]
        fade_len = int(sr_w * 0.03)
        fade_w = np.linspace(1.0, 0.0, fade_len)[:, np.newaxis]
        trimmed[-fade_len:] *= fade_w
        pk = np.max(np.abs(trimmed))
        norm = np.clip(trimmed * (0.94 * 32767.0 / pk), -32767, 32767).astype(np.int16)
        wav.write(os.path.join(SFX_DIR, out_name), sr_w, norm)
        print(f"Generated {out_name}: {len(norm)/sr_w:.3f}s")

    if os.path.exists(blade_dir):
        mix_slash(os.path.join(swish_dir, 'swish-2.wav'), os.path.join(blade_dir, 'blade_01.ogg'), 12, 0.85, 1.35, 'sword_slash_1.wav')
        mix_slash(os.path.join(rpg_dir, 'swing.wav'), os.path.join(blade_dir, 'blade_02.ogg'), 15, 0.80, 1.40, 'sword_slash_2.wav')
        mix_slash(os.path.join(swish_dir, 'swish-8.wav'), os.path.join(blade_dir, 'blade_03.ogg'), 10, 0.85, 1.30, 'sword_slash_3.wav')
        mix_slash(os.path.join(swish_dir, 'swish-2.wav'), os.path.join(blade_dir, 'blade_01.ogg'), 12, 0.85, 1.35, 'sword_slash.wav')

    print("--- 3. Building Sword Hits (Kenney Impact & Clashes CC0) ---")
    clash_dir = os.path.join(TEMP_DIR, 'sword_clashes')
    kenney_impact = os.path.join(TEMP_DIR, 'kenney_packs', 'impact-sounds', 'Audio')

    def mix_hit(clash_src, impact_src, blade_src, clash_gain, impact_gain, blade_gain, out_name):
        tmp_c = os.path.join(TEMP_DIR, 'c.wav')
        tmp_i = os.path.join(TEMP_DIR, 'i.wav')
        tmp_b = os.path.join(TEMP_DIR, 'bh.wav')
        run_ffmpeg(['ffmpeg', '-y', '-i', clash_src, '-af', f'highpass=f=400,volume={clash_gain}', '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', tmp_c])
        run_ffmpeg(['ffmpeg', '-y', '-i', impact_src, '-af', f'highpass=f=120,volume={impact_gain}', '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', tmp_i])
        run_ffmpeg(['ffmpeg', '-y', '-i', blade_src, '-af', f'highpass=f=1500,volume={blade_gain}', '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', tmp_b])
        sr, d_c = wav.read(tmp_c)
        _, d_i = wav.read(tmp_i)
        _, d_b = wav.read(tmp_b)
        total = min(max(len(d_c), len(d_i), len(d_b)), int(sr * 0.38))
        mixed = np.zeros((total, 2), dtype=np.float32)
        mixed[:min(total, len(d_c))] += d_c[:min(total, len(d_c))].astype(np.float32)
        mixed[:min(total, len(d_i))] += d_i[:min(total, len(d_i))].astype(np.float32)
        mixed[:min(total, len(d_b))] += d_b[:min(total, len(d_b))].astype(np.float32)
        fl = int(sr * 0.04)
        w = np.linspace(1.0, 0.0, fl)[:, np.newaxis]
        mixed[-fl:] *= w
        pk = np.max(np.abs(mixed))
        norm = np.clip(mixed * (0.94 * 32767.0 / pk), -32767, 32767).astype(np.int16)
        wav.write(os.path.join(SFX_DIR, out_name), sr, norm)
        print(f"Generated {out_name}: {len(norm)/sr:.3f}s")

    if os.path.exists(clash_dir):
        mix_hit(os.path.join(clash_dir, 'sword_clash.1.ogg'), os.path.join(kenney_impact, 'impactMetal_heavy_000.ogg'), os.path.join(blade_dir, 'blade_01.ogg'), 0.85, 0.90, 0.70, 'sword_hit_1.wav')
        mix_hit(os.path.join(clash_dir, 'sword_clash.2.ogg'), os.path.join(kenney_impact, 'impactMetal_medium_001.ogg'), os.path.join(blade_dir, 'blade_02.ogg'), 0.90, 0.85, 0.75, 'sword_hit_2.wav')
        mix_hit(os.path.join(clash_dir, 'sword_clash.3.ogg'), os.path.join(kenney_impact, 'impactMetal_heavy_002.ogg'), os.path.join(blade_dir, 'blade_03.ogg'), 0.85, 0.95, 0.70, 'sword_hit_3.wav')
        mix_hit(os.path.join(clash_dir, 'sword_clash.1.ogg'), os.path.join(kenney_impact, 'impactMetal_heavy_000.ogg'), os.path.join(blade_dir, 'blade_01.ogg'), 0.85, 0.90, 0.70, 'sword_hit.wav')

    print("\nALL AUDIO ASSETS BUILT AND MASTERED SUCCESSFULLY!")

if __name__ == "__main__":
    build_all_sfx()
