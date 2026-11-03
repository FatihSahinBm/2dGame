import os
import wave
import numpy as np
import scipy.signal as signal

def load_wav(path):
    with wave.open(path, 'rb') as w:
        n_ch = w.getnchannels()
        sr = w.getframerate()
        n_frames = w.getnframes()
        data = w.readframes(n_frames)
        sig = np.frombuffer(data, dtype=np.int16).reshape(-1, n_ch).astype(np.float32) / 32768.0
    return sig, sr, n_ch

def save_wav(path, sig, sr):
    sig_clipped = np.clip(sig, -1.0, 1.0)
    data = (sig_clipped * 32767.0).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(sig.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    peak_db = 20 * np.log10(max(np.max(np.abs(sig)), 1e-9))
    print(f"Saved: {path} (duration: {len(sig)/sr:.2f}s, frames: {len(sig)}, peak: {peak_db:.2f} dBFS)")

def write_import_file(wav_path, is_loop, loop_end_frame=0):
    import_path = wav_path + ".import"
    loop_mode = 1 if is_loop else 0
    content = f"""[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://assets/audio/sfx/{os.path.basename(wav_path)}"
dest_files=[]

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={loop_mode}
edit/loop_begin=0
edit/loop_end={loop_end_frame}
compress/mode=0
"""
    with open(import_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Created import: {import_path} (loop_mode={loop_mode}, loop_end={loop_end_frame})")

def apply_filters(sig, sr):
    # 1. High-pass filter at 90 Hz (12 dB/oct = 2nd order Butterworth)
    b_hp, a_hp = signal.butter(2, 90.0, btype='highpass', fs=sr)
    filtered = signal.lfilter(b_hp, a_hp, sig, axis=0)
    
    # 2. Peaking EQ filter: 3.5 kHz - 5 kHz resonance shaved by -3 dB (center 4200 Hz, Q = 2.0)
    f0 = 4200.0
    Q = 2.0
    gain_db = -3.0
    A = 10.0 ** (gain_db / 40.0)
    w0 = 2.0 * np.pi * f0 / sr
    alpha = np.sin(w0) / (2.0 * Q)
    b0 = 1.0 + alpha * A
    b1 = -2.0 * np.cos(w0)
    b2 = 1.0 - alpha * A
    a0 = 1.0 + alpha / A
    a1 = -2.0 * np.cos(w0)
    a2 = 1.0 - alpha / A

    b_peak = np.array([b0, b1, b2]) / a0
    a_peak = np.array([a0, a1, a2]) / a0
    filtered = signal.lfilter(b_peak, a_peak, filtered, axis=0)
    return filtered

def create_bed_loop(sig, sr):
    filtered = apply_filters(sig, sr)
    
    # De-crackle the bed: suppress transient spikes so only the warm flame murmur remains
    env = np.mean(np.abs(filtered), axis=1)
    smooth_win = int(sr * 0.02)
    smoothed_env = np.convolve(env, np.ones(smooth_win)/smooth_win, mode='same')
    
    th = 0.080
    bed = filtered.copy()
    for ch in range(bed.shape[1]):
        mask = smoothed_env > th
        reduction = np.where(mask, (th / np.maximum(smoothed_env, 1e-6)) ** 0.85, 1.0)
        bed[:, ch] *= reduction
    
    # Select a 7.0s segment + 0.8s crossfade tail from 1.2s to 9.0s
    start_sample = int(1.2 * sr)
    loop_duration = 7.0 # target 7.0 seconds
    crossfade_len = int(0.8 * sr)
    raw_len = int(loop_duration * sr) + crossfade_len
    segment = bed[start_sample : start_sample + raw_len].copy()
    
    N = int(loop_duration * sr)
    tail = segment[N : N + crossfade_len]
    
    # Equal power fade with exact endpoints (fade_in[0]=0, fade_out[0]=1)
    phase = np.linspace(0, np.pi / 2, crossfade_len)
    fade_in = (np.sin(phase) ** 2)[:, np.newaxis]
    fade_out = (np.cos(phase) ** 2)[:, np.newaxis]
    
    loop = segment[:N].copy()
    loop[:crossfade_len] = loop[:crossfade_len] * fade_in + tail * fade_out
    
    # Normalize bed to -9.0 dBFS True Peak (subtle warm background)
    cur_peak = np.max(np.abs(loop))
    target_peak = 10.0 ** (-9.0 / 20.0) # ~0.355
    loop = loop * (target_peak / cur_peak)
    
    return loop, N

def extract_crackles(sig, sr):
    slices = [
        (2.21, 2.58, "campfire_crackle_01.wav"), # Deep chunky wood pop
        (4.70, 5.04, "campfire_crackle_02.wav"), # Sharp crisp pop
        (5.36, 5.76, "campfire_crackle_03.wav"), # Snappy resonant crackle
        (7.23, 7.60, "campfire_crackle_04.wav"), # Woody spark burst
        (8.40, 8.74, "campfire_crackle_05.wav"), # Quick brittle snap
    ]
    
    fade_ms = 5
    fade_samples = int(sr * (fade_ms / 1000.0))
    phase = np.linspace(0, np.pi, fade_samples)
    fade_in = (0.5 * (1.0 - np.cos(phase)))[:, np.newaxis]
    fade_out = (0.5 * (1.0 + np.cos(phase)))[:, np.newaxis]
    
    crackles = []
    for t_start, t_end, filename in slices:
        s0 = int(t_start * sr)
        s1 = int(t_end * sr)
        chunk = sig[s0:s1].copy()
        
        # Apply highpass & 4.2 kHz dip
        chunk = apply_filters(chunk, sr)
        
        # Apply 5ms micro fade-in and fade-out
        chunk[:fade_samples] *= fade_in
        chunk[-fade_samples:] *= fade_out
        
        # Peak normalize to -6.8 dBFS (strictly below -6.0 dBFS ceiling)
        p = np.max(np.abs(chunk))
        if p > 0:
            target_p = 10.0 ** (-6.8 / 20.0)
            chunk = chunk * (target_p / p)
        
        crackles.append((filename, chunk))
    return crackles

def main():
    src_path = r"c:\Projects\2dgame\2-dgame\assets\audio\sfx\campfire.wav"
    out_dir = r"c:\Projects\2dgame\2-dgame\assets\audio\sfx"
    
    print(f"Loading source: {src_path}")
    sig, sr, n_ch = load_wav(src_path)
    
    # 1. Create bed loop
    bed_loop, bed_frames = create_bed_loop(sig, sr)
    bed_path = os.path.join(out_dir, "campfire_bed_loop.wav")
    save_wav(bed_path, bed_loop, sr)
    write_import_file(bed_path, is_loop=True, loop_end_frame=bed_frames)
    
    # 2. Extract crackles
    crackles = extract_crackles(sig, sr)
    for filename, chunk in crackles:
        c_path = os.path.join(out_dir, filename)
        save_wav(c_path, chunk, sr)
        write_import_file(c_path, is_loop=False, loop_end_frame=len(chunk))
        
    print("\nAdım A Başarıyla Tamamlandı: 1 bed loop + 5 çıtırtı sesi ve .import yapılandırmaları oluşturuldu.")

if __name__ == "__main__":
    main()
