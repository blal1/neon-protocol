# ==============================================================================
# AudioCompass.gd - Système de navigation sonore (Sonar/Radar)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Émet un son 3D positionné dans la direction de l'objectif
# Permet aux joueurs aveugles de naviguer avec un casque
# Plus on est proche de l'objectif, plus le son est fréquent
# ==============================================================================

extends Node3D
class_name AudioCompass

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal target_set(position: Vector3)
signal target_reached
signal target_cleared
signal ping_played(distance: float)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Sons")
@export var ping_sound: AudioStream  ## Son de ping principal
@export var ping_sound_close: AudioStream  ## Son quand très proche
@export var target_reached_sound: AudioStream  ## Son quand objectif atteint

@export_group("Distances")
@export var ping_distance: float = 5.0  ## Distance virtuelle du son par rapport au joueur
@export var max_tracking_distance: float = 100.0  ## Distance max de suivi
@export var reached_threshold: float = 3.0  ## Distance pour considérer l'objectif atteint

@export_group("Timing")
@export var ping_interval_far: float = 2.0  ## Intervalle quand loin
@export var ping_interval_close: float = 0.3  ## Intervalle quand proche
@export var pitch_variation: bool = true  ## Varier le pitch selon la distance

@export_group("Audio 3D")
@export var audio_bus: String = "Navigation"  ## Bus audio
@export var panning_strength: float = 2.0  ## Force de l'effet stéréo
@export var unit_size: float = 10.0  ## Taille de l'unité sonore

# ==============================================================================
# COMPOSANTS
# ==============================================================================
var _pinger: AudioStreamPlayer3D
var _close_pinger: AudioStreamPlayer3D

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_target_position: Vector3 = Vector3.ZERO
var is_active: bool = false
var _timer: float = 0.0
var _current_interval: float = 1.0
var _last_distance: float = 0.0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système de navigation sonore."""
	_setup_audio_players()


func _process(delta: float) -> void:
	"""Mise à jour du système de ping."""
	if not is_active:
		return
	
	_update_ping_position()
	_update_ping_timing(delta)


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _setup_audio_players() -> void:
	"""Configure les lecteurs audio 3D."""
	# Ping principal
	_pinger = AudioStreamPlayer3D.new()
	_pinger.name = "MainPinger"
	_pinger.bus = audio_bus
	_pinger.unit_size = unit_size
	_pinger.max_distance = max_tracking_distance
	_pinger.panning_strength = panning_strength
	_pinger.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if ping_sound:
		_pinger.stream = ping_sound
	add_child(_pinger)
	
	# Ping proche (son différent quand très proche)
	_close_pinger = AudioStreamPlayer3D.new()
	_close_pinger.name = "ClosePinger"
	_close_pinger.bus = audio_bus
	_close_pinger.unit_size = unit_size * 0.5
	_close_pinger.max_distance = 20.0
	_close_pinger.panning_strength = panning_strength
	if ping_sound_close:
		_close_pinger.stream = ping_sound_close
	add_child(_close_pinger)


# ==============================================================================
# GESTION DE LA CIBLE
# ==============================================================================

func set_target(target_pos: Vector3) -> void:
	"""
	Définit la position de l'objectif à suivre.
	@param target_pos: Position mondiale de l'objectif
	"""
	current_target_position = target_pos
	is_active = true
	_timer = 0.0  # Ping immédiat
	
	target_set.emit(target_pos)
	
	# Annoncer via TTS si disponible
	_announce_target_direction()


func set_target_node(target: Node3D) -> void:
	"""Suit un noeud 3D comme cible."""
	if target and is_instance_valid(target):
		set_target(target.global_position)


func clear_target() -> void:
	"""Arrête le guidage."""
	is_active = false
	current_target_position = Vector3.ZERO
	target_cleared.emit()


func mark_reached() -> void:
	"""Marque l'objectif comme atteint."""
	is_active = false
	
	# Jouer le son de réussite
	if target_reached_sound:
		_pinger.stream = target_reached_sound
		_pinger.global_position = global_position
		_pinger.play()
	
	target_reached.emit()


# ==============================================================================
# MISE À JOUR DU PING
# ==============================================================================

func _update_ping_position() -> void:
	"""Positionne le son dans la direction de l'objectif."""
	if not is_active:
		return
	
	var direction := global_position.direction_to(current_target_position)
	_last_distance = global_position.distance_to(current_target_position)
	
	# Vérifier si objectif atteint
	if _last_distance <= reached_threshold:
		mark_reached()
		return
	
	# Positionner le ping à distance fixe dans la direction de l'objectif
	# Cela permet d'entendre la DIRECTION même si l'objectif est très loin
	_pinger.global_position = global_position + (direction * ping_distance)
	_close_pinger.global_position = _pinger.global_position


func _update_ping_timing(delta: float) -> void:
	"""Gère le timing des pings basé sur la distance."""
	# Calculer l'intervalle basé sur la distance
	var distance_factor: float = clamp(_last_distance / max_tracking_distance, 0.0, 1.0)
	_current_interval = lerp(ping_interval_close, ping_interval_far, distance_factor)
	
	# Décrémenter le timer
	_timer -= delta
	
	if _timer <= 0.0:
		_play_ping()
		_timer = _current_interval


func _play_ping() -> void:
	"""Joue le son de ping."""
	# Choisir le son selon la distance
	var use_close_sound := _last_distance < 10.0 and ping_sound_close != null
	var player := _close_pinger if use_close_sound else _pinger
	
	# Varier le pitch selon la distance (plus aigu = plus proche)
	if pitch_variation:
		var pitch: float = lerp(1.2, 0.8, clamp(_last_distance / 50.0, 0.0, 1.0))
		player.pitch_scale = pitch
	
	player.play()
	ping_played.emit(_last_distance)


# ==============================================================================
# ANNONCES TTS
# ==============================================================================

func _announce_target_direction() -> void:
	"""Annonce la direction de l'objectif via TTS."""
	var blind_manager = get_node_or_null("/root/BlindAccessibilityManager")
	if not blind_manager or not blind_manager.has_method("speak"):
		return
	
	var direction := global_position.direction_to(current_target_position)
	var distance := global_position.distance_to(current_target_position)
	var direction_name := _get_direction_name(direction)
	
	var message := "Objectif %s à %.0f mètres" % [direction_name, distance]
	blind_manager.speak(message)


func _get_direction_name(direction: Vector3) -> String:
	"""Convertit un vecteur en nom de direction."""
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	
	var forward_dot := forward.dot(direction)
	var right_dot := right.dot(direction)
	
	if forward_dot > 0.7:
		return "devant"
	elif forward_dot < -0.7:
		return "derrière"
	elif right_dot > 0.7:
		return "à droite"
	elif right_dot < -0.7:
		return "à gauche"
	elif forward_dot > 0 and right_dot > 0:
		return "devant à droite"
	elif forward_dot > 0 and right_dot < 0:
		return "devant à gauche"
	elif forward_dot < 0 and right_dot > 0:
		return "derrière à droite"
	else:
		return "derrière à gauche"


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_direction_to_target() -> Vector3:
	"""Retourne la direction vers l'objectif."""
	if not is_active:
		return Vector3.ZERO
	return global_position.direction_to(current_target_position)


func get_distance_to_target() -> float:
	"""Retourne la distance à l'objectif."""
	if not is_active:
		return -1.0
	return _last_distance


func is_tracking() -> bool:
	"""Retourne true si un objectif est suivi."""
	return is_active


func force_ping() -> void:
	"""Force un ping immédiat."""
	if is_active:
		_play_ping()
		_timer = _current_interval
