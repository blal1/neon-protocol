# ==============================================================================
# TutorialLevel.gd - Contrôleur du niveau tutoriel
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère la progression du tutoriel avec objectifs guidés
# ==============================================================================

extends Node3D

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal tutorial_step_completed(step_index: int)
signal tutorial_completed

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum TutorialStep {
	MOVEMENT,
	CAMERA,
	INTERACTION,
	COMBAT,
	COMPLETED
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var player_spawn_point: Marker3D
@export var target_dummy_scene: PackedScene
@export var interaction_target: Node3D

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_step: TutorialStep = TutorialStep.MOVEMENT
var _is_active: bool = true

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du tutoriel."""
	_start_tutorial()


func _process(_delta: float) -> void:
	if not _is_active:
		return
		
	_check_progression()


# ==============================================================================
# LOGIQUE DU TUTORIEL
# ==============================================================================

func _start_tutorial() -> void:
	"""Démarre le tutoriel."""
	current_step = TutorialStep.MOVEMENT
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Bienvenue, Runner. Utilisez Z, Q, S, D pour vous déplacer dans la zone.")


func _check_progression() -> void:
	"""Vérifie si l'étape actuelle est validée."""
	match current_step:
		TutorialStep.MOVEMENT:
			# Logique de détection de mouvement
			pass
		TutorialStep.CAMERA:
			# Logique de rotation caméra
			pass


func complete_step() -> void:
	"""Valide l'étape actuelle et passe à la suivante."""
	tutorial_step_completed.emit(current_step)
	
	match current_step:
		TutorialStep.MOVEMENT:
			current_step = TutorialStep.CAMERA
			_announce_step("Mouvement validé. Utilisez la souris pour regarder autour de vous.")
		TutorialStep.CAMERA:
			current_step = TutorialStep.INTERACTION
			_announce_step("Caméra validée. Approchez-vous du terminal et appuyez sur E pour interagir.")
		TutorialStep.INTERACTION:
			current_step = TutorialStep.COMBAT
			_announce_step("Interaction validée. Un drone d'entraînement a été déployé. Utilisez J pour attaquer.")
		TutorialStep.COMBAT:
			current_step = TutorialStep.COMPLETED
			_finish_tutorial()


func _announce_step(message: String) -> void:
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak(message)


func _finish_tutorial() -> void:
	"""Termine le tutoriel."""
	_is_active = false
	tutorial_completed.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Tutoriel terminé. Vous êtes prêt pour la ville.")


func skip_tutorial() -> void:
	"""Passe le tutoriel."""
	_is_active = false
	tutorial_completed.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Tutoriel passé")
