## Configuración global del juego
## Valores balanceados para MVP1

extends Node

# --- Dimensiones del mundo ---
const WORLD_WIDTH: int = 200
const WORLD_HEIGHT: int = 200
const TILE_SIZE: int = 16

# --- Beeps iniciales ---
const INITIAL_BEEP_COUNT: int = 4

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
const REPRODUCTION_ENERGY_REQUIRED: float = 65.0
const REPRODUCTION_CHECK_INTERVAL: float = 90.0
const REPRODUCTION_COOLDOWN: float = 120.0

# --- Decisiones ---
const DECISION_INTERVAL: float = 45.0
const DECISION_RESPONSE_TIME: float = 35.0

# --- Construcción ---
const SHELTER_COST_WOOD: float = 15.0
const SHELTER_COST_STONE: float = 5.0
const SHELTER_CAPACITY: int = 8
const SHELTER_HEAL_RATE: float = 1.5

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
