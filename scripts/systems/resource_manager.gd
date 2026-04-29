## Gestiona los recursos globales de la colonia
## Autoload: ResourceManager

extends Node

signal resource_changed(resource_type: String, amount: float)
signal resource_critical(resource_type: String)

## Recursos disponibles
var food: float = 0.0
var wood: float = 0.0
var stone: float = 0.0

## Límites base (sin bonus de almacenes)
const BASE_MAX_FOOD: float = 500.0
const BASE_MAX_WOOD: float = 300.0
const BASE_MAX_STONE: float = 200.0

## Límites actuales (base + bonus de warehouses)
var max_food: float = BASE_MAX_FOOD
var max_wood: float = BASE_MAX_WOOD
var max_stone: float = BASE_MAX_STONE

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
	_init_max_capacity()


func add_food(amount: float) -> void:
	food = minf(food + amount, max_food)
	resource_changed.emit("food", food)


func remove_food(amount: float) -> bool:
	if food >= amount:
		food -= amount
		resource_changed.emit("food", food)
		_check_critical()
		return true
	return false


func add_wood(amount: float) -> void:
	wood = minf(wood + amount, max_wood)
	resource_changed.emit("wood", wood)


func remove_wood(amount: float) -> bool:
	if wood >= amount:
		wood -= amount
		resource_changed.emit("wood", wood)
		_check_critical()
		return true
	return false


func add_stone(amount: float) -> void:
	stone = minf(stone + amount, max_stone)
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
		"food_percent": (food / max_food) * 100.0,
		"wood_percent": (wood / max_wood) * 100.0,
		"stone_percent": (stone / max_stone) * 100.0,
		"max_food": max_food,
		"max_wood": max_wood,
		"max_stone": max_stone
	}


## Recalcular límites de almacenamiento según almacenes activos
## Se llama desde WarehouseBuilding cuando se construye/destruye un almacén
func recalculate_max_capacity() -> void:
	var bonus: Dictionary = BuildingType.get_total_storage_bonus()
	max_food = BASE_MAX_FOOD + bonus["food"]
	max_wood = BASE_MAX_WOOD + bonus["wood"]
	max_stone = BASE_MAX_STONE + bonus["stone"]
	print("[ResourceManager] Capacidad actualizada -> food: %.0f, wood: %.0f, stone: %.0f" % [max_food, max_wood, max_stone])


func reset() -> void:
	_init_resources()
	_init_max_capacity()


func _init_max_capacity() -> void:
	max_food = BASE_MAX_FOOD
	max_wood = BASE_MAX_WOOD
	max_stone = BASE_MAX_STONE


## --- Save / Load ---

func get_save_data() -> Dictionary:
	return {
		"food": food,
		"wood": wood,
		"stone": stone,
		"max_food": max_food,
		"max_wood": max_wood,
		"max_stone": max_stone,
	}


func apply_save_data(data: Dictionary) -> void:
	food = data.get("food", food)
	wood = data.get("wood", wood)
	stone = data.get("stone", stone)
	max_food = data.get("max_food", max_food)
	max_wood = data.get("max_wood", max_wood)
	max_stone = data.get("max_stone", max_stone)
