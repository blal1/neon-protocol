# ==============================================================================
# ScenarioFeteAuxBallons.gd - "La Fête aux Ballons"
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Clin d'œil Chrono Trigger, version cyberpunk.
# Fête illégale, ballons lumineux, musique pirate.
# La police arrive. Choix multiples.
# ==============================================================================

extends Node3D
class_name ScenarioFeteAuxBallons

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal scenario_started()
signal scenario_ended(outcome: String)
signal party_discovered()
signal police_arriving(time_remaining: float)
signal police_arrived()
signal choice_presented(choices: Array)
signal party_protected()
signal party_betrayed()
signal chaos_exploited()
signal party_ended_peacefully()

# ==============================================================================
# ENUMS
# ==============================================================================

enum ScenarioState {
	DORMANT,          ## Pas encore découvert
	PARTY_ACTIVE,     ## Fête en cours
	POLICE_WARNING,   ## Police arrive bientôt
	POLICE_RAID,      ## Raid en cours
	CHOICE_PENDING,   ## Choix présenté
	COMBAT,           ## Combat contre police
	ESCAPE,           ## Fuite organisée
	COMPLETED         ## Terminé
}

enum Outcome {
	NONE,
	PROTECTED,      ## Fête protégée
	BETRAYED,       ## Organisateurs trahis
	CHAOS_USED,     ## Chaos exploité
	PEACEFUL_END    ## Fête terminée à temps
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Fête")
@export var party_location_name: String = "Entrepôt Abandonné Secteur 7"
@export var attendee_count: int = 50
@export var balloon_count: int = 30

@export_group("Police")
@export var police_warning_time: float = 120.0  ## 2 minutes d'avertissement
@export var police_squad_size: int = 8
@export var police_scene: PackedScene

@export_group("Récompenses")
@export var protect_reputation: int = 30
@export var betray_credits: int = 2000
@export var chaos_contract_bonus: int = 500

# ==============================================================================
# VARIABLES
# ==============================================================================

var _state: ScenarioState = ScenarioState.DORMANT
var _outcome: Outcome = Outcome.NONE
var _warning_timer: float = 0.0
var _party_npcs: Array[Node3D] = []
var _police_npcs: Array[Node3D] = []
var _player: Node3D = null
var _organizer: Node3D = null

# Contrat secondaire disponible pendant le chaos
var _chaos_contract: Dictionary = {}

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_setup_chaos_contract()
	_spawn_party()
	scenario_started.emit()


func _setup_chaos_contract() -> void:
	"""Configure un contrat exploitable pendant le chaos."""
	_chaos_contract = {
		"id": "chaos_heist",
		"name": "Vol sous Couvert",
		"description": "Pendant la confusion, vole des données dans le bâtiment adjacent.",
		"target": "Serveur de données NovaTech",
		"reward": 1500,
		"time_window": 180  # 3 minutes pendant le raid
	}


func _spawn_party() -> void:
	"""Génère la fête."""
	# Créer l'organisateur
	_organizer = Node3D.new()
	_organizer.name = "Organizer_Maya"
	_organizer.set_meta("npc_name", "Maya Vox")
	_organizer.set_meta("npc_type", "party_organizer")
	_organizer.set_meta("faction", "citizens")
	add_child(_organizer)
	
	# Créer les ballons lumineux (visuels)
	_create_balloons()
	
	# Créer les fêtards (simplification)
	for i in range(attendee_count):
		var npc := Node3D.new()
		npc.name = "Partygoer_%d" % i
		npc.set_meta("npc_type", "civilian")
		npc.set_meta("is_partying", true)
		
		# Position aléatoire
		npc.position = Vector3(
			randf_range(-15, 15),
			0,
			randf_range(-15, 15)
		)
		add_child(npc)
		_party_npcs.append(npc)
	
	_state = ScenarioState.PARTY_ACTIVE


func _create_balloons() -> void:
	"""Crée les ballons lumineux."""
	for i in range(balloon_count):
		var balloon := Node3D.new()
		balloon.name = "Balloon_%d" % i
		
		# Position aléatoire en hauteur
		balloon.position = Vector3(
			randf_range(-20, 20),
			randf_range(3, 8),
			randf_range(-20, 20)
		)
		
		# Ajouter une lumière colorée
		var light := OmniLight3D.new()
		light.light_color = Color(
			randf_range(0.5, 1.0),
			randf_range(0.2, 0.8),
			randf_range(0.5, 1.0)
		)
		light.light_energy = 0.5
		light.omni_range = 5.0
		balloon.add_child(light)
		
		add_child(balloon)


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	match _state:
		ScenarioState.PARTY_ACTIVE:
			# Animation des fêtards
			_animate_party(delta)
		
		ScenarioState.POLICE_WARNING:
			_warning_timer -= delta
			if _warning_timer <= 0:
				_police_raid()


# ==============================================================================
# DÉCOUVERTE & INTERACTION
# ==============================================================================

func player_discovers_party(player: Node3D) -> Dictionary:
	"""Le joueur découvre la fête."""
	if _state != ScenarioState.PARTY_ACTIVE:
		return {"error": "Fête non active"}
	
	_player = player
	party_discovered.emit()
	
	# L'organisateur approche
	_organizer_speaks("Eh! Bienvenue à la fête interdite! Musique pirate, ballons synthétiques, et pas un seul corpo en vue!")
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Tu découvres une fête clandestine. Ballons lumineux, musique underground.")
	
	return {
		"location": party_location_name,
		"attendees": attendee_count,
		"organizer": "Maya Vox",
		"vibe": "joyeux mais illégal"
	}


func _organizer_speaks(text: String) -> void:
	"""L'organisatrice parle."""
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Maya dit: " + text)


func _animate_party(_delta: float) -> void:
	"""Animation simple des fêtards."""
	for npc in _party_npcs:
		if is_instance_valid(npc):
			# Légère oscillation
			npc.position.y = sin(Time.get_ticks_msec() * 0.003 + npc.get_instance_id()) * 0.1


# ==============================================================================
# ARRIVÉE DE LA POLICE
# ==============================================================================

func trigger_police_warning() -> void:
	"""Déclenche l'avertissement police."""
	if _state != ScenarioState.PARTY_ACTIVE:
		return
	
	_state = ScenarioState.POLICE_WARNING
	_warning_timer = police_warning_time
	
	police_arriving.emit(_warning_timer)
	
	_organizer_speaks("Merde! Quelqu'un a dénoncé la fête! La police arrive dans 2 minutes!")
	
	# Présenter les choix
	_present_choices()


func _present_choices() -> void:
	"""Présente les choix au joueur."""
	_state = ScenarioState.CHOICE_PENDING
	
	var choices := [
		{
			"id": "protect",
			"text": "Protéger la fête",
			"description": "Repousse la police. Combat difficile.",
			"icon": "shield",
			"consequence": "+%d réputation citoyens, ennemis de la police" % protect_reputation
		},
		{
			"id": "betray",
			"text": "Dénoncer les organisateurs",
			"description": "Indique l'organisatrice à la police.",
			"icon": "credits",
			"consequence": "+%d crédits, Maya sera arrêtée" % betray_credits
		},
		{
			"id": "chaos",
			"text": "Exploiter le chaos",
			"description": "Utilise la confusion pour un autre contrat.",
			"icon": "contract",
			"consequence": "Contrat bonus: %s" % _chaos_contract.name
		},
		{
			"id": "help_escape",
			"text": "Organiser la fuite",
			"description": "Aide tout le monde à s'échapper avant le raid.",
			"icon": "run",
			"consequence": "Fête terminée, personne arrêté"
		}
	]
	
	choice_presented.emit(choices)


func make_choice(choice_id: String) -> Dictionary:
	"""Le joueur fait son choix."""
	match choice_id:
		"protect":
			return _protect_party()
		"betray":
			return _betray_organizer()
		"chaos":
			return _exploit_chaos()
		"help_escape":
			return _organize_escape()
		_:
			return {"error": "Choix invalide"}


# ==============================================================================
# OUTCOMES
# ==============================================================================

func _protect_party() -> Dictionary:
	"""Le joueur protège la fête."""
	_state = ScenarioState.COMBAT
	_outcome = Outcome.PROTECTED
	
	# Spawn police
	_spawn_police()
	
	party_protected.emit()
	
	return {
		"action": "combat",
		"message": "Tu te prépares à défendre la fête!",
		"enemies": police_squad_size,
		"allies": 5,  # Quelques fêtards aident
		"objective": "Repousser la police"
	}


func complete_protection_combat(victory: bool) -> Dictionary:
	"""Combat de protection terminé."""
	if victory:
		_state = ScenarioState.COMPLETED
		
		# Réputation
		if FactionManager:
			FactionManager.add_reputation("citizens", protect_reputation)
			FactionManager.add_reputation("police", -40)
		
		# Réputation locale
		if DistrictEcosystem:
			DistrictEcosystem.modify_local_reputation(
				DistrictEcosystem.get_current_district(), 
				25
			)
		
		_organizer_speaks("T'es une légende! Cette nuit restera dans l'histoire du quartier!")
		
		scenario_ended.emit("protected")
		
		return {
			"outcome": "protected",
			"message": "La fête continue! Tu es un héros local.",
			"reputation_change": {"citizens": protect_reputation, "police": -40}
		}
	else:
		return _police_wins()


func _betray_organizer() -> Dictionary:
	"""Trahison de l'organisatrice."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.BETRAYED
	
	party_betrayed.emit()
	
	# Crédits
	if _player and _player.has_method("add_credits"):
		_player.add_credits(betray_credits)
	
	# Réputation
	if FactionManager:
		FactionManager.add_reputation("police", 15)
		FactionManager.add_reputation("citizens", -35)
	
	# Maya est arrêtée
	_organizer_speaks("Quoi?! Tu nous as... Comment tu peux faire ça?!")
	
	# Marquer pour conséquences futures
	_mark_betrayal_consequences()
	
	scenario_ended.emit("betrayed")
	
	return {
		"outcome": "betrayed",
		"message": "Tu pointes Maya. La police l'arrête. %d crédits." % betray_credits,
		"credits_earned": betray_credits,
		"reputation_change": {"police": 15, "citizens": -35},
		"future_consequences": true
	}


func _exploit_chaos() -> Dictionary:
	"""Exploiter le chaos pour un autre contrat."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.CHAOS_USED
	
	chaos_exploited.emit()
	
	# La police arrive de toute façon
	_spawn_police()
	
	return {
		"outcome": "chaos_exploited",
		"message": "Pendant que tout le monde panique, tu as %d secondes pour le contrat." % _chaos_contract.time_window,
		"contract": _chaos_contract,
		"bonus": chaos_contract_bonus
	}


func complete_chaos_contract(success: bool) -> Dictionary:
	"""Contrat chaos terminé."""
	if success:
		var total_reward: int = _chaos_contract.reward + chaos_contract_bonus
		
		if _player and _player.has_method("add_credits"):
			_player.add_credits(total_reward)
		
		scenario_ended.emit("chaos_exploited")
		
		return {
			"outcome": "chaos_contract_complete",
			"message": "Dans le chaos, personne n'a remarqué ton vol. %d crédits." % total_reward,
			"credits_earned": total_reward
		}
	else:
		return {
			"outcome": "chaos_contract_failed",
			"message": "Le chaos n'a pas suffi. Tu t'es fait repérer."
		}


func _organize_escape() -> Dictionary:
	"""Organise la fuite de tout le monde."""
	_state = ScenarioState.ESCAPE
	_outcome = Outcome.PEACEFUL_END
	
	# Tous les fêtards fuient
	for npc in _party_npcs:
		if is_instance_valid(npc):
			var tween := create_tween()
			tween.tween_property(npc, "position:z", npc.position.z + 50, randf_range(2, 4))
	
	# Maya aussi
	_organizer_speaks("Bonne idée! Tout le monde, on se disperse! On remettra ça!")
	
	# Petit bonus réputation
	if FactionManager:
		FactionManager.add_reputation("citizens", 10)
	
	party_ended_peacefully.emit()
	
	scenario_ended.emit("peaceful")
	
	return {
		"outcome": "peaceful_end",
		"message": "La fête se disperse dans le calme. Personne n'est arrêté.",
		"reputation_change": {"citizens": 10}
	}


func _police_raid() -> void:
	"""La police attaque."""
	_state = ScenarioState.POLICE_RAID
	police_arrived.emit()
	
	_spawn_police()


func _spawn_police() -> void:
	"""Génère les policiers."""
	for i in range(police_squad_size):
		var cop: Node3D
		if police_scene:
			cop = police_scene.instantiate() as Node3D
		else:
			cop = Node3D.new()
		
		cop.name = "Officer_%d" % i
		cop.set_meta("faction", "police")
		cop.set_meta("is_hostile", true)
		
		# Position à l'entrée
		cop.position = Vector3(
			randf_range(-5, 5),
			0,
			30 + i * 2
		)
		
		add_child(cop)
		_police_npcs.append(cop)


func _police_wins() -> Dictionary:
	"""La police gagne."""
	_state = ScenarioState.COMPLETED
	
	# Maya et plusieurs fêtards arrêtés
	scenario_ended.emit("police_win")
	
	return {
		"outcome": "police_win",
		"message": "La police prend le contrôle. Maya et 12 personnes sont arrêtées.",
		"arrested": 13
	}


# ==============================================================================
# CONSÉQUENCES FUTURES
# ==============================================================================

func _mark_betrayal_consequences() -> void:
	"""Marque les conséquences de la trahison."""
	# Ces conséquences seront utilisées par d'autres systèmes
	var consequences := {
		"maya_arrested": true,
		"underground_trust_lost": true,
		"future_events": [
			{
				"type": "revenge_attempt",
				"trigger": "random_district_visit",
				"delay_missions": 5,
				"description": "Des amis de Maya te cherchent"
			},
			{
				"type": "locked_content",
				"content": "underground_parties",
				"description": "Tu n'es plus invité aux fêtes clandestines"
			}
		]
	}
	
	set_meta("betrayal_consequences", consequences)


func has_betrayed_party() -> bool:
	"""Vérifie si le joueur a trahi."""
	return _outcome == Outcome.BETRAYED


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_state() -> ScenarioState:
	"""Retourne l'état du scénario."""
	return _state


func get_outcome() -> Outcome:
	"""Retourne l'issue."""
	return _outcome


func get_warning_time_remaining() -> float:
	"""Retourne le temps avant l'arrivée de la police."""
	return _warning_timer if _state == ScenarioState.POLICE_WARNING else 0.0


func get_scenario_summary() -> Dictionary:
	"""Retourne un résumé du scénario."""
	return {
		"name": "La Fête aux Ballons",
		"location": party_location_name,
		"attendees": attendee_count,
		"state": ScenarioState.keys()[_state],
		"outcome": Outcome.keys()[_outcome] if _outcome != Outcome.NONE else "pending"
	}
