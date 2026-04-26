## Loader para registrar class_name de scripts y input actions
extends Node

# Forzar carga de scripts con class_name (orden importa para dependencias)
const _BuildingBase = preload("res://scenes/buildings/Building.gd")
const _BeepStats = preload("res://scripts/agents/beep_stats.gd")
const _ResourceNodeScene = preload("res://scenes/resources/ResourceNode.gd")

# Shelter depende de BuildingBase, cargar después
var _shelter_loaded: bool = false

func _ready() -> void:
	# Cargar Shelter después de BuildingBase
	if not _shelter_loaded:
		var shelter_script = load("res://scenes/buildings/Shelter.gd")
		_shelter_loaded = shelter_script != null
	
	# Registrar input actions para Godot 4.6.2
	_register_input_actions()

# Registrar input actions programáticamente (Godot 4.6.2 no parsea [input] correctamente)
func _register_input_actions() -> void:
	var input_map = InputMap
	
	# Camera zoom (mouse wheel up/down)
	_add_action_if_missing(input_map, "camera_zoom_in")
	_add_action_if_missing(input_map, "camera_zoom_out")
	
	# Camera movement (WASD + arrow keys)
	_add_action_if_missing(input_map, "camera_move_left")
	_add_action_if_missing(input_map, "camera_move_right")
	_add_action_if_missing(input_map, "camera_move_up")
	_add_action_if_missing(input_map, "camera_move_down")
	
	# UI actions
	_add_action_if_missing(input_map, "ui_pause")
	_add_action_if_missing(input_map, "ui_debug")
	
	# Camera zoom: mouse wheel
	var zoom_in = InputEventMouseButton.new()
	zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_in.pressed = true
	input_map.action_add_event("camera_zoom_in", zoom_in)
	
	var zoom_out = InputEventMouseButton.new()
	zoom_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom_out.pressed = true
	input_map.action_add_event("camera_zoom_out", zoom_out)
	
	# Camera move: WASD
	var key_a = InputEventKey.new()
	key_a.physical_keycode = KEY_A
	key_a.pressed = true
	input_map.action_add_event("camera_move_left", key_a)
	
	var key_d = InputEventKey.new()
	key_d.physical_keycode = KEY_D
	key_d.pressed = true
	input_map.action_add_event("camera_move_right", key_d)
	
	var key_w = InputEventKey.new()
	key_w.physical_keycode = KEY_W
	key_w.pressed = true
	input_map.action_add_event("camera_move_up", key_w)
	
	var key_s = InputEventKey.new()
	key_s.physical_keycode = KEY_S
	key_s.pressed = true
	input_map.action_add_event("camera_move_down", key_s)
	
	# Camera move: Arrow keys
	var key_left = InputEventKey.new()
	key_left.physical_keycode = KEY_LEFT
	key_left.pressed = true
	input_map.action_add_event("camera_move_left", key_left)
	
	var key_right = InputEventKey.new()
	key_right.physical_keycode = KEY_RIGHT
	key_right.pressed = true
	input_map.action_add_event("camera_move_right", key_right)
	
	var key_up = InputEventKey.new()
	key_up.physical_keycode = KEY_UP
	key_up.pressed = true
	input_map.action_add_event("camera_move_up", key_up)
	
	var key_down = InputEventKey.new()
	key_down.physical_keycode = KEY_DOWN
	key_down.pressed = true
	input_map.action_add_event("camera_move_down", key_down)
	
	# UI Pause: Escape or F5
	var key_escape = InputEventKey.new()
	key_escape.physical_keycode = KEY_ESCAPE
	key_escape.pressed = true
	input_map.action_add_event("ui_pause", key_escape)
	
	var key_f5 = InputEventKey.new()
	key_f5.physical_keycode = KEY_F5
	key_f5.pressed = true
	input_map.action_add_event("ui_pause", key_f5)
	
	# UI Debug: F1
	var key_f1 = InputEventKey.new()
	key_f1.physical_keycode = KEY_F1
	key_f1.pressed = true
	input_map.action_add_event("ui_debug", key_f1)


static func _add_action_if_missing(input_map: InputMap, action_name: String) -> void:
	if not input_map.has_action(action_name):
		input_map.add_action(action_name)
