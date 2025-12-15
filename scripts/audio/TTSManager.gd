# ==============================================================================
# TTSManager.gd - Gestionnaire Text-to-Speech
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Wrapper pour le TTS natif de Godot (DisplayServer.tts_speak)
# Gère la file d'attente, les priorités, et l'internationalisation
# ==============================================================================

extends Node
# class_name TTSManager removed - conflicts with autoload singleton

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal speech_started(text: String)
signal speech_finished
signal voice_changed(voice_id: String)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Configuration")
@export var enabled: bool = true
@export var default_rate: float = 1.0  ## Vitesse de parole (0.5 - 2.0)
@export var default_pitch: float = 1.0  ## Hauteur de voix (0.5 - 2.0)
@export var default_volume: float = 100.0  ## Volume (0 - 100)

@export_group("Voix")
@export var preferred_language: String = "fr"  ## Code langue (fr, en, es...)
@export var voice_id: String = ""  ## ID de voix spécifique (vide = auto)

@export_group("File d'attente")
@export var queue_enabled: bool = true  ## Utiliser une file d'attente
@export var interrupt_on_priority: bool = true  ## Interrompre pour haute priorité

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum Priority {
	LOW,      # Info optionnelle
	NORMAL,   # Messages standards
	HIGH,     # Alertes importantes
	CRITICAL  # Interrompt tout
}

# ==============================================================================
# CLASSES INTERNES
# ==============================================================================
class SpeechRequest:
	var text: String
	var priority: int
	var rate: float
	var pitch: float
	var volume: float
	
	func _init(t: String, p: int = Priority.NORMAL, r: float = 1.0, pi: float = 1.0, v: float = 100.0):
		text = t
		priority = p
		rate = r
		pitch = pi
		volume = v

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _speech_queue: Array[SpeechRequest] = []
var _is_speaking: bool = false
var _available_voices: Array = []
var _current_voice: String = ""
var _tts_available: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du TTS."""
	_check_tts_availability()
	_load_voices()
	_select_voice()


func _process(_delta: float) -> void:
	"""Gestion de la file d'attente."""
	if not enabled or not _tts_available:
		return
	
	# Vérifier si la parole est terminée
	if _is_speaking and not DisplayServer.tts_is_speaking():
		_is_speaking = false
		speech_finished.emit()
		_process_queue()


# ==============================================================================
# PAROLE
# ==============================================================================

func speak(text: String, priority: int = Priority.NORMAL) -> void:
	"""
	Lit un texte à voix haute.
	@param text: Texte à lire
	@param priority: Niveau de priorité
	"""
	if not enabled or not _tts_available or text.is_empty():
		return
	
	var request := SpeechRequest.new(text, priority, default_rate, default_pitch, default_volume)
	
	# Priorité critique : interrompt tout
	if priority == Priority.CRITICAL:
		stop()
		_speak_now(request)
		return
	
	# Haute priorité : peut interrompre
	if priority == Priority.HIGH and interrupt_on_priority:
		stop()
		_speak_now(request)
		return
	
	# File d'attente
	if queue_enabled:
		_add_to_queue(request)
		if not _is_speaking:
			_process_queue()
	else:
		# Pas de file : remplacer
		stop()
		_speak_now(request)


func speak_immediate(text: String) -> void:
	"""Lit immédiatement, interrompant tout."""
	speak(text, Priority.CRITICAL)


func speak_menu(item_name: String) -> void:
	"""Lit un élément de menu."""
	speak(item_name, Priority.HIGH)


func speak_notification(text: String) -> void:
	"""Lit une notification."""
	speak(text, Priority.NORMAL)


func speak_hint(text: String) -> void:
	"""Lit un indice/conseil (basse priorité)."""
	speak(text, Priority.LOW)


# ==============================================================================
# CONTRÔLE
# ==============================================================================

func stop() -> void:
	"""Arrête la parole en cours."""
	DisplayServer.tts_stop()
	_speech_queue.clear()
	_is_speaking = false


func pause() -> void:
	"""Met en pause la parole."""
	DisplayServer.tts_pause()


func resume() -> void:
	"""Reprend la parole."""
	DisplayServer.tts_resume()


func is_speaking() -> bool:
	"""Retourne true si en train de parler."""
	return _is_speaking or DisplayServer.tts_is_speaking()


# ==============================================================================
# FILE D'ATTENTE
# ==============================================================================

func _add_to_queue(request: SpeechRequest) -> void:
	"""Ajoute une requête à la file."""
	# Limiter la taille de la file (prévenir overflow)
	const MAX_QUEUE_SIZE := 10
	if _speech_queue.size() >= MAX_QUEUE_SIZE:
		# Retirer les éléments de basse priorité
		for i in range(_speech_queue.size() - 1, -1, -1):
			if _speech_queue[i].priority <= Priority.LOW:
				_speech_queue.remove_at(i)
				break
		# Si toujours plein, retirer le plus ancien
		if _speech_queue.size() >= MAX_QUEUE_SIZE:
			_speech_queue.pop_back()
	
	# Insérer selon la priorité
	var insert_index := _speech_queue.size()
	for i in range(_speech_queue.size()):
		if _speech_queue[i].priority < request.priority:
			insert_index = i
			break
	
	_speech_queue.insert(insert_index, request)


func _process_queue() -> void:
	"""Traite le prochain élément de la file."""
	if _speech_queue.is_empty():
		return
	
	var next_request: SpeechRequest = _speech_queue.pop_front()
	_speak_now(next_request)


func _speak_now(request: SpeechRequest) -> void:
	"""Exécute la lecture immédiate."""
	_is_speaking = true
	speech_started.emit(request.text)
	
	DisplayServer.tts_speak(
		request.text,
		_current_voice,
		int(request.volume),
		request.pitch,
		request.rate
	)


# ==============================================================================
# CONFIGURATION DES VOIX
# ==============================================================================

func _check_tts_availability() -> void:
	"""Vérifie si le TTS est disponible."""
	_tts_available = DisplayServer.tts_is_speaking() or DisplayServer.tts_get_voices().size() > 0
	
	if not _tts_available:
		push_warning("TTSManager: TTS non disponible sur cette plateforme")


func _load_voices() -> void:
	"""Charge la liste des voix disponibles."""
	_available_voices = DisplayServer.tts_get_voices()


func _select_voice() -> void:
	"""Sélectionne la meilleure voix selon les préférences."""
	if _available_voices.is_empty():
		return
	
	# Si voix spécifique demandée
	if not voice_id.is_empty():
		for voice in _available_voices:
			if voice == voice_id:
				_current_voice = voice_id
				voice_changed.emit(_current_voice)
				return
	
	# Chercher une voix dans la langue préférée
	for voice in _available_voices:
		var voice_str := str(voice)
		if preferred_language.to_lower() in voice_str.to_lower():
			_current_voice = voice_str
			voice_changed.emit(_current_voice)
			return
	
	# Fallback : première voix disponible
	_current_voice = str(_available_voices[0])
	voice_changed.emit(_current_voice)


func get_available_voices() -> Array:
	"""Retourne la liste des voix disponibles."""
	return _available_voices


func set_voice(new_voice_id: String) -> void:
	"""Définit la voix à utiliser."""
	voice_id = new_voice_id
	_current_voice = new_voice_id
	voice_changed.emit(new_voice_id)


func set_rate(rate: float) -> void:
	"""Définit la vitesse de parole."""
	default_rate = clamp(rate, 0.5, 2.0)


func set_pitch(pitch: float) -> void:
	"""Définit la hauteur de voix."""
	default_pitch = clamp(pitch, 0.5, 2.0)


func set_volume(volume: float) -> void:
	"""Définit le volume TTS."""
	default_volume = clamp(volume, 0.0, 100.0)


# ==============================================================================
# MESSAGES PRÉDÉFINIS (ACCESSIBILITÉ)
# ==============================================================================

func announce_health(current: float, max_health: float) -> void:
	"""Annonce l'état de santé."""
	var percentage := int((current / max_health) * 100.0)
	speak("Santé à %d pourcent" % percentage)


func announce_enemy_count(count: int) -> void:
	"""Annonce le nombre d'ennemis."""
	if count == 0:
		speak("Aucun ennemi détecté")
	elif count == 1:
		speak("Un ennemi à proximité")
	else:
		speak("%d ennemis à proximité" % count)


func announce_mission(title: String) -> void:
	"""Annonce une nouvelle mission."""
	speak("Nouvelle mission : " + title, Priority.HIGH)


func announce_mission_complete(title: String) -> void:
	"""Annonce la fin d'une mission."""
	speak("Mission accomplie : " + title, Priority.HIGH)


func announce_item_pickup(item_name: String) -> void:
	"""Annonce le ramassage d'un objet."""
	speak("Récupéré : " + item_name)


func announce_damage_received(amount: float, direction: String) -> void:
	"""Annonce les dégâts reçus."""
	speak("Dégâts %s, %.0f points" % [direction, amount], Priority.HIGH)
