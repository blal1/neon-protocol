# ==============================================================================
# MeaningfulActivityGenerator.gd - Activités Secondaires Significatives
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Pas de fillers. Chaque activité révèle le monde et modifie l'équilibre local.
# ==============================================================================

extends Node
class_name MeaningfulActivityGenerator

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal activity_generated(activity: Dictionary)
signal activity_accepted(activity_id: String)
signal activity_completed(activity_id: String, outcome: Dictionary)
signal activity_failed(activity_id: String, reason: String)
signal world_state_changed(change: Dictionary)
signal local_balance_shifted(district_id: String, shift: Dictionary)

# ==============================================================================
# ENUMS
# ==============================================================================

enum ActivityType {
	DELIVERY,          ## Livraison (implant illégal, médicaments, etc.)
	ESCORT,            ## Escorte (médecin, informateur, etc.)
	PROTECTION,        ## Protection (food truck, stand, etc.)
	SABOTAGE,          ## Sabotage (ferme verticale, usine, etc.)
	INFILTRATION,      ## Infiltration (QuietRoom, bâtiment, etc.)
	INVESTIGATION,     ## Investigation (disparitions, crimes, etc.)
	RESCUE,            ## Sauvetage (prisonnier, endetta, etc.)
	PROPAGANDA         ## Propagande (diffusion, affichage, etc.)
}

enum ActivityDifficulty {
	ROUTINE = 1,
	CHALLENGING = 2,
	DANGEROUS = 3,
	SUICIDAL = 4
}

# ==============================================================================
# TEMPLATES D'ACTIVITÉS
# ==============================================================================

const ACTIVITY_TEMPLATES: Array[Dictionary] = [
	# ============ LIVRAISONS ============
	{
		"id_prefix": "delivery_implant",
		"type": ActivityType.DELIVERY,
		"name": "Implant en Transit",
		"description": "Livre un implant militaire illégal à un client dans {destination}.",
		"reveals": "Les flux du marché noir cybernétique",
		"world_impact": {
			"district_economic_boost": 0.05,
			"faction_rep_change": {"black_market": 10, "police": -5}
		},
		"difficulty": ActivityDifficulty.CHALLENGING,
		"time_limit": 300,  # 5 minutes
		"reward_credits": [500, 800],
		"complications": ["police_checkpoint", "rival_courier", "client_ambush"]
	},
	{
		"id_prefix": "delivery_medicine",
		"type": ActivityType.DELIVERY,
		"name": "Médicaments Sans Ordonnance",
		"description": "Apporte des médicaments vitaux à une clinique clandestine dans {destination}.",
		"reveals": "Le système de santé à deux vitesses",
		"world_impact": {
			"district_tension_reduce": 0.05,
			"faction_rep_change": {"citizens": 15}
		},
		"difficulty": ActivityDifficulty.ROUTINE,
		"time_limit": 600,
		"reward_credits": [200, 400],
		"complications": ["gang_toll", "expired_meds_ethical"]
	},
	
	# ============ ESCORTES ============
	{
		"id_prefix": "escort_doctor",
		"type": ActivityType.ESCORT,
		"name": "Le Médecin Clandestin",
		"description": "Escorte un médecin jusqu'à {destination} pour une opération urgente.",
		"reveals": "La violence du refus de soins",
		"world_impact": {
			"npc_saved": true,
			"district_reputation_boost": 10,
			"faction_rep_change": {"citizens": 20, "corporations": -10}
		},
		"difficulty": ActivityDifficulty.DANGEROUS,
		"reward_credits": [800, 1200],
		"npc_name": "Dr. ${random_name}",
		"complications": ["corpo_bounty_hunters", "patient_dies_anyway", "doctor_is_target"]
	},
	{
		"id_prefix": "escort_witness",
		"type": ActivityType.ESCORT,
		"name": "Témoin Gênant",
		"description": "Amène un témoin en sécurité avant que les corpos ne le trouvent.",
		"reveals": "Les crimes que les corporations veulent cacher",
		"world_impact": {
			"truth_revealed": true,
			"faction_rep_change": {"cryptopirates": 15, "novatech": -20}
		},
		"difficulty": ActivityDifficulty.DANGEROUS,
		"reward_credits": [1000, 1500],
		"complications": ["betrayal_offer", "witness_lies", "multiple_factions_hunt"]
	},
	
	# ============ PROTECTIONS ============
	{
		"id_prefix": "protect_foodtruck",
		"type": ActivityType.PROTECTION,
		"name": "Food Truck Informateur",
		"description": "Protège le food truck de {owner} pendant sa tournée. Il a des infos à livrer.",
		"reveals": "Le réseau d'information des petits commerçants",
		"world_impact": {
			"informant_network_strengthened": true,
			"district_food_security": 0.03,
			"faction_rep_change": {"citizens": 10, "gangs": -5}
		},
		"difficulty": ActivityDifficulty.CHALLENGING,
		"reward_credits": [400, 700],
		"duration": 900,  # 15 minutes de protection
		"complications": ["extortion_gang", "corrupt_health_inspector", "rival_vendor"]
	},
	{
		"id_prefix": "protect_clinic",
		"type": ActivityType.PROTECTION,
		"name": "La Clinique Assiégée",
		"description": "Défends une clinique clandestine contre les collecteurs de dettes.",
		"reveals": "Le cycle infernal de la dette médicale",
		"world_impact": {
			"clinic_survives": true,
			"district_medical_access": true,
			"faction_rep_change": {"citizens": 25, "debt_collectors": -30}
		},
		"difficulty": ActivityDifficulty.DANGEROUS,
		"reward_credits": [600, 1000],
		"wave_count": 3,
		"complications": ["hostage_situation", "clinic_has_stolen_goods", "collector_has_point"]
	},
	
	# ============ SABOTAGES ============
	{
		"id_prefix": "sabotage_farm",
		"type": ActivityType.SABOTAGE,
		"name": "Graines de Discorde",
		"description": "Sabote la ferme verticale de {corporation} pour forcer une redistribution.",
		"reveals": "Le contrôle alimentaire comme arme",
		"world_impact": {
			"food_prices_change": -0.1,
			"faction_rep_change": {"anarkingdom": 20, "novatech": -25}
		},
		"difficulty": ActivityDifficulty.DANGEROUS,
		"reward_credits": [1200, 1800],
		"stealth_required": true,
		"complications": ["worker_casualties", "backup_systems", "inside_help_is_trap"]
	},
	{
		"id_prefix": "sabotage_surveillance",
		"type": ActivityType.SABOTAGE,
		"name": "Angle Mort",
		"description": "Désactive le réseau de surveillance d'un quartier pendant 24h.",
		"reveals": "L'étendue de la surveillance quotidienne",
		"world_impact": {
			"district_surveillance_down": true,
			"faction_rep_change": {"cryptopirates": 15, "police": -20}
		},
		"difficulty": ActivityDifficulty.CHALLENGING,
		"reward_credits": [700, 1100],
		"hacking_required": true,
		"complications": ["backup_grid", "corpo_hackers_trace", "criminals_exploit"]
	},
	
	# ============ INFILTRATIONS ============
	{
		"id_prefix": "infiltrate_quietroom",
		"type": ActivityType.INFILTRATION,
		"name": "QuietRoom Piraté",
		"description": "Infiltre un QuietRoom™ compromis et découvre qui écoute les 'conversations privées'.",
		"reveals": "Même les espaces 'sûrs' sont surveillés",
		"world_impact": {
			"quiet_room_exposed": true,
			"faction_rep_change": {"cryptopirates": 20, "corporations": -15}
		},
		"difficulty": ActivityDifficulty.CHALLENGING,
		"reward_credits": [900, 1400],
		"social_skill_required": true,
		"complications": ["cover_blown", "vip_target_present", "blackmail_opportunity"]
	},
	{
		"id_prefix": "infiltrate_corpo",
		"type": ActivityType.INFILTRATION,
		"name": "Taupe d'un Jour",
		"description": "Infiltre les bureaux de {corporation} et récupère des données sensibles.",
		"reveals": "Les secrets que les corporations gardent",
		"world_impact": {
			"data_stolen": true,
			"faction_rep_change": {"cryptopirates": 25, "novatech": -30}
		},
		"difficulty": ActivityDifficulty.SUICIDAL,
		"reward_credits": [2000, 3500],
		"stealth_required": true,
		"hacking_required": true,
		"complications": ["security_upgrade", "double_agent", "files_are_honeypot"]
	},
	
	# ============ INVESTIGATIONS ============
	{
		"id_prefix": "investigate_missing",
		"type": ActivityType.INVESTIGATION,
		"name": "Les Disparus",
		"description": "Enquête sur des disparitions dans {district}. Les autorités n'en ont rien à faire.",
		"reveals": "Ce qui arrive aux gens que personne ne cherche",
		"world_impact": {
			"truth_uncovered": true,
			"district_awareness": 0.1,
			"faction_rep_change": {"citizens": 20, "police": -10}
		},
		"difficulty": ActivityDifficulty.CHALLENGING,
		"reward_credits": [500, 900],
		"investigation_points": 5,
		"complications": ["chop_shop_connection", "victims_complicit", "powerful_perpetrator"]
	},
	
	# ============ SAUVETAGES ============
	{
		"id_prefix": "rescue_debtor",
		"type": ActivityType.RESCUE,
		"name": "Avant la Saisie",
		"description": "Sauve quelqu'un avant que les collecteurs ne reprennent ses implants.",
		"reveals": "Le système de dette qui broie les gens",
		"world_impact": {
			"life_saved": true,
			"faction_rep_change": {"citizens": 15, "debt_collectors": -25}
		},
		"difficulty": ActivityDifficulty.DANGEROUS,
		"time_limit": 180,  # 3 minutes
		"reward_credits": [400, 800],
		"complications": ["victim_refuses_help", "collectors_are_ai", "debt_is_legitimate"]
	},
	
	# ============ PROPAGANDE ============
	{
		"id_prefix": "propaganda_truth",
		"type": ActivityType.PROPAGANDA,
		"name": "La Voix des Sans-Voix",
		"description": "Place des émetteurs pirates pour diffuser un message de résistance.",
		"reveals": "Le pouvoir de l'information libre",
		"world_impact": {
			"propaganda_level_reduced": 5,
			"district_tension_change": 0.1,
			"faction_rep_change": {"cryptopirates": 20, "police": -15}
		},
		"difficulty": ActivityDifficulty.CHALLENGING,
		"reward_credits": [600, 1000],
		"placement_count": 3,
		"complications": ["message_corrupted", "traced_immediately", "civilian_caught"]
	}
]

# ==============================================================================
# VARIABLES
# ==============================================================================

var _active_activities: Dictionary = {}  # id -> activity data
var _completed_activities: Array[String] = []
var _failed_activities: Array[String] = []
var _world_state_changes: Array[Dictionary] = []

# ==============================================================================
# GÉNÉRATION D'ACTIVITÉS
# ==============================================================================

func generate_activity_for_district(district_id: String) -> Dictionary:
	"""Génère une activité appropriée pour un district."""
	var district_data := {}
	if DistrictEcosystem:
		district_data = DistrictEcosystem.get_district_data(district_id)
	
	# Filtrer les activités appropriées au district
	var appropriate_templates := _filter_templates_for_district(district_id, district_data)
	
	if appropriate_templates.is_empty():
		return {}
	
	# Sélectionner un template aléatoire
	var template: Dictionary = appropriate_templates[randi() % appropriate_templates.size()]
	
	# Générer l'activité concrète
	var activity := _instantiate_activity(template, district_id)
	
	activity_generated.emit(activity)
	return activity


func _filter_templates_for_district(district_id: String, district_data: Dictionary) -> Array[Dictionary]:
	"""Filtre les templates appropriés au district."""
	var filtered: Array[Dictionary] = []
	var district_type: int = district_data.get("type", 0)
	
	for template in ACTIVITY_TEMPLATES:
		var activity_type: int = template.type
		
		# Certaines activités sont plus probables dans certains districts
		var is_appropriate := true
		
		match activity_type:
			ActivityType.SABOTAGE:
				# Sabotage plus courant dans les zones industrielles/corpo
				is_appropriate = district_type in [0, 2]  # CORPORATE, INDUSTRIAL
			ActivityType.RESCUE:
				# Sauvetages dans les zones pauvres
				is_appropriate = district_type in [3, 5]  # SLUMS, UNDERGROUND
			ActivityType.INFILTRATION:
				# Infiltrations partout sauf wasteland
				is_appropriate = district_type != 4  # NOMAD
		
		if is_appropriate:
			filtered.append(template)
	
	return filtered


func _instantiate_activity(template: Dictionary, district_id: String) -> Dictionary:
	"""Crée une instance concrète d'activité."""
	var activity := template.duplicate(true)
	
	# ID unique
	activity["id"] = "%s_%d" % [template.id_prefix, randi()]
	
	# Destination aléatoire
	var destinations := ["The Sprawl", "Dead End", "Rust Belt", "The Depths", "Neon Mile"]
	var destination := destinations[randi() % destinations.size()]
	
	# Remplacer les placeholders
	if activity.has("description"):
		activity.description = activity.description.replace("{destination}", destination)
		activity.description = activity.description.replace("{district}", district_id)
		activity.description = activity.description.replace("{corporation}", "NovaTech")
		activity.description = activity.description.replace("{owner}", _generate_npc_name())
	
	# Récompense aléatoire dans la fourchette
	if activity.has("reward_credits"):
		var range_arr: Array = activity.reward_credits
		activity.reward_credits = randi_range(range_arr[0], range_arr[1])
	
	# Sélectionner une complication aléatoire
	if activity.has("complications"):
		activity.active_complication = activity.complications[randi() % activity.complications.size()]
	
	# Métadonnées
	activity.source_district = district_id
	activity.destination = destination
	activity.generated_at = Time.get_ticks_msec()
	activity.status = "available"
	
	return activity


func _generate_npc_name() -> String:
	"""Génère un nom de PNJ aléatoire."""
	var first_names := ["Jin", "Marcus", "Elena", "Viktor", "Yuki", "Dante", "Zara", "Chen"]
	var last_names := ["Vance", "Reyes", "Nomura", "Black", "Sterling", "Cross", "Park"]
	return "%s %s" % [first_names[randi() % first_names.size()], last_names[randi() % last_names.size()]]


# ==============================================================================
# GESTION DES ACTIVITÉS
# ==============================================================================

func accept_activity(activity_id: String) -> bool:
	"""Accepte une activité."""
	if _active_activities.has(activity_id):
		return false  # Déjà active
	
	# Trouver l'activité (simplification - normalement stockée quelque part)
	var activity := {"id": activity_id, "status": "active"}
	_active_activities[activity_id] = activity
	
	activity_accepted.emit(activity_id)
	return true


func complete_activity(activity_id: String, success: bool = true) -> Dictionary:
	"""Complète une activité."""
	if not _active_activities.has(activity_id):
		return {"error": "Activité non trouvée"}
	
	var activity: Dictionary = _active_activities[activity_id]
	_active_activities.erase(activity_id)
	
	if success:
		_completed_activities.append(activity_id)
		var outcome := _apply_world_impact(activity)
		activity_completed.emit(activity_id, outcome)
		return outcome
	else:
		_failed_activities.append(activity_id)
		activity_failed.emit(activity_id, "failed")
		return {"success": false}


func _apply_world_impact(activity: Dictionary) -> Dictionary:
	"""Applique l'impact sur le monde."""
	var impact: Dictionary = activity.get("world_impact", {})
	var outcome := {
		"success": true,
		"reveals": activity.get("reveals", ""),
		"changes": []
	}
	
	var district: String = activity.get("source_district", "")
	
	# Boost économique
	if impact.has("district_economic_boost") and DistrictEcosystem:
		DistrictEcosystem.modify_district_economy(district, impact.district_economic_boost)
		outcome.changes.append("Économie locale +%d%%" % int(impact.district_economic_boost * 100))
	
	# Réduction de tension
	if impact.has("district_tension_reduce") and DistrictEcosystem:
		DistrictEcosystem.modify_tension(district, -impact.district_tension_reduce)
		outcome.changes.append("Tension locale réduite")
	
	# Changements de réputation
	if impact.has("faction_rep_change") and FactionManager:
		for faction_id in impact.faction_rep_change.keys():
			var rep_change: int = impact.faction_rep_change[faction_id]
			FactionManager.add_reputation(faction_id, rep_change)
			outcome.changes.append("Réputation %s: %+d" % [faction_id, rep_change])
	
	# Enregistrer le changement
	_world_state_changes.append({
		"activity": activity.id,
		"impact": impact,
		"time": Time.get_ticks_msec()
	})
	
	world_state_changed.emit(impact)
	local_balance_shifted.emit(district, impact)
	
	return outcome


# ==============================================================================
# REQUÊTES
# ==============================================================================

func get_active_activities() -> Dictionary:
	"""Retourne les activités actives."""
	return _active_activities


func get_activity_count() -> int:
	"""Retourne le nombre d'activités actives."""
	return _active_activities.size()


func get_completed_count() -> int:
	"""Retourne le nombre d'activités complétées."""
	return _completed_activities.size()


func get_world_changes() -> Array[Dictionary]:
	"""Retourne l'historique des changements."""
	return _world_state_changes


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"active": _active_activities.size(),
		"completed": _completed_activities.size(),
		"failed": _failed_activities.size(),
		"world_changes": _world_state_changes.size()
	}
