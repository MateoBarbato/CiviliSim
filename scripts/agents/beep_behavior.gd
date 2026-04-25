## Wrapper del Behavior Tree del Beep
## Instancia y ejecuta el Behavior Tree en C#

class_name BeepBehavior
extends Node

## Referencia al BeepAgent padre
@onready var beep_agent: BeepAgent = get_parent() as BeepAgent
@onready var stats: BeepStats = get_parent().get_node("BeepStats")

## Behavior Tree Engine (C#)
var _behavior_tree: Object = null

## Pathfinding instance (C#)
var _pathfinder: Object = null


func _ready() -> void:
	_initialize_behavior_tree()


func _process(delta: float) -> void:
	if not stats.is_alive():
		return
	
	if _behavior_tree != null:
		_behavior_tree.Tick(delta)


func _initialize_behavior_tree() -> void:
	var builder = _create_beep_behavior_builder()
	if builder == null:
		push_warning("No se pudo crear BeepBehaviorBuilder (¿C# compilado?)")
		return
	
	var root_node = builder.Build()
	_behavior_tree = load("res://scripts/core/BehaviorTree.cs").new()
	_behavior_tree.Initialize(root_node, 0.5)


func _create_beep_behavior_builder() -> Object:
	var builder_type = load("res://scripts/core/BeepBehaviorBuilder.cs")
	if builder_type == null:
		return null
	
	var builder = builder_type.new()
	builder._init(beep_agent)
	return builder


func _evaluate_behavior_tree() -> void:
	if _behavior_tree:
		_behavior_tree.Tick(1.0 / 60.0)


func reset() -> void:
	if _behavior_tree:
		_behavior_tree.Reset()


func stop() -> void:
	if _behavior_tree:
		_behavior_tree.Stop()


func set_blackboard(key: String, value: Variant) -> void:
	if _behavior_tree:
		_behavior_tree.SetBlackboard(key, value)


func get_blackboard(key: String) -> Variant:
	if _behavior_tree:
		return _behavior_tree.GetBlackboard(key)
	return null
