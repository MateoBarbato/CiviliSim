## Sistema de decisiones del jugador
## Genera eventos de decisión con cadenas, dificultad progresiva y efectos persistentes

class_name DecisionSystem
extends Node

signal decision_event_triggered(event: Dictionary)
signal decision_resolved(option_id: String)
signal decision_timed_out
signal persistent_effect_added(name: String, duration: float)
signal persistent_effect_removed(name: String)

## Evento actual activo
var current_event: Dictionary = {}
var is_event_active: bool = false

## Timer para respuestas
var response_timer: float = 0.0
var response_time_limit: float = GameConfig.DECISION_RESPONSE_TIME

## Intervalo entre decisiones (base, se ajusta con dificultad)
var decision_timer: float = 0.0
var _current_interval: float = GameConfig.DECISION_INTERVAL

## Pool de eventos posibles
var event_pool: Array[Dictionary] = []

## --- Event Chains ---
## Cadena activa: array de IDs de eventos que forman una narrativa
var _active_chain: Array[String] = []
var _chain_event_index: int = -1
## Map de cadenas definidas: chain_id -> array de event generator func names
var _defined_chains: Dictionary = {}
## Historial de eventos resueltos (para evitar repetición)
var _resolved_history: Array[String] = []
const MAX_HISTORY: int = 6

## --- Difficulty Phase ---
enum DifficultyPhase { EARLY, MID, LATE }
var _difficulty_phase: DifficultyPhase = DifficultyPhase.EARLY
var _difficulty_multiplier: float = 1.0

## --- Persistent Effects ---
## Efectos activos con duración temporal: { name: { value: float, delta: float, duration: float } }
var _persistent_effects: Dictionary = {}

## --- Invasion cooldown ---
var _invasion_cooldown: float = 0.0

## Discovery tracking
var _discovery_cooldown: float = 0.0
const DISCOVERY_COOLDOWN: float = 30.0  # segundos entre eventos de descubrimiento


func _ready() -> void:
	_generate_event_pool()
	_register_chains()
	# Primer evento más rápido para feedback del jugador
	decision_timer = _current_interval - 5.0

	# Conectar señales de niebla de guerra
	FogOfWar.area_discovered.connect(_on_area_discovered)
	FogOfWar.map_fully_explored.connect(_on_map_fully_explored)


func _process(delta: float) -> void:
	if not ColonyManager.game_active:
		return

	_update_discovery_cooldown(delta)
	_update_invasion_cooldown(delta)
	_update_persistent_effects(delta)
	_update_difficulty_phase()

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
	if decision_timer >= _current_interval:
		decision_timer = 0.0
		_trigger_random_event()


## --- Difficulty Phase ---
func _update_difficulty_phase() -> void:
	var gt: float = ColonyManager.game_time
	var new_phase: DifficultyPhase = DifficultyPhase.EARLY
	var new_mult: float = GameConfig.EVENT_DIFFICULTY_EARLY

	if gt >= GameConfig.EVENT_PHASE_LATE_TIME:
		new_phase = DifficultyPhase.LATE
		new_mult = GameConfig.EVENT_DIFFICULTY_LATE
	elif gt >= GameConfig.EVENT_PHASE_MID_TIME:
		new_phase = DifficultyPhase.MID
		new_mult = GameConfig.EVENT_DIFFICULTY_MID

	if new_phase != _difficulty_phase:
		_difficulty_phase = new_phase
		_difficulty_multiplier = new_mult
		if GameConfig.DEBUG_PRINT_DECISIONS:
			var phase_name = ["Early", "Mid", "Late"][_difficulty_phase]
			print("⚡ Difficulty Phase → %s (x%.1f)" % [phase_name, _difficulty_multiplier])


## --- Persistent Effects ---
func add_persistent_effect(name: String, stat_delta: float, duration: float) -> void:
	if _persistent_effects.size() >= GameConfig.PERSISTENT_EFFECT_MAX_ACTIVE:
		# Remover el más antiguo
		var oldest_key = _persistent_effects.keys()[0]
		_persistent_effects.erase(oldest_key)
		persistent_effect_removed.emit(oldest_key)
		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("💊 Removed oldest effect: %s (max active)" % oldest_key)

	_persistent_effects[name] = {
		"delta": stat_delta,
		"remaining": duration,
		"total": duration
	}
	persistent_effect_added.emit(name, duration)
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("💊 Added effect: %s (%.0f/s for %.0fs)" % [name, stat_delta, duration])


func _update_persistent_effects(delta: float) -> void:
	var to_remove: Array[String] = []
	for name in _persistent_effects:
		var eff: Dictionary = _persistent_effects[name]
		eff["remaining"] -= delta
		# Aplicar delta continuo
		_apply_stat_modifier(name, eff["delta"] * delta)
		if eff["remaining"] <= 0.0:
			to_remove.append(name)

	for name in to_remove:
		_persistent_effects.erase(name)
		persistent_effect_removed.emit(name)
		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("💊 Effect expired: %s" % name)


func _apply_stat_modifier(effect_name: String, amount: float) -> void:
	match effect_name:
		"feast_bonus":
			ColonyManager.happiness = clampf(ColonyManager.happiness + amount * 0.5, 0.0, 100.0)
		"rest_day_bonus":
			ColonyManager.happiness = clampf(ColonyManager.happiness + amount * 0.3, 0.0, 100.0)
			ColonyManager.health_average = clampf(ColonyManager.health_average + amount * 0.2, 0.0, 100.0)
		"quarantine_bonus":
			ColonyManager.health_average = clampf(ColonyManager.health_average + amount * 0.3, 0.0, 100.0)
		"exploration_bonus":
			ColonyManager.knowledge = clampf(ColonyManager.knowledge + amount * 0.5, 0.0, 100.0)
		"research_bonus":
			ColonyManager.knowledge = clampf(ColonyManager.knowledge + amount * 0.8, 0.0, 100.0)
		"famine_penalty":
			ColonyManager.health_average = clampf(ColonyManager.health_average + amount * 0.3, 0.0, 100.0)
		"disease_penalty":
			ColonyManager.health_average = clampf(ColonyManager.health_average + amount * 0.4, 0.0, 100.0)
		"invasion_prepared":
			pass  # handled at invasion time
		"celebration_bonus":
			ColonyManager.happiness = clampf(ColonyManager.happiness + amount * 0.4, 0.0, 100.0)
			ColonyManager.social_order = clampf(ColonyManager.social_order + amount * 0.2, 0.0, 100.0)
		"storm_damage":
			ColonyManager.happiness = clampf(ColonyManager.happiness + amount * 0.2, 0.0, 100.0)
		"winter_survival":
			ColonyManager.happiness = clampf(ColonyManager.happiness + amount * 0.3, 0.0, 100.0)
		"diplomacy_bonus":
			ColonyManager.social_order = clampf(ColonyManager.social_order + amount * 0.3, 0.0, 100.0)


## --- Event Chains ---
func _register_chains() -> void:
	_defined_chains = {
		"food_crisis": [
			"chain_food_warning",       # 1: advertencia de comida baja
			"chain_food_crisis",        # 2: crisis real
			"chain_food_desperation",   # 3: desesperación
		],
		"population_explosion": [
			"chain_pop_growth",         # 1: crecimiento
			"chain_pop_pressure",       # 2: presión en recursos
			"chain_pop_celebration",    # 3: o celebración
		],
		"disease_outbreak": [
			"chain_disease_suspect",    # 1: sospecha
			"chain_disease_spread",     # 2: propagación
			"chain_disease_recovery",   # 3: recuperación o colapso
		],
		"exploration_fever": [
			"chain_exploration_call",   # 1: llamado a explorar
			"chain_exploration_find",   # 2: hallazgo
			"chain_exploration_claim",  # 3: reclamar territorio
		],
	}


func _start_chain(chain_id: String) -> void:
	if _active_chain.size() > 0 and _active_chain[0] != chain_id:
		return  # Otra cadena activa
	if is_event_active:
		return

	_active_chain = _defined_chains.get(chain_id, [])
	_chain_event_index = 0
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🔗 Starting chain: %s (%d events)" % [chain_id, _active_chain.size()])
	_trigger_chain_event()


func _trigger_chain_event() -> void:
	if _chain_event_index >= _active_chain.size():
		_end_chain()
		return

	var generator_name: String = _active_chain[_chain_event_index]
	var event: Dictionary = _call_chain_generator(generator_name)
	if event.is_empty():
		_end_chain()
		return

	event["chain_id"] = _active_chain[0]
	event["chain_step"] = _chain_event_index + 1
	event["chain_total"] = _active_chain.size()

	current_event = event
	is_event_active = true
	response_timer = 0.0
	decision_timer = 0.0
	decision_event_triggered.emit(current_event)

	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🔗 Chain event %d/%d: %s" % [_chain_event_index + 1, _active_chain.size(), current_event["description"]])


func _advance_chain() -> void:
	_chain_event_index += 1
	if _chain_event_index < _active_chain.size():
		# Siguiente evento de la cadena en el próximo ciclo (no inmediatamente)
		decision_timer = _current_interval * 0.5  # acelera un poco


func _end_chain() -> void:
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🔗 Chain ended: %s" % _active_chain[0] if _active_chain.size() > 0 else "empty")
	_active_chain.clear()
	_chain_event_index = -1


func _call_chain_generator(name: String) -> Dictionary:
	# Returns empty dict if not found (caller checks for null/empty)
	match name:
		"chain_food_warning":
			return _chain_food_warning_event()
		"chain_food_crisis":
			return _chain_food_crisis_event()
		"chain_food_desperation":
			return _chain_food_desperation_event()
		"chain_pop_growth":
			return _chain_pop_growth_event()
		"chain_pop_pressure":
			return _chain_pop_pressure_event()
		"chain_pop_celebration":
			return _chain_pop_celebration_event()
		"chain_disease_suspect":
			return _chain_disease_suspect_event()
		"chain_disease_spread":
			return _chain_disease_spread_event()
		"chain_disease_recovery":
			return _chain_disease_recovery_event()
		"chain_exploration_call":
			return _chain_exploration_call_event()
		"chain_exploration_find":
			return _chain_exploration_find_event()
		"chain_exploration_claim":
			return _chain_exploration_claim_event()
	return {}


func _scaled_value(base: float) -> float:
	return roundf(base * _difficulty_multiplier)


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
		_technology_event(),
		# New event types
		_invasion_event(),
		_storm_event(),
		_diplomacy_event(),
	]


func _trigger_random_event() -> void:
	if event_pool.is_empty():
		return

	# Intentar iniciar una cadena si no hay una activa y hay condiciones
	if _active_chain.is_empty() and randf() < 0.35:
		_try_start_random_chain()
		if _active_chain.size() > 0:
			_trigger_chain_event()
			return

	var candidates: Array[Dictionary] = _build_contextual_event_pool()
	if candidates.is_empty():
		candidates = event_pool

	var event_index = randi() % candidates.size()
	current_event = candidates[event_index]
	is_event_active = true
	response_timer = 0.0
	decision_timer = 0.0
	
	decision_event_triggered.emit(current_event)
	
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🔔 Decision Event: ", current_event["description"])


func _try_start_random_chain() -> void:
	var eligible_chains: Array[String] = []
	var state: Dictionary = ResourceManager.get_resource_state()
	var food: float = state.get("food", 0.0)
	var wood: float = state.get("wood", 0.0)
	var pop: int = ColonyManager.population
	var health: float = ColonyManager.health_average

	if food < 50.0 and not _has_recently_resolved("food_crisis"):
		eligible_chains.append("food_crisis")
	if pop >= 8 and not _has_recently_resolved("population_explosion"):
		eligible_chains.append("population_explosion")
	if health < 60.0 and not _has_recently_resolved("disease_outbreak"):
		eligible_chains.append("disease_outbreak")
	if food > 60.0 and wood > 40.0 and not _has_recently_resolved("exploration_fever"):
		eligible_chains.append("exploration_fever")

	if eligible_chains.is_empty():
		return

	_start_chain(eligible_chains[randi() % eligible_chains.size()])


## --- Standalone Events (not chains, triggered via event pool) ---

func _invasion_event() -> Dictionary:
	var threat_level: String = "pequeño"
	var food_cost = _scaled_value(15.0)
	var health_hit = _scaled_value(10.0)

	if _difficulty_phase == DifficultyPhase.MID:
		threat_level = "mediano"
		food_cost = _scaled_value(20.0)
		health_hit = _scaled_value(15.0)
	elif _difficulty_phase == DifficultyPhase.LATE:
		threat_level = "grande"
		food_cost = _scaled_value(30.0)
		health_hit = _scaled_value(20.0)

	return {
		"type": "invasion",
		"description": "¡Un grupo de Beeps nómadas amenaza la colonia! Son %d invasores." % int(5 + _difficulty_multiplier * 5),
		"urgency": 0.9,
		"options": [
			{
				"id": "defend_colony",
				"text": "¡Defender la colonia a toda costa!",
				"effects": {
					"health": -health_hit,
					"happiness": -10,
					"social_order": 10,
					"food": -food_cost
				},
				"advance_chain": false
			},
			{
				"id": "negotiate",
				"text": "Intentar negociar con los nómadas",
				"effects": {
					"food": -food_cost * 0.7,
					"social_order": 5,
					"happiness": 5,
					"knowledge": 8
				},
				"advance_chain": false
			},
			{
				"id": "share_resources",
				"text": "Compartir recursos para evitar conflicto",
				"effects": {
					"food": -food_cost * 1.2,
					"wood": -_scaled_value(8.0),
					"happiness": -5,
					"social_order": 15,
					"health": -health_hit * 0.3,
					"persistent_effect": {"name": "diplomacy_bonus", "delta": 1.0, "duration": 60.0}
				},
				"advance_chain": false
			}
		],
		"default_option": {
			"id": "invasion_default",
			"text": "Sin defensa organizada",
			"effects": {
				"health": -health_hit * 1.5,
				"food": -food_cost * 1.3,
				"happiness": -25,
				"social_order": -15
			}
		}
	}


func _storm_event() -> Dictionary:
	return {
		"type": "natural_disaster",
		"description": "¡Una tormenta intensa se acerca! Los Beeps necesitan refugio.",
		"urgency": 0.85,
		"options": [
			{
				"id": "seek_shelter",
				"text": "Todos a los refugios",
				"effects": {
					"health": -_scaled_value(5.0),
					"happiness": -5,
					"wood": -_scaled_value(5.0),
					"persistent_effect": {"name": "storm_damage", "delta": -0.5, "duration": 30.0}
				}
			},
			{
				"id": "reinforce_shelters",
				"text": "Reforzar los refugios antes de la tormenta",
				"effects": {
					"wood": -_scaled_value(12.0),
					"stone": -_scaled_value(5.0),
					"health": -_scaled_value(2.0),
					"happiness": 0
				}
			},
			{
				"id": "ride_it_out",
				"text": "No hacer nada especial",
				"effects": {
					"health": -_scaled_value(15.0),
					"happiness": -15,
					"wood": -_scaled_value(10.0),
					"persistent_effect": {"name": "storm_damage", "delta": -1.5, "duration": 45.0}
				}
			}
		],
		"default_option": {
			"id": "storm_default",
			"text": "Tormenta sin preparación",
			"effects": {
				"health": -_scaled_value(20.0),
				"happiness": -20,
				"wood": -_scaled_value(15.0)
			}
		}
	}


func _diplomacy_event() -> Dictionary:
	return {
		"type": "diplomacy",
		"description": "Un grupo de Beeps errantes ha llegado buscando refugio. ¿Qué hacemos?",
		"urgency": 0.5,
		"options": [
			{
				"id": "welcome_refugees",
				"text": "Acogerlos en la colonia",
				"effects": {
					"food": -_scaled_value(10.0),
					"happiness": 15,
					"social_order": 10,
					"knowledge": 10,
					"persistent_effect": {"name": "celebration_bonus", "delta": 1.0, "duration": 50.0}
				}
			},
			{
				"id": "conditional_welcome",
				"text": "Acogerlos si contribuyen con trabajo",
				"effects": {
					"food": -_scaled_value(5.0),
					"wood": _scaled_value(8.0),
					"stone": _scaled_value(5.0),
					"social_order": 5
				}
			},
			{
				"id": "turn_away",
				"text": "Pedirles que sigan su camino",
				"effects": {
					"happiness": -10,
					"social_order": -5,
					"knowledge": -3
				}
			}
		],
		"default_option": {
			"id": "diplomacy_default",
			"text": "Sin decisión clara",
			"effects": {
				"happiness": -8,
				"social_order": -8
			}
		}
	}


func _has_recently_resolved(chain_id: String) -> bool:
	return _resolved_history.has(chain_id)


func _build_contextual_event_pool() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var state: Dictionary = ResourceManager.get_resource_state()
	var food: float = state.get("food", 0.0)
	var wood: float = state.get("wood", 0.0)
	var stone: float = state.get("stone", 0.0)
	var pop: int = ColonyManager.population
	var happiness: float = ColonyManager.happiness
	var health: float = ColonyManager.health_average

	for event in event_pool:
		var copies := _event_weight(event, food, wood, stone, pop, happiness, health)
		for i in range(copies):
			out.append(event)

	return out


func _event_weight(event: Dictionary, food: float, wood: float, stone: float, pop: int, happiness: float, health: float) -> int:
	var event_type: String = event.get("type", "")
	match event_type:
		"resource_shortage":
			var res: String = event.get("resource", "")
			if res == "food":
				if food < 40.0:
					return 5
				if food < 80.0:
					return 3
				return 0
			if res == "wood":
				if wood < 20.0:
					return 4
				if wood < 45.0:
					return 2
				return 0
			if res == "stone":
				if stone < 15.0:
					return 4
				if stone < 35.0:
					return 2
				return 0
		"population_growth":
			if pop >= max(4, int(GameConfig.REPRODUCTION_MAX_POPULATION * 0.4)):
				return 3
			return 1
		"disaster":
			var disaster: String = event.get("disaster", "")
			if disaster == "famine":
				if food < 30.0:
					return 4
				if food < 60.0:
					return 2
				return 0
			if disaster == "disease":
				if health < 55.0:
					return 4
				if health < 70.0:
					return 2
				return 1
		"moral":
			if happiness < 45.0:
				return 4
			if happiness < 65.0:
				return 2
			return 1
		"exploration":
			if food > 60.0 and wood > 40.0:
				return 2
			return 1
		"technology":
			if food > 55.0 and wood > 35.0 and stone > 25.0:
				return 2
			return 1
		"invasion":
			if _difficulty_phase == DifficultyPhase.EARLY:
				return 1
			if _difficulty_phase == DifficultyPhase.MID:
				return 2
			return 3
		"natural_disaster":
			return 1
		"diplomacy":
			if pop >= 10:
				return 2
			if happiness > 70.0:
				return 2
			return 1
		_:
			return 1

	return 1


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
		_track_history(current_event)
		is_event_active = false
		decision_resolved.emit(option_id)

		# Si es parte de una cadena, avanzar o terminar
		if current_event.get("chain_id", "") != "":
			var advance: bool = chosen_option.get("advance_chain", true)
			if advance:
				_advance_chain()
			else:
				_end_chain()

		if GameConfig.DEBUG_PRINT_DECISIONS:
			print("✅ Decision resolved: ", option_id)


func _timeout_current_event() -> void:
	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("⏰ Decision timed out - applying default effects")
	
	var default_option = current_event.get("default_option", null)
	if default_option != null:
		_apply_effects(default_option["effects"])
	
	_track_history(current_event)
	is_event_active = false
	decision_timed_out.emit()

	# Timeout termina la cadena
	if current_event.get("chain_id", "") != "":
		_end_chain()


func _track_history(event: Dictionary) -> void:
	var chain_id: String = event.get("chain_id", "")
	if chain_id != "":
		if not _resolved_history.has(chain_id):
			_resolved_history.append(chain_id)
			if _resolved_history.size() > MAX_HISTORY:
				_resolved_history.pop_front()


func _get_active_effects_description() -> String:
	if _persistent_effects.is_empty():
		return ""
	var parts: Array[String] = []
	for name in _persistent_effects:
		var eff: Dictionary = _persistent_effects[name]
		var remaining = ceilf(eff["remaining"])
		parts.append("%s (%ds)" % [name, remaining])
	return "Active: " + ", ".join(parts)


func _update_invasion_cooldown(delta: float) -> void:
	if _invasion_cooldown > 0.0:
		_invasion_cooldown -= delta


# --- Chain Event Generators ---

func _chain_food_warning_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "Los suministros de comida bajan más de lo esperado. ¿Actuamos pronto?",
		"urgency": 0.5,
		"options": [
			{
				"id": "chain_ration_now",
				"text": "Implementar racionamiento preventivo",
				"effects": {
					"priority": "food",
					"happiness": -5,
					"persistent_effect": {"name": "famine_penalty", "delta": 1.0, "duration": 45.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_ignore_warning",
				"text": "No alarmarse, sigue la rutina",
				"effects": {
					"food": -_scaled_value(10.0),
					"happiness": -3
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_warn_default",
			"text": "Sin acción",
			"effects": {
				"food": -_scaled_value(8.0)
			},
			"advance_chain": true
		}
	}


func _chain_food_crisis_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "¡La comida está críticamente baja! Los Beeps muestran señales de debilidad.",
		"urgency": 0.8,
		"options": [
			{
				"id": "chain_emergency_gather",
				"text": "Movilizar a TODOS para recolectar",
				"effects": {
					"priority": "food",
					"food": _scaled_value(20.0),
					"health": -_scaled_value(10.0),
					"happiness": -15,
					"persistent_effect": {"name": "famine_penalty", "delta": -1.0, "duration": 60.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_send_scouts",
				"text": "Enviar exploradores a buscar fuentes nuevas",
				"effects": {
					"priority": "exploration",
					"food": -_scaled_value(8.0),
					"persistent_effect": {"name": "exploration_bonus", "delta": 2.0, "duration": 50.0}
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_crisis_default",
			"text": "Desesperación",
			"effects": {
				"food": -_scaled_value(15.0),
				"happiness": -25,
				"health": -15
			},
			"advance_chain": true
		}
	}


func _chain_food_desperation_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "Los Beeps al borde del colapso. Las reservas están al límite.",
		"urgency": 0.95,
		"options": [
			{
				"id": "chain_last_resort_hunt",
				"text": "Expedición de supervivencia de alto riesgo",
				"effects": {
					"food": _scaled_value(35.0),
					"health": -_scaled_value(15.0),
					"happiness": -20,
					"social_order": -15,
					"persistent_effect": {"name": "winter_survival", "delta": 2.0, "duration": 90.0}
				},
				"advance_chain": false
			},
			{
				"id": "chain_accept_fate",
				"text": "Racionar al mínimo y esperar",
				"effects": {
					"food": -_scaled_value(5.0),
					"happiness": -30,
					"health": -25,
					"social_order": -20
				},
				"advance_chain": false
			}
		],
		"default_option": {
			"id": "chain_desperate_default",
			"text": "Colapso",
			"effects": {
				"food": -_scaled_value(20.0),
				"happiness": -35,
				"health": -30
			},
			"advance_chain": false
		}
	}


func _chain_pop_growth_event() -> Dictionary:
	var pop: int = ColonyManager.population
	return {
		"type": "chain",
		"description": "La colonia crece: %d Beeps. La energía es palpable." % pop,
		"urgency": 0.4,
		"options": [
			{
				"id": "chain_welcome_growth",
				"text": "¡Bienvenidos! Preparar nuevos espacios",
				"effects": {
					"happiness": 10,
					"social_order": 5,
					"food": -_scaled_value(5.0),
					"persistent_effect": {"name": "celebration_bonus", "delta": 1.0, "duration": 40.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_plan_growth",
				"text": "Planificar cuidadosamente la expansión",
				"effects": {
					"priority": "construction",
					"knowledge": 5
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_pop_default",
			"text": "Sin preparación",
			"effects": {
				"happiness": -5
			},
			"advance_chain": true
		}
	}


func _chain_pop_pressure_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "Con tantos Beeps, los recursos no dan abasto. Hay tensiones.",
		"urgency": 0.6,
		"options": [
			{
				"id": "chain_boost_gatherers",
				"text": "Más Beeps como recolectores",
				"effects": {
					"priority": "food",
					"food": _scaled_value(15.0),
					"wood": _scaled_value(8.0),
					"happiness": -5,
					"persistent_effect": {"name": "exploration_bonus", "delta": 1.5, "duration": 50.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_build_shelters",
				"text": "Priorizar refugios para todos",
				"effects": {
					"priority": "construction",
					"wood": -_scaled_value(12.0),
					"stone": -_scaled_value(5.0),
					"happiness": 10
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_pressure_default",
			"text": "Tensiones crecientes",
			"effects": {
				"happiness": -15,
				"social_order": -10
			},
			"advance_chain": true
		}
	}


func _chain_pop_celebration_event() -> Dictionary:
	var pop: int = ColonyManager.population
	return {
		"type": "chain",
		"description": "¡%d Beeps en la colonia! La comunidad es más fuerte que nunca." % pop,
		"urgency": 0.2,
		"options": [
			{
				"id": "chain_big_celebration",
				"text": "Gran celebración comunitaria",
				"effects": {
					"food": -_scaled_value(20.0),
					"happiness": 30,
					"social_order": 15,
					"persistent_effect": {"name": "celebration_bonus", "delta": 2.0, "duration": 90.0}
				},
				"advance_chain": false
			},
			{
				"id": "chain_channel_energy",
				"text": "Canalizar la energía en trabajo productivo",
				"effects": {
					"priority": "construction",
					"happiness": 10,
					"knowledge": 10,
					"wood": _scaled_value(10.0)
				},
				"advance_chain": false
			}
		],
		"default_option": {
			"id": "chain_celebrate_default",
			"text": "Pequeña celebración",
			"effects": {
				"happiness": 10,
				"food": -_scaled_value(8.0)
			},
			"advance_chain": false
		}
	}


func _chain_disease_suspect_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "Algunos Beeps muestran síntomas extraños. ¿Podría ser una enfermedad?",
		"urgency": 0.5,
		"options": [
			{
				"id": "chain_investigate_sick",
				"text": "Investigar y monitorear a los afectados",
				"effects": {
					"health": 5,
					"knowledge": 10,
					"persistent_effect": {"name": "quarantine_bonus", "delta": 1.0, "duration": 40.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_dismiss_symptoms",
				"text": "Probablemente nada grave, continuar",
				"effects": {
					"health": -_scaled_value(10.0)
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_suspect_default",
			"text": "Esperar y ver",
			"effects": {
				"health": -_scaled_value(5.0)
			},
			"advance_chain": true
		}
	}


func _chain_disease_spread_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "¡La enfermedad se propaga! Varios Beeps están enfermos.",
		"urgency": 0.85,
		"options": [
			{
				"id": "chain_full_quarantine",
				"text": "Cuarentena estricta de toda la colonia",
				"effects": {
					"health": 15,
					"happiness": -20,
					"social_order": -10,
					"wood": -_scaled_value(5.0),
					"persistent_effect": {"name": "quarantine_bonus", "delta": 2.0, "duration": 60.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_separate_groups",
				"text": "Separar enfermos y sanos en distintos grupos",
				"effects": {
					"health": 10,
					"happiness": -10,
					"social_order": -5
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_spread_default",
			"text": "Sin contención",
			"effects": {
				"health": -_scaled_value(25.0),
				"happiness": -25,
				"persistent_effect": {"name": "disease_penalty", "delta": -2.0, "duration": 50.0}
			},
			"advance_chain": true
		}
	}


func _chain_disease_recovery_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "La peor crisis pasó. Los Beeps se recuperan lentamente.",
		"urgency": 0.3,
		"options": [
			{
				"id": "chain_heal_together",
				"text": "Cuidado colectivo y descanso",
				"effects": {
					"health": 20,
					"happiness": 15,
					"social_order": 10,
					"food": -_scaled_value(10.0),
					"persistent_effect": {"name": "rest_day_bonus", "delta": 1.5, "duration": 60.0}
				},
				"advance_chain": false
			},
			{
				"id": "chain_learn_from_crisis",
				"text": "Documentar lo aprendido para prevenir",
				"effects": {
					"knowledge": 25,
					"health": 10,
					"happiness": 5
				},
				"advance_chain": false
			}
		],
		"default_option": {
			"id": "chain_recovery_default",
			"text": "Recuperación lenta",
			"effects": {
				"health": 5
			},
			"advance_chain": false
		}
	}


func _chain_exploration_call_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "Hay rumores de tierras ricas más allá del territorio conocido.",
		"urgency": 0.35,
		"options": [
			{
				"id": "chain_prepare_expedition",
				"text": "Preparar una expedición bien equipada",
				"effects": {
					"priority": "exploration",
					"food": -_scaled_value(10.0),
					"happiness": 10,
					"knowledge": 5,
					"persistent_effect": {"name": "exploration_bonus", "delta": 2.0, "duration": 45.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_cautious_exploration",
				"text": "Enviar un pequeño grupo de reconocimiento",
				"effects": {
					"food": -_scaled_value(5.0),
					"knowledge": 8
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_explore_default",
			"text": "No arriesgarse",
			"effects": {
				"happiness": -3
			},
			"advance_chain": true
		}
	}


func _chain_exploration_find_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "¡La expedición encontró algo valioso en las tierras nuevas!",
		"urgency": 0.5,
		"options": [
			{
				"id": "chain_claim_territory",
				"text": "Establecer presencia en el nuevo territorio",
				"effects": {
					"wood": _scaled_value(15.0),
					"stone": _scaled_value(10.0),
					"knowledge": 15,
					"happiness": 15,
					"food": _scaled_value(3.0),
					"persistent_effect": {"name": "exploration_bonus", "delta": 1.0, "duration": 30.0}
				},
				"advance_chain": true
			},
			{
				"id": "chain_quick_loot",
				"text": "Recoger recursos y volver rápido",
				"effects": {
					"wood": _scaled_value(10.0),
					"stone": _scaled_value(5.0),
					"happiness": 5
				},
				"advance_chain": true
			}
		],
		"default_option": {
			"id": "chain_find_default",
			"text": "Volver sin explorar más",
			"effects": {
				"knowledge": 5
			},
			"advance_chain": true
		}
	}


func _chain_exploration_claim_event() -> Dictionary:
	return {
		"type": "chain",
		"description": "El nuevo territorio ofrece grandes oportunidades. ¿Cómo lo integramos?",
		"urgency": 0.4,
		"options": [
			{
				"id": "chain_expand_colony",
				"text": "Expandir la colonia al nuevo territorio",
				"effects": {
					"priority": "construction",
					"happiness": 20,
					"knowledge": 20,
					"wood": _scaled_value(10.0),
					"stone": _scaled_value(8.0),
					"food": _scaled_value(5.0),
					"persistent_effect": {"name": "celebration_bonus", "delta": 1.5, "duration": 60.0}
				},
				"advance_chain": false
			},
			{
				"id": "chain_resource_outpost",
				"text": "Crear un puesto de recolección temporal",
				"effects": {
					"wood": _scaled_value(12.0),
					"stone": _scaled_value(8.0),
					"knowledge": 10,
					"happiness": 10
				},
				"advance_chain": false
			}
		],
		"default_option": {
			"id": "chain_claim_default",
			"text": "Mantener como zona de recolección",
			"effects": {
				"knowledge": 8,
				"happiness": 5
			},
			"advance_chain": false
		}
	}


func _apply_effects(effects: Dictionary) -> void:
	for key in effects:
		match key:
			"food":
				var val = _scaled_value(effects[key])
				if val > 0:
					ResourceManager.add_food(val)
				else:
					ResourceManager.remove_food(absf(val))
			"wood":
				var val = _scaled_value(effects[key])
				if val > 0:
					ResourceManager.add_wood(val)
				else:
					ResourceManager.remove_wood(absf(val))
			"stone":
				var val = _scaled_value(effects[key])
				if val > 0:
					ResourceManager.add_stone(val)
				else:
					ResourceManager.remove_stone(absf(val))
			"happiness":
				var val = _scaled_value(effects[key])
				ColonyManager.happiness = clampf(ColonyManager.happiness + val, 0.0, 100.0)
			"health":
				var val = _scaled_value(effects[key])
				ColonyManager.health_average = clampf(ColonyManager.health_average + val, 0.0, 100.0)
			"social_order":
				var val = _scaled_value(effects[key])
				ColonyManager.social_order = clampf(ColonyManager.social_order + val, 0.0, 100.0)
			"knowledge":
				var val = _scaled_value(effects[key])
				ColonyManager.knowledge = clampf(ColonyManager.knowledge + val, 0.0, 100.0)
			"priority":
				match effects[key]:
					"food":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.FOOD)
					"wood":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.CONSTRUCTION)
					"stone":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.CONSTRUCTION)
					"construction":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.CONSTRUCTION)
					"exploration":
						ColonyManager.set_colony_priority(ColonyManager.ColonyPriority.EXPLORATION)
			"persistent_effect":
				# Format: { "name": str, "delta": float, "duration": float }
				var pe: Dictionary = effects[key]
				add_persistent_effect(pe["name"], pe["delta"], pe["duration"])


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


# --- Discovery Events ---

func _on_area_discovered(_area_center: Vector2i, tiles_count: int) -> void:
	# Solo generar evento si hay suficiente descubrimiento y no estamos en cooldown
	if _discovery_cooldown > 0:
		return
	if tiles_count < 20:
		return  # Descubrimientos pequeños no generan eventos

	_discovery_cooldown = DISCOVERY_COOLDOWN

	if is_event_active:
		return  # Ya hay un evento activo

	# Generar evento de descubrimiento contextual
	var exploration_pct := FogOfWar.get_exploration_percentage()
	if exploration_pct < 0.2:
		current_event = _early_discovery_event(tiles_count)
	elif exploration_pct < 0.6:
		current_event = _mid_discovery_event(tiles_count)
	else:
		current_event = _late_discovery_event(tiles_count)

	is_event_active = true
	response_timer = 0.0
	decision_event_triggered.emit(current_event)

	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🗺️ Discovery Event: ", current_event["description"])


func _on_map_fully_explored() -> void:
	if is_event_active:
		return

	current_event = _map_complete_event()
	is_event_active = true
	response_timer = 0.0
	decision_event_triggered.emit(current_event)

	if GameConfig.DEBUG_PRINT_DECISIONS:
		print("🏆 Map Fully Explored!")


func _early_discovery_event(tiles_count: int) -> Dictionary:
	return {
		"type": "discovery",
		"description": "¡Los exploradores han revelado territorio nuevo! (%d tiles) ¿Qué hacemos?" % tiles_count,
		"urgency": 0.4,
		"options": [
			{
				"id": "send_more_explorers",
				"text": "Enviar más exploradores",
				"effects": {
					"priority": "exploration",
					"happiness": 10,
					"knowledge": 15,
					"food": -8
				}
			},
			{
				"id": "establish_camp",
				"text": "Establecer un campamento avanzado",
				"effects": {
					"priority": "construction",
					"wood": -8,
					"stone": -3,
					"knowledge": 10,
					"happiness": 5
				}
			},
			{
				"id": "focus_home",
				"text": "Concentrarnos en la base",
				"effects": {
					"knowledge": 5,
					"happiness": -3
				}
			}
		],
		"default_option": {
			"id": "do_nothing",
			"text": "Ninguna acción",
			"effects": {
				"knowledge": 2
			}
		}
	}


func _mid_discovery_event(tiles_count: int) -> Dictionary:
	return {
		"type": "discovery",
		"description": "Se ha descubierto una gran zona (%d tiles). ¿Cómo la aprovechamos?" % tiles_count,
		"urgency": 0.5,
		"options": [
			{
				"id": "explore_deeply",
				"text": "Exploración profunda del territorio",
				"effects": {
					"priority": "exploration",
					"knowledge": 20,
					"happiness": 15,
					"food": -12,
					"wood": 10
				}
			},
			{
				"id": "resource_survey",
				"text": "Evaluar recursos disponibles",
				"effects": {
					"knowledge": 15,
					"wood": 12,
					"stone": 8,
					"happiness": 5
				}
			},
			{
				"id": "expand_settlement",
				"text": "Expandir el asentamiento",
				"effects": {
					"priority": "construction",
					"wood": -10,
					"stone": -5,
					"happiness": 15,
					"knowledge": 10
				}
			}
		],
		"default_option": {
			"id": "do_nothing",
			"text": "Ninguna acción",
			"effects": {
				"knowledge": 5
			}
		}
	}


func _late_discovery_event(tiles_count: int) -> Dictionary:
	return {
		"type": "discovery",
		"description": "¡Últimas zonas por descubrir! (%d tiles nuevos) ¿Último esfuerzo?" % tiles_count,
		"urgency": 0.6,
		"options": [
			{
				"id": "final_push",
				"text": "Gran expedición final",
				"effects": {
					"priority": "exploration",
					"knowledge": 25,
					"happiness": 20,
					"food": -15,
					"health": -5
				}
			},
			{
				"id": "consolidate",
				"text": "Consolidar lo conquistado",
				"effects": {
					"knowledge": 15,
					"happiness": 10,
					"health": 10,
					"social_order": 10
				}
			}
		],
		"default_option": {
			"id": "do_nothing",
			"text": "Ninguna acción",
			"effects": {
				"knowledge": 8
			}
		}
	}


func _map_complete_event() -> Dictionary:
	return {
		"type": "discovery_complete",
		"description": "¡Todo el mapa ha sido explorado! La colonia tiene conocimiento total del territorio.",
		"urgency": 0.2,
		"options": [
			{
				"id": "celebrate",
				"text": "¡Celebrar el logro!",
				"effects": {
					"happiness": 30,
					"knowledge": 20,
					"social_order": 15,
					"food": -15
				}
			},
			{
				"id": "plan_future",
				"text": "Planificar la expansión futura",
				"effects": {
					"knowledge": 25,
					"happiness": 10,
					"social_order": 10
				}
			}
		],
		"default_option": {
			"id": "do_nothing",
			"text": "Ninguna acción",
			"effects": {
				"knowledge": 10,
				"happiness": 5
			}
		}
	}


## Update discovery cooldown
func _update_discovery_cooldown(delta: float) -> void:
	if _discovery_cooldown > 0:
		_discovery_cooldown -= delta
