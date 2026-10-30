import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SAMPLE_RATE = 44100
OUT_DIR = r"c:\Projects\2dgame\2-dgame\assets\audio\sfx"

def normalize(audio, peak=0.92):
    max_val = np.max(np.abs(audio))
    if max_val > 1e-6:
        return (audio / max_val) * peak
    return audio

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

def save_wav(path, audio_data):
    audio_data = np.clip(audio_data, -1.0, 1.0)
    pcm16 = (audio_data * 32767.0).astype(np.int16)
    wavfile.write(path, SAMPLE_RATE, pcm16)
    print(f"Saved: {path} ({len(audio_data)/SAMPLE_RATE:.3f}s)")

# -----------------------------------------------------------------------------
# FORMULA: Layer 1 (Whoosh / Hava Katmanı) + Layer 2 (Transient Ring / Metalik Çınlama)
# -----------------------------------------------------------------------------

def create_sword_slash_variant(var_idx, dur, whoosh_freq_start, whoosh_freq_end, ring_freqs, ring_offset_ms=15):
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    
    # --- KATMAN 1: Hava Katmanı (Whoosh) ---
    # Kılıcın kütlesini ve rüzgârı hissettiren düşük-orta frekanslı hava sürtünmesi
    noise = np.random.normal(0, 1, len(t))
    
    # 3-bant dinamik aerodinamik hava dalgası
    w_low = lowpass(noise, 450) * 0.45
    w_mid = bandpass(noise, whoosh_freq_end, whoosh_freq_start) * 0.75
    w_air = bandpass(noise, 1500, 4800) * 0.35
    
    # Asimetrik aerodinamik zarf (Darbeden önce yükselir, tepe noktasına ulaşır)
    whoosh_env = (np.sin(np.pi * (t / dur) ** 0.85) ** 2.2)
    whoosh_layer = (w_low + w_mid + w_air) * whoosh_env
    
    # --- KATMAN 2: Metalik Çınlama (Transient Ring) ---
    # Darbeden 15ms sonra / tepe anında patlayan parlak çelik tınısı
    offset_samples = int((ring_offset_ms / 1000.0) * SAMPLE_RATE)
    ring_layer = np.zeros(len(t))
    
    rem_samples = len(t) - offset_samples
    if rem_samples > 0:
        t_ring = np.linspace(0, rem_samples / SAMPLE_RATE, rem_samples, endpoint=False)
        
        # 1. Keskin çelik sürtünme atağı (Ultra-hızlı transient crack)
        friction_burst = highpass(np.random.normal(0, 1, rem_samples), 2400) * np.exp(-75.0 * t_ring) * 0.55
        
        # 2. Çelik bıçak harmonik rezonansları (Harmonic ringing)
        steel_resonances = np.zeros(rem_samples)
        for i, (f, amp, decay_rate) in enumerate(ring_freqs):
            decay = np.exp(-decay_rate * t_ring)
            steel_resonances += np.sin(2 * np.pi * f * t_ring) * amp * decay
            
        ring_layer[offset_samples:] = (friction_burst + steel_resonances)
        
    # --- KATMANLARI BİRLEŞTİRME & DENGELEME ---
    # Hava katmanı (Whoosh) kütleyi taşır; metalik çınlama keskinliği verir.
    composite = whoosh_layer * 0.78 + ring_layer * 0.52
    return normalize(composite, 0.90)

# -----------------------------------------------------------------------------
# SWORD HIT (DARBE / VURUŞ) KATMANLARI:
# Katman 1: Sub/Mid Flesh-Armor Impact Thud
# Katman 2: Sharp Edge Blade Cleave (Kesik)
# Katman 3: Vibrating Steel Blade Ring
# -----------------------------------------------------------------------------

def create_sword_hit_variant(var_idx, dur, sub_freq, bite_band, metal_freqs):
    t = np.linspace(0, dur, int(SAMPLE_RATE * dur), endpoint=False)
    
    # Katman 1: Tok gövde/zırh darbesi (Impact Thud)
    thud_env = np.exp(-48.0 * t)
    impact_thud = np.sin(2 * np.pi * sub_freq * t) * 0.70 * thud_env
    impact_crack = bandpass(np.random.normal(0, 1, len(t)), 80, 550) * thud_env * 0.50
    
    # Katman 2: Çelik ağız kesme / ısırma atağı (Edge Cleave Bite)
    cleave_noise = bandpass(np.random.normal(0, 1, len(t)), bite_band[0], bite_band[1]) * np.exp(-38.0 * t) * 0.55
    
    # Katman 3: Darbe sonrası bıçak metalik titreşimi
    metal_vibration = np.zeros(len(t))
    for f, amp, decay in metal_freqs:
        metal_vibration += np.sin(2 * np.pi * f * t) * amp * np.exp(-decay * t)
        
    composite = impact_thud + impact_crack + cleave_noise + metal_vibration
    return normalize(composite, 0.92)

def generate_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    
    # 3 Çeşit Kılıç Savurma (Slash 1, 2, 3)
    # 1. Hızlı, keskin hafif vuruş (0.19s, yüksek transient)
    s1 = create_sword_slash_variant(
        1, dur=0.19, 
        whoosh_freq_start=2400, whoosh_freq_end=650,
        ring_freqs=[(1920, 0.35, 32.0), (3840, 0.22, 42.0), (5760, 0.12, 55.0)],
        ring_offset_ms=12
    )
    save_wav(os.path.join(OUT_DIR, "sword_slash_1.wav"), s1)
    
    # 2. Çapraz akıcı kombo savurma (0.23s, dengeli geniş whoosh + çift çınlama)
    s2 = create_sword_slash_variant(
        2, dur=0.23,
        whoosh_freq_start=1950, whoosh_freq_end=480,
        ring_freqs=[(1650, 0.38, 28.0), (3300, 0.24, 38.0), (4950, 0.14, 48.0)],
        ring_offset_ms=16
    )
    save_wav(os.path.join(OUT_DIR, "sword_slash_2.wav"), s2)
    
    # 3. Geniş ağır kavis / sert savurma (0.27s, derin kütleli hava akımı + uzun çelik tınısı)
    s3 = create_sword_slash_variant(
        3, dur=0.27,
        whoosh_freq_start=1600, whoosh_freq_end=320,
        ring_freqs=[(1420, 0.40, 24.0), (2840, 0.25, 34.0), (4260, 0.16, 44.0)],
        ring_offset_ms=20
    )
    save_wav(os.path.join(OUT_DIR, "sword_slash_3.wav"), s3)
    
    # Ana dosya (Geriye uyumluluk için s2 master referans)
    save_wav(os.path.join(OUT_DIR, "sword_slash.wav"), s2)
    
    # 3 Çeşit Kılıç Vuruş Darbesi (Hit 1, 2, 3)
    # 1. Keskin hafif temas / zırh sıyrılması
    h1 = create_sword_hit_variant(
        1, dur=0.22, sub_freq=115, bite_band=(600, 3200),
        metal_freqs=[(1580, 0.32, 22.0), (2750, 0.20, 32.0)]
    )
    save_wav(os.path.join(OUT_DIR, "sword_hit_1.wav"), h1)
    
    # 2. Tok et ve gövde darbesi (Cleave impact)
    h2 = create_sword_hit_variant(
        2, dur=0.25, sub_freq=85, bite_band=(350, 2600),
        metal_freqs=[(1380, 0.35, 18.0), (2450, 0.22, 28.0), (3950, 0.12, 38.0)]
    )
    save_wav(os.path.join(OUT_DIR, "sword_hit_2.wav"), h2)
    
    # 3. Ağır zırh parçalama / kemik çatlama darbesi
    h3 = create_sword_hit_variant(
        3, dur=0.28, sub_freq=70, bite_band=(250, 2100),
        metal_freqs=[(1220, 0.38, 16.0), (2180, 0.25, 24.0), (3400, 0.14, 32.0)]
    )
    save_wav(os.path.join(OUT_DIR, "sword_hit_3.wav"), h3)
    
    # Ana dosya (Geriye uyumluluk için h2 master referans)
    save_wav(os.path.join(OUT_DIR, "sword_hit.wav"), h2)

if __name__ == "__main__":
    generate_all()
