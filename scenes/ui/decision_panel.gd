extends Control

@onready var event_label: Label = $MarginContainer/VBoxContainer/EventLabel
@onready var options_container: VBoxContainer = $MarginContainer/VBoxContainer/OptionsContainer

var _decision_system: Node
var current_event: Dictionary = {}
var is_visible: bool = false


func _ready() -> void:
	_decision_system = _get_decision_system()
	if _decision_system:
		_decision_system.decision_event_triggered.connect(_on_decision_event_triggered)
		_decision_system.decision_resolved.connect(_on_decision_resolved)
		_decision_system.decision_timed_out.connect(_on_decision_timed_out)


func _get_decision_system() -> Node:
	var parent = get_parent()
	while parent:
		for child in parent.get_children():
			if child.name == "DecisionSystem":
				return child
		parent = parent.get_parent()
	return null


func _on_decision_event_triggered(event: Dictionary) -> void:
	current_event = event
	event_label.text = event["description"]
	event_label.visible = true
	_clear_options()
	_populate_options(event["options"])


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _populate_options(options: Array) -> void:
	for i in range(options.size()):
		var option = options[i]
		var button = _create_option_button(i + 1, option["text"])
		options_container.add_child(button)


func _create_option_button(num: int, text: String) -> Button:
	var button = Button.new()
	button.text = "[%d] %s" % [num, text]
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(_on_option_selected.bind(num))
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.35, 0.95)
	hover.border_color = Color(0.6, 0.6, 0.8)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", hover)
	
	return button


func _on_option_selected(option_num: int) -> void:
	if _decision_system and _decision_system.is_event_active:
		var options = current_event.get("options", [])
		if option_num > 0 and option_num <= options.size():
			var selected = options[option_num - 1]
			_decision_system.resolve_decision(selected["id"])


func _on_decision_resolved(_option_id: String) -> void:
	_clear_options()
	event_label.visible = false


func _on_decision_timed_out() -> void:
	_clear_options()
	event_label.visible = false
