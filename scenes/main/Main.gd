extends Control

const WORLD_SCENE = preload("res://scenes/world/world.tscn")

var world: WorldScene = null
@onready var game_viewport: SubViewport = $SubViewportContainer/GameViewport

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
	
	
	
	# World dentro del SubViewport
	world = WORLD_SCENE.instantiate()
	game_viewport.add_child(world)
	
	# Estilos sidebar
	_setup_styles()
	
	await get_tree().create_timer(0.1).timeout
	start_game()


func _create_style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 6) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border != Color.TRANSPARENT:
		s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s


func _setup_styles() -> void:
	var stats_style = _create_style(Color(0.1, 0.1, 0.14), Color(0.3, 0.3, 0.4))
	$Sidebar/StatsPanel.add_theme_stylebox_override("panel", stats_style)
	
	var decision_style = _create_style(Color(0.1, 0.1, 0.14), Color(0.3, 0.3, 0.4))
	$Sidebar/DecisionPanel.add_theme_stylebox_override("panel", decision_style)


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
	# Redirigir input al SubViewport para cámara/beeps
	game_viewport.push_input(event)
	
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
	print("GAME OVER")


func _on_victory() -> void:
	current_state = GameState.VICTORY
	print("VICTORIA")
