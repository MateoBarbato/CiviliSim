extends Panel

## NOTE: This script is attached inline in Main.tscn, NOT from decision_panel.tscn.
## The node tree in Main.tscn is: DecisionPanel -> DecisionMargin/DecisionVBox/EventLabel, OptionsContainer, ChatScroll/ChatLog
@onready var event_label: Label = $DecisionMargin/DecisionVBox/EventLabel
@onready var options_container: VBoxContainer = $DecisionMargin/DecisionVBox/OptionsContainer
@onready var chat_log: RichTextLabel = $DecisionMargin/DecisionVBox/ChatScroll/ChatLog

var _decision_system: Node
var _chat_messages: Array[String] = []
const MAX_CHAT_LINES: int = 50
var current_event: Dictionary = {}
var panel_visible_state: bool = false
var _bind_retry_timer: float = 0.0


func _ready() -> void:
	chat_log.bbcode_enabled = false
	chat_log.text = ""
	call_deferred("_try_bind_decision_system")


func _process(delta: float) -> void:
	if _decision_system != null:
		return
	_bind_retry_timer += delta
	if _bind_retry_timer >= 0.5:
		_bind_retry_timer = 0.0
		_try_bind_decision_system()


func _try_bind_decision_system() -> void:
	if _decision_system != null:
		return
	_decision_system = _get_decision_system()
	if _decision_system:
		_decision_system.decision_event_triggered.connect(_on_decision_event_triggered)
		_decision_system.decision_resolved.connect(_on_decision_resolved)
		_decision_system.decision_timed_out.connect(_on_decision_timed_out)
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


func _chat(message: String, color: Color = Color(0.85, 0.85, 0.9)) -> void:
	if chat_log == null:
		return
	var time_str = ""
	if _decision_system:
		var gt = ColonyManager.game_time
		var mins = int(gt / 60.0)
		var secs = int(gt) % 60
		time_str = "[%02d:%02d] " % [mins, secs]
	chat_log.text += time_str + message + "\n"
	chat_log.scroll_to_line(chat_log.get_line_count() - 1)


func _on_decision_event_triggered(event: Dictionary) -> void:
	current_event = event
	event_label.text = event["description"]
	event_label.visible = true
	_clear_options()
	_populate_options(event["options"])
	_chat("🔔 Decision Event: " + event["description"], Color(1.0, 0.7, 0.3))


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _populate_options(options: Array) -> void:
	for i in range(options.size()):
		var option = options[i]
		var button = _create_option_button(i + 1, option["text"])
		options_container.add_child(button)


func _create_option_button(num: int, text: String) -> Button:
	var button = Button.new()
	button.text = "[%d] %s" % [num, text]
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(0, 30)
	button.pressed.connect(_on_option_selected.bind(num))
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.35, 0.95)
	hover.border_color = Color(0.6, 0.6, 0.8)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	button.add_theme_stylebox_override("hover", hover)
	
	return button


func _on_option_selected(option_num: int) -> void:
	if _decision_system and _decision_system.is_event_active:
		var options = current_event.get("options", [])
		if option_num > 0 and option_num <= options.size():
			var selected = options[option_num - 1]
			_chat("➤ Decisión: " + selected["text"], Color(0.4, 0.9, 0.6))
			_decision_system.resolve_decision(selected["id"])


func _on_decision_resolved(_option_id: String) -> void:
	_chat("✅ Decision resolved: " + _option_id, Color(0.5, 0.9, 0.5))
	_clear_options()
	event_label.visible = false


func _on_decision_timed_out() -> void:
	_clear_options()
	event_label.visible = false
	_chat("⏰ Decision timed out - applying default effects", Color(0.9, 0.4, 0.4))
