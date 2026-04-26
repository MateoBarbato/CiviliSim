## Panel de decisiones del jugador
## Muestra eventos de decisión y permite elegir opciones

extends Control

## Referencias a nodos UI
@onready var event_label: Label = $MarginContainer/VBoxContainer/EventLabel
@onready var timer_bar: ProgressBar = $MarginContainer/VBoxContainer/TimerBar
@onready var options_container: VBoxContainer = $MarginContainer/VBoxContainer/OptionsContainer
@onready var background_color_rect: ColorRect = $BackgroundColorRect

## Referencia al DecisionSystem
var _decision_system: Node

## Estado
var current_event: Dictionary = {}
var is_visible: bool = false


func _ready() -> void:
	hide()
	_decision_system = _get_decision_system()
	if _decision_system:
		_decision_system.decision_event_triggered.connect(_on_decision_event_triggered)
		_decision_system.decision_resolved.connect(_on_decision_resolved)
		_decision_system.decision_timed_out.connect(_on_decision_timed_out)


func _get_decision_system() -> Node:
	if get_parent():
		for child in get_parent().get_children():
			if child.name == "DecisionSystem":
				return child
	return null


func _process(delta: float) -> void:
	if is_visible and _decision_system and _decision_system.is_event_active:
		_update_timer_bar()


func _on_decision_event_triggered(event: Dictionary) -> void:
	current_event = event
	_show_decision_panel(event)


func _show_decision_panel(event: Dictionary) -> void:
	show()
	is_visible = true
	
	event_label.text = event["description"]
	if _decision_system:
		timer_bar.max_value = _decision_system.response_time_limit
		timer_bar.value = _decision_system.response_time_limit
	timer_bar.modulate = Color.YELLOW
	
	_clear_options()
	_populate_options(event["options"])
	
	_animate_entry()


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _populate_options(options: Array) -> void:
	for option in options:
		var button = _create_option_button(option)
		options_container.add_child(button)


func _create_option_button(option: Dictionary) -> Button:
	var button = Button.new()
	button.text = option["text"]
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(_on_option_selected.bind(option["id"]))
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style_box.border_color = Color(0.4, 0.4, 0.5)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style_box)
	
	var style_box_hover = StyleBoxFlat.new()
	style_box_hover.bg_color = Color(0.25, 0.25, 0.35, 0.95)
	style_box_hover.border_color = Color(0.6, 0.6, 0.8)
	style_box_hover.set_border_width_all(2)
	style_box_hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", style_box_hover)
	
	return button


func _on_option_selected(option_id: String) -> void:
	_decision_system.resolve_decision(option_id)


func _update_timer_bar() -> void:
	var remaining = _decision_system.get_remaining_time()
	timer_bar.value = remaining
	
	if remaining < _decision_system.response_time_limit * 0.3:
		timer_bar.modulate = Color.RED
	elif remaining < _decision_system.response_time_limit * 0.6:
		timer_bar.modulate = Color.ORANGE
	else:
		timer_bar.modulate = Color.YELLOW


func _on_decision_resolved(option_id: String) -> void:
	_animate_exit()


func _on_decision_timed_out() -> void:
	_animate_exit()


func _animate_entry() -> void:
	modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)


func _animate_exit() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(func():
		hide()
		is_visible = false
	)



