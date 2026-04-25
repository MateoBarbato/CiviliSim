## Definición de tipos de recurso para el MVP1

class_name ResourceType
extends RefCounted

enum Type { FOOD, WOOD, STONE }

const DATA: Dictionary = {
	Type.FOOD: {
		"name": "Comida",
		"icon_path": "res://assets/sprites/resource_food.png",
		"color": Color.GREEN,
		"spawn_weight": 40,  # probabilidad relativa de spawn
		"max_cluster_size": 5,
		"replenish_time": 120.0  # segundos para reaparecer
	},
	Type.WOOD: {
		"name": "Madera",
		"icon_path": "res://assets/sprites/resource_wood.png",
		"color": Color.SADDLE_BROWN,
		"spawn_weight": 35,
		"max_cluster_size": 3,
		"replenish_time": 300.0
	},
	Type.STONE: {
		"name": "Piedra",
		"icon_path": "res://assets/sprites/resource_stone.png",
		"color": Color.GRAY,
		"spawn_weight": 25,
		"max_cluster_size": 2,
		"replenish_time": 600.0
	}
}

static func get_name(resource_type: Type) -> String:
	return DATA[resource_type]["name"]

static func get_color(resource_type: Type) -> Color:
	return DATA[resource_type]["color"]

static func get_spawn_weight(resource_type: Type) -> int:
	return DATA[resource_type]["spawn_weight"]

static func get_all_types() -> Array[Type]:
	return [Type.FOOD, Type.WOOD, Type.STONE]
