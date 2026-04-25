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

## cooldowns
var _action_cooldown: float = 0.0
const ACTION_COOLDOWN_TIME: float = 0.5


func _ready() -> void:
	ColonyManager.register_beep(self)
	stats.beep_died.connect(_on_beep_died)
	stats.state_changed.connect(_on_state_changed)


func _physics_process(delta: float) -> void:
	if not stats.is_alive():
		return
	
	if _action_cooldown > 0:
		_action_cooldown -= delta
	
	if _is_moving:
		_move_toward_target(delta)
	
	_update_velocity()


func _move_toward_target(delta: float) -> void:
	var direction: Vector2 = _target_position - position
	
	if direction.length() < 2.0:
		_is_moving = false
		stats.set_state(BeepStats.State.IDLE)
		return
	
	velocity = direction.normalized() * move_speed
	stats.set_state(BeepStats.State.MOVING)


func _update_velocity() -> void:
	if velocity.length() > 0:
		move_and_slide()


func move_to(position: Vector2) -> void:
	if _action_cooldown > 0:
		return
	
	_target_position = position
	_is_moving = true
	stats.set_state(BeepStats.State.MOVING)


func move_to_node(target_node: Node2D) -> void:
	_current_target = target_node
	move_to(target_node.position)


func collect_resource(resource_node: Node) -> void:
	if _action_cooldown > 0:
		return
	
	if resource_node.has_method("collect"):
		stats.set_state(BeepStats.State.WORKING)
		resource_node.collect()
		_action_cooldown = ACTION_COOLDOWN_TIME
		await get_tree().create_timer(ACTION_COOLDOWN_TIME).timeout
		stats.set_state(BeepStats.State.IDLE)


func eat() -> void:
	if _action_cooldown > 0 or not ResourceManager.remove_food(1.0):
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
	ColonyManager.unregister_beep(self)
	queue_free()


func _on_state_changed(new_state: String) -> void:
	if sprite:
		_update_animation(new_state)


func _update_animation(state: String) -> void:
	if animated_sprite:
		if animated_sprite.has_animation(state):
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
	var food_node = _find_nearest_resource_type(ResourceType.Type.FOOD)
	if food_node:
		move_to_node(food_node)
		stats.assigned_task = "seeking_food"
	elif ResourceManager.get_food() > 5.0:
		eat()


func collect_nearby_resource() -> void:
	var resource = _find_nearest_resource_type(null)
	if resource:
		collect_resource(resource)
		stats.assigned_task = "collecting"


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


func _find_nearest_resource_type(resource_type) -> Node:
	var nearest: Node = null
	var nearest_distance: float = 999999.0
	
	var parent = get_parent()
	if not parent:
		return null
	
	for child in parent.get_children():
		if child is ResourceNodeScene:
			var rn = child as ResourceNodeScene
			if rn and rn.is_active():
				if resource_type == null or rn.get_resource_type() == resource_type:
					var distance = position.distance_to(child.position)
					if distance < nearest_distance:
						nearest_distance = distance
						nearest = child
	
	return nearest


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
