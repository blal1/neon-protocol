# ==============================================================================
# CityManager.gd - Générateur de Ville Procédural (Grille 2D)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère une ville 10x10 au démarrage avec routes et bâtiments
# Optimisé pour mobile : instanciation unique au Start
# ==============================================================================

extends Node3D
class_name CityManager

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal city_generation_started
signal city_generation_completed(building_count: int)
signal building_spawned(position: Vector3)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum CellType {
	EMPTY,          # Cellule vide (peut recevoir un bâtiment)
	ROAD_MAIN,      # Route principale (axe central)
	ROAD_SECONDARY, # Route secondaire
	BUILDING,       # Bâtiment placé
	PLAZA,          # Place publique (décoration)
	RESERVED        # Réservé (spawn joueur, objectifs, etc.)
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export_group("Taille de la Grille")
@export var grid_width: int = 10  ## Nombre de cellules en X
@export var grid_height: int = 10  ## Nombre de cellules en Z
@export var cell_size: float = 20.0  ## Taille d'une cellule en mètres

@export_group("Prefabs Bâtiments")
@export var building_prefabs: Array[PackedScene] = []  ## Liste des prefabs
@export var road_prefab: PackedScene  ## Prefab de route
@export var plaza_prefab: PackedScene  ## Prefab de place

@export_group("Routes")
@export var main_road_position: int = 5  ## Position X de la route principale (0-9)
@export var enable_secondary_roads: bool = true
@export var secondary_road_interval: int = 3  ## Intervalle des routes secondaires

@export_group("Génération")
@export var building_density: float = 0.7  ## Probabilité de placer un bâtiment (0-1)
@export var random_seed: int = 0  ## 0 = seed aléatoire
@export var height_variation: bool = true  ## Varier la hauteur des bâtiments

@export_group("Spawn Joueur")
@export var player_spawn_cell: Vector2i = Vector2i(5, 0)  ## Cellule de spawn

# ==============================================================================
# VARIABLES INTERNES
# ==============================================================================
var _grid: Array = []  # Array 2D [x][z] de CellType
var _buildings: Array[Node3D] = []  # Références aux bâtiments instanciés
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	"""Génère la ville au démarrage (évite le lag en jeu)."""
	# Initialiser le générateur aléatoire
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	
	# Générer la ville
	_generate_city()


func _generate_city() -> void:
	"""Pipeline complet de génération."""
	city_generation_started.emit()
	
	var start_time := Time.get_ticks_msec()
	
	# Étape 1 : Initialiser la grille vide
	_initialize_grid()
	
	# Étape 2 : Placer les routes
	_place_roads()
	
	# Étape 3 : Marquer les zones réservées
	_mark_reserved_zones()
	
	# Étape 4 : Placer les bâtiments
	var building_count := _place_buildings()
	
	# Étape 5 : Placer les décorations (optionnel)
	_place_decorations()
	
	var elapsed := Time.get_ticks_msec() - start_time
	print("CityManager: Ville générée en %d ms (%d bâtiments)" % [elapsed, building_count])
	
	city_generation_completed.emit(building_count)


# ==============================================================================
# ÉTAPE 1 : INITIALISATION DE LA GRILLE
# ==============================================================================

func _initialize_grid() -> void:
	"""Crée une grille 2D vide."""
	_grid.clear()
	
	for x in range(grid_width):
		var column: Array = []
		for z in range(grid_height):
			column.append(CellType.EMPTY)
		_grid.append(column)


# ==============================================================================
# ÉTAPE 2 : PLACEMENT DES ROUTES
# ==============================================================================

func _place_roads() -> void:
	"""Place la route principale et les routes secondaires."""
	
	# === ROUTE PRINCIPALE (axe vertical) ===
	var main_x := clampi(main_road_position, 0, grid_width - 1)
	for z in range(grid_height):
		_grid[main_x][z] = CellType.ROAD_MAIN
		_spawn_road(main_x, z, true)
	
	# === ROUTES SECONDAIRES (axes horizontaux) ===
	if enable_secondary_roads:
		for z in range(grid_height):
			if z % secondary_road_interval == 0:
				for x in range(grid_width):
					if _grid[x][z] == CellType.EMPTY:
						_grid[x][z] = CellType.ROAD_SECONDARY
						_spawn_road(x, z, false)


func _spawn_road(grid_x: int, grid_z: int, is_main: bool) -> void:
	"""Instancie un segment de route."""
	if not road_prefab:
		return
	
	var road := road_prefab.instantiate() as Node3D
	if road:
		road.position = _grid_to_world(grid_x, grid_z)
		
		# Optionnel : différencier visuellement les routes
		if road.has_method("set_road_type"):
			road.set_road_type("main" if is_main else "secondary")
		
		add_child(road)


# ==============================================================================
# ÉTAPE 3 : ZONES RÉSERVÉES
# ==============================================================================

func _mark_reserved_zones() -> void:
	"""Marque les cellules réservées (spawn, objectifs, etc.)."""
	
	# Zone de spawn du joueur
	var spawn_x := clampi(player_spawn_cell.x, 0, grid_width - 1)
	var spawn_z := clampi(player_spawn_cell.y, 0, grid_height - 1)
	_grid[spawn_x][spawn_z] = CellType.RESERVED
	
	# Zone autour du spawn (pour éviter les collisions)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var nx := spawn_x + dx
			var nz := spawn_z + dz
			if _is_valid_cell(nx, nz) and _grid[nx][nz] == CellType.EMPTY:
				_grid[nx][nz] = CellType.RESERVED


# ==============================================================================
# ÉTAPE 4 : PLACEMENT DES BÂTIMENTS
# ==============================================================================

func _place_buildings() -> int:
	"""Place les bâtiments sur les cellules vides."""
	var count := 0
	
	if building_prefabs.is_empty():
		push_warning("CityManager: Aucun prefab de bâtiment configuré!")
		return 0
	
	for x in range(grid_width):
		for z in range(grid_height):
			# Ne placer que sur les cellules vides
			if _grid[x][z] != CellType.EMPTY:
				continue
			
			# Probabilité de placement
			if _rng.randf() > building_density:
				continue
			
			# Choisir un prefab aléatoire
			var prefab_index := _rng.randi_range(0, building_prefabs.size() - 1)
			var prefab := building_prefabs[prefab_index]
			
			if prefab:
				_spawn_building(prefab, x, z)
				_grid[x][z] = CellType.BUILDING
				count += 1
	
	return count


func _spawn_building(prefab: PackedScene, grid_x: int, grid_z: int) -> void:
	"""Instancie un bâtiment à la position de grille donnée."""
	var building := prefab.instantiate() as Node3D
	if not building:
		return
	
	# Position
	building.position = _grid_to_world(grid_x, grid_z)
	
	# Rotation aléatoire (0°, 90°, 180°, 270°)
	var rotation_index := _rng.randi_range(0, 3)
	building.rotation_degrees.y = rotation_index * 90.0
	
	# Variation de hauteur (optionnel)
	if height_variation and building.has_method("set_height_scale"):
		var scale := _rng.randf_range(0.8, 1.3)
		building.set_height_scale(scale)
	
	# Ajouter à la scène
	add_child(building)
	_buildings.append(building)
	
	building_spawned.emit(building.position)


# ==============================================================================
# ÉTAPE 5 : DÉCORATIONS (OPTIONNEL)
# ==============================================================================

func _place_decorations() -> void:
	"""Place des éléments décoratifs (places, props)."""
	if not plaza_prefab:
		return
	
	# Placer une place au centre de la carte
	var center_x := grid_width / 2
	var center_z := grid_height / 2
	
	# Trouver la cellule vide la plus proche du centre
	for radius in range(0, 3):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var x := center_x + dx
				var z := center_z + dz
				if _is_valid_cell(x, z) and _grid[x][z] == CellType.EMPTY:
					var plaza := plaza_prefab.instantiate() as Node3D
					if plaza:
						plaza.position = _grid_to_world(x, z)
						add_child(plaza)
						_grid[x][z] = CellType.PLAZA
					return


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _grid_to_world(grid_x: int, grid_z: int) -> Vector3:
	"""Convertit les coordonnées de grille en position monde."""
	return Vector3(
		grid_x * cell_size + cell_size / 2.0,
		0.0,
		grid_z * cell_size + cell_size / 2.0
	)


func _world_to_grid(world_pos: Vector3) -> Vector2i:
	"""Convertit une position monde en coordonnées de grille."""
	return Vector2i(
		int(world_pos.x / cell_size),
		int(world_pos.z / cell_size)
	)


func _is_valid_cell(x: int, z: int) -> bool:
	"""Vérifie si les coordonnées sont dans la grille."""
	return x >= 0 and x < grid_width and z >= 0 and z < grid_height


func get_cell_type(grid_x: int, grid_z: int) -> CellType:
	"""Retourne le type d'une cellule."""
	if _is_valid_cell(grid_x, grid_z):
		return _grid[grid_x][grid_z]
	return CellType.EMPTY


func get_player_spawn_position() -> Vector3:
	"""Retourne la position de spawn du joueur en coordonnées monde."""
	return _grid_to_world(player_spawn_cell.x, player_spawn_cell.y)


func get_all_buildings() -> Array[Node3D]:
	"""Retourne la liste de tous les bâtiments."""
	return _buildings


# ==============================================================================
# API PUBLIQUE (pour événements dynamiques)
# ==============================================================================

func destroy_building_at(world_pos: Vector3) -> bool:
	"""Détruit un bâtiment à la position donnée."""
	var grid_pos := _world_to_grid(world_pos)
	
	if not _is_valid_cell(grid_pos.x, grid_pos.y):
		return false
	
	for building in _buildings:
		if _world_to_grid(building.position) == grid_pos:
			building.queue_free()
			_buildings.erase(building)
			_grid[grid_pos.x][grid_pos.y] = CellType.EMPTY
			return true
	
	return false


func regenerate_city(new_seed: int = 0) -> void:
	"""Régénère complètement la ville (pour debug/nouveau niveau)."""
	# Nettoyer les anciens bâtiments
	for building in _buildings:
		if is_instance_valid(building):
			building.queue_free()
	_buildings.clear()
	
	# Nettoyer les routes (trouver tous les enfants Node3D)
	for child in get_children():
		if child is Node3D:
			child.queue_free()
	
	# Nouveau seed
	if new_seed != 0:
		random_seed = new_seed
		_rng.seed = new_seed
	else:
		_rng.randomize()
	
	# Régénérer
	await get_tree().process_frame  # Attendre que queue_free soit traité
	_generate_city()
