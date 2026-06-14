# ==============================================================================
# MissionTerminal.gd - Terminal interactif pour obtenir des missions
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends StaticBody3D
class_name MissionTerminal

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export var terminal_name: String = "Terminal NovaTech"
@export var dialogue_id: String = "terminal_generic"

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("mission_terminal")
	
	# Créer une zone d'interaction si nécessaire
	_setup_collision()


func _setup_collision() -> void:
	# S'assurer que le terminal est sur la couche 4 (Interactable)
	collision_layer = 8 # Layer 4
	collision_mask = 0


# ==============================================================================
# INTERACTION
# ==============================================================================

func interact(_interactor: Node3D) -> void:
	"""Appelé quand le joueur interagit avec le terminal."""
	if DialogueSystem:
		DialogueSystem.start_npc_dialogue(dialogue_id)
		
	# Feedback audio
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play_ui("click")


func get_display_name() -> String:
	return terminal_name
