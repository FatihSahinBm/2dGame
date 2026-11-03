#!/usr/bin/env python3
"""
Yamalı Dünya — Hibrit Kamp Ateşi QA Doğrulama ve DSP Analiz Scripti
Kriterler:
 1. 25 saniyelik gerçek sahne kaydı (stage_1_forest_camp.tscn).
 2. 11 saniyelik periyodik tekrar döngüsünün kaybolduğunun otokorelasyon ile kanıtlanması.
 3. 3.5 kHz üzerindeki sert tepe noktalarının (True Peak) -6 dBFS tavanını aşmadığının kanıtlanması.
 4. Mesafe kırpması (Distance Culling) ile 450 px dışında tam sessizlik sağlandığının kanıtlanması.
"""

import json
import wave
from pathlib import Path
import numpy as np
import scipy.signal as signal

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
CAPTURES_DIR = PROJECT_ROOT / "qa" / "audio" / "captures"
HYBRID_WAV = CAPTURES_DIR / "campfire_hybrid_25s.wav"
SOURCE_WAV = CAPTURES_DIR / "campfire_source.wav"
TEL_FILE = CAPTURES_DIR / "campfire_hybrid_telemetry.json"

def read_wav_mono(path: Path):
    with wave.open(str(path), "rb") as wf:
        n_ch = wf.getnchannels()
        sr = wf.getframerate()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)
    data = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    if n_ch == 2:
        mono = 0.5 * (data[0::2] + data[1::2])
    else:
        mono = data
    return mono, sr

def main():
    print("=================================================================")
    print(" YAMALI DÜNYA — HİBRİT KAMP ATEŞİ SESİ QA DOĞRULAMA RAPORU")
    print("=================================================================")
    
    # Kriter 1: 25 Saniyelik Gerçek Sahne Kaydı
    mono_hybrid, sr = read_wav_mono(HYBRID_WAV)
    duration_s = len(mono_hybrid) / sr
    overall_peak_dbfs = 20.0 * np.log10(np.max(np.abs(mono_hybrid)))
    overall_rms_dbfs = 20.0 * np.log10(np.sqrt(np.mean(mono_hybrid**2)))
    
    print(f"\n[KRİTER 1] Gerçek Sahne Kaydı:")
    print(f"  - Dosya: {HYBRID_WAV.name}")
    print(f"  - Süre: {duration_s:.2f} saniye (Hedef: >= 25.0s)")
    print(f"  - Örnekleme Oranı: {sr} Hz")
    print(f"  - Genel Peak: {overall_peak_dbfs:.2f} dBFS | RMS: {overall_rms_dbfs:.2f} dBFS")
    status_c1 = "PASS" if duration_s >= 25.0 else "FAIL"
    print(f"  -> Durum: {status_c1}")
    
    # Kriter 2: 11 Saniyelik Periyodik Tekrar İmzası Otokorelasyon Analizi
    # 25 saniyelik sinyalde 10.0s - 12.0s aralığındaki gecikmelerde (lag) normalize otokorelasyon
    print(f"\n[KRİTER 2] 11 Saniyelik Periyodik Tekrar İmzası Analizi:")
    # Sinyali aşağı örnekle (hesaplama optimizasyonu için örn. 2000 Hz)
    target_sr = 2000
    downsample_factor = sr // target_sr
    sig_ds = mono_hybrid[::downsample_factor]
    sig_ds = sig_ds - np.mean(sig_ds)
    norm = np.sum(sig_ds**2)
    
    # Otokorelasyon
    corr = signal.correlate(sig_ds, sig_ds, mode='full')
    corr = corr[len(sig_ds)-1:] / (norm if norm > 0 else 1.0)
    
    # 10.5s - 11.8s penceresi
    lag_min = int(10.5 * target_sr)
    lag_max = int(11.8 * target_sr)
    window_corr = corr[lag_min:lag_max]
    max_corr_11s = float(np.max(window_corr))
    
    # 2s ile 20s arasındaki genel maksimum tepe
    general_corr = corr[int(2.0 * target_sr):int(22.0 * target_sr)]
    max_general_corr = float(np.max(general_corr))
    
    print(f"  - 10.5s - 11.8s Aralığındaki Maksimum Korelasyon: {max_corr_11s:.4f}")
    print(f"  - 2.0s - 22.0s Aralığındaki Maksimum İkincil Tepe: {max_general_corr:.4f}")
    # Periyodik bir döngüde korelasyon > 0.70 civarındadır; stokastik/hibrit yapıda < 0.25'tir
    is_non_periodic = max_corr_11s < 0.25
    status_c2 = "PASS" if is_non_periodic else "FAIL"
    print(f"  - Periyodik Tekrar İmzası Yok Edildi mi?: {is_non_periodic} (Korelasyon katsayısı < 0.25 eşiği)")
    print(f"  -> Durum: {status_c2}")
    
    # Kriter 3: 3.5 kHz Üzeri Sert Tepe Noktaları (True Peak) Analizi
    print(f"\n[KRİTER 3] 3.5 kHz Üzeri Harshness & True Peak Analizi:")
    # 3.5 kHz High-Pass Butterworth filtresi (4. derece)
    sos = signal.butter(4, 3500.0, btype='highpass', fs=sr, output='sos')
    high_freq_sig = signal.sosfilt(sos, mono_hybrid)
    
    peak_above_3k5 = float(np.max(np.abs(high_freq_sig)))
    peak_above_3k5_dbfs = 20.0 * np.log10(peak_above_3k5) if peak_above_3k5 > 1e-6 else -96.0
    rms_above_3k5 = float(np.sqrt(np.mean(high_freq_sig**2)))
    rms_above_3k5_dbfs = 20.0 * np.log10(rms_above_3k5) if rms_above_3k5 > 1e-6 else -96.0
    
    print(f"  - 3.5 kHz Üzeri True Peak: {peak_above_3k5_dbfs:.2f} dBFS (Kabul Kriteri: < -6.0 dBFS)")
    print(f"  - 3.5 kHz Üzeri RMS: {rms_above_3k5_dbfs:.2f} dBFS")
    status_c3 = "PASS" if peak_above_3k5_dbfs < -6.0 else "FAIL"
    print(f"  -> Durum: {status_c3}")
    
    # Kriter 4: Mesafe Kırpması (Distance Culling) Doğrulaması
    print(f"\n[KRİTER 4] Mesafe Kırpma (Distance Culling) Doğrulaması:")
    with open(TEL_FILE, "r", encoding="utf-8") as f:
        tel = json.load(f)
    culling_data = tel.get("culling_test", {})
    amp_200px = culling_data.get("dist_200px_max_amp", 0.0)
    amp_600px = culling_data.get("dist_600px_max_amp", 1.0)
    is_culled_flag = culling_data.get("is_culled_flag", False)
    
    dbfs_200px = 20.0 * np.log10(amp_200px) if amp_200px > 1e-6 else -96.0
    dbfs_600px = 20.0 * np.log10(amp_600px) if amp_600px > 1e-6 else -96.0
    
    print(f"  - 200 px Mesafe (Etki Alanı İçi) Peak: {dbfs_200px:.2f} dBFS (Genlik: {amp_200px:.5f} - Duyulabilir)")
    print(f"  - 600 px Mesafe (Kırpılmış/Cull Alanı) Peak: {dbfs_600px:.2f} dBFS (Genlik: {amp_600px:.5f} - Sıfır Sızıntı)")
    print(f"  - Culled Flag Durumu: {is_culled_flag}")
    
    culling_pass = (amp_600px < 1e-4) and is_culled_flag and (amp_200px > 0.01)
    status_c4 = "PASS" if culling_pass else "FAIL"
    print(f"  -> Durum: {status_c4}")
    
    # Özet Sonuç
    all_pass = all(s == "PASS" for s in [status_c1, status_c2, status_c3, status_c4])
    print("\n=================================================================")
    print(f" NİHAİ DOĞRULAMA SONUCU: {'PASS - BAŞARILI' if all_pass else 'FAIL'}")
    print("=================================================================")
    
    summary_report = {
        "status": "PASS" if all_pass else "FAIL",
        "criteria": {
            "25s_real_scene_capture": {"duration_s": round(duration_s, 2), "status": status_c1},
            "11s_periodicity_elimination": {"max_corr_11s": round(max_corr_11s, 4), "status": status_c2},
            "true_peak_above_3k5hz": {"peak_dbfs": round(peak_above_3k5_dbfs, 2), "ceiling_dbfs": -6.0, "status": status_c3},
            "distance_culling_450px": {"amp_200px": round(amp_200px, 5), "amp_600px": round(amp_600px, 5), "is_culled": is_culled_flag, "status": status_c4}
        }
    }
    
    out_file = CAPTURES_DIR.parent / "analysis" / "campfire_hybrid_qa_verification.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(summary_report, f, indent=2)
    print(f"\nRapor kaydedildi: {out_file}")

if __name__ == "__main__":
    main()
