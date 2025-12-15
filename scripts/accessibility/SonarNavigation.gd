# ==============================================================================
# SonarNavigation.gd - Navigation audio par sonar
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Système de navigation pour accessibilité (joueurs aveugles)
# Utilise des sons spatiaux pour guider le joueur
# ==============================================================================

extends Node
class_name SonarNavigation

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal target_reached
signal target_updated(target_position: Vector3)
signal obstacle_detected(direction: String)
signal sonar_pulse_sent

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Sonar")
@export var sonar_enabled: bool = true
@export var pulse_interval: float = 1.5  ## Intervalle entre les pings
@export var pulse_range: float = 30.0  ## Portée du sonar
@export var min_pitch: float = 0.5  ## Pitch pour cibles éloignées
@export var max_pitch: float = 2.0  ## Pitch pour cibles proches

@export_group("Feedback")
@export var proximity_feedback: bool = true  ## Feedback quand proche d'un mur
@export var enemy_detection: bool = true  ## Détecter les ennemis
@export var item_detection: bool = true  ## Détecter les pickups

@export_group("Audio")
@export var objective_sound_path: String = "res://audio/navigation/42796__digifishmusic__sonar-ping.wav"
@export var enemy_sound_path: String = "res://audio/navigation/493162__breviceps__submarine-sonar.wav"
@export var wall_sound_path: String = "res://audio/navigation/371178__samsterbirdies__sonar-sweep-beep.wav"

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var _pulse_timer: float = 0.0
var _player: Node3D = null

# Audio players (3D spatialisés)
var _objective_audio: AudioStreamPlayer3D
var _enemy_audio: AudioStreamPlayer3D
var _wall_audio: AudioStreamPlayer3D
var _ambient_audio: AudioStreamPlayer3D

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_find_player()
	_setup_audio_players()
	
	# Charger les sons
	_load_audio_streams()


func _process(delta: float) -> void:
	"""Mise à jour du sonar."""
	if not sonar_enabled or not _player:
		return
	
	_pulse_timer += delta
	
	if _pulse_timer >= pulse_interval:
		_pulse_timer = 0.0
		_send_sonar_pulse()


func _input(event: InputEvent) -> void:
	"""Gère l'entrée pour le ping manuel de navigation."""
	if event.is_action_pressed("ping_navigation"):
		trigger_ping()


# ==============================================================================
# PING MANUEL
# ==============================================================================

func trigger_ping() -> void:
	"""
	Déclenche manuellement un ping vers l'objectif actuel.
	Appelé par l'action 'ping_navigation' (Tab ou L3).
	"""
	if not has_target:
		var accessibility_mgr = get_node_or_null("/root/AccessibilityManager")
		if accessibility_mgr and accessibility_mgr.has_method("speak"):
			accessibility_mgr.speak("Aucun objectif défini")
		return
	
	if not _player:
		_find_player()
		if not _player:
			return
	
	# Créer un son temporaire à la position de l'objectif
	var audio_player := AudioStreamPlayer3D.new()
	get_tree().root.add_child(audio_player)
	
	audio_player.global_position = current_target
	audio_player.stream = _objective_audio.stream
	audio_player.bus = "GameplayCritical"
	
	# Réglages Audio 3D cruciaux pour l'orientation
	audio_player.max_distance = pulse_range
	audio_player.unit_size = 15.0  # Zone d'audibilité plus large
	audio_player.panning_strength = 2.0  # Exagérer la stéréo pour bien entendre gauche/droite
	
	# Modifier le pitch selon la distance (plus proche = plus aigu)
	var dist := _player.global_position.distance_to(current_target)
	var pitch := clamp(2.0 - (dist / 20.0), 0.5, 2.0)
	audio_player.pitch_scale = pitch
	
	audio_player.play()
	
	# Nettoyage après lecture
	audio_player.finished.connect(audio_player.queue_free)
	
	# Annonce TTS de la distance
	var accessibility_mgr = get_node_or_null("/root/AccessibilityManager")
	if accessibility_mgr and accessibility_mgr.has_method("speak"):
		var direction := get_direction_to_target()
		accessibility_mgr.speak("Objectif %s, %.0f mètres" % [direction, dist])


# ==============================================================================
# CONFIGURATION AUDIO
# ==============================================================================

func _setup_audio_players() -> void:
	"""Configure les lecteurs audio 3D."""
	# Objectif
	_objective_audio = AudioStreamPlayer3D.new()
	_objective_audio.name = "ObjectiveAudio"
	_objective_audio.max_distance = pulse_range
	_objective_audio.unit_size = 3.0
	_objective_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_objective_audio)
	
	# Ennemis
	_enemy_audio = AudioStreamPlayer3D.new()
	_enemy_audio.name = "EnemyAudio"
	_enemy_audio.max_distance = 20.0
	_enemy_audio.unit_size = 2.0
	add_child(_enemy_audio)
	
	# Murs/obstacles
	_wall_audio = AudioStreamPlayer3D.new()
	_wall_audio.name = "WallAudio"
	_wall_audio.max_distance = 10.0
	_wall_audio.unit_size = 1.0
	add_child(_wall_audio)
	
	# Ambiant (non-3D)
	_ambient_audio = AudioStreamPlayer3D.new()
	_ambient_audio.name = "AmbientAudio"
	add_child(_ambient_audio)


func _load_audio_streams() -> void:
	"""Charge les streams audio."""
	if ResourceLoader.exists(objective_sound_path):
		_objective_audio.stream = load(objective_sound_path)
	
	if ResourceLoader.exists(enemy_sound_path):
		_enemy_audio.stream = load(enemy_sound_path)
	
	if ResourceLoader.exists(wall_sound_path):
		_wall_audio.stream = load(wall_sound_path)


# ==============================================================================
# SONAR
# ==============================================================================

func _send_sonar_pulse() -> void:
	"""Envoie une impulsion sonar."""
	sonar_pulse_sent.emit()
	
	# Ping objectif
	if has_target:
		_ping_objective()
	
	# Détection ennemis
	if enemy_detection:
		_detect_enemies()
	
	# Détection obstacles
	if proximity_feedback:
		_detect_obstacles()
	
	# Détection pickups
	if item_detection:
		_detect_items()


func _ping_objective() -> void:
	"""Joue un son vers l'objectif."""
	if not _player or not has_target:
		return
	
	var distance := _player.global_position.distance_to(current_target)
	
	if distance > pulse_range:
		return
	
	# Positionner le son de l'objectif
	_objective_audio.global_position = current_target
	
	# Pitch basé sur la distance (plus proche = plus aigu)
	var distance_ratio := 1.0 - clamp(distance / pulse_range, 0.0, 1.0)
	_objective_audio.pitch_scale = lerp(min_pitch, max_pitch, distance_ratio)
	
	# Volume basé sur la distance
	_objective_audio.volume_db = lerp(-20.0, 0.0, distance_ratio)
	
	_objective_audio.play()
	
	# Vérifier si atteint
	if distance < 2.0:
		target_reached.emit()
		
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Objectif atteint")


func _detect_enemies() -> void:
	"""Détecte les ennemis proches et joue un son."""
	if not _player:
		return
	
	var enemies := get_tree().get_nodes_in_group("enemy")
	var closest_enemy: Node3D = null
	var closest_distance := 20.0
	
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		
		var dist := _player.global_position.distance_to(enemy.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest_enemy = enemy
	
	if closest_enemy:
		_enemy_audio.global_position = closest_enemy.global_position
		
		# Pitch selon distance (plus proche = plus rapide/aigu)
		var urgency := 1.0 - (closest_distance / 20.0)
		_enemy_audio.pitch_scale = lerp(0.8, 1.5, urgency)
		_enemy_audio.volume_db = lerp(-15.0, 0.0, urgency)
		
		_enemy_audio.play()
		
		# Annonce TTS si très proche
		if closest_distance < 5.0:
			var direction := _get_direction_name(_player, closest_enemy)
			
			var tts = get_node_or_null("/root/TTSManager")
			if tts:
				tts.speak_hint("Ennemi " + direction)


func _detect_obstacles() -> void:
	"""Détecte les murs/obstacles proches via raycasting."""
	if not _player:
		return
	
	var space := _player.get_world_3d().direct_space_state
	var player_pos := _player.global_position + Vector3(0, 1, 0)
	
	# Directions à vérifier
	var directions := {
		"devant": -_player.global_transform.basis.z,
		"derrière": _player.global_transform.basis.z,
		"gauche": -_player.global_transform.basis.x,
		"droite": _player.global_transform.basis.x
	}
	
	var closest_hit_distance := 10.0
	var closest_direction := ""
	var hit_position := Vector3.ZERO
	
	for dir_name in directions:
		var direction: Vector3 = directions[dir_name]
		
		var query := PhysicsRayQueryParameters3D.new()
		query.from = player_pos
		query.to = player_pos + direction * 5.0
		query.collision_mask = 1  # Couche obstacles
		
		var result := space.intersect_ray(query)
		
		if result and result.has("position"):
			var dist: float = player_pos.distance_to(result["position"])
			if dist < closest_hit_distance:
				closest_hit_distance = dist
				closest_direction = dir_name
				hit_position = result["position"]
	
	# Jouer le son si obstacle proche
	if closest_hit_distance < 3.0:
		_wall_audio.global_position = hit_position
		_wall_audio.volume_db = lerp(-20.0, -5.0, 1.0 - (closest_hit_distance / 3.0))
		_wall_audio.play()
		
		obstacle_detected.emit(closest_direction)


func _detect_items() -> void:
	"""Détecte les pickups proches."""
	if not _player:
		return
	
	var pickups := get_tree().get_nodes_in_group("pickup")
	
	for pickup in pickups:
		if not pickup is Node3D:
			continue
		
		var dist := _player.global_position.distance_to(pickup.global_position)
		
		if dist < 8.0:
			# Son subtil pour les items (utiliser objective audio avec pitch différent)
			# On ne joue pas systématiquement pour ne pas surcharger
			if dist < 3.0:
				var tts = get_node_or_null("/root/TTSManager")
				if tts:
					tts.speak_hint("Objet proche")
				break


# ==============================================================================
# CONTRÔLE
# ==============================================================================

func set_target(position: Vector3) -> void:
	"""Définit l'objectif de navigation."""
	current_target = position
	has_target = true
	target_updated.emit(position)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Nouvel objectif marqué")


func clear_target() -> void:
	"""Efface l'objectif."""
	has_target = false
	current_target = Vector3.ZERO


func enable() -> void:
	"""Active le sonar."""
	sonar_enabled = true


func disable() -> void:
	"""Désactive le sonar."""
	sonar_enabled = false


func set_pulse_interval(interval: float) -> void:
	"""Modifie l'intervalle entre les pings."""
	pulse_interval = clamp(interval, 0.5, 5.0)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _get_direction_name(from: Node3D, target: Node3D) -> String:
	"""Retourne la direction relative vers une cible."""
	var to_target := (target.global_position - from.global_position).normalized()
	var forward := -from.global_transform.basis.z
	var right := from.global_transform.basis.x
	
	var dot_forward := forward.dot(to_target)
	var dot_right := right.dot(to_target)
	
	if abs(dot_forward) > abs(dot_right):
		return "devant" if dot_forward > 0 else "derrière"
	else:
		return "à droite" if dot_right > 0 else "à gauche"


func get_distance_to_target() -> float:
	"""Retourne la distance jusqu'à l'objectif."""
	if not has_target or not _player:
		return -1.0
	return _player.global_position.distance_to(current_target)


func get_direction_to_target() -> String:
	"""Retourne la direction vers l'objectif."""
	if not has_target or not _player:
		return ""
	
	var dummy := Node3D.new()
	dummy.global_position = current_target
	var result := _get_direction_name(_player, dummy)
	dummy.free()
	return result
