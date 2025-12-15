# ==============================================================================
# DeadGroundGenerator.gd - Générateur du Sol Mort (Niveau 0)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère le biome du niveau 0: décharges, brume toxique, bidonvilles, gangs
# ==============================================================================

extends Node3D
class_name DeadGroundGenerator

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal generation_complete(structure_count: int)
signal structure_spawned(structure: Node3D, position: Vector3)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Taille de Zone")
@export var zone_width: float = 200.0
@export var zone_depth: float = 200.0
@export var cell_size: float = 15.0

@export_group("Décharges")
@export var dump_prefabs: Array[PackedScene] = []
@export var dump_density: float = 0.3
@export var debris_prefabs: Array[PackedScene] = []
@export var debris_per_dump: int = 8

@export_group("Bidonvilles")
@export var shanty_prefabs: Array[PackedScene] = []
@export var shanty_cluster_count: int = 5
@export var shanties_per_cluster: int = 8

@export_group("Marchés Gris")
@export var market_prefab: PackedScene
@export var market_stall_prefabs: Array[PackedScene] = []
@export var markets_count: int = 2

@export_group("Dangers")
@export var toxic_zone_prefab: PackedScene
@export var toxic_zone_count: int = 4
@export var radiation_prefab: PackedScene

@export_group("Spawn Ennemis")
@export var gang_spawn_points: int = 10
@export var enemy_spawn_prefab: PackedScene

# ==============================================================================
# VARIABLES
# ==============================================================================

var _rng := RandomNumberGenerator.new()
var _structures: Array[Node3D] = []
var _spawn_points: Array[Vector3] = []
var _occupied_cells: Dictionary = {}  # Vector2i -> bool

# ==============================================================================
# GÉNÉRATION
# ==============================================================================

func _ready() -> void:
	_rng.randomize()


func generate(seed_value: int = 0) -> void:
	"""Génère le niveau Sol Mort complet."""
	if seed_value != 0:
		_rng.seed = seed_value
	
	_clear_existing()
	
	# Étapes de génération
	_generate_dumps()
	_generate_shanty_clusters()
	_generate_gray_markets()
	_generate_toxic_zones()
	_generate_spawn_points()
	
	generation_complete.emit(_structures.size())


func _clear_existing() -> void:
	"""Supprime les structures existantes."""
	for structure in _structures:
		if is_instance_valid(structure):
			structure.queue_free()
	_structures.clear()
	_spawn_points.clear()
	_occupied_cells.clear()


# ==============================================================================
# DÉCHARGES
# ==============================================================================

func _generate_dumps() -> void:
	"""Génère les zones de décharge avec débris."""
	if dump_prefabs.is_empty():
		return
	
	var cells_x := int(zone_width / cell_size)
	var cells_z := int(zone_depth / cell_size)
	
	for x in range(cells_x):
		for z in range(cells_z):
			if _rng.randf() > dump_density:
				continue
			
			var cell := Vector2i(x, z)
			if _occupied_cells.has(cell):
				continue
			
			_occupied_cells[cell] = true
			var world_pos := _cell_to_world(x, z)
			
			# Placer la décharge principale
			var dump := _instance_random(dump_prefabs)
			if dump:
				dump.position = world_pos
				dump.rotation.y = _rng.randf() * TAU
				add_child(dump)
				_structures.append(dump)
				structure_spawned.emit(dump, world_pos)
			
			# Ajouter des débris autour
			_scatter_debris(world_pos)


func _scatter_debris(center: Vector3) -> void:
	"""Disperse des débris autour d'un point."""
	if debris_prefabs.is_empty():
		return
	
	for i in range(debris_per_dump):
		var offset := Vector3(
			_rng.randf_range(-cell_size * 0.4, cell_size * 0.4),
			0,
			_rng.randf_range(-cell_size * 0.4, cell_size * 0.4)
		)
		
		var debris := _instance_random(debris_prefabs)
		if debris:
			debris.position = center + offset
			debris.rotation.y = _rng.randf() * TAU
			debris.scale = Vector3.ONE * _rng.randf_range(0.5, 1.5)
			add_child(debris)
			_structures.append(debris)


# ==============================================================================
# BIDONVILLES
# ==============================================================================

func _generate_shanty_clusters() -> void:
	"""Génère des clusters de bidonvilles."""
	if shanty_prefabs.is_empty():
		return
	
	for i in range(shanty_cluster_count):
		var cluster_center := Vector3(
			_rng.randf_range(cell_size, zone_width - cell_size),
			0,
			_rng.randf_range(cell_size, zone_depth - cell_size)
		)
		
		_generate_shanty_cluster(cluster_center)


func _generate_shanty_cluster(center: Vector3) -> void:
	"""Génère un cluster de cabanes autour d'un centre."""
	var radius := cell_size * 2.0
	
	for i in range(shanties_per_cluster):
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(2.0, radius)
		var offset := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var pos := center + offset
		
		# Vérifier les limites
		if pos.x < 0 or pos.x > zone_width or pos.z < 0 or pos.z > zone_depth:
			continue
		
		var shanty := _instance_random(shanty_prefabs)
		if shanty:
			shanty.position = pos
			shanty.rotation.y = angle + _rng.randf_range(-0.3, 0.3)
			shanty.scale = Vector3.ONE * _rng.randf_range(0.8, 1.2)
			add_child(shanty)
			_structures.append(shanty)
			structure_spawned.emit(shanty, pos)


# ==============================================================================
# MARCHÉS GRIS
# ==============================================================================

func _generate_gray_markets() -> void:
	"""Génère les marchés clandestins."""
	for i in range(markets_count):
		var pos := Vector3(
			_rng.randf_range(zone_width * 0.2, zone_width * 0.8),
			0,
			_rng.randf_range(zone_depth * 0.2, zone_depth * 0.8)
		)
		
		_generate_market_area(pos)


func _generate_market_area(center: Vector3) -> void:
	"""Génère une zone de marché avec étals."""
	# Structure principale du marché
	if market_prefab:
		var market := market_prefab.instantiate() as Node3D
		market.position = center
		add_child(market)
		_structures.append(market)
		structure_spawned.emit(market, center)
	
	# Étals autour
	if market_stall_prefabs.is_empty():
		return
	
	var stall_count := _rng.randi_range(4, 8)
	for i in range(stall_count):
		var angle := (float(i) / stall_count) * TAU
		var distance := _rng.randf_range(5.0, 12.0)
		var pos := center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		var stall := _instance_random(market_stall_prefabs)
		if stall:
			stall.position = pos
			stall.rotation.y = angle + PI  # Face vers le centre
			add_child(stall)
			_structures.append(stall)


# ==============================================================================
# ZONES TOXIQUES
# ==============================================================================

func _generate_toxic_zones() -> void:
	"""Génère les zones de brume toxique."""
	if not toxic_zone_prefab:
		return
	
	for i in range(toxic_zone_count):
		var pos := Vector3(
			_rng.randf_range(0, zone_width),
			0,
			_rng.randf_range(0, zone_depth)
		)
		
		var toxic := toxic_zone_prefab.instantiate() as Node3D
		toxic.position = pos
		toxic.scale = Vector3.ONE * _rng.randf_range(1.5, 3.0)
		add_child(toxic)
		_structures.append(toxic)


# ==============================================================================
# POINTS DE SPAWN
# ==============================================================================

func _generate_spawn_points() -> void:
	"""Génère les points de spawn pour les ennemis."""
	for i in range(gang_spawn_points):
		var pos := Vector3(
			_rng.randf_range(10, zone_width - 10),
			0,
			_rng.randf_range(10, zone_depth - 10)
		)
		_spawn_points.append(pos)
		
		if enemy_spawn_prefab:
			var spawn := enemy_spawn_prefab.instantiate() as Node3D
			spawn.position = pos
			add_child(spawn)
			_structures.append(spawn)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _cell_to_world(x: int, z: int) -> Vector3:
	"""Convertit coordonnées de cellule en position monde."""
	return Vector3(
		x * cell_size + cell_size / 2.0,
		0,
		z * cell_size + cell_size / 2.0
	)


func _instance_random(prefabs: Array[PackedScene]) -> Node3D:
	"""Instancie un prefab aléatoire depuis une liste."""
	if prefabs.is_empty():
		return null
	var scene := prefabs[_rng.randi() % prefabs.size()]
	if scene:
		return scene.instantiate() as Node3D
	return null


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_spawn_points() -> Array[Vector3]:
	"""Retourne les points de spawn des ennemis."""
	return _spawn_points


func get_structure_count() -> int:
	"""Retourne le nombre de structures générées."""
	return _structures.size()


func get_random_position() -> Vector3:
	"""Retourne une position aléatoire valide dans la zone."""
	return Vector3(
		_rng.randf_range(5, zone_width - 5),
		0,
		_rng.randf_range(5, zone_depth - 5)
	)
