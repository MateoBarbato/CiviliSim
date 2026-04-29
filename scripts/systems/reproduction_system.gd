## Sistema de reproducción de Beeps
## Gestiona apareamiento, nacimiento y regulación poblacional

class_name ReproductionSystem
extends Node

## Escena del Beep (pre-cargada)
const BEEP_SCENE: PackedScene = preload("res://scenes/beep/beep.tscn")

signal beep_reproduced(new_beep: Node)
signal reproduction_blocked(reason: String)
signal population_warning(count: int)

## Timer de reproducción
var reproduction_timer: float = 0.0
const REPRODUCTION_CHECK_INTERVAL: float = GameConfig.REPRODUCTION_CHECK_INTERVAL

## Condiciones mínimas para reproducción
var min_population: int = GameConfig.REPRODUCTION_MIN_POPULATION
var max_population: int = GameConfig.REPRODUCTION_MAX_POPULATION
var food_required: float = GameConfig.REPRODUCTION_FOOD_REQUIRED
var energy_required: float = GameConfig.REPRODUCTION_ENERGY_REQUIRED

## Cooldown entre reproducciones
var reproduction_cooldown: float = 0.0
const COOLDOWN_TIME: float = GameConfig.REPRODUCTION_COOLDOWN

## Estadísticas
var total_births: int = 0
var total_failures: int = 0
var fertility_progress: float = 0.0


func _process(delta: float) -> void:
	if not ColonyManager.game_active:
		return
	
	reproduction_timer += delta
	reproduction_cooldown = maxf(0.0, reproduction_cooldown - delta)
	
	if reproduction_timer >= REPRODUCTION_CHECK_INTERVAL:
		reproduction_timer = 0.0
		_attempt_reproduction()


func _attempt_reproduction() -> void:
	if reproduction_cooldown > 0:
		fertility_progress = maxf(0.0, fertility_progress - 5.0)
		return
	
	if not _check_population_conditions():
		return
	
	if not _check_resource_conditions():
		fertility_progress = maxf(0.0, fertility_progress - 8.0)
		return
	
	var parents = _select_parents()
	if parents.is_empty():
		fertility_progress = maxf(0.0, fertility_progress - 4.0)
		return

	# Progreso paulatino: la reproducción sube por etapas (más orgánico)
	fertility_progress += 35.0
	if fertility_progress < 100.0:
		if GameConfig.DEBUG_PRINT_REPRODUCTION:
			print("ℹ️ Progreso de reproducción: ", int(fertility_progress), "%")
		return
	
	_consume_reproduction_cost()
	_spawn_new_beep(parents)
	reproduction_cooldown = COOLDOWN_TIME
	fertility_progress = 0.0
	total_births += 1
	
	if GameConfig.DEBUG_PRINT_REPRODUCTION:
		print("🐣 Beep nacido! Población: ", ColonyManager.population + 1)


func _check_population_conditions() -> bool:
	var current_pop = ColonyManager.population
	
	if current_pop < min_population:
		if GameConfig.DEBUG_PRINT_REPRODUCTION:
			print("❌ Población muy baja para reproducir: ", current_pop)
		total_failures += 1
		return false
	
	if current_pop >= max_population:
		if GameConfig.DEBUG_PRINT_REPRODUCTION:
			print("❌ Población máxima alcanzada: ", current_pop)
		total_failures += 1
		return false
	
	return true


func _check_resource_conditions() -> bool:
	if ResourceManager.get_food() < food_required:
		if GameConfig.DEBUG_PRINT_REPRODUCTION:
			print("❌ Comida insuficiente para reproducción")
		total_failures += 1
		return false
	
	return true


func _select_parents() -> Dictionary:
	var beeps = ColonyManager.beeps
	if beeps.size() < 2:
		return {}
	
	var eligible: Array = []
	var fallback: Array = []
	for beep in beeps:
		if beep == null or beep.is_queued_for_deletion():
			continue
		if not (beep.has_method("get_energy") and beep.has_method("get_health")):
			continue
		var energy: float = beep.get_energy()
		var health: float = beep.get_health()
		if energy >= energy_required and health >= 45.0:
			eligible.append(beep)
		elif energy >= energy_required - 15.0 and health >= 35.0:
			fallback.append(beep)

	if eligible.size() < 2 and fallback.size() >= 2:
		eligible = fallback
	
	if eligible.size() < 2:
		if GameConfig.DEBUG_PRINT_REPRODUCTION:
			print("❌ Beeps elegibles insuficientes: ", eligible.size())
		total_failures += 1
		return {}
	
	var parent1 = eligible[randi() % eligible.size()]
	var parent2 = eligible[randi() % eligible.size()]
	
	while parent2 == parent1 and eligible.size() > 1:
		parent2 = eligible[randi() % eligible.size()]
	
	return {
		"parent1": parent1,
		"parent2": parent2
	}


func _consume_reproduction_cost() -> void:
	ResourceManager.remove_food(food_required)


func _spawn_new_beep(parents: Dictionary) -> void:
	var parent1 = parents["parent1"]
	var parent2 = parents["parent2"]
	
	var spawn_pos = _calculate_spawn_position(parent1, parent2)

	
	var new_beep = BEEP_SCENE.instantiate()
	new_beep.position = spawn_pos
	
	var parent = parent1.get_parent()
	if parent:
		parent.add_child(new_beep)
	
	# Inicializar como baby
	if new_beep.has_method("stats"):
		new_beep.stats.init_as_baby()
	
	_inherit_stats(new_beep, parent1, parent2)
	
	beep_reproduced.emit(new_beep)
	
	if GameConfig.DEBUG_PRINT_REPRODUCTION:
		print("🐣 Baby Beep nacido en: ", spawn_pos)


func _calculate_spawn_position(parent1: Node2D, parent2: Node2D) -> Vector2:
	var mid_point = (parent1.position + parent2.position) / 2.0
	var offset = Vector2(
		(randf() - 0.5) * 60.0,
		(randf() - 0.5) * 60.0
	)
	return mid_point + offset


func _inherit_stats(new_beep: Node2D, parent1: Node2D, parent2: Node2D) -> void:
	if new_beep.has_method("stats"):
		var stats_node = new_beep.stats
		var h1 = parent1.get_health() if parent1.has_method("get_health") else 100.0
		var h2 = parent2.get_health() if parent2.has_method("get_health") else 100.0
		# Herencia: promedio de padres con pequeño bonus, capped a 100
		stats_node.health = minf((h1 + h2) / 2.0 * 1.1, 100.0)


func get_statistics() -> Dictionary:
	return {
		"total_births": total_births,
		"total_failures": total_failures,
		"current_population": ColonyManager.population,
		"reproduction_cooldown": reproduction_cooldown,
		"fertility_progress": fertility_progress
	}


func force_reproduction_check() -> void:
	reproduction_timer = REPRODUCTION_CHECK_INTERVAL - 0.01


func reset() -> void:
	reproduction_timer = 0.0
	reproduction_cooldown = 0.0
	total_births = 0
	total_failures = 0
	fertility_progress = 0.0


## --- Save / Load ---

func get_save_data() -> Dictionary:
	return {
		"reproduction_timer": reproduction_timer,
		"reproduction_cooldown": reproduction_cooldown,
		"total_births": total_births,
		"total_failures": total_failures,
		"fertility_progress": fertility_progress,
	}


func apply_save_data(data: Dictionary) -> void:
	reproduction_timer = data.get("reproduction_timer", 0.0)
	reproduction_cooldown = data.get("reproduction_cooldown", 0.0)
	total_births = data.get("total_births", 0)
	total_failures = data.get("total_failures", 0)
	fertility_progress = data.get("fertility_progress", 0.0)
