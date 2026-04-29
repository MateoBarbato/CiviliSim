## Nodo de recurso en el mundo
## Representa un recurso recolectable (comida, madera, piedra)

class_name ResourceNodeScene
extends Node2D

signal resource_collected(resource_type: ResourceType.Type, amount: float)
signal resource_depleted

## Tipo de recurso
var _resource_type: ResourceType.Type = ResourceType.Type.FOOD

## Cantidad disponible
var _amount: float = 0.0
var _max_amount: float = 100.0

## Tasa de regeneración
var _regeneration_rate: float = 1.0

## ¿Está activo?
var _is_active: bool = true

## Placeholder visual
const RESOURCE_RADIUS: float = 12.0

## Referencias visuales
@onready var sprite: Sprite2D = $Sprite2D
@onready var amount_label: Label = $AmountLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## Valores por tipo de recurso
const COLLECTION_AMOUNTS: Dictionary = {
	ResourceType.Type.FOOD: 5.0,
	ResourceType.Type.WOOD: 3.0,
	ResourceType.Type.STONE: 2.0
}

const MAX_AMOUNTS: Dictionary = {
	ResourceType.Type.FOOD: 100.0,
	ResourceType.Type.WOOD: 100.0,
	ResourceType.Type.STONE: 100.0
}

const REGENERATION_RATES: Dictionary = {
	ResourceType.Type.FOOD: 2.0,
	ResourceType.Type.WOOD: 0.5,
	ResourceType.Type.STONE: 0.25
}


func _ready() -> void:
	_update_visuals()
	queue_redraw()


func _draw() -> void:
	var color: Color = ResourceType.get_color(_resource_type)
	draw_circle(Vector2.ZERO, RESOURCE_RADIUS, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, RESOURCE_RADIUS - 2, color)


func _process(delta: float) -> void:
	_regenerate(delta)

	# Clima: posibilidad de destrucción en tormenta (normalizado por delta)
	if WeatherSystem.current_weather == WeatherSystem.Weather.STORM:
		var destruct_chance: float = WeatherSystem.get_resource_destruct_chance() * delta
		if randf() < destruct_chance:
			_amount = maxf(_amount - 10.0, 0.0)
			if _amount <= 0:
				_is_active = false
				resource_depleted.emit()
			_update_visuals()


func set_resource_type(resource_type: ResourceType.Type) -> void:
	_resource_type = resource_type
	_max_amount = MAX_AMOUNTS.get(resource_type, 100.0)
	_amount = _max_amount
	_regeneration_rate = REGENERATION_RATES.get(resource_type, 1.0)
	_update_visuals()


func get_resource_type() -> ResourceType.Type:
	return _resource_type


func get_amount() -> float:
	return _amount


func is_active() -> bool:
	return _is_active


func can_collect() -> bool:
	return _is_active and _amount > 0


func collect() -> float:
	if not can_collect():
		return 0.0
	
	var amount: float = COLLECTION_AMOUNTS.get(_resource_type, 1.0)
	var actual_amount: float = minf(amount, _amount)
	
	_amount -= actual_amount
	resource_collected.emit(_resource_type, actual_amount)
	
	if _amount <= 0:
		_amount = 0.0
		_is_active = false
		resource_depleted.emit()
	
	_update_visuals()
	return actual_amount


func _update_visuals() -> void:
	if sprite == null:
		return
	
	var color: Color = ResourceType.get_color(_resource_type)
	sprite.modulate = color
	if amount_label:
		amount_label.text = str(int(round(_amount)))
	
	if _is_active:
		show()
	else:
		hide()
	
	queue_redraw()


func _regenerate(delta: float) -> void:
	if _amount < _max_amount:
		# Clima: multiplicador de regeneración según tipo de recurso y clima
		var weather_mult: float = WeatherSystem.get_resource_regen_multiplier(_resource_type)
		_amount += _regeneration_rate * weather_mult * delta
		_amount = minf(_amount, _max_amount)

		if _amount > 0 and not _is_active:
			_is_active = true
			_update_visuals()
