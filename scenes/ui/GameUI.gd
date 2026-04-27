extends CanvasLayer

@onready var root: Node2D = get_tree().root.get_child(0)
@onready var food_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/FoodLabel")
@onready var wood_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/WoodLabel")
@onready var stone_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/StoneLabel")
@onready var pop_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/PopLabel")
@onready var happiness_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/HappinessLabel")
@onready var health_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/HealthLabel")
@onready var order_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/OrderLabel")
@onready var time_label: Label = root.get_node("Sidebar/StatsPanel/StatsMargin/StatsVBox/TimeLabel")

var hud_update_timer: float = 0.0
const HUD_UPDATE_INTERVAL: float = 0.5


func _create_style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	if border != Color.TRANSPARENT:
		s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	return s


func _ready() -> void:
	# Estilos sidebar
	var sidebar = $Sidebar
	sidebar.add_theme_stylebox_override("panel", _create_style(Color(0.08, 0.08, 0.1)))
	
	# Estilos stats
	var stats = $Sidebar/StatsPanel
	stats.add_theme_stylebox_override("panel", _create_style(Color(0.12, 0.12, 0.15), Color(0.25, 0.25, 0.3)))
	
	# Estilos decision
	var decision = $Sidebar/DecisionPanel
	decision.add_theme_stylebox_override("panel", _create_style(Color(0.12, 0.12, 0.15), Color(0.25, 0.25, 0.3)))
	
	_update_hud()


func _process(delta: float) -> void:
	hud_update_timer += delta
	if hud_update_timer >= HUD_UPDATE_INTERVAL:
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
