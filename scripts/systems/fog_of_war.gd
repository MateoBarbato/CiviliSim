## Niebla de guerra
## Gestiona visibilidad del mapa basado en la posición de los beeps

class_name FogOfWarSystem
extends Node

## Señales
signal tile_revealed(tile_pos: Vector2i)
signal area_discovered(area_center: Vector2i, tiles_count: int)
signal map_fully_explored
signal fog_updated  # Se emite cada vez que el estado de niebla cambia

## Estados de un tile
enum TileState {
	UNKNOWN,   # Nunca visto — completamente oculto
	VISITED,   # Visto antes pero no en rango ahora
	VISIBLE    # En rango de detección actualmente
}

## Grid de visibilidad: Dictionary[Vector2i, TileState]
var _fog_grid: Dictionary = {}

## Configuración
const EXPLORE_RADIUS: int = 8      # tiles que revela cada beep
const UPDATE_INTERVAL: float = 0.5 # segundos entre updates de niebla

## Tracking de progreso
var _total_tiles: int = 0
var _revealed_count: int = 0
var _update_timer: float = 0.0

## Lista de beeps activos para actualizar visibilidad
var _active_beeps: Array[Node2D] = []


func _ready() -> void:
	_total_tiles = GameConfig.WORLD_WIDTH * GameConfig.WORLD_HEIGHT
	# Inicializar todo como UNKNOWN (no creamos el dict, usamos lazy init)


func _process(delta: float) -> void:
	if not ColonyManager.game_active:
		return

	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_fog()


## Revelar tiles alrededor de un beep (marcar como VISIBLE)
func reveal_around(beep_pos: Vector2) -> void:
	var tile_pos := _pixel_to_tile(beep_pos)
	var revealed_new: int = 0

	for dx in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
		for dy in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
			var dist: float = float(dx) * dx + float(dy) * dy
			if dist > float(EXPLORE_RADIUS) * EXPLORE_RADIUS:
				continue

			var pos := tile_pos + Vector2i(dx, dy)
			if not _is_in_bounds(pos):
				continue

			var prev_state: TileState = _get_tile_state(pos)
			if prev_state == TileState.UNKNOWN:
				_set_tile_state(pos, TileState.VISIBLE)
				revealed_new += 1
				tile_revealed.emit(pos)
			elif prev_state == TileState.VISITED:
				# Ya revelado pero fuera de rango — ahora vuelve a estar en rango
				_set_tile_state(pos, TileState.VISIBLE)

	if revealed_new > 0:
		_revealed_count += revealed_new
		if _revealed_count >= _total_tiles:
			map_fully_explored.emit()


## Revelar tiles en un área (para descubrimientos masivos)
func reveal_area(center: Vector2, radius: int) -> void:
	var tile_pos := _pixel_to_tile(center)
	var revealed_new: int = 0

	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var dist: float = float(dx) * dx + float(dy) * dy
			if dist > float(radius) * radius:
				continue

			var pos := tile_pos + Vector2i(dx, dy)
			if not _is_in_bounds(pos):
				continue

			var prev_state: TileState = _get_tile_state(pos)
			if prev_state == TileState.UNKNOWN:
				_set_tile_state(pos, TileState.VISIBLE)
				revealed_new += 1
			elif prev_state == TileState.VISITED:
				_set_tile_state(pos, TileState.VISIBLE)

	if revealed_new > 0:
		_revealed_count += revealed_new
		area_discovered.emit(tile_pos, revealed_new)


## Forzar actualización inmediata de niebla
func update_now() -> void:
	_update_fog()


## Actualizar niebla: marcar tiles fuera de rango como VISITED
func _update_fog() -> void:
	# Reset todos los tiles VISIBLE a VISITED
	for pos in _fog_grid:
		if _fog_grid[pos] == TileState.VISIBLE:
			_fog_grid[pos] = TileState.VISITED

	# Revelar alrededor de cada beep activo
	for beep in _active_beeps:
		if beep and not beep.is_queued_for_deletion() and beep.has_method("is_alive"):
			if beep.is_alive():
				reveal_around(beep.global_position)

	


## Registrar un beep para que actualice la niebla
func register_beep(beep: Node2D) -> void:
	if not _active_beeps.has(beep):
		_active_beeps.append(beep)
		# Revelar inmediatamente alrededor del beep al nacer
		if ColonyManager.game_active:
			reveal_around(beep.global_position)


## Desregistrar un beep
func unregister_beep(beep: Node2D) -> void:
	_active_beeps.erase(beep)


## ¿Es un tile visible (en rango de detección ahora)?
func is_visible(tile_pos: Vector2i) -> bool:
	return _get_tile_state(tile_pos) == TileState.VISIBLE


## ¿Ha sido visto antes (VISIBLE o VISITED)?
func is_revealed(tile_pos: Vector2i) -> bool:
	var state: TileState = _get_tile_state(tile_pos)
	return state == TileState.VISIBLE or state == TileState.VISITED


## Obtener el estado de un tile
func get_tile_state(tile_pos: Vector2i) -> TileState:
	return _get_tile_state(tile_pos)


## Porcentaje del mapa explorado (0.0 - 1.0)
func get_exploration_percentage() -> float:
	if _total_tiles <= 0:
		return 0.0
	return float(_revealed_count) / float(_total_tiles)


## Cantidad de tiles revelados
func get_revealed_count() -> int:
	return _revealed_count


## Cantidad total de tiles
func get_total_tiles() -> int:
	return _total_tiles


## Convertir píxeles a coordenadas de tile
static func _pixel_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(pos.x / GameConfig.TILE_SIZE, pos.y / GameConfig.TILE_SIZE)


## ¿Está dentro del mundo?
static func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GameConfig.WORLD_WIDTH and pos.y >= 0 and pos.y < GameConfig.WORLD_HEIGHT


## Helpers internos para el grid (lazy initialization)
func _get_tile_state(pos: Vector2i) -> TileState:
	if _fog_grid.has(pos):
		return _fog_grid[pos] as TileState
	return TileState.UNKNOWN


func _set_tile_state(pos: Vector2i, state: TileState) -> void:
	_fog_grid[pos] = state
