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
const COOLDOWN_TIME: float = 90.0

## Estadísticas
var total_births: int = 0
var total_failures: int = 0


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
		return
	
	if not _check_population_conditions():
		return
	
	if not _check_resource_conditions():
		return
	
	var parents = _select_parents()
	if parents == null:
		return
	
	_consume_reproduction_cost()
	_spawn_new_beep(parents)
	reproduction_cooldown = COOLDOWN_TIME
	total_births += 1
	
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🐣 Beep nacido! Población: ", ColonyManager.population + 1)


func _check_population_conditions() -> bool:
	var current_pop = ColonyManager.population
	
	if current_pop < min_population:
		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("❌ Población muy baja para reproducir: ", current_pop)
		total_failures += 1
		return false
	
	if current_pop >= max_population:
		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("❌ Población máxima alcanzada: ", current_pop)
		total_failures += 1
		return false
	
	return true


func _check_resource_conditions() -> bool:
	if ResourceManager.get_food() < food_required:
		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("❌ Comida insuficiente para reproducción")
		total_failures += 1
		return false
	
	return true


func _select_parents() -> Dictionary?:
	var beeps = ColonyManager.beeps
	if beeps.size() < 2:
		return null
	
	var eligible = []
	for beep in beeps:
		if beep == null or beep.is_queued_for_deletion():
			continue
		if beep.has_method("get_energy") and beep.get_energy() >= energy_required:
			if beep.has_method("get_health") and beep.get_health() >= 50.0:
				eligible.append(beep)
	
	if eligible.size() < 2:
		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("❌ Beeps elegibles insuficientes: ", eligible.size())
		total_failures += 1
		return null
	
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
	
	_inherit_stats(new_beep, parent1, parent2)
	
	beep_reproduced.emit(new_beep)
	
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🐣 Nuevo Beep spawneado en: ", spawn_pos)


func _calculate_spawn_position(parent1: Node2D, parent2: Node2D) -> Vector2:
	var mid_point = (parent1.position + parent2.position) / 2.0
	var offset = Vector2(
		(randf() - 0.5) * 60.0,
		(randf() - 0.5) * 60.0
	)
	return mid_point + offset


func _inherit_stats(new_beep: Node2D, parent1: Node2D, parent2: Node2D) -> void:
	if new_beep.has_method("get_stats"):
		var stats_node = new_beep.get_node_or_null("BeepStats")
		if stats_node:
			var h1 = parent1.get_health() if parent1.has_method("get_health") else 100.0
			var h2 = parent2.get_health() if parent2.has_method("get_health") else 100.0
			stats_node.health = (h1 + h2) / 2.0 * 1.1
			stats_node.health = minf(stats_node.health, 100.0)


func get_statistics() -> Dictionary:
	return {
		"total_births": total_births,
		"total_failures": total_failures,
		"current_population": ColonyManager.population,
		"reproduction_cooldown": reproduction_cooldown
	}


func force_reproduction_check() -> void:
	reproduction_timer = REPRODUCTION_CHECK_INTERVAL - 0.01


func reset() -> void:
	reproduction_timer = 0.0
	reproduction_cooldown = 0.0
	total_births = 0
	total_failures = 0
