# ==============================================================================
# GameManager.gd - Orchestrateur de la boucle de jeu
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère le cycle de vie d'une session de jeu:
# 1. Initialisation des systèmes
# 2. Génération du monde (CityManager)
# 3. Placement du joueur
# 4. Cycle de missions
# ==============================================================================

extends Node
class_name GameManager

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@export_group("Composants")
@export var city_manager: CityManager
@export var hud: GameHUD
@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var player: Player = null
var is_game_started: bool = false

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	"""Démarre la séquence d'initialisation du jeu."""
	print("[GameManager] Démarrage de la session...")
	
	# Réactiver l'accessibilité gameplay
	_set_gameplay_accessibility(true)
	
	if not city_manager:
		push_error("[GameManager] CityManager manquant!")
		return

	# 1. Connecter les signaux de génération immédiatement (avant tout await)
	# pour ne pas manquer city_generation_completed émis en différé par CityManager.
	city_manager.city_generation_completed.connect(_on_city_generated)
	
	# Connecter les signaux de mission
	if MissionManager:
		MissionManager.mission_completed.connect(_on_mission_completed)


func _set_gameplay_accessibility(active: bool) -> void:
	"""Active ou désactive les systèmes d'accessibilité liés au gameplay."""
	var kam = get_node_or_null("/root/KeyboardAccessibilityManager")
	if kam:
		kam.enabled = active
		
	var bam = get_node_or_null("/root/BlindAccessibilityManager")
	if bam:
		if active:
			bam.activate()
		else:
			bam.deactivate()


func _on_city_generated(_building_count: int) -> void:
	"""Appelé quand le monde est prêt."""
	print("[GameManager] Monde généré. Initialisation du joueur...")
	
	# 3. Spawner le joueur
	_spawn_player()
	
	# 4. Initialiser le HUD
	_setup_hud()
	
	# 5. Démarrer la première mission
	_start_initial_mission()
	
	is_game_started = true
	print("[GameManager] Jeu prêt !")


func _spawn_player() -> void:
	"""Instancie le joueur à la position de spawn de la ville."""
	if not player_scene:
		push_error("[GameManager] PlayerScene non définie")
		return
		
	player = player_scene.instantiate() as Player
	add_child(player)
	
	# Position de spawn depuis CityManager
	var spawn_pos := city_manager.get_player_spawn_position()
	player.global_position = spawn_pos + Vector3(0, 1.0, 0)
	
	# Enregistrer le joueur dans le WorldLayerManager
	if WorldLayerManager:
		WorldLayerManager.player = player
		
	# Connecter les signaux d'interaction
	player.interaction_triggered.connect(_on_player_interacted)
		
	# Notification TTS
	if TTSManager:
		TTSManager.speak("Bienvenue dans Neon Protocol. Le monde a été généré. Bonne chance, Runner.")


func _setup_hud() -> void:
	"""Configure le HUD avec les données du joueur."""
	if not hud or not player:
		return
		
	# Connecter les signaux de santé
	if player.health_component:
		player.health_component.health_changed.connect(hud.update_health)
		hud.update_health(player.health_component.current_health, player.health_component.max_health)
		
	# Credits initiaux
	hud.update_credits(MissionManager.total_credits_earned if MissionManager else 0)


func _start_initial_mission() -> void:
	"""Démarre automatiquement la première mission disponible."""
	if not MissionManager:
		return
		
	var mission = MissionManager.get_next_mission()
	if mission:
		MissionManager.start_mission(mission.id)
		_spawn_mission_objectives(mission)
		
		# Feedback Dialogue
		if DialogueSystem:
			DialogueSystem.show_mission_dialogue({
				"title": mission.title,
				"description": mission.description,
				"story_context": mission.story_context
			})


# ==============================================================================
# BOUCLE DE JEU (MISE À JOUR)
# ==============================================================================

func _process(_delta: float) -> void:
	if not is_game_started or not player:
		return
		
	# Vérifier les objectifs de type "GoTo"
	_check_mission_objectives()


func _check_mission_objectives() -> void:
	"""Vérifie périodiquement si les objectifs de mission sont remplis."""
	if not MissionManager or not MissionManager.active_mission:
		return
		
	var active = MissionManager.active_mission
	
	if active.objective_type == "GoTo":
		# Utiliser la méthode du MissionManager
		MissionManager.check_goto_objective(player.global_position)
		
	# Les autres types d'objectifs (Kill, Collect) sont gérés par signaux
	# émis par les ennemis ou les pickups.


# ==============================================================================
# GESTION DES ÉVÉNEMENTS
# ==============================================================================

func _on_enemy_killed(_enemy) -> void:
	"""Appelé quand un ennemi meurt."""
	if MissionManager and MissionManager.active_mission:
		if MissionManager.active_mission.objective_type == "Kill":
			MissionManager.update_progress(1)


func _on_item_collected(_item) -> void:
	"""Appelé quand un item de quête est ramassé."""
	if MissionManager and MissionManager.active_mission:
		if MissionManager.active_mission.objective_type == "Collect":
			MissionManager.update_progress(1)


func _on_player_interacted(_target: Node3D) -> void:
	"""Appelé quand le joueur interagit avec un objet."""
	if MissionManager and MissionManager.active_mission:
		if MissionManager.active_mission.objective_type == "Interact":
			MissionManager.update_progress(1)


func _on_mission_completed(_mission) -> void:
	"""Appelé quand une mission est terminée. Prépare la suivante."""
	# Attendre un peu que le joueur voit le message de succès
	await get_tree().create_timer(5.0).timeout
	
	# Chercher la prochaine mission
	var next_mission = MissionManager.get_next_mission()
	if next_mission:
		MissionManager.start_mission(next_mission.id)
		_spawn_mission_objectives(next_mission)
		
		# Feedback Dialogue
		if DialogueSystem:
			DialogueSystem.show_mission_dialogue({
				"title": next_mission.title,
				"description": next_mission.description,
				"story_context": next_mission.story_context
			})
	else:
		# Fin de la campagne
		if TTSManager:
			TTSManager.speak("Toutes les missions sont terminées. Vous avez libéré la ville.")
		if hud:
			hud.show_notification("CAMPAGNE TERMINÉE !")


func _spawn_mission_objectives(mission) -> void:
	"""Spawn les objets nécessaires pour la mission."""
	match mission.objective_type:
		"Collect":
			_spawn_collectables(mission)
		"Interact":
			_spawn_interactables(mission)
		"Kill":
			_spawn_targets(mission)


func _spawn_collectables(mission) -> void:
	var pickup_scene := preload("res://scenes/gameplay/Pickup.tscn") if ResourceLoader.exists("res://scenes/gameplay/Pickup.tscn") else null
	if not pickup_scene: return
	
	for i in range(mission.target_count):
		var pickup = pickup_scene.instantiate()
		pickup.pickup_type = 6 # DATA_CHIP
		# Positionner autour des coordonnées cibles
		var offset := Vector3(randf_range(-10, 10), 0.5, randf_range(-10, 10))
		pickup.global_position = mission.target_coordinates + offset
		add_child(pickup)


func _spawn_interactables(mission) -> void:
	var terminal_scene := preload("res://scenes/world/MissionTerminal.tscn")
	for i in range(mission.target_count):
		var terminal = terminal_scene.instantiate()
		var offset := Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		terminal.global_position = mission.target_coordinates + offset
		add_child(terminal)


func _spawn_targets(mission) -> void:
	var enemy_scene := preload("res://scenes/enemies/SecurityRobot.tscn")
	for i in range(mission.target_count):
		var enemy = enemy_scene.instantiate()
		var offset := Vector3(randf_range(-15, 15), 0.5, randf_range(-15, 15))
		enemy.global_position = mission.target_coordinates + offset
		if enemy.has_signal("died"):
			enemy.died.connect(func(): _on_enemy_killed(enemy))
		add_child(enemy)
