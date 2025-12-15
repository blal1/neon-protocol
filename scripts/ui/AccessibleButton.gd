# ==============================================================================
# AccessibleButton.gd - Bouton accessible avec TTS
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Script générique pour tous les boutons du menu
# Lit le texte du bouton lors du focus et joue des sons UI
# ==============================================================================

extends Button
class_name AccessibleButton

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var custom_description: String = ""  ## Description personnalisée pour TTS
@export var play_sounds: bool = true  ## Jouer les sons de focus/sélection

# ==============================================================================
# CHEMINS AUDIO
# ==============================================================================
const FOCUS_SOUND_PATH := "res://audio/sfx/ui/click_001.ogg"
const SELECT_SOUND_PATH := "res://audio/sfx/ui/select_001.ogg"

# ==============================================================================
# CACHE AUDIO
# ==============================================================================
var _focus_sound: AudioStream = null
var _select_sound: AudioStream = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du bouton accessible."""
	# Connecter les signaux
	focus_entered.connect(_on_focus_entered)
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)
	
	# Précharger les sons
	if ResourceLoader.exists(FOCUS_SOUND_PATH):
		_focus_sound = load(FOCUS_SOUND_PATH)
	if ResourceLoader.exists(SELECT_SOUND_PATH):
		_select_sound = load(SELECT_SOUND_PATH)


# ==============================================================================
# GESTION DES ÉVÉNEMENTS
# ==============================================================================

func _on_focus_entered() -> void:
	"""Appelée quand le bouton reçoit le focus clavier/manette."""
	_announce_button()
	_play_focus_sound()


func _on_mouse_entered() -> void:
	"""Appelée quand la souris survole le bouton."""
	# Donner le focus pour unifier le comportement souris/clavier
	grab_focus()


func _on_pressed() -> void:
	"""Appelée quand le bouton est pressé."""
	_play_select_sound()


# ==============================================================================
# TTS ET AUDIO
# ==============================================================================

func _announce_button() -> void:
	"""Annonce le texte du bouton via TTS."""
	var accessibility_manager = get_node_or_null("/root/AccessibilityManager")
	if not accessibility_manager:
		return
	
	# Utiliser la description personnalisée si disponible
	var text_to_read := custom_description if custom_description != "" else text
	
	# Fallback sur le nom du noeud si pas de texte
	if text_to_read == "":
		text_to_read = name.replace("_", " ")
	
	# Appeler la fonction speak du manager
	if accessibility_manager.has_method("speak"):
		accessibility_manager.speak(text_to_read, true)


func _play_focus_sound() -> void:
	"""Joue le son de focus."""
	if not play_sounds or not _focus_sound:
		return
	
	_play_ui_sound(_focus_sound)


func _play_select_sound() -> void:
	"""Joue le son de sélection."""
	if not play_sounds or not _select_sound:
		return
	
	_play_ui_sound(_select_sound)


func _play_ui_sound(stream: AudioStream) -> void:
	"""Joue un son UI via AccessibilityManager ou directement."""
	var accessibility_manager = get_node_or_null("/root/AccessibilityManager")
	
	if accessibility_manager and accessibility_manager.has_method("play_ui_sound"):
		accessibility_manager.play_ui_sound(stream)
	else:
		# Fallback: créer un AudioStreamPlayer temporaire
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "UI"
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
