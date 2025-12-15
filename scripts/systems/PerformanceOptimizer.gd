# ==============================================================================
# PerformanceOptimizer.gd - Optimisations de performance
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les optimisations : streaming audio, occlusion, LOD
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal optimization_applied(optimization_name: String)
signal performance_warning(message: String)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Streaming Audio")
@export var audio_streaming_enabled: bool = true
@export var audio_unload_distance: float = 50.0
@export var audio_preload_distance: float = 30.0

@export_group("Occlusion Culling")
@export var occlusion_enabled: bool = true
@export var occlusion_check_interval: float = 0.1

@export_group("LOD System")
@export var lod_enabled: bool = true
@export var lod_distances: Array[float] = [10.0, 25.0, 50.0]

@export_group("Object Pooling")
@export var pool_enabled: bool = true
@export var max_pool_size: int = 50

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _camera: Camera3D = null
var _player: Node3D = null
var _occlusion_timer: float = 0.0
var _loaded_audio_streams: Dictionary = {}
var _object_pools: Dictionary = {}

# Performance stats
var _fps_history: Array[float] = []
var _memory_warnings: int = 0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	# Trouver les références
	_find_references()
	
	# Optimisations initiales
	_apply_initial_optimizations()


func _process(delta: float) -> void:
	"""Mise à jour des optimisations."""
	# Occlusion culling
	if occlusion_enabled:
		_occlusion_timer += delta
		if _occlusion_timer >= occlusion_check_interval:
			_occlusion_timer = 0.0
			_update_occlusion()
	
	# Monitor FPS
	_monitor_fps()


# ==============================================================================
# OPTIMISATIONS INITIALES
# ==============================================================================

func _apply_initial_optimizations() -> void:
	"""Applique les optimisations au démarrage."""
	# Réduire la qualité des ombres sur mobile
	if OS.has_feature("mobile"):
		RenderingServer.directional_shadow_quality_set(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		RenderingServer.positional_shadow_quality_set(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		optimization_applied.emit("mobile_shadows")
	
	# Limiter le nombre de lumières simultanées
	Engine.max_fps = 60
	
	print("PerformanceOptimizer: Optimisations initiales appliquées")


# ==============================================================================
# AUDIO STREAMING
# ==============================================================================

func stream_audio(path: String, position: Vector3) -> AudioStream:
	"""
	Charge un audio stream à la demande.
	Décharge ceux trop éloignés.
	"""
	if not audio_streaming_enabled:
		return load(path) if ResourceLoader.exists(path) else null
	
	# Vérifier si déjà chargé
	if _loaded_audio_streams.has(path):
		return _loaded_audio_streams[path]
	
	# Vérifier la distance
	if _player:
		var distance := position.distance_to(_player.global_position)
		if distance > audio_preload_distance:
			return null  # Trop loin pour charger
	
	# Charger en background
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		_loaded_audio_streams[path] = stream
		return stream
	
	return null


func unload_distant_audio() -> void:
	"""Décharge les audios trop éloignés."""
	if not _player:
		return
	
	var to_unload: Array[String] = []
	
	# Cette fonction nécessite le tracking des positions des sons
	# Pour l'instant on décharge après un timeout
	
	for path in to_unload:
		_loaded_audio_streams.erase(path)


# ==============================================================================
# OCCLUSION CULLING
# ==============================================================================

func _update_occlusion() -> void:
	"""Met à jour le culling basé sur l'occlusion."""
	if not _camera:
		_find_references()
		return
	
	var meshes := get_tree().get_nodes_in_group("occludable")
	var cam_pos := _camera.global_position
	var cam_forward := -_camera.global_transform.basis.z
	
	for mesh in meshes:
		if not mesh is MeshInstance3D:
			continue
		
		var to_mesh := mesh.global_position - cam_pos
		var distance := to_mesh.length()
		
		# Frustum culling simple (angle)
		var dot := cam_forward.normalized().dot(to_mesh.normalized())
		
		# Cacher si derrière la caméra ou trop loin
		if dot < 0.0 or distance > 100.0:
			mesh.visible = false
		else:
			mesh.visible = true
			
			# LOD basé sur la distance
			if lod_enabled:
				_apply_lod(mesh, distance)


func _apply_lod(mesh: MeshInstance3D, distance: float) -> void:
	"""Applique le niveau de détail selon la distance."""
	# Chercher des variations LOD
	var lod_level := 0
	
	for i in range(lod_distances.size()):
		if distance > lod_distances[i]:
			lod_level = i + 1
	
	# Appliquer via custom shader ou mesh swap
	# Pour l'instant: réduire la visibilité des petits détails
	if mesh.has_meta("base_scale"):
		var base_scale: Vector3 = mesh.get_meta("base_scale")
		if lod_level >= 2:
			mesh.scale = base_scale * 0.8
		else:
			mesh.scale = base_scale


# ==============================================================================
# OBJECT POOLING
# ==============================================================================

func get_pooled_object(pool_name: String, scene: PackedScene) -> Node:
	"""Récupère un objet du pool ou en crée un nouveau."""
	if not pool_enabled:
		return scene.instantiate()
	
	# Créer le pool si nécessaire
	if not _object_pools.has(pool_name):
		_object_pools[pool_name] = []
	
	var pool: Array = _object_pools[pool_name]
	
	# Chercher un objet inactif
	for obj in pool:
		if is_instance_valid(obj) and not obj.is_inside_tree():
			return obj
	
	# Créer un nouveau si le pool n'est pas plein
	if pool.size() < max_pool_size:
		var new_obj := scene.instantiate()
		pool.append(new_obj)
		return new_obj
	
	# Pool plein, créer temporairement
	return scene.instantiate()


func return_to_pool(pool_name: String, obj: Node) -> void:
	"""Retourne un objet au pool."""
	if not pool_enabled:
		obj.queue_free()
		return
	
	if not _object_pools.has(pool_name):
		obj.queue_free()
		return
	
	# Retirer de l'arbre mais garder en mémoire
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	
	# Reset état
	if obj.has_method("reset"):
		obj.reset()


func clear_pool(pool_name: String) -> void:
	"""Vide un pool."""
	if not _object_pools.has(pool_name):
		return
	
	for obj in _object_pools[pool_name]:
		if is_instance_valid(obj):
			obj.queue_free()
	
	_object_pools[pool_name].clear()


# ==============================================================================
# MONITORING
# ==============================================================================

func _monitor_fps() -> void:
	"""Surveille les FPS et avertit si problèmes."""
	var fps := Engine.get_frames_per_second()
	
	_fps_history.append(fps)
	if _fps_history.size() > 60:
		_fps_history.pop_front()
	
	# Vérifier moyenne
	var avg: float = 0.0
	for f in _fps_history:
		avg += f
	avg /= _fps_history.size()
	
	if avg < 30.0:
		performance_warning.emit("Low FPS: %.1f" % avg)


func get_average_fps() -> float:
	"""Retourne la moyenne des FPS."""
	if _fps_history.is_empty():
		return 60.0
	
	var avg: float = 0.0
	for f in _fps_history:
		avg += f
	return avg / _fps_history.size()


func get_memory_usage_mb() -> float:
	"""Retourne l'utilisation mémoire en MB."""
	return OS.get_static_memory_usage() / 1048576.0


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_references() -> void:
	"""Trouve les références nécessaires."""
	# Caméra
	_camera = get_viewport().get_camera_3d()
	
	# Joueur
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func set_quality_preset(preset: String) -> void:
	"""Applique un preset de qualité."""
	match preset:
		"low":
			lod_distances = [5.0, 15.0, 30.0]
			occlusion_enabled = true
			Engine.max_fps = 30
			RenderingServer.directional_shadow_quality_set(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		"medium":
			lod_distances = [10.0, 25.0, 50.0]
			occlusion_enabled = true
			Engine.max_fps = 60
			RenderingServer.directional_shadow_quality_set(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		"high":
			lod_distances = [20.0, 40.0, 80.0]
			occlusion_enabled = false
			Engine.max_fps = 120
			RenderingServer.directional_shadow_quality_set(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	
	optimization_applied.emit("preset_" + preset)
