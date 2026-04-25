## Estadísticas del Beep
## Maneja hambre, energía, salud y estado del agente

class_name BeepStats
extends Node

signal hunger_changed(value: float)
signal energy_changed(value: float)
signal health_changed(value: float)
signal state_changed(new_state: String)
signal beep_died

## Enum de estados
enum State {
	IDLE,
	WORKING,
	EATING,
	RESTING,
	MOVING,
	DEAD
}

## Stats principales
var hunger: float = 0.0
var energy: float = 100.0
var health: float = 100.0
var age: float = 0.0

## Estado actual
var current_state: State = State.IDLE

## Tarea asignada
var assigned_task: String = ""

## Límites
const MAX_HUNGER: float = 100.0
const MAX_ENERGY: float = 100.0
const MAX_HEALTH: float = 100.0

## Tasas
var hunger_rate: float = GameConfig.HUNGER_RATE / 60.0
var energy_drain_rate: float = GameConfig.ENERGY_DRAIN_WORKING
var energy_regen_rate: float = GameConfig.ENERGY_REGEN_RESTING


func _process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	age += delta
	_update_stats(delta)
	_check_death_conditions()


func _update_stats(delta: float) -> void:
	match current_state:
		State.IDLE:
			hunger = clampf(hunger + hunger_rate * delta, 0.0, MAX_HUNGER)
		State.WORKING:
			hunger = clampf(hunger + hunger_rate * delta * 1.5, 0.0, MAX_HUNGER)
			energy = clampf(energy - energy_drain_rate * delta, 0.0, MAX_ENERGY)
		State.EATING:
			hunger = clampf(hunger - hunger_rate * delta * 5.0, 0.0, MAX_HUNGER)
		State.RESTING:
			hunger = clampf(hunger + hunger_rate * delta * 0.5, 0.0, MAX_HUNGER)
			energy = clampf(energy + energy_regen_rate * delta, 0.0, MAX_ENERGY)
			health = clampf(health + 0.5 * delta, 0.0, MAX_HEALTH)
		State.MOVING:
			hunger = clampf(hunger + hunger_rate * delta, 0.0, MAX_HUNGER)
			energy = clampf(energy - energy_drain_rate * delta * 0.3, 0.0, MAX_ENERGY)


func _check_death_conditions() -> void:
	if hunger >= MAX_HUNGER or health <= 0.0:
		set_dead()


func set_state(new_state: State) -> void:
	if current_state == State.DEAD:
		return
	current_state = new_state
	state_changed.emit(_get_state_name(new_state))


func _get_state_name(state: State) -> String:
	match state:
		State.IDLE:
			return "idle"
		State.WORKING:
			return "working"
		State.EATING:
			return "eating"
		State.RESTING:
			return "resting"
		State.MOVING:
			return "moving"
		State.DEAD:
			return "dead"
		_:
			return "unknown"


func set_dead() -> void:
	current_state = State.DEAD
	state_changed.emit("dead")
	beep_died.emit()


func is_alive() -> bool:
	return current_state != State.DEAD


func get_state() -> State:
	return current_state


func get_hunger() -> float:
	return hunger


func get_energy() -> float:
	return energy


func get_health() -> float:
	return health


func get_stats() -> Dictionary:
	return {
		"hunger": hunger,
		"energy": energy,
		"health": health,
		"age": age,
		"state": _get_state_name(current_state),
		"task": assigned_task
	}


func reset() -> void:
	hunger = 0.0
	energy = MAX_ENERGY
	health = MAX_HEALTH
	age = 0.0
	current_state = State.IDLE
	assigned_task = ""
