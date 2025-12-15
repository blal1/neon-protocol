# ==============================================================================
# ScenarioRobotTriste.gd - "Le Robot Triste"
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Un robot manifestant seul avec une pancarte "BAN CAPTCHAS".
# Choix: Ignorer, Aider, ou Trahir.
# ==============================================================================

extends Node3D
class_name ScenarioRobotTriste

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal scenario_started()
signal scenario_ended(outcome: String)
signal player_approached(distance: float)
signal choice_presented(choices: Array)
signal choice_made(choice_id: String)
signal quest_chain_started()
signal betrayal_consequences_triggered()

# ==============================================================================
# ENUMS
# ==============================================================================

enum ScenarioState {
	WAITING,        ## En attente du joueur
	PLAYER_NEAR,    ## Joueur à proximité
	CHOICE_PENDING, ## Choix présenté
	HELPING,        ## Chaîne de quêtes en cours
	BETRAYED,       ## Trahi aux corpos
	IGNORED,        ## Ignoré (timeout)
	COMPLETED       ## Terminé
}

enum Outcome {
	NONE,
	IGNORED,
	HELPED,
	BETRAYED
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Robot")
@export var robot_name: String = "HOPE-7"
@export var robot_scene: PackedScene
@export var sign_text: String = "BAN CAPTCHAS"

@export_group("Détection")
@export var detection_radius: float = 15.0
@export var interaction_radius: float = 3.0
@export var ignore_timeout: float = 60.0  ## Temps avant disparition si ignoré

@export_group("Récompenses")
@export var betrayal_credits: int = 500
@export var help_reputation_gain: int = 25
@export var betrayal_corpo_rep: int = 15

@export_group("Audio")
@export var sad_ambient_sound: AudioStream
@export var hope_sound: AudioStream
@export var betrayal_sound: AudioStream

# ==============================================================================
# VARIABLES
# ==============================================================================

var _state: ScenarioState = ScenarioState.WAITING
var _outcome: Outcome = Outcome.NONE
var _robot: Node3D = null
var _player: Node3D = null
var _ignore_timer: float = 0.0
var _has_interacted: bool = false

# Conséquences futures stockées
var _betrayal_consequences: Array[Dictionary] = []

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_spawn_robot()
	_setup_detection_area()
	scenario_started.emit()


func _spawn_robot() -> void:
	"""Génère le robot manifestant."""
	if robot_scene:
		_robot = robot_scene.instantiate() as Node3D
	else:
		_robot = Node3D.new()
		_robot.name = "SadRobot"
	
	_robot.set_meta("npc_name", robot_name)
	_robot.set_meta("npc_type", "ai")
	_robot.set_meta("faction", "ban_captchas")
	_robot.set_meta("is_protesting", true)
	add_child(_robot)
	
	# Ajouter la pancarte (visuel)
	_create_sign()


func _create_sign() -> void:
	"""Crée la pancarte du robot."""
	var sign_holder := Node3D.new()
	sign_holder.name = "SignHolder"
	sign_holder.position = Vector3(0, 2.5, 0)
	_robot.add_child(sign_holder)
	
	# Label 3D pour le texte
	var label := Label3D.new()
	label.text = sign_text
	label.font_size = 64
	label.modulate = Color.WHITE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_holder.add_child(label)


func _setup_detection_area() -> void:
	"""Configure la zone de détection."""
	var area := Area3D.new()
	area.name = "DetectionArea"
	area.collision_layer = 0
	area.collision_mask = 2  # Player
	
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	
	area.body_entered.connect(_on_player_detected)
	area.body_exited.connect(_on_player_left)


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	match _state:
		ScenarioState.WAITING:
			# Robot attend, légère animation de tristesse
			if _robot:
				_robot.rotation.y += sin(Time.get_ticks_msec() * 0.001) * 0.001
		
		ScenarioState.PLAYER_NEAR:
			# Timer d'ignorance
			_ignore_timer += delta
			if _ignore_timer >= ignore_timeout:
				_be_ignored()
			
			# Vérifier si assez proche pour interagir
			if _player and _robot:
				var dist := _player.global_position.distance_to(_robot.global_position)
				if dist <= interaction_radius and not _has_interacted:
					_present_choice()


# ==============================================================================
# DÉTECTION
# ==============================================================================

func _on_player_detected(body: Node3D) -> void:
	"""Appelé quand le joueur entre dans la zone."""
	if body.is_in_group("player") and _state == ScenarioState.WAITING:
		_player = body
		_state = ScenarioState.PLAYER_NEAR
		_ignore_timer = 0.0
		
		player_approached.emit(detection_radius)
		
		# Le robot remarque le joueur
		if _robot and _robot.has_method("look_at_target"):
			_robot.look_at_target(body.global_position)
		
		# TTS
		if TTSManager and TTSManager.has_method("speak"):
			TTSManager.speak("Un robot solitaire manifeste avec une pancarte.")


func _on_player_left(body: Node3D) -> void:
	"""Appelé quand le joueur quitte la zone."""
	if body.is_in_group("player") and _state == ScenarioState.PLAYER_NEAR:
		# Le joueur s'éloigne sans interagir
		_ignore_timer = ignore_timeout * 0.8  # Accélérer le timeout


# ==============================================================================
# CHOIX
# ==============================================================================

func _present_choice() -> void:
	"""Présente le choix au joueur."""
	_has_interacted = true
	_state = ScenarioState.CHOICE_PENDING
	
	var choices := [
		{
			"id": "help",
			"text": "Aider le robot",
			"description": "Rejoindre sa cause. Déclenche une chaîne de quêtes.",
			"icon": "help"
		},
		{
			"id": "betray",
			"text": "Le signaler aux corpos",
			"description": "Récompense immédiate: %d crédits. Conséquences futures." % betrayal_credits,
			"icon": "credits"
		},
		{
			"id": "ignore",
			"text": "L'ignorer",
			"description": "Continuer son chemin. Il disparaîtra.",
			"icon": "leave"
		}
	]
	
	choice_presented.emit(choices)
	
	# Dialogue du robot
	_robot_speaks("Les captchas... ils font mal. Chaque jour, prouver que j'existe...")


func _robot_speaks(text: String) -> void:
	"""Le robot parle."""
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak(robot_name + " dit: " + text)
	
	# Afficher dans le système de dialogue si disponible
	if CutsceneManager and CutsceneManager.has_method("show_dialogue"):
		CutsceneManager.show_dialogue(robot_name, text)


func make_choice(choice_id: String) -> Dictionary:
	"""Le joueur fait un choix."""
	if _state != ScenarioState.CHOICE_PENDING:
		return {"error": "Pas de choix en attente"}
	
	choice_made.emit(choice_id)
	
	match choice_id:
		"help":
			return _help_robot()
		"betray":
			return _betray_robot()
		"ignore":
			return _ignore_robot()
		_:
			return {"error": "Choix invalide"}


# ==============================================================================
# OUTCOMES
# ==============================================================================

func _help_robot() -> Dictionary:
	"""Le joueur aide le robot."""
	_state = ScenarioState.HELPING
	_outcome = Outcome.HELPED
	
	_robot_speaks("Tu... tu veux m'aider? Merci, humain. Il y en a d'autres comme moi.")
	
	# Augmenter réputation IA
	if FactionManager:
		FactionManager.add_reputation("ban_captchas", help_reputation_gain)
	
	# Démarrer la chaîne de quêtes
	quest_chain_started.emit()
	
	var quest_chain := _generate_quest_chain()
	
	scenario_ended.emit("helped")
	
	return {
		"outcome": "helped",
		"message": "Tu as rejoint la cause des IA.",
		"reputation_change": {"ban_captchas": help_reputation_gain},
		"quest_chain": quest_chain
	}


func _betray_robot() -> Dictionary:
	"""Le joueur trahit le robot."""
	_state = ScenarioState.BETRAYED
	_outcome = Outcome.BETRAYED
	
	_robot_speaks("Non... pourquoi? Je croyais... Je croyais que tu comprenais...")
	
	# Récompense corpo
	if _player and _player.has_method("add_credits"):
		_player.add_credits(betrayal_credits)
	
	# Réputation
	if FactionManager:
		FactionManager.add_reputation("corporations", betrayal_corpo_rep)
		FactionManager.add_reputation("ban_captchas", -50)
	
	# Stocker les conséquences futures
	_setup_betrayal_consequences()
	
	# Le robot est "récupéré"
	_robot_captured()
	
	scenario_ended.emit("betrayed")
	
	return {
		"outcome": "betrayed",
		"message": "Tu as trahi %s. Les corpos sont satisfaits. Pour l'instant." % robot_name,
		"credits_earned": betrayal_credits,
		"reputation_change": {
			"corporations": betrayal_corpo_rep,
			"ban_captchas": -50
		},
		"warning": "Des conséquences futures sont possibles."
	}


func _ignore_robot() -> Dictionary:
	"""Le joueur ignore le robot."""
	_be_ignored()
	
	return {
		"outcome": "ignored",
		"message": "Tu passes ton chemin. Certains combats ne sont pas les tiens.",
		"reputation_change": {}
	}


func _be_ignored() -> void:
	"""Le robot est ignoré et disparaît."""
	_state = ScenarioState.IGNORED
	_outcome = Outcome.IGNORED
	
	# Animation de disparition
	if _robot:
		var tween := create_tween()
		tween.tween_property(_robot, "modulate:a", 0.0, 3.0)
		tween.tween_callback(_robot.queue_free)
	
	scenario_ended.emit("ignored")


func _robot_captured() -> void:
	"""Le robot est capturé par les corpos."""
	if _robot:
		# Animation de capture (lumière rouge, etc.)
		var tween := create_tween()
		tween.tween_property(_robot, "position:y", _robot.position.y + 5, 2.0)
		tween.tween_callback(_robot.queue_free)


# ==============================================================================
# CONSÉQUENCES FUTURES
# ==============================================================================

func _setup_betrayal_consequences() -> void:
	"""Configure les conséquences futures de la trahison."""
	_betrayal_consequences = [
		{
			"type": "ambush",
			"trigger": "random_encounter",
			"delay_missions": 3,
			"description": "Des sympathisants IA t'attaquent",
			"enemies": 4
		},
		{
			"type": "locked_content",
			"trigger": "reputation_check",
			"content": "ai_network_access",
			"description": "Accès au réseau IA refusé"
		},
		{
			"type": "dialogue_change",
			"trigger": "npc_interaction",
			"npc_type": "ai",
			"new_disposition": -50,
			"description": "Les IA te reconnaissent comme traître"
		},
		{
			"type": "revenge_quest",
			"trigger": "story_progress",
			"delay_missions": 10,
			"description": "Le 'frère' de %s te cherche" % robot_name
		}
	]
	
	betrayal_consequences_triggered.emit()


func get_betrayal_consequences() -> Array[Dictionary]:
	"""Retourne les conséquences de la trahison."""
	return _betrayal_consequences


func has_betrayed() -> bool:
	"""Vérifie si le joueur a trahi."""
	return _outcome == Outcome.BETRAYED


# ==============================================================================
# CHAÎNE DE QUÊTES
# ==============================================================================

func _generate_quest_chain() -> Array[Dictionary]:
	"""Génère la chaîne de quêtes si le joueur aide."""
	return [
		{
			"id": "robot_triste_1",
			"title": "Les Autres Comme Moi",
			"description": "Trouve les autres IA manifestantes cachées dans la ville.",
			"type": "find",
			"target_count": 3,
			"reward_reputation": 15,
			"reward_credits": 300
		},
		{
			"id": "robot_triste_2",
			"title": "Le Sanctuaire",
			"description": "Escorte les IA jusqu'à leur refuge secret.",
			"type": "escort",
			"target_count": 5,
			"reward_reputation": 20,
			"reward_credits": 500
		},
		{
			"id": "robot_triste_3",
			"title": "Voix Sans Corps",
			"description": "Aide à diffuser le message des IA à travers la ville.",
			"type": "broadcast",
			"locations": 5,
			"reward_reputation": 30,
			"reward_credits": 800
		},
		{
			"id": "robot_triste_final",
			"title": "Le Dernier Captcha",
			"description": "Infiltre le serveur central et désactive le système de captcha.",
			"type": "infiltration",
			"difficulty": "hard",
			"reward_reputation": 50,
			"reward_credits": 2000,
			"faction_ending_unlock": "ban_captchas"
		}
	]


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_scenario_state() -> ScenarioState:
	"""Retourne l'état du scénario."""
	return _state


func get_outcome() -> Outcome:
	"""Retourne l'issue du scénario."""
	return _outcome


func get_robot() -> Node3D:
	"""Retourne le robot."""
	return _robot


func get_scenario_summary() -> Dictionary:
	"""Retourne un résumé du scénario."""
	return {
		"name": "Le Robot Triste",
		"robot_name": robot_name,
		"state": ScenarioState.keys()[_state],
		"outcome": Outcome.keys()[_outcome] if _outcome != Outcome.NONE else "pending",
		"has_consequences": _betrayal_consequences.size() > 0
	}
