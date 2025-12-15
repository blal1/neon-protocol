# ==============================================================================
# ChunkStreamer.gd - Système de Streaming par Chunks
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Charge/décharge des zones entières de la ville selon la position du joueur
# Plus efficace que le culling individuel pour grandes cartes
# ==============================================================================

extends Node
class_name ChunkStreamer

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal chunk_loaded(chunk_id: Vector2i)
signal chunk_unloaded(chunk_id: Vector2i)

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export_group("Chunks")
@export var chunk_size: float = 40.0  ## Taille d'un chunk en mètres
@export var load_radius: int = 2  ## Nombre de chunks chargés autour du joueur
@export var unload_radius: int = 3  ## Distance pour décharger (doit être > load_radius)

@export_group("Références")
@export var player: Node3D
@export var city_manager: CityManager

@export_group("Performance")
@export var update_interval: float = 0.5  ## Fréquence de vérification

# ==============================================================================
# VARIABLES
# ==============================================================================
var _loaded_chunks: Dictionary = {}  # {Vector2i: Array[Node3D]}
var _player_chunk: Vector2i = Vector2i(-999, -999)
var _timer: float = 0.0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	if not player:
		await get_tree().process_frame
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0] as Node3D
	
	if city_manager:
		_assign_objects_to_chunks()


func _assign_objects_to_chunks() -> void:
	"""Assigne chaque bâtiment à son chunk."""
	for building in city_manager.get_all_buildings():
		var chunk_id := _world_to_chunk(building.global_position)
		
		if not _loaded_chunks.has(chunk_id):
			_loaded_chunks[chunk_id] = []
		
		_loaded_chunks[chunk_id].append(building)


# ==============================================================================
# MISE À JOUR
# ==============================================================================

func _process(delta: float) -> void:
	if not player:
		return
	
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	
	var new_chunk := _world_to_chunk(player.global_position)
	
	# Le joueur a changé de chunk ?
	if new_chunk != _player_chunk:
		_player_chunk = new_chunk
		_update_chunks()


func _update_chunks() -> void:
	"""Charge/décharge les chunks selon la nouvelle position."""
	var chunks_to_load: Array[Vector2i] = []
	var chunks_to_unload: Array[Vector2i] = []
	
	# Trouver les chunks à charger
	for dx in range(-load_radius, load_radius + 1):
		for dz in range(-load_radius, load_radius + 1):
			var chunk_id := Vector2i(_player_chunk.x + dx, _player_chunk.y + dz)
			chunks_to_load.append(chunk_id)
	
	# Trouver les chunks à décharger
	for chunk_id in _loaded_chunks.keys():
		var distance := _chunk_distance(chunk_id, _player_chunk)
		if distance > unload_radius:
			chunks_to_unload.append(chunk_id)
	
	# Effectuer les opérations
	for chunk_id in chunks_to_unload:
		_unload_chunk(chunk_id)
	
	for chunk_id in chunks_to_load:
		_load_chunk(chunk_id)


func _load_chunk(chunk_id: Vector2i) -> void:
	"""Active tous les objets d'un chunk."""
	if not _loaded_chunks.has(chunk_id):
		return
	
	for obj in _loaded_chunks[chunk_id]:
		if is_instance_valid(obj):
			obj.visible = true
			obj.set_process(true)
			obj.set_physics_process(true)
	
	chunk_loaded.emit(chunk_id)


func _unload_chunk(chunk_id: Vector2i) -> void:
	"""Désactive tous les objets d'un chunk."""
	if not _loaded_chunks.has(chunk_id):
		return
	
	for obj in _loaded_chunks[chunk_id]:
		if is_instance_valid(obj):
			obj.visible = false
			obj.set_process(false)
			obj.set_physics_process(false)
	
	chunk_unloaded.emit(chunk_id)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	"""Convertit une position monde en ID de chunk."""
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)


func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	"""Distance de Chebyshev entre deux chunks."""
	return max(abs(a.x - b.x), abs(a.y - b.y))


func get_loaded_chunk_count() -> int:
	"""Retourne le nombre de chunks actuellement chargés."""
	var count := 0
	for chunk_id in _loaded_chunks.keys():
		if _chunk_distance(chunk_id, _player_chunk) <= load_radius:
			count += 1
	return count
