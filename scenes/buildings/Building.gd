## Edificio base
## Clase base para todos los edificios del juego

class_name BuildingBase
extends Node2D

signal building_constructed(building_type: String)
signal building_destroyed
signal building_updated

## Tipo de edificio
var building_type: String = "unknown"

## Estado de construcci
var is_under_construction: bool = true
var construction_progress: float = 0.0
var construction_time: float = 5.0

## Capacidad
var capacity: int = 10
var current_occupants: int = 0

## Referencias visuales
@onready var sprite: Sprite2D = $Sprite2D
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	ColonyManager.register_building(self)
	_update_visuals()


func _process(delta: float) -> void:
	if is_under_construction:
		_construct(delta)


func _construct(delta: float) -> void:
	construction_progress += (delta / construction_time)
	
	if construction_progress >= 1.0:
		construction_progress = 1.0
		_construction_complete()
	
	_update_progress_bar()


func _construction_complete() -> void:
	is_under_construction = false
	building_constructed.emit(building_type)
	
	if progress_bar:
		progress_bar.hide()
	
	_update_visuals()


func _update_visuals() -> void:
	if sprite:
		if is_under_construction:
			sprite.modulate = Color(0.5, 0.5, 0.5, 1)
		else:
			sprite.modulate = Color(1, 1, 1, 1)


func _update_progress_bar() -> void:
	if progress_bar:
		progress_bar.value = construction_progress * 100.0


func add_occupant() -> bool:
	if current_occupants < capacity:
		current_occupants += 1
		return true
	return false


func remove_occupant() -> bool:
	if current_occupants > 0:
		current_occupants -= 1
		return true
	return false


func is_full() -> bool:
	return current_occupants >= capacity


func has_space() -> bool:
	return current_occupants < capacity


func get_occupancy() -> float:
	if capacity == 0:
		return 0.0
	return float(current_occupants) / float(capacity)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		ColonyManager.unregister_building(self)
		building_destroyed.emit()
