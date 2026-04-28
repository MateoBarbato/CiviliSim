extends CanvasLayer

signal start_requested

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/VBox/SubtitleLabel
@onready var start_button: Button = $Panel/MarginContainer/VBox/StartButton
@onready var controls_label: Label = $Panel/MarginContainer/VBox/ControlsLabel


func _ready() -> void:
	_setup_styles()
	start_button.pressed.connect(_on_start_pressed)


func _setup_styles() -> void:
	# Panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.09, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Título
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.4))

	# Subtítulo
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

	# Botón
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.5, 0.3)
	button_style.border_color = Color(0.4, 0.7, 0.4)
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(6)
	start_button.add_theme_stylebox_override("normal", button_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.6, 0.4)
	hover_style.border_color = Color(0.5, 0.8, 0.5)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(6)
	start_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.15, 0.4, 0.2)
	pressed_style.border_color = Color(0.3, 0.6, 0.3)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(6)
	start_button.add_theme_stylebox_override("pressed", pressed_style)

	start_button.add_theme_font_size_override("font_size", 18)

	# Controles
	controls_label.add_theme_font_size_override("font_size", 12)
	controls_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))


func _on_start_pressed() -> void:
	visible = false
	start_requested.emit()
