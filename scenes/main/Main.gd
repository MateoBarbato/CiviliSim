## Scene principal del juego
## Gestiona el inicio, pausa y fin del juego

extends Node2D

## Referencias
@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var ui_layer: CanvasLayer = $UILayer

## Estado del juego
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }
var current_state: GameState = GameState.MENU

## Tiempo de juego
var game_time: float = 0.0


func _ready() -> void:
	# Conectar señales de ColonyManager
	ColonyManager.game_over.connect(_on_game_over)
	ColonyManager.victory.connect(_on_victory)
	
	# Mostrar menú inicial
	_show_menu()


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		game_time += delta


func _input(event: InputEvent) -> void:
	if current_state == GameState.PLAYING:
		if event.is_action_pressed("ui_pause"):
			_pause_game()
	elif current_state == GameState.PAUSED:
		if event.is_action_pressed("ui_pause"):
			_resume_game()


func start_game() -> void:
	current_state = GameState.PLAYING
	game_time = 0.0
	ColonyManager.start_game()
	world.initialize_beeps()


func _pause_game() -> void:
	current_state = GameState.PAUSED
	get_tree().paused = true


func _resume_game() -> void:
	current_state = GameState.PLAYING
	get_tree().paused = false


func _show_menu() -> void:
	current_state = GameState.MENU
	# Mostrar UI del menú
	pass


func _on_game_over() -> void:
	current_state = GameState.GAME_OVER
	# Mostrar pantalla de Game Over
	print("GAME OVER - Todos los Beeps han muerto")


func _on_victory() -> void:
	current_state = GameState.VICTORY
	# Mostrar pantalla de victoria
	print("VICTORIA - La colonia alcanzó 10 Beeps!")
