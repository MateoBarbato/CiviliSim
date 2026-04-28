## Controlador principal del Beep
## Gestiona movimiento, interacciones y comportamiento

class_name BeepAgent
extends CharacterBody2D

## Constructor activo
var _is_constructing: bool = false
var _construction_work_timer: float = 0.0
const CONSTRUCTION_WORK_TIME: float = 1.5  # segundos por tick de trabajo

## Referencias
@onready var stats: BeepStats = $BeepStats
@onready var sprite: Sprite2D = $Sprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea

## Velocidad de movimiento
@export var move_speed: float = 60.0

## Radio de detección de recursos
@export var detection_radius: float = 64.0

## Estado de movimiento
var _target_position: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _current_target: Node2D = null
var _last_position: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
const STUCK_TIMEOUT: float = 2.5
var _debug_label: Label = null

## Pathfinding
var _path: Array[Vector2] = []
var _waypoint_index: int = 0

var _reserved_resource_id: int = 0
const MAX_BEEPS_PER_RESOURCE: int = 2
static var _resource_reservations: Dictionary = {}

## cooldowns
var _action_cooldown: float = 0.0
const ACTION_COOLDOWN_TIME: float = 0.5

## Placeholder visual
const BEEP_RADIUS: float = 14.0
const COLLECTION_RANGE: float = 20.0
const NEARBY_SEARCH_RADIUS: float = 220.0
const EXTENDED_SEARCH_RADIUS: float = 700.0

## Refugio actual (null si no está dentro)
var _shelter: ShelterBuilding = null

## Umbrales para entrar/salir de refugio
const HEALTH_THRESHOLD_ENTER: float = 60.0  # Entra si health < 60%
const HEALTH_THRESHOLD_LEAVE: float = 80.0  # Sale si health > 80%
const ENERGY_THRESHOLD_LEAVE: float = 70.0  # Y energy > 70%

## Descanso preventivo: si lleva mucho tiempo sin descansar, ir al shelter
var _time_since_rest: float = 0.0
const MAX_TIME_WITHOUT_REST: float = 20.0  # segundos

## AI decision loop
var _decision_timer: float = 0.0
const DECISION_INTERVAL: float = 0.5


func _draw() -> void:
	draw_circle(Vector2.ZERO, BEEP_RADIUS, Color(0.2, 1.0, 0.3))


func _ready() -> void:
	ColonyManager.register_beep(self)
	FogOfWar.register_beep(self)
	stats.beep_died.connect(_on_beep_died)
	stats.state_changed.connect(_on_state_changed)
	_last_position = position
	if GameConfig.DEBUG_SHOW_BEEP_OVERLAY:
		_debug_label = Label.new()
		_debug_label.position = Vector2(-42, -30)
		_debug_label.add_theme_font_size_override("font_size", 10)
		add_child(_debug_label)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not stats.is_alive():
		return
	queue_redraw()
	_update_debug_overlay()
	if _action_cooldown > 0:
		_action_cooldown -= delta

	# Track time since last rest (only when outside shelter)
	if _shelter == null:
		_time_since_rest += delta

	if _is_moving:
		_move_toward_target(delta)
		_check_stuck(delta)

	_update_velocity()

	_decision_timer += delta
	if _decision_timer >= DECISION_INTERVAL:
		_decision_timer = 0.0
		_decide_action()


func _decide_action() -> void:
	if _is_moving:
		return

	# Si está dentro de un refugio, solo decidir si salir o quedarse
	if _shelter != null:
		_try_leave_shelter()
		return

	# Descanso preventivo: si lleva mucho tiempo sin descansar, ir al shelter
	if _time_since_rest >= MAX_TIME_WITHOUT_REST:
		# Si es worker, desasignar para poder descansar
		if ConstructionManager.assigned_workers.has(self):
			ConstructionManager.unassign_worker(self)
		rest()
		return

	# Si está agotado, priorizar descanso para evitar quedarse "clavado" trabajando
	if stats.energy < GameConfig.ENERGY_THRESHOLD_REST:
		# Si es worker, desasignar para poder descansar
		if ConstructionManager.assigned_workers.has(self):
			ConstructionManager.unassign_worker(self)
		rest()
		return

	# Si está hambriento, buscar comida (o comer del stock global)
	if stats.hunger > GameConfig.HUNGER_THRESHOLD_PANIC:
		seek_food()
		return
	elif stats.hunger > GameConfig.HUNGER_THRESHOLD_WORK:
		seek_food()
		return

	# Si la salud está baja, buscar refugio para curarse
	if stats.health < HEALTH_THRESHOLD_ENTER:
		_seek_and_enter_shelter()
		return

	var food := ResourceManager.get_food()
	var wood := ResourceManager.get_wood()
	var stone := ResourceManager.get_stone()

	# Recursos críticos — asignar recolección prioritaria
	var food_critical := food < 20.0
	var wood_critical := wood < 20.0
	var stone_critical := stone < 15.0

	# Si algún recurso es crítico, recolectar ese específico
	if wood_critical and randf() < 0.4:
		collect_nearby_resource(ResourceType.Type.WOOD)
		return
	if stone_critical and randf() < 0.4:
		collect_nearby_resource(ResourceType.Type.STONE)
		return
	if food_critical and randf() < 0.4:
		seek_food()
		return

	# Si este beep es worker pero necesita descansar, dejar construcción temporalmente
	if ConstructionManager.assigned_workers.has(self):
		return  # Continuar construyendo

	# Verificar si la colonia debería construir un refugio
	if ConstructionManager.should_start_construction() and randf() < 0.15:
		ConstructionManager.start_shelter_construction()
		join_construction()
		return

	# Verificar si la colonia debería construir un camino (más común que refugios)
	if ConstructionManager.should_start_path_construction() and randf() < 0.25:
		ConstructionManager.start_path_construction()
		join_construction()
		return

	# Building Diversity: proponer almacén si los recursos están altos
	if ConstructionManager.should_start_warehouse_construction() and randf() < 0.12:
		ConstructionManager.start_warehouse_construction()
		join_construction()
		return

	# Building Diversity: proponer centro de investigación si hay conocimiento y recursos
	if ConstructionManager.should_start_research_center_construction() and randf() < 0.08:
		ConstructionManager.start_research_center_construction()
		join_construction()
		return

	# Si hay una construcción activa y este beep no está asignado, unirse como worker
	if ConstructionManager.is_construction_active() and not ConstructionManager.assigned_workers.has(self):
		join_construction()
		return

	# Si este beep ya es worker, verificar si debe continuar construyendo
	if ConstructionManager.assigned_workers.has(self):
		join_construction()
		return

	# Distribución equilibrada: algunos buscan comida, otros madera/piedra, otros exploran
	var roll: float = randf()
	if roll < 0.3:
		seek_food()
	elif roll < 0.5:
		collect_nearby_resource(ResourceType.Type.WOOD)
	elif roll < 0.65:
		collect_nearby_resource(ResourceType.Type.STONE)
	elif roll < 0.85:
		explore()
	else:
		wander()


func _priority_resource_type() -> Variant:
	match ColonyManager.colony_priority:
		ColonyManager.ColonyPriority.FOOD:
			return ResourceType.Type.FOOD
		ColonyManager.ColonyPriority.CONSTRUCTION:
			# Construcción: alterna madera y piedra según escasez
			if ResourceManager.get_wood() <= ResourceManager.get_stone():
				return ResourceType.Type.WOOD
			return ResourceType.Type.STONE
		ColonyManager.ColonyPriority.EXPLORATION:
			return null
		_:
			return null


func collect_nearby_resource(resource_type = null) -> void:
	# Si ya puede recolectar desde donde está, hacerlo
	if _try_collect_adjacent_resource(resource_type):
		stats.assigned_task = "collecting"
		return

	# Buscar primero cerca, luego en radio extendido
	var resource = _find_nearest_resource_type(resource_type, NEARBY_SEARCH_RADIUS)
	if resource == null:
		resource = _find_nearest_resource_type(resource_type, EXTENDED_SEARCH_RADIUS)
	if resource:
		move_to_node(resource)
		stats.assigned_task = "collecting"
	else:
		explore()


## Manejar llegada al destino (factoriza lógica duplicada)
func _handle_arrival_at_target() -> void:
	_release_current_resource_target()
	_current_target = null

	# Si la tarea es construir y hay construcción activa, empezar a trabajar
	if stats.assigned_task == "building" and ConstructionManager.is_construction_active():
		_work_on_construction()
		return

	# Si la tarea es buscar refugio, intentar entrar
	if stats.assigned_task == "seeking_shelter":
		var shelter = _find_nearest_shelter()
		if shelter and shelter.has_space():
			enter_shelter(shelter)
			return

	stats.set_state(BeepStats.State.IDLE)


func _move_toward_target(delta: float) -> void:
	if _current_target != null and not is_instance_valid(_current_target):
		_release_current_resource_target()
		_current_target = null
		_is_moving = false
		velocity = Vector2.ZERO
		stats.set_state(BeepStats.State.IDLE)
		_path.clear()
		_waypoint_index = 0
		return

	var waypoint: Vector2
	if _path.is_empty():
		waypoint = _target_position
	else:
		if _waypoint_index >= _path.size():
			_is_moving = false
			velocity = Vector2.ZERO
			_stuck_timer = 0.0
			_handle_arrival_at_target()
			_path.clear()
			_waypoint_index = 0
			return
		waypoint = _path[_waypoint_index]

	var direction: Vector2 = waypoint - position

	if direction.length() < 8.0:
		if _path.is_empty():
			_is_moving = false
			velocity = Vector2.ZERO
			_stuck_timer = 0.0
			_handle_arrival_at_target()
			_path.clear()
			_waypoint_index = 0
			return
		_waypoint_index += 1
		return

	velocity = direction.normalized() * move_speed
	stats.set_state(BeepStats.State.MOVING)


func _update_velocity() -> void:
	if velocity.length() > 0:
		move_and_slide()


func move_to(position: Vector2) -> void:
	if _action_cooldown > 0:
		return

	_current_target = null
	_release_current_resource_target()
	_target_position = position
	_is_moving = true
	_stuck_timer = 0.0
	stats.set_state(BeepStats.State.MOVING)

	var world = _get_world()
	if world:
		_path = Pathfinding.simplify_path(Pathfinding.find_path(world, self.position, position))
		_waypoint_index = 0


func move_to_node(target_node: Node2D) -> void:
	if target_node is ResourceNodeScene:
		if not _reserve_resource_target(target_node):
			return
	else:
		_release_current_resource_target()

	_current_target = target_node
	_target_position = target_node.position
	_is_moving = true
	_stuck_timer = 0.0
	stats.set_state(BeepStats.State.MOVING)

	var world = _get_world()
	if world:
		_path = Pathfinding.simplify_path(Pathfinding.find_path(world, self.position, target_node.position))
		_waypoint_index = 0


func collect_resource(resource_node: Node) -> void:
	if _action_cooldown > 0:
		return
	if resource_node is Node2D and position.distance_to((resource_node as Node2D).position) > COLLECTION_RANGE:
		return
	
	if resource_node.has_method("collect"):
		stats.set_state(BeepStats.State.WORKING)
		var collected: float = resource_node.collect()
		if collected <= 0.0:
			stats.set_state(BeepStats.State.IDLE)
			return
		_action_cooldown = ACTION_COOLDOWN_TIME
		await get_tree().create_timer(ACTION_COOLDOWN_TIME).timeout
		stats.set_state(BeepStats.State.IDLE)


func eat() -> void:
	if _action_cooldown > 0 or stats.hunger < 10.0 or not ResourceManager.remove_food(1.0):
		return
	
	stats.set_state(BeepStats.State.EATING)
	_action_cooldown = ACTION_COOLDOWN_TIME * 2
	
	await get_tree().create_timer(ACTION_COOLDOWN_TIME * 2).timeout
	stats.set_state(BeepStats.State.IDLE)


func rest() -> void:
	_time_since_rest = 0.0
	var shelter = _find_nearest_shelter()
	if shelter and shelter.has_space():
		move_to_node(shelter)
		stats.assigned_task = "seeking_shelter"
	else:
		stats.set_state(BeepStats.State.RESTING)
		stats.assigned_task = "resting"



func _on_beep_died() -> void:
	_release_current_resource_target()
	# Clean up shelter occupants
	if _shelter and is_instance_valid(_shelter):
		_shelter.exit_beep(self)
		_shelter = null

	ColonyManager.unregister_beep(self)
	FogOfWar.unregister_beep(self)
	queue_free()


func _on_state_changed(new_state: String) -> void:
	if sprite:
		_update_animation(new_state)


func _update_animation(state: String) -> void:
	if animated_sprite:
		animated_sprite.play(state)


func is_alive() -> bool:
	return stats.is_alive()


func get_health() -> float:
	return stats.get_health()


func get_hunger() -> float:
	return stats.get_hunger()


func get_energy() -> float:
	return stats.get_energy()


func get_colony_priority() -> String:
	match ColonyManager.colony_priority:
		ColonyManager.ColonyPriority.FOOD:
			return "Comida"
		ColonyManager.ColonyPriority.CONSTRUCTION:
			return "Construcción"
		ColonyManager.ColonyPriority.EXPLORATION:
			return "Exploración"
	return "Comida"


func seek_food() -> void:
	var food_node = _find_nearest_resource_type(ResourceType.Type.FOOD, NEARBY_SEARCH_RADIUS)
	if food_node == null:
		food_node = _find_nearest_resource_type(ResourceType.Type.FOOD, EXTENDED_SEARCH_RADIUS)
	if food_node:
		move_to_node(food_node)
		stats.assigned_task = "seeking_food"
	elif ResourceManager.get_food() > 5.0:
		eat()
	else:
		explore()


## Unirse a la construcción activa
func join_construction() -> void:
	if not ConstructionManager.is_construction_active():
		return

	# Si no estoy asignado aún, asignarme
	if not ConstructionManager.assigned_workers.has(self):
		if not ConstructionManager.assign_worker(self):
			return

	stats.set_state(BeepStats.State.WORKING)
	stats.assigned_task = "building"

	var build_pos: Vector2 = ConstructionManager.get_build_position()

	# Si ya estoy cerca, trabajar en el sitio
	if position.distance_to(build_pos) <= COLLECTION_RANGE * 2:
		_work_on_construction()
		return

	# Moverse al sitio de construcción
	_current_target = null
	_release_current_resource_target()
	_target_position = build_pos
	_is_moving = true
	_stuck_timer = 0.0
	stats.set_state(BeepStats.State.MOVING)

	var world = _get_world()
	if world:
		_path = Pathfinding.simplify_path(Pathfinding.find_path(world, self.position, build_pos))
		_waypoint_index = 0


## Trabajar en el sitio de construcción (permanecer ahí y contribuir)
func _work_on_construction() -> void:
	if not ConstructionManager.is_construction_active():
		ConstructionManager.unassign_worker(self)
		stats.set_state(BeepStats.State.IDLE)
		stats.assigned_task = "idle"
		return

	stats.set_state(BeepStats.State.WORKING)
	stats.assigned_task = "building"

	# Contribuir con el trabajo (el progreso real se calcula en ConstructionManager)
	_action_cooldown = CONSTRUCTION_WORK_TIME
	await get_tree().create_timer(CONSTRUCTION_WORK_TIME).timeout

	if ConstructionManager.is_construction_active():
		_work_on_construction()
	else:
		ConstructionManager.unassign_worker(self)
		stats.set_state(BeepStats.State.IDLE)
		stats.assigned_task = "idle"


func explore() -> void:
	# Si la prioridad es exploración, buscar tiles desconocidos
	if ColonyManager.colony_priority == ColonyManager.ColonyPriority.EXPLORATION:
		var unknown_tile = _find_unknown_tile_edge()
		if unknown_tile != null:
			var target_pos = unknown_tile * GameConfig.TILE_SIZE + Vector2(8, 8)
			move_to(target_pos)
			stats.assigned_task = "exploring"
			return

	var angle = randf() * TAU
	var distance = 100.0 + randf() * 200.0
	var target = position + Vector2.from_angle(angle) * distance
	move_to(target)
	stats.assigned_task = "exploring"


## Buscar un tile UNKNOWN en el borde del area explorada
func _find_unknown_tile_edge() -> Variant:
	var current_tile := Vector2i(position.x / GameConfig.TILE_SIZE, position.y / GameConfig.TILE_SIZE)
	var search_radius := 15  # tiles

	# Recolectar candidatos
	var candidates: Array[Vector2i] = []

	for dx in range(-search_radius, search_radius + 1):
		for dy in range(-search_radius, search_radius + 1):
			var pos := current_tile + Vector2i(dx, dy)
			if pos.x < 0 or pos.x >= GameConfig.WORLD_WIDTH or pos.y < 0 or pos.y >= GameConfig.WORLD_HEIGHT:
				continue
			if FogOfWar.get_tile_state(pos) != FogOfWar.TileState.UNKNOWN:
				continue

			# Verificar que esté adyacente a un tile visitado (borde de exploración)
			var is_edge := false
			for adx in range(-1, 2):
				for ady in range(-1, 2):
					var neighbor := pos + Vector2i(adx, ady)
					if FogOfWar.is_revealed(neighbor):
						is_edge = true
						break
				if is_edge:
					break

			if is_edge:
				candidates.append(pos)

	if candidates.is_empty():
		return null

	# Elegir uno aleatorio de los candidatos
	return candidates[randi() % candidates.size()]


func wander() -> void:
	var angle = randf() * TAU
	var distance = 50.0 + randf() * 100.0
	var target = position + Vector2.from_angle(angle) * distance
	move_to(target)
	stats.assigned_task = "wandering"


func enter_shelter(shelter: ShelterBuilding) -> void:
	shelter.enter_beep(self)
	_shelter = shelter
	stats.set_state(BeepStats.State.RESTING)
	stats.assigned_task = "resting_in_shelter"


## Buscar refugio y entrar
func _seek_and_enter_shelter() -> void:
	var shelter = _find_nearest_shelter()
	if shelter and shelter.has_space():
		move_to_node(shelter)
		stats.assigned_task = "seeking_shelter"
	else:
		# No hay refugio disponible, explorar para seguir buscando recursos
		explore()


## Intentar salir del refugio si las stats están bien
func _try_leave_shelter() -> void:
	if _shelter == null:
		return

	# Verificar si puede salir
	if stats.health >= HEALTH_THRESHOLD_LEAVE and stats.energy >= ENERGY_THRESHOLD_LEAVE:
		_leave_shelter()
		return

	# Verificar si el refugio ya no existe
	if not is_instance_valid(_shelter):
		_shelter = null
		stats.set_state(BeepStats.State.IDLE)
		stats.assigned_task = "idle"
		return


## Salir del refugio
func _leave_shelter() -> void:
	if _shelter and is_instance_valid(_shelter):
		_shelter.exit_beep(self)
	_shelter = null
	_time_since_rest = 0.0
	stats.set_state(BeepStats.State.IDLE)
	stats.assigned_task = "idle"


func heal(amount: float) -> void:
	stats.health = clampf(stats.health + amount, 0.0, 100.0)


func get_stats() -> Dictionary:
	return stats.get_stats()


func _find_nearest_resource_type(resource_type, max_distance: float = INF) -> Node:
	var nearest: Node = null
	var nearest_distance: float = 999999.0

	var resource_container := _get_resource_container()
	if resource_container == null:
		return null

	for child in resource_container.get_children():
		if child is ResourceNodeScene:
			var rn = child as ResourceNodeScene
			if rn and rn.is_active():
				if not _resource_is_available_for_me(rn):
					continue
				if resource_type == null or rn.get_resource_type() == resource_type:
					var distance = position.distance_to(child.position)
					if distance <= max_distance and distance < nearest_distance:
						nearest_distance = distance
						nearest = child
	
	return nearest


func _get_resource_container() -> Node2D:
	var parent = get_parent()
	if parent == null:
		return null
	var world = parent.get_parent()
	if world == null:
		return null
	return world.get_node_or_null("ResourceContainer")


func _get_world() -> WorldScene:
	var parent = get_parent()
	if parent == null:
		return null
	var world = parent.get_parent()
	if world is WorldScene:
		return world
	return null


func _try_collect_adjacent_resource(resource_type = null) -> bool:
	var resource = _find_nearest_resource_type(resource_type, COLLECTION_RANGE)
	if resource == null:
		return false
	collect_resource(resource)
	stats.assigned_task = "collecting"
	return true


func _check_stuck(delta: float) -> void:
	var moved_distance: float = position.distance_to(_last_position)
	_last_position = position

	if moved_distance < 0.5:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	if _stuck_timer >= STUCK_TIMEOUT:
		_is_moving = false
		velocity = Vector2.ZERO
		_release_current_resource_target()
		_current_target = null
		_stuck_timer = 0.0
		_path.clear()
		_waypoint_index = 0
		explore()


func _resource_is_available_for_me(resource: ResourceNodeScene) -> bool:
	if _reserved_resource_id != 0 and resource.get_instance_id() == _reserved_resource_id:
		return true
	var id: int = resource.get_instance_id()
	var count: int = int(_resource_reservations.get(id, 0))
	return count < MAX_BEEPS_PER_RESOURCE


func _reserve_resource_target(resource: ResourceNodeScene) -> bool:
	var id: int = resource.get_instance_id()
	if _reserved_resource_id == id:
		return true

	var count: int = int(_resource_reservations.get(id, 0))
	if count >= MAX_BEEPS_PER_RESOURCE:
		return false

	_release_current_resource_target()
	_resource_reservations[id] = count + 1
	_reserved_resource_id = id
	return true


func _release_current_resource_target() -> void:
	if _reserved_resource_id == 0:
		return
	var count: int = int(_resource_reservations.get(_reserved_resource_id, 0))
	count = maxi(0, count - 1)
	if count == 0:
		_resource_reservations.erase(_reserved_resource_id)
	else:
		_resource_reservations[_reserved_resource_id] = count
	_reserved_resource_id = 0


func _update_debug_overlay() -> void:
	if _debug_label == null:
		return
	var target_name := "none"
	if _current_target != null and is_instance_valid(_current_target):
		target_name = _current_target.name
	_debug_label.text = "E:%d\n%s\n→ %s" % [int(stats.energy), stats.assigned_task, target_name]


func _find_nearest_shelter() -> ShelterBuilding:
	var nearest: ShelterBuilding = null
	var nearest_distance: float = 200.0
	
	for building in ColonyManager.buildings:
		if building is ShelterBuilding:
			var shelter = building as ShelterBuilding
			if shelter and not shelter.is_under_construction:
				var distance = position.distance_to(shelter.position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest = shelter
	
	return nearest


func _get_build_position() -> Vector2:
	# Delegate to ConstructionManager
	return ConstructionManager.get_build_position()
