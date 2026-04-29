## Sistema de clima
## Autoload: WeatherSystem
## Controla estados de clima, transiciones naturales y efectos en el mundo

extends Node

## Estados de clima
enum Weather {
	CLEAR,
	RAIN,
	STORM,
	FOG,
	WIND
}

## Señales
signal weather_changed(new_weather: Weather, duration: float)
signal storm_started
signal storm_ended

## Clima actual
var current_weather: Weather = Weather.CLEAR

## Duración del clima actual (s)
var _weather_timer: float = 0.0
var _weather_duration: float = 60.0

## Si true, el clima fue forzado por un evento (no cambiar hasta que expire)
var _is_forced: bool = false
var _forced_duration: float = 0.0

## Multiplicador de daño de tormenta (reforzar refugios lo baja)
var storm_severity: float = 1.0

## Intensity 0.0 → 1.0 para fade visual
var intensity: float = 0.0
const FADE_SPEED: float = 2.0  # cuánto tarda en llegar a 1.0

## Probabilidades de transición natural (pesos)
# Desde CLEAR: RAIN(40), FOG(20), WIND(25), STORM(15)
# Desde RAIN: CLEAR(30), STORM(25), FOG(20), WIND(25)
# Desde STORM: RAIN(50), CLEAR(30), WIND(20)
# Desde FOG: CLEAR(40), RAIN(25), WIND(25), STORM(10)
# Desde WIND: CLEAR(40), RAIN(20), FOG(25), STORM(15)
const TRANSITION_WEIGHTS: Dictionary = {
	Weather.CLEAR: {
		Weather.RAIN: 40,
		Weather.FOG: 20,
		Weather.WIND: 25,
		Weather.STORM: 15
	},
	Weather.RAIN: {
		Weather.CLEAR: 30,
		Weather.STORM: 25,
		Weather.FOG: 20,
		Weather.WIND: 25
	},
	Weather.STORM: {
		Weather.RAIN: 50,
		Weather.CLEAR: 30,
		Weather.WIND: 20
	},
	Weather.FOG: {
		Weather.CLEAR: 40,
		Weather.RAIN: 25,
		Weather.WIND: 25,
		Weather.STORM: 10
	},
	Weather.WIND: {
		Weather.CLEAR: 40,
		Weather.RAIN: 20,
		Weather.FOG: 25,
		Weather.STORM: 15
	}
}


func _process(delta: float) -> void:
	# Fade de intensidad hacia 1.0 cuando cambia el clima
	if intensity < 1.0 and current_weather != Weather.CLEAR:
		intensity = minf(intensity + FADE_SPEED * delta, 1.0)
	elif intensity > 0.0 and current_weather == Weather.CLEAR:
		intensity = maxf(intensity - FADE_SPEED * delta, 0.0)

	# Timer del clima actual
	_weather_timer += delta

	# Si es forzado, no cambiar hasta que expire
	if _is_forced:
		if _weather_timer >= _forced_duration:
			_is_forced = false
			_weather_timer = 0.0
			_set_weather(Weather.CLEAR)
		return

	# Cambio natural
	if _weather_timer >= _weather_duration:
		_weather_timer = 0.0
		_weather_duration = randf_range(30.0, 90.0)  # duración del nuevo clima
		_pick_next_weather()


## Forzar un clima específico (usado por eventos del DecisionSystem)
## Idempotente: si ya está forzado con el mismo clima, no resetea el timer
func force_set_weather(weather: Weather, duration: float = -1.0) -> void:
	if duration < 0:
		duration = GameConfig.WEATHER_STORM_DURATION

	# Si ya está forzado con el mismo clima, no resetear (evita extensión)
	if _is_forced and current_weather == weather:
		return

	_is_forced = true
	_forced_duration = duration
	_weather_timer = 0.0
	_weather_duration = duration
	if weather == Weather.STORM:
		storm_severity = 1.0
	_set_weather(weather)


## Reducir severidad de tormenta (reforzar refugios)
## NO resetea el timer — solo baja el multiplicador de daño
func reduce_storm_severity(factor: float) -> void:
	storm_severity = maxf(storm_severity * (1.0 - factor), 0.3)


## Obtener multiplicador de velocidad para beeps según clima actual
func get_speed_multiplier() -> float:
	match current_weather:
		Weather.RAIN: return GameConfig.WEATHER_SPEED_RAIN
		Weather.FOG: return GameConfig.WEATHER_SPEED_FOG
		Weather.WIND: return GameConfig.WEATHER_SPEED_WIND
		Weather.STORM: return GameConfig.WEATHER_SPEED_STORM
	return GameConfig.WEATHER_SPEED_CLEAR


## Obtener multiplicador de radio de detección (niebla)
func get_detection_multiplier() -> float:
	if current_weather == Weather.FOG:
		return GameConfig.WEATHER_FOG_DETECTION_MULT
	return 1.0


## Daño por segundo en tormenta (multiplicado por severidad)
func get_storm_damage_per_sec() -> float:
	if current_weather == Weather.STORM:
		return GameConfig.WEATHER_STORM_DAMAGE_PER_SEC * storm_severity
	return 0.0


## Multiplicador de regeneración de recursos por clima
func get_resource_regen_multiplier(resource_type: ResourceType.Type) -> float:
	match current_weather:
		Weather.RAIN:
			if resource_type == ResourceType.Type.FOOD:
				return GameConfig.WEATHER_RAIN_FOOD_REGEN_MULT
		Weather.STORM:
			if resource_type == ResourceType.Type.FOOD:
				return GameConfig.WEATHER_STORM_FOOD_REGEN_MULT
		Weather.WIND:
			if resource_type == ResourceType.Type.WOOD:
				return GameConfig.WEATHER_WIND_WOOD_REGEN_MULT
	return 1.0


## Probabilidad de destrucción de recurso en tormenta (por tick)
func get_resource_destruct_chance() -> float:
	if current_weather == Weather.STORM:
		return GameConfig.WEATHER_STORM_RESOURCE_DESTRUCT_CHANCE * storm_severity
	return 0.0


## Nombre legible del clima
func get_weather_name() -> String:
	match current_weather:
		Weather.CLEAR: return "Despejado"
		Weather.RAIN: return "Lluvia"
		Weather.STORM: return "Tormenta"
		Weather.FOG: return "Niebla"
		Weather.WIND: return "Viento"
	return "Despejado"


## Emoji del clima
func get_weather_emoji() -> String:
	match current_weather:
		Weather.CLEAR: return "☀️"
		Weather.RAIN: return "🌧️"
		Weather.STORM: return "⛈️"
		Weather.FOG: return "🌫️"
		Weather.WIND: return "💨"
	return "☀️"


## Cambiar clima interno (emite señal, maneja señales de tormenta)
func _set_weather(weather: Weather) -> void:
	var old = current_weather
	current_weather = weather
	intensity = 0.0

	if weather == Weather.STORM and old != Weather.STORM:
		storm_started.emit()
	elif old == Weather.STORM and weather != Weather.STORM:
		storm_ended.emit()

	weather_changed.emit(weather, _weather_duration)


## Elegir siguiente clima basado en pesos
func _pick_next_weather() -> void:
	var weights: Dictionary = TRANSITION_WEIGHTS.get(current_weather, {})
	if weights.is_empty():
		_set_weather(Weather.CLEAR)
		return

	var total: int = 0
	for w in weights:
		total += weights[w]

	var roll: int = randi() % total
	var cumulative: int = 0
	for w in weights:
		cumulative += weights[w]
		if roll < cumulative:
			_set_weather(w)
			return

	# Fallback
	_set_weather(Weather.CLEAR)


func _random_change_interval() -> float:
	return randf_range(
		GameConfig.WEATHER_CHANGE_MIN_INTERVAL,
		GameConfig.WEATHER_CHANGE_MAX_INTERVAL
	)
