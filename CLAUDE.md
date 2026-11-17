# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

Two corrections to `AGENTS.md`, which is stale on these points:

- **Autoloads exist.** Twelve are registered in `project.godot` (see Architecture).
- **The 300-line limit is already exceeded** by many scripts (`player.gd`, `audio_manager.gd`, `vlad_boss.gd`, `save_manager.gd`, …). Don't grow them; put new behaviour in a separate component script.

## Layout

The Godot project root is `2-dgame/`, not the repo root — `res://` maps to `2-dgame/`. Everything outside it (`ogre/`, `output/`, `dev.md`, `asset.md`) is sprite-pipeline reference material.

Comments, test output and player-facing source strings are Turkish; identifiers are English. All files are UTF-8 — when reading or writing through PowerShell 5.1, pass `-Encoding utf8` or Turkish characters get corrupted.

## Commands

Godot is not on `PATH`. The console build used on this machine (also hardcoded in `qa/playthrough/run_play.ps1`):

```powershell
$g = "C:\Users\bokeg\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
```

Run from `2-dgame/`:

```powershell
& $g --path .                                             # run the game (main menu)
& $g --path . res://scenes/levels/vlad/stage_1_camp.tscn  # run one scene directly
& $g --path . --editor                                    # open the editor
```

There is no build step, linter, or test framework (no GUT). Tests are standalone scripts that print `PASS:`/`FAIL:` lines and set the process exit code (0 = pass). There are two kinds, run differently:

```powershell
# 1. Scene runners: tests/verify_*.tscn (+ *_runner.gd), a few verify_*.tscn in the project root
& $g --headless --path . res://tests/verify_quest.tscn

# 2. `extends SceneTree` scripts: root verify_*.gd, tools/test_*.gd, tests/test_*.gd, tests/independent_qa_verifier.gd
& $g --headless --path . --script res://tools/test_vlad_all_scenes_load.gd
```

Check the first line of a test file (`extends SceneTree` vs `extends Node`) to know which form to use. Read `$LASTEXITCODE` for the result — Godot prints "ObjectDB instances leaked" / "resources still in use" at exit even on passing runs.

Other entry points:

- `qa/playthrough/run_play.ps1 -Mode scenario -Scenario PLAY-002` (or `-Mode campaign`) — input-driven bot playthrough. Runs in a **real window, not headless**; writes logs, screenshots and bug reports under `qa/playthrough/`. Exit 1 = FAIL, 2 = BLOCKED.
- `tools/capture_*.gd` — screenshot capture scripts (need a window, so no `--headless`).
- `tools/*.py`, `scripts/tools/*.py` — one-off asset generators (sprites, `.tres` SpriteFrames, SFX). `python 2-dgame/tools/test_vlad_integrity.py` is run from the **repo root**.
- `scratch/` is git-ignored.

## Architecture

### Autoloads (`scripts/autoloads/`)

| Autoload | Role |
| --- | --- |
| `GameState` | Run-wide story state: corruption/morality score, ally sacrifice counts, unlocked abilities, chapter-2 flags, `persistent_events` (bosses beaten, gates opened), `current_stage_path`. Drives the ending (`get_ending_alignment`). |
| `StoryDataLoader` | Loads and caches `data/story/chapter_*.json`; returns dialogue sequences already localized. |
| `QuestManager` / `CodexManager` | Quest and bestiary/lore state. Definitions are registered in code (`init_default_quests`, `init_default_codex`) with `*_en` sibling fields. Both expose `export_save_data` / `import_save_data`. |
| `SaveManager` | 3 slots at `user://savegame_slot_N.json`, schema-versioned, checksummed, with backup recovery. Also owns the in-memory checkpoint (`set_checkpoint`) and re-applies cached player stats after a scene load. |
| `SceneTransition` | Fade + `change_scene`; also updates `GameState.current_stage_path`, resets the checkpoint and autosaves. |
| `LocalizationManager` | Builds `Translation` objects for `tr`/`en` at startup from `data/translations/translations.json`. |
| `CinematicManager` | Tracks active cinematics by source id (`begin_cinematic` / `end_cinematic`, with a timeout safety reset), plus reduce-motion / reduce-flashing accessibility. |
| `CameraManager` | Prioritised screen shake, boss-arena camera bounds/zoom. |
| `AudioManager` | Bus setup, keyed SFX registry, positional audio, adaptive music state machine (exploration / combat / boss phases), ambience. |
| `InputControllerManager` | Gamepad detection, keyboard↔controller prompt glyphs, rumble. |
| `WeatherManager` | Weather effects. |

Several managers persist their own keys into the shared `user://game_settings.json` by read-merge-write; follow that pattern rather than overwriting the file.

**Autoloads are reached by path, not by global name**: `get_node_or_null("/root/GameState")` followed by `has_method` / `"prop" in node` checks. This is deliberate — it lets scenes and scripts load inside the `--script` test harnesses and in isolation. Keep new code consistent with it.

### Player

`scripts/player.gd` (`class_name Player`) is the full controller: movement, dash/slide/roll, wall jump, combo attacks, shield/parry, throwables, sword overlay. `scripts/combat/combat_test_player.gd` extends it with the chapter-2 mechanics (sword rebellion, heal, blood-mist dash).

Despite the name, **`scenes/combat/test_player.tscn` is the production player** — every level instances it as a node named `CombatPlayer`. `scenes/player.tscn` is only used by `main.tscn` and some verify scripts.

### Levels

Each level is one scene plus one root script in `scripts/levels/<chapter>/`. The script owns everything level-specific: camera limits, HUD setup, trigger wiring, quest advancement, and the hardcoded path of the next scene. Levels instance `CombatPlayer`, `FantasyHUD` and usually `DialogueBox` as direct children.

Scene flow:

- **Main menu / chapter select** → `stone_age/stage_1_prehistoric_valley` → `stone_age/stage_2_trex_boss_arena` → `stoneage/stoneage_08_first_heart_fragment` → `vlad/stage_1_forest_camp` → `stage_1_camp` → `stage_1_fatih_tent` → `stage_1_bridge_assault` → `stage_2_castle_dungeon` → `stage_3_throne_room`.
- `stoneage/stoneage_01` … `07` is a newer, more granular stone-age chain (01→02→…→07) that is **not yet reachable from the menu**. Note the two directories: `stone_age/` (original two stages) and `stoneage/` (numbered levels).

Level-to-level transitions do their own fade and call `get_tree().change_scene_to_file` directly; only the main and pause menus go through `SceneTransition`. So the autosave in `SceneTransition.change_scene` does not fire between levels — mid-run progress is saved by `CampfireCheckpoint` → `SaveManager.set_checkpoint`.

### Story text and localization

Two separate mechanisms:

- **Dialogue** lives in `data/story/chapter_N_*.json` under `dialogues.<key>` as an array of entries (`speaker`, `title`, `text`, `portrait`, optional `choices`), each with an `_en` sibling (`text_en`, `speaker_en`, …). Play it with `dialogue_box.start_dialogue_from_data("<key>", speaker_node)`; fetch raw with `StoryDataLoader.get_dialogue_sequence("<key>")`. Lookup tries the active chapter, then the others.
- **UI strings** go through `tr()` against `data/translations/translations.json`, whose keys are either `UPPER_SNAKE` ids or the literal Turkish source string. The JSON is what the game loads at runtime; `translations.csv` (and its generated `.translation` files) mirror it and are kept in sync by hand — update both.

Turkish is the default and fallback locale. Any new player-facing string needs both `tr` and `en`.

### Combat conventions

- Damage is duck-typed: anything hittable implements `take_damage(amount, ...)` and joins the `damageable` group. Extra parameters vary by script, so check the target's signature.
- Groups carry most cross-object lookup: `player`, `enemies`, `allies`, `damageable`, `burnable`, `interactables`, `reflectable_projectile`, `player_projectiles`.
- Physics layers are unnamed in `project.godot`; the convention in code is bit 1 = world and character bodies, bit 2 = enemies, bit 3 (value 4) = barricades / interactables / hitboxes, bit 5 (value 16) = shield.
- Killing or sacrificing allies raises `GameState` corruption, which triggers the sword-rebellion mechanic and shifts the ending.

### Rendering and physics settings worth knowing

1280×720 viewport, `canvas_items` stretch with scale 1.35, nearest-neighbour texture filtering (pixel art), 120 physics ticks/s, gravity 1200.
