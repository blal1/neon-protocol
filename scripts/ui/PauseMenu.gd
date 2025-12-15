# ==============================================================================
# PauseMenu.gd - Menu de pause in-game
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends CanvasLayer

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal resumed
signal options_opened
signal quit_to_menu

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
@onready var panel: Control = $Panel
@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var options_button: Button = $Panel/VBox/OptionsButton
@onready var quit_button: Button = $Panel/VBox/QuitButton

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_paused: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du menu pause."""
	hide_menu()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Fonctionne même en pause


func _input(event: InputEvent) -> void:
	"""Gestion de la touche Escape."""
	if event.is_action_pressed("pause"):
		toggle_pause()


# ==============================================================================
# PAUSE
# ==============================================================================

func toggle_pause() -> void:
	"""Bascule l'état de pause."""
	if is_paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	"""Met le jeu en pause."""
	is_paused = true
	get_tree().paused = true
	show_menu()
	
	# TTS pour accessibilité
	var tts = get_node_or_null("/root/TTSManager")
	if tts and tts.has_method("speak"):
		tts.speak("Jeu en pause")


func resume_game() -> void:
	"""Reprend le jeu."""
	is_paused = false
	get_tree().paused = false
	hide_menu()
	resumed.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts and tts.has_method("speak"):
		tts.speak("Reprise du jeu")


# ==============================================================================
# AFFICHAGE
# ==============================================================================

func show_menu() -> void:
	"""Affiche le menu pause."""
	panel.visible = true
	layer = 100  # Au-dessus de tout
	
	# Focus sur le premier bouton pour accessibilité
	if resume_button:
		resume_button.grab_focus()


func hide_menu() -> void:
	"""Cache le menu pause."""
	panel.visible = false


# ==============================================================================
# CALLBACKS BOUTONS
# ==============================================================================

func _on_resume_pressed() -> void:
	"""Bouton Reprendre."""
	resume_game()


func _on_options_pressed() -> void:
	"""Bouton Options."""
	options_opened.emit()
	
	# Charger et afficher le menu options
	var options_scene := load("res://scenes/ui/OptionsMenu.tscn")
	if options_scene:
		var options_menu := options_scene.instantiate()
		options_menu.name = "OptionsMenuInstance"
		add_child(options_menu)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Menu options")


func _on_quit_pressed() -> void:
	"""Bouton Quitter."""
	is_paused = false
	get_tree().paused = false
	quit_to_menu.emit()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
