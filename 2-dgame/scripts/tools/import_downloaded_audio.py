import os
import sys
import shutil
import glob
import time
import numpy as np
from scipy.io import wavfile
import re

PROJECT_ROOT = r"C:\Projects\2dgame\2-dgame"
STAGING_DIR = os.path.join(PROJECT_ROOT, "ses_efektleri")
DOWNLOADS_DIR = os.path.expanduser(r"~\Downloads")
SFX_DIR = os.path.join(PROJECT_ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(PROJECT_ROOT, "assets", "audio", "music")

os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUSIC_DIR, exist_ok=True)
os.makedirs(STAGING_DIR, exist_ok=True)

TARGET_MAPPINGS = {
    # 1. Karakter & Hareket (Player & Movement)
    "jump": ["jump", "zipla", "hop", "leap"],
    "dash": ["dash", "atilma", "dodge", "kayma"],
    "player_hurt": ["player_hurt", "hurt", "hasar", "inleme", "damage"],
    "player_death": ["player_death", "death", "olum", "defeat_fall"],

    # 2. Yakın Dövüş & Savunma (Combat & Sword)
    "sword_slash": ["sword_slash", "slash", "kilic_savur", "blade_slice"],
    "sword_hit": ["sword_hit", "sword_strike", "vurus", "kilic_vurus", "cleave"],
    "parry_clang": ["parry_clang", "parry", "deflect", "clash", "sekme", "savusturma"],
    "sword_rebellion_whisper": ["rebellion", "whisper", "isyan", "fisilti", "corruption"],

    # 3. İkincil Fırlatılabilir Eşyalar (Secondary Throwables)
    "throw_item": ["throw_item", "throw", "firlat", "toss"],
    "knife_hit": ["knife_hit", "knife", "bicak", "dagger"],
    "torch_burn": ["torch_burn", "burn", "tutustur", "ates_yak", "flame_burst"],
    "holy_water_shatter": ["holy_water", "shatter", "kirilma", "kutsal_su", "vial"],
    "empty_ammo": ["empty_ammo", "empty", "tik", "bos_tetik", "no_ammo"],

    # 4. Çevre, Tuzaklar & Mekanizmalar (Environment & Traps & Interactive)
    "campfire": ["campfire", "fire", "ates", "kamp_atesi", "crackle"],
    "checkpoint_activated": ["checkpoint", "chime", "bell_chime", "zil", "kayit_noktasi"],
    "rest_heal": ["rest_heal", "rest", "heal", "dinlen", "melodi", "harp", "kanun"],
    "spike_trap": ["spike_trap", "spike", "tuzak", "trap", "spring", "kazik"],
    "guillotine_swing": ["guillotine", "wind", "ruzgar", "pendulum", "giyotin"],
    "platform_crumble": ["platform_crumble", "crumble", "coken", "cokus", "rock_crack"],
    "platform_restore": ["platform_restore", "restore", "birlesti", "yenilenme"],
    "torch": ["torch", "mesale", "flame_loop"],
    "dungeon_drip": ["drip", "water_drip", "damla", "su_damlasi"],
    "waterfall": ["waterfall", "selale", "water_roar"],
    "bell_toll": ["bell_toll", "bell", "can_sesi", "cathedral_bell"],

    # 5. Düşmanlar & Yaratıklar & Boss'lar (Enemies & Bosses)
    "enemy_step": ["enemy_step", "step", "ayak_sesi", "footstep"],
    "boss_roar": ["boss_roar", "roar", "kukreme", "monster_growl"],
    "mist_dash": ["mist_dash", "mist", "sis", "vampire_mist"],
    "blood_shield": ["blood_shield", "blood_barrier", "kan_kalkani"],
    "blood_magic": ["blood_magic", "dark_magic", "kan_buyusu"],
    "werewolf_claw": ["werewolf_claw", "claw", "pence", "kurtadam_pence"],
    "werewolf_leap": ["werewolf_leap", "slam", "kurtadam_darbe", "ground_slam"],
    "bat_scream": ["bat_scream", "scream", "ciglik", "yarasa_ciglik"],
    "bat_dive": ["bat_dive", "dive", "swoop", "dalis"],

    # 6. Arayüz, Kitaplar & Görevler (UI, Inventory, Codex & Quests)
    "ui_click": ["ui_click", "click", "tiklama", "button_press"],
    "inventory_open": ["inventory_open", "bag_open", "canta_ac"],
    "inventory_close": ["inventory_close", "bag_close", "canta_kapat"],
    "potion_drink": ["potion_drink", "potion", "drink", "iksir", "gulp"],
    "item_equip": ["item_equip", "equip", "kusan", "armor_clink"],
    "codex_open": ["codex_open", "book_open", "kitap_ac"],
    "codex_close": ["codex_close", "book_close", "kitap_kapat"],
    "page_turn": ["page_turn", "page", "turn", "sayfa", "paper"],
    "codex_unlock": ["codex_unlock", "unlock", "kilit_acildi", "discovery"],
    "quest_log_open": ["quest_log_open", "scroll_open", "parsumen_ac"],
    "quest_log_close": ["quest_log_close", "scroll_close", "parsumen_kapat"],
    "objective_complete": ["objective_complete", "objective", "hedef"],
    "quest_complete": ["quest_complete", "quest", "complete", "gorev", "fanfare", "victory_short"],

    # 7. Müzik & Ambiyans (Music & Ambience)
    "combat_theme": ["combat", "battle", "savas", "dovus"],
    "menu_theme": ["menu_theme", "main_theme", "giris", "intro"],
    "camp_ambience": ["camp_ambience", "ordugah", "gece_kamp", "night_camp"],
    "vlad_theme": ["vlad_theme", "vlad_boss", "gothic_theme"],
    "vlad_ambience": ["vlad_ambience", "dungeon_ambience", "zindan_ruzgar"],
    "prehistoric_theme": ["prehistoric_theme", "stone_age", "tas_devri"],
    "prehistoric_ambience": ["prehistoric_ambience", "cave", "magara"]
}

def identify_target(filename: str):
    name_clean = os.path.splitext(os.path.basename(filename))[0].lower().strip()
    
    # 1. Tam birebir eşleşme (örn: "sword_slash.wav" -> "sword_slash")
    if name_clean in TARGET_MAPPINGS:
        return name_clean

    # 2. Ön ek veya alt tire temizleme (örn: "sfx_sword_slash", "01_jump")
    for target in TARGET_MAPPINGS:
        if name_clean.endswith(f"_{target}") or name_clean.startswith(f"{target}_") or f"_{target}_" in name_clean:
            return target

    # 3. İsimde doğrudan hedef adın geçmesi (örn: "hero_sword_slash_v2")
    for target in TARGET_MAPPINGS:
        if target in name_clean:
            return target

    # 4. Belirli ayrık kelime / anahtar kelime eşleşmesi
    # Kelimeleri ayırarak eşleştir (Örn: "counter-strike" gibi ilgisiz dosyaları engellemek için)
    words = re.findall(r'[a-zA-Z0-9_]+', name_clean)
    for target, keywords in TARGET_MAPPINGS.items():
        for kw in keywords:
            if kw in words:
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
    
    # Check format & convert to 16-bit 44.1kHz PCM WAV
    ext = os.path.splitext(src_path)[1].lower()
    if ext == ".wav":
        try:
            sr, data = wavfile.read(src_path)
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
        # mp3 or ogg -> direct copy
        shutil.copy2(src_path, os.path.join(dest_dir, f"{target}{ext}"))

    print(f"SUCCESS: {target} imported successfully into {dest_dir}!")
    return True

def scan_directory(folder_path: str):
    if not os.path.exists(folder_path):
        print(f"Directory not found: {folder_path}")
        return 0

    print(f"Scanning '{folder_path}' for audio files...")
    extensions = ["*.wav", "*.mp3", "*.ogg"]
    found_files = []
    for ext in extensions:
        found_files.extend(glob.glob(os.path.join(folder_path, ext)))

    if not found_files:
        print(f"No audio files found in '{folder_path}'.")
        return 0

    imported_count = 0
    for f in found_files:
        if import_file(f):
            imported_count += 1

    print(f"\nScan complete for '{folder_path}'. Total files imported: {imported_count}")
    return imported_count

if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg_path = sys.argv[1]
        if os.path.isdir(arg_path):
            scan_directory(arg_path)
        elif os.path.isfile(arg_path):
            import_file(arg_path)
        else:
            print(f"Invalid path: {arg_path}")
    else:
        # First check project's staging folder
        count = scan_directory(STAGING_DIR)
        if count == 0:
            # Fallback to Downloads folder
            scan_directory(DOWNLOADS_DIR)
