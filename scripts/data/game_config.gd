## Configuración global del juego
## Valores base para el MVP1

class_name GameConfig
extends RefCounted

# --- Dimensiones del mundo ---
const WORLD_WIDTH: int = 200
const WORLD_HEIGHT: int = 200
const TILE_SIZE: int = 16

# --- Beeps iniciales ---
const INITIAL_BEEP_COUNT: int = 2

# --- Recursos ---
const INITIAL_FOOD: float = 50.0
const INITIAL_WOOD: float = 20.0
const INITIAL_STONE: float = 10.0

# --- Umbrales del Beep ---
const HUNGER_THRESHOLD_WORK: float = 70.0
const HUNGER_THRESHOLD_PANIC: float = 90.0
const ENERGY_THRESHOLD_REST: float = 20.0
const ENERGY_THRESHOLD_WORK: float = 40.0
const HEALTH_THRESHOLD_SEEK_SHELTER: float = 30.0

# --- Tasas de consumo ---
const HUNGER_RATE: float = 2.0  # por minuto de juego
const ENERGY_DRAIN_WORKING: float = 5.0  # por acción de trabajo
const ENERGY_REGEN_RESTING: float = 3.0  # por segundo descansando

# --- Reproducción ---
const REPRODUCTION_MIN_POPULATION: int = 4
const REPRODUCTION_MAX_POPULATION: int = 50
const REPRODUCTION_FOOD_REQUIRED: float = 30.0
const REPRODUCTION_ENERGY_REQUIRED: float = 60.0

# --- Decisiones ---
const DECISION_INTERVAL: float = 60.0  # segundos entre decisiones
const DECISION_RESPONSE_TIME: float = 30.0  # tiempo para responder

# --- Construcción ---
const SHELTER_COST_WOOD: float = 15.0
const SHELTER_COST_STONE: float = 5.0
const SHELTER_CAPACITY: int = 10

# --- Condición de victoria/derrota ---
const WIN_POPULATION: int = 10
const LOSE_POPULATION: int = 0

# --- Pathfinding ---
const PATHFINDING_MAX_STEPS: int = 500
const PATHFINDING_UPDATE_INTERVAL: float = 0.5

# --- Guardado ---
const AUTO_SAVE_INTERVAL: float = 300.0  # 5 minutos
const SAVE_PATH: String = "user://saves/auto_save.json"

# --- Debug ---
const DEBUG_DRAW_PATHS: bool = false
const DEBUG_DRAW_BEHAVIOR_TREE: bool = false
const DEBUG_PRINT_DECISIONS: bool = true

func _init():
	pass
