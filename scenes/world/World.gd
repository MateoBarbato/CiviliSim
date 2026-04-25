## Scene del mundo 2D tileado
## Genera el terreno proceduralmente y gestiona las capas del TileMap

class_name WorldScene
extends Node2D

## Referencia al TileMap
@onready var tile_map: TileMap = $TileMap

## Referencia al SpawnManager
@onready var spawn_manager: SpawnManager = $SpawnManager

## Contenedor de recursos
@onready var resource_container: Node2D = $ResourceContainer

## Contenedor de Beeps
@onready var beep_container: Node2D = $BeepContainer

## Escenas pre-cargadas
const BEEP_SCENE: PackedScene = preload("res://scenes/beep/beep.tscn")
const RESOURCE_SCENE: PackedScene = preload("res://scenes/resources/resource_node.tscn")

## Dimensiones del mundo
var world_width: int = GameConfig.WORLD_WIDTH
var world_height: int = GameConfig.WORLD_HEIGHT

## Recursos iniciales a spawneear
const INITIAL_RESOURCE_COUNT: int = 30

## Intervalo de spawneo periódico
var _spawn_timer: float = 0.0

## Tipos de terreno
enum Terrain {
	GRASS,      # Pasto - transitable
	WATER,      # Agua - no transitable
	MOUNTAIN,   # Montaña - no transitable
	SAND,       # Arena - transitable
	FOREST      # Bosque - transitable (bonus madera)
}

## Estadísticas del mundo generado
var terrain_stats: Dictionary = {}


func _ready() -> void:
	_initialize_spawn_manager()


func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= GameConfig.RESOURCE_SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_periodic_resources()


func _initialize_spawn_manager() -> void:
	spawn_manager.set_tile_map(tile_map)
	spawn_manager._resource_scene = RESOURCE_SCENE
	spawn_manager._beep_scene = BEEP_SCENE
	_spawn_initial_resources()


func initialize_beeps() -> void:
	spawn_manager.spawn_initial_beeps(GameConfig.INITIAL_BEEP_COUNT, beep_container)


func _spawn_initial_resources() -> void:
	var resources = spawn_manager.spawn_resources(INITIAL_RESOURCE_COUNT, resource_container)
	for resource in resources:
		_connect_resource_signals(resource)


func _spawn_periodic_resources() -> void:
	var resource = spawn_manager.spawn_resource_at(
		spawn_manager._get_random_valid_position(),
		spawn_manager._pick_resource_type(),
		resource_container
	)
	if resource != null:
		_connect_resource_signals(resource)


func _connect_resource_signals(resource_node: Node) -> void:
	if resource_node.has_signal("resource_collected"):
		resource_node.resource_collected.connect(_on_resource_collected.bind())
	if resource_node.has_signal("resource_depleted"):
		resource_node.resource_depleted.connect(_on_resource_depleted.bind())


func _on_resource_collected(resource_type: ResourceType.Type, amount: float) -> void:
	match resource_type:
		ResourceType.Type.FOOD:
			ResourceManager.add_food(amount)
		ResourceType.Type.WOOD:
			ResourceManager.add_wood(amount)
		ResourceType.Type.STONE:
			ResourceManager.add_stone(amount)


func _on_resource_depleted(resource_node: Node) -> void:
	pass


# TODO: Implementar generación de terreno con TileSet
# func _configure_noise() -> void:
# 	_noise.seed = randi()
# 	_noise.noise_type = FastNoiseLite.TYPE_PERLIN_SIMPLEX
# 	_noise.period = 100.0
# 	_noise.frequency = 0.01
# 	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
#
#
# func _configure_tile_map_layers() -> void:
# 	pass
#
#
# func _generate_terrain() -> void:
# 	pass


func is_walkable(position: Vector2i) -> bool:
	# Verificar si la posición es transitable
	# Agua y montaña no son transitables
	var cell_terrain: Terrain = _get_terrain_at(position)
	return cell_terrain != Terrain.WATER and cell_terrain != Terrain.MOUNTAIN


func _get_terrain_at(position: Vector2i) -> Terrain:
	if position.x < 0 or position.x >= world_width:
		return Terrain.WATER
	if position.y < 0 or position.y >= world_height:
		return Terrain.WATER
	
	# Consultar el TileMap para obtener el terreno
	# Por ahora retornamos pasto como default
	return Terrain.GRASS


func get_random_walkable_position() -> Vector2i:
	var attempts: int = 0
	while attempts < 1000:
		var x: int = randi() % world_width
		var y: int = randi() % world_height
		if is_walkable(Vector2i(x, y)):
			return Vector2i(x, y)
		attempts += 1
	
	# Fallback al centro
	return Vector2i(world_width / 2, world_height / 2)
