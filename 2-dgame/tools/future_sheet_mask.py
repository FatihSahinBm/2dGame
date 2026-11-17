# -*- coding: utf-8 -*-
"""Bölüm 5 (2D-158) kaynak sheet'leri için arka plan ayrıştırma çekirdeği.

Gemini/AI ile üretilmiş sheet'lerde arka plan düz değil (koyu lacivert + vinyet + nokta ızgarası)
ve karakterlerin koyu zırhı arka planla neredeyse aynı tonda. Bu yüzden extract_new_blood_knight.py'deki
sabit renk eşiği yerine "arka plan taşma dolgusu" kullanılır:
  1) Yerel arka plan rengi 1/16 ölçekte %20'lik dilimle tahmin edilip yumuşatılır (vinyet/gradyan telafisi).
  2) Yerel arka plana çok yakın (BG_TOL) pikseller aday arka plandır; bunlardan yalnızca büyük bağlı
     bölgeler (gerçek boşluk) arka plan sayılır. Silüet içindeki koyu zırh alanları küçük/kapalı kaldığı
     için opak kalır.
  3) Silüet kenarında alfa, farka göre yumuşak rampalanır; neon parıltı rengi arka plandan "un-mix" edilir.
  4) Küçük gürültü adacıkları (nokta ızgarası, JPEG artefaktı) bağlı bileşen analiziyle atılır.
"""
import numpy as np
from PIL import Image
from scipy import ndimage

BG_TOL = 6.0       # yerel arka plana bu farktan yakın pikseller aday arka plan
EDGE_T1 = 34.0     # kenar rampasında bu farkın üstü tamamen opak
MIN_BG_REGION = 900
MIN_BLOB = 60


def load_rgba(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)


def local_background(rgb, step=16, pct=20):
    h, w, _ = rgb.shape
    hh, ww = h // step, w // step
    small = rgb[: hh * step, : ww * step].reshape(hh, step, ww, step, 3)
    small = np.percentile(small, pct, axis=(1, 3))
    small = ndimage.median_filter(small, size=(9, 9, 1))
    small = ndimage.uniform_filter(small, size=(5, 5, 1))
    img = Image.fromarray(np.clip(small, 0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)
    return np.asarray(img).astype(np.float32)


def extract_alpha(rgba, bg_tol=BG_TOL):
    rgb = rgba[..., :3]
    src_a = rgba[..., 3] / 255.0
    bg = local_background(rgb)
    smooth = ndimage.uniform_filter(rgb, size=(3, 3, 1))
    diff = np.abs(smooth - bg).max(axis=2)
    cand = (diff < bg_tol) | (src_a < 0.1)
    cand = ndimage.binary_opening(cand, iterations=1)
    lab, n = ndimage.label(cand)
    bgmask = np.zeros_like(cand)
    if n:
        sizes = ndimage.sum(cand, lab, range(1, n + 1))
        bgmask = np.isin(lab, np.where(sizes >= MIN_BG_REGION)[0] + 1)
    fg = ~bgmask
    lab, n = ndimage.label(fg)
    if n:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg &= ~np.isin(lab, np.where(sizes < MIN_BLOB)[0] + 1)
    raw_diff = np.abs(rgb - bg).max(axis=2)
    ramp = np.clip((raw_diff - bg_tol) / (EDGE_T1 - bg_tol), 0.0, 1.0)
    inner = ndimage.binary_erosion(fg, iterations=2)
    alpha = np.where(inner, 1.0, np.where(fg, np.maximum(ramp, 0.55), 0.0)) * src_a
    a = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - (1.0 - a) * bg) / a, 0, 255)
    color = np.where(alpha[..., None] > 0.9, rgb, color)
    return np.dstack([color, alpha * 255.0]), bg


def to_image(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
