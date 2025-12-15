# ==============================================================================
# SubNetworkGenerator.gd - Générateur du Sous-Réseau (Souterrain)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère le biome souterrain: métro abandonné, serveurs, sanctuaires IA
# ==============================================================================

extends Node3D
class_name SubNetworkGenerator

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal generation_complete(segment_count: int)
signal secret_found(secret_type: String, position: Vector3)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Dimensions")
@export var zone_width: float = 250.0
@export var zone_depth: float = 250.0
@export var tunnel_depth: float = -80.0  ## Profondeur Y principale

@export_group("Métro Abandonné")
@export var tunnel_prefab: PackedScene
@export var station_prefab: PackedScene
@export var tunnel_segments: int = 20
@export var stations_count: int = 4
@export var train_wreck_prefab: PackedScene

@export_group("Serveurs Oubliés")
@export var server_room_prefab: PackedScene
@export var server_rack_prefabs: Array[PackedScene] = []
@export var server_rooms_count: int = 6
@export var data_terminal_prefab: PackedScene

@export_group("Sanctuaires IA")
@export var ai_shrine_prefab: PackedScene
@export var ai_core_prefab: PackedScene
@export var shrine_count: int = 3

@export_group("Marchés d'Organes")
@export var organ_market_prefab: PackedScene
@export var organ_stall_prefabs: Array[PackedScene] = []
@export var organ_markets_count: int = 2

@export_group("Dangers")
@export var collapsed_section_prefab: PackedScene
@export var rogue_ai_spawner_prefab: PackedScene
@export var hazard_prefabs: Array[PackedScene] = []

@export_group("Ambiance")
@export var pipe_prefabs: Array[PackedScene] = []
@export var debris_prefabs: Array[PackedScene] = []
@export var light_prefab: PackedScene

# ==============================================================================
# VARIABLES
# ==============================================================================

var _rng := RandomNumberGenerator.new()
var _structures: Array[Node3D] = []
var _tunnel_nodes: Array[Vector3] = []  # Points du réseau de tunnels
var _secrets: Dictionary = {}  # {type: Array[Node3D]}

# ==============================================================================
# GÉNÉRATION
# ==============================================================================

func _ready() -> void:
	_rng.randomize()


func generate(seed_value: int = 0) -> void:
	"""Génère le Sous-Réseau complet."""
	if seed_value != 0:
		_rng.seed = seed_value
	
	_clear_existing()
	
	# Réseau de tunnels
	_generate_tunnel_network()
	_generate_metro_stations()
	
	# Zones spéciales
	_generate_server_rooms()
	_generate_ai_shrines()
	_generate_organ_markets()
	
	# Ambiance et dangers
	_generate_debris_and_pipes()
	_generate_hazards()
	
	generation_complete.emit(_tunnel_nodes.size())


func _clear_existing() -> void:
	"""Supprime les structures existantes."""
	for structure in _structures:
		if is_instance_valid(structure):
			structure.queue_free()
	_structures.clear()
	_tunnel_nodes.clear()
	_secrets.clear()


# ==============================================================================
# RÉSEAU DE TUNNELS
# ==============================================================================

func _generate_tunnel_network() -> void:
	"""Génère le réseau de tunnels de métro abandonné."""
	if not tunnel_prefab:
		return
	
	# Créer une grille de points de tunnel
	var grid_spacing := zone_width / 5.0
	
	for x in range(5):
		for z in range(5):
			var node_pos := Vector3(
				x * grid_spacing + grid_spacing / 2 + _rng.randf_range(-10, 10),
				tunnel_depth + _rng.randf_range(-5, 5),
				z * grid_spacing + grid_spacing / 2 + _rng.randf_range(-10, 10)
			)
			_tunnel_nodes.append(node_pos)
	
	# Connecter les nœuds adjacents
	for i in range(_tunnel_nodes.size()):
		var node_a := _tunnel_nodes[i]
		
		# Connecter aux voisins
		for j in range(i + 1, _tunnel_nodes.size()):
			var node_b := _tunnel_nodes[j]
			var dist := node_a.distance_to(node_b)
			
			# Connecter si assez proche et avec probabilité
			if dist < grid_spacing * 1.8 and _rng.randf() < 0.7:
				_create_tunnel_segment(node_a, node_b)


func _create_tunnel_segment(start: Vector3, end: Vector3) -> void:
	"""Crée un segment de tunnel entre deux points."""
	var segment_length := 15.0
	var direction := (end - start).normalized()
	var total_length := start.distance_to(end)
	var segments := int(total_length / segment_length)
	
	for i in range(segments):
		var pos := start + direction * (i * segment_length + segment_length / 2)
		var tunnel := tunnel_prefab.instantiate() as Node3D
		tunnel.position = pos
		tunnel.look_at(pos + direction, Vector3.UP)
		
		# Variation aléatoire
		tunnel.rotation.z += _rng.randf_range(-0.05, 0.05)
		
		add_child(tunnel)
		_structures.append(tunnel)
	
	# Ajouter occasionnellement un train abandonné
	if _rng.randf() < 0.15 and train_wreck_prefab:
		var train_pos := (start + end) / 2
		var train := train_wreck_prefab.instantiate() as Node3D
		train.position = train_pos
		train.look_at(train_pos + direction, Vector3.UP)
		add_child(train)
		_structures.append(train)


func _generate_metro_stations() -> void:
	"""Génère des stations de métro abandonnées."""
	if not station_prefab:
		return
	
	# Placer des stations à certains nœuds
	var station_indices := []
	while station_indices.size() < min(stations_count, _tunnel_nodes.size()):
		var idx := _rng.randi() % _tunnel_nodes.size()
		if idx not in station_indices:
			station_indices.append(idx)
	
	for idx in station_indices:
		var pos := _tunnel_nodes[idx]
		var station := station_prefab.instantiate() as Node3D
		station.position = pos
		station.rotation.y = _rng.randf() * TAU
		add_child(station)
		_structures.append(station)


# ==============================================================================
# SERVEURS OUBLIÉS
# ==============================================================================

func _generate_server_rooms() -> void:
	"""Génère des salles de serveurs abandonnées."""
	if not server_room_prefab:
		return
	
	for i in range(server_rooms_count):
		var pos := _get_random_underground_position()
		
		var room := server_room_prefab.instantiate() as Node3D
		room.position = pos
		room.rotation.y = _rng.randf() * TAU
		add_child(room)
		_structures.append(room)
		
		# Ajouter des racks de serveurs
		_populate_server_room(pos)
		
		# Terminal de données (loot spécial)
		if data_terminal_prefab and _rng.randf() < 0.6:
			var terminal := data_terminal_prefab.instantiate() as Node3D
			terminal.position = pos + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
			add_child(terminal)
			_structures.append(terminal)
			_register_secret("data_terminal", terminal)
			secret_found.emit("data_terminal", terminal.position)


func _populate_server_room(center: Vector3) -> void:
	"""Remplit une salle de serveurs avec des racks."""
	if server_rack_prefabs.is_empty():
		return
	
	var rack_count := _rng.randi_range(4, 10)
	for i in range(rack_count):
		var offset := Vector3(
			_rng.randf_range(-8, 8),
			0,
			_rng.randf_range(-8, 8)
		)
		
		var rack := _instance_random(server_rack_prefabs)
		if rack:
			rack.position = center + offset
			rack.rotation.y = _rng.randf() * TAU
			add_child(rack)
			_structures.append(rack)


# ==============================================================================
# SANCTUAIRES IA
# ==============================================================================

func _generate_ai_shrines() -> void:
	"""Génère des sanctuaires dédiés aux IA rogue."""
	if not ai_shrine_prefab:
		return
	
	for i in range(shrine_count):
		var pos := _get_random_underground_position()
		pos.y -= 10  # Plus profond
		
		var shrine := ai_shrine_prefab.instantiate() as Node3D
		shrine.position = pos
		add_child(shrine)
		_structures.append(shrine)
		_register_secret("ai_shrine", shrine)
		secret_found.emit("ai_shrine", pos)
		
		# Core IA au centre
		if ai_core_prefab:
			var core := ai_core_prefab.instantiate() as Node3D
			core.position = pos + Vector3(0, 2, 0)
			add_child(core)
			_structures.append(core)


# ==============================================================================
# MARCHÉS D'ORGANES
# ==============================================================================

func _generate_organ_markets() -> void:
	"""Génère les marchés noirs d'organes."""
	if not organ_market_prefab:
		return
	
	for i in range(organ_markets_count):
		var pos := _get_random_underground_position()
		
		var market := organ_market_prefab.instantiate() as Node3D
		market.position = pos
		market.rotation.y = _rng.randf() * TAU
		add_child(market)
		_structures.append(market)
		_register_secret("organ_market", market)
		secret_found.emit("organ_market", pos)
		
		# Étals autour
		if not organ_stall_prefabs.is_empty():
			var stall_count := _rng.randi_range(3, 6)
			for j in range(stall_count):
				var angle := (float(j) / stall_count) * TAU
				var stall_pos := pos + Vector3(cos(angle) * 8, 0, sin(angle) * 8)
				
				var stall := _instance_random(organ_stall_prefabs)
				if stall:
					stall.position = stall_pos
					stall.rotation.y = angle + PI
					add_child(stall)
					_structures.append(stall)


# ==============================================================================
# AMBIANCE & DANGERS
# ==============================================================================

func _generate_debris_and_pipes() -> void:
	"""Génère débris et tuyaux pour l'ambiance."""
	var debris_count := 100
	
	for i in range(debris_count):
		var pos := _get_random_underground_position()
		
		# Débris ou tuyau
		var prefabs := debris_prefabs if _rng.randf() < 0.7 else pipe_prefabs
		var obj := _instance_random(prefabs)
		if obj:
			obj.position = pos
			obj.rotation = Vector3(
				_rng.randf() * TAU,
				_rng.randf() * TAU,
				_rng.randf() * TAU
			)
			obj.scale = Vector3.ONE * _rng.randf_range(0.5, 2.0)
			add_child(obj)
			_structures.append(obj)
	
	# Éclairage sporadique
	if light_prefab:
		for node in _tunnel_nodes:
			if _rng.randf() < 0.3:
				var light := light_prefab.instantiate() as Node3D
				light.position = node + Vector3(0, 3, 0)
				add_child(light)
				_structures.append(light)


func _generate_hazards() -> void:
	"""Génère les zones dangereuses."""
	# Sections effondrées
	if collapsed_section_prefab:
		var collapse_count := _rng.randi_range(3, 6)
		for i in range(collapse_count):
			var pos := _get_random_underground_position()
			var collapse := collapsed_section_prefab.instantiate() as Node3D
			collapse.position = pos
			add_child(collapse)
			_structures.append(collapse)
	
	# Spawners d'IA rogue
	if rogue_ai_spawner_prefab:
		for i in range(5):
			var pos := _get_random_underground_position()
			var spawner := rogue_ai_spawner_prefab.instantiate() as Node3D
			spawner.position = pos
			add_child(spawner)
			_structures.append(spawner)
	
	# Autres dangers
	for prefab in hazard_prefabs:
		var count := _rng.randi_range(2, 5)
		for i in range(count):
			var pos := _get_random_underground_position()
			var hazard := prefab.instantiate() as Node3D
			hazard.position = pos
			add_child(hazard)
			_structures.append(hazard)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _get_random_underground_position() -> Vector3:
	"""Retourne une position aléatoire souterraine."""
	return Vector3(
		_rng.randf_range(20, zone_width - 20),
		tunnel_depth + _rng.randf_range(-20, 20),
		_rng.randf_range(20, zone_depth - 20)
	)


func _instance_random(prefabs: Array[PackedScene]) -> Node3D:
	"""Instancie un prefab aléatoire."""
	if prefabs.is_empty():
		return null
	var scene := prefabs[_rng.randi() % prefabs.size()]
	if scene:
		return scene.instantiate() as Node3D
	return null


func _register_secret(secret_type: String, node: Node3D) -> void:
	"""Enregistre un secret découvrable."""
	if not _secrets.has(secret_type):
		_secrets[secret_type] = []
	_secrets[secret_type].append(node)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_secrets_by_type(secret_type: String) -> Array:
	"""Retourne tous les secrets d'un type donné."""
	return _secrets.get(secret_type, [])


func get_all_secrets() -> Dictionary:
	"""Retourne tous les secrets."""
	return _secrets


func get_tunnel_nodes() -> Array[Vector3]:
	"""Retourne les nœuds du réseau de tunnels."""
	return _tunnel_nodes


func get_nearest_tunnel_node(position: Vector3) -> Vector3:
	"""Retourne le nœud de tunnel le plus proche."""
	var nearest := Vector3.ZERO
	var min_dist := INF
	
	for node in _tunnel_nodes:
		var dist := position.distance_to(node)
		if dist < min_dist:
			min_dist = dist
			nearest = node
	
	return nearest


func get_structure_count() -> int:
	"""Retourne le nombre de structures."""
	return _structures.size()
