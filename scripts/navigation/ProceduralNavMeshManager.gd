# ==============================================================================
# ProceduralNavMeshManager.gd - Navigation Mesh Dynamique
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Baking dynamique de NavMesh pour monde procédural.
# Gestion multi-couche, évitement de foule, régions.
# ==============================================================================

extends Node3D
class_name ProceduralNavMeshManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal navmesh_baking_started(region_id: String)
signal navmesh_baking_completed(region_id: String)
signal navmesh_region_added(region: NavigationRegion3D)
signal navmesh_region_removed(region_id: String)
signal path_calculated(path: PackedVector3Array)
signal agent_registered(agent_id: int)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("NavMesh Settings")
@export var cell_size: float = 0.25
@export var cell_height: float = 0.2
@export var agent_height: float = 2.0
@export var agent_radius: float = 0.5
@export var agent_max_climb: float = 0.5
@export var agent_max_slope: float = 45.0

@export_group("Baking")
@export var async_baking: bool = true
@export var bake_padding: float = 2.0
@export var max_concurrent_bakes: int = 2

@export_group("Performance")
@export var rebake_distance_threshold: float = 50.0
@export var update_interval: float = 0.5

# ==============================================================================
# VARIABLES
# ==============================================================================

## Régions de navigation par chunk_id
var _nav_regions: Dictionary = {}  # chunk_id -> NavigationRegion3D

## Queue de baking
var _baking_queue: Array[Dictionary] = []
var _active_bakes: int = 0

## Agents enregistrés
var _navigation_agents: Dictionary = {}  # agent_id -> NavigationAgent3D

## Cache des paths
var _path_cache: Dictionary = {}  # hash -> path
var _path_cache_timeout: float = 2.0

## Timer pour updates
var _update_timer: float = 0.0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	# S'assurer que le serveur de navigation est configuré
	_configure_navigation_server()


func _configure_navigation_server() -> void:
	"""Configure le serveur de navigation global."""
	var map_rid := get_world_3d().navigation_map
	
	NavigationServer3D.map_set_cell_size(map_rid, cell_size)
	NavigationServer3D.map_set_cell_height(map_rid, cell_height)
	NavigationServer3D.map_set_edge_connection_margin(map_rid, agent_radius)
	NavigationServer3D.map_set_link_connection_radius(map_rid, agent_radius * 2)


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	_update_timer += delta
	
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_process_baking_queue()
		_cleanup_path_cache()


# ==============================================================================
# CRÉATION DE RÉGIONS NAVMESH
# ==============================================================================

func create_navmesh_for_chunk(chunk_id: String, chunk_node: Node3D, layer: int = 0) -> void:
	"""Crée un NavMesh pour un chunk généré."""
	if _nav_regions.has(chunk_id):
		return  # Déjà existant
	
	# Créer la région de navigation
	var nav_region := NavigationRegion3D.new()
	nav_region.name = "NavRegion_%s" % chunk_id
	
	# Configurer le mesh de navigation
	var nav_mesh := NavigationMesh.new()
	_configure_navmesh(nav_mesh, layer)
	nav_region.navigation_mesh = nav_mesh
	
	# Ajouter au chunk
	chunk_node.add_child(nav_region)
	_nav_regions[chunk_id] = nav_region
	
	navmesh_region_added.emit(nav_region)
	
	# Queue le baking
	_queue_baking(chunk_id, nav_region)


func _configure_navmesh(nav_mesh: NavigationMesh, layer: int) -> void:
	"""Configure les paramètres du NavMesh selon la couche."""
	nav_mesh.cell_size = cell_size
	nav_mesh.cell_height = cell_height
	nav_mesh.agent_height = agent_height
	nav_mesh.agent_radius = agent_radius
	nav_mesh.agent_max_climb = agent_max_climb
	nav_mesh.agent_max_slope = agent_max_slope
	
	# Géométrie à parser
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	
	# Ajustements par couche verticale
	match layer:
		0:  # Corporate Tower
			nav_mesh.agent_max_slope = 30.0  # Sols plus plats
		1:  # Living City
			nav_mesh.agent_max_climb = 0.7  # Plus d'escaliers
		2:  # Dead Ground
			nav_mesh.agent_max_slope = 50.0  # Terrain accidenté
		3:  # Sub-Network
			nav_mesh.agent_height = 1.5  # Tunnels bas


func remove_navmesh_for_chunk(chunk_id: String) -> void:
	"""Retire le NavMesh d'un chunk."""
	if not _nav_regions.has(chunk_id):
		return
	
	var nav_region: NavigationRegion3D = _nav_regions[chunk_id]
	if is_instance_valid(nav_region):
		nav_region.queue_free()
	
	_nav_regions.erase(chunk_id)
	navmesh_region_removed.emit(chunk_id)


# ==============================================================================
# BAKING ASYNCHRONE
# ==============================================================================

func _queue_baking(chunk_id: String, nav_region: NavigationRegion3D) -> void:
	"""Ajoute un baking à la queue."""
	_baking_queue.append({
		"chunk_id": chunk_id,
		"region": nav_region,
		"priority": 0
	})
	
	navmesh_baking_started.emit(chunk_id)


func _process_baking_queue() -> void:
	"""Traite la queue de baking."""
	while _active_bakes < max_concurrent_bakes and not _baking_queue.is_empty():
		var bake_request: Dictionary = _baking_queue.pop_front()
		_start_baking(bake_request)


func _start_baking(bake_request: Dictionary) -> void:
	"""Démarre le baking d'une région."""
	var nav_region: NavigationRegion3D = bake_request.region
	
	if not is_instance_valid(nav_region):
		return
	
	_active_bakes += 1
	
	if async_baking:
		# Baking en arrière-plan
		nav_region.bake_navigation_mesh.call_deferred()
		nav_region.bake_finished.connect(
			_on_baking_finished.bind(bake_request.chunk_id),
			CONNECT_ONE_SHOT
		)
	else:
		# Baking synchrone
		nav_region.bake_navigation_mesh()
		_on_baking_finished(bake_request.chunk_id)


func _on_baking_finished(chunk_id: String) -> void:
	"""Callback quand le baking est terminé."""
	_active_bakes -= 1
	navmesh_baking_completed.emit(chunk_id)


func rebake_region(chunk_id: String) -> void:
	"""Force le rebaking d'une région."""
	if not _nav_regions.has(chunk_id):
		return
	
	var nav_region: NavigationRegion3D = _nav_regions[chunk_id]
	_queue_baking(chunk_id, nav_region)


# ==============================================================================
# GESTION DES AGENTS
# ==============================================================================

func register_agent(agent: NavigationAgent3D) -> int:
	"""Enregistre un agent de navigation."""
	var agent_id := agent.get_instance_id()
	
	# Configurer l'agent
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.5
	agent.avoidance_enabled = true
	agent.radius = agent_radius
	agent.neighbor_distance = 5.0
	agent.max_neighbors = 10
	agent.time_horizon_agents = 1.0
	agent.time_horizon_obstacles = 0.5
	agent.max_speed = 5.0
	
	_navigation_agents[agent_id] = agent
	agent_registered.emit(agent_id)
	
	return agent_id


func unregister_agent(agent_id: int) -> void:
	"""Désenregistre un agent."""
	_navigation_agents.erase(agent_id)


func get_registered_agents() -> Array:
	"""Retourne tous les agents enregistrés."""
	return _navigation_agents.values()


# ==============================================================================
# CALCUL DE CHEMINS
# ==============================================================================

func calculate_path(from: Vector3, to: Vector3, use_cache: bool = true) -> PackedVector3Array:
	"""Calcule un chemin entre deux points."""
	var map_rid := get_world_3d().navigation_map
	
	# Vérifier le cache
	if use_cache:
		var cache_key := _get_path_cache_key(from, to)
		if _path_cache.has(cache_key):
			var cached: Dictionary = _path_cache[cache_key]
			if Time.get_ticks_msec() - cached.time < _path_cache_timeout * 1000:
				return cached.path
	
	# Calculer le chemin
	var path := NavigationServer3D.map_get_path(
		map_rid,
		from,
		to,
		true  # Optimiser le chemin
	)
	
	# Mettre en cache
	if use_cache and path.size() > 0:
		var cache_key := _get_path_cache_key(from, to)
		_path_cache[cache_key] = {
			"path": path,
			"time": Time.get_ticks_msec()
		}
	
	path_calculated.emit(path)
	return path


func _get_path_cache_key(from: Vector3, to: Vector3) -> String:
	"""Génère une clé de cache pour un chemin."""
	return "%d_%d_%d_%d_%d_%d" % [
		int(from.x), int(from.y), int(from.z),
		int(to.x), int(to.y), int(to.z)
	]


func _cleanup_path_cache() -> void:
	"""Nettoie le cache des chemins expirés."""
	var current_time := Time.get_ticks_msec()
	var to_remove := []
	
	for key in _path_cache.keys():
		if current_time - _path_cache[key].time > _path_cache_timeout * 1000:
			to_remove.append(key)
	
	for key in to_remove:
		_path_cache.erase(key)


func is_position_navigable(position: Vector3) -> bool:
	"""Vérifie si une position est navigable."""
	var map_rid := get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map_rid, position)
	return position.distance_to(closest) < agent_radius * 2


func get_closest_navigable_point(position: Vector3) -> Vector3:
	"""Retourne le point navigable le plus proche."""
	var map_rid := get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map_rid, position)


# ==============================================================================
# LIENS ENTRE COUCHES (ASCENSEURS, ESCALIERS)
# ==============================================================================

func create_navigation_link(from: Vector3, to: Vector3, bidirectional: bool = true) -> RID:
	"""Crée un lien de navigation entre deux points (ex: ascenseur)."""
	var map_rid := get_world_3d().navigation_map
	
	var link_rid := NavigationServer3D.link_create()
	NavigationServer3D.link_set_map(link_rid, map_rid)
	NavigationServer3D.link_set_start_position(link_rid, from)
	NavigationServer3D.link_set_end_position(link_rid, to)
	NavigationServer3D.link_set_bidirectional(link_rid, bidirectional)
	NavigationServer3D.link_set_enabled(link_rid, true)
	
	return link_rid


func remove_navigation_link(link_rid: RID) -> void:
	"""Supprime un lien de navigation."""
	NavigationServer3D.free_rid(link_rid)


# ==============================================================================
# OBSTACLES DYNAMIQUES
# ==============================================================================

func add_obstacle(obstacle_node: Node3D, radius: float, height: float) -> RID:
	"""Ajoute un obstacle dynamique (ex: véhicule, PNJ statique)."""
	var map_rid := get_world_3d().navigation_map
	
	var obstacle_rid := NavigationServer3D.obstacle_create()
	NavigationServer3D.obstacle_set_map(obstacle_rid, map_rid)
	NavigationServer3D.obstacle_set_position(obstacle_rid, obstacle_node.global_position)
	NavigationServer3D.obstacle_set_radius(obstacle_rid, radius)
	NavigationServer3D.obstacle_set_height(obstacle_rid, height)
	NavigationServer3D.obstacle_set_avoidance_enabled(obstacle_rid, true)
	
	return obstacle_rid


func update_obstacle_position(obstacle_rid: RID, position: Vector3) -> void:
	"""Met à jour la position d'un obstacle."""
	NavigationServer3D.obstacle_set_position(obstacle_rid, position)


func remove_obstacle(obstacle_rid: RID) -> void:
	"""Supprime un obstacle."""
	NavigationServer3D.free_rid(obstacle_rid)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_region_count() -> int:
	"""Retourne le nombre de régions."""
	return _nav_regions.size()


func get_agent_count() -> int:
	"""Retourne le nombre d'agents."""
	return _navigation_agents.size()


func get_baking_queue_size() -> int:
	"""Retourne la taille de la queue de baking."""
	return _baking_queue.size()


func is_baking() -> bool:
	"""Vérifie si du baking est en cours."""
	return _active_bakes > 0


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"regions": _nav_regions.size(),
		"agents": _navigation_agents.size(),
		"baking_queue": _baking_queue.size(),
		"active_bakes": _active_bakes,
		"cached_paths": _path_cache.size()
	}
