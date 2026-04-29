## Gestiona los roles especializados de los Beeps
## Autoload: BeepRole

extends Node

## Tipos de rol
enum Role {
	NONE,       # Sin asignar (bebés, sin rol aún)
	GATHERER,   # Recolector — prioriza comida y recursos
	BUILDER,    # Constructor — prioriza construcción
	EXPLORER,   # Explorador — prioriza descubrimiento
	GUARDIAN    # Guardián — resistente, base para defensa futura
}

## Señales
signal role_assigned(beep: Node, role: Role)
signal role_revoked(beep: Node)

## Timer para re-evaluar distribución
var _reassign_timer: float = 0.0

## Roles actuales por beep (instance_id -> Role)
var _beep_roles: Dictionary = {}


## --- API pública ---

func get_role(beep: Node) -> Role:
	var id: int = beep.get_instance_id()
	return _int_to_role(_beep_roles.get(id, 0))


func set_role(beep: Node, role: Role) -> void:
	var id: int = beep.get_instance_id()
	if role == Role.NONE:
		_beep_roles.erase(id)
		role_revoked.emit(beep)
	else:
		_beep_roles[id] = role
		role_assigned.emit(beep, role)


func has_role(beep: Node) -> bool:
	var id: int = beep.get_instance_id()
	return _beep_roles.has(id)


## Contar beeps por rol
func count_role(role: Role) -> int:
	var count: int = 0
	for r in _beep_roles.values():
		if r == role:
			count += 1
	return count


## Total de beeps con rol asignado
func count_assigned() -> int:
	return _beep_roles.size()


## Limpiar rol al morir
func clear_role(beep: Node) -> void:
	var id: int = beep.get_instance_id()
	_beep_roles.erase(id)


## --- Lógica de auto-asignación ---

## Se llama periódicamente para ajustar la distribución de roles según necesidades
func _process(delta: float) -> void:
	if not ColonyManager.game_active:
		return

	_reassign_timer += delta
	if _reassign_timer >= GameConfig.ROLE_REASSIGN_INTERVAL:
		_reassign_timer = 0.0
		_rebalance_roles()


func _rebalance_roles() -> void:
	var adults: Array = _get_adults_without_or_with_role()
	if adults.size() < GameConfig.ROLE_MIN_ADULTS:
		return

	var total: int = adults.size()
	var target_gatherer: int = int(total * GameConfig.ROLE_GATHERER_TARGET_PCT)
	var target_builder: int = int(total * GameConfig.ROLE_BUILDER_TARGET_PCT)
	var target_explorer: int = int(total * GameConfig.ROLE_EXPLORER_TARGET_PCT)
	var target_guardian: int = int(total * GameConfig.ROLE_GUARDIAN_TARGET_PCT)

	# Contar actuales (solo entre los adultos activos)
	var current_gatherer: int = 0
	var current_builder: int = 0
	var current_explorer: int = 0
	var current_guardian: int = 0
	var unassigned: Array = []

	for beep: Node in adults:
		match get_role(beep):
			Role.GATHERER: current_gatherer += 1
			Role.BUILDER: current_builder += 1
			Role.EXPLORER: current_explorer += 1
			Role.GUARDIAN: current_guardian += 1
			_: unassigned.append(beep)

	# Barajar no-asignados para variedad
	unassigned.shuffle()

	# Asignar faltantes
	var idx: int = 0
	while idx < unassigned.size():
		var beep: Node = unassigned[idx]
		var assigned: bool = false

		if current_gatherer < target_gatherer:
			set_role(beep, Role.GATHERER)
			current_gatherer += 1
			assigned = true
		elif current_builder < target_builder:
			set_role(beep, Role.BUILDER)
			current_builder += 1
			assigned = true
		elif current_explorer < target_explorer:
			set_role(beep, Role.EXPLORER)
			current_explorer += 1
			assigned = true
		elif current_guardian < target_guardian:
			set_role(beep, Role.GUARDIAN)
			current_guardian += 1
			assigned = true

		if not assigned:
			break
		idx += 1


## Devuelve los beeps adultos (sin importar si tienen rol o no)
func _get_adults_without_or_with_role() -> Array:
	var result: Array = []
	for beep: Node in ColonyManager.beeps:
		if beep == null or beep.is_queued_for_deletion():
			continue
		if not beep.has_method("stats") or beep.stats == null:
			continue
		if beep.stats.is_adult():
			result.append(beep)
	return result


## --- Utilidades ---

static func role_name(role: Role) -> String:
	match role:
		Role.NONE: return "—"
		Role.GATHERER: return "Recolector"
		Role.BUILDER: return "Constructor"
		Role.EXPLORER: return "Explorador"
		Role.GUARDIAN: return "Guardián"
	return "?"


static func role_emoji(role: Role) -> String:
	match role:
		Role.NONE: return ""
		Role.GATHERER: return "🌾"
		Role.BUILDER: return "🔨"
		Role.EXPLORER: return "🧭"
		Role.GUARDIAN: return "🛡️"
	return ""


## Helper: el valor del enum es directamente int
## Role.NONE == 0, Role.GATHERER == 1, etc.
func _int_to_role(value: int) -> Role:
	match value:
		0: return Role.NONE
		1: return Role.GATHERER
		2: return Role.BUILDER
		3: return Role.EXPLORER
		4: return Role.GUARDIAN
		_: return Role.NONE


func reset() -> void:
	_beep_roles.clear()
	_reassign_timer = 0.0
