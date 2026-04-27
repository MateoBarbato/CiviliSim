# CiviliSim — Godot 4.x Agent Notes

## Godot Version & Tooling

- **Godot 4.6.2** — `Vector2i` (lowercase i), `TYPE_SIMPLEX` (not PERLIN_SIMPLEX)
- **C# removed** — GDScript only. `CiviliSim.csproj` is stale, ignore it.
- **Godot binary**: `/opt/homebrew/bin/godot`
- **Headless test**: `godot --headless --run-main-scene --quit 2>&1` (SpriteFrame texture errors are expected, non-fatal)
- **Godot MCP server**: Connected. Use `listToolFiles` → `readToolFile` → `executeToolCode` to interact with Godot at runtime (scene tree inspection, node queries, signal checks, etc.)

## Repository Layout

- `scenes/` — Godot scenes (`.tscn`) and attached scripts
- `scripts/data/` — Autoload singletons: `GameConfig`, `BuildingType`, `ResourceType`
- `scripts/systems/` — `ColonyManager`, `ResourceManager`, `DecisionSystem`, `ReproductionSystem`, `SpawnManager`
- `scripts/core/` — `ScriptLoader` (runtime input action registration)
- `scripts/agents/` — `BeepStats`
- `scenes/world/` — Procedural terrain (FastNoiseLite), resource/beep spawning
- `scenes/beep/` — BeepAgent (autonomous agents)
- `scenes/resources/` — Resource nodes on the map
- `scenes/camera/` — CameraController (WASD, mouse wheel zoom)
- `scenes/ui/` — DecisionPanel, DebugConsole
- `test/` — GdUnit4 tests

## Viewport Architecture (Critical)

Root is a `Control` (`layout_mode = 3`, canvas_all) with two children:

1. **SubViewportContainer** (80% left, `anchors_preset = 15`): displays the game world
   - **GameViewport** (SubViewport): `size = Vector2i(2, 2)` with `size_2d_override_stretch = true` — stretches to fill container
   - Camera2D at `(1600, 1600)` with `zoom = 0.5`, has `CameraController.gd` attached
   - DecisionSystem and ReproductionSystem sit inside GameViewport
   - World scene is **instantiated dynamically** in `Main._ready()` via `game_viewport.add_child(world)`
2. **Sidebar** (VBoxContainer, 20% right): StatsPanel (SHRINK) → Separator → DecisionPanel (FILL)

**Input flow**: `Main._input()` forwards every event to `game_viewport.push_input(event)`. CameraController reads keys directly (`KEY_W/A/S/D`) in `_process`. No input actions exist in `project.godot` — all actions registered at runtime in `ScriptLoader`.

**MarginContainers inside Panels**: use `layout_mode = 1` with `anchors_preset = 15` to fill the Panel. Children inside margin containers use `layout_mode = 2` (container-relative).

**decision_panel.gd**: extends `Panel` (not `Control`).

## Autoloads

7 autoloads in `project.godot`: ScriptLoader, GameConfig, BuildingType, ResourceType, ColonyManager, ResourceManager. All globally accessible (`ColonyManager.population`, `ResourceManager.add_food()`, etc.)

## Key Conventions

- Commit format: `type: description` (feat, fix, refactor, docs, test, chore)
- Behavior Tree evaluation every **0.5s** (not per-frame)
- World: 200×200 tiles × 16px = 3200×3200 px
- Game auto-starts (no menu), pauses on `ui_pause` action
- SpriteFrame texture errors in headless mode are expected (no art assets yet)
