## Controlador de cámara con zoom y pan
## Permite mover la cámara con WASD/flechas y hacer zoom con el scroll

class_name CameraController
extends Camera2D

## Velocidad de movimiento
@export var move_speed: float = 300.0

## Límites de zoom
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0

## Velocidad de zoom
@export var zoom_speed: float = 0.5

## Suavizado de movimiento
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 10.0

## Posición objetivo
var _target_position: Vector2 = Vector2.ZERO

## Zoom objetivo
var _target_zoom: Vector2 = Vector2.ONE




func _ready() -> void:
	_target_position = position
	_target_zoom = zoom


func _process(delta: float) -> void:
	_handle_movement(delta)
	_handle_zoom()
	_apply_smoothing(delta)


func _handle_movement(delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	
	# WASD o flechas
	if Input.is_action_pressed("camera_move_left"):
		direction.x -= 1
	if Input.is_action_pressed("camera_move_right"):
		direction.x += 1
	if Input.is_action_pressed("camera_move_up"):
		direction.y -= 1
	if Input.is_action_pressed("camera_move_down"):
		direction.y += 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		_target_position += direction * move_speed * delta


func _handle_zoom() -> void:
	# Zoom con scroll del mouse
	if Input.is_action_just_pressed("camera_zoom_in"):
		_target_zoom = _target_zoom * (1.0 - zoom_speed)
		_target_zoom = _target_zoom.clamp(Vector2(min_zoom), Vector2(max_zoom))
	
	if Input.is_action_just_pressed("camera_zoom_out"):
		_target_zoom = _target_zoom * (1.0 + zoom_speed)
		_target_zoom = _target_zoom.clamp(Vector2(min_zoom), Vector2(max_zoom))


func _apply_smoothing(delta: float) -> void:
	if smoothing_enabled:
		# Suavizar posición
		position = position.lerp(_target_position, smoothing_speed * delta)
		# Suavizar zoom
		zoom = zoom.lerp(_target_zoom, smoothing_speed * delta)
	else:
		position = _target_position
		zoom = _target_zoom



