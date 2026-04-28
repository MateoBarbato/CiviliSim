## Definición de tipos de edificio para el MVP2

extends Node

enum Type { SHELTER, PATH, WAREHOUSE, RESEARCH_CENTER }

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
	},
	Type.WAREHOUSE: {
		"name": "Almacén",
		"icon_path": "res://assets/sprites/warehouse_sprite.png",
		"cost_wood": 25.0,
		"cost_stone": 15.0,
		"cost_food": 10.0,
		"capacity": 0,
		"build_time": 8.0,  # segundos - más lento, requiere más recursos
		"provides_shelter": false,
		"heals_per_second": 0.0,
		## Bonus a la capacidad máxima de recursos (multiplicador)
		"storage_bonus": {
			"food": 300.0,
			"wood": 200.0,
			"stone": 100.0
		}
	},
	Type.RESEARCH_CENTER: {
		"name": "Centro de Investigación",
		"icon_path": "res://assets/sprites/research_center_sprite.png",
		"cost_wood": 30.0,
		"cost_stone": 20.0,
		"cost_food": 15.0,
		"capacity": 0,
		"build_time": 10.0,  # segundos - el más lento
		"provides_shelter": false,
		"heals_per_second": 0.0,
		## Generación de conocimiento por segundo
		"knowledge_generation": 0.5,
		## Bonus de felicidad (los beeps investigan, mejora moral)
		"happiness_bonus": 0.1
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

static func get_all_types() -> Array:
	return [Type.SHELTER, Type.PATH, Type.WAREHOUSE, Type.RESEARCH_CENTER]


## Devolver tipos que se pueden construir (excluye PATH que se maneja aparte)
static func get_constructible_types() -> Array:
	return [Type.SHELTER, Type.WAREHOUSE, Type.RESEARCH_CENTER]


## Obtener bonus de almacenamiento de todos los almacenes activos
static func get_total_storage_bonus() -> Dictionary:
	var bonus := {"food": 0.0, "wood": 0.0, "stone": 0.0}
	for building in ColonyManager.buildings:
		if building.get("building_type") == "warehouse" and not building.get("is_under_construction", true):
			var data: Dictionary = DATA[Type.WAREHOUSE]
			if data.has("storage_bonus"):
				var sb: Dictionary = data["storage_bonus"]
				bonus["food"] += sb.get("food", 0.0)
				bonus["wood"] += sb.get("wood", 0.0)
				bonus["stone"] += sb.get("stone", 0.0)
	return bonus
