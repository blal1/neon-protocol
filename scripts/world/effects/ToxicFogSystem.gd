# ==============================================================================
# ToxicFogSystem.gd - Système de Brume Toxique
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les effets visuels et dégâts de la brume toxique du Sol Mort
# ==============================================================================

extends Node3D
class_name ToxicFogSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal player_entered_fog()
signal player_exited_fog()
signal damage_tick(damage: float)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Zone")
## Rayon de la zone toxique
@export var zone_radius: float = 30.0
## Hauteur de la brume
@export var fog_height: float = 8.0

@export_group("Dégâts")
## Dégâts par seconde
@export var damage_per_second: float = 5.0
## Intervalle entre les ticks de dégâts
@export var damage_interval: float = 1.0
## Multiplicateur si le joueur n'a pas de masque
@export var no_mask_multiplier: float = 2.0

@export_group("Visuel")
## Couleur de la brume
@export var fog_color: Color = Color(0.4, 0.5, 0.2, 0.6)
## Densité de particules
@export var particle_density: float = 50.0
## Vitesse de mouvement de la brume
@export var fog_speed: float = 0.5

@export_group("Audio")
## Son ambiant de la brume
@export var ambient_sound: AudioStream
## Volume du son ambiant (dB)
@export var ambient_volume_db: float = -10.0

# ==============================================================================
# NODES
# ==============================================================================

var _area: Area3D
var _collision_shape: CollisionShape3D
var _particles: GPUParticles3D
var _audio_player: AudioStreamPlayer3D
var _fog_mesh: MeshInstance3D

# ==============================================================================
# VARIABLES
# ==============================================================================

var _player_inside: bool = false
var _player_ref: Node3D = null
var _damage_timer: float = 0.0
var _has_protection: bool = false

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_setup_area()
	_setup_visuals()
	_setup_audio()


func _setup_area() -> void:
	"""Configure la zone de détection."""
	_area = Area3D.new()
	_area.name = "ToxicArea"
	_area.collision_layer = 0
	_area.collision_mask = 2  # Layer 2 = Player
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	add_child(_area)
	
	# Shape cylindrique
	_collision_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = zone_radius
	cylinder.height = fog_height
	_collision_shape.shape = cylinder
	_collision_shape.position.y = fog_height / 2
	_area.add_child(_collision_shape)


func _setup_visuals() -> void:
	"""Configure les effets visuels de brume."""
	# Mesh de base pour la zone
	_fog_mesh = MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = zone_radius
	cylinder_mesh.bottom_radius = zone_radius
	cylinder_mesh.height = fog_height
	_fog_mesh.mesh = cylinder_mesh
	_fog_mesh.position.y = fog_height / 2
	
	# Matériau semi-transparent
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = fog_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fog_mesh.material_override = material
	
	add_child(_fog_mesh)
	
	# Particules de brume
	_setup_particles()


func _setup_particles() -> void:
	"""Configure le système de particules."""
	_particles = GPUParticles3D.new()
	_particles.name = "FogParticles"
	_particles.amount = int(particle_density * zone_radius)
	_particles.lifetime = 4.0
	_particles.speed_scale = fog_speed
	_particles.randomness = 0.5
	_particles.position.y = fog_height / 2
	
	# Process material
	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = zone_radius * 0.9
	process_mat.direction = Vector3(1, 0.2, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 2.0
	process_mat.gravity = Vector3(0, -0.1, 0)
	process_mat.scale_min = 2.0
	process_mat.scale_max = 5.0
	process_mat.color = fog_color
	_particles.process_material = process_mat
	
	# Draw pass (quad simple)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_particles.draw_pass_1 = quad
	
	add_child(_particles)


func _setup_audio() -> void:
	"""Configure le son ambiant."""
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "AmbientAudio"
	_audio_player.stream = ambient_sound
	_audio_player.volume_db = ambient_volume_db
	_audio_player.max_distance = zone_radius * 2
	_audio_player.autoplay = true
	add_child(_audio_player)


# ==============================================================================
# MISE À JOUR
# ==============================================================================

func _process(delta: float) -> void:
	if not _player_inside or not _player_ref:
		return
	
	_damage_timer += delta
	
	if _damage_timer >= damage_interval:
		_damage_timer = 0.0
		_apply_damage()


func _apply_damage() -> void:
	"""Applique les dégâts au joueur."""
	var damage := damage_per_second * damage_interval
	
	# Vérifier si le joueur a une protection
	_has_protection = _check_player_protection()
	
	if not _has_protection:
		damage *= no_mask_multiplier
	
	damage_tick.emit(damage)
	
	# Appliquer les dégâts via le système de santé du joueur
	if _player_ref.has_method("take_damage"):
		_player_ref.take_damage(damage, "toxic")
	elif _player_ref.has_method("apply_damage"):
		_player_ref.apply_damage(damage)


func _check_player_protection() -> bool:
	"""Vérifie si le joueur a une protection contre le poison."""
	if _player_ref.has_method("has_status_protection"):
		return _player_ref.has_status_protection("toxic")
	if _player_ref.has_method("has_gas_mask"):
		return _player_ref.has_gas_mask()
	
	# Vérifier via le gestionnaire d'inventaire global
	if InventoryManager and InventoryManager.has_method("has_equipped_item"):
		return InventoryManager.has_equipped_item("gas_mask")
	
	return false


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_body_entered(body: Node3D) -> void:
	"""Appelé quand un corps entre dans la zone."""
	if body.is_in_group("player"):
		_player_inside = true
		_player_ref = body
		_damage_timer = 0.0
		player_entered_fog.emit()
		
		# Notification TTS pour accessibilité
		if TTSManager and TTSManager.has_method("speak"):
			TTSManager.speak("Attention: zone toxique détectée")


func _on_body_exited(body: Node3D) -> void:
	"""Appelé quand un corps sort de la zone."""
	if body.is_in_group("player"):
		_player_inside = false
		_player_ref = null
		player_exited_fog.emit()
		
		# Notification TTS
		if TTSManager and TTSManager.has_method("speak"):
			TTSManager.speak("Sortie de zone toxique")


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

## Vérifie si le joueur est dans la brume
func is_player_inside() -> bool:
	return _player_inside


## Définit le rayon de la zone
func set_zone_radius(radius: float) -> void:
	zone_radius = radius
	if _collision_shape and _collision_shape.shape is CylinderShape3D:
		(_collision_shape.shape as CylinderShape3D).radius = radius
	if _fog_mesh and _fog_mesh.mesh is CylinderMesh:
		(_fog_mesh.mesh as CylinderMesh).top_radius = radius
		(_fog_mesh.mesh as CylinderMesh).bottom_radius = radius


## Définit la couleur de la brume
func set_fog_color(color: Color) -> void:
	fog_color = color
	if _fog_mesh and _fog_mesh.material_override:
		(_fog_mesh.material_override as StandardMaterial3D).albedo_color = color
	if _particles and _particles.process_material:
		(_particles.process_material as ParticleProcessMaterial).color = color


## Active/désactive la zone
func set_active(active: bool) -> void:
	_area.monitoring = active
	_particles.emitting = active
	visible = active
