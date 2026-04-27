## Refugio para los Beeps
## Permite descanso y recuperación de salud

class_name ShelterBuilding
extends BuildingBase

## Tasa de curación
var heal_rate: float = 1.0

## Beeps dentro del refugio
var occupants: Array = []

## Placeholder visual
const SHELTER_RADIUS: float = 20.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, SHELTER_RADIUS, Color(0.6, 0.5, 0.4, 0.5))
	draw_circle(Vector2.ZERO, SHELTER_RADIUS - 3, Color(0.7, 0.6, 0.5, 0.3))
	queue_redraw()


func _ready() -> void:
	building_type = "shelter"
	construction_time = BuildingType.get_build_time(BuildingType.Type.SHELTER)
	capacity = BuildingType.get_capacity(BuildingType.Type.SHELTER)
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


func enter_beep(beep_node: Node) -> bool:
	if not has_space():
		return false
	
	if not occupants.has(beep_node):
		occupants.append(beep_node)
		add_occupant()
		return true
	
	return false


func exit_beep(beep_node: Node) -> void:
	if occupants.has(beep_node):
		occupants.erase(beep_node)
		remove_occupant()


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
