## HUD principal del juego
## Muestra recursos, población y estado de la colonia

extends CanvasLayer

## Referencias a elementos del HUD
@onready var food_label: Label = $HUDPanel/MarginContainer/VBoxContainer/ResourcesHBox/FoodLabel
@onready var wood_label: Label = $HUDPanel/MarginContainer/VBoxContainer/ResourcesHBox/WoodLabel
@onready var stone_label: Label = $HUDPanel/MarginContainer/VBoxContainer/ResourcesHBox/StoneLabel
@onready var population_label: Label = $HUDPanel/MarginContainer/VBoxContainer/ResourcesHBox/PopulationLabel
@onready var priority_label: Label = $HUDPanel/MarginContainer/VBoxContainer/PriorityLabel
@onready var game_time_label: Label = $HUDPanel/MarginContainer/VBoxContainer/TimeLabel

## Timer para actualizar el HUD
var hud_update_timer: float = 0.0
const HUD_UPDATE_INTERVAL: float = 0.25


func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)


func _process(delta: float) -> void:
	hud_update_timer += delta
	if hud_update_timer >= HUD_UPDATE_INTERVAL:
		hud_update_timer = 0.0
		_update_hud()


func _update_hud() -> void:
	_update_resource_labels()
	_update_population()
	_update_priority()
	_update_game_time()


func _update_resource_labels() -> void:
	var state = ResourceManager.get_resource_state()
	food_label.text = "🍖 %d" % int(state["food"])
	wood_label.text = "🪵 %d" % int(state["wood"])
	stone_label.text = "🪨 %d" % int(state["stone"])


func _update_population() -> void:
	population_label.text = "👥 %d" % ColonyManager.population


func _update_priority() -> void:
	match ColonyManager.colony_priority:
		ColonyManager.ColonyPriority.FOOD:
			priority_label.text = "⚡ Prioridad: Comida"
		ColonyManager.ColonyPriority.CONSTRUCTION:
			priority_label.text = "🔨 Prioridad: Construcción"
		ColonyManager.ColonyPriority.EXPLORATION:
			priority_label.text = "🗺️ Prioridad: Exploración"


func _update_game_time() -> void:
	var minutes = int(ColonyManager.game_time / 60.0)
	var seconds = int(ColonyManager.game_time) % 60
	game_time_label.text = "⏱️ %02d:%02d" % [minutes, seconds]


func _on_resource_changed(resource_type: String, amount: float) -> void:
	_update_resource_labels()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_debug"):
		_toggle_debug_info()


func _toggle_debug_info() -> void:
	var debug_label = $HUDPanel/MarginContainer/VBoxContainer.get_node_or_null("DebugLabel")
	if debug_label:
		debug_label.visible = not debug_label.visible
