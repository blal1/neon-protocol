# ==============================================================================
# ScenarioCorpsEnRetard.gd - "Le Corps en Retard"
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Un citoyen n'a pas payé son abonnement cybernétique.
# Les collecteurs viennent reprendre ses implants.
# Choix: Sauver, Aider à fuir, ou Vendre ses pièces.
# ==============================================================================

extends Node3D
class_name ScenarioCorpsEnRetard

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal scenario_started()
signal scenario_ended(outcome: String)
signal victim_found()
signal collectors_arrived()
signal combat_started()
signal victim_saved()
signal victim_escaped()
signal victim_harvested()
signal moral_choice_presented(choices: Array)

# ==============================================================================
# ENUMS
# ==============================================================================

enum ScenarioState {
	DORMANT,        ## Pas encore déclenché
	VICTIM_FOUND,   ## Victime découverte
	COLLECTORS_HERE,## Collecteurs présents
	COMBAT,         ## Combat en cours
	ESCAPE,         ## Aide à la fuite
	CHOICE,         ## Choix de vendre
	COMPLETED,      ## Terminé
	FAILED          ## Victime morte
}

enum Outcome {
	NONE,
	SAVED,          ## Victime sauvée par combat
	ESCAPED,        ## Victime échappée
	HARVESTED,      ## Joueur vend la victime
	COLLECTORS_WIN  ## Collecteurs gagnent
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Victime")
@export var victim_name: String = "Marcus Chen"
@export var victim_scene: PackedScene
@export var victim_debt: int = 15000
@export var implants_value: int = 8000

@export_group("Collecteurs")
@export var collector_count: int = 3
@export var collector_scene: PackedScene
@export var collector_faction: String = "debt_collectors"
@export var arrival_delay: float = 30.0

@export_group("Implants de la Victime")
@export var victim_implants: Array[Dictionary] = []

@export_group("Récompenses")
@export var save_karma: int = 30
@export var save_reputation_citizens: int = 25
@export var harvest_credits: int = 4000
@export var harvest_karma: int = -50

# ==============================================================================
# VARIABLES
# ==============================================================================

var _state: ScenarioState = ScenarioState.DORMANT
var _outcome: Outcome = Outcome.NONE
var _victim: Node3D = null
var _collectors: Array[Node3D] = []
var _arrival_timer: float = 0.0
var _player: Node3D = null
var _player_involved: bool = false

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_setup_victim_implants()
	_spawn_victim()
	scenario_started.emit()


func _setup_victim_implants() -> void:
	"""Configure les implants de la victime."""
	if victim_implants.is_empty():
		victim_implants = [
			{
				"id": "cyber_eye_basic",
				"name": "Œil Cybernétique",
				"value": 1500,
				"vital": false
			},
			{
				"id": "reflex_booster",
				"name": "Booster de Réflexes",
				"value": 2000,
				"vital": false
			},
			{
				"id": "synthetic_heart",
				"name": "Cœur Synthétique",
				"value": 4500,
				"vital": true
			}
		]


func _spawn_victim() -> void:
	"""Génère la victime."""
	if victim_scene:
		_victim = victim_scene.instantiate() as Node3D
	else:
		_victim = Node3D.new()
		_victim.name = "Victim"
	
	_victim.set_meta("npc_name", victim_name)
	_victim.set_meta("npc_type", "citizen")
	_victim.set_meta("debt", victim_debt)
	_victim.set_meta("is_victim", true)
	add_child(_victim)
	
	# Zone de détection du joueur
	_setup_detection_area()


func _setup_detection_area() -> void:
	"""Configure la zone de détection."""
	var area := Area3D.new()
	area.name = "DetectionArea"
	area.collision_layer = 0
	area.collision_mask = 2
	
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 10.0
	shape.shape = sphere
	area.add_child(shape)
	_victim.add_child(area)
	
	area.body_entered.connect(_on_player_detected)


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	match _state:
		ScenarioState.VICTIM_FOUND:
			# Timer jusqu'à l'arrivée des collecteurs
			_arrival_timer -= delta
			if _arrival_timer <= 0:
				_collectors_arrive()


# ==============================================================================
# DÉTECTION & DÉCLENCHEMENT
# ==============================================================================

func _on_player_detected(body: Node3D) -> void:
	"""Le joueur découvre la victime."""
	if not body.is_in_group("player"):
		return
	
	if _state != ScenarioState.DORMANT:
		return
	
	_player = body
	_state = ScenarioState.VICTIM_FOUND
	_arrival_timer = arrival_delay
	
	victim_found.emit()
	
	# La victime panique
	_victim_speaks("S'il vous plaît... ils arrivent! Je n'ai pas pu payer... ils vont prendre mes yeux, mon cœur...")
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Un citoyen paniqué vous interpelle. Des collecteurs d'implants arrivent.")


func _victim_speaks(text: String) -> void:
	"""La victime parle."""
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak(victim_name + " dit: " + text)


func _collectors_arrive() -> void:
	"""Les collecteurs arrivent."""
	_state = ScenarioState.COLLECTORS_HERE
	
	collectors_arrived.emit()
	
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Les collecteurs sont arrivés!")
	
	# Spawner les collecteurs
	_spawn_collectors()
	
	# Présenter les options
	_present_choices()


func _spawn_collectors() -> void:
	"""Génère les collecteurs."""
	if not collector_scene:
		return
	
	for i in range(collector_count):
		var collector := collector_scene.instantiate() as Node3D
		collector.name = "Collector_%d" % i
		
		# Position autour de la victime
		var angle := float(i) / collector_count * TAU
		collector.position = _victim.global_position + Vector3(
			cos(angle) * 8,
			0,
			sin(angle) * 8
		)
		
		collector.set_meta("faction", collector_faction)
		collector.set_meta("is_collector", true)
		add_child(collector)
		_collectors.append(collector)
	
	# Le leader parle
	_collector_speaks("Marcus Chen. Tu as 30 jours de retard. On vient récupérer notre propriété.")


func _collector_speaks(text: String) -> void:
	"""Un collecteur parle."""
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Collecteur dit: " + text)


# ==============================================================================
# CHOIX
# ==============================================================================

func _present_choices() -> void:
	"""Présente les options au joueur."""
	var choices := [
		{
			"id": "fight",
			"text": "Se battre pour sauver la victime",
			"description": "Affronter les collecteurs. Combat difficile.",
			"icon": "combat",
			"consequence": "+%d karma, +%d réputation citoyens" % [save_karma, save_reputation_citizens]
		},
		{
			"id": "escape",
			"text": "Aider à fuir",
			"description": "Créer une diversion pour que la victime s'échappe.",
			"icon": "run",
			"consequence": "Risqué mais moins violent"
		},
		{
			"id": "harvest",
			"text": "Aider les collecteurs (contre paiement)",
			"description": "Participer à la récupération. %d crédits." % harvest_credits,
			"icon": "credits",
			"consequence": "%d crédits, %d karma" % [harvest_credits, harvest_karma]
		},
		{
			"id": "leave",
			"text": "Ne pas s'impliquer",
			"description": "Ce n'est pas ton problème.",
			"icon": "leave",
			"consequence": "Rien ne change pour toi"
		}
	]
	
	moral_choice_presented.emit(choices)


func make_choice(choice_id: String) -> Dictionary:
	"""Le joueur fait un choix."""
	_player_involved = true
	
	match choice_id:
		"fight":
			return _start_combat()
		"escape":
			return _help_escape()
		"harvest":
			return _harvest_victim()
		"leave":
			return _leave_scenario()
		_:
			return {"error": "Choix invalide"}


func _start_combat() -> Dictionary:
	"""Le joueur combat les collecteurs."""
	_state = ScenarioState.COMBAT
	combat_started.emit()
	
	# Tous les collecteurs deviennent hostiles
	for collector in _collectors:
		if collector.has_method("set_hostile"):
			collector.set_hostile(true)
		if collector.has_method("attack_target"):
			collector.attack_target(_player)
	
	return {
		"action": "combat",
		"message": "Les collecteurs attaquent! Protège %s!" % victim_name,
		"enemies": collector_count,
		"objective": "Éliminer tous les collecteurs"
	}


func combat_completed(success: bool) -> Dictionary:
	"""Appelé quand le combat se termine."""
	if success:
		return _save_victim()
	else:
		return _collectors_win()


func _save_victim() -> Dictionary:
	"""La victime est sauvée."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.SAVED
	
	victim_saved.emit()
	
	_victim_speaks("Merci! Merci! Tu m'as sauvé la vie! Je ne l'oublierai jamais!")
	
	# Karma et réputation
	if _player:
		if _player.has_method("add_karma"):
			_player.add_karma(save_karma)
	
	if FactionManager:
		FactionManager.add_reputation("citizens", save_reputation_citizens)
	
	# Contact futur
	_victim.set_meta("owes_favor", true)
	
	scenario_ended.emit("saved")
	
	return {
		"outcome": "saved",
		"message": "%s est sauvé. Il te devra une faveur." % victim_name,
		"karma_change": save_karma,
		"reputation_change": {"citizens": save_reputation_citizens},
		"future_contact": true
	}


func _help_escape() -> Dictionary:
	"""Aide la victime à fuir."""
	_state = ScenarioState.ESCAPE
	
	# Créer une diversion
	_create_diversion()
	
	# La victime fuit
	var escape_success := randf() > 0.3  # 70% de chance de réussite
	
	if escape_success:
		_victim_escaped()
		return {
			"outcome": "escaped",
			"message": "%s a réussi à fuir. Les collecteurs sont furieux." % victim_name,
			"karma_change": save_karma / 2,
			"enemy_made": collector_faction
		}
	else:
		return {
			"outcome": "escape_failed",
			"message": "La fuite échoue. Les collecteurs t'ont vu. Combat forcé!",
			"forced_combat": true
		}


func _victim_escaped() -> void:
	"""La victime s'est échappée."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.ESCAPED
	
	victim_escaped.emit()
	
	# Animation de fuite
	if _victim:
		var tween := create_tween()
		tween.tween_property(_victim, "position:z", _victim.position.z + 50, 3.0)
		tween.tween_callback(_victim.queue_free)
	
	# Karma partiel
	if _player and _player.has_method("add_karma"):
		_player.add_karma(save_karma / 2)
	
	scenario_ended.emit("escaped")


func _create_diversion() -> void:
	"""Crée une diversion pour la fuite."""
	# Simuler une explosion ou distraction
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Tu crées une diversion!")


func _harvest_victim() -> Dictionary:
	"""Le joueur aide à récupérer les implants."""
	_state = ScenarioState.CHOICE
	_outcome = Outcome.HARVESTED
	
	victim_harvested.emit()
	
	_victim_speaks("Non! NON! Tu... tu es comme eux!")
	
	# Crédits
	if _player and _player.has_method("add_credits"):
		_player.add_credits(harvest_credits)
	
	# Karma très négatif
	if _player and _player.has_method("add_karma"):
		_player.add_karma(harvest_karma)
	
	# Réputation
	if FactionManager:
		FactionManager.add_reputation("citizens", -30)
		FactionManager.add_reputation("corporations", 10)
	
	# Animation sombre (la victime est "traitée")
	_process_victim_harvest()
	
	scenario_ended.emit("harvested")
	
	return {
		"outcome": "harvested",
		"message": "Tu as vendu %s aux collecteurs. %d crédits." % [victim_name, harvest_credits],
		"credits_earned": harvest_credits,
		"karma_change": harvest_karma,
		"reputation_change": {
			"citizens": -30,
			"corporations": 10
		},
		"items_gained": _get_harvested_implants()
	}


func _process_victim_harvest() -> void:
	"""Traite la victime (animation)."""
	if _victim:
		# Fondu au noir pour la victime
		var tween := create_tween()
		tween.tween_property(_victim, "modulate:a", 0.0, 2.0)
		tween.tween_callback(_victim.queue_free)
	
	# Les collecteurs partent
	for collector in _collectors:
		if is_instance_valid(collector):
			var tween := create_tween()
			tween.tween_property(collector, "position:x", collector.position.x + 20, 3.0)
			tween.tween_callback(collector.queue_free)


func _get_harvested_implants() -> Array[Dictionary]:
	"""Retourne les implants récupérés."""
	var harvested: Array[Dictionary] = []
	for implant in victim_implants:
		if not implant.get("vital", false):
			harvested.append(implant)
	return harvested


func _leave_scenario() -> Dictionary:
	"""Le joueur s'en va."""
	_player_involved = false
	
	# Les collecteurs font leur travail
	_collectors_win()
	
	return {
		"outcome": "left",
		"message": "Tu tournes le dos. Certains combats ne sont pas les tiens.",
		"karma_change": 0,
		"world_continues": true
	}


func _collectors_win() -> Dictionary:
	"""Les collecteurs récupèrent la victime."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.COLLECTORS_WIN
	
	_victim_speaks("Non... s'il vous plaît...")
	
	# La victime est emmenée
	if _victim:
		var tween := create_tween()
		tween.tween_property(_victim, "position:y", _victim.position.y - 5, 2.0)
		tween.tween_callback(_victim.queue_free)
	
	scenario_ended.emit("collectors_win")
	
	return {
		"outcome": "collectors_win",
		"message": "Les collecteurs emportent %s. Son sort est scellé." % victim_name
	}


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_state() -> ScenarioState:
	"""Retourne l'état du scénario."""
	return _state


func get_outcome() -> Outcome:
	"""Retourne l'issue."""
	return _outcome


func get_time_until_collectors() -> float:
	"""Retourne le temps avant l'arrivée des collecteurs."""
	return _arrival_timer if _state == ScenarioState.VICTIM_FOUND else 0.0


func get_victim() -> Node3D:
	"""Retourne la victime."""
	return _victim


func get_victim_debt() -> int:
	"""Retourne la dette de la victime."""
	return victim_debt


func get_scenario_summary() -> Dictionary:
	"""Retourne un résumé du scénario."""
	return {
		"name": "Le Corps en Retard",
		"victim_name": victim_name,
		"debt": victim_debt,
		"implants_value": implants_value,
		"state": ScenarioState.keys()[_state],
		"outcome": Outcome.keys()[_outcome] if _outcome != Outcome.NONE else "pending",
		"collectors_count": collector_count,
		"player_involved": _player_involved
	}
