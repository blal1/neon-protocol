# ==============================================================================
# CyberpunkReputationSystem.gd - Réputation Multi-Couches
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Système de réputation complexe avec interdépendances entre groupes.
# Une bonne réputation avec un groupe peut verrouiller des options chez l'autre.
# ==============================================================================

extends Node
class_name CyberpunkReputationSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal reputation_changed(group_id: String, old_value: int, new_value: int)
signal reputation_tier_changed(group_id: String, old_tier: int, new_tier: int)
signal option_locked(option_id: String, reason: String)
signal option_unlocked(option_id: String)
signal reputation_conflict(group_a: String, group_b: String)

# ==============================================================================
# ENUMS
# ==============================================================================

enum ReputationGroup {
	CORPORATIONS,  ## Mégacorporations
	GANGS,         ## Gangs de rue
	CITIZENS,      ## Citoyens ordinaires
	AI_COLLECTIVE  ## IA et synthétiques
}

enum ReputationTier {
	HATED = -3,      ## Ennemi juré (-100 à -75)
	DESPISED = -2,   ## Méprisé (-74 à -50)
	DISLIKED = -1,   ## Mal vu (-49 à -25)
	NEUTRAL = 0,     ## Neutre (-24 à +24)
	LIKED = 1,       ## Apprécié (+25 à +49)
	RESPECTED = 2,   ## Respecté (+50 à +74)
	REVERED = 3      ## Vénéré (+75 à +100)
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## Matrice d'antagonisme (si +rep avec A, -rep avec B)
const ANTAGONISM_MATRIX: Dictionary = {
	"corporations": {
		"gangs": -0.5,       # Bon avec corpo = mauvais avec gangs
		"citizens": -0.2,    # Légère méfiance des citoyens
		"ai_collective": 0.0 # Neutre
	},
	"gangs": {
		"corporations": -0.5,
		"citizens": -0.3,    # Citoyens craignent les gangs
		"ai_collective": 0.1 # Légère sympathie
	},
	"citizens": {
		"corporations": 0.0,
		"gangs": -0.2,
		"ai_collective": 0.2 # Sympathie envers les IA
	},
	"ai_collective": {
		"corporations": -0.4,  # Corps exploitent les IA
		"gangs": 0.1,
		"citizens": 0.2
	}
}

## Options verrouillées par réputation
const LOCKED_OPTIONS: Dictionary = {
	"corpo_job_offer": {
		"requires": {"corporations": 50},
		"blocks": {"gangs": 25}  # Si rep gangs > 25, option bloquée
	},
	"gang_initiation": {
		"requires": {"gangs": 30},
		"blocks": {"corporations": 0}  # Bloqué si rep corpo positive
	},
	"citizen_safehouse": {
		"requires": {"citizens": 40},
		"blocks": {"gangs": 50}  # Trop lié aux gangs = méfiance
	},
	"ai_network_access": {
		"requires": {"ai_collective": 60},
		"blocks": {"corporations": 30}
	},
	"underground_clinic": {
		"requires": {"gangs": 20, "citizens": -10},  # Besoin rep gang, citoyens pas trop amicaux
		"blocks": {}
	}
}

# ==============================================================================
# VARIABLES
# ==============================================================================

## Réputation avec chaque groupe (-100 à +100)
var _reputation: Dictionary = {
	"corporations": 0,
	"gangs": 0,
	"citizens": 0,
	"ai_collective": 0
}

## Tier de réputation par groupe
var _reputation_tiers: Dictionary = {}

## Options actuellement verrouillées
var _locked_options: Array[String] = []

## Historique des changements (pour debugging)
var _history: Array[Dictionary] = []

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_update_all_tiers()
	_recalculate_locked_options()


# ==============================================================================
# RÉPUTATION DE BASE
# ==============================================================================

func get_reputation(group_id: String) -> int:
	"""Retourne la réputation avec un groupe."""
	return _reputation.get(group_id, 0)


func get_tier(group_id: String) -> ReputationTier:
	"""Retourne le tier de réputation avec un groupe."""
	return _reputation_tiers.get(group_id, ReputationTier.NEUTRAL)


func get_tier_name(group_id: String) -> String:
	"""Retourne le nom du tier."""
	var tier: int = get_tier(group_id)
	return ReputationTier.keys()[tier + 3]  # Offset pour l'enum négatif


func add_reputation(group_id: String, amount: int, propagate: bool = true) -> void:
	"""Ajoute/retire de la réputation avec propagation automatique."""
	if not _reputation.has(group_id):
		return
	
	var old_value: int = _reputation[group_id]
	_reputation[group_id] = clampi(old_value + amount, -100, 100)
	var new_value: int = _reputation[group_id]
	
	if old_value != new_value:
		reputation_changed.emit(group_id, old_value, new_value)
		_update_tier(group_id)
		
		# Historique
		_history.append({
			"group": group_id,
			"change": amount,
			"old": old_value,
			"new": new_value,
			"time": Time.get_ticks_msec()
		})
		
		# Propager aux autres groupes
		if propagate:
			_propagate_reputation_change(group_id, amount)
		
		# Recalculer les options verrouillées
		_recalculate_locked_options()


func set_reputation(group_id: String, value: int) -> void:
	"""Définit directement la réputation (sans propagation)."""
	if not _reputation.has(group_id):
		return
	
	var old_value: int = _reputation[group_id]
	_reputation[group_id] = clampi(value, -100, 100)
	var new_value: int = _reputation[group_id]
	
	if old_value != new_value:
		reputation_changed.emit(group_id, old_value, new_value)
		_update_tier(group_id)
		_recalculate_locked_options()


# ==============================================================================
# PROPAGATION
# ==============================================================================

func _propagate_reputation_change(source_group: String, amount: int) -> void:
	"""Propage les changements de réputation aux groupes antagonistes."""
	var antagonisms: Dictionary = ANTAGONISM_MATRIX.get(source_group, {})
	
	for target_group in antagonisms.keys():
		var multiplier: float = antagonisms[target_group]
		var propagated_amount := int(amount * multiplier)
		
		if propagated_amount != 0:
			# Ajouter sans re-propager (éviter boucle infinie)
			var old_val: int = _reputation[target_group]
			_reputation[target_group] = clampi(old_val + propagated_amount, -100, 100)
			var new_val: int = _reputation[target_group]
			
			if old_val != new_val:
				reputation_changed.emit(target_group, old_val, new_val)
				_update_tier(target_group)
				
				# Notifier le conflit si significatif
				if abs(propagated_amount) >= 10:
					reputation_conflict.emit(source_group, target_group)


# ==============================================================================
# TIERS
# ==============================================================================

func _update_tier(group_id: String) -> void:
	"""Met à jour le tier de réputation."""
	var rep: int = _reputation[group_id]
	var old_tier: int = _reputation_tiers.get(group_id, ReputationTier.NEUTRAL)
	var new_tier: int
	
	if rep <= -75:
		new_tier = ReputationTier.HATED
	elif rep <= -50:
		new_tier = ReputationTier.DESPISED
	elif rep <= -25:
		new_tier = ReputationTier.DISLIKED
	elif rep <= 24:
		new_tier = ReputationTier.NEUTRAL
	elif rep <= 49:
		new_tier = ReputationTier.LIKED
	elif rep <= 74:
		new_tier = ReputationTier.RESPECTED
	else:
		new_tier = ReputationTier.REVERED
	
	if old_tier != new_tier:
		_reputation_tiers[group_id] = new_tier
		reputation_tier_changed.emit(group_id, old_tier, new_tier)


func _update_all_tiers() -> void:
	"""Met à jour tous les tiers."""
	for group_id in _reputation.keys():
		_update_tier(group_id)


# ==============================================================================
# OPTIONS VERROUILLÉES
# ==============================================================================

func _recalculate_locked_options() -> void:
	"""Recalcule toutes les options verrouillées."""
	var old_locked := _locked_options.duplicate()
	_locked_options.clear()
	
	for option_id in LOCKED_OPTIONS.keys():
		var config: Dictionary = LOCKED_OPTIONS[option_id]
		var is_locked := false
		var lock_reason := ""
		
		# Vérifier les blocages
		var blocks: Dictionary = config.get("blocks", {})
		for block_group in blocks.keys():
			var threshold: int = blocks[block_group]
			if _reputation.get(block_group, 0) > threshold:
				is_locked = true
				lock_reason = "Réputation %s trop haute" % block_group
				break
		
		# Vérifier les prérequis
		if not is_locked:
			var requires: Dictionary = config.get("requires", {})
			for req_group in requires.keys():
				var threshold: int = requires[req_group]
				if _reputation.get(req_group, 0) < threshold:
					is_locked = true
					lock_reason = "Réputation %s insuffisante" % req_group
					break
		
		if is_locked:
			_locked_options.append(option_id)
			if option_id not in old_locked:
				option_locked.emit(option_id, lock_reason)
		elif option_id in old_locked:
			option_unlocked.emit(option_id)


func is_option_available(option_id: String) -> bool:
	"""Vérifie si une option est disponible."""
	return option_id not in _locked_options


func get_locked_options() -> Array[String]:
	"""Retourne toutes les options verrouillées."""
	return _locked_options


func get_option_requirements(option_id: String) -> Dictionary:
	"""Retourne les prérequis d'une option."""
	return LOCKED_OPTIONS.get(option_id, {})


# ==============================================================================
# RÉACTIONS DES GROUPES
# ==============================================================================

func get_group_reaction(group_id: String) -> String:
	"""Retourne la réaction d'un groupe envers le joueur."""
	var tier: int = get_tier(group_id)
	
	match group_id:
		"corporations":
			match tier:
				ReputationTier.HATED:
					return "Ordre d'élimination en cours"
				ReputationTier.DESPISED:
					return "Accès aux zones corpo interdit"
				ReputationTier.DISLIKED:
					return "Surveillance renforcée"
				ReputationTier.NEUTRAL:
					return "Citoyen lambda"
				ReputationTier.LIKED:
					return "Contractant potentiel"
				ReputationTier.RESPECTED:
					return "Associé de confiance"
				ReputationTier.REVERED:
					return "Actionnaire honoraire"
		
		"gangs":
			match tier:
				ReputationTier.HATED:
					return "Prime sur ta tête"
				ReputationTier.DESPISED:
					return "Attaqué à vue"
				ReputationTier.DISLIKED:
					return "Méfiance totale"
				ReputationTier.NEUTRAL:
					return "Inconnu"
				ReputationTier.LIKED:
					return "Un des nôtres"
				ReputationTier.RESPECTED:
					return "Frère de sang"
				ReputationTier.REVERED:
					return "Légende de la rue"
		
		"citizens":
			match tier:
				ReputationTier.HATED:
					return "Monstre public"
				ReputationTier.DESPISED:
					return "Criminel notoire"
				ReputationTier.DISLIKED:
					return "Voyou"
				ReputationTier.NEUTRAL:
					return "Passant"
				ReputationTier.LIKED:
					return "Bon Samaritain"
				ReputationTier.RESPECTED:
					return "Héros local"
				ReputationTier.REVERED:
					return "Légende vivante"
		
		"ai_collective":
			match tier:
				ReputationTier.HATED:
					return "Menace existentielle"
				ReputationTier.DESPISED:
					return "Oppresseur"
				ReputationTier.DISLIKED:
					return "Suspect"
				ReputationTier.NEUTRAL:
					return "Humain ordinaire"
				ReputationTier.LIKED:
					return "Sympathisant"
				ReputationTier.RESPECTED:
					return "Allié de la cause"
				ReputationTier.REVERED:
					return "Libérateur"
	
	return "Inconnu"


# ==============================================================================
# PRIX ET SERVICES
# ==============================================================================

func get_price_modifier(group_id: String) -> float:
	"""Retourne le modificateur de prix basé sur la réputation."""
	var tier: int = get_tier(group_id)
	
	match tier:
		ReputationTier.HATED:
			return 2.0      # Double prix (si même accessible)
		ReputationTier.DESPISED:
			return 1.5
		ReputationTier.DISLIKED:
			return 1.25
		ReputationTier.NEUTRAL:
			return 1.0
		ReputationTier.LIKED:
			return 0.9
		ReputationTier.RESPECTED:
			return 0.75
		ReputationTier.REVERED:
			return 0.5      # Moitié prix
	
	return 1.0


func can_access_service(service_id: String, group_id: String) -> bool:
	"""Vérifie si le joueur peut accéder à un service."""
	var tier: int = get_tier(group_id)
	
	# Services de base accessibles à tous sauf si haï
	if tier <= ReputationTier.HATED:
		return false
	
	# Services premium nécessitent une bonne réputation
	var premium_services := ["vip_lounge", "black_market_elite", "corpo_surgery"]
	if service_id in premium_services:
		return tier >= ReputationTier.RESPECTED
	
	return true


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_all_reputations() -> Dictionary:
	"""Retourne toutes les réputations."""
	return _reputation.duplicate()


func get_reputation_summary() -> Dictionary:
	"""Retourne un résumé complet."""
	var summary := {}
	for group_id in _reputation.keys():
		summary[group_id] = {
			"value": _reputation[group_id],
			"tier": get_tier_name(group_id),
			"reaction": get_group_reaction(group_id),
			"price_modifier": get_price_modifier(group_id)
		}
	return summary


func get_dominant_faction() -> String:
	"""Retourne la faction avec la meilleure réputation."""
	var best_group := ""
	var best_rep := -101
	
	for group_id in _reputation.keys():
		if _reputation[group_id] > best_rep:
			best_rep = _reputation[group_id]
			best_group = group_id
	
	return best_group


func reset_all() -> void:
	"""Remet toutes les réputations à zéro."""
	for group_id in _reputation.keys():
		_reputation[group_id] = 0
	_update_all_tiers()
	_recalculate_locked_options()
