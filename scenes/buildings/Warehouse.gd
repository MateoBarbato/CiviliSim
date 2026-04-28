## Almacén - aumenta la capacidad máxima de recursos de la colonia
## Cada almacén suma un bonus fijo a food/wood/stone max.

class_name WarehouseBuilding
extends BuildingBase

## Bonus de almacenamiento (se inicializa desde BuildingType en _ready)
var storage_bonus: Dictionary = {"food": 0.0, "wood": 0.0, "stone": 0.0}

## Dimensiones visuales
const WAREHOUSE_WIDTH: float = 40.0
const WAREHOUSE_HEIGHT: float = 32.0
const ROOF_HEIGHT: float = 10.0


func _draw() -> void:
	var base_color: Color
	var roof_color: Color
	var accent_color: Color
	if is_under_construction:
		base_color = Color(0.4, 0.35, 0.3, 0.7)
		roof_color = Color(0.35, 0.3, 0.3, 0.7)
		accent_color = Color(0.3, 0.25, 0.25, 0.7)
	else:
		base_color = Color(0.55, 0.45, 0.3)
		roof_color = Color(0.4, 0.3, 0.2)
		accent_color = Color(0.65, 0.55, 0.35)

	# Base rectángulo
	var base_rect := Rect2(
		-WAREHOUSE_WIDTH / 2.0,
		-WAREHOUSE_HEIGHT / 2.0,
		WAREHOUSE_WIDTH,
		WAREHOUSE_HEIGHT
	)
	draw_rect(base_rect, base_color)
	draw_rect(base_rect, Color(0, 0, 0, 0.3), false, 1.0)

	# Techo plano con bordes
	var roof_rect := Rect2(
		-WAREHOUSE_WIDTH / 2.0 - 2,
		-WAREHOUSE_HEIGHT / 2.0 - ROOF_HEIGHT,
		WAREHOUSE_WIDTH + 4,
		ROOF_HEIGHT
	)
	draw_rect(roof_rect, roof_color)
	draw_rect(roof_rect, Color(0, 0, 0, 0.3), false, 1.0)

	# Puerta grande
	var door_rect := Rect2(
		-8.0,
		-WAREHOUSE_HEIGHT / 2.0 + WAREHOUSE_HEIGHT - 18.0,
		16.0,
		18.0
	)
	draw_rect(door_rect, Color(0.2, 0.15, 0.1))

	# Líneas decorativas (ventanas pequeñas)
	var win_w: float = 6.0
	var win_h: float = 6.0
	var win_y: float = -WAREHOUSE_HEIGHT / 2.0 + 6.0
	draw_rect(Rect2(-WAREHOUSE_WIDTH / 4.0 - win_w / 2.0, win_y, win_w, win_h), accent_color)
	draw_rect(Rect2(WAREHOUSE_WIDTH / 4.0 - win_w / 2.0, win_y, win_w, win_h), accent_color)

	# Barra de progreso de construcción
	if is_under_construction:
		var bar_width: float = WAREHOUSE_WIDTH + 8
		var bar_height: float = 4.0
		var bar_y: float = -WAREHOUSE_HEIGHT / 2.0 - ROOF_HEIGHT - 10

		draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))

		var progress_width: float = bar_width * minf(construction_progress, 1.0)
		var progress_color: Color = Color(0.3, 0.9, 0.3)
		if construction_progress < 0.3:
			progress_color = Color(0.9, 0.7, 0.2)
		draw_rect(Rect2(-bar_width / 2.0, bar_y, progress_width, bar_height), progress_color)

		var font := ThemeDB.fallback_font
		if font:
			var pct_text := "%.0f%%" % (construction_progress * 100.0)
			var text_pos := Vector2(-6, bar_y - 2)
			draw_string(font, text_pos, pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	else:
		## Icono de +storage cuando está completo
		var font := ThemeDB.fallback_font
		if font:
			var text_pos := Vector2(-10, WAREHOUSE_HEIGHT / 2.0 + 4)
			draw_string(font, text_pos, "+📦", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func _ready() -> void:
	building_type = "warehouse"
	construction_time = BuildingType.get_build_time(BuildingType.Type.WAREHOUSE)
	capacity = 0

	# Cargar bonus de almacenamiento
	var data: Dictionary = BuildingType.DATA[BuildingType.Type.WAREHOUSE]
	if data.has("storage_bonus"):
		storage_bonus = data["storage_bonus"].duplicate()

	super._ready()
	_apply_storage_bonus()
	queue_redraw()


func _construction_complete() -> void:
	super._construction_complete()
	_apply_storage_bonus()
	queue_redraw()


## Aplicar el bonus de almacenamiento al ResourceManager
func _apply_storage_bonus() -> void:
	if not is_under_construction:
		ResourceManager.recalculate_max_capacity()


## Desaplicar el bonus si se destruye
func _remove_storage_bonus() -> void:
	ResourceManager.recalculate_max_capacity()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_remove_storage_bonus()
		super._notification(what)
