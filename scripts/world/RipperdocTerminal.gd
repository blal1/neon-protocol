# ==============================================================================
# RipperdocTerminal.gd - Terminal pour les augmentations cybernétiques
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends MissionTerminal
class_name RipperdocTerminal

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@export var cyberware_ui_scene: PackedScene = preload("res://scenes/ui/CyberwareUI.tscn")

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	super._ready()
	terminal_name = "Clinique Ripperdoc"
	add_to_group("ripperdoc")


# ==============================================================================
# INTERACTION
# ==============================================================================

func interact(interactor: Node3D) -> void:
	"""Ouvre l'interface de Cyberware."""
	# Feedback audio
	var sfx = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play_ui("click")
		
	# Instancier l'UI si elle n'existe pas déjà
	var hud = get_tree().root.find_child("GameHUD", true, false)
	if not hud: return
	
	var ui = hud.get_node_or_null("CyberwareUI")
	if not ui:
		ui = cyberware_ui_scene.instantiate()
		hud.add_child(ui)
		
	if ui.has_method("open"):
		ui.open()
	else:
		ui.show()
		
	# Optionnel: Pause le jeu ou fige le joueur
	if interactor.has_method("set_physics_process"):
		interactor.set_physics_process(false)
		ui.closed.connect(func(): interactor.set_physics_process(true), CONNECT_ONE_SHOT)
