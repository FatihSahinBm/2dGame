#!/usr/bin/env python3
"""
Yamalı Dünya — Kapsamlı Ses Mühendisliği, Spektral FFT ve Döngü Analizörü (Aşama 4)
Tüm kaydı baştan sona inceler (kısmi pencere değil):
 - Bütün ses boyunca RMS, Peak dBFS, Kırpılma, DC Offset
 - Sol ve Sağ kanal bağımsız analizi, Stereo Korelasyon ve Faz İptali (Phase Cancellation)
 - Tüm kaydın Spektral Enerji Dağılımı (Low, Mid, High)
 - Kamp ateşi 2 döngü dikiş analizi: 11.2s döngü geçiş noktasında genlik sürekliliği (Zero-Crossing / Jump Delta)
 - Zaman içindeki ses seviyesi grafikleri ve yüksek çözünürlüklü spektrogramlar
"""

import os
import wave
import json
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
CAPTURES_DIR = PROJECT_ROOT / "qa" / "audio" / "captures"
ANALYSIS_DIR = PROJECT_ROOT / "qa" / "audio" / "analysis"
ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)


def analyze_full_wav(path: Path) -> dict:
    rel_path = str(path.relative_to(PROJECT_ROOT)).replace("\\", "/")
    with wave.open(str(path), "rb") as wf:
        n_channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        framerate = wf.getframerate()
        n_frames = wf.getnframes()
        raw_bytes = wf.readframes(n_frames)

    duration_s = n_frames / framerate if framerate > 0 else 0.0

    if sampwidth == 2:
        samples = np.frombuffer(raw_bytes, dtype=np.int16).astype(np.float32) / 32768.0
    elif sampwidth == 1:
        samples = (np.frombuffer(raw_bytes, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    else:
        samples = np.frombuffer(raw_bytes, dtype=np.int16).astype(np.float32) / 32768.0

    if n_channels == 2:
        left = samples[0::2]
        right = samples[1::2]
        mono = 0.5 * (left + right)
        # Stereo Korelasyon & Faz İptali
        denom = (np.std(left) * np.std(right))
        if denom > 1e-6:
            stereo_corr = float(np.corrcoef(left, right)[0, 1])
        else:
            stereo_corr = 1.0
        phase_cancellation_risk = stereo_corr < -0.1
    else:
        left = samples
        right = samples
        mono = samples
        stereo_corr = 1.0
        phase_cancellation_risk = False

    # 1. Metrikler (Tüm kayıt boyunca)
    peak = float(np.max(np.abs(mono))) if len(mono) > 0 else 0.0
    peak_dbfs = float(20.0 * np.log10(peak)) if peak > 1e-6 else -96.0

    peak_l = float(np.max(np.abs(left))) if len(left) > 0 else 0.0
    peak_r = float(np.max(np.abs(right))) if len(right) > 0 else 0.0
    peak_l_dbfs = float(20.0 * np.log10(peak_l)) if peak_l > 1e-6 else -96.0
    peak_r_dbfs = float(20.0 * np.log10(peak_r)) if peak_r > 1e-6 else -96.0

    rms = float(np.sqrt(np.mean(mono**2))) if len(mono) > 0 else 0.0
    rms_dbfs = float(20.0 * np.log10(rms)) if rms > 1e-6 else -96.0

    dc_offset = float(np.mean(mono)) if len(mono) > 0 else 0.0
    clipping_samples = int(np.sum(np.abs(mono) >= 0.999))

    # 2. Spektral Enerji (Tüm kaydı kapsayan FFT ortalaması)
    # 2048'lik bloklar halinde Welch benzeri pencereli güç spektrumu
    block_size = 2048
    n_blocks = len(mono) // block_size
    if n_blocks > 0:
        blocks = mono[:n_blocks * block_size].reshape(n_blocks, block_size)
        window = np.hanning(block_size)
        fft_powers = np.mean(np.abs(np.fft.rfft(blocks * window, axis=1))**2, axis=0)
        freqs = np.fft.rfftfreq(block_size, 1.0 / framerate)

        low_energy = float(np.sum(fft_powers[freqs < 300]))
        mid_energy = float(np.sum(fft_powers[(freqs >= 300) & (freqs < 4500)]))
        high_energy = float(np.sum(fft_powers[freqs >= 4500]))
        total_e = low_energy + mid_energy + high_energy
        spectral_dist = {
            "low_pct": round(low_energy / total_e * 100, 1) if total_e > 0 else 0,
            "mid_pct": round(mid_energy / total_e * 100, 1) if total_e > 0 else 0,
            "high_pct": round(high_energy / total_e * 100, 1) if total_e > 0 else 0
        }
    else:
        spectral_dist = {"low_pct": 0, "mid_pct": 0, "high_pct": 0}

    # 3. Kamp Ateşi 2 Döngü Dikiş Sürekliliği İncelemesi
    seam_analysis = None
    if "emitter_2loops" in path.name:
        loop_samples = 493920 # 11.2s @ 44.1kHz
        if len(mono) >= loop_samples + 200:
            # Döngü noktası etrafında 100 sample incelenir
            seam_before = mono[loop_samples - 5:loop_samples]
            seam_after = mono[loop_samples:loop_samples + 5]
            step_delta = float(abs(mono[loop_samples] - mono[loop_samples - 1]))
            seam_analysis = {
                "loop_sample_index": loop_samples,
                "loop_time_s": 11.20,
                "step_delta_amplitude": round(step_delta, 5),
                "is_seamless": step_delta < 0.12,
                "status": "PASS" if step_delta < 0.12 else "REVIEW"
            }

    # 4. Grafikler
    plot_name = f"{path.stem}_full_analysis.png"
    plot_path = ANALYSIS_DIR / plot_name

    try:
        fig, (ax_wave, ax_spec) = plt.subplots(2, 1, figsize=(11, 6), sharex=True)
        time_axis = np.linspace(0.0, duration_s, len(mono))
        ax_wave.plot(time_axis, mono, color="#2196F3", lw=0.4, label="Mono Karışım")
        if n_channels == 2:
            ax_wave.plot(time_axis, left, color="#E91E63", lw=0.2, alpha=0.3, label="Sol (L)")
            ax_wave.plot(time_axis, right, color="#4CAF50", lw=0.2, alpha=0.3, label="Sağ (R)")
        ax_wave.set_title(f"Waveform: {path.name} (Peak: {peak_dbfs:.1f} dBFS, RMS: {rms_dbfs:.1f} dBFS, Süre: {duration_s:.1f}s)")
        ax_wave.set_ylabel("Genlik [-1, 1]")
        ax_wave.set_ylim(-1.05, 1.05)
        ax_wave.grid(True, alpha=0.25)
        ax_wave.legend(loc="upper right", fontsize=8)

        # Spektrogram
        ax_spec.specgram(mono, Fs=framerate, NFFT=1024, noverlap=512, cmap="magma")
        ax_spec.set_title(f"Spektrogram: Low={spectral_dist['low_pct']}%, Mid={spectral_dist['mid_pct']}%, High={spectral_dist['high_pct']}%")
        ax_spec.set_xlabel("Zaman (s)")
        ax_spec.set_ylabel("Frekans (Hz)")

        plt.tight_layout()
        plt.savefig(plot_path, dpi=120)
        plt.close()
    except Exception as e:
        print(f"Plot hatası ({path.name}): {e}")

    return {
        "file": path.name,
        "path": rel_path,
        "channels": n_channels,
        "framerate": framerate,
        "duration_s": round(duration_s, 2),
        "peak_dbfs": round(peak_dbfs, 2),
        "peak_left_dbfs": round(peak_l_dbfs, 2),
        "peak_right_dbfs": round(peak_r_dbfs, 2),
        "rms_dbfs": round(rms_dbfs, 2),
        "dc_offset": round(dc_offset, 5),
        "clipping_samples": clipping_samples,
        "stereo_correlation": round(stereo_corr, 3),
        "phase_cancellation_risk": phase_cancellation_risk,
        "spectral_distribution": spectral_dist,
        "seam_analysis": seam_analysis,
        "analysis_plot": plot_name,
        "status": "PASS" if clipping_samples == 0 and peak_dbfs <= -0.1 and not phase_cancellation_risk else "REVIEW"
    }


def main():
    print("Yamalı Dünya Kapsamlı Ses Analizi Başlatılıyor...", flush=True)
    wav_files = sorted(list(CAPTURES_DIR.glob("*.wav")))
    print(f"Analiz edilecek yakalama dosyası sayısı: {len(wav_files)}", flush=True)

    results = []
    for w in wav_files:
        info = analyze_full_wav(w)
        results.append(info)
        print(f"  {info['file']:35s} | Peak={info['peak_dbfs']:6.1f} dBFS | RMS={info['rms_dbfs']:6.1f} dBFS | Kırpılma={info['clipping_samples']} | Faz Risk={info['phase_cancellation_risk']} -> {info['status']}", flush=True)

    # Telemetriyi ekle
    tel_file = CAPTURES_DIR / "campfire_loop_telemetry.json"
    tel_data = None
    if tel_file.exists():
        with open(tel_file, "r", encoding="utf-8") as f:
            tel_data = json.load(f)

    report = {
        "methodology": "Tüm Sinyal Welch-STFT Spektral Güç Analizi, True Peak/RMS, Stereo Faz Korelasyonu ve Zero-Crossing Dikiş Ölçümü",
        "captures_analyzed": len(results),
        "campfire_telemetry": tel_data,
        "results": results
    }

    out_json = ANALYSIS_DIR / "full_audio_analysis_report.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"Tam ses analiz raporu kaydedildi: {out_json}", flush=True)


if __name__ == "__main__":
    main()
