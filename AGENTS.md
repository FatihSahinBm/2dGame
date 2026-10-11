# AGENTS.md - 2D Story Game Guidelines

- **Project**: Godot 4.x (Forward+ / 4.7), GDScript, 2D story-driven game targeting Steam.
- **Directory Map**: `2-dgame/{assets, scenes, scripts, tools, project.godot}`, `.agents/`, `ogre/`, `output/`.
- **Autoloads**: None currently registered in `project.godot`.
- **Response Rules**: Be concise. Explain only when asked. Output only modified lines/diffs; never rewrite whole files. Provide max 3 lines summary upon task completion.
- **File Access**: Read only relevant target files before editing. Do not scan whole codebase. Never read `.godot/`, `*.import`, or `assets/`.
- **Code Standards**: Strict static typing (`x: Type = val`). Decouple via signals (`signal_name.emit()`). Global state allowed only in autoloads.
- **Data Architecture**: Do not hardcode dialogue or story narrative into code; store under `data/`.
- **Size Limit**: Maximum 300 lines per script; decompose into modular components if larger.
