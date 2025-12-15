# ==============================================================================
# FootstepSystem.gd - Système de bruits de pas 3D
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Joue des sons de pas basés sur la surface et la vitesse
# Essentiel pour l'accessibilité (savoir qu'on bouge)
# ==============================================================================

extends Node
class_name FootstepSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal footstep_played(surface_type: String)
signal surface_changed(new_surface: String)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum SurfaceType {
	CONCRETE,
	METAL,
	WATER,
	GLASS,
	DIRT,
	CARPET,
	GRATE  # Grilles métalliques cyberpunk
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Sons par Surface")
@export var sounds_concrete: Array[AudioStream]
@export var sounds_metal: Array[AudioStream]
@export var sounds_water: Array[AudioStream]
@export var sounds_glass: Array[AudioStream]
@export var sounds_dirt: Array[AudioStream]
@export var sounds_carpet: Array[AudioStream]
@export var sounds_grate: Array[AudioStream]

@export_group("Timing")
@export var step_interval_walk: float = 0.5  ## Intervalle en marchant
@export var step_interval_run: float = 0.3  ## Intervalle en courant
@export var dash_sound: AudioStream  ## Son de dash

@export_group("Audio")
@export var audio_bus: String = "SFX"
@export var base_volume_db: float = -5.0
@export var pitch_variation: float = 0.1  ## Variation de pitch aléatoire

@export_group("Détection")
@export var floor_detector_path: NodePath  ## Chemin vers le RayCast3D
@export var velocity_threshold: float = 0.5  ## Vitesse min pour jouer un son

# ==============================================================================
# COMPOSANTS
# ==============================================================================
var _audio_player: AudioStreamPlayer3D
var _floor_detector: RayCast3D
var _parent_body: CharacterBody3D

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _step_timer: float = 0.0
var _current_surface: SurfaceType = SurfaceType.CONCRETE
var _current_surface_name: String = "concrete"
var _is_moving: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système."""
	_setup_audio_player()
	_find_components()


func _physics_process(delta: float) -> void:
	"""Mise à jour des pas."""
	if not _parent_body:
		return
	
	# Vérifier si on bouge
	var velocity := _parent_body.velocity
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	_is_moving = horizontal_speed > velocity_threshold and _parent_body.is_on_floor()
	
	if not _is_moving:
		_step_timer = 0.0
		return
	
	# Détecter la surface
	_detect_surface()
	
	# Calculer l'intervalle selon la vitesse
	var is_running := horizontal_speed > 4.0
	var interval := step_interval_run if is_running else step_interval_walk
	
	# Jouer le son de pas
	_step_timer -= delta
	if _step_timer <= 0.0:
		_play_footstep()
		_step_timer = interval


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _setup_audio_player() -> void:
	"""Configure le lecteur audio 3D."""
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "FootstepPlayer"
	_audio_player.bus = audio_bus
	_audio_player.volume_db = base_volume_db
	_audio_player.max_distance = 20.0
	_audio_player.unit_size = 5.0
	add_child(_audio_player)


func _find_components() -> void:
	"""Trouve les composants nécessaires."""
	# Trouver le parent CharacterBody3D
	var parent := get_parent()
	while parent and not parent is CharacterBody3D:
		parent = parent.get_parent()
	
	if parent is CharacterBody3D:
		_parent_body = parent
	
	# Trouver le floor detector
	if floor_detector_path:
		_floor_detector = get_node_or_null(floor_detector_path) as RayCast3D


# ==============================================================================
# DÉTECTION DE SURFACE
# ==============================================================================

func _detect_surface() -> void:
	"""Détecte le type de surface sous les pieds."""
	if not _floor_detector or not _floor_detector.is_colliding():
		return
	
	var collider := _floor_detector.get_collider()
	if not collider:
		return
	
	var new_surface := SurfaceType.CONCRETE
	var new_surface_name := "concrete"
	
	# Détection par groupes
	if collider.is_in_group("metal") or collider.is_in_group("metallic"):
		new_surface = SurfaceType.METAL
		new_surface_name = "metal"
	elif collider.is_in_group("water") or collider.is_in_group("puddle"):
		new_surface = SurfaceType.WATER
		new_surface_name = "water"
	elif collider.is_in_group("glass"):
		new_surface = SurfaceType.GLASS
		new_surface_name = "glass"
	elif collider.is_in_group("dirt") or collider.is_in_group("ground"):
		new_surface = SurfaceType.DIRT
		new_surface_name = "dirt"
	elif collider.is_in_group("carpet") or collider.is_in_group("soft"):
		new_surface = SurfaceType.CARPET
		new_surface_name = "carpet"
	elif collider.is_in_group("grate") or collider.is_in_group("grating"):
		new_surface = SurfaceType.GRATE
		new_surface_name = "grate"
	
	# Émettre signal si surface a changé
	if new_surface != _current_surface:
		_current_surface = new_surface
		_current_surface_name = new_surface_name
		surface_changed.emit(new_surface_name)


# ==============================================================================
# LECTURE DES SONS
# ==============================================================================

func _play_footstep() -> void:
	"""Joue un son de pas."""
	var sounds := _get_sounds_for_surface(_current_surface)
	
	if sounds.is_empty():
		# Fallback vers concrete
		sounds = sounds_concrete
	
	if sounds.is_empty():
		return
	
	# Choisir un son aléatoire
	var sound: AudioStream = sounds.pick_random()
	_audio_player.stream = sound
	
	# Variation de pitch pour réalisme
	_audio_player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	
	# Positionner au niveau des pieds
	if _parent_body:
		_audio_player.global_position = _parent_body.global_position
	
	_audio_player.play()
	footstep_played.emit(_current_surface_name)


func _get_sounds_for_surface(surface: SurfaceType) -> Array[AudioStream]:
	"""Retourne les sons pour un type de surface."""
	match surface:
		SurfaceType.CONCRETE:
			return sounds_concrete
		SurfaceType.METAL:
			return sounds_metal
		SurfaceType.WATER:
			return sounds_water
		SurfaceType.GLASS:
			return sounds_glass
		SurfaceType.DIRT:
			return sounds_dirt
		SurfaceType.CARPET:
			return sounds_carpet
		SurfaceType.GRATE:
			return sounds_grate
	return sounds_concrete


func play_dash_sound() -> void:
	"""Joue le son de dash."""
	if dash_sound:
		_audio_player.stream = dash_sound
		_audio_player.pitch_scale = 1.0
		_audio_player.play()


func play_land_sound() -> void:
	"""Joue un son d'atterrissage."""
	# Utiliser un son de pas plus fort
	var sounds := _get_sounds_for_surface(_current_surface)
	if sounds.is_empty():
		return
	
	_audio_player.stream = sounds.pick_random()
	_audio_player.pitch_scale = 0.8  # Plus grave pour l'impact
	_audio_player.volume_db = base_volume_db + 3.0
	_audio_player.play()
	
	# Restaurer le volume
	await get_tree().create_timer(0.1).timeout
	_audio_player.volume_db = base_volume_db


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_current_surface() -> String:
	"""Retourne le nom de la surface actuelle."""
	return _current_surface_name


func is_moving() -> bool:
	"""Retourne true si le joueur bouge."""
	return _is_moving


func set_volume(volume_db: float) -> void:
	"""Définit le volume des pas."""
	base_volume_db = volume_db
	if _audio_player:
		_audio_player.volume_db = volume_db
