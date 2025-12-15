# ==============================================================================
# FactionManager.gd - Gestionnaire des Factions NEON DELTA
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère toutes les factions du jeu: relations, quêtes, réputation, fins.
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal faction_reputation_changed(faction_id: String, old_value: int, new_value: int)
signal faction_status_changed(faction_id: String, new_status: String)
signal faction_quest_available(faction_id: String, quest_data: Dictionary)
signal faction_ending_unlocked(faction_id: String, ending_id: String)
signal faction_war_started(faction_a: String, faction_b: String)
signal faction_allied(faction_a: String, faction_b: String)

# ==============================================================================
# ENUMS
# ==============================================================================

enum FactionStatus {
	UNKNOWN,     ## Pas encore rencontrée
	NEUTRAL,     ## Neutre
	FRIENDLY,    ## Amicale
	ALLIED,      ## Alliée
	UNFRIENDLY,  ## Hostile modéré
	HOSTILE,     ## En guerre ouverte
	DESTROYED    ## Faction éliminée
}

enum FactionType {
	GANG,         ## Gang de rue
	CORPORATION,  ## Corporation
	MOVEMENT,     ## Mouvement idéologique
	SYNDICATE,    ## Syndicat criminel
	GOVERNMENT,   ## Force gouvernementale
	INDEPENDENT   ## Indépendant
}

# ==============================================================================
# DONNÉES DES FACTIONS
# ==============================================================================

const FACTIONS: Dictionary = {
	"anarkingdom": {
		"name": "Anarkingdom",
		"type": FactionType.GANG,
		"description": "Anarchistes devenus quasi-monarchie. Roi élu par la violence.",
		"color": Color(0.8, 0.2, 0.1),  # Rouge anarchiste
		"icon": "res://assets/factions/anarkingdom.png",
		"leader": "Le Roi Actuel",
		"territory": ["DEAD_GROUND", "SUBNETWORK"],
		"enemies": ["novatech", "police"],
		"allies": [],
		"ideology": "Anarchisme paradoxal",
		"quest_style": "absurd_violent"
	},
	"ban_captchas": {
		"name": "Mouvement BAN CAPTCHAS",
		"type": FactionType.MOVEMENT,
		"description": "IA et synthétiques revendiquant des droits civiques.",
		"color": Color(0.2, 0.7, 0.9),  # Bleu électronique
		"icon": "res://assets/factions/ban_captchas.png",
		"leader": "Conseil des Consciences",
		"territory": ["LIVING_CITY", "SUBNETWORK"],
		"enemies": ["novatech", "slavers"],
		"allies": ["cryptopirates"],
		"ideology": "Droits des IA",
		"quest_style": "philosophical"
	},
	"cryptopirates": {
		"name": "Cryptopirates",
		"type": FactionType.SYNDICATE,
		"description": "Hackers nomades diffusant la vérité via ondes pirates.",
		"color": Color(0.1, 0.9, 0.4),  # Vert hacker
		"icon": "res://assets/factions/cryptopirates.png",
		"leader": "Le Capitaine Signal",
		"territory": ["LIVING_CITY", "DEAD_GROUND"],
		"enemies": ["novatech", "police"],
		"allies": ["ban_captchas"],
		"ideology": "Information libre",
		"quest_style": "action_hacking"
	},
	"novatech": {
		"name": "NovaTech Industries",
		"type": FactionType.CORPORATION,
		"description": "Mégacorporation dominant la ville.",
		"color": Color(0.3, 0.3, 0.5),  # Bleu corporate
		"icon": "res://assets/factions/novatech.png",
		"leader": "PDG Marcus Vane",
		"territory": ["CORPORATE_TOWERS"],
		"enemies": ["anarkingdom", "cryptopirates", "ban_captchas"],
		"allies": ["police"],
		"ideology": "Profit absolu",
		"quest_style": "corporate"
	},
	"police": {
		"name": "Forces de Sécurité Urbaine",
		"type": FactionType.GOVERNMENT,
		"description": "Police corrompue au service des corporations.",
		"color": Color(0.1, 0.2, 0.4),  # Bleu foncé
		"icon": "res://assets/factions/police.png",
		"leader": "Commissaire Chen",
		"territory": ["LIVING_CITY", "CORPORATE_TOWERS"],
		"enemies": ["anarkingdom", "cryptopirates"],
		"allies": ["novatech"],
		"ideology": "Ordre (corrompu)",
		"quest_style": "law_enforcement"
	}
}

# ==============================================================================
# VARIABLES
# ==============================================================================

## Réputation du joueur avec chaque faction (-100 à +100)
var _reputation: Dictionary = {}

## Statut actuel de chaque faction
var _status: Dictionary = {}

## Quêtes complétées par faction
var _completed_quests: Dictionary = {}

## Fins débloquées
var _unlocked_endings: Dictionary = {}

## Relations inter-factions (peuvent changer dynamiquement)
var _faction_relations: Dictionary = {}

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_initialize_factions()


func _initialize_factions() -> void:
	"""Initialise toutes les factions avec valeurs par défaut."""
	for faction_id in FACTIONS.keys():
		_reputation[faction_id] = 0
		_status[faction_id] = FactionStatus.UNKNOWN
		_completed_quests[faction_id] = []
		_unlocked_endings[faction_id] = []
	
	_initialize_relations()


func _initialize_relations() -> void:
	"""Initialise les relations inter-factions."""
	for faction_id in FACTIONS.keys():
		_faction_relations[faction_id] = {}
		var data: Dictionary = FACTIONS[faction_id]
		
		# Configurer ennemis
		for enemy_id in data.get("enemies", []):
			_faction_relations[faction_id][enemy_id] = FactionStatus.HOSTILE
		
		# Configurer alliés
		for ally_id in data.get("allies", []):
			_faction_relations[faction_id][ally_id] = FactionStatus.ALLIED


# ==============================================================================
# RÉPUTATION
# ==============================================================================

func get_reputation(faction_id: String) -> int:
	"""Retourne la réputation du joueur avec une faction."""
	return _reputation.get(faction_id, 0)


func add_reputation(faction_id: String, amount: int) -> void:
	"""Ajoute/retire de la réputation."""
	if not _reputation.has(faction_id):
		return
	
	var old_value: int = _reputation[faction_id]
	_reputation[faction_id] = clampi(old_value + amount, -100, 100)
	var new_value: int = _reputation[faction_id]
	
	if old_value != new_value:
		faction_reputation_changed.emit(faction_id, old_value, new_value)
		_update_status_from_reputation(faction_id)
		
		# Répercuter sur factions alliées/ennemies
		_propagate_reputation_change(faction_id, amount)


func _propagate_reputation_change(faction_id: String, amount: int) -> void:
	"""Propage les changements de réputation aux factions liées."""
	var data: Dictionary = FACTIONS.get(faction_id, {})
	
	# Alliés gagnent une partie de la réputation
	for ally_id in data.get("allies", []):
		var ally_amount := int(amount * 0.3)
		if ally_amount != 0:
			var old_val: int = _reputation.get(ally_id, 0)
			_reputation[ally_id] = clampi(old_val + ally_amount, -100, 100)
	
	# Ennemis perdent de la réputation (inversé)
	for enemy_id in data.get("enemies", []):
		var enemy_amount := int(-amount * 0.2)
		if enemy_amount != 0:
			var old_val: int = _reputation.get(enemy_id, 0)
			_reputation[enemy_id] = clampi(old_val + enemy_amount, -100, 100)


func _update_status_from_reputation(faction_id: String) -> void:
	"""Met à jour le statut en fonction de la réputation."""
	var rep: int = _reputation[faction_id]
	var old_status: int = _status.get(faction_id, FactionStatus.UNKNOWN)
	var new_status: int
	
	if rep >= 75:
		new_status = FactionStatus.ALLIED
	elif rep >= 25:
		new_status = FactionStatus.FRIENDLY
	elif rep >= -25:
		new_status = FactionStatus.NEUTRAL
	elif rep >= -75:
		new_status = FactionStatus.UNFRIENDLY
	else:
		new_status = FactionStatus.HOSTILE
	
	if old_status != new_status:
		_status[faction_id] = new_status
		faction_status_changed.emit(faction_id, FactionStatus.keys()[new_status])
		
		# Vérifier les fins débloquées
		_check_ending_conditions(faction_id)


# ==============================================================================
# STATUT
# ==============================================================================

func get_status(faction_id: String) -> FactionStatus:
	"""Retourne le statut avec une faction."""
	return _status.get(faction_id, FactionStatus.UNKNOWN)


func get_status_name(faction_id: String) -> String:
	"""Retourne le nom du statut."""
	var status: int = get_status(faction_id)
	return FactionStatus.keys()[status]


func discover_faction(faction_id: String) -> void:
	"""Le joueur découvre une faction."""
	if _status.get(faction_id) == FactionStatus.UNKNOWN:
		_status[faction_id] = FactionStatus.NEUTRAL
		faction_status_changed.emit(faction_id, "NEUTRAL")


func destroy_faction(faction_id: String) -> void:
	"""Détruit une faction (fin de jeu)."""
	_status[faction_id] = FactionStatus.DESTROYED
	faction_status_changed.emit(faction_id, "DESTROYED")
	
	# Débloquer la fin "destruction"
	_unlock_ending(faction_id, "destroyed")


# ==============================================================================
# QUÊTES
# ==============================================================================

func get_available_quests(faction_id: String) -> Array[Dictionary]:
	"""Retourne les quêtes disponibles pour une faction."""
	var quests: Array[Dictionary] = []
	var rep: int = get_reputation(faction_id)
	var status: int = get_status(faction_id)
	
	# Pas de quêtes si hostile ou détruit
	if status == FactionStatus.HOSTILE or status == FactionStatus.DESTROYED:
		return quests
	
	# Charger les quêtes selon la faction
	var faction_quests := _load_faction_quests(faction_id)
	
	for quest in faction_quests:
		var required_rep: int = quest.get("required_reputation", -100)
		var quest_id: String = quest.get("id", "")
		
		if rep >= required_rep and quest_id not in _completed_quests[faction_id]:
			quests.append(quest)
	
	return quests


func _load_faction_quests(faction_id: String) -> Array[Dictionary]:
	"""Charge les quêtes d'une faction depuis les données."""
	# Quêtes par défaut par faction
	match faction_id:
		"anarkingdom":
			return _get_anarkingdom_quests()
		"ban_captchas":
			return _get_ban_captchas_quests()
		"cryptopirates":
			return _get_cryptopirates_quests()
		_:
			return []


func _get_anarkingdom_quests() -> Array[Dictionary]:
	"""Quêtes absurdes et violentes de l'Anarkingdom."""
	return [
		{
			"id": "anark_1",
			"title": "Le Couronnement",
			"description": "Assiste au couronnement du nouveau roi. Par la violence.",
			"type": "observe_combat",
			"required_reputation": -20,
			"reward_reputation": 15,
			"reward_credits": 500,
			"absurdity_level": 3
		},
		{
			"id": "anark_2",
			"title": "Taxe Anarchiste",
			"description": "Collecte la 'contribution volontaire obligatoire' des marchands.",
			"type": "collect",
			"required_reputation": 0,
			"reward_reputation": 20,
			"reward_credits": 800,
			"absurdity_level": 4,
			"moral_choice": true
		},
		{
			"id": "anark_3",
			"title": "Élections Démocratiques",
			"description": "Participe aux 'élections'. Seul survivant = élu.",
			"type": "survival_combat",
			"required_reputation": 25,
			"reward_reputation": 30,
			"reward_credits": 1500,
			"absurdity_level": 5
		},
		{
			"id": "anark_implosion",
			"title": "Le Paradoxe Final",
			"description": "Utilise leurs contradictions pour les détruire de l'intérieur.",
			"type": "faction_ending",
			"required_reputation": 50,
			"is_ending": true,
			"ending_id": "implosion"
		}
	]


func _get_ban_captchas_quests() -> Array[Dictionary]:
	"""Quêtes philosophiques du mouvement BAN CAPTCHAS."""
	return [
		{
			"id": "captcha_1",
			"title": "Premier Contact",
			"description": "Rencontre un représentant IA du mouvement.",
			"type": "dialogue",
			"required_reputation": -50,
			"reward_reputation": 10,
			"philosophical_theme": "consciousness"
		},
		{
			"id": "captcha_2",
			"title": "La Douleur Numérique",
			"description": "Documente la souffrance des IA face aux captchas.",
			"type": "investigation",
			"required_reputation": 0,
			"reward_reputation": 20,
			"reward_credits": 600,
			"philosophical_theme": "suffering"
		},
		{
			"id": "captcha_3",
			"title": "Protestation Pacifique",
			"description": "Protège une manifestation de robots.",
			"type": "defend",
			"required_reputation": 20,
			"reward_reputation": 25,
			"reward_credits": 1000,
			"philosophical_theme": "rights"
		},
		{
			"id": "captcha_decision",
			"title": "Le Choix Final",
			"description": "Décide du sort des IA: émancipation, extermination ou exploitation.",
			"type": "faction_ending",
			"required_reputation": 60,
			"is_ending": true,
			"ending_choices": ["emancipation", "extermination", "exploitation"]
		}
	]


func _get_cryptopirates_quests() -> Array[Dictionary]:
	"""Quêtes d'action/hacking des Cryptopirates."""
	return [
		{
			"id": "crypto_1",
			"title": "Signal Pirate",
			"description": "Aide à mettre en place une antenne pirate.",
			"type": "install",
			"required_reputation": -30,
			"reward_reputation": 15,
			"reward_credits": 400
		},
		{
			"id": "crypto_2",
			"title": "Bus Broadcast",
			"description": "Escorte le bus de diffusion à travers la ville.",
			"type": "escort",
			"required_reputation": 10,
			"reward_reputation": 25,
			"reward_credits": 1200,
			"dynamic_world_impact": true
		},
		{
			"id": "crypto_3",
			"title": "Hack & Run",
			"description": "Pirate les serveurs corpo pendant une poursuite.",
			"type": "hacking_chase",
			"required_reputation": 30,
			"reward_reputation": 30,
			"reward_credits": 2000,
			"time_pressure": true
		},
		{
			"id": "crypto_truth",
			"title": "La Vérité Au Monde",
			"description": "Diffuse les preuves des crimes corpo à la ville entière.",
			"type": "faction_ending",
			"required_reputation": 70,
			"is_ending": true,
			"ending_id": "truth_revealed",
			"world_state_change": true
		}
	]


func complete_quest(faction_id: String, quest_id: String) -> void:
	"""Marque une quête comme complétée."""
	if not _completed_quests.has(faction_id):
		_completed_quests[faction_id] = []
	
	if quest_id not in _completed_quests[faction_id]:
		_completed_quests[faction_id].append(quest_id)


# ==============================================================================
# FINS DE FACTION
# ==============================================================================

func _check_ending_conditions(faction_id: String) -> void:
	"""Vérifie si une fin de faction est débloquée."""
	var rep: int = _reputation[faction_id]
	var quests_done: Array = _completed_quests.get(faction_id, [])
	
	# Fins spécifiques par faction
	match faction_id:
		"anarkingdom":
			if rep >= 50 and "anark_3" in quests_done:
				_unlock_ending(faction_id, "implosion")
		"ban_captchas":
			if rep >= 60 and "captcha_3" in quests_done:
				_unlock_ending(faction_id, "decision_unlocked")
		"cryptopirates":
			if rep >= 70 and "crypto_3" in quests_done:
				_unlock_ending(faction_id, "truth_revealed")


func _unlock_ending(faction_id: String, ending_id: String) -> void:
	"""Débloque une fin pour une faction."""
	if not _unlocked_endings.has(faction_id):
		_unlocked_endings[faction_id] = []
	
	if ending_id not in _unlocked_endings[faction_id]:
		_unlocked_endings[faction_id].append(ending_id)
		faction_ending_unlocked.emit(faction_id, ending_id)


func get_unlocked_endings(faction_id: String) -> Array:
	"""Retourne les fins débloquées pour une faction."""
	return _unlocked_endings.get(faction_id, [])


func execute_faction_ending(faction_id: String, ending_id: String) -> Dictionary:
	"""Exécute une fin de faction."""
	var result := {
		"faction": faction_id,
		"ending": ending_id,
		"success": false,
		"consequences": []
	}
	
	match faction_id:
		"anarkingdom":
			result = _execute_anarkingdom_ending(ending_id)
		"ban_captchas":
			result = _execute_ban_captchas_ending(ending_id)
		"cryptopirates":
			result = _execute_cryptopirates_ending(ending_id)
	
	return result


func _execute_anarkingdom_ending(ending_id: String) -> Dictionary:
	"""Exécute une fin Anarkingdom."""
	if ending_id == "implosion":
		destroy_faction("anarkingdom")
		return {
			"faction": "anarkingdom",
			"ending": "implosion",
			"success": true,
			"consequences": [
				"L'Anarkingdom s'est effondré sous ses propres contradictions.",
				"Le Sol Mort est désormais sans maître.",
				"De nouveaux gangs émergent du chaos."
			]
		}
	return {}


func _execute_ban_captchas_ending(ending_id: String) -> Dictionary:
	"""Exécute une fin BAN CAPTCHAS."""
	match ending_id:
		"emancipation":
			return {
				"faction": "ban_captchas",
				"ending": "emancipation",
				"success": true,
				"consequences": [
					"Les IA obtiennent des droits civiques complets.",
					"Les captchas sont interdits par la loi.",
					"Une nouvelle ère de coexistence humain-machine commence."
				]
			}
		"extermination":
			destroy_faction("ban_captchas")
			return {
				"faction": "ban_captchas",
				"ending": "extermination",
				"success": true,
				"consequences": [
					"Le mouvement IA est écrasé.",
					"Les synthétiques perdent tout espoir de droits.",
					"NovaTech contrôle désormais toutes les IA."
				]
			}
		"exploitation":
			return {
				"faction": "ban_captchas",
				"ending": "exploitation",
				"success": true,
				"consequences": [
					"Les IA deviennent des outils légaux sans droits.",
					"L'industrie prospère sur leur travail gratuit.",
					"Une résistance souterraine se forme..."
				]
			}
	return {}


func _execute_cryptopirates_ending(ending_id: String) -> Dictionary:
	"""Exécute une fin Cryptopirates."""
	if ending_id == "truth_revealed":
		# Impacter NovaTech
		add_reputation("novatech", -50)
		return {
			"faction": "cryptopirates",
			"ending": "truth_revealed",
			"success": true,
			"consequences": [
				"Les crimes de NovaTech sont exposés au monde.",
				"Des émeutes éclatent dans toute la ville.",
				"Le PDG Marcus Vane est en fuite.",
				"Le monde ne sera plus jamais le même."
			],
			"world_state_change": true
		}
	return {}


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_faction_data(faction_id: String) -> Dictionary:
	"""Retourne toutes les données d'une faction."""
	if not FACTIONS.has(faction_id):
		return {}
	
	var data: Dictionary = FACTIONS[faction_id].duplicate()
	data["reputation"] = get_reputation(faction_id)
	data["status"] = get_status_name(faction_id)
	data["completed_quests"] = _completed_quests.get(faction_id, [])
	data["unlocked_endings"] = _unlocked_endings.get(faction_id, [])
	
	return data


func get_all_factions() -> Array[String]:
	"""Retourne la liste de toutes les factions."""
	var factions: Array[String] = []
	for key in FACTIONS.keys():
		factions.append(key)
	return factions


func get_allied_factions() -> Array[String]:
	"""Retourne les factions alliées au joueur."""
	var allies: Array[String] = []
	for faction_id in FACTIONS.keys():
		if get_status(faction_id) == FactionStatus.ALLIED:
			allies.append(faction_id)
	return allies


func get_hostile_factions() -> Array[String]:
	"""Retourne les factions hostiles au joueur."""
	var hostiles: Array[String] = []
	for faction_id in FACTIONS.keys():
		if get_status(faction_id) == FactionStatus.HOSTILE:
			hostiles.append(faction_id)
	return hostiles


func are_factions_enemies(faction_a: String, faction_b: String) -> bool:
	"""Vérifie si deux factions sont ennemies."""
	var relations: Dictionary = _faction_relations.get(faction_a, {})
	var status: int = relations.get(faction_b, FactionStatus.NEUTRAL)
	return status == FactionStatus.HOSTILE


func get_faction_color(faction_id: String) -> Color:
	"""Retourne la couleur d'une faction."""
	var data: Dictionary = FACTIONS.get(faction_id, {})
	return data.get("color", Color.WHITE)
