extends Node2D

const WORLD_SCENE = preload("res://scenes/world/world.tscn")

var world: WorldScene = null
@onready var game_viewport: SubViewport = $GameViewport
@onready var game_view: TextureRect = $GameView

enum GameState { PLAYING, PAUSED, GAME_OVER, VICTORY }
var current_state: GameState = GameState.PLAYING


func _ready() -> void:
	ColonyManager.game_over.connect(_on_game_over)
	ColonyManager.victory.connect(_on_victory)
	
	# Conectar SubViewport al TextureRect
	var vp_texture = ViewportTexture.new()
	vp_texture.viewport_path = game_viewport.get_path()
	game_view.texture = vp_texture
	
	# Instanciar world dentro del SubViewport
	world = WORLD_SCENE.instantiate()
	game_viewport.add_child(world)
	
	# Iniciar juego con un delay breve
	await get_tree().create_timer(0.1).timeout
	start_game()


func _input(event: InputEvent) -> void:
	if current_state == GameState.PLAYING:
		if event.is_action_pressed("ui_pause"):
			_pause_game()
	elif current_state == GameState.PAUSED:
		if event.is_action_pressed("ui_pause"):
			_resume_game()


func start_game() -> void:
	current_state = GameState.PLAYING
	ColonyManager.start_game()
	world.initialize_beeps()


func _pause_game() -> void:
	current_state = GameState.PAUSED
	get_tree().paused = true


func _resume_game() -> void:
	current_state = GameState.PLAYING
	get_tree().paused = false


func _on_game_over() -> void:
	current_state = GameState.GAME_OVER
	print("GAME OVER - Todos los Beeps han muerto")


func _on_victory() -> void:
	current_state = GameState.VICTORY
	print("VICTORIA - La colonia alcanzó %d Beeps!" % GameConfig.WIN_POPULATION)
