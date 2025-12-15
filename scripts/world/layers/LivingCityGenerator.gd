# ==============================================================================
# LivingCityGenerator.gd - Générateur de la Ville Vivante (Niveau +1 à +20)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère le biome urbain: rails aériens, commerces, cliniques, quartiers
# ==============================================================================

extends Node3D
class_name LivingCityGenerator

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal generation_complete(structure_count: int)
signal poi_spawned(poi_type: String, position: Vector3)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Dimensions")
@export var zone_width: float = 300.0
@export var zone_depth: float = 300.0
@export var floor_height: float = 10.0  ## Hauteur d'un étage
@export var num_floors: int = 20  ## Nombre d'étages à générer

@export_group("Bâtiments Résidentiels")
@export var residential_prefabs: Array[PackedScene] = []
@export var residential_density: float = 0.4

@export_group("Commerces")
@export var food_stall_prefabs: Array[PackedScene] = []
@export var food_stalls_per_floor: int = 8
@export var bar_prefabs: Array[PackedScene] = []
@export var bars_per_floor: int = 3

@export_group("Services")
@export var cyber_clinic_prefab: PackedScene
@export var clinics_per_floor: int = 1
@export var shop_prefabs: Array[PackedScene] = []
@export var shops_per_floor: int = 5

@export_group("Infrastructure")
@export var rail_segment_prefab: PackedScene
@export var rail_station_prefab: PackedScene
@export var walkway_prefab: PackedScene
@export var elevator_prefab: PackedScene

@export_group("Décorations")
@export var neon_sign_prefabs: Array[PackedScene] = []
@export var neon_density: float = 0.6
@export var prop_prefabs: Array[PackedScene] = []

# ==============================================================================
# VARIABLES
# ==============================================================================

var _rng := RandomNumberGenerator.new()
var _structures: Array[Node3D] = []
var _pois: Dictionary = {}  # {type: Array[Node3D]}

# ==============================================================================
# GÉNÉRATION
# ==============================================================================

func _ready() -> void:
	_rng.randomize()


func generate(seed_value: int = 0) -> void:
	"""Génère la Ville Vivante complète."""
	if seed_value != 0:
		_rng.seed = seed_value
	
	_clear_existing()
	
	# Générer chaque étage
	for floor_idx in range(num_floors):
		var floor_y := (floor_idx + 1) * floor_height
		_generate_floor(floor_idx, floor_y)
	
	# Infrastructure verticale
	_generate_rail_network()
	_generate_elevators()
	
	generation_complete.emit(_structures.size())


func _clear_existing() -> void:
	"""Supprime les structures existantes."""
	for structure in _structures:
		if is_instance_valid(structure):
			structure.queue_free()
	_structures.clear()
	_pois.clear()


# ==============================================================================
# GÉNÉRATION PAR ÉTAGE
# ==============================================================================

func _generate_floor(floor_idx: int, floor_y: float) -> void:
	"""Génère un étage complet de la ville."""
	
	# Bâtiments résidentiels
	_generate_residential(floor_y)
	
	# Commerces et services
	_generate_food_stalls(floor_y)
	_generate_bars(floor_y)
	_generate_shops(floor_y)
	
	# Cliniques (pas à tous les étages)
	if floor_idx % 3 == 0:
		_generate_clinics(floor_y)
	
	# Décorations néon
	_generate_neons(floor_y)
	
	# Passerelles entre bâtiments
	_generate_walkways(floor_y)


func _generate_residential(floor_y: float) -> void:
	"""Génère des bâtiments résidentiels."""
	if residential_prefabs.is_empty():
		return
	
	var grid_size := 30.0
	var cells_x := int(zone_width / grid_size)
	var cells_z := int(zone_depth / grid_size)
	
	for x in range(cells_x):
		for z in range(cells_z):
			if _rng.randf() > residential_density:
				continue
			
			var pos := Vector3(
				x * grid_size + _rng.randf_range(5, grid_size - 5),
				floor_y,
				z * grid_size + _rng.randf_range(5, grid_size - 5)
			)
			
			var building := _instance_random(residential_prefabs)
			if building:
				building.position = pos
				building.rotation.y = _rng.randf() * TAU
				add_child(building)
				_structures.append(building)


func _generate_food_stalls(floor_y: float) -> void:
	"""Génère des stands de nourriture."""
	if food_stall_prefabs.is_empty():
		return
	
	for i in range(food_stalls_per_floor):
		var pos := _get_random_floor_position(floor_y)
		var stall := _instance_random(food_stall_prefabs)
		if stall:
			stall.position = pos
			stall.rotation.y = _rng.randf() * TAU
			add_child(stall)
			_structures.append(stall)
			_register_poi("food_stall", stall)
			poi_spawned.emit("food_stall", pos)


func _generate_bars(floor_y: float) -> void:
	"""Génère des bars AR."""
	if bar_prefabs.is_empty():
		return
	
	for i in range(bars_per_floor):
		var pos := _get_random_floor_position(floor_y)
		var bar := _instance_random(bar_prefabs)
		if bar:
			bar.position = pos
			bar.rotation.y = _rng.randf() * TAU
			add_child(bar)
			_structures.append(bar)
			_register_poi("bar", bar)
			poi_spawned.emit("bar", pos)


func _generate_shops(floor_y: float) -> void:
	"""Génère des boutiques."""
	if shop_prefabs.is_empty():
		return
	
	for i in range(shops_per_floor):
		var pos := _get_random_floor_position(floor_y)
		var shop := _instance_random(shop_prefabs)
		if shop:
			shop.position = pos
			shop.rotation.y = _rng.randf() * TAU
			add_child(shop)
			_structures.append(shop)
			_register_poi("shop", shop)
			poi_spawned.emit("shop", pos)


func _generate_clinics(floor_y: float) -> void:
	"""Génère des cliniques cyber."""
	if not cyber_clinic_prefab:
		return
	
	for i in range(clinics_per_floor):
		var pos := _get_random_floor_position(floor_y)
		var clinic := cyber_clinic_prefab.instantiate() as Node3D
		clinic.position = pos
		add_child(clinic)
		_structures.append(clinic)
		_register_poi("cyber_clinic", clinic)
		poi_spawned.emit("cyber_clinic", pos)


func _generate_neons(floor_y: float) -> void:
	"""Génère des enseignes néon."""
	if neon_sign_prefabs.is_empty():
		return
	
	var neon_count := int(zone_width * zone_depth / 1000.0 * neon_density)
	
	for i in range(neon_count):
		var pos := _get_random_floor_position(floor_y)
		pos.y += _rng.randf_range(3, 8)  # Au-dessus du sol
		
		var neon := _instance_random(neon_sign_prefabs)
		if neon:
			neon.position = pos
			neon.rotation.y = _rng.randf() * TAU
			add_child(neon)
			_structures.append(neon)


func _generate_walkways(floor_y: float) -> void:
	"""Génère des passerelles entre bâtiments."""
	if not walkway_prefab:
		return
	
	var walkway_count := _rng.randi_range(3, 8)
	
	for i in range(walkway_count):
		var start_pos := _get_random_floor_position(floor_y)
		var angle := _rng.randf() * TAU
		var length := _rng.randf_range(15, 40)
		
		var walkway := walkway_prefab.instantiate() as Node3D
		walkway.position = start_pos
		walkway.rotation.y = angle
		
		# Si le walkway a une méthode pour définir sa longueur
		if walkway.has_method("set_length"):
			walkway.set_length(length)
		
		add_child(walkway)
		_structures.append(walkway)


# ==============================================================================
# INFRASTRUCTURE
# ==============================================================================

func _generate_rail_network() -> void:
	"""Génère le réseau de rails aériens."""
	if not rail_segment_prefab:
		return
	
	# Rails horizontaux à différentes hauteurs
	var rail_heights := [50.0, 100.0, 150.0]
	
	for height in rail_heights:
		# Rail le long de X
		for z in range(0, int(zone_depth), 80):
			_create_rail_line(
				Vector3(0, height, z),
				Vector3(zone_width, height, z)
			)
		
		# Rail le long de Z
		for x in range(0, int(zone_width), 80):
			_create_rail_line(
				Vector3(x, height, 0),
				Vector3(x, height, zone_depth)
			)
	
	# Stations aux intersections
	if rail_station_prefab:
		_generate_rail_stations(rail_heights)


func _create_rail_line(start: Vector3, end: Vector3) -> void:
	"""Crée une ligne de rail entre deux points."""
	var segment_length := 20.0
	var direction := (end - start).normalized()
	var total_length := start.distance_to(end)
	var segments := int(total_length / segment_length)
	
	for i in range(segments):
		var pos := start + direction * (i * segment_length + segment_length / 2)
		var rail := rail_segment_prefab.instantiate() as Node3D
		rail.position = pos
		rail.look_at(pos + direction, Vector3.UP)
		add_child(rail)
		_structures.append(rail)


func _generate_rail_stations(heights: Array) -> void:
	"""Génère des stations de rail aux intersections."""
	var station_positions := [
		Vector3(zone_width * 0.25, 0, zone_depth * 0.25),
		Vector3(zone_width * 0.75, 0, zone_depth * 0.25),
		Vector3(zone_width * 0.25, 0, zone_depth * 0.75),
		Vector3(zone_width * 0.75, 0, zone_depth * 0.75),
		Vector3(zone_width * 0.5, 0, zone_depth * 0.5),
	]
	
	for base_pos in station_positions:
		for height in heights:
			var pos := Vector3(base_pos.x, height, base_pos.z)
			var station := rail_station_prefab.instantiate() as Node3D
			station.position = pos
			add_child(station)
			_structures.append(station)
			_register_poi("rail_station", station)


func _generate_elevators() -> void:
	"""Génère des ascenseurs verticaux."""
	if not elevator_prefab:
		return
	
	var elevator_positions := [
		Vector3(zone_width * 0.2, 0, zone_depth * 0.2),
		Vector3(zone_width * 0.8, 0, zone_depth * 0.2),
		Vector3(zone_width * 0.2, 0, zone_depth * 0.8),
		Vector3(zone_width * 0.8, 0, zone_depth * 0.8),
		Vector3(zone_width * 0.5, 0, zone_depth * 0.5),
	]
	
	for pos in elevator_positions:
		var elevator := elevator_prefab.instantiate() as Node3D
		elevator.position = pos
		
		# Si l'ascenseur a des paramètres de hauteur
		if elevator.has_method("set_height_range"):
			elevator.set_height_range(floor_height, num_floors * floor_height)
		
		add_child(elevator)
		_structures.append(elevator)
		_register_poi("elevator", elevator)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _get_random_floor_position(floor_y: float) -> Vector3:
	"""Retourne une position aléatoire sur un étage."""
	return Vector3(
		_rng.randf_range(10, zone_width - 10),
		floor_y,
		_rng.randf_range(10, zone_depth - 10)
	)


func _instance_random(prefabs: Array[PackedScene]) -> Node3D:
	"""Instancie un prefab aléatoire."""
	if prefabs.is_empty():
		return null
	var scene := prefabs[_rng.randi() % prefabs.size()]
	if scene:
		return scene.instantiate() as Node3D
	return null


func _register_poi(poi_type: String, node: Node3D) -> void:
	"""Enregistre un point d'intérêt."""
	if not _pois.has(poi_type):
		_pois[poi_type] = []
	_pois[poi_type].append(node)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_pois_by_type(poi_type: String) -> Array:
	"""Retourne tous les POIs d'un type donné."""
	return _pois.get(poi_type, [])


func get_nearest_poi(position: Vector3, poi_type: String) -> Node3D:
	"""Retourne le POI le plus proche d'un type donné."""
	var pois := get_pois_by_type(poi_type)
	if pois.is_empty():
		return null
	
	var nearest: Node3D = null
	var min_dist := INF
	
	for poi in pois:
		if not is_instance_valid(poi):
			continue
		var dist := position.distance_to(poi.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = poi
	
	return nearest


func get_all_pois() -> Dictionary:
	"""Retourne tous les POIs."""
	return _pois


func get_structure_count() -> int:
	"""Retourne le nombre de structures."""
	return _structures.size()
