# ==============================================================================
# CrowdAvoidanceSystem.gd - Évitement de Foule Intelligent
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gestion RVO (Reciprocal Velocity Obstacles) pour éviter collisions.
# Optimisé pour couloirs étroits des bidonvilles.
# ==============================================================================

extends Node
class_name CrowdAvoidanceSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal crowd_density_changed(position: Vector3, density: float)
signal bottleneck_detected(position: Vector3)
signal agent_stuck(agent: NavigationAgent3D)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Avoidance")
@export var avoidance_radius: float = 1.5
@export var time_horizon: float = 2.0
@export var max_speed: float = 5.0

@export_group("Crowd Sensing")
@export var sensing_radius: float = 10.0
@export var high_density_threshold: int = 5

@export_group("Bottleneck Detection")
@export var bottleneck_check_interval: float = 1.0
@export var stuck_velocity_threshold: float = 0.1
@export var stuck_time_threshold: float = 3.0

# ==============================================================================
# VARIABLES
# ==============================================================================

var _agents: Array[NavigationAgent3D] = []
var _agent_velocities: Dictionary = {}  # agent_id -> Vector3
var _agent_stuck_timers: Dictionary = {}  # agent_id -> float
var _bottleneck_positions: Array[Vector3] = []
var _check_timer: float = 0.0

# ==============================================================================
# PROCESS
# ==============================================================================

func _physics_process(delta: float) -> void:
	_update_avoidance_velocities(delta)
	
	_check_timer += delta
	if _check_timer >= bottleneck_check_interval:
		_check_timer = 0.0
		_detect_bottlenecks()
		_check_stuck_agents(delta)


# ==============================================================================
# GESTION DES AGENTS
# ==============================================================================

func register_agent(agent: NavigationAgent3D) -> void:
	"""Enregistre un agent pour l'évitement."""
	if agent in _agents:
		return
	
	_agents.append(agent)
	_agent_velocities[agent.get_instance_id()] = Vector3.ZERO
	_agent_stuck_timers[agent.get_instance_id()] = 0.0
	
	# Configurer l'agent pour l'évitement
	agent.avoidance_enabled = true
	agent.radius = avoidance_radius
	agent.time_horizon_agents = time_horizon
	agent.max_speed = max_speed
	agent.neighbor_distance = sensing_radius
	agent.max_neighbors = 10


func unregister_agent(agent: NavigationAgent3D) -> void:
	"""Désenregistre un agent."""
	var idx := _agents.find(agent)
	if idx >= 0:
		_agents.remove_at(idx)
	
	var agent_id := agent.get_instance_id()
	_agent_velocities.erase(agent_id)
	_agent_stuck_timers.erase(agent_id)


# ==============================================================================
# CALCUL D'ÉVITEMENT RVO
# ==============================================================================

func _update_avoidance_velocities(delta: float) -> void:
	"""Met à jour les vélocités d'évitement pour tous les agents."""
	for agent in _agents:
		if not is_instance_valid(agent):
			continue
		
		var agent_id := agent.get_instance_id()
		var desired_velocity: Vector3 = agent.velocity
		
		# Calculer la vélocité d'évitement
		var avoidance_velocity := _calculate_rvo_velocity(agent, desired_velocity)
		
		# Stocker pour tracking
		_agent_velocities[agent_id] = avoidance_velocity


func _calculate_rvo_velocity(agent: NavigationAgent3D, desired_velocity: Vector3) -> Vector3:
	"""Calcule la vélocité RVO pour un agent."""
	var agent_position: Vector3 = agent.get_parent().global_position if agent.get_parent() else Vector3.ZERO
	var nearby_agents := _get_nearby_agents(agent, agent_position)
	
	if nearby_agents.is_empty():
		return desired_velocity
	
	var avoidance := Vector3.ZERO
	
	for other in nearby_agents:
		if not is_instance_valid(other):
			continue
		
		var other_pos: Vector3 = other.get_parent().global_position if other.get_parent() else Vector3.ZERO
		var relative_pos := other_pos - agent_position
		var distance := relative_pos.length()
		
		if distance < 0.01:
			continue
		
		var direction := relative_pos.normalized()
		
		# Force d'évitement inversement proportionnelle à la distance
		var strength := 1.0 - (distance / sensing_radius)
		strength = clampf(strength, 0.0, 1.0)
		
		avoidance -= direction * strength * max_speed * 0.5
	
	# Combiner avec la vélocité désirée
	var result := desired_velocity + avoidance
	
	# Limiter à la vitesse max
	if result.length() > max_speed:
		result = result.normalized() * max_speed
	
	return result


func _get_nearby_agents(agent: NavigationAgent3D, position: Vector3) -> Array[NavigationAgent3D]:
	"""Récupère les agents à proximité."""
	var nearby: Array[NavigationAgent3D] = []
	
	for other in _agents:
		if other == agent:
			continue
		
		if not is_instance_valid(other):
			continue
		
		var other_pos: Vector3 = other.get_parent().global_position if other.get_parent() else Vector3.ZERO
		if position.distance_to(other_pos) <= sensing_radius:
			nearby.append(other)
	
	return nearby


# ==============================================================================
# DÉTECTION DE GOULOTS D'ÉTRANGLEMENT
# ==============================================================================

func _detect_bottlenecks() -> void:
	"""Détecte les zones de congestion."""
	_bottleneck_positions.clear()
	
	# Grouper les agents par position approximative
	var position_clusters: Dictionary = {}
	var grid_size := 5.0
	
	for agent in _agents:
		if not is_instance_valid(agent):
			continue
		
		var pos: Vector3 = agent.get_parent().global_position if agent.get_parent() else Vector3.ZERO
		var grid_key := "%d_%d" % [int(pos.x / grid_size), int(pos.z / grid_size)]
		
		if not position_clusters.has(grid_key):
			position_clusters[grid_key] = {
				"count": 0,
				"center": Vector3.ZERO
			}
		
		position_clusters[grid_key].count += 1
		position_clusters[grid_key].center += pos
	
	# Identifier les goulots
	for key in position_clusters.keys():
		var cluster: Dictionary = position_clusters[key]
		if cluster.count >= high_density_threshold:
			var center: Vector3 = cluster.center / cluster.count
			_bottleneck_positions.append(center)
			bottleneck_detected.emit(center)
			crowd_density_changed.emit(center, float(cluster.count))


func get_crowd_density_at(position: Vector3) -> float:
	"""Retourne la densité de foule à une position."""
	var count := 0
	
	for agent in _agents:
		if not is_instance_valid(agent):
			continue
		
		var agent_pos: Vector3 = agent.get_parent().global_position if agent.get_parent() else Vector3.ZERO
		if position.distance_to(agent_pos) <= sensing_radius:
			count += 1
	
	return float(count) / high_density_threshold


func is_bottleneck(position: Vector3) -> bool:
	"""Vérifie si une position est un goulot."""
	for bottleneck in _bottleneck_positions:
		if position.distance_to(bottleneck) < sensing_radius:
			return true
	return false


# ==============================================================================
# DÉTECTION D'AGENTS BLOQUÉS
# ==============================================================================

func _check_stuck_agents(delta: float) -> void:
	"""Vérifie si des agents sont bloqués."""
	for agent in _agents:
		if not is_instance_valid(agent):
			continue
		
		var agent_id := agent.get_instance_id()
		var velocity: Vector3 = _agent_velocities.get(agent_id, Vector3.ZERO)
		
		if velocity.length() < stuck_velocity_threshold:
			_agent_stuck_timers[agent_id] = _agent_stuck_timers.get(agent_id, 0.0) + delta
			
			if _agent_stuck_timers[agent_id] >= stuck_time_threshold:
				agent_stuck.emit(agent)
				_agent_stuck_timers[agent_id] = 0.0  # Reset
		else:
			_agent_stuck_timers[agent_id] = 0.0


func unstick_agent(agent: NavigationAgent3D) -> void:
	"""Tente de débloquer un agent."""
	if not is_instance_valid(agent):
		return
	
	var parent := agent.get_parent()
	if not parent:
		return
	
	# Trouver une position alternative
	var current_pos: Vector3 = parent.global_position
	var alternatives := [
		current_pos + Vector3(2, 0, 0),
		current_pos + Vector3(-2, 0, 0),
		current_pos + Vector3(0, 0, 2),
		current_pos + Vector3(0, 0, -2)
	]
	
	for alt in alternatives:
		if ProceduralNavMeshManager and ProceduralNavMeshManager.has_method("is_position_navigable"):
			if ProceduralNavMeshManager.is_position_navigable(alt):
				parent.global_position = alt
				break


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_agent_count() -> int:
	"""Retourne le nombre d'agents."""
	return _agents.size()


func get_bottleneck_count() -> int:
	"""Retourne le nombre de goulots."""
	return _bottleneck_positions.size()


func get_bottleneck_positions() -> Array[Vector3]:
	"""Retourne les positions des goulots."""
	return _bottleneck_positions


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"agents": _agents.size(),
		"bottlenecks": _bottleneck_positions.size(),
		"average_density": _calculate_average_density()
	}


func _calculate_average_density() -> float:
	"""Calcule la densité moyenne."""
	if _agents.is_empty():
		return 0.0
	
	var total_density := 0.0
	for agent in _agents:
		if is_instance_valid(agent):
			var pos: Vector3 = agent.get_parent().global_position if agent.get_parent() else Vector3.ZERO
			total_density += get_crowd_density_at(pos)
	
	return total_density / _agents.size()
