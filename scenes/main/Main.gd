## Scene principal del juego
## Gestiona el inicio, pausa y fin del juego

extends Node2D

## Referencias
@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var decision_system: DecisionSystem = $DecisionSystem
@onready var game_ui: CanvasLayer = $GameUI
@onready var decision_panel: Control = $DecisionPanel

## Estado del juego
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }
var current_state: GameState = GameState.MENU

## Referencia a la escena del menú
var menu_scene: PackedScene = preload("res://scenes/ui/menu.tscn") if ResourceLoader.exists("res://scenes/ui/menu.tscn") else null


func _ready() -> void:
	ColonyManager.game_over.connect(_on_game_over)
	ColonyManager.victory.connect(_on_victory)
	_show_menu()



func _input(event: InputEvent) -> void:
	if current_state == GameState.PLAYING:
		if event.is_action_pressed("ui_pause"):
			_pause_game()
	elif current_state == GameState.PAUSED:
		if event.is_action_pressed("ui_pause"):
			_resume_game()
	elif current_state == GameState.MENU:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
			start_game()


func start_game() -> void:
	current_state = GameState.PLAYING
	ColonyManager.start_game()
	world.initialize_beeps()
	game_ui.show()
	decision_panel.show()


func _pause_game() -> void:
	current_state = GameState.PAUSED
	get_tree().paused = true


func _resume_game() -> void:
	current_state = GameState.PLAYING
	get_tree().paused = false


func _show_menu() -> void:
	current_state = GameState.MENU
	if menu_scene:
		var menu_instance = menu_scene.instantiate()
		add_child(menu_instance)


func _on_game_over() -> void:
	current_state = GameState.GAME_OVER
	game_ui.hide()
	decision_panel.hide()
	print("GAME OVER - Todos los Beeps han muerto")


func _on_victory() -> void:
	current_state = GameState.VICTORY
	game_ui.hide()
	decision_panel.hide()
	print("VICTORIA - La colonia alcanzó 10 Beeps!")
