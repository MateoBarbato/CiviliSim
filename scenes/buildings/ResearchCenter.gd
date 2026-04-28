## Centro de Investigación - genera conocimiento y mejora felicidad
## El conocimiento desbloquea mejoras pasivas para la colonia.

class_name ResearchCenterBuilding
extends BuildingBase

## Tasa de generación de conocimiento (se inicializa desde BuildingType)
var knowledge_generation: float = 0.0

## Bonus de felicidad por segundo
var happiness_bonus: float = 0.0

## Conocimiento acumulado (solo este centro)
var knowledge_accumulated: float = 0.0

## Nivel de investigación actual (0-10)
var research_level: int = 0

## Dimensiones visuales
const RC_WIDTH: float = 36.0
const RC_HEIGHT: float = 36.0
const TOWER_HEIGHT: float = 20.0


func _draw() -> void:
	var base_color: Color
	var tower_color: Color
	var glow_color: Color
	if is_under_construction:
		base_color = Color(0.35, 0.35, 0.4, 0.7)
		tower_color = Color(0.3, 0.3, 0.35, 0.7)
		glow_color = Color(0.2, 0.2, 0.25, 0.5)
	else:
		base_color = Color(0.4, 0.4, 0.6)
		tower_color = Color(0.3, 0.3, 0.5)
		glow_color = Color(0.5, 0.5, 0.9, 0.4)

	# Base cuadrada
	var base_rect := Rect2(
		-RC_WIDTH / 2.0,
		-RC_HEIGHT / 2.0,
		RC_WIDTH,
		RC_HEIGHT
	)
	draw_rect(base_rect, base_color)
	draw_rect(base_rect, Color(0, 0, 0, 0.3), false, 1.0)

	# Torre / cúpula en el centro
	var tower_rect := Rect2(
		-8.0,
		-RC_HEIGHT / 2.0 - TOWER_HEIGHT,
		16.0,
		TOWER_HEIGHT
	)
	draw_rect(tower_rect, tower_color)
	draw_rect(tower_rect, Color(0, 0, 0, 0.3), false, 1.0)

	# Cúpula semicircular en la torre
	draw_circle(Vector2(0, -RC_HEIGHT / 2.0 - TOWER_HEIGHT), 8.0, tower_color)

	# Glow de conocimiento (solo si está completo)
	if not is_under_construction and knowledge_accumulated > 0:
		var glow_intensity: float = minf(knowledge_accumulated / 50.0, 1.0)
		var glow_c := Color(0.4, 0.4, 1.0, 0.15 * glow_intensity)
		draw_rect(Rect2(-RC_WIDTH / 2.0 - 4, -RC_HEIGHT / 2.0 - TOWER_HEIGHT - 4,
			RC_WIDTH + 8, RC_HEIGHT + TOWER_HEIGHT + 4), glow_c)

	# Puerta
	var door_rect := Rect2(
		-5.0,
		RC_HEIGHT / 2.0 - 12.0,
		10.0,
		12.0
	)
	draw_rect(door_rect, Color(0.15, 0.15, 0.25))

	# Símbolo de investigación (◇) en la base
	var font := ThemeDB.fallback_font
	if font:
		if is_under_construction:
			# Barra de progreso
			var bar_width: float = RC_WIDTH + 8
			var bar_height: float = 4.0
			var bar_y: float = -RC_HEIGHT / 2.0 - TOWER_HEIGHT - 14

			draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))

			var progress_width: float = bar_width * minf(construction_progress, 1.0)
			var progress_color: Color = Color(0.3, 0.9, 0.3)
			if construction_progress < 0.3:
				progress_color = Color(0.9, 0.7, 0.2)
			draw_rect(Rect2(-bar_width / 2.0, bar_y, progress_width, bar_height), progress_color)

			var pct_text := "%.0f%%" % (construction_progress * 100.0)
			var text_pos := Vector2(-6, bar_y - 2)
			draw_string(font, text_pos, pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		else:
			# Mostrar nivel de investigación
			var lvl_text := "N%d" % research_level
			var text_pos := Vector2(-6, RC_HEIGHT / 2.0 + 4)
			draw_string(font, text_pos, lvl_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func _ready() -> void:
	building_type = "research_center"
	construction_time = BuildingType.get_build_time(BuildingType.Type.RESEARCH_CENTER)
	capacity = 0

	# Cargar parámetros
	var data: Dictionary = BuildingType.DATA[BuildingType.Type.RESEARCH_CENTER]
	knowledge_generation = data.get("knowledge_generation", 0.5)
	happiness_bonus = data.get("happiness_bonus", 0.1)

	super._ready()
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)

	if not is_under_construction:
		_generate_knowledge(delta)
		_apply_happiness_bonus(delta)


func _generate_knowledge(delta: float) -> void:
	knowledge_accumulated += knowledge_generation * delta

	## Subir de nivel cada 25 puntos de conocimiento
	var new_level: int = int(knowledge_accumulated / 25.0)
	if new_level > research_level:
		research_level = minf(new_level, 10)
		_on_research_level_up()
		queue_redraw()


func _apply_happiness_bonus(delta: float) -> void:
	if is_instance_valid(ColonyManager):
		ColonyManager.happiness = minf(
			ColonyManager.happiness + happiness_bonus * delta,
			100.0
		)


func _on_research_level_up() -> void:
	print("[ResearchCenter] ¡Nivel de investigación subió a %d!" % research_level)

	# Beneficios por nivel (pasivos)
	match research_level:
		1:
			# +10% eficiencia de recolección
			print("  -> +10% eficiencia de recolección desbloqueada")
		2:
			# +10% velocidad de construcción
			print("  -> +10% velocidad de construcción desbloqueada")
		3:
			# -10% consumo de comida
			print("  -> -10% consumo de comida desbloqueado")
		4:
			# +1 capacidad máxima de beeps
			print("  -> +1 capacidad máxima de beeps desbloqueada")
		5:
			# +20% resistencia a enfermedades
			print("  -> +20% resistencia a enfermedades desbloqueada")
		6:
			# +15% eficiencia de recolección adicional
			print("  -> +15% eficiencia de recolección adicional desbloqueada")
		7:
			# +15% velocidad de construcción adicional
			print("  -> +15% velocidad de construcción adicional desbloqueada")
		8:
			# -15% consumo de comida adicional
			print("  -> -15% consumo de comida adicional desbloqueado")
		9:
			# +2 felicidad base
			print("  -> +2 felicidad base desbloqueada")
		10:
			# Máximo nivel - todos los bonuses al máximo
			print("  -> ¡Nivel máximo de investigación alcanzado!")


## Obtener multiplicador de eficiencia de recolección basado en nivel
func get_gathering_bonus() -> float:
	var bonus: float = 0.0
	if research_level >= 1:
		bonus += 0.10
	if research_level >= 6:
		bonus += 0.15
	return bonus


## Obtener multiplicador de velocidad de construcción
func get_construction_speed_bonus() -> float:
	var bonus: float = 0.0
	if research_level >= 2:
		bonus += 0.10
	if research_level >= 7:
		bonus += 0.15
	return bonus


## Obtener reducción de consumo de comida
func get_food_consumption_reduction() -> float:
	var reduction: float = 0.0
	if research_level >= 3:
		reduction += 0.10
	if research_level >= 8:
		reduction += 0.15
	return reduction


## Obtener bonus de felicidad base
func get_happiness_base_bonus() -> float:
	return 2.0 if research_level >= 9 else 0.0


## Obtener bonus global de recolección (para que los beeps lo usen)
static func get_total_gathering_bonus() -> float:
	var total: float = 0.0
	for building in ColonyManager.buildings:
		if building.get("building_type") == "research_center" and not building.get("is_under_construction", true):
			total += building.get("get_gathering_bonus", func(): 0.0).call() if building.has_method("get_gathering_bonus") else 0.0
	return total


static func get_total_construction_bonus() -> float:
	var total: float = 0.0
	for building in ColonyManager.buildings:
		if building.get("building_type") == "research_center" and not building.get("is_under_construction", true):
			if building.has_method("get_construction_speed_bonus"):
				total += building.get_construction_speed_bonus()
	return total


static func get_total_food_reduction() -> float:
	var total: float = 0.0
	for building in ColonyManager.buildings:
		if building.get("building_type") == "research_center" and not building.get("is_under_construction", true):
			if building.has_method("get_food_consumption_reduction"):
				total += building.get_food_consumption_reduction()
	return total


static func get_total_knowledge() -> float:
	var total: float = 0.0
	for building in ColonyManager.buildings:
		if building.get("building_type") == "research_center" and not building.get("is_under_construction", true):
			total += building.get("knowledge_accumulated", 0.0)
	return total
