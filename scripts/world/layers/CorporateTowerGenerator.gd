# ==============================================================================
# CorporateTowerGenerator.gd - Générateur des Tours Corporatistes (Niveau +21+)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère le biome corporate: arcologies, fermes verticales, zones interdites
# ==============================================================================

extends Node3D
class_name CorporateTowerGenerator

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal generation_complete(tower_count: int)
signal restricted_zone_spawned(zone: Node3D, bounds: AABB)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Dimensions")
@export var zone_width: float = 400.0
@export var zone_depth: float = 400.0
@export var base_altitude: float = 210.0  ## Y de départ

@export_group("Tours Principales")
@export var tower_prefabs: Array[PackedScene] = []
@export var tower_count: int = 8
@export var tower_min_height: float = 100.0
@export var tower_max_height: float = 300.0
@export var tower_spacing: float = 60.0

@export_group("Arcologies")
@export var arcology_prefab: PackedScene
@export var arcology_count: int = 2

@export_group("Fermes Verticales")
@export var vertical_farm_prefab: PackedScene
@export var farms_per_tower: int = 2

@export_group("Sécurité")
@export var security_checkpoint_prefab: PackedScene
@export var turret_prefab: PackedScene
@export var drone_patrol_prefab: PackedScene
@export var restricted_zone_prefab: PackedScene

@export_group("Ponts Corporatifs")
@export var skybridge_prefab: PackedScene
@export var helipad_prefab: PackedScene

# ==============================================================================
# VARIABLES
# ==============================================================================

var _rng := RandomNumberGenerator.new()
var _structures: Array[Node3D] = []
var _towers: Array[Node3D] = []
var _restricted_zones: Array[AABB] = []

# ==============================================================================
# GÉNÉRATION
# ==============================================================================

func _ready() -> void:
	_rng.randomize()


func generate(seed_value: int = 0) -> void:
	"""Génère les Tours Corporatistes complètes."""
	if seed_value != 0:
		_rng.seed = seed_value
	
	_clear_existing()
	
	# Tours principales
	_generate_towers()
	
	# Arcologies
	_generate_arcologies()
	
	# Infrastructures
	_generate_skybridges()
	_generate_helipads()
	
	# Sécurité
	_generate_security_systems()
	
	generation_complete.emit(_towers.size())


func _clear_existing() -> void:
	"""Supprime les structures existantes."""
	for structure in _structures:
		if is_instance_valid(structure):
			structure.queue_free()
	_structures.clear()
	_towers.clear()
	_restricted_zones.clear()


# ==============================================================================
# TOURS
# ==============================================================================

func _generate_towers() -> void:
	"""Génère les tours corporatistes principales."""
	if tower_prefabs.is_empty():
		return
	
	var placed_positions: Array[Vector3] = []
	var attempts := 0
	var max_attempts := tower_count * 10
	
	while _towers.size() < tower_count and attempts < max_attempts:
		attempts += 1
		
		var pos := Vector3(
			_rng.randf_range(tower_spacing, zone_width - tower_spacing),
			base_altitude,
			_rng.randf_range(tower_spacing, zone_depth - tower_spacing)
		)
		
		# Vérifier l'espacement avec les autres tours
		var valid := true
		for existing in placed_positions:
			if pos.distance_to(existing) < tower_spacing:
				valid = false
				break
		
		if not valid:
			continue
		
		placed_positions.append(pos)
		
		# Créer la tour
		var tower := _instance_random(tower_prefabs)
		if tower:
			tower.position = pos
			tower.rotation.y = _rng.randf() * TAU
			
			# Hauteur variable
			var height := _rng.randf_range(tower_min_height, tower_max_height)
			if tower.has_method("set_height"):
				tower.set_height(height)
			
			add_child(tower)
			_structures.append(tower)
			_towers.append(tower)
			
			# Ajouter fermes verticales
			_attach_vertical_farms(tower, height)
			
			# Zone restreinte autour de la tour
			_create_restricted_zone(pos, tower_spacing * 0.8, height)


func _attach_vertical_farms(tower: Node3D, tower_height: float) -> void:
	"""Attache des fermes verticales aux tours."""
	if not vertical_farm_prefab:
		return
	
	for i in range(farms_per_tower):
		var farm := vertical_farm_prefab.instantiate() as Node3D
		var height_offset := _rng.randf_range(tower_height * 0.3, tower_height * 0.7)
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(8, 15)
		
		farm.position = tower.position + Vector3(
			cos(angle) * distance,
			height_offset,
			sin(angle) * distance
		)
		farm.rotation.y = angle + PI
		
		add_child(farm)
		_structures.append(farm)


# ==============================================================================
# ARCOLOGIES
# ==============================================================================

func _generate_arcologies() -> void:
	"""Génère les méga-structures arcologies."""
	if not arcology_prefab:
		return
	
	var positions := [
		Vector3(zone_width * 0.25, base_altitude, zone_depth * 0.5),
		Vector3(zone_width * 0.75, base_altitude, zone_depth * 0.5),
	]
	
	for i in range(min(arcology_count, positions.size())):
		var arcology := arcology_prefab.instantiate() as Node3D
		arcology.position = positions[i]
		add_child(arcology)
		_structures.append(arcology)
		
		# Grande zone restreinte
		_create_restricted_zone(positions[i], 80.0, 200.0)


# ==============================================================================
# PONTS & HELIPADS
# ==============================================================================

func _generate_skybridges() -> void:
	"""Génère des ponts entre les tours."""
	if not skybridge_prefab or _towers.size() < 2:
		return
	
	# Connecter les tours proches
	for i in range(_towers.size()):
		for j in range(i + 1, _towers.size()):
			var tower_a := _towers[i]
			var tower_b := _towers[j]
			var dist := tower_a.position.distance_to(tower_b.position)
			
			# Connecter si assez proches
			if dist < tower_spacing * 2.5 and _rng.randf() < 0.6:
				_create_skybridge(tower_a.position, tower_b.position)


func _create_skybridge(start: Vector3, end: Vector3) -> void:
	"""Crée un pont aérien entre deux points."""
	var bridge := skybridge_prefab.instantiate() as Node3D
	var midpoint := (start + end) / 2.0
	var height_variation := _rng.randf_range(30, 80)
	
	bridge.position = Vector3(midpoint.x, base_altitude + height_variation, midpoint.z)
	bridge.look_at(Vector3(end.x, bridge.position.y, end.z), Vector3.UP)
	
	if bridge.has_method("set_length"):
		bridge.set_length(start.distance_to(end))
	
	add_child(bridge)
	_structures.append(bridge)


func _generate_helipads() -> void:
	"""Génère des helipads sur les tours."""
	if not helipad_prefab:
		return
	
	for tower in _towers:
		if _rng.randf() < 0.5:  # 50% des tours ont un helipad
			var helipad := helipad_prefab.instantiate() as Node3D
			helipad.position = tower.position + Vector3(0, tower_max_height + 10, 0)
			add_child(helipad)
			_structures.append(helipad)


# ==============================================================================
# SÉCURITÉ
# ==============================================================================

func _generate_security_systems() -> void:
	"""Génère les systèmes de sécurité."""
	_generate_checkpoints()
	_generate_turrets()
	_generate_drone_patrols()


func _generate_checkpoints() -> void:
	"""Génère des checkpoints de sécurité."""
	if not security_checkpoint_prefab:
		return
	
	# Un checkpoint à l'entrée de chaque tour
	for tower in _towers:
		var checkpoint := security_checkpoint_prefab.instantiate() as Node3D
		var angle := _rng.randf() * TAU
		checkpoint.position = tower.position + Vector3(
			cos(angle) * 25,
			0,
			sin(angle) * 25
		)
		checkpoint.rotation.y = angle + PI
		add_child(checkpoint)
		_structures.append(checkpoint)


func _generate_turrets() -> void:
	"""Génère des tourelles automatiques."""
	if not turret_prefab:
		return
	
	for tower in _towers:
		var turret_count := _rng.randi_range(2, 4)
		for i in range(turret_count):
			var turret := turret_prefab.instantiate() as Node3D
			var angle := (float(i) / turret_count) * TAU
			var height := _rng.randf_range(20, 60)
			
			turret.position = tower.position + Vector3(
				cos(angle) * 12,
				height,
				sin(angle) * 12
			)
			turret.rotation.y = angle
			add_child(turret)
			_structures.append(turret)


func _generate_drone_patrols() -> void:
	"""Génère des points de patrouille pour drones."""
	if not drone_patrol_prefab:
		return
	
	# Patrouilles entre les tours
	for tower in _towers:
		var patrol := drone_patrol_prefab.instantiate() as Node3D
		patrol.position = tower.position + Vector3(0, 50, 0)
		add_child(patrol)
		_structures.append(patrol)


func _create_restricted_zone(center: Vector3, radius: float, height: float) -> void:
	"""Crée une zone restreinte."""
	var zone_aabb := AABB(
		center - Vector3(radius, 10, radius),
		Vector3(radius * 2, height + 20, radius * 2)
	)
	_restricted_zones.append(zone_aabb)
	
	if restricted_zone_prefab:
		var zone := restricted_zone_prefab.instantiate() as Node3D
		zone.position = center
		if zone.has_method("set_bounds"):
			zone.set_bounds(radius, height)
		add_child(zone)
		_structures.append(zone)
		restricted_zone_spawned.emit(zone, zone_aabb)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _instance_random(prefabs: Array[PackedScene]) -> Node3D:
	"""Instancie un prefab aléatoire."""
	if prefabs.is_empty():
		return null
	var scene := prefabs[_rng.randi() % prefabs.size()]
	if scene:
		return scene.instantiate() as Node3D
	return null


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func is_in_restricted_zone(position: Vector3) -> bool:
	"""Vérifie si une position est dans une zone restreinte."""
	for zone in _restricted_zones:
		if zone.has_point(position):
			return true
	return false


func get_towers() -> Array[Node3D]:
	"""Retourne toutes les tours."""
	return _towers


func get_restricted_zones() -> Array[AABB]:
	"""Retourne toutes les zones restreintes."""
	return _restricted_zones


func get_structure_count() -> int:
	"""Retourne le nombre de structures."""
	return _structures.size()
