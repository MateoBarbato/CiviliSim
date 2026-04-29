## Sistema de guardado y carga del juego
## Autoload: SaveSystem

extends Node

## Señales
signal save_completed(path: String)
signal load_completed(path: String)
signal save_failed(error: String)
signal load_failed(error: String)

## Configuración
const SAVE_DIR: String = "user://saves"
const SAVE_EXTENSION: String = ".json"
const AUTO_SAVE_SLOT: String = "autosave"
const MAX_AUTO_SAVES: int = 3

## Auto-save
var _auto_save_timer: float = 0.0
var AUTO_SAVE_INTERVAL: float = 120.0  # 2 minutos


func _ready() -> void:
	_ensure_save_directory()


func _process(delta: float) -> void:
	if not ColonyManager.game_active:
		return

	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		_auto_save()


## --- API Pública ---

## Guardar juego con nombre de slot
func save_game(slot_name: String = "save1") -> bool:
	var data: Dictionary = _collect_full_state()
	if data.is_empty():
		push_error("[SaveSystem] No hay datos para guardar")
		save_failed.emit("Estado vacío")
		return false

	var path: String = _get_save_path(slot_name)
	var success: bool = _write_json(path, data)

	if success:
		# Guardar metadata de timestamp
		_update_save_thumbnail(slot_name)
		save_completed.emit(slot_name)
		print("[SaveSystem] Juego guardado en: ", slot_name)
	else:
		save_failed.emit("Error escribiendo archivo")
		return false

	return true


## Cargar juego desde un slot (async - usar con await)
func load_game(slot_name: String) -> bool:
	var path: String = _get_save_path(slot_name)
	var data: Variant = _read_json(path)

	if data == null or not data is Dictionary:
		push_error("[SaveSystem] No se pudo cargar: ", slot_name)
		load_failed.emit("Archivo no válido o corrupto")
		return false

	var success: bool = yield(_restore_full_state(data), "completed")
	if success:
		load_completed.emit(slot_name)
		print("[SaveSystem] Juego cargado desde: ", slot_name)
		# Reiniciar timer de auto-guardado
		_auto_save_timer = 0.0
	else:
		load_failed.emit("Error restaurando estado")

	return success


## Listar slots disponibles
func list_saves() -> Array[String]:
	var saves: Array[String] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return saves

	var dir := DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next_file_name()
		while file_name != "":
			if file_name.ends_with(SAVE_EXTENSION) and not file_name.begins_with("."):
				var slot_name: String = file_name.trim_suffix(SAVE_EXTENSION)
				saves.append(slot_name)
			file_name = dir.get_next_file_name()
	dir.list_dir_end()

	saves.sort()
	return saves


## Eliminar un slot
func delete_save(slot_name: String) -> bool:
	var path: String = _get_save_path(slot_name)
	if not FileAccess.file_exists(path):
		return false

	DirAccess.remove_absolute(path)
	print("[SaveSystem] Slot eliminado: ", slot_name)
	return true


## Verificar si existe un slot
func save_exists(slot_name: String) -> bool:
	var path: String = _get_save_path(slot_name)
	return FileAccess.file_exists(path)


## Guardar timestamp del último guardado (thumbnail data)
func _update_save_thumbnail(slot_name: String) -> void:
	var thumb_path: String = SAVE_DIR + "/%s.thumb" % slot_name
	var thumb_data: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"game_time": ColonyManager.game_time,
		"population": ColonyManager.population,
		"happiness": ColonyManager.happiness,
	}
	_write_json(thumb_path, thumb_data)


## Leer thumbnail de un slot
func get_save_thumbnail(slot_name: String) -> Dictionary:
	var thumb_path: String = SAVE_DIR + "/%s.thumb" % slot_name
	var data: Variant = _read_json(thumb_path)
	if data is Dictionary:
		return data
	return {}


## Auto-guardado silencioso
func _auto_save() -> void:
	if not ColonyManager.game_active:
		return
	var data: Dictionary = _collect_full_state()
	if data.is_empty():
		return
	var path: String = _get_save_path(AUTO_SAVE_SLOT)
	_write_json(path, data)
	print("[SaveSystem] Auto-guardado completado")


## --- Colección de Estado ---

## Recopilar TODO el estado del juego en un diccionario serializable
func _collect_full_state() -> Dictionary:
	var state: Dictionary = {}

	# Metadata
	state["meta"] = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
	}

	# ColonyManager
	state["colony"] = _collect_colony_state()

	# ResourceManager
	state["resources"] = ResourceManager.get_save_data()

	# WeatherSystem
	state["weather"] = WeatherSystem.get_save_data()

	# ConstructionManager
	state["construction"] = ConstructionManager.get_save_data()

	# ReproductionSystem
	var repro: Node = _get_reproduction_system()
	if repro and repro.has_method("get_save_data"):
		state["reproduction"] = repro.get_save_data()

	# DecisionSystem
	var decision: Node = _get_decision_system()
	if decision and decision.has_method("get_save_data"):
		state["decision"] = decision.get_save_data()

	# FogOfWar
	state["fog_of_war"] = FogOfWar.get_save_data()

	# Beeps (individual state + role)
	state["beeps"] = _collect_beeps_state()

	# Buildings
	state["buildings"] = _collect_buildings_state()

	# Resource nodes
	state["resource_nodes"] = _collect_resource_nodes_state()

	return state


## --- Restauración de Estado ---

## Restaurar TODO el estado del juego desde un diccionario
func _restore_full_state(data: Dictionary) -> bool:
	if data.is_empty():
		return false

	# Detener juego actual
	ColonyManager.stop_game()

	# Limpiar mundo actual
	_clear_world()

	# Esperar frame para que nodos se liberen
	await get_tree().process_frame

	# Restaurar ColonyManager
	if data.has("colony"):
		ColonyManager.apply_save_data(data["colony"])

	# Restaurar ResourceManager
	if data.has("resources"):
		ResourceManager.apply_save_data(data["resources"])

	# Restaurar WeatherSystem
	if data.has("weather"):
		WeatherSystem.apply_save_data(data["weather"])

	# Restaurar ConstructionManager (pero NO reactivar construcción automáticamente)
	if data.has("construction"):
		ConstructionManager.apply_save_data(data["construction"])

	# Restaurar ReproductionSystem
	if data.has("reproduction"):
		var repro: Node = _get_reproduction_system()
		if repro and repro.has_method("apply_save_data"):
			repro.apply_save_data(data["reproduction"])

	# Restaurar DecisionSystem
	if data.has("decision"):
		var decision: Node = _get_decision_system()
		if decision and decision.has_method("apply_save_data"):
			decision.apply_save_data(data["decision"])

	# Restaurar FogOfWar
	if data.has("fog_of_war"):
		FogOfWar.apply_save_data(data["fog_of_war"])

	# Obtener referencia al mundo
	var world: WorldScene = _get_world()
	if not world:
		push_error("[SaveSystem] No se encontró el mundo para restaurar entidades")
		return false

	# Restaurar edificios
	if data.has("buildings"):
		_restore_buildings(data["buildings"], world)

	# Restaurar beeps
	if data.has("beeps"):
		_restore_beeps(data["beeps"], world.beep_container)

	# Restaurar nodos de recurso
	if data.has("resource_nodes"):
		_restore_resource_nodes(data["resource_nodes"], world.resource_container)

	# Reactivar juego
	ColonyManager.start_game()

	# Sincronizar conocimiento (recalcular desde edificios restaurados)
	ColonyManager.knowledge = ResearchCenterBuilding.get_total_knowledge()

	return true


## --- Colección por Tipo ---

func _collect_colony_state() -> Dictionary:
	return {
		"priority": ColonyManager.colony_priority,
		"happiness": ColonyManager.happiness,
		"health_average": ColonyManager.health_average,
		"social_order": ColonyManager.social_order,
		"knowledge": ColonyManager.knowledge,
		"game_time": ColonyManager.game_time,
		"debug_mode": ColonyManager.debug_mode,
	}


func _collect_beeps_state() -> Array:
	var beeps_data: Array = []

	for beep in ColonyManager.beeps:
		if not is_instance_valid(beep) or beep.is_queued_for_deletion():
			continue

		var data: Dictionary = {}
		data["position"] = [beep.position.x, beep.position.y]

		# Stats
		if beep.has_method("get_stats"):
			data["stats"] = beep.get_stats()
		elif beep.stats != null:
			data["stats"] = beep.stats.get_stats()

		# Role
		data["role"] = BeepRole.get_role(beep)

		beeps_data.append(data)

	return beeps_data


func _collect_buildings_state() -> Array:
	var buildings_data: Array = []

	for building in ColonyManager.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion():
			continue

		var data: Dictionary = {}
		data["type"] = building.get("building_type", "shelter")
		data["position"] = [building.position.x, building.position.y]
		data["is_under_construction"] = building.get("is_under_construction", false)
		data["construction_progress"] = building.get("construction_progress", 1.0)

		# Shelter: ocupantes
		if building.has_method("get_current_occupants"):
			data["current_occupants"] = building.get_current_occupants()

		# ResearchCenter: knowledge
		if building.has_method("get_knowledge"):
			data["knowledge"] = building.get_knowledge()

		buildings_data.append(data)

	return buildings_data


func _collect_resource_nodes_state() -> Array:
	var nodes_data: Array = []

	var world: WorldScene = _get_world()
	if not world:
		return nodes_data

	for child in world.resource_container.get_children():
		if not child is ResourceNodeScene:
			continue

		var data: Dictionary = {}
		data["type"] = child.get_resource_type()
		data["position"] = [child.position.x, child.position.y]
		data["amount"] = child.get_amount()
		data["is_active"] = child.is_active()

		nodes_data.append(data)

	return nodes_data


## --- Restauración por Tipo ---

func _restore_buildings(buildings_data: Array, world: WorldScene) -> void:
	for bdata in buildings_data:
		var building_type: String = bdata.get("type", "shelter")
		var scene: PackedScene = ConstructionManager.get_scene_for_type_string(building_type)

		if not scene:
			push_warning("[SaveSystem] Escena de edificio no encontrada: ", building_type)
			continue

		var building: Node = scene.instantiate()
		var pos: Vector2 = _vec2_from_array(bdata.get("position", [1600.0, 1600.0]))
		building.position = pos

		# Aplicar progreso de construcción
		building.set("is_under_construction", bdata.get("is_under_construction", false))
		building.set("construction_progress", bdata.get("construction_progress", 1.0))

		# Registrar
		world.add_child(building)
		ColonyManager.register_building(building)


func _restore_beeps(beeps_data: Array, parent: Node) -> void:
	if not parent:
		push_error("[SaveSystem] No hay padre para beeps")
		return

	for bdata in beeps_data:
		var new_beep: Node = ReproductionSystem.BEEP_SCENE.instantiate()
		new_beep.position = _vec2_from_array(bdata.get("position", [1600.0, 1600.0]))

		# Aplicar stats
		if bdata.has("stats") and new_beep.stats != null:
			var stats: Dictionary = bdata["stats"]
			new_beep.stats.hunger = stats.get("hunger", 0.0)
			new_beep.stats.energy = stats.get("energy", 100.0)
			new_beep.stats.health = stats.get("health", 100.0)
			new_beep.stats.age = stats.get("age", 0.0)

			# Life stage
			var life_stage_int: int = stats.get("life_stage", 2)
			new_beep.stats.life_stage = BeepStats.LifeStage.find_key(life_stage_int) if life_stage_int >= 0 else BeepStats.LifeStage.ADULT

			# State
			var state_str: String = stats.get("state", "idle")
			new_beep.stats.assigned_task = stats.get("task", "")

			# Reconstruir life_stage desde edad como fallback
			new_beep.stats._update_life_stage()

		parent.add_child(new_beep)
		ColonyManager.register_beep(new_beep)

		# Asignar rol
		var role: int = bdata.get("role", 0)
		if role > 0:
			BeepRole.set_role(new_beep, role)


func _restore_resource_nodes(nodes_data: Array, parent: Node) -> void:
	if not parent:
		push_error("[SaveSystem] No hay padre para recursos")
		return

	for ndata in nodes_data:
		var resource: Node = WorldScene.RESOURCE_SCENE.instantiate()
		resource.position = _vec2_from_array(ndata.get("position", [1600.0, 1600.0]))

		var rtype: int = ndata.get("type", 0)
		resource.set_resource_type(rtype)
		resource.set_meta("_restore_amount", ndata.get("amount", 100.0))

		parent.add_child(resource)

		# Aplicar amount después de _ready
		await get_tree().process_frame
		resource.set_meta("_restore_amount", ndata.get("amount", resource.get_amount()))
		# Usar setter si existe
		if resource.has_method("set_amount"):
			resource.set_amount(ndata.get("amount", resource.get_amount()))


## --- Limpieza ---

func _clear_world() -> void:
	var world: WorldScene = _get_world()
	if not world:
		return

	# Limpiar beeps
	for child in world.beep_container.get_children():
		child.queue_free()

	# Limpiar edificios
	for child in world.get_children():
		if child is Node2D and child != world.tile_map and child != world.spawn_manager \
		   and child != world.resource_container and child != world.beep_container \
		   and child.name != "FogOfWarVisual":
			child.queue_free()

	# Limpiar recursos
	for child in world.resource_container.get_children():
		child.queue_free()

	# Limpiar sistemas
	BeepRole.reset()
	ConstructionManager.reset()
	ReproductionSystem.reset()
	FogOfWar.reset()


## --- Helpers ---

func _get_save_path(slot_name: String) -> String:
	return SAVE_DIR + "/%s%s" % [slot_name, SAVE_EXTENSION]


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveSystem] No se pudo abrir archivo: ", path)
		return false

	# Usar JSON.stringify con indentación para legibilidad
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[SaveSystem] No se pudo leer archivo: ", path)
		return null

	var content: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error: Error = json.parse(content)
	if error != OK:
		push_error("[SaveSystem] JSON inválido en: ", path, " Error: ", error)
		return null

	return json.data


func _vec2_from_array(arr: Variant) -> Vector2:
	if arr is Array and arr.size() >= 2:
		return Vector2(float(arr[0]), float(arr[1]))
	return Vector2(1600.0, 1600.0)


func _get_world() -> WorldScene:
	var viewport: SubViewport = _find_subviewport(get_tree().root)
	if viewport:
		for child in viewport.get_children():
			if child is WorldScene:
				return child
	return null


func _find_subviewport(node: Node) -> SubViewport:
	if node is SubViewport:
		return node
	for child in node.get_children():
		var result: SubViewport = _find_subviewport(child)
		if result:
			return result
	return null


func _get_reproduction_system() -> Node:
	var viewport: SubViewport = _find_subviewport(get_tree().root)
	if viewport:
		return viewport.get_node_or_null("ReproductionSystem")
	return null


func _get_decision_system() -> Node:
	var viewport: SubViewport = _find_subviewport(get_tree().root)
	if viewport:
		return viewport.get_node_or_null("DecisionSystem")
	return null
