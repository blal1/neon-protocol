# ==============================================================================
# ImpactEffects.gd - Système de particules d'impact
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère des effets visuels lors des impacts de combat
# ==============================================================================

extends Node
class_name ImpactEffects

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal effect_spawned(effect_type: String, position: Vector3)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const EFFECT_LIFETIME := 1.0

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var hit_particles_count: int = 15
@export var spark_color: Color = Color(1.0, 0.8, 0.2)
@export var blood_color: Color = Color(0.8, 0.1, 0.1)
@export var cyber_color: Color = Color(0, 1, 1)

# ==============================================================================
# POOL D'EFFETS
# ==============================================================================
var _particle_pool: Array[GPUParticles3D] = []
var _pool_size: int = 10

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialise le pool de particules."""
	_create_particle_pool()


# ==============================================================================
# CRÉATION DU POOL
# ==============================================================================

func _create_particle_pool() -> void:
	"""Crée un pool de systèmes de particules réutilisables."""
	for i in range(_pool_size):
		var particles := GPUParticles3D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 0.9
		particles.amount = hit_particles_count
		particles.lifetime = 0.5
		
		# Material de particules
		var material := ParticleProcessMaterial.new()
		material.direction = Vector3(0, 1, 0)
		material.spread = 180.0
		material.initial_velocity_min = 3.0
		material.initial_velocity_max = 8.0
		material.gravity = Vector3(0, -10, 0)
		material.scale_min = 0.05
		material.scale_max = 0.15
		material.color = spark_color
		particles.process_material = material
		
		# Mesh de particule (petite sphère)
		var mesh := SphereMesh.new()
		mesh.radius = 0.03
		mesh.height = 0.06
		particles.draw_pass_1 = mesh
		
		add_child(particles)
		_particle_pool.append(particles)


func _get_available_particles() -> GPUParticles3D:
	"""Retourne un système de particules disponible."""
	for particles in _particle_pool:
		if not particles.emitting:
			return particles
	
	# Tous occupés, créer un nouveau temporairement
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	add_child(particles)
	return particles


# ==============================================================================
# EFFETS D'IMPACT
# ==============================================================================

func spawn_hit_effect(position: Vector3, normal: Vector3 = Vector3.UP, effect_type: String = "spark") -> void:
	"""
	Génère un effet d'impact à la position donnée.
	@param position: Position mondiale
	@param normal: Direction de l'impact
	@param effect_type: Type d'effet (spark, blood, cyber, electric)
	"""
	var particles := _get_available_particles()
	particles.global_position = position
	
	# Configurer selon le type
	var material: ParticleProcessMaterial = particles.process_material
	
	match effect_type:
		"spark":
			material.color = spark_color
			material.initial_velocity_min = 3.0
			material.initial_velocity_max = 8.0
		"blood":
			material.color = blood_color
			material.initial_velocity_min = 2.0
			material.initial_velocity_max = 5.0
		"cyber":
			material.color = cyber_color
			material.initial_velocity_min = 4.0
			material.initial_velocity_max = 10.0
		"electric":
			material.color = Color(0.5, 0.8, 1.0)
			material.initial_velocity_min = 5.0
			material.initial_velocity_max = 12.0
	
	# Orienter vers la normale
	if normal != Vector3.UP:
		material.direction = normal
	
	particles.emitting = true
	effect_spawned.emit(effect_type, position)


func spawn_slash_effect(position: Vector3, direction: Vector3) -> void:
	"""Génère un effet de slash (pour attaques mêlée)."""
	# Créer un mesh temporaire pour le trail de slash
	var slash := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.02, 1.5)
	slash.mesh = mesh
	
	# Material émissif
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cyber_color
	mat.emission_enabled = true
	mat.emission = cyber_color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash.set_surface_override_material(0, mat)
	
	# Positionner et orienter
	slash.global_position = position
	slash.look_at(position + direction)
	
	get_tree().current_scene.add_child(slash)
	
	# Animation
	var tween := create_tween()
	tween.tween_property(slash, "scale", Vector3(1.5, 1.5, 0.1), 0.2)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(slash.queue_free)


func spawn_explosion_effect(position: Vector3, radius: float = 2.0) -> void:
	"""Génère un effet d'explosion."""
	var particles := _get_available_particles()
	particles.global_position = position
	particles.amount = 30
	
	var material: ParticleProcessMaterial = particles.process_material
	material.color = Color(1.0, 0.5, 0.1)
	material.initial_velocity_min = radius * 2
	material.initial_velocity_max = radius * 4
	material.spread = 180.0
	
	particles.emitting = true
	
	# Flash lumineux
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 5.0
	light.omni_range = radius * 2
	light.global_position = position
	get_tree().current_scene.add_child(light)
	
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)
	
	effect_spawned.emit("explosion", position)


func spawn_heal_effect(position: Vector3) -> void:
	"""Génère un effet de soin."""
	var particles := _get_available_particles()
	particles.global_position = position
	
	var material: ParticleProcessMaterial = particles.process_material
	material.color = Color(0.2, 1.0, 0.4)
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, 2, 0)  # Monte vers le haut
	
	particles.emitting = true
	effect_spawned.emit("heal", position)


# ==============================================================================
# SINGLETON ACCESS
# ==============================================================================

static var _instance: ImpactEffects = null

static func get_instance() -> ImpactEffects:
	"""Retourne l'instance singleton."""
	if not _instance:
		_instance = ImpactEffects.new()
	return _instance
