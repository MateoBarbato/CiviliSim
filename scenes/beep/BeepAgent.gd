## Controlador principal del Beep
## Gestiona movimiento, interacciones y comportamiento

class_name BeepAgent
extends CharacterBody2D

## Escena del refugio (pre-cargada)
const SHELTER_SCENE: PackedScene = preload("res://scenes/buildings/shelter.tscn")

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

## AI decision loop
var _decision_timer: float = 0.0
const DECISION_INTERVAL: float = 0.5


func _draw() -> void:
	draw_circle(Vector2.ZERO, BEEP_RADIUS, Color(0.2, 1.0, 0.3))


func _ready() -> void:
	ColonyManager.register_beep(self)
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

	# Si está agotado, priorizar descanso para evitar quedarse "clavado" trabajando
	if stats.energy < GameConfig.ENERGY_THRESHOLD_REST:
		rest()
		return

	# Si está hambriento, buscar comida (o comer del stock global)
	if stats.hunger > GameConfig.HUNGER_THRESHOLD_PANIC:
		seek_food()
		return
	elif stats.hunger > GameConfig.HUNGER_THRESHOLD_WORK:
		seek_food()
		return

	var food_low := ResourceManager.get_food() < 15.0
	var wood_low := ResourceManager.get_wood() < 40.0
	var stone_low := ResourceManager.get_stone() < 30.0

	# Solo recolectar si realmente hace falta algo
	if food_low:
		seek_food()
		return

	if wood_low or stone_low:
		collect_nearby_resource(_priority_resource_type())
		return

	# Si no hay necesidad inmediata, explorar/vagar para descubrir nuevas zonas
	if randf() < 0.25:
		collect_nearby_resource(_priority_resource_type())
	elif randf() < 0.5:
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
			if _current_target != null and is_instance_valid(_current_target):
				if _current_target is ResourceNodeScene:
					if position.distance_to(_current_target.position) <= COLLECTION_RANGE:
						collect_resource(_current_target)
			_release_current_resource_target()
			_current_target = null
			stats.set_state(BeepStats.State.IDLE)
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
			if _current_target != null and is_instance_valid(_current_target):
				if _current_target is ResourceNodeScene:
					if position.distance_to(_current_target.position) <= COLLECTION_RANGE:
						collect_resource(_current_target)
			_release_current_resource_target()
			_current_target = null
			stats.set_state(BeepStats.State.IDLE)
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
	var shelter = _find_nearest_shelter()
	if shelter and shelter.has_space():
		enter_shelter(shelter)
	else:
		stats.set_state(BeepStats.State.RESTING)


func rest_in_shelter(shelter: ShelterBuilding) -> void:
	if shelter.enter_beep(self):
		stats.set_state(BeepStats.State.RESTING)
		stats.assigned_task = "resting_in_shelter"


func _on_beep_died() -> void:
	_release_current_resource_target()
	# Clean up shelter occupants
	for building in ColonyManager.buildings:
		if building is ShelterBuilding:
			var shelter = building as ShelterBuilding
			if shelter and shelter.occupants.has(self):
				shelter.exit_beep(self)
	
	ColonyManager.unregister_beep(self)
	queue_free()


func _on_state_changed(new_state: String) -> void:
	if sprite:
		_update_animation(new_state)


func _update_animation(state: String) -> void:
	if animated_sprite:
		animated_sprite.play(state)


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


func build_nearby() -> void:
	if not ResourceManager.has_enough_for_shelter():
		return
	
	stats.set_state(BeepStats.State.WORKING)
	stats.assigned_task = "building"
	
	var build_pos = _get_build_position()
	_build_shelter(build_pos)
	
	_action_cooldown = 2.0
	stats.set_state(BeepStats.State.IDLE)


func explore() -> void:
	var angle = randf() * TAU
	var distance = 100.0 + randf() * 200.0
	var target = position + Vector2.from_angle(angle) * distance
	move_to(target)
	stats.assigned_task = "exploring"


func wander() -> void:
	var angle = randf() * TAU
	var distance = 50.0 + randf() * 100.0
	var target = position + Vector2.from_angle(angle) * distance
	move_to(target)
	stats.assigned_task = "wandering"


func enter_shelter(shelter: ShelterBuilding) -> void:
	shelter.enter_beep(self)
	stats.set_state(BeepStats.State.RESTING)
	stats.assigned_task = "resting_in_shelter"


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
	var angle = randf() * TAU
	var distance = 80.0 + randf() * 60.0
	return position + Vector2.from_angle(angle) * distance


func _build_shelter(build_pos: Vector2) -> void:
	if not ResourceManager.consume_shelter_cost():
		return

	var shelter = SHELTER_SCENE.instantiate()
	shelter.position = build_pos
	
	var parent = get_parent()
	if parent:
		parent.add_child(shelter)
