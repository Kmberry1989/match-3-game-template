This repository is a Godot-based Match-3 game template. The following notes are focused, actionable guidance to help AI coding agents be productive editing and extending this project.

Key areas to read first
- Scenes/: contains the main scenes. Start with `Scenes/Game.tscn`, `Scenes/GameUI.tscn`, and `Scenes/Dot.tscn` to understand entity structure and node hierarchies.
- Scripts/: gameplay logic lives here. Important files:
  - `Scripts/Grid.gd` — core matchfinding, spawning, input handling, and game loop (grid coordinate ↔ pixel mapping).
  - `Scripts/Dot.gd` — per-dot visuals and animations (textures, tweens, state machine for idle/blink/match).
  - `Scripts/GameUI.gd`, `Scripts/PlayerManager.gd`, `Scripts/NetworkManager.gd`, `Scripts/AudioManager.gd` — UI, persistence, multiplayer glue, and audio.

Big-picture architecture
- Single-process Godot game: Scenes are composed of Nodes; logic is GDScript in `Scripts/`.
- Responsibilities:
  - Grid.gd: game state, spawn/destroy/refill logic, match detection, timers and score updates.
  - Dot.gd: individual dot behavior, animations, and textures. Dots are instances of `Scenes/Dots/*.tscn`.
  - GameUI.gd: displays score, player names and feeds events from Grid.
  - NetworkManager.gd: optional WebSocket-based multiplayer; Grid checks `NetworkManager.peer` to decide multiplayer flows.

Conventions & patterns (project-specific)
- Indexing/loops: code uses numeric width/height exported properties. Iterate with `for i in range(width):` not `for i in width:` (many files already follow this after fixes).
- Grid coordinates: `grid_to_pixel(column,row)` and `pixel_to_grid(x,y)` are the single source of truth for placement. Use these when moving dots.
- Timers & tweens: Many animations use `get_tree().create_tween()` and `Timer.new()` nodes. For repeating tweens, the project uses `set_loops(-1)` to make intent explicit.
- Textures: Dot textures are loaded from `res://Assets/Dots/<character>avatar*.png`. Use `Dot.color` → `color_to_character` mapping in `Dot.gd` when adding new colors/characters.
- Time API: project mixes `Time.get_unix_time_from_system()` and `OS.get_ticks_msec()` in places — do not globally change API without confirming the Godot engine version used by the project.

Developer workflows
- Open the project in Godot Editor (recommended) for scene inspection and runtime testing. The project root contains `project.godot`.
- Quick manual smoke tests:
  - Open `Scenes/Game.tscn` and press Play (F5) to run the main scene.
  - Use the Godot Output/Debugger to see runtime errors (missing nodes, API mismatches).
- Linting/build: There is no automated build file. Validate GDScript by running in the Godot editor or using `godot --script` checks if available locally.

Integration points & external deps
- NetworkManager (WebSocket): `Scripts/NetworkManager.gd` exposes a `peer` and signals `opponent_score_updated`, `server_disconnected` used by `Grid.gd` for multiplayer state. Treat multiplayer code paths as optional; check `is_multiplayer` guard before changes.
- PlayerManager: responsible for persisting player data (score, objectives). `Grid.gd` calls `PlayerManager.save_player_data()` on disconnect.
- AudioManager: central audio playback via `AudioManager.play_sound(name)`; reuse its keys for new sounds.

Safe automated edits an AI can perform
- Fix invalid loop constructs (e.g., change `for i in width:` → `for i in range(width):`). Example: `Grid.gd`.
- Initialize typed node/tween vars to `null` to avoid static warnings (e.g., `var tween: Tween = null`). Example: `Background.gd`, `Dot.gd`.
- Make infinite tweens explicit: use `.set_loops(-1)` rather than `.set_loops()` with no args. Example: `Dot.gd` and `Background.gd`.
- Repair obvious identifier typos (`self_modulate` → `modulate`). Example: `Background.gd`.

Risky changes to avoid without confirmation
- Global time API normalization (Time.* → OS.*) — may break compatibility with target Godot version. Ask which Godot version is used before changing.
- Renaming exported properties or scene node names — will break scene references; update scenes accordingly.

Examples to reference when coding
- Spawn and avoid immediate matches: see `Grid.gd` spawn loop which re-rolls a dot if it creates a match (limit 100 tries).
- Dot visuals: `Dot.gd` uses `create_shadow()`, `start_floating()` and `start_pulsing()` to drive continuous visual behavior — create similar patterns for new visual nodes.

If you add or change scenes
- Keep exported property names intact (width, height, offset, y_offset) to preserve scene compatibility.
- When moving or renaming nodes referenced by `get_node()` calls (e.g., `game_ui = get_node("../GameUI")`), update all call sites.

Guidance for Code Review by AI
- Prefer small, local edits. Run the project in Godot after changes to catch API/scene binding issues.
- When changing Time/OS APIs, include a short compatibility note and run the game to validate no static errors appear.

Questions for maintainers
- Which Godot engine version is the canonical target for this project (3.x or 4.x)?

If anything above is unclear or you want more detail (engine version normalization plan, or an automated repo-wide pass for the "safe" edits listed), tell me and I will iterate.
