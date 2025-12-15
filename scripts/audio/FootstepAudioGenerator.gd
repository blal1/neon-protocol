# ==============================================================================
# FootstepAudioGenerator.gd - Générateur de sons de pas
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère des sons de pas procéduraux basés sur le terrain
# ==============================================================================

extends Node
class_name FootstepAudioGenerator

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal footstep_played(surface_type: String)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum SurfaceType {
	CONCRETE,
	METAL,
	WATER,
	GRATE,
	CARPET,
	DIRT
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var enabled: bool = true
@export var volume_db: float = -5.0
@export var pitch_variation: float = 0.15
@export var step_interval: float = 0.4

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
var _audio_player: AudioStreamPlayer3D
var _player: Node3D = null
var _last_step_time: float = 0.0
var _is_moving: bool = false

# Streams pré-générés par type de surface
var _surface_sounds: Dictionary = {}

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_find_player()
	_setup_audio()
	_generate_footstep_sounds()


func _process(delta: float) -> void:
	"""Mise à jour."""
	if not enabled or not _player:
		return
	
	# Vérifier si le joueur bouge
	var velocity := Vector3.ZERO
	if _player is CharacterBody3D:
		velocity = _player.velocity
	
	_is_moving = velocity.length() > 0.5
	
	if _is_moving:
		_last_step_time += delta
		if _last_step_time >= step_interval:
			_last_step_time = 0.0
			play_footstep()


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _setup_audio() -> void:
	"""Configure le lecteur audio."""
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.max_distance = 20.0
	_audio_player.unit_size = 1.0
	_audio_player.volume_db = volume_db
	add_child(_audio_player)


func _generate_footstep_sounds() -> void:
	"""Génère ou charge les sons de pas."""
	# Utiliser les sons UI existants comme base
	var base_sounds := {
		SurfaceType.CONCRETE: "res://audio/sfx/ui/click_001.ogg",
		SurfaceType.METAL: "res://audio/sfx/ui/glass_001.ogg",
		SurfaceType.WATER: "res://audio/sfx/ui/drop_001.ogg",
		SurfaceType.GRATE: "res://audio/sfx/ui/scratch_001.ogg",
		SurfaceType.CARPET: "res://audio/sfx/ui/tick_001.ogg",
		SurfaceType.DIRT: "res://audio/sfx/ui/pluck_001.ogg"
	}
	
	for surface_type in base_sounds:
		var path: String = base_sounds[surface_type]
		if ResourceLoader.exists(path):
			_surface_sounds[surface_type] = load(path)


# ==============================================================================
# LECTURE
# ==============================================================================

func play_footstep(surface: SurfaceType = SurfaceType.CONCRETE) -> void:
	"""Joue un son de pas."""
	if not _audio_player:
		return
	
	# Détecter la surface si possible
	var detected_surface := _detect_surface()
	if detected_surface != -1:
		surface = detected_surface
	
	# Obtenir le son
	var stream: AudioStream = _surface_sounds.get(surface)
	if not stream:
		stream = _surface_sounds.get(SurfaceType.CONCRETE)
	
	if not stream:
		return
	
	# Positionner au niveau du joueur
	if _player:
		_audio_player.global_position = _player.global_position
	
	# Variation de pitch pour réalisme
	_audio_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	_audio_player.stream = stream
	_audio_player.play()
	
	footstep_played.emit(_get_surface_name(surface))


func _detect_surface() -> int:
	"""Détecte le type de surface sous le joueur."""
	if not _player:
		return SurfaceType.CONCRETE
	
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3(0, 0.5, 0)
	var to := _player.global_position + Vector3(0, -0.5, 0)
	
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	
	var result := space.intersect_ray(query)
	
	if result and result.has("collider"):
		var collider: Node = result["collider"]
		
		# Vérifier les groupes
		if collider.is_in_group("metal"):
			return SurfaceType.METAL
		elif collider.is_in_group("water"):
			return SurfaceType.WATER
		elif collider.is_in_group("grate"):
			return SurfaceType.GRATE
		elif collider.is_in_group("carpet"):
			return SurfaceType.CARPET
		elif collider.is_in_group("dirt"):
			return SurfaceType.DIRT
	
	return SurfaceType.CONCRETE


func _get_surface_name(surface: SurfaceType) -> String:
	"""Retourne le nom d'une surface."""
	match surface:
		SurfaceType.METAL:
			return "metal"
		SurfaceType.WATER:
			return "water"
		SurfaceType.GRATE:
			return "grate"
		SurfaceType.CARPET:
			return "carpet"
		SurfaceType.DIRT:
			return "dirt"
		_:
			return "concrete"


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func set_step_interval(running: bool) -> void:
	"""Ajuste l'intervalle selon course/marche."""
	step_interval = 0.25 if running else 0.4
