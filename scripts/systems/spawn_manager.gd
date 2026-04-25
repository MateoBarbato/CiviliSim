## Gestiona el spawneo de recursos y Beeps en el mundo

class_name SpawnManager
extends Node

signal resource_spawned(resource_node: Node)
signal beep_spawned(beep_node: Node)

## Scene del Beep (se carga dinámicamente)
var _beep_scene: PackedScene = null

## Scene de ResourceNode (se carga dinámicamente)
var _resource_scene: PackedScene = null

## Referencia al TileMap para verificar posiciones válidas
var _tile_map: TileMap = null

## Dimensiones del mundo en tiles
var _world_width: int = GameConfig.WORLD_WIDTH
var _world_height: int = GameConfig.WORLD_HEIGHT

## Beeps spawneados
var spawned_beeps: Array = []

## Recursos spawneados
var spawned_resources: Array = []


func _ready() -> void:
	pass


func set_tile_map(tile_map: TileMap) -> void:
	_tile_map = tile_map


func load_beep_scene(scene_path: String) -> void:
	_beep_scene = load(scene_path)


func load_resource_scene(scene_path: String) -> void:
	_resource_scene = load(scene_path)


func spawn_initial_beeps(count: int, parent_node: Node) -> Array:
	var beeps: Array = []
	var spawn_positions: Array = _get_valid_spawn_positions(count, 100)
	
	for i in range(mini(count, spawn_positions.size())):
		if _beep_scene == null:
			push_warning("Beep scene no cargada. Usa load_beep_scene primero.")
			return beeps
		
		var beep: Node = _beep_scene.instantiate()
		beep.position = spawn_positions[i]
		parent_node.add_child(beep)
		beeps.append(beep)
		spawned_beeps.append(beep)
		beep_spawned.emit(beep)
	
	return beeps


func spawn_resources(count: int, parent_node: Node) -> Array:
	var resources: Array = []
	
	for i in range(count):
		if _resource_scene == null:
			push_warning("Resource scene no cargada.")
			return resources
		
		var pos: Vector2I = _get_random_valid_position()
		var resource_type: ResourceType.Type = _pick_resource_type()
		
		var resource: Node = _resource_scene.instantiate()
		resource.position = Vector2(pos) * GameConfig.TILE_SIZE
		resource.set_resource_type(resource_type)
		parent_node.add_child(resource)
		resources.append(resource)
		spawned_resources.append(resource)
		resource_spawned.emit(resource)
	
	return resources


func spawn_resource_at(position: Vector2I, resource_type: ResourceType.Type, parent_node: Node) -> Node:
	if _resource_scene == null:
		return null
	
	var resource: Node = _resource_scene.instantiate()
	resource.position = Vector2(position) * GameConfig.TILE_SIZE
	resource.set_resource_type(resource_type)
	parent_node.add_child(resource)
	spawned_resources.append(resource)
	resource_spawned.emit(resource)
	
	return resource


func _get_random_valid_position() -> Vector2I:
	var attempts: int = 0
	while attempts < 100:
		var x: int = randi() % _world_width
		var y: int = randi() % _world_height
		if _is_valid_spawn_position(x, y):
			return Vector2i(x, y)
		attempts += 1
	
	# Si no encuentra posición válida, retornar centro
	return Vector2i(_world_width / 2, _world_height / 2)


func _get_valid_spawn_positions(count: int, min_distance: float) -> Array:
	var positions: Array = []
	var center: Vector2 = Vector2(_world_width / 2, _world_height / 2) * GameConfig.TILE_SIZE
	
	for i in range(count):
		var angle: float = (TAU * i) / count
		var radius: float = 50.0 + (randf() * 50.0)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		positions.append(pos)
	
	return positions


func _is_valid_spawn_position(x: int, y: int) -> bool:
	if _tile_map == null:
		return true
	# Verificar que no sea agua ni montaña
	return true


func _pick_resource_type() -> ResourceType.Type:
	var total_weight: int = 0
	for rt in ResourceType.get_all_types():
		total_weight += ResourceType.get_spawn_weight(rt)
	
	var roll: int = randi() % total_weight
	var current: int = 0
	
	for rt in ResourceType.get_all_types():
		current += ResourceType.get_spawn_weight(rt)
		if roll < current:
			return rt
	
	return ResourceType.Type.FOOD


func clear_all() -> void:
	for beep in spawned_beeps:
		if is_instance_valid(beep):
			beep.queue_free()
	spawned_beeps.clear()
	
	for res in spawned_resources:
		if is_instance_valid(res):
			res.queue_free()
	spawned_resources.clear()
