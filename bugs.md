# Bug Tracking - CiviliSim MVP1
# Audit completado: 25 de Abril 2026

## CRITICAL (5) - El juego no funciona correctamente

### C1: start_game() desactiva el juego inmediatamente [FIXED]
**File:** `scripts/systems/colony_manager.gd:63-68`
**Desc:** `start_game()` setea `game_active = true`, pero luego llama `_init_colony()` que lo resetea a `false`
**Fix:** Reordenar: `_init_colony()` primero, luego `game_active = true`

### C2: game_time se incrementa doblemente [FIXED]
**File:** `scripts/systems/colony_manager.gd:45` + `scripts/systems/decision_system.gd:48`
**Desc:** Ambos scripts hacen `game_time += delta`, el tiempo avanza al doble
**Fix:** Remover incremento de `decision_system.gd`, que solo lea `ColonyManager.game_time`

### C3: GameConfig extiende RefCounted (no puede ser Autoload) [FIXED]
**File:** `scripts/data/game_config.gd:5`
**Desc:** `extends RefCounted` no puede ser Autoload, debe ser `extends Node`
**Fix:** Cambiar a `extends Node`

### C4: _regenerate() nunca se llama (recursos no se regeneran) [FIXED]
**File:** `scenes/resources/ResourceNode.gd:108`
**Desc:** `_regenerate(delta)` definido pero nunca llamado desde `_process()`
**Fix:** Agregar `_process(delta)` que llame a `_regenerate(delta)`

### C5: _select_parents() retorna null pero declara Dictionary [FIXED]
**File:** `scripts/systems/reproduction_system.gd:93-96,110`
**Desc:** `-> Dictionary` pero retorna `null` en failure paths
**Fix:** Cambiar return type a `-> Dictionary?` o retornar `{}`

---

## HIGH (10) - Bugs importantes

### H1: Main.gd game_time no definido [FIXED]
**File:** `scenes/main/Main.gd:29`
**Desc:** `game_time += delta` pero `game_time` nunca declarado
**Fix:** Remover línea (ya gestionado por ColonyManager)

### H2: beep_behavior.gd script huérfano [FIXED]
**File:** `scripts/agents/beep_behavior.gd`
**Desc:** Script no attachado a ninguna escena
**Fix:** Remover si no se usa

### H3: World.gd terreno genera 40K iteraciones sin pintar [FIXED]
**File:** `scenes/world/World.gd:125-197`
**Desc:** `_generate_terrain()` hace 40K iteraciones, `_paint_terrain()` solo tiene `pass`
**Fix:** Remover código hasta que haya TileSet

### H4: Runtime load() en reproduction_system.gd [FIXED]
**File:** `scripts/systems/reproduction_system.gd:134`
**Desc:** `load("res://scenes/beep/beep.tscn")` en runtime
**Fix:** Usar `preload()` 

### H5: Runtime load() en BeepAgent.gd [FIXED]
**File:** `scenes/beep/BeepAgent.gd:262`
**Desc:** `load("res://scenes/buildings/shelter.tscn")` en runtime
**Fix:** Usar `preload()`

### H6: Runtime load() en beep_behavior.gd [FIXED]
**File:** `scripts/agents/beep_behavior.gd:37,42`
**Desc:** `load()` para C# scripts en runtime
**Fix:** Usar `preload()`

### H7: Shelter.gd usa string path en vez de class_name [FIXED]
**File:** `scenes/buildings/Shelter.gd:5`
**Desc:** `extends "res://scenes/buildings/Building.gd"` en vez de `extends BuildingBase`
**Fix:** Cambiar a `extends BuildingBase`

### H8: decision_panel.gd sintaxis Godot 3 deprecated [FIXED]
**File:** `scenes/ui/decision_panel.gd:65`
**Desc:** `button.connect("pressed", ...)` es Godot 3.x
**Fix:** Cambiar a `button.pressed.connect(...)`

### H9: "knowledge" effect silenciosamente perdido [FIXED]
**File:** `scripts/systems/decision_system.gd:405`
**Desc:** `_technology_event()` incluye `"knowledge": 20` pero `_apply_effects()` no tiene caso para `"knowledge"`
**Fix:** Agregar caso `"knowledge"` en `_apply_effects()`

### H10: _calculate_spawn_position usa Node en vez de Node2D [FIXED]
**File:** `scripts/systems/reproduction_system.gd:154`
**Desc:** `.position` es propiedad de Node2D, no de Node
**Fix:** Cambiar parameter types a `Node2D`

---

## MEDIUM (9) - Problemas de código

### M1: DebugLabel no existe en hud.tscn [FIXED]
**File:** `scenes/ui/GameUI.gd:74`
**Desc:** `get_node_or_null("DebugLabel")` siempre retorna null
**Fix:** Remover código

### M2: decision_panel llama método privado [FIXED]
**File:** `scenes/ui/decision_panel.gd:85`
**Desc:** `DecisionSystem._resolve_decision()` llama método privado
**Fix:** Renombrar a `resolve_decision()` (público)

### M3: _on_decision_panel_closed() dead code [FIXED]
**File:** `scenes/ui/decision_panel.gd:123-125`
**Desc:** Función definida pero nunca conectada
**Fix:** Remover

### M4: CameraController follow dead code [FIXED]
**File:** `scenes/camera/CameraController.gd:81-91`
**Desc:** `follow_beep()` y `_on_beep_moved()` nunca usados
**Fix:** Remover

### M5: CameraController missing class_name [FIXED]
**File:** `scenes/camera/CameraController.gd:4`
**Desc:** No tiene `class_name CameraController`
**Fix:** Agregar

### M6: _is_valid_spawn_position() no-op [FIXED]
**File:** `scripts/systems/spawn_manager.gd:126-130`
**Desc:** Siempre retorna true, no valida tiles
**Fix:** Implementar validación o remover

### M7: collect_resource() state flash [FIXED]
**File:** `scenes/beep/BeepAgent.gd:85,88`
**Desc:** Setea WORKING luego IDLE en el mismo frame
**Fix:** Usar await con timer

### M8: World.gd runtime load() [FIXED]
**File:** `scenes/world/World.gd:63-64`
**Desc:** `spawn_manager.load_resource_scene()` usa `load()` en runtime
**Fix:** Usar `preload()`

### M9: print_debug() no es función válida [FIXED]
**File:** `scripts/systems/colony_manager.gd:104`
**Desc:** `print_debug()` no existe en Godot 4
**Fix:** Cambiar a `push_debug()` o `print()`

---

## WARNING (10) - Standards violations

### W1: `:` en vez de `:=` para consts [FIXED]
**Files:** Múltiples
**Desc:** Standards requieren `:=` para immutable constants
**Fix:** Reemplazar todos

### W2: Missing class_name en autoloads [FIXED]
**Files:** `resource_manager.gd:4`, `colony_manager.gd:4`
**Desc:** Autoloads sin `class_name`
**Fix:** Agregar

### W3: Private variables sin _prefix [FIXED]
**Files:** Múltiples
**Desc:** Variables internas sin prefijo `_`
**Fix:** Agregar `_` prefix

### W4: print() en vez de push_warning/push_debug [FIXED]
**Files:** Múltiples
**Desc:** Standards requieren GD.print para logging
**Fix:** Reemplazar (low priority)

### W5: Untyped Array declarations [FIXED]
**Files:** Múltiples
**Desc:** `Array` sin tipo de elemento
**Fix:** Usar `Array[Type]`

### W6: Empty _init()/_ready() con pass [FIXED]
**Files:** Múltiples
**Desc:** Funciones vacías con `pass`
**Fix:** Remover

### W7-W8: `:` en vez de `:=` (building_types, resource_types) [FIXED]
**Files:** `scripts/data/building_types.gd`, `scripts/data/resource_types.gd`
**Fix:** Mismo que W1

### W9: happiness inicializado desde food value [FIXED]
**File:** `scripts/systems/colony_manager.gd:52`
**Desc:** `happiness = GameConfig.INITIAL_FOOD / 2.0`
**Fix:** Usar valor hardcoded o constante separada

### W10: SPAWN_INTERVAL inconsistente [FIXED]
**File:** `scenes/world/World.gd:30`
**Desc:** `World.gd` define 30s, `GameConfig` define 25s
**Fix:** Usar GameConfig

---

## INFO (4) - Mejoras menores

### I1: Comentario truncado [FIXED]
**File:** `scenes/buildings/Building.gd:14`
**Desc:** `## Estado de construcci` incompleto

### I2: SpawnManager autoload vs instance [FIXED]
**File:** `plans/standards.md`
**Desc:** Ambigüedad en arquitectura

### I3: CollisionShape2D naming [FIXED]
**File:** `scenes/beep/beep.tscn`
**Desc:** Dos CollisionShape2D, referencia ambigua

### I4: DEBUG_PRINT_DECISIONS usado para reproducción [FIXED]
**File:** `scripts/systems/reproduction_system.gd`
**Desc:** Debería usar `DEBUG_PRINT_REPRODUCTION`

---

## Round 2 Fixes (25 Abril 2026)

### R1: `_regenerate` lógica invertida [FIXED]
**File:** `scenes/resources/ResourceNode.gd`
**Desc:** Solo regeneraba cuando `not _is_active`, debería regenerar siempre que `_amount < _max_amount`

### R2: `_check_decision_timer` vacío [FIXED]
**File:** `scripts/systems/decision_system.gd`
**Desc:** Al remover `game_time += delta`, la función quedó sin lógica. Ahora usa timer local `decision_timer`

### R3: `next_decision_time` variable removida [FIXED]
**File:** `scripts/systems/decision_system.gd`
**Desc:** `_trigger_random_event` referenciaba variable que ya no existía

### R4: `REPRODUCTION_CHECK_INTERVAL` duplicado [FIXED]
**File:** `scripts/systems/reproduction_system.gd`
**Desc:** Definido como 60.0 localmente, override de GameConfig 90.0
