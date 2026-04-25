## Sistema de decisiones del jugador
## Genera eventos de decisión y gestiona los efectos sobre el juego

class_name DecisionSystem
extends Node

signal decision_event_triggered(event: Dictionary)
signal decision_resolved(option_id: String)
signal decision_timed_out

## Evento actual activo
var current_event: Dictionary = {}
var is_event_active: bool = false

## Timer para respuestas
var response_timer: float = 0.0
var response_time_limit: float = GameConfig.DECISION_RESPONSE_TIME

## Intervalo entre decisiones
var decision_timer: float = 0.0
const DECISION_INTERVAL: float = GameConfig.DECISION_INTERVAL

## Pool de eventos posibles
var event_pool: Array[Dictionary] = []


func _ready() -> void:
	_generate_event_pool()


func _process(delta: float) -> void:
	if not ColonyManager.game_active:
		return
	
	if is_event_active:
		_update_response_timer(delta)
	else:
		_check_decision_timer(delta)


func _update_response_timer(delta: float) -> void:
	response_timer += delta
	if response_timer >= response_time_limit:
		_timeout_current_event()


func _check_decision_timer(delta: float) -> void:
	decision_timer += delta
	if decision_timer >= DECISION_INTERVAL:
		decision_timer = 0.0
		_trigger_random_event()


func _generate_event_pool() -> void:
	event_pool = [
		_resource_shortage_event("food"),
		_resource_shortage_event("wood"),
		_resource_shortage_event("stone"),
		_population_growth_event(),
		_disaster_event("disease"),
		_disaster_event("famine"),
		_moral_event(),
		_exploration_event(),
		_technology_event()
	]


func _trigger_random_event() -> void:
	if event_pool.is_empty():
		return

	var event_index = randi() % event_pool.size()
	current_event = event_pool[event_index]
	is_event_active = true
	response_timer = 0.0
	decision_timer = 0.0
	
	decision_event_triggered.emit(current_event)
	
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🔔 Decision Event: ", current_event["description"])


func resolve_decision(option_id: String) -> void:
	if not is_event_active:
		return
	
	var chosen_option = null
	for option in current_event["options"]:
		if option["id"] == option_id:
			chosen_option = option
			break
	
	if chosen_option != null:
		_apply_effects(chosen_option["effects"])
		is_event_active = false
		decision_resolved.emit(option_id)
		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("✅ Decision resolved: ", option_id)


func _timeout_current_event() -> void:
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("⏰ Decision timed out - applying default effects")
	
	var default_option = current_event.get("default_option", null)
	if default_option != null:
		_apply_effects(default_option["effects"])
	
	is_event_active = false
	decision_timed_out.emit()


func _apply_effects(effects: Dictionary) -> void:
	for key in effects:
		match key:
			"food":
				if effects[key] > 0:
					ResourceManager.add_food(effects[key])
				else:
					ResourceManager.remove_food(absf(effects[key]))
			"wood":
				if effects[key] > 0:
					ResourceManager.add_wood(effects[key])
				else:
					ResourceManager.remove_wood(absf(effects[key]))
			"stone":
				if effects[key] > 0:
					ResourceManager.add_stone(effects[key])
				else:
					ResourceManager.remove_stone(absf(effects[key]))
			"happiness":
				ColonyManager.happiness = clampf(ColonyManager.happiness + effects[key], 0.0, 100.0)
			"health":
				ColonyManager.health_average = clampf(ColonyManager.health_average + effects[key], 0.0, 100.0)
			"social_order":
				ColonyManager.social_order = clampf(ColonyManager.social_order + effects[key], 0.0, 100.0)
			"priority":
				match effects[key]:
					"food":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.FOOD)
					"construction":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.CONSTRUCTION)
					"exploration":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.EXPLORATION)
			"knowledge":
				ColonyManager.knowledge += effects[key]


func get_response_percentage() -> float:
	if not is_event_active:
		return 0.0
	return (response_timer / response_time_limit) * 100.0


func get_remaining_time() -> float:
	if not is_event_active:
		return 0.0
	return maxf(0.0, response_time_limit - response_timer)


# --- Event Templates ---

func _resource_shortage_event(resource_type: String) -> Dictionary:
	var descriptions = {
		"food": "Los Beeps están hambrientos. ¿Cómo priorizamos la comida?",
		"wood": "La madera escasea. ¿Qué hacemos con los materiales?",
		"stone": "La piedra se está agotando. ¿Cómo resolvemos esto?"
	}
	
	var resource_ids = {
		"food": "food",
		"wood": "wood",
		"stone": "stone"
	}
	
	return {
		"type": "resource_shortage",
		"resource": resource_type,
		"description": descriptions.get(resource_type, "Recurso escaseando"),
		"urgency": 0.7,
		"options": [
			{
				"id": "prioritize_" + resource_type,
				"text": "Priorizar recolección de " + resource_type,
				"effects": {
					"priority": resource_ids.get(resource_type, "food"),
					"happiness": -5
				}
			},
			{
				"id": "conserve_" + resource_type,
				"text": "Conservar lo que queda (racionar)",
				"effects": {
					resource_type: -5,
					"happiness": -10,
					"health": -5
				}
			},
			{
				"id": "explore_for_" + resource_type,
				"text": "Enviar exploradores a buscar más",
				"effects": {
					"priority": "exploration",
					resource_type: 10,
					"happiness": 5
				}
			}
		],
		"default_option": {
			"id": "do_nothing",
			"text": "Ninguna acción",
			"effects": {
				resource_type: -10,
				"happiness": -15,
				"health": -10
			}
		}
	}


func _population_growth_event() -> Dictionary:
	return {
		"type": "population_growth",
		"description": "La colonia crece rápidamente. ¿Cómo manejamos la expansión?",
		"urgency": 0.5,
		"options": [
			{
				"id": "build_more_shelters",
				"text": "Construir más refugios",
				"effects": {
					"priority": "construction",
					"wood": -10,
					"stone": -5,
					"happiness": 10
				}
			},
			{
				"id": "focus_on_food",
				"text": "Asegurar suministro de comida",
				"effects": {
					"priority": "food",
					"food": 15,
					"happiness": 5
				}
			},
			{
				"id": "maintain_status_quo",
				"text": "Seguir con lo establecido",
				"effects": {
					"happiness": -5
				}
			}
		],
		"default_option": {
			"id": "ignore",
			"text": "Ignorar el problema",
			"effects": {
				"happiness": -15,
				"health": -10
			}
		}
	}


func _disaster_event(disaster_type: String) -> Dictionary:
	var descriptions = {
		"disease": "Una enfermedad afecta a los Beeps. ¿Cómo respondemos?",
		"famine": "Una hambruna amenaza la colonia. ¡Decisión urgente!"
	}
	
	var effects = {
		"disease": {
			"health": -20,
			"happiness": -15
		},
		"famine": {
			"food": -25,
			"happiness": -20,
			"health": -15
		}
	}
	
	return {
		"type": "disaster",
		"disaster": disaster_type,
		"description": descriptions.get(disaster_type, "Desastre inminente"),
		"urgency": 0.9,
		"options": [
			{
				"id": "emergency_response",
				"text": "Respuesta de emergencia",
				"effects": {
					"priority": "food",
					"health": 10,
					"happiness": 5,
					"food": -15
				}
			},
			{
				"id": "quarantine",
				"text": "Aislar a los afectados",
				"effects": {
					"health": 15,
					"happiness": -10,
					"social_order": -10
				}
			}
		],
		"default_option": {
			"id": "no_action",
			"text": "No hacer nada",
			"effects": effects.get(disaster_type, {"health": -20, "happiness": -20})
		}
	}


func _moral_event() -> Dictionary:
	return {
		"type": "moral",
		"description": "Los Beeps están descontentos. ¿Cómo mejoramos el ánimo?",
		"urgency": 0.4,
		"options": [
			{
				"id": "feast",
				"text": "Organizar un banquete",
				"effects": {
					"food": -20,
					"happiness": 25,
					"health": 5
				}
			},
			{
				"id": "rest_day",
				"text": "Día de descanso para todos",
				"effects": {
					"happiness": 15,
					"health": 10,
					"social_order": 5
				}
			},
			{
				"id": "speech",
				"text": "Discurso motivacional",
				"effects": {
					"happiness": 10,
					"social_order": 10
				}
			}
		],
		"default_option": {
			"id": "ignore_morale",
			"text": "Ignorar el descontento",
			"effects": {
				"happiness": -20,
				"social_order": -15
			}
		}
	}


func _exploration_event() -> Dictionary:
	return {
		"type": "exploration",
		"description": "Se descubrió un nuevo territorio. ¿Exploramos?",
		"urgency": 0.3,
		"options": [
			{
				"id": "send_explorers",
				"text": "Enviar grupo de exploradores",
				"effects": {
					"priority": "exploration",
					"food": -10,
					"wood": 15,
					"stone": 10,
					"happiness": 10
				}
			},
			{
				"id": "stay_safe",
				"text": "Permanecer en territorio conocido",
				"effects": {
					"happiness": -5
				}
			}
		],
		"default_option": {
			"id": "delay_decision",
			"text": "Postergar la decisión",
			"effects": {}
		}
	}


func _technology_event() -> Dictionary:
	return {
		"type": "technology",
		"description": "Los Beeps descubrieron una nueva técnica. ¿La investigamos?",
		"urgency": 0.35,
		"options": [
			{
				"id": "investigate",
				"text": "Invertir recursos en investigación",
				"effects": {
					"food": -10,
					"wood": -10,
					"knowledge": 20,
					"happiness": 15
				}
			},
			{
				"id": "ignore",
				"text": "No perder tiempo",
				"effects": {
					"happiness": -5
				}
			}
		],
		"default_option": {
			"id": "do_nothing",
			"text": "Ninguna acción",
			"effects": {}
		}
	}
