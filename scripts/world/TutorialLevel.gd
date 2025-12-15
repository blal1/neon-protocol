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
signal tutorial_started
signal step_completed(step_index: int, step_name: String)
signal tutorial_completed
signal objective_shown(objective_text: String)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var auto_start_tutorial: bool = true
@export var skip_completed_steps: bool = true

# ==============================================================================
# ÉTAPES DU TUTORIEL
# ==============================================================================
enum TutorialStep {
	INTRODUCTION,
	MOVEMENT,
	ATTACK,
	DASH,
	INTERACT,
	COMBAT,
	COMPLETE
}

var steps_data: Dictionary = {
	TutorialStep.INTRODUCTION: {
		"title": "Bienvenue",
		"description": "Bienvenue dans Neo-Kyoto, Runner. Je suis ARIA, ton interface neurale.",
		"objective": "Appuyez sur n'importe quelle touche pour continuer",
		"wait_for": "any_input"
	},
	TutorialStep.MOVEMENT: {
		"title": "Déplacement",
		"description": "Utilise le joystick gauche ou les touches WASD pour te déplacer.",
		"objective": "Déplacez-vous vers la zone lumineuse devant vous",
		"wait_for": "reach_zone",
		"zone": "Zone1_Movement"
	},
	TutorialStep.ATTACK: {
		"title": "Combat",
		"description": "Appuie sur le bouton d'attaque pour frapper. Les combos infligent plus de dégâts.",
		"objective": "Effectuez 3 attaques",
		"wait_for": "attack_count",
		"required_count": 3
	},
	TutorialStep.DASH: {
		"title": "Dash",
		"description": "Le dash te permet d'esquiver les attaques et de traverser rapidement.",
		"objective": "Effectuez un dash vers la zone lumineuse",
		"wait_for": "reach_zone",
		"zone": "Zone3_Dash"
	},
	TutorialStep.INTERACT: {
		"title": "Interaction",
		"description": "Tu peux interagir avec les terminaux, portes et PNJ.",
		"objective": "Approchez-vous du terminal et interagissez",
		"wait_for": "interact"
	},
	TutorialStep.COMBAT: {
		"title": "Combat Réel",
		"description": "Des ennemis approchent. Élimine-les en utilisant tout ce que tu as appris.",
		"objective": "Éliminez tous les ennemis (0/3)",
		"wait_for": "kill_count",
		"required_count": 3
	},
	TutorialStep.COMPLETE: {
		"title": "Tutoriel Terminé",
		"description": "Excellent travail, Runner. Tu es prêt pour les rues de Neo-Kyoto.",
		"objective": "",
		"wait_for": "none"
	}
}

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_step: TutorialStep = TutorialStep.INTRODUCTION
var _player: Node3D = null
var _attack_count: int = 0
var _kill_count: int = 0
var _step_completed_flags: Array[bool] = []
var _is_active: bool = false

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var tutorial_zones: Node3D = $TutorialZones
@onready var enemy_spawns: Node3D = $EnemySpawns
@onready var spawn_point: Node3D = $SpawnPoint

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du niveau tutoriel."""
	# Initialiser les flags
	for i in range(TutorialStep.size()):
		_step_completed_flags.append(false)
	
	# Trouver le joueur
	_find_player()
	
	# Connecter les zones
	_connect_zones()
	
	# Démarrer le tutoriel
	if auto_start_tutorial:
		await get_tree().create_timer(1.0).timeout
		start_tutorial()


func _input(event: InputEvent) -> void:
	"""Gestion des inputs pour le tutoriel."""
	if not _is_active:
		return
	
	var step_data: Dictionary = steps_data[current_step]
	
	# Intro: n'importe quelle touche
	if current_step == TutorialStep.INTRODUCTION:
		if event is InputEventKey and event.pressed:
			_complete_current_step()
		elif event is InputEventScreenTouch and event.pressed:
			_complete_current_step()
	
	# Attaque
	if current_step == TutorialStep.ATTACK:
		if event.is_action_pressed("attack"):
			_attack_count += 1
			_update_objective_text()
			if _attack_count >= step_data.get("required_count", 3):
				_complete_current_step()
	
	# Dash
	if current_step == TutorialStep.DASH:
		if event.is_action_pressed("dash"):
			# Le dash est validé quand on atteint la zone
			pass
	
	# Interact
	if current_step == TutorialStep.INTERACT:
		if event.is_action_pressed("interact"):
			_complete_current_step()


# ==============================================================================
# GESTION DU TUTORIEL
# ==============================================================================

func start_tutorial() -> void:
	"""Démarre le tutoriel."""
	_is_active = true
	current_step = TutorialStep.INTRODUCTION
	tutorial_started.emit()
	
	# Afficher l'intro
	_show_step(current_step)
	
	# Jouer la musique du tutoriel
	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.play_context(0)  # MENU context
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Tutoriel démarré")


func _show_step(step: TutorialStep) -> void:
	"""Affiche une étape du tutoriel."""
	var step_data: Dictionary = steps_data[step]
	
	# Afficher via TutorialManager
	var tutorial = get_node_or_null("/root/TutorialManager")
	if tutorial and tutorial.has_method("show_tip"):
		tutorial.show_tip(step_data["title"], step_data["description"])
	
	# Toast de l'objectif
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show("🎯 " + step_data["objective"], 0)  # INFO type
	
	objective_shown.emit(step_data["objective"])
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak(step_data["description"])
	
	# Activer la zone correspondante
	_highlight_zone(step_data.get("zone", ""))
	
	# Spawner les ennemis si nécessaire
	if step == TutorialStep.COMBAT:
		_spawn_tutorial_enemies()


func _complete_current_step() -> void:
	"""Termine l'étape actuelle."""
	_step_completed_flags[current_step] = true
	step_completed.emit(current_step, TutorialStep.keys()[current_step])
	
	# Notification de succès
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_success("✓ Étape complétée!")
	
	# Passer à l'étape suivante
	var next_step := current_step + 1
	if next_step < TutorialStep.COMPLETE:
		current_step = next_step as TutorialStep
		_reset_step_counters()
		await get_tree().create_timer(1.5).timeout
		_show_step(current_step)
	else:
		_complete_tutorial()


func _complete_tutorial() -> void:
	"""Termine le tutoriel."""
	current_step = TutorialStep.COMPLETE
	_is_active = false
	
	_show_step(TutorialStep.COMPLETE)
	tutorial_completed.emit()
	
	# Notification
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_achievement("Tutoriel Terminé", "Vous êtes prêt pour l'aventure!")
	
	# Sauvegarder la progression
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("set_setting"):
		save.set_setting("tutorial_completed", true)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Félicitations! Tutoriel terminé.")


# ==============================================================================
# ZONES
# ==============================================================================

func _connect_zones() -> void:
	"""Connecte les signaux des zones."""
	if not tutorial_zones:
		return
	
	for child in tutorial_zones.get_children():
		if child is Area3D:
			child.body_entered.connect(_on_zone_entered.bind(child.name))


func _on_zone_entered(body: Node3D, zone_name: String) -> void:
	"""Appelé quand le joueur entre dans une zone."""
	if not body.is_in_group("player"):
		return
	
	var step_data: Dictionary = steps_data[current_step]
	
	if step_data.get("wait_for") == "reach_zone" and step_data.get("zone") == zone_name:
		_complete_current_step()


func _highlight_zone(zone_name: String) -> void:
	"""Met en surbrillance une zone."""
	if not tutorial_zones or zone_name.is_empty():
		return
	
	# Désactiver toutes les lumières de zone
	for child in tutorial_zones.get_children():
		var marker = child.get_node_or_null("Marker")
		if marker:
			marker.visible = false
	
	# Activer la lumière de la zone cible
	var target_zone = tutorial_zones.get_node_or_null(zone_name)
	if target_zone:
		var marker = target_zone.get_node_or_null("Marker")
		if marker:
			marker.visible = true
			# Animation de pulsation
			var tween := create_tween().set_loops()
			tween.tween_property(marker, "scale", Vector3(1.3, 1.3, 1.3), 0.5)
			tween.tween_property(marker, "scale", Vector3.ONE, 0.5)


# ==============================================================================
# ENNEMIS
# ==============================================================================

func _spawn_tutorial_enemies() -> void:
	"""Fait apparaître les ennemis du tutoriel."""
	if not enemy_spawns:
		return
	
	var enemy_scene_path := "res://scenes/enemies/SecurityRobot.tscn"
	if not ResourceLoader.exists(enemy_scene_path):
		# Créer des ennemis factices
		for spawn_point in enemy_spawns.get_children():
			_create_dummy_enemy(spawn_point.global_position)
		return
	
	var enemy_scene := load(enemy_scene_path) as PackedScene
	
	for spawn_point in enemy_spawns.get_children():
		var enemy := enemy_scene.instantiate()
		enemy.global_position = spawn_point.global_position
		enemy.add_to_group("enemy")
		add_child(enemy)
		
		# Connecter le signal de mort
		var health = enemy.get_node_or_null("HealthComponent")
		if health:
			health.died.connect(_on_enemy_killed)


func _create_dummy_enemy(pos: Vector3) -> void:
	"""Crée un ennemi factice pour le tutoriel."""
	var enemy := CharacterBody3D.new()
	enemy.global_position = pos
	enemy.add_to_group("enemy")
	
	# Mesh simple
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 2, 1)
	mesh.mesh = box
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.1, 0.1)
	mesh.set_surface_override_material(0, mat)
	
	enemy.add_child(mesh)
	add_child(enemy)


func _on_enemy_killed() -> void:
	"""Appelé quand un ennemi est tué."""
	_kill_count += 1
	_update_objective_text()
	
	var step_data: Dictionary = steps_data[current_step]
	if current_step == TutorialStep.COMBAT:
		if _kill_count >= step_data.get("required_count", 3):
			_complete_current_step()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
	else:
		_player = $Player if has_node("Player") else null


func _reset_step_counters() -> void:
	"""Réinitialise les compteurs d'étape."""
	_attack_count = 0
	# Ne pas réinitialiser _kill_count entre les étapes


func _update_objective_text() -> void:
	"""Met à jour le texte de l'objectif."""
	var step_data: Dictionary = steps_data[current_step]
	var text := step_data.get("objective", "")
	
	if current_step == TutorialStep.ATTACK:
		text = "Effectuez 3 attaques (%d/3)" % _attack_count
	elif current_step == TutorialStep.COMBAT:
		text = "Éliminez tous les ennemis (%d/%d)" % [_kill_count, step_data.get("required_count", 3)]
	
	objective_shown.emit(text)


func is_tutorial_active() -> bool:
	"""Retourne si le tutoriel est actif."""
	return _is_active


func skip_tutorial() -> void:
	"""Passe le tutoriel."""
	_is_active = false
	tutorial_completed.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Tutoriel passé")
