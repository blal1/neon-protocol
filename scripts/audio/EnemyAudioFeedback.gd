# ==============================================================================
# EnemyAudioFeedback.gd - Retour audio pour les ennemis
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Fait que les ennemis émettent des sons 3D pour la navigation aveugle
# Sons de pas robotiques, servomoteurs, alertes
# ==============================================================================

extends Node
class_name EnemyAudioFeedback

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal enemy_sound_played(sound_type: String)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Sons de Mouvement")
@export var footstep_sounds: Array[AudioStream]
@export var servo_sounds: Array[AudioStream]  ## Sons de servomoteurs

@export_group("Sons d'État")
@export var patrol_hum_sound: AudioStream  ## Bourdonnement en patrouille
@export var alert_sound: AudioStream  ## Son quand ennemi détecte joueur
@export var chase_sound: AudioStream  ## Son pendant poursuite
@export var attack_sound: AudioStream  ## Son d'attaque
@export var death_sound: AudioStream  ## Son de destruction

@export_group("Configuration")
@export var step_interval: float = 0.4
@export var audio_bus: String = "SFX"
@export var max_distance: float = 25.0

# ==============================================================================
# COMPOSANTS
# ==============================================================================
var _footstep_player: AudioStreamPlayer3D
var _state_player: AudioStreamPlayer3D
var _ambient_player: AudioStreamPlayer3D

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _parent_enemy: Node3D
var _step_timer: float = 0.0
var _is_moving: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système audio ennemi."""
	_setup_audio_players()
	_find_parent_enemy()
	_connect_signals()


func _physics_process(delta: float) -> void:
	"""Mise à jour des sons de mouvement."""
	if not _parent_enemy:
		return
	
	# Détecter le mouvement en vérifiant la vélocité
	if _parent_enemy is CharacterBody3D:
		var body := _parent_enemy as CharacterBody3D
		_is_moving = body.velocity.length() > 0.5
	
	# Jouer les pas si en mouvement
	if _is_moving:
		_step_timer -= delta
		if _step_timer <= 0.0:
			play_footstep()
			_step_timer = step_interval


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _setup_audio_players() -> void:
	"""Configure les lecteurs audio."""
	# Pas
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.name = "EnemyFootsteps"
	_footstep_player.bus = audio_bus
	_footstep_player.max_distance = max_distance
	_footstep_player.unit_size = 8.0
	_footstep_player.panning_strength = 1.5  # Important pour localisation
	add_child(_footstep_player)
	
	# États (alerte, attaque)
	_state_player = AudioStreamPlayer3D.new()
	_state_player.name = "EnemyState"
	_state_player.bus = audio_bus
	_state_player.max_distance = max_distance * 1.5  # Plus audible
	_state_player.unit_size = 10.0
	_state_player.panning_strength = 2.0
	add_child(_state_player)
	
	# Ambiant (bourdonnement continu)
	_ambient_player = AudioStreamPlayer3D.new()
	_ambient_player.name = "EnemyAmbient"
	_ambient_player.bus = audio_bus
	_ambient_player.max_distance = max_distance
	_ambient_player.volume_db = -10.0
	_ambient_player.autoplay = true
	if patrol_hum_sound:
		_ambient_player.stream = patrol_hum_sound
	add_child(_ambient_player)


func _find_parent_enemy() -> void:
	"""Trouve l'ennemi parent."""
	_parent_enemy = get_parent() as Node3D


func _connect_signals() -> void:
	"""Connecte aux signaux de l'ennemi si disponibles."""
	if not _parent_enemy:
		return
	
	# Connecter au signal de changement d'état si SecurityRobot
	if _parent_enemy.has_signal("state_changed"):
		_parent_enemy.state_changed.connect(_on_state_changed)
	
	if _parent_enemy.has_signal("attack_started"):
		_parent_enemy.attack_started.connect(_on_attack)
	
	if _parent_enemy.has_signal("player_detected"):
		_parent_enemy.player_detected.connect(_on_player_detected)


# ==============================================================================
# SONS DE MOUVEMENT
# ==============================================================================

func play_footstep() -> void:
	"""Joue un son de pas robotique."""
	if footstep_sounds.is_empty():
		return
	
	_footstep_player.stream = footstep_sounds.pick_random()
	_footstep_player.pitch_scale = randf_range(0.9, 1.1)
	
	if _parent_enemy:
		_footstep_player.global_position = _parent_enemy.global_position
	
	_footstep_player.play()
	enemy_sound_played.emit("footstep")


func play_servo_sound() -> void:
	"""Joue un son de servomoteur (rotation, mouvement mécanique)."""
	if servo_sounds.is_empty():
		return
	
	_state_player.stream = servo_sounds.pick_random()
	_state_player.play()
	enemy_sound_played.emit("servo")


# ==============================================================================
# SONS D'ÉTAT
# ==============================================================================

func _on_state_changed(new_state) -> void:
	"""Réagit aux changements d'état de l'ennemi."""
	# Convertir l'état en int si c'est un enum
	var state_int: int = new_state if new_state is int else 0
	
	match state_int:
		0:  # PATROL
			play_patrol_ambient()
		1:  # CHASE
			play_chase_sound()
		2:  # ATTACK
			pass  # Géré par attack_started
		3:  # RETURN
			play_patrol_ambient()


func _on_player_detected() -> void:
	"""Joue le son d'alerte quand le joueur est détecté."""
	play_alert_sound()


func _on_attack() -> void:
	"""Joue le son d'attaque."""
	play_attack_sound()


func play_patrol_ambient() -> void:
	"""Joue/met à jour l'ambiance de patrouille."""
	if patrol_hum_sound and not _ambient_player.playing:
		_ambient_player.stream = patrol_hum_sound
		_ambient_player.play()


func play_alert_sound() -> void:
	"""Joue le son d'alerte (ennemi vous a vu)."""
	if alert_sound:
		_state_player.stream = alert_sound
		_state_player.pitch_scale = 1.0
		_state_player.play()
		enemy_sound_played.emit("alert")


func play_chase_sound() -> void:
	"""Joue le son de poursuite."""
	if chase_sound:
		_state_player.stream = chase_sound
		_state_player.play()
		enemy_sound_played.emit("chase")
	
	# Accélérer les pas
	step_interval = 0.25


func play_attack_sound() -> void:
	"""Joue le son d'attaque."""
	if attack_sound:
		_state_player.stream = attack_sound
		_state_player.pitch_scale = randf_range(0.95, 1.05)
		_state_player.play()
		enemy_sound_played.emit("attack")


func play_death_sound() -> void:
	"""Joue le son de mort/destruction."""
	# Arrêter les autres sons
	_ambient_player.stop()
	_footstep_player.stop()
	
	if death_sound:
		_state_player.stream = death_sound
		_state_player.play()
		enemy_sound_played.emit("death")


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func set_volume(volume_db: float) -> void:
	"""Définit le volume de tous les sons."""
	_footstep_player.volume_db = volume_db
	_state_player.volume_db = volume_db
	_ambient_player.volume_db = volume_db - 10.0


func stop_all_sounds() -> void:
	"""Arrête tous les sons."""
	_footstep_player.stop()
	_state_player.stop()
	_ambient_player.stop()
