## Refugio para los Beeps
## Permite descanso y recuperación de salud

class_name ShelterBuilding
extends BuildingBase

## Tasa de curación (se inicializa desde BuildingType en _ready)
var heal_rate: float = 0.0

## Beeps dentro del refugio
var occupants: Array = []

## Placeholder visual
const SHELTER_WIDTH: float = 36.0
const SHELTER_HEIGHT: float = 28.0
const ROOF_HEIGHT: float = 16.0
const DOOR_WIDTH: float = 10.0
const DOOR_HEIGHT: float = 14.0


func _draw() -> void:
	var base_color: Color
	var roof_color: Color
	if is_under_construction:
		base_color = Color(0.4, 0.35, 0.3, 0.7)
		roof_color = Color(0.3, 0.25, 0.25, 0.7)
	else:
		base_color = Color(0.7, 0.55, 0.4)
		roof_color = Color(0.55, 0.3, 0.2)

	# Base rectángulo
	var base_rect := Rect2(
		-SHELTER_WIDTH / 2.0,
		-SHELTER_HEIGHT / 2.0,
		SHELTER_WIDTH,
		SHELTER_HEIGHT
	)
	draw_rect(base_rect, base_color)
	draw_rect(base_rect, Color(0, 0, 0, 0.3), false, 1.0)

	# Techo triángulo
	var roof_top := Vector2(0, -SHELTER_HEIGHT / 2.0 - ROOF_HEIGHT)
	var roof_left := Vector2(-SHELTER_WIDTH / 2.0 - 4, -SHELTER_HEIGHT / 2.0)
	var roof_right := Vector2(SHELTER_WIDTH / 2.0 + 4, -SHELTER_HEIGHT / 2.0)
	draw_colored_polygon(
		PackedVector2Array([roof_top, roof_left, roof_right]),
		roof_color
	)
	draw_line(roof_top, roof_left, Color(0, 0, 0, 0.3), 1.0)
	draw_line(roof_left, roof_right, Color(0, 0, 0, 0.3), 1.0)
	draw_line(roof_right, roof_top, Color(0, 0, 0, 0.3), 1.0)

	# Puerta
	var door_rect := Rect2(
		-DOOR_WIDTH / 2.0,
		-SHELTER_HEIGHT / 2.0 + DOOR_HEIGHT - 2,
		DOOR_WIDTH,
		DOOR_HEIGHT
	)
	draw_rect(door_rect, Color(0.2, 0.15, 0.1))

	# Indicador ocupantes
	if not is_under_construction and occupants.size() > 0:
		var count_text := str(occupants.size())
		var font := ThemeDB.fallback_font
		if font:
			var text_pos := Vector2(-6, SHELTER_HEIGHT / 2.0 + 4)
			draw_string(font, text_pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func _ready() -> void:
	building_type = "shelter"
	construction_time = BuildingType.get_build_time(BuildingType.Type.SHELTER)
	capacity = BuildingType.get_capacity(BuildingType.Type.SHELTER)
	heal_rate = BuildingType.DATA[BuildingType.Type.SHELTER]["heals_per_second"]
	super._ready()
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	
	if not is_under_construction:
		_heal_occupants(delta)


func _heal_occupants(delta: float) -> void:
	for beep in occupants:
		if is_instance_valid(beep) and beep.has_method("heal"):
			beep.heal(heal_rate * delta)


func _construction_complete() -> void:
	super._construction_complete()
	occupants = []
	queue_redraw()


func enter_beep(beep_node: Node) -> bool:
	if not has_space():
		return false
	
	if not occupants.has(beep_node):
		occupants.append(beep_node)
		add_occupant()
		queue_redraw()
		return true
	
	return false


func exit_beep(beep_node: Node) -> void:
	if occupants.has(beep_node):
		occupants.erase(beep_node)
		remove_occupant()
		queue_redraw()


func get_nearby_shelter(position: Vector2, max_distance: float = 200.0) -> ShelterBuilding:
	var nearest: ShelterBuilding = null
	var nearest_distance: float = max_distance
	
	for building in ColonyManager.buildings:
		if building is ShelterBuilding:
			var shelter = building as ShelterBuilding
			if shelter and not shelter.is_under_construction:
				var distance = position.distance_to(shelter.position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest = shelter
	
	return nearest
