# ==============================================================================
# MusicManager.gd - Gestionnaire de musique d'ambiance
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les tracks musicales, transitions, et ambiance
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal track_changed(track_name: String)
signal music_faded_out
signal music_faded_in

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum MusicContext {
	MENU,
	EXPLORATION,
	COMBAT,
	STEALTH,
	BOSS,
	CUTSCENE,
	VICTORY,
	GAMEOVER
}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MUSIC_PATH := "res://audio/music/"
const DEFAULT_VOLUME := -5.0
const FADE_DURATION := 1.5

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var auto_play: bool = true
@export var default_context: MusicContext = MusicContext.MENU

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_context: MusicContext = MusicContext.MENU
var current_track: String = ""
var is_playing: bool = false
var _target_volume: float = DEFAULT_VOLUME

# Dictionnaire des tracks par contexte (noms de fichiers dans audio/music/)
var tracks: Dictionary = {
	MusicContext.MENU: ["Dark 80's Synth", "Twilight", "Neon Alley"],
	MusicContext.EXPLORATION: ["Erebus", "The Cosmic Crypt", "Reaching the Event Horizon", "Solar Flare"],
	MusicContext.COMBAT: ["A Call to Action", "Invasion", "Lazerface", "Lizard King"],
	MusicContext.STEALTH: ["Heavy Anxiety", "Predators Await", "Is Anyone There_"],
	MusicContext.BOSS: ["Extinction", "The Evil Transforms", "Madness"],
	MusicContext.CUTSCENE: ["Arrival to Carcosa", "Horror Piano", "The Replicant"],
	MusicContext.VICTORY: ["There Is Hope", "Sovereign"],
	MusicContext.GAMEOVER: ["Death Do Us Part", "Return to the Nightmare", "Every Town a Ghost Town"]
}

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
var _main_player: AudioStreamPlayer
var _crossfade_player: AudioStreamPlayer

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du gestionnaire de musique."""
	_create_audio_players()
	
	if auto_play:
		play_context(default_context)


func _create_audio_players() -> void:
	"""Crée les lecteurs audio."""
	_main_player = AudioStreamPlayer.new()
	_main_player.bus = "Music"
	_main_player.volume_db = DEFAULT_VOLUME
	add_child(_main_player)
	
	_crossfade_player = AudioStreamPlayer.new()
	_crossfade_player.bus = "Music"
	_crossfade_player.volume_db = -80.0
	add_child(_crossfade_player)
	
	# Connexion pour boucler
	_main_player.finished.connect(_on_track_finished)


# ==============================================================================
# LECTURE
# ==============================================================================

func play_context(context: MusicContext, crossfade: bool = true) -> void:
	"""
	Joue de la musique pour un contexte donné.
	@param context: Le contexte musical
	@param crossfade: Effectuer un crossfade
	"""
	if context == current_context and is_playing:
		return
	
	current_context = context
	
	var track_list: Array = tracks.get(context, [])
	if track_list.is_empty():
		stop()
		return
	
	# Choisir une track aléatoirement
	var track_name: String = track_list[randi() % track_list.size()]
	
	if crossfade and is_playing:
		_crossfade_to(track_name)
	else:
		_play_track(track_name)


func play_track(track_name: String, crossfade: bool = true) -> void:
	"""Joue une track spécifique."""
	if crossfade and is_playing:
		_crossfade_to(track_name)
	else:
		_play_track(track_name)


func _play_track(track_name: String) -> void:
	"""Joue une track directement."""
	var stream := _load_track(track_name)
	if not stream:
		push_warning("MusicManager: Track introuvable: " + track_name)
		return
	
	_main_player.stream = stream
	_main_player.volume_db = _target_volume
	_main_player.play()
	
	current_track = track_name
	is_playing = true
	
	track_changed.emit(track_name)
	print("MusicManager: Lecture de '%s'" % track_name)


func _crossfade_to(track_name: String) -> void:
	"""Effectue un crossfade vers une nouvelle track."""
	var stream := _load_track(track_name)
	if not stream:
		return
	
	# Démarrer la nouvelle track sur le crossfade player
	_crossfade_player.stream = stream
	_crossfade_player.volume_db = -80.0
	_crossfade_player.play()
	
	# Crossfade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_main_player, "volume_db", -80.0, FADE_DURATION)
	tween.tween_property(_crossfade_player, "volume_db", _target_volume, FADE_DURATION)
	
	await tween.finished
	
	# Échanger les players
	_main_player.stop()
	var temp := _main_player
	_main_player = _crossfade_player
	_crossfade_player = temp
	
	current_track = track_name
	track_changed.emit(track_name)


func _load_track(track_name: String) -> AudioStream:
	"""Charge une track depuis les ressources."""
	var extensions := ["ogg", "mp3", "wav"]
	
	for ext in extensions:
		var path: String = MUSIC_PATH + track_name + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	
	return null


# ==============================================================================
# CONTRÔLES
# ==============================================================================

func stop(fade: bool = true) -> void:
	"""Arrête la musique."""
	if not is_playing:
		return
	
	if fade:
		var tween := create_tween()
		tween.tween_property(_main_player, "volume_db", -80.0, FADE_DURATION)
		await tween.finished
		music_faded_out.emit()
	
	_main_player.stop()
	is_playing = false
	current_track = ""


func pause() -> void:
	"""Met en pause."""
	_main_player.stream_paused = true


func resume() -> void:
	"""Reprend la lecture."""
	_main_player.stream_paused = false


func set_volume(volume_db: float) -> void:
	"""Définit le volume."""
	_target_volume = volume_db
	_main_player.volume_db = volume_db


func get_volume() -> float:
	"""Retourne le volume actuel."""
	return _target_volume


# ==============================================================================
# TRANSITIONS CONTEXTUELLES
# ==============================================================================

func enter_combat() -> void:
	"""Transition vers la musique de combat."""
	play_context(MusicContext.COMBAT)


func exit_combat() -> void:
	"""Retour à l'exploration."""
	play_context(MusicContext.EXPLORATION)


func enter_stealth() -> void:
	"""Transition vers la musique furtive."""
	play_context(MusicContext.STEALTH)


func enter_boss() -> void:
	"""Musique de boss."""
	play_context(MusicContext.BOSS)


func play_victory() -> void:
	"""Joue le thème de victoire."""
	play_context(MusicContext.VICTORY, false)


func play_gameover() -> void:
	"""Joue le thème de game over."""
	play_context(MusicContext.GAMEOVER, false)


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_track_finished() -> void:
	"""Appelé quand une track se termine."""
	# Rejouer la même track (loop manuel)
	if is_playing and current_track:
		_main_player.play()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_context_name() -> String:
	"""Retourne le nom du contexte actuel."""
	return MusicContext.keys()[current_context]


func is_music_playing() -> bool:
	"""Retourne true si de la musique joue."""
	return is_playing
