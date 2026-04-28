class_name WorldScene
extends Node2D

@onready var tile_map: TileMap = $TileMap
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var resource_container: Node2D = $ResourceContainer
@onready var beep_container: Node2D = $BeepContainer

const BEEP_SCENE: PackedScene = preload("res://scenes/beep/beep.tscn")
const RESOURCE_SCENE: PackedScene = preload("res://scenes/resources/resource_node.tscn")
const _TerrainTilesetGenerator = preload("res://scenes/world/_terrain_tileset_generator.gd")

var world_width: int = GameConfig.WORLD_WIDTH
var world_height: int = GameConfig.WORLD_HEIGHT

var _spawn_timer: float = 0.0
var _fog_visual: TileMap = null
var _fog_update_timer: float = 0.0
var _fog_enabled: bool = true

## Batch init de fog: pintar todo el mapa de negro
var _fog_init_y: int = 0

enum Terrain {
	GRASS,
	WATER,
	MOUNTAIN,
	SAND,
	FOREST
}

var terrain_stats: Dictionary = {}
var _terrain_map: Dictionary = {}

## Colores de terreno (fuente de verdad compartida con _terrain_tileset_generator)
const TERRAIN_COLORS: Dictionary = {
	Terrain.GRASS: Color(0.3, 0.7, 0.3),
	Terrain.WATER: Color(0.2, 0.4, 0.8),
	Terrain.MOUNTAIN: Color(0.5, 0.5, 0.5),
	Terrain.SAND: Color(0.9, 0.8, 0.5),
	Terrain.FOREST: Color(0.2, 0.5, 0.2),
}


func _ready() -> void:
	_generate_terrain()
	_create_terrain_visuals()
	_initialize_spawn_manager()
	_create_fog_overlay()


func _toggle_fog() -> void:
	_fog_enabled = not _fog_enabled
	if _fog_visual:
		_fog_visual.visible = _fog_enabled
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("[FOG] Toggle: ", "ON" if _fog_enabled else "OFF")


## Crear overlay de niebla de guerra
func _create_fog_overlay() -> void:
	_fog_visual = TileMap.new()
	_fog_visual.name = "FogOfWarVisual"
	_fog_visual.z_index = 100
	_setup_fog_tileset()
	add_child(_fog_visual)
	# Empezar pintado inicial en batches
	_fog_init_y = 0


func _setup_fog_tileset() -> void:
	var atlas_img := Image.create(GameConfig.TILE_SIZE * 2, GameConfig.TILE_SIZE, false, Image.FORMAT_RGBA8)
	# Tile 0: UNKNOWN (negro opaco)
	for dx in range(GameConfig.TILE_SIZE):
		for dy in range(GameConfig.TILE_SIZE):
			atlas_img.set_pixel(dx, dy, Color(0.05, 0.05, 0.08, 1.0))
	# Tile 1: VISITED (gris)
	for dx in range(GameConfig.TILE_SIZE):
		for dy in range(GameConfig.TILE_SIZE):
			atlas_img.set_pixel(GameConfig.TILE_SIZE + dx, dy, Color(0.15, 0.15, 0.2, 0.6))
	var atlas_tex := ImageTexture.create_from_image(atlas_img)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(1, 0))
	tileset.add_source(source, 0)
	_fog_visual.tile_set = tileset


func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= GameConfig.RESOURCE_SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_periodic_resources()

	# Batch init: pintar filas del mapa de negro
	if _fog_init_y < world_height:
		_paint_fog_init_rows(15)

	# Refrescar area visible
	_fog_update_timer += delta
	if _fog_update_timer >= 0.5:
		_fog_update_timer = 0.0
		call_deferred("_deferred_refresh_fog")


## Pintar filas del mapa como UNKNOWN (batch para no bloquear)
func _paint_fog_init_rows(rows: int) -> void:
	if _fog_visual == null:
		return
	var end_y: int = min(_fog_init_y + rows, world_height)
	for y in range(_fog_init_y, end_y):
		for x in range(world_width):
			_fog_visual.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))
	_fog_init_y = end_y


## Deferred refresh (executed after autoloads have processed)
func _deferred_refresh_fog() -> void:
	if not _fog_enabled or _fog_visual == null:
		return
	_refresh_visible_area()


## Refrescar solo el area visible de la camara
func _refresh_visible_area() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var cam_pos := cam.position
	var zoom_val := cam.zoom.x
	var vp_size: Vector2i = get_viewport().size
	var radius_x := ceilf(vp_size.x / 2.0 / zoom_val / GameConfig.TILE_SIZE) + 2
	var radius_y := ceilf(vp_size.y / 2.0 / zoom_val / GameConfig.TILE_SIZE) + 2
	var tile_center: Vector2i = Vector2i(cam_pos.x / GameConfig.TILE_SIZE, cam_pos.y / GameConfig.TILE_SIZE)

	for dx in range(-radius_x, radius_x + 1):
		for dy in range(-radius_y, radius_y + 1):
			var pos: Vector2i = tile_center + Vector2i(dx, dy)
			if pos.x < 0 or pos.x >= GameConfig.WORLD_WIDTH or pos.y < 0 or pos.y >= GameConfig.WORLD_HEIGHT:
				continue
			var state := FogOfWar.get_tile_state(pos)
			match state:
				FogOfWar.TileState.UNKNOWN:
					# Ya pintado en init, no hacer nada
					pass
				FogOfWar.TileState.VISITED:
					_fog_visual.set_cell(0, pos, 0, Vector2i(1, 0))
				FogOfWar.TileState.VISIBLE:
					_fog_visual.set_cell(0, pos, -1)


func _generate_terrain() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.01

	var grass_count: int = 0
	var water_count: int = 0
	var mountain_count: int = 0
	var sand_count: int = 0
	var forest_count: int = 0

	for x in range(world_width):
		for y in range(world_height):
			var noise_val: float = noise.get_noise_2d(x, y)
			var terrain: int

			if noise_val < -0.3:
				terrain = Terrain.WATER
				water_count += 1
			elif noise_val < -0.1:
				terrain = Terrain.SAND
				sand_count += 1
			elif noise_val > 0.5:
				terrain = Terrain.MOUNTAIN
				mountain_count += 1
			elif noise_val > 0.3:
				terrain = Terrain.FOREST
				forest_count += 1
			else:
				terrain = Terrain.GRASS
				grass_count += 1

			_terrain_map[Vector2i(x, y)] = terrain

	terrain_stats = {
		"grass": grass_count,
		"water": water_count,
		"mountain": mountain_count,
		"sand": sand_count,
		"forest": forest_count,
	}


func _create_terrain_visuals() -> void:
	var atlas_img = _TerrainTilesetGenerator.create_terrain_atlas()
	var atlas_tex = ImageTexture.create_from_image(atlas_img)

	# Configurar TileSet
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)

	# Crear AtlasSource
	var source = TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)

	# Registrar tiles (5 tipos de terreno)
	for i in range(5):
		source.create_tile(Vector2i(i, 0))

	tileset.add_source(source, 0)

	# Asignar al TileMap
	tile_map.tile_set = tileset
	tile_map.z_index = -1

	# Pintar terreno
	for x in range(world_width):
		for y in range(world_height):
			var terrain: int = _terrain_map.get(Vector2i(x, y), Terrain.GRASS)
			tile_map.set_cell(0, Vector2i(x, y), 0, Vector2i(terrain, 0))


func _initialize_spawn_manager() -> void:
	spawn_manager.set_tile_map(tile_map)
	spawn_manager._resource_scene = RESOURCE_SCENE
	spawn_manager._beep_scene = BEEP_SCENE
	_spawn_initial_resources()


func initialize_beeps() -> void:
	spawn_manager.spawn_initial_beeps(GameConfig.INITIAL_BEEP_COUNT, beep_container)
	# Forzar primer update de fog inmediatamente
	FogOfWar.update_now()


func _spawn_initial_resources() -> void:
	var resources = spawn_manager.spawn_resources(GameConfig.INITIAL_RESOURCE_COUNT, resource_container)
	for resource in resources:
		_connect_resource_signals(resource)


func _spawn_periodic_resources() -> void:
	if resource_container.get_child_count() >= GameConfig.MAX_RESOURCES_ON_MAP:
		return
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


func _on_resource_depleted() -> void:
	# TODO: despawn visual del nodo agotado y/o respawn después de un delay
	pass


func is_walkable(pos: Vector2i) -> bool:
	var cell_terrain: Terrain = _get_terrain_at(pos)
	return cell_terrain != Terrain.WATER and cell_terrain != Terrain.MOUNTAIN


func _get_terrain_at(pos: Vector2i) -> Terrain:
	if pos.x < 0 or pos.x >= world_width:
		return Terrain.WATER
	if pos.y < 0 or pos.y >= world_height:
		return Terrain.WATER
	return _terrain_map.get(pos, Terrain.GRASS)


func get_random_walkable_position() -> Vector2i:
	var attempts: int = 0
	while attempts < 1000:
		var x: int = randi() % world_width
		var y: int = randi() % world_height
		if is_walkable(Vector2i(x, y)):
			return Vector2i(x, y)
		attempts += 1
	return Vector2i(world_width / 2, world_height / 2)
