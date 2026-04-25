## Scene del mundo 2D tileado
## Genera el terreno proceduralmente y gestiona las capas del TileMap

class_name WorldScene
extends Node2D

## Referencia al TileMap
@onready var tile_map: TileMap = $TileMap

## Referencia al SpawnManager
@onready var spawn_manager: Node = $SpawnManager

## Contenedor de recursos
@onready var resource_container: Node2D = $ResourceContainer

## Contenedor de Beeps
@onready var beep_container: Node2D = $BeepContainer

## Generador de ruido para terreno
var _noise: FastNoiseLite = FastNoiseLite.new()

## Dimensiones del mundo
var world_width: int = GameConfig.WORLD_WIDTH
var world_height: int = GameConfig.WORLD_HEIGHT

## Recursos iniciales a spawneear
const INITIAL_RESOURCE_COUNT: int = 30

## Intervalo de spawneo periódico
const SPAWN_INTERVAL: float = 30.0
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
	_configure_noise()
	_generate_terrain()
	_configure_tile_map_layers()
	_calculate_terrain_stats()
	_initialize_spawn_manager()


func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_periodic_resources()


func _initialize_spawn_manager() -> void:
	spawn_manager.set_tile_map(tile_map)
	spawn_manager.load_resource_scene("res://scenes/resources/resource_node.tscn")
	spawn_manager.load_beep_scene("res://scenes/beep/beep.tscn")
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


func _configure_noise() -> void:
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN_SIMPLEX
	_noise.period = 100.0
	_noise.frequency = 0.01
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE


func _configure_tile_map_layers() -> void:
	# Configurar las capas del TileMap
	# Capa 0: Terreno base
	# Capa 1: Recursos
	# Capa 2: Edificios
	pass


func _generate_terrain() -> void:
	# Generar terreno usando ruido de Perlin
	# Se crean tiles de colores para el prototipo
	var terrain_data: Dictionary = {}
	
	for x in range(world_width):
		for y in range(world_height):
			var noise_value: float = _noise.get_noise_2d(x, y)
			var terrain_type: Terrain = _classify_terrain(noise_value)
			terrain_data["%d,%d" % [x, y]] = terrain_type
	
	# Aplicar suavizado al terreno (cellular automata passes)
	for _pass in range(3):
		terrain_data = _smooth_terrain(terrain_data)
	
	# Pintar el terreno en el TileMap
	_paint_terrain(terrain_data)


func _classify_terrain(noise_value: float) -> Terrain:
	if noise_value < -0.3:
		return Terrain.WATER
	elif noise_value < -0.1:
		return Terrain.SAND
	elif noise_value > 0.5:
		return Terrain.MOUNTAIN
	elif noise_value > 0.3:
		return Terrain.FOREST
	else:
		return Terrain.GRASS


func _smooth_terrain(terrain_data: Dictionary) -> Dictionary:
	var smoothed: Dictionary = terrain_data.duplicate()
	
	for x in range(1, world_width - 1):
		for y in range(1, world_height - 1):
			var neighbors: Array = [
				terrain_data.get("%d,%d" % [x-1, y], Terrain.GRASS),
				terrain_data.get("%d,%d" % [x+1, y], Terrain.GRASS),
				terrain_data.get("%d,%d" % [x, y-1], Terrain.GRASS),
				terrain_data.get("%d,%d" % [x, y+1], Terrain.GRASS)
			]
			
			# Contar tipos de vecinos
			var counts: Dictionary = {}
			for neighbor in neighbors:
				counts[neighbor] = counts.get(neighbor, 0) + 1
			
			# Usar el tipo más común
			var max_count: int = 0
			var dominant_type: Terrain = terrain_data["%d,%d" % [x, y]]
			for type in counts:
				if counts[type] > max_count:
					max_count = counts[type]
					dominant_type = type
			
			smoothed["%d,%d" % [x, y]] = dominant_type
	
	return smoothed


func _paint_terrain(terrain_data: Dictionary) -> void:
	# Para el prototipo, usamos colores sólidos
	# En producción se usarían sprites de tiles
	for x in range(world_width):
		for y in range(world_height):
			var terrain_type: Terrain = terrain_data["%d,%d" % [x, y]]
			var color: Color = _get_terrain_color(terrain_type)
			
			# Crear un ColorRect para cada tile (prototipo)
			# En producción se usa TileMap con TileSet
			pass  # Se implementa con TileSet real


func _get_terrain_color(terrain_type: Terrain) -> Color:
	match terrain_type:
		Terrain.GRASS:
			return Color(0.4, 0.7, 0.3)
		Terrain.WATER:
			return Color(0.2, 0.4, 0.8)
		Terrain.MOUNTAIN:
			return Color(0.5, 0.5, 0.5)
		Terrain.SAND:
			return Color(0.8, 0.75, 0.5)
		Terrain.FOREST:
			return Color(0.2, 0.5, 0.2)
		_:
			return Color.WHITE


func _calculate_terrain_stats() -> void:
	var stats: Dictionary = {
		Terrain.GRASS: 0,
		Terrain.WATER: 0,
		Terrain.MOUNTAIN: 0,
		Terrain.SAND: 0,
		Terrain.FOREST: 0
	}
	
	# Contar tiles de cada tipo
	# (Se implementa al generar el terreno)
	terrain_stats = stats


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
