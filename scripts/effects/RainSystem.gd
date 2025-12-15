# ==============================================================================
# RainSystem.gd - Système de Pluie Optimisé Mobile
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# La pluie suit le joueur et ne tombe pas à l'intérieur
# Optimisé pour téléphones milieu de gamme
# ==============================================================================

extends Node3D
class_name RainSystem

# ==============================================================================
# CONSTANTES OPTIMISATION MOBILE
# ==============================================================================
# Ces valeurs sont calibrées pour ~60 FPS sur mobile milieu de gamme
const MAX_PARTICLES_MOBILE: int = 500  # Max 500 particules (vs 2000+ sur PC)
const EMISSION_RATE_LIGHT: float = 100.0  # Pluie légère
const EMISSION_RATE_MEDIUM: float = 250.0  # Pluie normale
const EMISSION_RATE_HEAVY: float = 400.0  # Pluie forte

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export_group("Cible")
@export var follow_target: Node3D  ## Le joueur à suivre
@export var height_above_target: float = 15.0  ## Hauteur de spawn de la pluie

@export_group("Zone de Pluie")
@export var rain_area_size: Vector2 = Vector2(20.0, 20.0)  ## Taille XZ de la zone
@export var follow_smoothing: float = 5.0  ## Lissage du suivi

@export_group("Intensité")
@export_enum("Light", "Medium", "Heavy") var rain_intensity: int = 1
@export var wind_direction: Vector2 = Vector2(0.2, 0.0)  ## Direction du vent (XZ)

@export_group("Détection Intérieur")
@export var check_indoor: bool = true  ## Activer la détection d'intérieur
@export var indoor_raycast_layers: int = 2  ## Layer des toits/plafonds

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var particles: GPUParticles3D = $RainParticles
@onready var indoor_detector: RayCast3D = $IndoorDetector

# ==============================================================================
# ÉTAT
# ==============================================================================
var _is_indoor: bool = false
var _target_emission_rate: float = 0.0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	# Trouver le joueur automatiquement
	if not follow_target:
		await get_tree().process_frame
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			follow_target = players[0]
	
	# Configurer le GPUParticles3D
	_setup_particles()
	
	# Configurer le RayCast pour détecter les intérieurs
	_setup_indoor_detector()
	
	# Définir l'intensité initiale
	set_intensity(rain_intensity)


func _setup_particles() -> void:
	"""Configure le système de particules pour mobile."""
	if not particles:
		push_error("RainSystem: GPUParticles3D manquant!")
		return
	
	# === OPTIMISATION CRITIQUE POUR MOBILE ===
	particles.amount = MAX_PARTICLES_MOBILE
	particles.lifetime = 1.5  # Durée de vie courte
	particles.one_shot = false
	particles.explosiveness = 0.0  # Émission continue
	particles.randomness = 0.1
	
	# Visibility AABB (culling automatique)
	particles.visibility_aabb = AABB(
		Vector3(-rain_area_size.x/2, -height_above_target, -rain_area_size.y/2),
		Vector3(rain_area_size.x, height_above_target + 5.0, rain_area_size.y)
	)
	
	# Créer le ProcessMaterial si nécessaire
	if not particles.process_material:
		particles.process_material = _create_rain_material()


func _create_rain_material() -> ParticleProcessMaterial:
	"""Crée le matériau de particules pour la pluie."""
	var mat := ParticleProcessMaterial.new()
	
	# === ÉMISSION ===
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(rain_area_size.x/2, 0.1, rain_area_size.y/2)
	
	# === DIRECTION ET GRAVITÉ ===
	mat.direction = Vector3(wind_direction.x, -1.0, wind_direction.y)
	mat.spread = 5.0  # Légère variation de direction
	mat.gravity = Vector3(0, -20.0, 0)  # Gravité forte pour pluie rapide
	
	# === VITESSE ===
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 25.0
	
	# === TAILLE (gouttes fines) ===
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	
	# === COULEUR ===
	mat.color = Color(0.7, 0.8, 1.0, 0.6)  # Bleu-gris semi-transparent
	
	return mat


func _setup_indoor_detector() -> void:
	"""Configure le RayCast pour détecter les intérieurs."""
	if not indoor_detector:
		# Créer le RayCast s'il n'existe pas
		indoor_detector = RayCast3D.new()
		indoor_detector.name = "IndoorDetector"
		add_child(indoor_detector)
	
	indoor_detector.target_position = Vector3(0, height_above_target + 5.0, 0)
	indoor_detector.collision_mask = indoor_raycast_layers
	indoor_detector.enabled = check_indoor


# ==============================================================================
# MISE À JOUR
# ==============================================================================

func _process(delta: float) -> void:
	# Suivre le joueur
	_follow_target(delta)
	
	# Vérifier si on est à l'intérieur
	if check_indoor:
		_check_indoor_status()
	
	# Mettre à jour l'émission
	_update_emission(delta)


func _follow_target(delta: float) -> void:
	"""Fait suivre la pluie au joueur."""
	if not follow_target:
		return
	
	var target_pos := follow_target.global_position
	target_pos.y += height_above_target
	
	# Suivi lissé (smooth follow)
	global_position = global_position.lerp(target_pos, follow_smoothing * delta)


func _check_indoor_status() -> void:
	"""Vérifie si le joueur est sous un toit."""
	if not indoor_detector:
		return
	
	# Positionner le raycast au niveau du joueur
	if follow_target:
		indoor_detector.global_position = follow_target.global_position
	
	# Si le ray touche quelque chose au-dessus, on est à l'intérieur
	_is_indoor = indoor_detector.is_colliding()


func _update_emission(delta: float) -> void:
	"""Met à jour le taux d'émission (transition douce intérieur/extérieur)."""
	if not particles or not particles.process_material:
		return
	
	var mat := particles.process_material as ParticleProcessMaterial
	if not mat:
		return
	
	# Cible : 0 si intérieur, sinon selon intensité
	var target_rate := 0.0 if _is_indoor else _target_emission_rate
	
	# Transition douce
	var current_amount := float(particles.amount)
	var new_amount := lerp(current_amount, target_rate / EMISSION_RATE_HEAVY * MAX_PARTICLES_MOBILE, 3.0 * delta)
	
	# Appliquer (émulation du rate via amount car GPUParticles3D n'a pas de rate direct)
	particles.amount = int(clamp(new_amount, 0, MAX_PARTICLES_MOBILE))
	particles.emitting = particles.amount > 10


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func set_intensity(intensity: int) -> void:
	"""Définit l'intensité de la pluie (0=Light, 1=Medium, 2=Heavy)."""
	rain_intensity = intensity
	
	match intensity:
		0:
			_target_emission_rate = EMISSION_RATE_LIGHT
		1:
			_target_emission_rate = EMISSION_RATE_MEDIUM
		2:
			_target_emission_rate = EMISSION_RATE_HEAVY


func set_wind(direction: Vector2) -> void:
	"""Change la direction du vent."""
	wind_direction = direction
	
	if particles and particles.process_material:
		var mat := particles.process_material as ParticleProcessMaterial
		mat.direction = Vector3(direction.x, -1.0, direction.y).normalized()


func start_rain() -> void:
	"""Démarre la pluie."""
	if particles:
		particles.emitting = true


func stop_rain() -> void:
	"""Arrête la pluie progressivement."""
	_target_emission_rate = 0.0


func is_raining() -> bool:
	"""Retourne true si la pluie est active."""
	return particles and particles.emitting and not _is_indoor


func is_indoor() -> bool:
	"""Retourne true si le joueur est à l'intérieur."""
	return _is_indoor
