import os
import sys
import shutil
import glob
import time
import numpy as np
from scipy.io import wavfile

DOWNLOADS_DIR = os.path.expanduser(r"~\Downloads")
PROJECT_ROOT = r"C:\Projects\2dgame\2-dgame"
SFX_DIR = os.path.join(PROJECT_ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(PROJECT_ROOT, "assets", "audio", "music")

os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUSIC_DIR, exist_ok=True)

TARGET_MAPPINGS = {
    # SFX
    "sword_slash": ["slash", "swing", "whoosh", "swoosh", "kilic_savur"],
    "sword_hit": ["sword_hit", "hit", "strike", "impact", "cleave", "vurus"],
    "parry_clang": ["parry", "clang", "deflect", "clash", "sekme"],
    "guillotine_swing": ["guillotine", "wind", "ruzgar", "pendulum", "giyotin"],
    "spike_trap": ["spike", "tuzak", "trap", "spring", "kazik"],
    "campfire": ["campfire", "fire", "ates", "flame", "crackle"],
    "checkpoint_activated": ["checkpoint", "chime", "bell_chime", "zil"],
    "rest_heal": ["rest", "heal", "dinlen", "melodi", "harp", "kanun"],
    "page_turn": ["page", "turn", "sayfa", "paper"],
    "codex_open": ["codex_open", "book_open", "kitap_ac"],
    "codex_close": ["codex_close", "book_close", "kitap_kapat"],
    "inventory_open": ["inventory_open", "bag_open", "canta_ac"],
    "inventory_close": ["inventory_close", "bag_close", "canta_kapat"],
    "quest_complete": ["quest", "complete", "gorev", "fanfare", "victory_short"],
    
    # Music & Ambience
    "combat_theme": ["combat", "battle", "savas", "dovus"],
    "menu_theme": ["menu", "main_theme", "giris", "intro"],
    "camp_ambience": ["camp_ambience", "ordugah", "gece_kamp", "night_camp"],
    "vlad_theme": ["vlad_theme", "vlad_boss", "gothic_theme"],
    "vlad_ambience": ["vlad_ambience", "dungeon_ambience", "zindan_ruzgar"],
    "prehistoric_theme": ["prehistoric", "stone_age", "tas_devri"],
    "prehistoric_ambience": ["prehistoric_ambience", "cave", "magara"]
}

def identify_target(filename: str):
    name_lower = os.path.splitext(os.path.basename(filename))[0].lower()
    
    # Direct match first
    for target in TARGET_MAPPINGS:
        if target in name_lower:
            return target
            
    # Keyword match
    for target, keywords in TARGET_MAPPINGS.items():
        for kw in keywords:
            if kw in name_lower:
                return target
    return None

def import_file(src_path: str):
    target = identify_target(src_path)
    if not target:
        print(f"Skipping '{os.path.basename(src_path)}': could not determine target sound.")
        return False

    is_music = "theme" in target or "ambience" in target
    dest_dir = MUSIC_DIR if is_music else SFX_DIR
    dest_file = os.path.join(dest_dir, f"{target}.wav")

    print(f"Importing '{os.path.basename(src_path)}' -> '{dest_file}'...")
    
    # Check format
    ext = os.path.splitext(src_path)[1].lower()
    if ext == ".wav":
        try:
            sr, data = wavfile.read(src_path)
            # Ensure float / standard 16-bit PCM
            if data.dtype != np.int16:
                if np.issubdtype(data.dtype, np.floating):
                    data = np.clip(data, -1.0, 1.0)
                    data = (data * 32767.0).astype(np.int16)
                else:
                    data = data.astype(np.int16)
            wavfile.write(dest_file, sr, data)
        except Exception as e:
            print(f"Direct WAV copy fallback due to: {e}")
            shutil.copy2(src_path, dest_file)
    else:
        # If mp3 or ogg, copy directly with same extension or convert
        shutil.copy2(src_path, os.path.join(dest_dir, f"{target}{ext}"))

    print(f"SUCCESS: {target} imported successfully into {dest_dir}!")
    return True

def scan_downloads():
    print(f"Scanning '{DOWNLOADS_DIR}' for new audio files...")
    extensions = ["*.wav", "*.mp3", "*.ogg"]
    found_files = []
    for ext in extensions:
        found_files.extend(glob.glob(os.path.join(DOWNLOADS_DIR, ext)))

    # Sort by modification time, newest first
    found_files.sort(key=os.path.getmtime, reverse=True)
    recent_audio = [f for f in found_files if time.time() - os.path.getmtime(f) < 7200] # last 2 hours

    if not recent_audio:
        print("No recent audio files found in Downloads folder (within last 2 hours).")
        return 0

    imported_count = 0
    for f in recent_audio:
        if import_file(f):
            imported_count += 1

    print(f"Scan complete. Total files imported: {imported_count}")
    return imported_count

if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Specific file passed
        import_file(sys.argv[1])
    else:
        scan_downloads()

