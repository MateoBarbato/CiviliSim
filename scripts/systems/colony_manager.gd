## Gestiona el estado global de la colonia
## Autoload: ColonyManager

extends Node

signal colony_priority_changed(priority: String)
signal population_changed(count: int)
signal game_over
signal victory

## Prioridades de la colonia
enum ColonyPriority { FOOD, CONSTRUCTION, EXPLORATION }

## Estado de la colonia
var colony_priority: ColonyPriority = ColonyPriority.FOOD
var population: int = 0
var happiness: float = 75.0
var health_average: float = 80.0
var social_order: float = 70.0
var knowledge: float = 0.0

## Estado del juego
var game_active: bool = false
var game_time: float = 0.0
var decision_timer: float = 0.0

## Lista de Beeps activos
var beeps: Array = []

## Lista de edificios
var buildings: Array = []

## Debug
var debug_mode: bool = false


func _ready() -> void:
	_init_colony()


func _process(delta: float) -> void:
	if not game_active:
		return
	
	game_time += delta
	_update_colony_stats(delta)
	_check_game_conditions()


func _init_colony() -> void:
	population = 0
	happiness = GameConfig.INITIAL_FOOD / 2.0
	health_average = 80.0
	social_order = 70.0
	knowledge = 0.0
	colony_priority = ColonyPriority.FOOD
	game_active = false
	game_time = 0.0
	beeps.clear()
	buildings.clear()


func start_game() -> void:
	game_active = true
	game_time = 0.0
	_init_colony()
	colony_priority = ColonyPriority.FOOD
	_on_population_changed(0)


func stop_game() -> void:
	game_active = false


func register_beep(beep_node: Node) -> void:
	if not beeps.has(beep_node):
		beeps.append(beep_node)
		population = beeps.size()
		_on_population_changed(population)


func unregister_beep(beep_node: Node) -> void:
	if beeps.has(beep_node):
		beeps.erase(beep_node)
		population = beeps.size()
		_on_population_changed(population)


func register_building(building_node: Node) -> void:
	if not buildings.has(building_node):
		buildings.append(building_node)


func unregister_building(building_node: Node) -> void:
	if buildings.has(building_node):
		buildings.erase(building_node)


func set_colony_priority(priority: ColonyPriority) -> void:
	colony_priority = priority
	colony_priority_changed.emit(_get_priority_name(priority))
	
	if debug_mode:
		print_debug("Prioridad de colonia cambiada a: ", _get_priority_name(priority))


func _get_priority_name(priority: ColonyPriority) -> String:
	match priority:
		ColonyPriority.FOOD:
			return "Comida"
		ColonyPriority.CONSTRUCTION:
			return "Construcción"
		ColonyPriority.EXPLORATION:
			return "Exploración"
		_:
			return "Desconocida"


func _update_colony_stats(delta: float) -> void:
	if beeps.is_empty():
		return
	
	var total_health: float = 0.0
	var alive_count: int = 0
	
	for beep in beeps:
		if beep.is_queued_for_deletion():
			continue
		if beep.has_method("get_health"):
			total_health += beep.get_health()
			alive_count += 1
	
	if alive_count > 0:
		health_average = total_health / alive_count
	else:
		health_average = 0.0
	
	# La felicidad se ve afectada por la salud promedio
	if health_average < 50:
		happiness = maxf(0, happiness - 2.0 * delta)
	elif health_average > 70:
		happiness = minf(100, happiness + 1.0 * delta)


func _check_game_conditions() -> void:
	if population <= GameConfig.LOSE_POPULATION:
		game_active = false
		game_over.emit()
	
	if population >= GameConfig.WIN_POPULATION:
		game_active = false
		victory.emit()


func _on_population_changed(new_count: int) -> void:
	population_changed.emit(new_count)


func get_colony_state() -> Dictionary:
	return {
		"priority": colony_priority,
		"population": population,
		"happiness": happiness,
		"health_average": health_average,
		"social_order": social_order,
		"knowledge": knowledge,
		"game_time": game_time
	}


func get_beep_count() -> int:
	return population


func get_building_count() -> int:
	return buildings.size()
