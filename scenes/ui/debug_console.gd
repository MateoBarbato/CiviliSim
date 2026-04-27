## Consola de debug para el desarrollo
## Permite ver el estado del juego en tiempo real

extends CanvasLayer

## Referencias
@onready var debug_panel: Panel = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel

## Estado
var is_visible: bool = false
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.5


var _decision_system: Node


func _ready() -> void:
	hide()
	debug_panel.visible = false
	_decision_system = _find_decision_system()


func _find_decision_system() -> Node:
	var parent = get_parent()
	while parent:
		for child in parent.get_children():
			if child.name == "DecisionSystem":
				return child
			if child is SubViewport:
				for sub_child in child.get_children():
					if sub_child.name == "DecisionSystem":
						return sub_child
		parent = parent.get_parent()
	return null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_debug"):
		_toggle_debug_console()


func _toggle_debug_console() -> void:
	is_visible = not is_visible
	debug_panel.visible = is_visible
	show() if is_visible else hide()


func _process(delta: float) -> void:
	if is_visible:
		update_timer += delta
		if update_timer >= UPDATE_INTERVAL:
			update_timer = 0.0
			_update_debug_info()


func _update_debug_info() -> void:
	var info = []
	
	info.append("=== CIVILISIM DEBUG ===")
	info.append("")
	
	info.append("--- Colonia ---")
	info.append("Población: %d / %d" % [ColonyManager.population, GameConfig.REPRODUCTION_MAX_POPULATION])
	info.append("Felicidad: %.1f" % ColonyManager.happiness)
	info.append("Salud promedio: %.1f" % ColonyManager.health_average)
	info.append("Orden social: %.1f" % ColonyManager.social_order)
	info.append("Tiempo: %d" % int(ColonyManager.game_time))
	
	info.append("")
	info.append("--- Recursos ---")
	var res_state = ResourceManager.get_resource_state()
	info.append("Comida: %.0f / %d (%.0f%%)" % [res_state["food"], ResourceManager.MAX_FOOD, res_state["food_percent"]])
	info.append("Madera: %.0f / %d (%.0f%%)" % [res_state["wood"], ResourceManager.MAX_WOOD, res_state["wood_percent"]])
	info.append("Piedra: %.0f / %d (%.0f%%)" % [res_state["stone"], ResourceManager.MAX_STONE, res_state["stone_percent"]])
	
	info.append("")
	info.append("--- Edificios ---")
	info.append("Edificios activos: %d" % ColonyManager.buildings.size())
	
	info.append("")
	info.append("--- Decisiones ---")
	var ds = _decision_system
	info.append("Evento activo: %s" % ["Sí" if ds and ds.is_event_active else "No"])
	if ds and ds.is_event_active:
		info.append("Tiempo restante: %.1fs" % ds.get_remaining_time())
	
	info.append("")
	info.append("--- Reproductión ---")
	var repro_stats = null
	var repro_system = null
	for child in get_tree().root.get_children():
		if child.name == "ReproductionSystem":
			repro_system = child
			break
	if repro_system and repro_system.has_method("get_statistics"):
		repro_stats = repro_system.get_statistics()
		info.append("Nacimientos: %d" % repro_stats["total_births"])
		info.append("Fallos: %d" % repro_stats["total_failures"])
		info.append("Cooldown: %.0fs" % repro_stats["reproduction_cooldown"])
	
	info.append("")
	info.append("[F1] Toggle Debug")
	
	debug_label.text = "\n".join(info)
