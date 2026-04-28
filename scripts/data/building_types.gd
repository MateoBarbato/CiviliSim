## Definición de tipos de edificio para el MVP1

extends Node

enum Type { SHELTER, PATH }

const DATA: Dictionary = {
	Type.SHELTER: {
		"name": "Refugio",
		"icon_path": "res://assets/sprites/shelter_sprite.png",
		"cost_wood": 15.0,
		"cost_stone": 5.0,
		"cost_food": 0.0,
		"capacity": 10,
		"build_time": 5.0,  # segundos
		"provides_shelter": true,
		"heals_per_second": 1.0
	},
	Type.PATH: {
		"name": "Camino",
		"icon_path": "res://assets/sprites/path_sprite.png",
		"cost_wood": 3.0,
		"cost_stone": 1.0,
		"cost_food": 0.0,
		"capacity": 0,
		"build_time": 2.0,  # segundos - más rápido que shelter
		"provides_shelter": false,
		"heals_per_second": 0.0
	}
}

static func get_building_name(building_type: Type) -> String:
	return DATA[building_type]["name"]

static func get_cost_wood(building_type: Type) -> float:
	return DATA[building_type]["cost_wood"]

static func get_cost_stone(building_type: Type) -> float:
	return DATA[building_type]["cost_stone"]

static func get_cost_food(building_type: Type) -> float:
	return DATA[building_type]["cost_food"]

static func get_capacity(building_type: Type) -> int:
	return DATA[building_type]["capacity"]

static func get_build_time(building_type: Type) -> float:
	return DATA[building_type]["build_time"]

static func get_all_types() -> Array[Type]:
	return [Type.SHELTER, Type.PATH]
