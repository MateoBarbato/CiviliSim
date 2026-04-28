## Camino - edificio que marca rutas para los Beeps
## Visualmente: segmento de camino en el suelo

class_name PathBuilding
extends BuildingBase

## Longitud del camino en píxeles
const PATH_LENGTH: float = 48.0
const PATH_WIDTH: float = 16.0

func _draw() -> void:
	var color: Color
	if is_under_construction:
		color = Color(0.4, 0.35, 0.25, 0.5)
	else:
		color = Color(0.55, 0.45, 0.3)

	# Dibujar rectángulo del camino
	var rect := Rect2(-PATH_LENGTH / 2.0, -PATH_WIDTH / 2.0, PATH_LENGTH, PATH_WIDTH)
	draw_rect(rect, color)
	draw_rect(rect, Color(0, 0, 0, 0.2), false, 1.0)

	# Líneas decorativas internas
	draw_line(Vector2(-PATH_LENGTH / 2.0 + 2, -PATH_WIDTH / 4), Vector2(PATH_LENGTH / 2.0 - 2, -PATH_WIDTH / 4), Color(0, 0, 0, 0.15), 1.0)
	draw_line(Vector2(-PATH_LENGTH / 2.0 + 2, PATH_WIDTH / 4), Vector2(PATH_LENGTH / 2.0 - 2, PATH_WIDTH / 4), Color(0, 0, 0, 0.15), 1.0)


func _ready() -> void:
	building_type = "path"
	construction_time = BuildingType.get_build_time(BuildingType.Type.PATH)
	capacity = 0
	super._ready()
	queue_redraw()
