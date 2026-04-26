## Scene principal del juego
## Gestiona el inicio, pausa y fin del juego

extends Node2D

const WORLD_SCENE = preload("res://scenes/world/world.tscn")

## Referencias
var world: WorldScene = null
@onready var camera: Camera2D = $Camera2D
@onready var decision_system: Node = $DecisionSystem
@onready var game_ui: CanvasLayer = get_node_or_null("GameUI")
@onready var decision_panel: Control = get_node_or_null("DecisionPanel")

## Estado del juego
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }
var current_state: GameState = GameState.MENU

## Referencia a la escena del menú
var menu_scene: PackedScene = null


func _ready() -> void:
	ColonyManager.game_over.connect(_on_game_over)
	ColonyManager.victory.connect(_on_victory)
	world = WORLD_SCENE.instantiate()
	add_child(world)
	await get_tree().process_frame
	start_game()



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
	if game_ui:
		game_ui.show()
	if decision_panel:
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
	if game_ui:
		game_ui.hide()
	if decision_panel:
		decision_panel.hide()
	print("GAME OVER - Todos los Beeps han muerto")


func _on_victory() -> void:
	current_state = GameState.VICTORY
	if game_ui:
		game_ui.hide()
	if decision_panel:
		decision_panel.hide()
	print("VICTORIA - La colonia alcanzó %d Beeps!" % GameConfig.WIN_POPULATION)
