## Gestiona los recursos globales de la colonia
## Autoload: ResourceManager

class_name ResourceManager
extends Node

signal resource_changed(resource_type: String, amount: float)
signal resource_critical(resource_type: String)

## Recursos disponibles
var food: float = 0.0
var wood: float = 0.0
var stone: float = 0.0

## Límites
const MAX_FOOD: float = 500.0
const MAX_WOOD: float = 300.0
const MAX_STONE: float = 200.0

## Umbrales críticos
const CRITICAL_FOOD: float = 10.0
const CRITICAL_WOOD: float = 5.0
const CRITICAL_STONE: float = 2.0


func _ready() -> void:
	_init_resources()


func _init_resources() -> void:
	food = GameConfig.INITIAL_FOOD
	wood = GameConfig.INITIAL_WOOD
	stone = GameConfig.INITIAL_STONE


func add_food(amount: float) -> void:
	food = minf(food + amount, MAX_FOOD)
	resource_changed.emit("food", food)


func remove_food(amount: float) -> bool:
	if food >= amount:
		food -= amount
		resource_changed.emit("food", food)
		_check_critical()
		return true
	return false


func add_wood(amount: float) -> void:
	wood = minf(wood + amount, MAX_WOOD)
	resource_changed.emit("wood", wood)


func remove_wood(amount: float) -> bool:
	if wood >= amount:
		wood -= amount
		resource_changed.emit("wood", wood)
		_check_critical()
		return true
	return false


func add_stone(amount: float) -> void:
	stone = minf(stone + amount, MAX_STONE)
	resource_changed.emit("stone", stone)


func remove_stone(amount: float) -> bool:
	if stone >= amount:
		stone -= amount
		resource_changed.emit("stone", stone)
		_check_critical()
		return true
	return false


func get_food() -> float:
	return food


func get_wood() -> float:
	return wood


func get_stone() -> float:
	return stone


func has_enough_for_shelter() -> bool:
	return wood >= BuildingType.get_cost_wood(BuildingType.Type.SHELTER) and \
		   stone >= BuildingType.get_cost_stone(BuildingType.Type.SHELTER)


func consume_shelter_cost() -> bool:
	var wood_cost: float = BuildingType.get_cost_wood(BuildingType.Type.SHELTER)
	var stone_cost: float = BuildingType.get_cost_stone(BuildingType.Type.SHELTER)
	
	if wood >= wood_cost and stone >= stone_cost:
		remove_wood(wood_cost)
		remove_stone(stone_cost)
		return true
	return false


func _check_critical() -> void:
	if food <= CRITICAL_FOOD:
		resource_critical.emit("food")
	if wood <= CRITICAL_WOOD:
		resource_critical.emit("wood")
	if stone <= CRITICAL_STONE:
		resource_critical.emit("stone")


func get_resource_state() -> Dictionary:
	return {
		"food": food,
		"wood": wood,
		"stone": stone,
		"food_percent": (food / MAX_FOOD) * 100.0,
		"wood_percent": (wood / MAX_WOOD) * 100.0,
		"stone_percent": (stone / MAX_STONE) * 100.0
	}


func reset() -> void:
	_init_resources()
