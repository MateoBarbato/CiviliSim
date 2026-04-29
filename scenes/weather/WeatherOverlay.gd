## Overlay visual de clima
## Se renderiza dentro del GameViewport y responde a WeatherSystem

extends CanvasLayer

@onready var rain_particles: GPUParticles2D = $RainParticles
@onready var storm_particles: GPUParticles2D = $StormParticles
@onready var fog_overlay: ColorRect = $FogOverlay
@onready var darkness_overlay: ColorRect = $DarknessOverlay
@onready var wind_particles: GPUParticles2D = $WindParticles

const FADE_SPEED: float = 1.5


func _ready() -> void:
	# Conectar señales de WeatherSystem
	WeatherSystem.weather_changed.connect(_on_weather_changed)
	WeatherSystem.storm_started.connect(_on_storm_started)
	WeatherSystem.storm_ended.connect(_on_storm_ended)

	# Configurar visibilidad inicial
	rain_particles.emitting = false
	storm_particles.emitting = false
	wind_particles.emitting = false
	fog_overlay.visible = false
	darkness_overlay.visible = false
	fog_overlay.modulate = Color(1, 1, 1, 0)
	darkness_overlay.modulate = Color(1, 1, 1, 0)


func _process(delta: float) -> void:
	# Smooth fade de overlays
	var current_fog: float = fog_overlay.modulate.a
	fog_overlay.modulate.a = lerp(current_fog, _target_fog_alpha(), FADE_SPEED * delta)

	var current_dark: float = darkness_overlay.modulate.a
	darkness_overlay.modulate.a = lerp(current_dark, _target_dark_alpha(), FADE_SPEED * delta)

	# Shake de cámara en tormenta (usar camera_shake_offset, no modificar position)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera and WeatherSystem.current_weather == WeatherSystem.Weather.STORM:
		var strength: float = GameConfig.WEATHER_STORM_SHAKE_STRENGTH * WeatherSystem.storm_severity
		camera.camera_shake(1.0, 1.0, strength, 0.0)


func _on_weather_changed(new_weather: WeatherSystem.Weather, _duration: float) -> void:
	# Reset todo
	rain_particles.emitting = false
	storm_particles.emitting = false
	wind_particles.emitting = false

	match new_weather:
		WeatherSystem.Weather.RAIN:
			rain_particles.emitting = true
			fog_overlay.visible = false
			darkness_overlay.visible = true

		WeatherSystem.Weather.STORM:
			rain_particles.emitting = true
			storm_particles.emitting = true
			fog_overlay.visible = false
			darkness_overlay.visible = true

		WeatherSystem.Weather.FOG:
			fog_overlay.visible = true
			darkness_overlay.visible = false

		WeatherSystem.Weather.WIND:
			wind_particles.emitting = true
			fog_overlay.visible = false
			darkness_overlay.visible = false

		WeatherSystem.Weather.CLEAR:
			fog_overlay.visible = false
			darkness_overlay.visible = false


func _on_storm_started() -> void:
	storm_particles.emitting = true


func _on_storm_ended() -> void:
	storm_particles.emitting = false


func _target_fog_alpha() -> float:
	if WeatherSystem.current_weather == WeatherSystem.Weather.FOG:
		return 0.35
	return 0.0


func _target_dark_alpha() -> float:
	match WeatherSystem.current_weather:
		WeatherSystem.Weather.RAIN:
			return 0.1
		WeatherSystem.Weather.STORM:
			return 0.35
	return 0.0
