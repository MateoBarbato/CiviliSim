extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var result_title: Label = $Panel/MarginContainer/VBox/ResultTitle
@onready var result_message: Label = $Panel/MarginContainer/VBox/ResultMessage
@onready var population_label: Label = $Panel/MarginContainer/VBox/PopulationLabel
@onready var time_label: Label = $Panel/MarginContainer/VBox/TimeLabel
@onready var restart_button: Button = $Panel/MarginContainer/VBox/RestartButton


func _ready() -> void:
	_setup_styles()
	visible = false


func _setup_styles() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.09, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)

	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.5, 0.3)
	button_style.border_color = Color(0.4, 0.7, 0.4)
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(6)
	restart_button.add_theme_stylebox_override("normal", button_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.6, 0.4)
	hover_style.border_color = Color(0.5, 0.8, 0.5)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(6)
	restart_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.4, 0.2)
	pressed_style.border_color = Color(0.3, 0.6, 0.3)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(6)
	restart_button.add_theme_stylebox_override("pressed", pressed_style)

	restart_button.pressed.connect(_on_restart_pressed)


func show_game_over() -> void:
	_setup_result_colors(Color(0.8, 0.2, 0.2), Color(0.6, 0.15, 0.15))
	result_title.text = "GAME OVER"
	result_message.text = "La colonia ha caído."
	_update_stats()
	visible = true


func show_victory() -> void:
	_setup_result_colors(Color(0.2, 0.7, 0.3), Color(0.4, 0.85, 0.3))
	result_title.text = "VICTORIA"
	result_message.text = "La colonia ha prosperado."
	_update_stats()
	visible = true


func _setup_result_colors(title_color: Color, button_base: Color) -> void:
	if result_title:
		result_title.add_theme_color_override("font_color", title_color)

	var button_style = StyleBoxFlat.new()
	button_style.bg_color = button_base
	button_style.border_color = button_base.lightened(0.2)
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(6)
	restart_button.add_theme_stylebox_override("normal", button_style)


func _update_stats() -> void:
	population_label.text = "Población final: %d" % ColonyManager.population

	var minutes = int(ColonyManager.game_time / 60.0)
	var seconds = int(ColonyManager.game_time) % 60
	time_label.text = "Tiempo: %02d:%02d" % [minutes, seconds]


func _on_restart_pressed() -> void:
	visible = false
	get_tree().reload_current_scene()
