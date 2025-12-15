# ==============================================================================
# HackingMinigame.gd - Mini-jeu de piratage
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Puzzle de piratage pour ouvrir portes, désactiver caméras, etc.
# Accessible avec audio feedback pour joueurs aveugles
# ==============================================================================

extends Control
class_name HackingMinigame

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal hack_started(target: Node)
signal hack_success
signal hack_failed
signal hack_cancelled
signal progress_changed(percent: float)

# ==============================================================================
# TYPES DE PUZZLES
# ==============================================================================
enum PuzzleType {
	SEQUENCE,    # Répéter une séquence
	TIMING,      # Appuyer au bon moment
	PATTERN,     # Trouver le pattern
	MEMORY       # Mémoriser et reproduire
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Configuration")
@export var puzzle_type: PuzzleType = PuzzleType.SEQUENCE
@export var difficulty: int = 1  ## 1-5
@export var time_limit: float = 30.0  ## Temps pour résoudre
@export var max_attempts: int = 3

@export_group("Audio")
@export var success_sound: AudioStream
@export var fail_sound: AudioStream
@export var beep_sounds: Array[AudioStream]  ## Sons pour chaque input

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_active: bool = false
var current_target: Node = null
var remaining_time: float = 0.0
var attempts_left: int = 0

# Puzzle SEQUENCE
var _sequence: Array[int] = []  # Séquence à reproduire
var _player_input: Array[int] = []  # Inputs du joueur
var _sequence_index: int = 0

# Puzzle TIMING
var _cursor_position: float = 0.0
var _target_zone_start: float = 0.0
var _target_zone_end: float = 0.0
var _cursor_speed: float = 1.0

# Audio
@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	add_child(audio_player)
	audio_player.bus = "Interface"
	visible = false


func _process(delta: float) -> void:
	"""Mise à jour du puzzle."""
	if not is_active:
		return
	
	# Timer
	remaining_time -= delta
	if remaining_time <= 0:
		_on_timeout()
		return
	
	# Update selon le type
	match puzzle_type:
		PuzzleType.TIMING:
			_update_timing_puzzle(delta)


func _input(event: InputEvent) -> void:
	"""Gestion des inputs."""
	if not is_active:
		return
	
	# Annuler avec Escape
	if event.is_action_pressed("pause"):
		cancel_hack()
		return
	
	# Inputs du puzzle
	if event.is_action_pressed("attack") or (event is InputEventScreenTouch and event.pressed):
		_handle_puzzle_input(0)
	elif event.is_action_pressed("dash"):
		_handle_puzzle_input(1)
	elif event.is_action_pressed("interact"):
		_handle_puzzle_input(2)


# ==============================================================================
# DÉMARRAGE DU HACK
# ==============================================================================

func start_hack(target: Node, type: PuzzleType = PuzzleType.SEQUENCE, diff: int = 1) -> void:
	"""
	Démarre un mini-jeu de piratage.
	@param target: L'objet à pirater
	@param type: Type de puzzle
	@param diff: Difficulté (1-5)
	"""
	current_target = target
	puzzle_type = type
	difficulty = clamp(diff, 1, 5)
	
	# Initialiser
	remaining_time = time_limit - (difficulty * 3)  # Plus dur = moins de temps
	attempts_left = max_attempts
	is_active = true
	visible = true
	
	# Setup selon le type
	match puzzle_type:
		PuzzleType.SEQUENCE:
			_setup_sequence_puzzle()
		PuzzleType.TIMING:
			_setup_timing_puzzle()
		PuzzleType.MEMORY:
			_setup_memory_puzzle()
	
	hack_started.emit(target)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Piratage démarré. " + _get_puzzle_instructions())


func _get_puzzle_instructions() -> String:
	"""Retourne les instructions pour le TTS."""
	match puzzle_type:
		PuzzleType.SEQUENCE:
			return "Écoutez la séquence et reproduisez-la avec les boutons Attaque, Dash, et Interaction."
		PuzzleType.TIMING:
			return "Appuyez sur Attaque quand le curseur est dans la zone verte."
		PuzzleType.MEMORY:
			return "Mémorisez les positions qui s'allument."
	return "Complétez le puzzle."


# ==============================================================================
# PUZZLE SÉQUENCE
# ==============================================================================

func _setup_sequence_puzzle() -> void:
	"""Configure le puzzle de séquence."""
	_sequence.clear()
	_player_input.clear()
	_sequence_index = 0
	
	# Générer une séquence
	var length := 3 + difficulty
	for i in range(length):
		_sequence.append(randi() % 3)  # 0, 1, ou 2
	
	# Jouer la séquence
	_play_sequence()


func _play_sequence() -> void:
	"""Joue la séquence audio."""
	for i in range(_sequence.size()):
		await get_tree().create_timer(0.5).timeout
		_play_beep(_sequence[i])
		
		# TTS pour accessibilité
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			var names := ["Attaque", "Dash", "Interaction"]
			tts.speak(names[_sequence[i]])


func _handle_sequence_input(input_index: int) -> void:
	"""Gère un input pour le puzzle séquence."""
	_player_input.append(input_index)
	_play_beep(input_index)
	
	# Vérifier si correct
	var expected := _sequence[_player_input.size() - 1]
	if input_index != expected:
		_on_wrong_input()
		return
	
	# Vérifier si séquence complète
	if _player_input.size() >= _sequence.size():
		_on_hack_success()


# ==============================================================================
# PUZZLE TIMING
# ==============================================================================

func _setup_timing_puzzle() -> void:
	"""Configure le puzzle de timing."""
	_cursor_position = 0.0
	_cursor_speed = 0.5 + (difficulty * 0.2)
	
	# Zone cible (plus petite = plus dur)
	var zone_size := 0.3 - (difficulty * 0.04)
	_target_zone_start = randf_range(0.2, 0.7 - zone_size)
	_target_zone_end = _target_zone_start + zone_size


func _update_timing_puzzle(delta: float) -> void:
	"""Met à jour le puzzle timing."""
	_cursor_position += _cursor_speed * delta
	if _cursor_position > 1.0:
		_cursor_position = 0.0
	
	progress_changed.emit(_cursor_position * 100)


func _handle_timing_input() -> void:
	"""Gère un input pour le puzzle timing."""
	# Vérifier si dans la zone
	if _cursor_position >= _target_zone_start and _cursor_position <= _target_zone_end:
		_on_hack_success()
	else:
		_on_wrong_input()


# ==============================================================================
# PUZZLE MÉMOIRE
# ==============================================================================

func _setup_memory_puzzle() -> void:
	"""Configure le puzzle mémoire."""
	_sequence.clear()
	_player_input.clear()
	
	# Générer des positions à mémoriser
	var count := 2 + difficulty
	for i in range(count):
		_sequence.append(randi() % 9)  # Grille 3x3
	
	# Montrer les positions
	_show_memory_pattern()


func _show_memory_pattern() -> void:
	"""Affiche le pattern à mémoriser."""
	for pos in _sequence:
		# Flash visuel
		await get_tree().create_timer(0.6).timeout
		_play_beep(pos % 3)
		
		# TTS: position
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			var row := pos / 3 + 1
			var col := pos % 3 + 1
			tts.speak("Ligne " + str(row) + ", colonne " + str(col))


# ==============================================================================
# RÉSULTATS
# ==============================================================================

func _on_hack_success() -> void:
	"""Hack réussi."""
	is_active = false
	visible = false
	
	if success_sound:
		audio_player.stream = success_sound
		audio_player.play()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Piratage réussi !")
	
	# Appliquer l'effet sur la cible
	if current_target and current_target.has_method("on_hacked"):
		current_target.on_hacked()
	
	hack_success.emit()
	
	# Achievement
	var ach = get_node_or_null("/root/AchievementManager")
	if ach:
		ach.increment_stat("hacks_completed")


func _on_wrong_input() -> void:
	"""Mauvais input."""
	attempts_left -= 1
	
	if fail_sound:
		audio_player.stream = fail_sound
		audio_player.play()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Erreur ! " + str(attempts_left) + " essais restants.")
	
	if attempts_left <= 0:
		_on_hack_failed()
	else:
		# Réinitialiser pour réessayer
		_player_input.clear()


func _on_hack_failed() -> void:
	"""Hack échoué."""
	is_active = false
	visible = false
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Piratage échoué ! Alerte déclenchée.")
	
	# Déclencher une alerte sur la cible
	if current_target and current_target.has_method("on_hack_failed"):
		current_target.on_hack_failed()
	
	hack_failed.emit()


func _on_timeout() -> void:
	"""Temps écoulé."""
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Temps écoulé !")
	
	_on_hack_failed()


func cancel_hack() -> void:
	"""Annule le hack."""
	is_active = false
	visible = false
	hack_cancelled.emit()


# ==============================================================================
# AUDIO
# ==============================================================================

func _play_beep(index: int) -> void:
	"""Joue un son de beep."""
	if index < beep_sounds.size() and beep_sounds[index]:
		audio_player.stream = beep_sounds[index]
		audio_player.pitch_scale = 0.8 + (index * 0.2)  # Pitch différent par bouton
		audio_player.play()


func _handle_puzzle_input(input_index: int) -> void:
	"""Redirige l'input selon le type de puzzle."""
	match puzzle_type:
		PuzzleType.SEQUENCE, PuzzleType.MEMORY:
			_handle_sequence_input(input_index)
		PuzzleType.TIMING:
			_handle_timing_input()
