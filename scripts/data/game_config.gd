## Configuración global del juego
## Valores balanceados para MVP1

extends Node

# --- Dimensiones del mundo ---
const WORLD_WIDTH: int = 300
const WORLD_HEIGHT: int = 300
const TILE_SIZE: int = 16

# --- Beeps iniciales ---
const INITIAL_BEEP_COUNT: int = 6

# --- Recursos iniciales ---
const INITIAL_FOOD: float = 50.0
const INITIAL_WOOD: float = 20.0
const INITIAL_STONE: float = 10.0

# --- Umbrales del Beep (balanceados) ---
const HUNGER_THRESHOLD_WORK: float = 65.0
const HUNGER_THRESHOLD_PANIC: float = 85.0
const ENERGY_THRESHOLD_REST: float = 25.0
const ENERGY_THRESHOLD_WORK: float = 45.0
const HEALTH_THRESHOLD_SEEK_SHELTER: float = 35.0

# --- Tasas de consumo ---
const HUNGER_RATE: float = 1.5
const ENERGY_DRAIN_WORKING: float = 4.0
const ENERGY_REGEN_RESTING: float = 4.0
const HEALTH_DECAY_RATE: float = 0.5

# --- Reproducción ---
const REPRODUCTION_MIN_POPULATION: int = 2
const REPRODUCTION_MAX_POPULATION: int = 30
const REPRODUCTION_FOOD_REQUIRED: float = 20.0
const REPRODUCTION_ENERGY_REQUIRED: float = 45.0
const REPRODUCTION_CHECK_INTERVAL: float = 45.0
const REPRODUCTION_COOLDOWN: float = 90.0

# --- Decisiones ---
const DECISION_INTERVAL: float = 45.0
const DECISION_RESPONSE_TIME: float = 35.0

# --- Event Depth ---
## Multiplicador de dificultad por cada fase (early/mid/late)
const EVENT_DIFFICULTY_EARLY: float = 1.0
const EVENT_DIFFICULTY_MID: float = 1.3
const EVENT_DIFFICULTY_LATE: float = 1.7
## Tiempo en segundos para transición entre fases
const EVENT_PHASE_MID_TIME: float = 180.0   # 3 min → fase media
const EVENT_PHASE_LATE_TIME: float = 420.0  # 7 min → fase tardía
## Efectos persistentes
const PERSISTENT_EFFECT_MAX_ACTIVE: int = 5
## Invasión
const INVASION_MIN_INTERVAL: float = 120.0   # primera invasión posible a 2 min
const INVASION_COOLDOWN: float = 180.0       # entre invasiones

# --- Construcción ---
# NOTA: SHELTER_COST_*, SHELTER_CAPACITY y SHELTER_HEAL_RATE se definen en
# BuildingType.DATA[BuildingType.Type.SHELTER] como fuente única de verdad.
const SHELTER_COST_WOOD: float = 15.0  # alias = BuildingType.DATA[Type.SHELTER].cost_wood
const SHELTER_COST_STONE: float = 5.0  # alias = BuildingType.DATA[Type.SHELTER].cost_stone
const SHELTER_CAPACITY: int = 10  # alias = BuildingType.DATA[Type.SHELTER].capacity
const SHELTER_HEAL_RATE: float = 1.0  # alias = BuildingType.DATA[Type.SHELTER].heals_per_second
## Límites de edificios por tipo
const MAX_SHELTERS: int = 3
const MAX_PATHS: int = 8
const MAX_WAREHOUSES: int = 3
const MAX_RESEARCH_CENTERS: int = 2

# --- Condición de victoria/derrota ---
const WIN_POPULATION: int = 15
const LOSE_POPULATION: int = 0

# --- Pathfinding ---
const PATHFINDING_MAX_STEPS: int = 500
const PATHFINDING_UPDATE_INTERVAL: float = 0.5

# --- Guardado ---
const AUTO_SAVE_INTERVAL: float = 300.0
const SAVE_PATH: String = "user://saves/auto_save.json"

# --- Debug ---
const DEBUG_DRAW_PATHS: bool = false
const DEBUG_DRAW_BEHAVIOR_TREE: bool = false
const DEBUG_SHOW_BEEP_OVERLAY: bool = true
const DEBUG_PRINT_DECISIONS: bool = true
const DEBUG_PRINT_REPRODUCTION: bool = true
const DEBUG_PRINT_RESOURCES: bool = false

# --- Spawn de recursos ---
const INITIAL_RESOURCE_COUNT: int = 50
const RESOURCE_SPAWN_INTERVAL: float = 25.0
const MAX_RESOURCES_ON_MAP: int = 60

# --- Cámara ---
const CAMERA_ZOOM_MIN: float = 0.5
const CAMERA_ZOOM_MAX: float = 2.0
const CAMERA_ZOOM_SPEED: float = 0.5

# --- Clima ---
## Tiempo mínimo entre cambios de clima (s)
const WEATHER_CHANGE_MIN_INTERVAL: float = 60.0
## Tiempo máximo entre cambios de clima (s)
const WEATHER_CHANGE_MAX_INTERVAL: float = 120.0
## Duración default de tormenta forzada por evento (s)
const WEATHER_STORM_DURATION: float = 30.0

## Multiplicadores de velocidad por clima (aplicado a beeps afuera)
const WEATHER_SPEED_CLEAR: float = 1.0
const WEATHER_SPEED_RAIN: float = 0.7
const WEATHER_SPEED_FOG: float = 0.8
const WEATHER_SPEED_WIND: float = 0.8
const WEATHER_SPEED_STORM: float = 0.4

## Daño por segundo en tormenta (solo afuera del refugio)
const WEATHER_STORM_DAMAGE_PER_SEC: float = 2.0

## Bonus de regeneración de comida bajo lluvia
const WEATHER_RAIN_FOOD_REGEN_MULT: float = 2.0
## Bonus de regeneración de comida bajo tormenta
const WEATHER_STORM_FOOD_REGEN_MULT: float = 3.0
## Bonus de regeneración de madera bajo viento
const WEATHER_WIND_WOOD_REGEN_MULT: float = 1.5

## Reducción de radio de detección en niebla
const WEATHER_FOG_DETECTION_MULT: float = 0.5

## Chance por tick de nodo de recurso ser destruido en tormenta (0-1)
const WEATHER_STORM_RESOURCE_DESTRUCT_CHANCE: float = 0.002

## Shake de cámara en tormenta
const WEATHER_STORM_SHAKE_STRENGTH: float = 2.0
