# ==============================================================================
# AudioCueSystem.gd - Système d'indices audio 3D pour non-voyants
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les sons spatiaux pour la navigation et le combat sans vision
# Utilise AudioStreamPlayer3D pour le positionnement stéréo
# ==============================================================================

extends Node
class_name AudioCueSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal cue_played(cue_type: CueType, position: Vector3)
signal beacon_started(target: Node3D)
signal beacon_stopped

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum CueType {
	ENEMY,      # Ennemi détecté
	ENEMY_CLOSE,# Ennemi très proche
	ITEM,       # Objet ramassable
	DOOR,       # Porte / passage
	HAZARD,     # Danger
	OBJECTIVE,  # Objectif
	ATTACK,     # Indication d'attaque
	DAMAGE,     # Joueur touché
	FOOTSTEP,   # Pas du joueur
	WALL        # Mur / obstacle proche
}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MAX_AUDIO_PLAYERS := 8
const ENEMY_PULSE_INTERVAL := 1.0  # Intervalle de pulse ennemi en secondes
const CLOSE_DISTANCE := 3.0  # Distance "proche" en mètres
const PITCH_MIN := 0.8
const PITCH_MAX := 1.5

# Fréquences de pulse basées sur la distance
const PULSE_RATES := {
	"far": 2.0,    # > 10m
	"medium": 1.0, # 5-10m
	"close": 0.5,  # 2-5m
	"danger": 0.2  # < 2m
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Références")
@export var player: Node3D  ## Référence au joueur

@export_group("Audio")
@export var master_volume_db: float = 0.0
@export var spatial_blend: float = 1.0  ## 0 = 2D, 1 = 3D complet

@export_group("Sons")
@export var enemy_sound: AudioStream
@export var enemy_close_sound: AudioStream
@export var item_sound: AudioStream
@export var door_sound: AudioStream
@export var hazard_sound: AudioStream
@export var objective_sound: AudioStream
@export var damage_sound: AudioStream
@export var footstep_sound: AudioStream

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _audio_players: Array[AudioStreamPlayer3D] = []
var _player_index: int = 0
var _beacon_target: Node3D = null
var _beacon_timer: float = 0.0
var _beacon_interval: float = 1.0
var _enemy_pulse_timers: Dictionary = {}  # enemy_id -> timer
var is_active: bool = true

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système audio."""
	# Créer le pool de lecteurs audio
	for i in range(MAX_AUDIO_PLAYERS):
		var player3d := AudioStreamPlayer3D.new()
		player3d.name = "AudioPlayer_%d" % i
		player3d.max_db = master_volume_db
		player3d.unit_size = 5.0  # Taille de l'unité en mètres
		player3d.max_distance = 30.0
		player3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player3d)
		_audio_players.append(player3d)
	
	# Trouver le joueur
	await get_tree().process_frame
	_find_player()


func _process(delta: float) -> void:
	"""Mise à jour continue."""
	if not is_active:
		return
	
	# Gérer le beacon
	if _beacon_target and is_instance_valid(_beacon_target):
		_beacon_timer += delta
		if _beacon_timer >= _beacon_interval:
			_beacon_timer = 0.0
			play_3d_cue(_beacon_target.global_position, CueType.OBJECTIVE)


# ==============================================================================
# LECTURE DE SONS 3D
# ==============================================================================

func play_3d_cue(position: Vector3, cue_type: CueType) -> void:
	"""
	Joue un son 3D positionné dans l'espace.
	@param position: Position mondiale du son
	@param cue_type: Type d'indice audio
	"""
	if not is_active:
		return
	
	var audio_player := _get_next_audio_player()
	if not audio_player:
		return
	
	# Positionner le lecteur
	audio_player.global_position = position
	
	# Sélectionner le son approprié
	var stream := _get_sound_for_type(cue_type)
	if not stream:
		# Utiliser un son généré si pas de stream
		stream = _generate_tone_for_type(cue_type)
	
	if stream:
		audio_player.stream = stream
		
		# Ajuster le pitch selon la distance
		if player:
			var distance := player.global_position.distance_to(position)
			audio_player.pitch_scale = _get_pitch_for_distance(distance, cue_type)
		
		audio_player.play()
		cue_played.emit(cue_type, position)


func play_enemy_cue(position: Vector3, distance: float) -> void:
	"""
	Joue un son d'ennemi avec pulse basé sur la distance.
	@param position: Position de l'ennemi
	@param distance: Distance au joueur
	"""
	var cue_type := CueType.ENEMY_CLOSE if distance < CLOSE_DISTANCE else CueType.ENEMY
	play_3d_cue(position, cue_type)


func play_directional_cue(direction: Vector3, cue_type: CueType) -> void:
	"""
	Joue un son dans une direction relative au joueur.
	@param direction: Direction normalisée
	@param cue_type: Type d'indice
	"""
	if not player:
		return
	
	# Calculer la position à une distance fixe dans la direction
	var distance := 5.0
	var position := player.global_position + direction * distance
	play_3d_cue(position, cue_type)


func play_damage_indicator(source_position: Vector3) -> void:
	"""Joue un son indiquant la direction des dégâts."""
	play_3d_cue(source_position, CueType.DAMAGE)


# ==============================================================================
# BEACON (Son répétitif pour objectif)
# ==============================================================================

func start_beacon(target: Node3D, interval: float = 1.0) -> void:
	"""
	Démarre un beacon audio vers une cible.
	@param target: Cible à signaler
	@param interval: Intervalle entre les sons
	"""
	_beacon_target = target
	_beacon_interval = interval
	_beacon_timer = 0.0
	beacon_started.emit(target)


func stop_beacon() -> void:
	"""Arrête le beacon actif."""
	_beacon_target = null
	beacon_stopped.emit()


func update_beacon_interval_by_distance() -> void:
	"""Met à jour l'intervalle du beacon selon la distance."""
	if not _beacon_target or not player:
		return
	
	var distance := player.global_position.distance_to(_beacon_target.global_position)
	_beacon_interval = _get_pulse_rate_for_distance(distance)


# ==============================================================================
# RADAR AUDIO
# ==============================================================================

func play_radar_sweep() -> void:
	"""
	Joue un sweep radar indiquant les objets autour.
	Utile pour donner un aperçu audio de l'environnement.
	"""
	if not player:
		return
	
	# Collecter tous les points d'intérêt
	var points: Array[Dictionary] = []
	
	# Ennemis
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy is Node3D:
			var health = enemy.get_node_or_null("HealthComponent")
			if health and health.is_dead:
				continue
			points.append({
				"position": enemy.global_position,
				"type": CueType.ENEMY
			})
	
	# Objets
	for item in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(item) and item is Node3D:
			points.append({
				"position": item.global_position,
				"type": CueType.ITEM
			})
	
	# Jouer les sons avec délai
	for i in range(points.size()):
		var point: Dictionary = points[i]
		await get_tree().create_timer(0.2 * i).timeout
		play_3d_cue(point["position"], point["type"])


# ==============================================================================
# FOOTSTEPS (Retour audio du mouvement)
# ==============================================================================

func play_footstep() -> void:
	"""Joue un son de pas."""
	if player:
		play_3d_cue(player.global_position, CueType.FOOTSTEP)


# ==============================================================================
# UTILITAIRES AUDIO
# ==============================================================================

func _get_next_audio_player() -> AudioStreamPlayer3D:
	"""Retourne le prochain lecteur audio disponible."""
	var player_audio := _audio_players[_player_index]
	_player_index = (_player_index + 1) % MAX_AUDIO_PLAYERS
	return player_audio


func _get_sound_for_type(cue_type: CueType) -> AudioStream:
	"""Retourne le son correspondant au type."""
	match cue_type:
		CueType.ENEMY:
			return enemy_sound
		CueType.ENEMY_CLOSE:
			return enemy_close_sound if enemy_close_sound else enemy_sound
		CueType.ITEM:
			return item_sound
		CueType.DOOR:
			return door_sound
		CueType.HAZARD:
			return hazard_sound
		CueType.OBJECTIVE:
			return objective_sound
		CueType.DAMAGE:
			return damage_sound
		CueType.FOOTSTEP:
			return footstep_sound
	return null


func _generate_tone_for_type(cue_type: CueType) -> AudioStream:
	"""
	Génère un son procédural pour les types sans fichier audio.
	Note: En production, utiliser de vrais fichiers audio.
	"""
	# Pour l'instant, retourner null
	# Les sons devront être fournis dans l'éditeur
	return null


func _get_pitch_for_distance(distance: float, cue_type: CueType) -> float:
	"""Calcule le pitch basé sur la distance."""
	# Plus proche = pitch plus élevé (plus urgent)
	var normalized := clamp(distance / 20.0, 0.0, 1.0)
	var pitch := lerp(PITCH_MAX, PITCH_MIN, normalized)
	
	# Certains types ont un pitch fixe
	if cue_type == CueType.HAZARD:
		pitch *= 0.8  # Son plus grave pour danger
	elif cue_type == CueType.ITEM:
		pitch *= 1.2  # Son plus aigu pour objets
	
	return pitch


func _get_pulse_rate_for_distance(distance: float) -> float:
	"""Retourne l'intervalle de pulse basé sur la distance."""
	if distance < 2.0:
		return PULSE_RATES["danger"]
	elif distance < 5.0:
		return PULSE_RATES["close"]
	elif distance < 10.0:
		return PULSE_RATES["medium"]
	else:
		return PULSE_RATES["far"]


# ==============================================================================
# RÉFÉRENCES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	if player:
		return
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node3D:
		player = players[0]


# ==============================================================================
# ACTIVATION
# ==============================================================================

func set_active(active: bool) -> void:
	"""Active ou désactive le système."""
	is_active = active
	if not active:
		stop_beacon()
		# Arrêter tous les sons
		for audio_player in _audio_players:
			audio_player.stop()


func set_master_volume(volume_db: float) -> void:
	"""Définit le volume principal."""
	master_volume_db = volume_db
	for audio_player in _audio_players:
		audio_player.max_db = volume_db
