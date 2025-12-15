# ==============================================================================
# ChunkStateSerializer.gd - Persistance du Monde Procédural
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Sauvegarde les modifications des chunks générés.
# Ennemis tués, objets déplacés, états modifiés persistent.
# ==============================================================================

extends Node
class_name ChunkStateSerializer

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal chunk_state_saved(chunk_id: String)
signal chunk_state_loaded(chunk_id: String)
signal chunk_state_cleared(chunk_id: String)
signal world_state_saved()
signal world_state_loaded()

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Storage")
@export var save_path: String = "user://world_state/"
@export var file_extension: String = ".chunk"
@export var use_compression: bool = true

@export_group("Auto-Save")
@export var auto_save_on_chunk_exit: bool = true
@export var auto_save_interval: float = 60.0  # Secondes

@export_group("Cleanup")
@export var max_cached_chunks: int = 100
@export var cache_expiry_time: float = 300.0  # 5 minutes

# ==============================================================================
# TYPES DE DONNÉES SÉRIALISABLES
# ==============================================================================

enum EntityState {
	ALIVE,
	DEAD,
	REMOVED,
	MODIFIED
}

# ==============================================================================
# VARIABLES
# ==============================================================================

## Cache en mémoire des états de chunks
var _chunk_cache: Dictionary = {}  # chunk_id -> ChunkData

## Chunks modifiés non sauvegardés
var _dirty_chunks: Array[String] = []

## Timer auto-save
var _auto_save_timer: float = 0.0

## Stats
var _total_entities_tracked: int = 0
var _total_items_tracked: int = 0

# ==============================================================================
# CLASSES INTERNES
# ==============================================================================

class ChunkData:
	var chunk_id: String = ""
	var last_modified: float = 0.0
	var entities: Dictionary = {}  # entity_id -> EntityData
	var items: Dictionary = {}  # item_id -> ItemData
	var interactables: Dictionary = {}  # id -> state
	var custom_data: Dictionary = {}
	
	func to_dict() -> Dictionary:
		return {
			"chunk_id": chunk_id,
			"last_modified": last_modified,
			"entities": entities,
			"items": items,
			"interactables": interactables,
			"custom_data": custom_data
		}
	
	static func from_dict(data: Dictionary) -> ChunkData:
		var chunk := ChunkData.new()
		chunk.chunk_id = data.get("chunk_id", "")
		chunk.last_modified = data.get("last_modified", 0.0)
		chunk.entities = data.get("entities", {})
		chunk.items = data.get("items", {})
		chunk.interactables = data.get("interactables", {})
		chunk.custom_data = data.get("custom_data", {})
		return chunk


# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_ensure_save_directory()


func _ensure_save_directory() -> void:
	"""Crée le répertoire de sauvegarde si nécessaire."""
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists(save_path.replace("user://", "")):
		dir.make_dir_recursive(save_path.replace("user://", ""))


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	if auto_save_interval > 0:
		_auto_save_timer += delta
		if _auto_save_timer >= auto_save_interval:
			_auto_save_timer = 0.0
			save_dirty_chunks()


# ==============================================================================
# ENREGISTREMENT D'ENTITÉS
# ==============================================================================

func register_entity_death(chunk_id: String, entity_id: String, entity_type: String) -> void:
	"""Enregistre la mort d'une entité."""
	var chunk := _get_or_create_chunk(chunk_id)
	
	chunk.entities[entity_id] = {
		"state": EntityState.DEAD,
		"type": entity_type,
		"death_time": Time.get_ticks_msec() / 1000.0
	}
	
	_mark_dirty(chunk_id)
	_total_entities_tracked += 1


func register_entity_removal(chunk_id: String, entity_id: String) -> void:
	"""Enregistre la suppression d'une entité (pas de respawn)."""
	var chunk := _get_or_create_chunk(chunk_id)
	
	chunk.entities[entity_id] = {
		"state": EntityState.REMOVED,
		"removal_time": Time.get_ticks_msec() / 1000.0
	}
	
	_mark_dirty(chunk_id)


func register_entity_state(chunk_id: String, entity_id: String, custom_state: Dictionary) -> void:
	"""Enregistre un état custom pour une entité."""
	var chunk := _get_or_create_chunk(chunk_id)
	
	chunk.entities[entity_id] = {
		"state": EntityState.MODIFIED,
		"custom": custom_state,
		"modified_time": Time.get_ticks_msec() / 1000.0
	}
	
	_mark_dirty(chunk_id)


func is_entity_dead(chunk_id: String, entity_id: String) -> bool:
	"""Vérifie si une entité est morte."""
	var chunk := _chunk_cache.get(chunk_id)
	if not chunk:
		chunk = _load_chunk_from_disk(chunk_id)
	
	if not chunk or not chunk.entities.has(entity_id):
		return false
	
	var state: int = chunk.entities[entity_id].get("state", EntityState.ALIVE)
	return state in [EntityState.DEAD, EntityState.REMOVED]


func get_entity_state(chunk_id: String, entity_id: String) -> Dictionary:
	"""Récupère l'état d'une entité."""
	var chunk := _chunk_cache.get(chunk_id)
	if not chunk:
		chunk = _load_chunk_from_disk(chunk_id)
	
	if not chunk or not chunk.entities.has(entity_id):
		return {}
	
	return chunk.entities[entity_id]


# ==============================================================================
# ENREGISTREMENT D'ITEMS
# ==============================================================================

func register_item_dropped(chunk_id: String, item_id: String, item_data: Dictionary, position: Vector3) -> void:
	"""Enregistre un item laissé au sol."""
	var chunk := _get_or_create_chunk(chunk_id)
	
	chunk.items[item_id] = {
		"data": item_data,
		"position": {
			"x": position.x,
			"y": position.y,
			"z": position.z
		},
		"drop_time": Time.get_ticks_msec() / 1000.0
	}
	
	_mark_dirty(chunk_id)
	_total_items_tracked += 1


func register_item_picked(chunk_id: String, item_id: String) -> void:
	"""Enregistre qu'un item a été ramassé."""
	var chunk := _get_or_create_chunk(chunk_id)
	
	if chunk.items.has(item_id):
		chunk.items.erase(item_id)
		_mark_dirty(chunk_id)


func get_dropped_items(chunk_id: String) -> Array[Dictionary]:
	"""Récupère les items au sol dans un chunk."""
	var chunk := _chunk_cache.get(chunk_id)
	if not chunk:
		chunk = _load_chunk_from_disk(chunk_id)
	
	if not chunk:
		return []
	
	var items: Array[Dictionary] = []
	for item_id in chunk.items.keys():
		var item_data: Dictionary = chunk.items[item_id].duplicate()
		item_data["id"] = item_id
		items.append(item_data)
	
	return items


# ==============================================================================
# ENREGISTREMENT D'INTERACTABLES
# ==============================================================================

func register_interactable_state(chunk_id: String, interactable_id: String, state: Dictionary) -> void:
	"""Enregistre l'état d'un objet interactif (porte, coffre, etc.)."""
	var chunk := _get_or_create_chunk(chunk_id)
	
	chunk.interactables[interactable_id] = {
		"state": state,
		"modified_time": Time.get_ticks_msec() / 1000.0
	}
	
	_mark_dirty(chunk_id)


func get_interactable_state(chunk_id: String, interactable_id: String) -> Dictionary:
	"""Récupère l'état d'un interactable."""
	var chunk := _chunk_cache.get(chunk_id)
	if not chunk:
		chunk = _load_chunk_from_disk(chunk_id)
	
	if not chunk or not chunk.interactables.has(interactable_id):
		return {}
	
	return chunk.interactables[interactable_id].get("state", {})


# ==============================================================================
# DONNÉES CUSTOM
# ==============================================================================

func set_custom_data(chunk_id: String, key: String, value: Variant) -> void:
	"""Définit une donnée custom pour un chunk."""
	var chunk := _get_or_create_chunk(chunk_id)
	chunk.custom_data[key] = value
	_mark_dirty(chunk_id)


func get_custom_data(chunk_id: String, key: String, default: Variant = null) -> Variant:
	"""Récupère une donnée custom."""
	var chunk := _chunk_cache.get(chunk_id)
	if not chunk:
		chunk = _load_chunk_from_disk(chunk_id)
	
	if not chunk:
		return default
	
	return chunk.custom_data.get(key, default)


# ==============================================================================
# GESTION DU CACHE
# ==============================================================================

func _get_or_create_chunk(chunk_id: String) -> ChunkData:
	"""Récupère ou crée un chunk dans le cache."""
	if _chunk_cache.has(chunk_id):
		return _chunk_cache[chunk_id]
	
	# Essayer de charger depuis le disque
	var loaded := _load_chunk_from_disk(chunk_id)
	if loaded:
		_chunk_cache[chunk_id] = loaded
		return loaded
	
	# Créer nouveau
	var chunk := ChunkData.new()
	chunk.chunk_id = chunk_id
	chunk.last_modified = Time.get_ticks_msec() / 1000.0
	
	_chunk_cache[chunk_id] = chunk
	_cleanup_cache_if_needed()
	
	return chunk


func _mark_dirty(chunk_id: String) -> void:
	"""Marque un chunk comme modifié."""
	if chunk_id not in _dirty_chunks:
		_dirty_chunks.append(chunk_id)
	
	if _chunk_cache.has(chunk_id):
		_chunk_cache[chunk_id].last_modified = Time.get_ticks_msec() / 1000.0


func _cleanup_cache_if_needed() -> void:
	"""Nettoie le cache si trop gros."""
	if _chunk_cache.size() <= max_cached_chunks:
		return
	
	# Trier par dernière modification
	var sorted_chunks: Array = []
	for chunk_id in _chunk_cache.keys():
		sorted_chunks.append({
			"id": chunk_id,
			"time": _chunk_cache[chunk_id].last_modified
		})
	
	sorted_chunks.sort_custom(func(a, b): return a.time < b.time)
	
	# Supprimer les plus anciens
	var to_remove := sorted_chunks.size() - max_cached_chunks
	for i in range(to_remove):
		var chunk_id: String = sorted_chunks[i].id
		
		# Sauvegarder si dirty avant de supprimer
		if chunk_id in _dirty_chunks:
			_save_chunk_to_disk(chunk_id)
		
		_chunk_cache.erase(chunk_id)


# ==============================================================================
# SAUVEGARDE/CHARGEMENT DISQUE
# ==============================================================================

func _get_chunk_file_path(chunk_id: String) -> String:
	"""Retourne le chemin de fichier pour un chunk."""
	var safe_id := chunk_id.replace("/", "_").replace("\\", "_").replace(":", "_")
	return save_path + safe_id + file_extension


func _save_chunk_to_disk(chunk_id: String) -> bool:
	"""Sauvegarde un chunk sur disque."""
	if not _chunk_cache.has(chunk_id):
		return false
	
	var chunk: ChunkData = _chunk_cache[chunk_id]
	var path := _get_chunk_file_path(chunk_id)
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("ChunkStateSerializer: Impossible d'ouvrir %s" % path)
		return false
	
	var data := chunk.to_dict()
	var json := JSON.stringify(data)
	
	if use_compression:
		file.store_var(json.compress(FileAccess.COMPRESSION_ZSTD))
	else:
		file.store_string(json)
	
	file.close()
	
	# Retirer de dirty
	var idx := _dirty_chunks.find(chunk_id)
	if idx >= 0:
		_dirty_chunks.remove_at(idx)
	
	chunk_state_saved.emit(chunk_id)
	return true


func _load_chunk_from_disk(chunk_id: String) -> ChunkData:
	"""Charge un chunk depuis le disque."""
	var path := _get_chunk_file_path(chunk_id)
	
	if not FileAccess.file_exists(path):
		return null
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	
	var json_string: String
	if use_compression:
		var compressed: PackedByteArray = file.get_var()
		json_string = compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_ZSTD).get_string_from_utf8()
	else:
		json_string = file.get_as_text()
	
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("ChunkStateSerializer: Erreur de parsing JSON pour %s" % chunk_id)
		return null
	
	var chunk := ChunkData.from_dict(json.data)
	chunk_state_loaded.emit(chunk_id)
	
	return chunk


func save_dirty_chunks() -> void:
	"""Sauvegarde tous les chunks modifiés."""
	for chunk_id in _dirty_chunks.duplicate():
		_save_chunk_to_disk(chunk_id)


func save_all_chunks() -> void:
	"""Sauvegarde tous les chunks en cache."""
	for chunk_id in _chunk_cache.keys():
		_save_chunk_to_disk(chunk_id)
	
	world_state_saved.emit()


func load_chunk(chunk_id: String) -> void:
	"""Force le chargement d'un chunk."""
	var chunk := _load_chunk_from_disk(chunk_id)
	if chunk:
		_chunk_cache[chunk_id] = chunk


# ==============================================================================
# INTÉGRATION AVEC CHUNKSTREAMER
# ==============================================================================

func on_chunk_loaded(chunk_id: String, chunk_node: Node3D) -> void:
	"""Appelé quand un chunk est chargé - restaure son état."""
	var chunk := _get_or_create_chunk(chunk_id)
	
	# Restaurer les entités mortes/supprimées
	for entity_id in chunk.entities.keys():
		var entity_data: Dictionary = chunk.entities[entity_id]
		var state: int = entity_data.get("state", EntityState.ALIVE)
		
		if state in [EntityState.DEAD, EntityState.REMOVED]:
			# Trouver et supprimer l'entité
			var entity := chunk_node.get_node_or_null(entity_id)
			if entity:
				entity.queue_free()
	
	# Restaurer les items au sol
	for item_id in chunk.items.keys():
		var item_data: Dictionary = chunk.items[item_id]
		var pos := Vector3(
			item_data.position.x,
			item_data.position.y,
			item_data.position.z
		)
		
		# TODO: Créer l'item avec le bon type
		# Pickup.spawn(item_data.data, pos, chunk_node)
	
	# Restaurer les états des interactables
	for interact_id in chunk.interactables.keys():
		var interactable := chunk_node.get_node_or_null(interact_id)
		if interactable and interactable.has_method("restore_state"):
			interactable.restore_state(chunk.interactables[interact_id].get("state", {}))


func on_chunk_unloaded(chunk_id: String) -> void:
	"""Appelé quand un chunk est déchargé - sauvegarde son état."""
	if auto_save_on_chunk_exit and chunk_id in _dirty_chunks:
		_save_chunk_to_disk(chunk_id)


# ==============================================================================
# NETTOYAGE
# ==============================================================================

func clear_chunk_state(chunk_id: String) -> void:
	"""Efface l'état d'un chunk (reset)."""
	_chunk_cache.erase(chunk_id)
	
	var path := _get_chunk_file_path(chunk_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	var idx := _dirty_chunks.find(chunk_id)
	if idx >= 0:
		_dirty_chunks.remove_at(idx)
	
	chunk_state_cleared.emit(chunk_id)


func clear_all_state() -> void:
	"""Efface tout l'état du monde (nouveau jeu)."""
	_chunk_cache.clear()
	_dirty_chunks.clear()
	
	# Supprimer tous les fichiers
	var dir := DirAccess.open(save_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(file_extension):
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_dirty_chunk_count() -> int:
	"""Retourne le nombre de chunks non sauvegardés."""
	return _dirty_chunks.size()


func get_cached_chunk_count() -> int:
	"""Retourne le nombre de chunks en cache."""
	return _chunk_cache.size()


func has_chunk_state(chunk_id: String) -> bool:
	"""Vérifie si un chunk a un état sauvegardé."""
	if _chunk_cache.has(chunk_id):
		return true
	return FileAccess.file_exists(_get_chunk_file_path(chunk_id))


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"cached_chunks": _chunk_cache.size(),
		"dirty_chunks": _dirty_chunks.size(),
		"total_entities_tracked": _total_entities_tracked,
		"total_items_tracked": _total_items_tracked
	}
