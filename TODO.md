# CiviliSim — Todo List

## Construcción de Refugios
- [x] ConstructionManager autoload con cola, workers, progreso logarítmico
- [x] BeepAgent: `should_start_construction()`, `join_construction()`, `_work_on_construction()`
- [x] Marcador visual durante construcción (Node2D + ColorRect + Label)
- [x] HUD: `ConstructionLabel` en sidebar
- [x] FIX: `_get_world()` no encontraba SubViewport — búsqueda recursiva corrigida
- [x] FIX: Distribución equilibrada recursos — beeps ya no solo buscan comida
- [x] Headless verificado: refugio completo en ~50s

## Progreso General
- [x] Procedural terrain (FastNoiseLite)
- [x] Resource spawning (wood, stone, food)
- [x] BeepAgent con Behavior Tree
- [x] ColonyManager, ResourceManager
- [x] CameraController WASD + zoom
- [x] DecisionSystem con panel UI
- [x] ReproductionSystem
- [x] StatsPanel (sidebar) — labels actualizados cada 0.5s

## Interacción con Refugios
- [x] Beeps entran al shelter cuando health < 60% o energy < 25%
- [x] Beeps entran por descanso preventivo (20s sin descansar)
- [x] Shelter cura health + regenera energy de ocupantes
- [x] Beeps salen cuando health > 80% y energy > 70%
- [x] Workers de construcción pueden ser desasignados para descansar
- [x] `_time_since_rest` tracking para descanso preventivo

## Construcción de Caminos
- [x] Path building type en BuildingType.DATA
- [x] PathBuilding class con _draw() visual
- [x] ConstructionManager: `start_path_construction()`, `_find_path_position()`
- [x] Paths conectan refugios existentes (punto medio + fallback)
- [x] Beeps construyen paths después de refugios (25% probabilidad)
- [x] BuildingBase maneja nodos opcionales (Sprite2D/ProgressBar null en Path)
- [x] FIX: recursos se validan ANTES de consumir (evita pérdida en fallbacks)
- [x] Headless verificado: 3 paths en 120s

## Niebla de Guerra + Exploración
- [x] FogOfWarSystem autoload con grid de visibilidad por tiles
- [x] Estados: UNKNOWN (oculto), VISITED (visto antes), VISIBLE (en rango)
- [x] Beeps revelan tiles en radio de 8 tiles cada 0.8s
- [x] Overlay visual con TileMap (negro para UNKNOWN, gris para VISITED)
- [x] DecisionSystem: eventos de descubrimiento territorial (early/mid/late/complete)
- [x] Prioridad EXPLORATION: beeps buscan tiles UNKNOWN en el borde explorado
- [x] HUD: label de % exploración del mapa

## Siguientes Features
1. ~~Interacción con refugios~~ (completado)
2. ~~Construcción de caminos~~ (completado)
3. **Defensa** — enemigos básicos, muros
4. **Misiones/eventos** dinámicos en DecisionSystem
5. ~~**Exploración** — mapa desconocido, niebla de guerra~~ (completado)
6. **Multi-tipo de edificios**: almacenes, centros de investigación, torres defensivas

## Bugs / Issues Pendientes
- [ ] `resource_depleted` signal mismatch: emite 0 args, `_on_resource_depleted` espera 1
- [ ] `_find_valid_build_position()` tiene código muerto (líneas 262-264 unreachable)
- [ ] Max 3 refugios / 8 paths arbitrario, debería ser configurable
