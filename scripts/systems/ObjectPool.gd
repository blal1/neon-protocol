# ==============================================================================
# ObjectPool.gd - Système de pooling d'objets
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Réutilise les objets au lieu de les créer/détruire
# Réduit les allocations mémoire et améliore les performances
# ==============================================================================

extends Node
class_name ObjectPool

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal object_spawned(obj: Node)
signal object_returned(obj: Node)
signal pool_exhausted(pool_name: String)

# ==============================================================================
# CLASSES
# ==============================================================================

class Pool:
	var scene: PackedScene
	var available: Array[Node] = []
	var in_use: Array[Node] = []
	var max_size: int = 50
	var grow_amount: int = 5
	var parent: Node
	
	func get_object() -> Node:
		if available.is_empty():
			if in_use.size() >= max_size:
				return null
			_grow()
		
		if available.is_empty():
			return null
		
		var obj: Node = available.pop_back()
		in_use.append(obj)
		return obj
	
	func return_object(obj: Node) -> void:
		if obj in in_use:
			in_use.erase(obj)
			available.append(obj)
			
			# Désactiver l'objet
			if obj is Node3D:
				obj.visible = false
				obj.process_mode = Node.PROCESS_MODE_DISABLED
			elif obj is Node2D:
				obj.visible = false
				obj.process_mode = Node.PROCESS_MODE_DISABLED
	
	func _grow() -> void:
		var to_add := mini(grow_amount, max_size - in_use.size() - available.size())
		for i in range(to_add):
			var obj: Node = scene.instantiate()
			if obj is Node3D:
				obj.visible = false
			obj.process_mode = Node.PROCESS_MODE_DISABLED
			parent.add_child(obj)
			available.append(obj)
	
	func clear() -> void:
		for obj in available:
			obj.queue_free()
		for obj in in_use:
			obj.queue_free()
		available.clear()
		in_use.clear()

# ==============================================================================
# VARIABLES
# ==============================================================================
var _pools: Dictionary = {}  # pool_name -> Pool

# ==============================================================================
# CRÉATION DE POOLS
# ==============================================================================

func create_pool(pool_name: String, scene: PackedScene, initial_size: int = 10, max_size: int = 50, parent: Node = null) -> void:
	"""
	Crée un nouveau pool d'objets.
	@param pool_name: Nom unique du pool
	@param scene: Scène à instancier
	@param initial_size: Nombre d'objets pré-créés
	@param max_size: Taille maximale du pool
	@param parent: Nœud parent pour les objets (défaut: ce nœud)
	"""
	if _pools.has(pool_name):
		push_warning("ObjectPool: Pool déjà existant: " + pool_name)
		return
	
	var pool := Pool.new()
	pool.scene = scene
	pool.max_size = max_size
	pool.parent = parent if parent else self
	
	# Pré-créer les objets
	pool.grow_amount = initial_size
	pool._grow()
	pool.grow_amount = 5
	
	_pools[pool_name] = pool


func create_enemy_pool(scene: PackedScene, pool_name: String = "enemies") -> void:
	"""Crée un pool pour les ennemis."""
	create_pool(pool_name, scene, 10, 30)


func create_projectile_pool(scene: PackedScene, pool_name: String = "projectiles") -> void:
	"""Crée un pool pour les projectiles."""
	create_pool(pool_name, scene, 20, 100)


func create_effect_pool(scene: PackedScene, pool_name: String = "effects") -> void:
	"""Crée un pool pour les effets visuels."""
	create_pool(pool_name, scene, 15, 50)


# ==============================================================================
# RÉCUPÉRATION D'OBJETS
# ==============================================================================

func get_object(pool_name: String) -> Node:
	"""
	Récupère un objet du pool.
	@return: L'objet ou null si pool épuisé
	"""
	if not _pools.has(pool_name):
		push_warning("ObjectPool: Pool inconnu: " + pool_name)
		return null
	
	var pool: Pool = _pools[pool_name]
	var obj := pool.get_object()
	
	if obj == null:
		pool_exhausted.emit(pool_name)
		return null
	
	# Réactiver l'objet
	if obj is Node3D:
		obj.visible = true
	obj.process_mode = Node.PROCESS_MODE_INHERIT
	
	object_spawned.emit(obj)
	return obj


func spawn_at(pool_name: String, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> Node:
	"""
	Récupère et positionne un objet 3D.
	"""
	var obj := get_object(pool_name)
	if obj and obj is Node3D:
		obj.global_position = position
		obj.rotation = rotation
	return obj


func spawn_2d_at(pool_name: String, position: Vector2) -> Node:
	"""Récupère et positionne un objet 2D."""
	var obj := get_object(pool_name)
	if obj and obj is Node2D:
		obj.global_position = position
	return obj


# ==============================================================================
# RETOUR D'OBJETS
# ==============================================================================

func return_object(pool_name: String, obj: Node) -> void:
	"""Retourne un objet au pool."""
	if not _pools.has(pool_name):
		push_warning("ObjectPool: Pool inconnu: " + pool_name)
		obj.queue_free()
		return
	
	var pool: Pool = _pools[pool_name]
	pool.return_object(obj)
	object_returned.emit(obj)


func return_all(pool_name: String) -> void:
	"""Retourne tous les objets d'un pool."""
	if not _pools.has(pool_name):
		return
	
	var pool: Pool = _pools[pool_name]
	for obj in pool.in_use.duplicate():
		pool.return_object(obj)


# ==============================================================================
# GESTION DES POOLS
# ==============================================================================

func clear_pool(pool_name: String) -> void:
	"""Vide et supprime un pool."""
	if _pools.has(pool_name):
		_pools[pool_name].clear()
		_pools.erase(pool_name)


func clear_all_pools() -> void:
	"""Vide tous les pools."""
	for pool_name in _pools.keys():
		_pools[pool_name].clear()
	_pools.clear()


func get_pool_stats(pool_name: String) -> Dictionary:
	"""Retourne les statistiques d'un pool."""
	if not _pools.has(pool_name):
		return {}
	
	var pool: Pool = _pools[pool_name]
	return {
		"available": pool.available.size(),
		"in_use": pool.in_use.size(),
		"max_size": pool.max_size,
		"usage_percent": (float(pool.in_use.size()) / float(pool.max_size)) * 100.0
	}


func get_all_pools_stats() -> Dictionary:
	"""Retourne les stats de tous les pools."""
	var result := {}
	for pool_name in _pools:
		result[pool_name] = get_pool_stats(pool_name)
	return result


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func has_pool(pool_name: String) -> bool:
	"""Vérifie si un pool existe."""
	return _pools.has(pool_name)


func get_available_count(pool_name: String) -> int:
	"""Retourne le nombre d'objets disponibles."""
	if _pools.has(pool_name):
		return _pools[pool_name].available.size()
	return 0
