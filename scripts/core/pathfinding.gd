## A* Pathfinding implementation
## Grid-based pathfinding that avoids WATER and MOUNTAIN tiles

class_name Pathfinding
extends RefCounted

## Grid cell size in pixels (from GameConfig.TILE_SIZE)
const CELL_SIZE: float = float(GameConfig.TILE_SIZE)

## Maximum path length to prevent excessive computation
const MAX_PATH_LENGTH: int = 500

## Minimum distance between consecutive waypoints (pixels)
const WAYPOINT_SKIP: float = 80.0


## Find path from start to end using A*
## Returns array of Vector2 waypoints in pixel coordinates
static func find_path(world: WorldScene, start: Vector2, end: Vector2) -> Array[Vector2]:
	var start_cell := _to_cell(start)
	var end_cell := _to_cell(end)

	if not world.is_walkable(start_cell):
		start_cell = _find_nearest_walkable(world, start_cell)
	if not world.is_walkable(end_cell):
		end_cell = _find_nearest_walkable(world, end_cell)

	if start_cell == end_cell:
		return [Vector2(end_cell) * CELL_SIZE]

	var open_set: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}

	g_score[start_cell] = 0.0
	f_score[start_cell] = _heuristic(start_cell, end_cell)

	var closed_set: Dictionary = {}

	while not open_set.is_empty():
		var current := _find_lowest_f(open_set, f_score)
		if current == end_cell:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)
		closed_set[current] = true

		for neighbor in _get_neighbors(current):
			if closed_set.has(neighbor):
				continue

			var tentative_g: float = g_score[current] + _movement_cost(current, neighbor)

			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, end_cell)

				if not open_set.has(neighbor):
					open_set.append(neighbor)

		if g_score.size() > MAX_PATH_LENGTH:
			break

	return []


## Simplify path by removing unnecessary intermediate waypoints
static func simplify_path(path: Array[Vector2], min_distance: float = WAYPOINT_SKIP) -> Array[Vector2]:
	if path.size() <= 2:
		return path

	var simplified: Array[Vector2] = [path[0]]
	var i: int = 0

	while i < path.size() - 1:
		var current: Vector2 = path[i]
		var next: Vector2 = path[i + 1]
		if current.distance_to(next) >= min_distance:
			simplified.append(next)
			i += 1
		else:
			i += 1

	if not simplified.is_empty():
		simplified.append(path[-1])

	return simplified


static func _to_cell(position: Vector2) -> Vector2i:
	return Vector2i(int(position.x / CELL_SIZE), int(position.y / CELL_SIZE))


static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return maxf(dx, dy) + 0.414 * minf(dx, dy)


static func _movement_cost(from: Vector2i, to: Vector2i) -> float:
	var dx := absi(from.x - to.x)
	var dy := absi(from.y - to.y)
	if dx > 0 and dy > 0:
		return 1.414
	return 1.0


static func _find_lowest_f(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var lowest: Vector2i = open_set[0]
	var lowest_f: float = f_score[lowest]
	for cell in open_set:
		var f: float = f_score[cell]
		if f < lowest_f:
			lowest = cell
			lowest_f = f
	return lowest


static func _get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(cell.x - 1, cell.y - 1),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x + 1, cell.y - 1),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y + 1),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x + 1, cell.y + 1),
	]


static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2]:
	var path: Array[Vector2] = [Vector2(current) * CELL_SIZE]
	while came_from.has(current):
		current = came_from[current]
		path.append(Vector2(current) * CELL_SIZE)
	path.reverse()
	return path


static func _find_nearest_walkable(world: WorldScene, cell: Vector2i) -> Vector2i:
	var radius: int = 1
	while radius <= 10:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var check := Vector2i(cell.x + dx, cell.y + dy)
				if world.is_walkable(check):
					return check
		radius += 1
	return cell
