## Gestiona la cola de construcción y la asignación de trabajadores
## Autoload: ConstructionManager

extends Node

const SHELTER_SCENE: PackedScene = preload("res://scenes/buildings/shelter.tscn")
const PATH_SCENE: PackedScene = preload("res://scenes/buildings/path.tscn")

signal construction_started(building_type: String, position: Vector2)
signal construction_completed(building: BuildingBase)
signal construction_failed(reason: String)
signal construction_progress_updated(progress: float, building_type: String)

## Tipo de edificio que se puede construir
enum PendingType { SHELTER, PATH }

## Límite de caminos
const MAX_PATHS: int = 8

## Orden de construcción pendiente (solo una a la vez en MVP1)
var current_order: Dictionary = {}
var has_active_order: bool = false

## Progreso de construcción actual
var construction_progress: float = 0.0

## Beeps trabajando en la construcción actual
var assigned_workers: Array = []

## Sitio de construcción actual
var build_position: Vector2 = Vector2.ZERO

## Nodo marcador visual durante la construcción
var _construction_site: Node2D = null

## Distancia mínima entre edificios (px)
const MIN_BUILDING_DISTANCE: float = 80.0

## Distancia mínima desde el centro para construir (evitar spawn cluster)
const MIN_DISTANCE_FROM_CENTER: float = 120.0


func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)


func _process(delta: float) -> void:
	_update_progress(delta)


func _update_progress(delta: float) -> void:
	if not has_active_order:
		return

	var worker_count: int = _get_active_worker_count()
	if worker_count <= 0:
		return

	var rate: float = _get_construction_rate(worker_count)
	construction_progress += rate * delta

	if construction_progress >= 1.0:
		construction_progress = 1.0
		_complete_construction()
	else:
		construction_progress_updated.emit(construction_progress, current_order.get("type", ""))


## Verificar si se puede construir un refugio
func should_start_construction() -> bool:
	# Ya hay una construcción activa
	if has_active_order:
		return false

	# Si ya hay refugios completos, no priorizar más construcción (MVP1)
	var shelter_count: int = 0
	for b in ColonyManager.buildings:
		if _is_shelter(b) and not b.is_under_construction:
			shelter_count += 1

	# Límite de refugios en MVP1
	if shelter_count >= 3:
		return false

	# Verificar recursos
	if not ResourceManager.has_enough_for_shelter():
		return false

	# Solo si hay beeps disponibles (no trabajando en otra cosa crítica)
	var available_beeps: int = _count_available_beeps()
	if available_beeps < 1:
		return false

	return true


## Verificar si se puede construir un camino
func should_start_path_construction() -> bool:
	# Ya hay una construcción activa
	if has_active_order:
		return false

	# Contar caminos existentes
	var path_count: int = 0
	for b in ColonyManager.buildings:
		if _is_path(b):
			path_count += 1

	# Límite de caminos
	if path_count >= MAX_PATHS:
		return false

	# Necesita al menos un refugio para construir caminos
	var has_shelter: bool = false
	for b in ColonyManager.buildings:
		if _is_shelter(b) and not b.is_under_construction:
			has_shelter = true
			break

	if not has_shelter:
		return false

	# Verificar recursos
	var wood_cost: float = BuildingType.get_cost_wood(BuildingType.Type.PATH)
	var stone_cost: float = BuildingType.get_cost_stone(BuildingType.Type.PATH)

	if ResourceManager.get_wood() < wood_cost or ResourceManager.get_stone() < stone_cost:
		return false

	# Solo si hay beeps disponibles
	var available_beeps: int = _count_available_beeps()
	if available_beeps < 1:
		return false

	return true


## Helpers para verificar tipos de edificio
func _is_shelter(building: Node) -> bool:
	return building.get("building_type") == "shelter"


func _is_path(building: Node) -> bool:
	return building.get("building_type") == "path"


## Iniciar construcción de un refugio
func start_shelter_construction() -> void:
	_start_construction(BuildingType.Type.SHELTER)


## Iniciar construcción de un camino
func start_path_construction() -> void:
	_start_construction(BuildingType.Type.PATH)


## Función genérica para iniciar construcción
func _start_construction(type: int) -> void:
	if has_active_order:
		return

	var name: String = _type_to_name(type)
	var scene: PackedScene = _get_scene_for_type(type)

	# Encontrar posición válida ANTES de consumir recursos
	if type == BuildingType.Type.PATH:
		build_position = _find_path_position()
	else:
		build_position = _find_valid_build_position()

	var world = _get_world()
	if world and not world.is_walkable(Pathfinding._to_cell(build_position)):
		_fail_construction("No se encontró un terreno válido para construir %s" % name)
		return

	# Verificar recursos
	var wood_cost: float = BuildingType.get_cost_wood(type)
	var stone_cost: float = BuildingType.get_cost_stone(type)

	if ResourceManager.get_wood() < wood_cost or ResourceManager.get_stone() < stone_cost:
		_fail_construction("Recursos insuficientes para %s" % name)
		return

	# Consumir recursos (solo si la posición es válida)
	ResourceManager.remove_wood(wood_cost)
	ResourceManager.remove_stone(stone_cost)

	has_active_order = true
	construction_progress = 0.0
	current_order = {
		"type": _type_to_string(type),
		"building_type": type,
	}

	construction_started.emit(_type_to_string(type), build_position)
	# Crear marcador visual
	_spawn_construction_site()

	print("[ConstructionManager] Iniciando construcción de %s en %s" % [name, build_position])


## Tipo a nombre legible
func _type_to_name(type: int) -> String:
	return BuildingType.DATA[type]["name"]


## Tipo a string interno
func _type_to_string(type: int) -> String:
	match type:
		BuildingType.Type.SHELTER: return "shelter"
		BuildingType.Type.PATH: return "path"
	return "unknown"


## Obtener escena para tipo
func _get_scene_for_type(type: int) -> PackedScene:
	match type:
		BuildingType.Type.PATH: return PATH_SCENE
	return SHELTER_SCENE


## Asignar un beep como trabajador
func assign_worker(beep: BeepAgent) -> bool:
	if not has_active_order:
		return false
	if assigned_workers.has(beep):
		return false

	assigned_workers.append(beep)
	return true


## Desasignar un beep
func unassign_worker(beep: BeepAgent) -> void:
	assigned_workers.erase(beep)


## Obtener la posición de construcción para que los beeps se muevan ahí
func get_build_position() -> Vector2:
	return build_position


## Obtener progreso actual (0.0 - 1.0)
func get_progress() -> float:
	return construction_progress


## Verificar si hay construcción activa
func is_construction_active() -> bool:
	return has_active_order


## Obtener el tipo de edificio en construcción
func get_pending_type() -> String:
	return current_order.get("type", "")


## Completar la construcción
func _complete_construction() -> void:
	var building_type: int = current_order.get("building_type", BuildingType.Type.SHELTER)
	var scene: PackedScene = _get_scene_for_type(building_type)

	var building = scene.instantiate()
	building.position = build_position

	# Encontrar el contenedor de edificios en el mundo
	var parent = _get_building_parent()
	if parent:
		parent.add_child(building)
	else:
		_fail_construction("No se encontró un lugar para colocar el edificio")
		return

	# Reset
	_remove_construction_site()
	has_active_order = false
	construction_progress = 0.0
	current_order = {}
	assigned_workers.clear()

	construction_completed.emit(building)
	print("[ConstructionManager] %s completado en %s" % [_type_to_name(building_type), build_position])


## Fallar la construcción
func _fail_construction(reason: String) -> void:
	_remove_construction_site()
	has_active_order = false
	construction_progress = 0.0
	current_order = {}
	assigned_workers.clear()
	construction_failed.emit(reason)
	print("[ConstructionManager] Construcción fallida: ", reason)


## Cancelar construcción actual (devolver recursos parciales)
func cancel_construction() -> void:
	if not has_active_order:
		return

	# Devolver 50% de los recursos
	var wood_cost: float = BuildingType.get_cost_wood(BuildingType.Type.SHELTER)
	var stone_cost: float = BuildingType.get_cost_stone(BuildingType.Type.SHELTER)
	ResourceManager.add_wood(wood_cost * 0.5)
	ResourceManager.add_stone(stone_cost * 0.5)

	_remove_construction_site()
	has_active_order = false
	construction_progress = 0.0
	current_order = {}
	assigned_workers.clear()
	print("[ConstructionManager] Construcción cancelada, recursos devueltos")


## Encontrar posición para un camino (entre edificios existentes)
func _find_path_position() -> Vector2:
	var world = _get_world()
	if not world:
		return Vector2(1600, 1600)

	# Obtener refugios existentes
	var shelters: Array = []
	for b in ColonyManager.buildings:
		if _is_shelter(b) and not b.is_under_construction:
			shelters.append(b)

	if shelters.size() < 1:
		# No hay refugios, poner camino cerca del centro
		return Vector2(
			world.world_width * GameConfig.TILE_SIZE / 2.0,
			world.world_height * GameConfig.TILE_SIZE / 2.0
		)

	if shelters.size() == 1:
		# Un solo refugio: poner camino entre el refugio y un punto cercano
		var shelter: Node2D = shelters[0]
		var angle: float = randf() * TAU
		var distance: float = 100.0 + randf() * 100.0
		return shelter.position + Vector2.from_angle(angle) * distance

	# Múltiples refugios: poner camino entre dos refugios cercanos
	var i: int = randi() % shelters.size()
	var j: int = (i + 1) % shelters.size()
	var shelter_a: Node2D = shelters[i]
	var shelter_b: Node2D = shelters[j]

	# Intentar punto medio entre los dos refugios (varias veces con offsets)
	for attempt in range(10):
		var midpoint = (shelter_a.position + shelter_b.position) / 2.0
		var offset_angle: float = randf() * TAU
		var offset_distance: float = attempt * 20.0
		var candidate = midpoint + Vector2.from_angle(offset_angle) * offset_distance

		var cell := Pathfinding._to_cell(candidate)
		if world.is_walkable(cell):
			return candidate

	# Fallback: centro del mundo
	return Vector2(
		world.world_width * GameConfig.TILE_SIZE / 2.0,
		world.world_height * GameConfig.TILE_SIZE / 2.0
	)


## Encontrar posición válida para construir (edificios no-path)
func _find_valid_build_position() -> Vector2:
	var world = _get_world()
	if not world:
		return Vector2(1600, 1600)

	var world_center := Vector2(
		world.world_width * GameConfig.TILE_SIZE / 2.0,
		world.world_height * GameConfig.TILE_SIZE / 2.0
	)

	# Buscar en espiral desde el centro
	var attempts: int = 0
	var max_attempts: int = 200
	var radius: float = MIN_DISTANCE_FROM_CENTER

	while attempts < max_attempts:
		var angle: float = randf() * TAU
		var candidate: Vector2 = world_center + Vector2.from_angle(angle) * radius

		var cell := Pathfinding._to_cell(candidate)

		# Verificar terreno walkable
		if not world.is_walkable(cell):
			attempts += 1
			continue

		# Verificar distancia con otros edificios
		var too_close: bool = false
		for b in ColonyManager.buildings:
			if b is Node2D:
				var dist: float = candidate.distance_to(b.position)
				if dist < MIN_BUILDING_DISTANCE:
					too_close = true
					break

		if too_close:
			attempts += 1
			continue

		# Posición válida
		return candidate

		radius += 40.0
		attempts += 1

	# Fallback
	return world_center + Vector2(MIN_DISTANCE_FROM_CENTER, 0)


## Verificar si una posición es válida para construir
static func is_valid_build_position(pos: Vector2, world: WorldScene) -> bool:
	if not world:
		return false

	var cell := Pathfinding._to_cell(pos)
	if not world.is_walkable(cell):
		return false

	# Verificar distancia con edificios existentes
	for b in ColonyManager.buildings:
		if b is Node2D:
			var dist: float = pos.distance_to(b.position)
			if dist < MIN_BUILDING_DISTANCE:
				return false

	return true


## Tasa de construcción con diminishing returns
func _get_construction_rate(worker_count: int) -> float:
	# Base rate: 0.08 por segundo con 1 worker
	# Cada worker adicional suma menos (logarítmico)
	var base_rate: float = 0.08
	var bonus: float = 0.04 * (log(float(worker_count + 1)) / log(2.0))
	return base_rate + bonus


## Contar beeps disponibles (no moviéndose, no trabajando, no durmiendo)
func _count_available_beeps() -> int:
	var count: int = 0
	for beep in ColonyManager.beeps:
		if not is_instance_valid(beep):
			continue
		if beep.is_queued_for_deletion():
			continue
		# Un beep está disponible si está vivo y no tiene tarea crítica
		if beep.stats.is_alive():
			var task: String = beep.stats.assigned_task
			if task == "idle" or task == "wandering" or task == "exploring":
				count += 1
	return count


## Contar workers activos en la construcción actual
func _get_active_worker_count() -> int:
	var count: int = 0
	for beep in assigned_workers:
		if is_instance_valid(beep) and not beep.is_queued_for_deletion():
			count += 1
	return count


## Cuando cambian recursos, verificar si se puede iniciar construcción
func _on_resource_changed(_resource_type: String, _amount: float) -> void:
	# No hacer nada automáticamente, los beeps decidirán cuando _decide_action()
	pass


## Helpers para encontrar el mundo
func _get_world() -> WorldScene:
	# Buscar recursivamente en el tree. El mundo está dentro de:
	# SceneTreeRoot -> Main -> SubViewportContainer -> GameViewport -> WorldScene
	var viewport = _find_subviewport(get_tree().root)
	if viewport:
		for gc in viewport.get_children():
			if gc is WorldScene:
				return gc
	return null


func _find_subviewport(node: Node) -> SubViewport:
	if node is SubViewport:
		return node
	for child in node.get_children():
		var result = _find_subviewport(child)
		if result:
			return result
	return null


func _get_building_parent() -> Node:
	var world = _get_world()
	if world:
		return world
	return null


## Crear marcador visual en el sitio de construcción
func _spawn_construction_site() -> void:
	var site := Node2D.new()
	site.name = "ConstructionSite"
	site.position = build_position

	# Script del sitio (inline draw)
	var script := GDScript.new()
	# Usar un approach más simple: crear un nodo con código inline
	# En realidad, mejor creamos una escena o usamos _draw directo
	# Para simplicidad, usaremos un ColorRect + Label
	var color_rect := ColorRect.new()
	color_rect.size = Vector2(48, 48)
	color_rect.position = Vector2(-24, -24)
	color_rect.color = Color(0.7, 0.55, 0.3, 0.4)
	site.add_child(color_rect)

	var label := Label.new()
	label.text = "🔨 Construyendo..."
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(-50, 30)
	site.add_child(label)

	var parent = _get_building_parent()
	if parent:
		parent.add_child(site)
		_construction_site = site
	else:
		_fail_construction("No se encontró el contenedor de edificios")


## Remover marcador visual
func _remove_construction_site() -> void:
	if _construction_site and is_instance_valid(_construction_site):
		_construction_site.queue_free()
		_construction_site = null


## Reset completo
func reset() -> void:
	_remove_construction_site()
	has_active_order = false
	construction_progress = 0.0
	current_order = {}
	assigned_workers.clear()
