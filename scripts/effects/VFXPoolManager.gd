# ==============================================================================
# VFXPoolManager.gd - Gestionnaire de Pool VFX/Particules
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Pool de particules GPU pour éviter les stutters sur mobile.
# Pré-chargement explosions, impacts, muzzle flashes, etc.
# ==============================================================================

extends Node
class_name VFXPoolManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal vfx_spawned(vfx_id: String, instance: Node3D)
signal vfx_returned(vfx_id: String)
signal pool_exhausted(vfx_id: String)
signal pool_expanded(vfx_id: String, new_size: int)

# ==============================================================================
# TYPES DE VFX
# ==============================================================================

enum VFXType {
	MUZZLE_FLASH,
	BULLET_IMPACT_METAL,
	BULLET_IMPACT_FLESH,
	BULLET_IMPACT_CONCRETE,
	EXPLOSION_SMALL,
	EXPLOSION_MEDIUM,
	EXPLOSION_LARGE,
	SPARK,
	SMOKE,
	BLOOD_SPRAY,
	SHIELD_HIT,
	ELECTRIC_ARC,
	NEON_SHATTER,
	CYBER_GLITCH,
	HEAL_EFFECT,
	DAMAGE_NUMBER
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Pool Sizes")
@export var default_pool_size: int = 20
@export var max_pool_size: int = 100
@export var auto_expand: bool = true
@export var expand_amount: int = 5

@export_group("Performance")
@export var warm_up_on_ready: bool = true
@export var warm_up_frames: int = 3
@export var cull_unused_after: float = 60.0

@export_group("Scenes")
@export var vfx_scenes: Dictionary = {}  # VFXType -> PackedScene

# ==============================================================================
# VARIABLES
# ==============================================================================

## Pools par type
var _pools: Dictionary = {}  # VFXType -> Array[Node3D]

## Instances actives
var _active_instances: Dictionary = {}  # instance_id -> {type, spawn_time}

## Stats
var _spawn_counts: Dictionary = {}  # VFXType -> int
var _last_used: Dictionary = {}  # VFXType -> timestamp

## Container
var _container: Node3D = null

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_create_container()
	_register_default_vfx()
	
	if warm_up_on_ready:
		_warm_up_pools()


func _create_container() -> void:
	"""Crée le container pour les VFX."""
	_container = Node3D.new()
	_container.name = "VFXContainer"
	add_child(_container)


func _register_default_vfx() -> void:
	"""Enregistre les VFX par défaut si pas de scènes définies."""
	for vfx_type in VFXType.values():
		if not _pools.has(vfx_type):
			_pools[vfx_type] = []
			_spawn_counts[vfx_type] = 0
			_last_used[vfx_type] = 0.0


func _warm_up_pools() -> void:
	"""Pré-instancie les VFX sur plusieurs frames."""
	var types := VFXType.values()
	var current_frame := 0
	
	for vfx_type in types:
		# Créer quelques instances de base
		_expand_pool(vfx_type, mini(default_pool_size, 5))


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	_cleanup_finished_vfx()
	_cull_unused_pools(delta)


func _cleanup_finished_vfx() -> void:
	"""Nettoie les VFX terminés."""
	var to_return := []
	
	for instance_id in _active_instances.keys():
		var data: Dictionary = _active_instances[instance_id]
		var instance: Node3D = instance_from_id(instance_id)
		
		if not is_instance_valid(instance):
			to_return.append(instance_id)
			continue
		
		# Vérifier si les particules sont finies
		if _is_vfx_finished(instance):
			to_return.append(instance_id)
			_return_to_pool(instance, data.type)
	
	for instance_id in to_return:
		_active_instances.erase(instance_id)


func _is_vfx_finished(instance: Node3D) -> bool:
	"""Vérifie si un VFX a terminé."""
	# Vérifier GPUParticles3D
	var particles := instance.get_node_or_null("GPUParticles3D")
	if particles is GPUParticles3D:
		return not particles.emitting and particles.get_process_material() != null
	
	# Vérifier CPUParticles3D
	var cpu_particles := instance.get_node_or_null("CPUParticles3D")
	if cpu_particles is CPUParticles3D:
		return not cpu_particles.emitting
	
	# Vérifier AnimationPlayer
	var anim := instance.get_node_or_null("AnimationPlayer")
	if anim is AnimationPlayer:
		return not anim.is_playing()
	
	# Par défaut, vérifier le temps de vie
	if instance.has_meta("lifetime"):
		var spawn_time: float = instance.get_meta("spawn_time", 0)
		var lifetime: float = instance.get_meta("lifetime", 1.0)
		return Time.get_ticks_msec() / 1000.0 - spawn_time > lifetime
	
	return false


func _cull_unused_pools(_delta: float) -> void:
	"""Réduit les pools inutilisés."""
	var current_time := Time.get_ticks_msec() / 1000.0
	
	for vfx_type in _pools.keys():
		var last_use: float = _last_used.get(vfx_type, 0)
		if current_time - last_use > cull_unused_after:
			var pool: Array = _pools[vfx_type]
			# Garder au moins 3 instances
			while pool.size() > 3:
				var instance: Node3D = pool.pop_back()
				if is_instance_valid(instance):
					instance.queue_free()


# ==============================================================================
# SPAWN VFX
# ==============================================================================

func spawn(vfx_type: VFXType, position: Vector3, rotation: Vector3 = Vector3.ZERO, config: Dictionary = {}) -> Node3D:
	"""Spawn un VFX depuis le pool."""
	var instance := _get_from_pool(vfx_type)
	
	if not instance:
		pool_exhausted.emit(VFXType.keys()[vfx_type])
		return null
	
	# Configurer la position
	instance.global_position = position
	instance.rotation = rotation
	
	# Appliquer la configuration
	_apply_config(instance, config)
	
	# Activer
	instance.visible = true
	instance.set_process(true)
	
	# Démarrer les particules
	_start_vfx(instance)
	
	# Tracker
	var instance_id := instance.get_instance_id()
	_active_instances[instance_id] = {
		"type": vfx_type,
		"spawn_time": Time.get_ticks_msec() / 1000.0
	}
	instance.set_meta("spawn_time", Time.get_ticks_msec() / 1000.0)
	
	_spawn_counts[vfx_type] += 1
	_last_used[vfx_type] = Time.get_ticks_msec() / 1000.0
	
	vfx_spawned.emit(VFXType.keys()[vfx_type], instance)
	
	return instance


func spawn_at_node(vfx_type: VFXType, target: Node3D, offset: Vector3 = Vector3.ZERO, config: Dictionary = {}) -> Node3D:
	"""Spawn un VFX à la position d'un node."""
	var position := target.global_position + offset
	return spawn(vfx_type, position, Vector3.ZERO, config)


func spawn_between(vfx_type: VFXType, from: Vector3, to: Vector3, config: Dictionary = {}) -> Node3D:
	"""Spawn un VFX entre deux points (ex: arc électrique)."""
	var mid_point := (from + to) / 2
	var direction := (to - from).normalized()
	var rotation := Vector3.ZERO
	
	# Calculer la rotation pour pointer vers la cible
	if direction.length() > 0.01:
		rotation.y = atan2(direction.x, direction.z)
		rotation.x = -asin(direction.y)
	
	config["scale_z"] = from.distance_to(to)
	
	return spawn(vfx_type, mid_point, rotation, config)


func _apply_config(instance: Node3D, config: Dictionary) -> void:
	"""Applique la configuration au VFX."""
	# Échelle
	if config.has("scale"):
		instance.scale = Vector3.ONE * config.scale
	if config.has("scale_z"):
		instance.scale.z = config.scale_z
	
	# Couleur
	if config.has("color"):
		_set_vfx_color(instance, config.color)
	
	# Lifetime
	if config.has("lifetime"):
		instance.set_meta("lifetime", config.lifetime)
	else:
		instance.set_meta("lifetime", 2.0)
	
	# Intensité
	if config.has("intensity"):
		_set_vfx_intensity(instance, config.intensity)


func _set_vfx_color(instance: Node3D, color: Color) -> void:
	"""Définit la couleur du VFX."""
	var particles := instance.get_node_or_null("GPUParticles3D")
	if particles is GPUParticles3D and particles.process_material:
		var mat: ParticleProcessMaterial = particles.process_material
		mat.color = color


func _set_vfx_intensity(instance: Node3D, intensity: float) -> void:
	"""Définit l'intensité du VFX."""
	var particles := instance.get_node_or_null("GPUParticles3D")
	if particles is GPUParticles3D:
		particles.amount_ratio = clampf(intensity, 0.1, 2.0)


func _start_vfx(instance: Node3D) -> void:
	"""Démarre l'émission des particules."""
	for child in instance.get_children():
		if child is GPUParticles3D:
			child.emitting = true
			child.restart()
		elif child is CPUParticles3D:
			child.emitting = true
			child.restart()
		elif child is AnimationPlayer:
			child.play("default")
		elif child is OmniLight3D or child is SpotLight3D:
			child.visible = true


# ==============================================================================
# POOL MANAGEMENT
# ==============================================================================

func _get_from_pool(vfx_type: VFXType) -> Node3D:
	"""Récupère une instance du pool."""
	if not _pools.has(vfx_type):
		_pools[vfx_type] = []
	
	var pool: Array = _pools[vfx_type]
	
	# Chercher une instance disponible
	for instance in pool:
		if is_instance_valid(instance) and not instance.visible:
			return instance
	
	# Pool épuisé - expand si autorisé
	if auto_expand and pool.size() < max_pool_size:
		_expand_pool(vfx_type, expand_amount)
		pool_expanded.emit(VFXType.keys()[vfx_type], pool.size())
		
		# Retry
		for instance in pool:
			if is_instance_valid(instance) and not instance.visible:
				return instance
	
	return null


func _return_to_pool(instance: Node3D, _vfx_type: VFXType) -> void:
	"""Retourne une instance au pool."""
	if not is_instance_valid(instance):
		return
	
	# Désactiver
	instance.visible = false
	instance.set_process(false)
	
	# Stopper les particules
	for child in instance.get_children():
		if child is GPUParticles3D:
			child.emitting = false
		elif child is CPUParticles3D:
			child.emitting = false
		elif child is AnimationPlayer:
			child.stop()
		elif child is OmniLight3D or child is SpotLight3D:
			child.visible = false
	
	# Repositionner hors vue
	instance.global_position = Vector3(0, -1000, 0)
	
	vfx_returned.emit(VFXType.keys()[_vfx_type])


func _expand_pool(vfx_type: VFXType, amount: int) -> void:
	"""Agrandit un pool."""
	if not _pools.has(vfx_type):
		_pools[vfx_type] = []
	
	for i in range(amount):
		var instance := _create_vfx_instance(vfx_type)
		if instance:
			_pools[vfx_type].append(instance)


func _create_vfx_instance(vfx_type: VFXType) -> Node3D:
	"""Crée une nouvelle instance de VFX."""
	var instance: Node3D
	
	# Charger depuis les scènes définies
	if vfx_scenes.has(vfx_type) and vfx_scenes[vfx_type] is PackedScene:
		instance = vfx_scenes[vfx_type].instantiate() as Node3D
	else:
		# Créer un VFX procédural par défaut
		instance = _create_default_vfx(vfx_type)
	
	if instance:
		instance.name = "VFX_%s_%d" % [VFXType.keys()[vfx_type], randi()]
		instance.visible = false
		_container.add_child(instance)
	
	return instance


func _create_default_vfx(vfx_type: VFXType) -> Node3D:
	"""Crée un VFX par défaut (procédural)."""
	var root := Node3D.new()
	
	var particles := GPUParticles3D.new()
	particles.name = "GPUParticles3D"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	
	# Material par défaut
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	
	match vfx_type:
		VFXType.MUZZLE_FLASH:
			particles.amount = 16
			particles.lifetime = 0.1
			mat.initial_velocity_min = 5.0
			mat.initial_velocity_max = 10.0
			mat.color = Color(1, 0.8, 0.3)
		
		VFXType.SPARK:
			particles.amount = 20
			particles.lifetime = 0.3
			mat.initial_velocity_min = 3.0
			mat.initial_velocity_max = 8.0
			mat.gravity = Vector3(0, -5, 0)
			mat.color = Color(1, 0.6, 0.2)
		
		VFXType.EXPLOSION_SMALL:
			particles.amount = 50
			particles.lifetime = 0.5
			mat.emission_sphere_radius = 0.5
			mat.initial_velocity_min = 5.0
			mat.initial_velocity_max = 15.0
			mat.color = Color(1, 0.5, 0.1)
		
		VFXType.BLOOD_SPRAY:
			particles.amount = 30
			particles.lifetime = 0.4
			mat.initial_velocity_min = 2.0
			mat.initial_velocity_max = 6.0
			mat.gravity = Vector3(0, -10, 0)
			mat.color = Color(0.8, 0.1, 0.1)
		
		VFXType.ELECTRIC_ARC:
			particles.amount = 10
			particles.lifetime = 0.2
			mat.color = Color(0.3, 0.8, 1.0)
		
		_:
			particles.amount = 20
			particles.lifetime = 0.5
			mat.color = Color.WHITE
	
	particles.process_material = mat
	
	# Mesh simple pour les particules
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = mesh
	
	root.add_child(particles)
	
	# Ajouter lumière flash pour certains effets
	if vfx_type in [VFXType.MUZZLE_FLASH, VFXType.EXPLOSION_SMALL, VFXType.EXPLOSION_MEDIUM]:
		var light := OmniLight3D.new()
		light.light_color = mat.color
		light.light_energy = 2.0
		light.omni_range = 3.0
		light.omni_attenuation = 2.0
		root.add_child(light)
	
	return root


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func register_vfx_scene(vfx_type: VFXType, scene: PackedScene, pool_size: int = -1) -> void:
	"""Enregistre une scène VFX custom."""
	vfx_scenes[vfx_type] = scene
	
	var size := pool_size if pool_size > 0 else default_pool_size
	_expand_pool(vfx_type, size)


func get_pool_size(vfx_type: VFXType) -> int:
	"""Retourne la taille d'un pool."""
	return _pools.get(vfx_type, []).size()


func get_active_count() -> int:
	"""Retourne le nombre de VFX actifs."""
	return _active_instances.size()


func get_total_spawned(vfx_type: VFXType) -> int:
	"""Retourne le nombre total de spawns pour un type."""
	return _spawn_counts.get(vfx_type, 0)


func clear_all() -> void:
	"""Nettoie tous les VFX actifs."""
	for instance_id in _active_instances.keys():
		var instance: Node3D = instance_from_id(instance_id)
		if is_instance_valid(instance):
			var data: Dictionary = _active_instances[instance_id]
			_return_to_pool(instance, data.type)
	
	_active_instances.clear()


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	var pool_sizes := {}
	for vfx_type in _pools.keys():
		pool_sizes[VFXType.keys()[vfx_type]] = _pools[vfx_type].size()
	
	return {
		"active_vfx": _active_instances.size(),
		"pool_sizes": pool_sizes,
		"total_spawned": _spawn_counts.values().reduce(func(a, b): return a + b, 0)
	}
