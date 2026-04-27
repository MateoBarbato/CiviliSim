extends Node2D

const WORLD_SCENE = preload("res://scenes/world/world.tscn")

var world: WorldScene = null
@onready var game_viewport: SubViewport = $GameViewport
@onready var game_view: TextureRect = $GameView

@onready var food_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/FoodLabel
@onready var wood_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/WoodLabel
@onready var stone_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/StoneLabel
@onready var pop_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/PopLabel
@onready var happiness_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/HappinessLabel
@onready var health_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/HealthLabel
@onready var order_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/OrderLabel
@onready var time_label: Label = $Sidebar/StatsPanel/StatsMargin/StatsVBox/TimeLabel

enum GameState { PLAYING, PAUSED, GAME_OVER, VICTORY }
var current_state: GameState = GameState.PLAYING

var hud_update_timer: float = 0.0


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
	
	# Estilos sidebar
	_setup_sidebar_styles()
	
	# Iniciar juego con un delay breve
	await get_tree().create_timer(0.1).timeout
	start_game()


func _create_style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border != Color.TRANSPARENT:
		s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s


func _setup_sidebar_styles() -> void:
	$Sidebar.add_theme_stylebox_override("panel", _create_style(Color(0.08, 0.08, 0.1)))
	$Sidebar/StatsPanel.add_theme_stylebox_override("panel", _create_style(Color(0.12, 0.12, 0.15), Color(0.25, 0.25, 0.3)))
	$Sidebar/DecisionPanel.add_theme_stylebox_override("panel", _create_style(Color(0.12, 0.12, 0.15), Color(0.25, 0.25, 0.3)))


func _process(delta: float) -> void:
	hud_update_timer += delta
	if hud_update_timer >= 0.5:
		hud_update_timer = 0.0
		_update_hud()


func _update_hud() -> void:
	var state = ResourceManager.get_resource_state()
	food_label.text = "🍖 %d" % int(state["food"])
	wood_label.text = "🪵 %d" % int(state["wood"])
	stone_label.text = "🪨 %d" % int(state["stone"])
	pop_label.text = "👥 %d / %d" % [ColonyManager.population, GameConfig.REPRODUCTION_MAX_POPULATION]
	happiness_label.text = "😊 %.0f" % ColonyManager.happiness
	health_label.text = "❤️ %.0f" % ColonyManager.health_average
	order_label.text = "⚖️ %.0f" % ColonyManager.social_order
	
	var minutes = int(ColonyManager.game_time / 60.0)
	var seconds = int(ColonyManager.game_time) % 60
	time_label.text = "⏱ %02d:%02d" % [minutes, seconds]


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
