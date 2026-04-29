extends Panel

## Panel de decisiones con preview de efectos, cadena de eventos, 
## barra de urgencia/tiempo, y efectos persistentes activos.

@onready var decision_margin: MarginContainer = $DecisionMargin
@onready var decision_vbox: VBoxContainer = $DecisionMargin/DecisionVBox
@onready var event_label: Label = $DecisionMargin/DecisionVBox/EventLabel
@onready var options_container: VBoxContainer = $DecisionMargin/DecisionVBox/OptionsContainer
@onready var chat_log: RichTextLabel = $DecisionMargin/DecisionVBox/ChatScroll/ChatLog

## --- Nodes creados en runtime ---
var _urgency_bar_container: HBoxContainer
var _urgency_bar: ProgressBar
var _timer_bar: ProgressBar
var _chain_indicator: Label
var _persistent_effects_container: HBoxContainer
var _effects_preview_label: Label

var _decision_system: Node
var current_event: Dictionary = {}
var panel_visible_state: bool = false
var _bind_retry_timer: float = 0.0

## --- Efectos persistentes activos ---
var _active_persistent_effects: Array[Dictionary] = []


func _ready() -> void:
	chat_log.bbcode_enabled = true
	chat_log.text = ""
	_create_ui_elements()
	_setup_persistent_effects_ui()
	call_deferred("_try_bind_decision_system")


func _create_ui_elements() -> void:
	## Urgency bar (barra roja sobre el evento)
	_urgency_bar_container = HBoxContainer.new()
	_urgency_bar_container.layout_mode = 1  # PARENT
	_urgency_bar_container.add_theme_constant_override("separation", 6)
	
	var urgency_label = Label.new()
	urgency_label.text = "⚠ URGENCIA"
	urgency_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_urgency_bar_container.add_child(urgency_label)
	
	_urgency_bar = ProgressBar.new()
	_urgency_bar.value = 0.0
	_urgency_bar.max_value = 100.0
	_urgency_bar.show_percentage = false
	_urgency_bar.size_flags_horizontal = Control.SIZE_FILL
	_urgency_bar.custom_minimum_size = Vector2(0, 8)
	_setup_progress_bar_style(_urgency_bar, Color(0.9, 0.3, 0.2))
	_urgency_bar_container.add_child(_urgency_bar)
	
	decision_vbox.add_child(_urgency_bar_container)
	_urgency_bar_container.visible = false

	## Timer bar (barra verde sobre las opciones)
	_timer_bar = ProgressBar.new()
	_timer_bar.value = 100.0
	_timer_bar.max_value = 100.0
	_timer_bar.show_percentage = false
	_timer_bar.size_flags_horizontal = Control.SIZE_FILL
	_timer_bar.custom_minimum_size = Vector2(0, 6)
	_setup_progress_bar_style(_timer_bar, Color(0.3, 0.8, 0.4))
	decision_vbox.add_child(_timer_bar)
	_timer_bar.visible = false

	## Chain indicator (pequeño texto "Paso 2/3 - Cadena: Food Crisis")
	_chain_indicator = Label.new()
	_chain_indicator.autowrap_mode = TextServer.AUTOWRAP_WORD
	_chain_indicator.visible = false
	_chain_indicator.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	decision_vbox.add_child(_chain_indicator)

	## Effects preview label (muestra "+15 food, -5 happiness")
	_effects_preview_label = Label.new()
	_effects_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_effects_preview_label.visible = false
	_effects_preview_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	_effects_preview_label.custom_minimum_size = Vector2(0, 20)
	decision_vbox.add_child(_effects_preview_label)


func _setup_persistent_effects_ui() -> void:
	## Contenedor de badges de efectos persistentes (siempre visible)
	_persistent_effects_container = HBoxContainer.new()
	_persistent_effects_container.layout_mode = 1  # PARENT
	_persistent_effects_container.add_theme_constant_override("separation", 4)
	_persistent_effects_container.visible = false
	decision_vbox.add_child(_persistent_effects_container)


func _setup_progress_bar_style(bar: ProgressBar, color: Color) -> void:
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	bg_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_style)


func _process(delta: float) -> void:
	if _decision_system != null:
		_update_timer_bar(delta)
		_update_persistent_effects_badges(delta)
		return
	_bind_retry_timer += delta
	if _bind_retry_timer >= 0.5:
		_bind_retry_timer = 0.0
		_try_bind_decision_system()


func _update_timer_bar(_delta: float) -> void:
	if not _decision_system or not _decision_system.is_event_active:
		return
	var pct: float = _decision_system.get_response_percentage()
	_timer_bar.value = maxf(0.0, 100.0 - pct)
	
	## Color dinámico: verde → amarillo → rojo
	if pct < 0.5:
		_timer_bar.get_theme_stylebox("fill").bg_color = Color(0.3, 0.8, 0.4)
	elif pct < 0.75:
		_timer_bar.get_theme_stylebox("fill").bg_color = Color(0.9, 0.7, 0.2)
	else:
		_timer_bar.get_theme_stylebox("fill").bg_color = Color(0.9, 0.3, 0.2)


func _update_persistent_effects_badges(_delta: float) -> void:
	if not _decision_system:
		return
	
	## Sincronizar con signals del DecisionSystem
	## (se actualiza cuando se emiten persistent_effect_added/removed)
	pass


func _try_bind_decision_system() -> void:
	if _decision_system != null:
		return
	_decision_system = _get_decision_system()
	if _decision_system:
		_decision_system.decision_event_triggered.connect(_on_decision_event_triggered)
		_decision_system.decision_resolved.connect(_on_decision_resolved)
		_decision_system.decision_timed_out.connect(_on_decision_timed_out)
		_decision_system.persistent_effect_added.connect(_on_persistent_effect_added)
		_decision_system.persistent_effect_removed.connect(_on_persistent_effect_removed)
		_chat("DecisionSystem conectado. Esperando eventos...", Color(0.4, 0.8, 0.4))


func _get_decision_system() -> Node:
	var scene_root = get_tree().current_scene
	if scene_root:
		var found = _search_node_by_name(scene_root, "DecisionSystem")
		if found:
			return found
	return null


func _search_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found = _search_node_by_name(child, target_name)
		if found:
			return found
	return null


## ============================================================
##  SIGNAL HANDLERS
## ============================================================

func _on_decision_event_triggered(event: Dictionary) -> void:
	current_event = event
	event_label.text = event["description"]
	event_label.visible = true
	
	## Urgency bar
	_urgency_bar.visible = true
	_urgency_bar_container.visible = true
	var urgency: float = event.get("urgency", 0.5)
	_urgency_bar.value = urgency * 100.0

	## Timer bar
	_timer_bar.visible = true
	
	## Chain indicator
	var chain_id: String = event.get("chain_id", "")
	if chain_id != "":
		var step: int = event.get("chain_step", 0)
		var total: int = event.get("chain_total", 0)
		_chain_indicator.text = "🔗 Paso %d/%d — %s" % [step, total, _chain_display_name(chain_id)]
		_chain_indicator.visible = true
	else:
		_chain_indicator.visible = false

	## Options con preview de efectos
	_clear_options()
	_populate_options_with_preview(event["options"])
	
	_chat("🔔 %s" % event["description"], Color(1.0, 0.7, 0.3))


func _on_option_selected(option_num: int) -> void:
	if _decision_system and _decision_system.is_event_active:
		var options = current_event.get("options", [])
		if option_num > 0 and option_num <= options.size():
			var selected = options[option_num - 1]
			_chat("➤ %s" % selected["text"], Color(0.4, 0.9, 0.6))
			_decision_system.resolve_decision(selected["id"])
			_effects_preview_label.visible = false


func _on_option_hovered(option: Dictionary, hovered: bool) -> void:
	if hovered:
		_show_effects_preview(option.get("effects", {}))
	else:
		_effects_preview_label.visible = false


func _show_effects_preview(effects: Dictionary) -> void:
	if effects.is_empty():
		_effects_preview_label.text = "(sin efectos)"
		_effects_preview_label.visible = true
		return

	var parts: Array[String] = []
	for key in effects:
		if key == "priority":
			parts.append("🎯 %s" % effects[key])
		elif key == "persistent_effect":
			var pe: Dictionary = effects[key]
			parts.append("💊 %s (%.0fs)" % [pe["name"], pe["duration"]])
		elif key == "action":
			continue  # acciones internas, no mostrar al jugador
		else:
			var val = effects[key]
			# Solo mostrar valores numéricos
			if not (val is int or val is float):
				continue
			var num_val: float = float(val)
			var icon: String
			match key:
				"food": icon = "🍖"
				"wood": icon = "🪵"
				"stone": icon = "🪨"
				"happiness": icon = "😊"
				"health": icon = "❤️"
				"social_order": icon = "⚖️"
				"knowledge": icon = "📖"
				_: icon = "?"
			var sign_str = "+" if num_val > 0 else ""
			parts.append("%s %s%d" % [icon, sign_str, int(num_val)])

	_effects_preview_label.text = "→ " + ", ".join(parts)
	_effects_preview_label.visible = true


func _on_decision_resolved(_option_id: String) -> void:
	_chat("✅ Decision resolved", Color(0.5, 0.9, 0.5))
	_clear_options()
	event_label.visible = false
	_urgency_bar.visible = false
	_urgency_bar_container.visible = false
	_timer_bar.visible = false
	_chain_indicator.visible = false
	_effects_preview_label.visible = false


func _on_decision_timed_out() -> void:
	_clear_options()
	event_label.visible = false
	_urgency_bar.visible = false
	_urgency_bar_container.visible = false
	_timer_bar.visible = false
	_chain_indicator.visible = false
	_effects_preview_label.visible = false
	_chat("⏰ Decision timed out", Color(0.9, 0.4, 0.4))


func _on_persistent_effect_added(effect_name: String, duration: float) -> void:
	_active_persistent_effects.append({"name": effect_name, "duration": duration, "remaining": duration})
	_update_persistent_badges()
	_chat("💊 Efecto activo: %s (%.0fs)" % [effect_name, duration], Color(0.6, 0.7, 1.0))


func _on_persistent_effect_removed(effect_name: String) -> void:
	for i in range(_active_persistent_effects.size()):
		if _active_persistent_effects[i]["name"] == effect_name:
			_active_persistent_effects.remove_at(i)
			break
	_update_persistent_badges()


func _update_persistent_badges() -> void:
	## Limpiar badges existentes
	for child in _persistent_effects_container.get_children():
		child.queue_free()

	if _active_persistent_effects.is_empty():
		_persistent_effects_container.visible = false
		return

	_persistent_effects_container.visible = true

	for eff in _active_persistent_effects:
		var badge = Label.new()
		var icon: String = "+" if _is_positive_effect(eff["name"]) else "-"
		badge.text = "%s %s" % [icon, _effect_short_name(eff["name"])]
		badge.custom_minimum_size = Vector2(0, 16)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.25, 0.35, 0.85)
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)
		style.border_color = Color(0.4, 0.5, 0.7)
		badge.add_theme_stylebox_override("normal", style)
		badge.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
		
		_persistent_effects_container.add_child(badge)


## ============================================================
##  OPTIONS BUILDING (con preview de efectos)
## ============================================================

func _populate_options_with_preview(options: Array) -> void:
	for i in range(options.size()):
		var option = options[i]
		
		## Contenedor para el botón + label de efectos
		var hbox = HBoxContainer.new()
		hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_theme_constant_override("separation", 4)
		
		var button = Button.new()
		button.text = "[%d] %s" % [i + 1, option["text"]]
		button.size_flags_horizontal = Control.SIZE_FILL
		button.custom_minimum_size = Vector2(0, 30)
		button.pressed.connect(_on_option_selected.bind(i + 1))
		
		## Estilos del botón
		_apply_button_styles(button)
		
		## Mouse enter/exit para preview
		button.mouse_entered.connect(_on_option_hovered.bind(option, true))
		button.mouse_exited.connect(_on_option_hovered.bind(option, false))
		
		hbox.add_child(button)
		options_container.add_child(hbox)


func _apply_button_styles(button: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	normal.border_color = Color(0.4, 0.4, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.35, 0.95)
	hover.border_color = Color(0.6, 0.6, 0.8)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", hover)
	
	var focus = StyleBoxFlat.new()
	focus.bg_color = Color(0.2, 0.3, 0.4, 0.95)
	focus.border_color = Color(0.5, 0.7, 1.0)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


## ============================================================
##  HELPERS
## ============================================================

func _chat(message: String, color: Color = Color(0.85, 0.85, 0.9)) -> void:
	if chat_log == null:
		return
	var time_str = ""
	if _decision_system:
		var gt = ColonyManager.game_time
		var mins = int(gt / 60.0)
		var secs = int(gt) % 60
		time_str = "[%02d:%02d] " % [mins, secs]
	chat_log.text += "[color=" + color.to_html() + "]" + time_str + message + "[/color]\n"
	chat_log.scroll_to_line(chat_log.get_line_count() - 1)


func _chain_display_name(chain_id: String) -> String:
	match chain_id:
		"food_crisis": return "Crisis de Comida"
		"population_explosion": return "Explosión Poblacional"
		"disease_outbreak": return "Brote de Enfermedad"
		"exploration_fever": return "Fiebre de Exploración"
		"building_expansion": return "Expansión de Edificios"
	return chain_id


func _effect_short_name(eff_name: String) -> String:
	match eff_name:
		"feast_bonus": return "Banquete"
		"rest_day_bonus": return "Descanso"
		"quarantine_bonus": return "Cuarentena"
		"exploration_bonus": return "Exploración"
		"research_bonus": return "Investigación"
		"famine_penalty": return "Hambruna"
		"disease_penalty": return "Enfermedad"
		"invasion_prepared": return "Defensa"
		"celebration_bonus": return "Celebración"
		"storm_damage": return "Tormenta"
		"winter_survival": return "Invierno"
		"diplomacy_bonus": return "Diplomacia"
	return eff_name


func _is_positive_effect(eff_name: String) -> bool:
	return eff_name.ends_with("_bonus")
