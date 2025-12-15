# ==============================================================================
# CyberwareManager.gd - Système de Cyberware Décisionnel
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Pas de loot libre. Chaque implant = avantage clair + coût caché.
# Nécessite clinique/chirurgien/marché noir.
# Humanité fragmentée: sociale, cognitive, corporelle.
# ==============================================================================

extends Node
class_name CyberwareManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal implant_installed(implant_data: Dictionary)
signal implant_removed(implant_id: String)
signal humanity_changed(humanity_type: String, old_value: float, new_value: float)
signal hidden_cost_revealed(implant_id: String, cost: Dictionary)
signal surgery_required(implant_data: Dictionary, surgery_type: String)
signal npc_reaction_to_augments(npc: Node3D, reaction: String)
signal cyberware_malfunction(implant_id: String, malfunction_type: String)

# ==============================================================================
# ENUMS
# ==============================================================================

enum ImplantSlot {
	NEURAL,       ## Cerveau
	EYES,         ## Yeux
	EARS,         ## Oreilles
	ARMS,         ## Bras
	LEGS,         ## Jambes
	TORSO,        ## Torse
	SKIN,         ## Peau
	HEART,        ## Cœur
	SPINE         ## Colonne vertébrale
}

enum SurgeryType {
	CLINIC,       ## Clinique légale
	BACK_ALLEY,   ## Chirurgien illégal
	BLACK_MARKET, ## Marché noir
	SELF_INSTALL  ## Auto-installation (risqué)
}

enum HumanityType {
	SOCIAL,       ## Capacité à interagir humainement
	COGNITIVE,    ## Stabilité mentale
	CORPOREAL     ## Connexion au corps physique
}

# ==============================================================================
# BASE DE DONNÉES D'IMPLANTS
# ==============================================================================

const IMPLANT_DATABASE: Dictionary = {
	# ============ NEURAL ============
	"reflex_booster": {
		"name": "Booster de Réflexes",
		"slot": ImplantSlot.NEURAL,
		"benefits": {
			"reflex_bonus": 15,
			"initiative_bonus": 10
		},
		"visible_cost": {
			"credits": 5000,
			"surgery": SurgeryType.CLINIC
		},
		"hidden_costs": {
			"humanity_cognitive": -5,
			"side_effect": "Parfois, tu agis avant de penser"
		},
		"surgery_risk": 0.05
	},
	"memory_chip": {
		"name": "Puce Mémorielle",
		"slot": ImplantSlot.NEURAL,
		"benefits": {
			"memory_perfect": true,
			"language_download": true
		},
		"visible_cost": {
			"credits": 8000,
			"surgery": SurgeryType.CLINIC
		},
		"hidden_costs": {
			"humanity_cognitive": -10,
			"side_effect": "Parfois, des souvenirs qui ne sont pas les tiens",
			"corpo_tracking": true
		},
		"surgery_risk": 0.1
	},
	
	# ============ EYES ============
	"cyber_eye_basic": {
		"name": "Œil Cybernétique Basique",
		"slot": ImplantSlot.EYES,
		"benefits": {
			"zoom": 2.0,
			"low_light_vision": true
		},
		"visible_cost": {
			"credits": 3000,
			"surgery": SurgeryType.CLINIC
		},
		"hidden_costs": {
			"humanity_social": -3,
			"side_effect": "Regard froid, inhumain"
		},
		"surgery_risk": 0.02
	},
	"military_optics": {
		"name": "Optiques Militaires",
		"slot": ImplantSlot.EYES,
		"benefits": {
			"zoom": 5.0,
			"thermal_vision": true,
			"target_tracking": true,
			"accuracy_bonus": 20
		},
		"visible_cost": {
			"credits": 15000,
			"surgery": SurgeryType.BLACK_MARKET
		},
		"hidden_costs": {
			"humanity_social": -15,
			"humanity_cognitive": -5,
			"side_effect": "Dialogues modifiés. Certains PNJ te craignent ou te détestent",
			"npc_fear_chance": 0.3
		},
		"surgery_risk": 0.08
	},
	
	# ============ ARMS ============
	"cyber_arm_strength": {
		"name": "Bras Cybernétique Force",
		"slot": ImplantSlot.ARMS,
		"benefits": {
			"strength_bonus": 25,
			"melee_damage_bonus": 30
		},
		"visible_cost": {
			"credits": 7000,
			"surgery": SurgeryType.CLINIC
		},
		"hidden_costs": {
			"humanity_corporeal": -8,
			"side_effect": "Difficulté à doser la force. Poignées de main... problématiques"
		},
		"surgery_risk": 0.05
	},
	"mantis_blades": {
		"name": "Lames Mantis",
		"slot": ImplantSlot.ARMS,
		"benefits": {
			"hidden_weapon": true,
			"melee_damage": 50,
			"armor_pierce": 20
		},
		"visible_cost": {
			"credits": 20000,
			"surgery": SurgeryType.BLACK_MARKET
		},
		"hidden_costs": {
			"humanity_social": -20,
			"humanity_corporeal": -10,
			"side_effect": "Impossible de cacher ce que tu es. Les gens voient le prédateur",
			"npc_fear_chance": 0.5,
			"police_alert_level": 2
		},
		"surgery_risk": 0.12
	},
	
	# ============ HEART ============
	"synthetic_heart": {
		"name": "Cœur Synthétique",
		"slot": ImplantSlot.HEART,
		"benefits": {
			"stamina_bonus": 50,
			"health_regen": 2,
			"poison_immunity": true
		},
		"visible_cost": {
			"credits": 25000,
			"surgery": SurgeryType.CLINIC
		},
		"hidden_costs": {
			"humanity_corporeal": -20,
			"subscription_required": true,
			"subscription_cost": 500,
			"side_effect": "Tu n'as plus de battements de cœur. Le silence intérieur est... perturbant"
		},
		"surgery_risk": 0.15
	},
	
	# ============ SKIN ============
	"subdermal_armor": {
		"name": "Armure Sous-dermique",
		"slot": ImplantSlot.SKIN,
		"benefits": {
			"armor_bonus": 15,
			"damage_reduction": 10
		},
		"visible_cost": {
			"credits": 10000,
			"surgery": SurgeryType.CLINIC
		},
		"hidden_costs": {
			"humanity_corporeal": -5,
			"humanity_social": -5,
			"side_effect": "Ta peau a une texture... différente. Les contacts physiques révèlent l'artifice"
		},
		"surgery_risk": 0.03
	}
}

# ==============================================================================
# VARIABLES
# ==============================================================================

## Implants installés par slot
var installed_implants: Dictionary = {}

## Humanité fragmentée (0-100 chacune)
var humanity: Dictionary = {
	"social": 100.0,
	"cognitive": 100.0,
	"corporeal": 100.0
}

## Abonnements actifs (implant_id -> cost)
var active_subscriptions: Dictionary = {}

## Coûts cachés révélés
var revealed_hidden_costs: Array[String] = []

## Mauvaises réactions NPC enregistrées
var _npc_fear_list: Array[String] = []

# ==============================================================================
# INSTALLATION D'IMPLANTS
# ==============================================================================

func can_install_implant(implant_id: String, surgery_type: SurgeryType) -> Dictionary:
	"""Vérifie si un implant peut être installé."""
	if not IMPLANT_DATABASE.has(implant_id):
		return {"can_install": false, "reason": "Implant inconnu"}
	
	var implant: Dictionary = IMPLANT_DATABASE[implant_id]
	var slot: int = implant.slot
	
	# Vérifier si le slot est libre
	if installed_implants.has(slot):
		return {
			"can_install": false, 
			"reason": "Slot %s déjà occupé" % ImplantSlot.keys()[slot],
			"current_implant": installed_implants[slot].id
		}
	
	# Vérifier le type de chirurgie requis
	var required_surgery: int = implant.visible_cost.surgery
	if surgery_type < required_surgery:
		return {
			"can_install": false,
			"reason": "Nécessite au minimum: %s" % SurgeryType.keys()[required_surgery]
		}
	
	return {"can_install": true, "risk": _calculate_surgery_risk(implant, surgery_type)}


func install_implant(implant_id: String, surgery_type: SurgeryType) -> Dictionary:
	"""Installe un implant."""
	var check := can_install_implant(implant_id, surgery_type)
	if not check.can_install:
		return {"success": false, "reason": check.reason}
	
	var implant: Dictionary = IMPLANT_DATABASE[implant_id]
	var slot: int = implant.slot
	
	# Vérifier le risque chirurgical
	var risk: float = check.risk
	var surgery_failed := randf() < risk
	
	if surgery_failed:
		return _handle_surgery_failure(implant_id, surgery_type)
	
	# Installation réussie
	var installed := {
		"id": implant_id,
		"name": implant.name,
		"slot": slot,
		"benefits": implant.benefits.duplicate(),
		"install_time": Time.get_ticks_msec(),
		"hidden_costs_active": false
	}
	
	installed_implants[slot] = installed
	
	# Appliquer les coûts visibles en humanité
	_apply_hidden_humanity_costs(implant)
	
	# Vérifier abonnement
	if implant.hidden_costs.has("subscription_required"):
		active_subscriptions[implant_id] = implant.hidden_costs.subscription_cost
	
	implant_installed.emit(installed)
	
	return {
		"success": true,
		"implant": installed,
		"benefits": implant.benefits,
		"warning": "Des effets secondaires peuvent se manifester avec le temps..."
	}


func _calculate_surgery_risk(implant: Dictionary, surgery_type: SurgeryType) -> float:
	"""Calcule le risque de chirurgie."""
	var base_risk: float = implant.surgery_risk
	
	match surgery_type:
		SurgeryType.CLINIC:
			return base_risk * 0.5
		SurgeryType.BACK_ALLEY:
			return base_risk * 1.5
		SurgeryType.BLACK_MARKET:
			return base_risk * 1.2
		SurgeryType.SELF_INSTALL:
			return base_risk * 3.0
	
	return base_risk


func _handle_surgery_failure(implant_id: String, surgery_type: SurgeryType) -> Dictionary:
	"""Gère un échec de chirurgie."""
	var damage := randi_range(20, 50)
	var complications := []
	
	if surgery_type == SurgeryType.SELF_INSTALL:
		damage *= 2
		complications.append("infection_risk")
	
	return {
		"success": false,
		"reason": "Échec chirurgical",
		"damage": damage,
		"complications": complications,
		"message": "L'opération a échoué. Tu perds %d points de vie." % damage
	}


# ==============================================================================
# RETRAIT D'IMPLANTS
# ==============================================================================

func remove_implant(slot: int, surgery_type: SurgeryType) -> Dictionary:
	"""Retire un implant."""
	if not installed_implants.has(slot):
		return {"success": false, "reason": "Aucun implant dans ce slot"}
	
	var implant := installed_implants[slot]
	var implant_data: Dictionary = IMPLANT_DATABASE.get(implant.id, {})
	
	# Risque de retrait
	var risk: float = implant_data.get("surgery_risk", 0.1) * 0.5
	risk = _calculate_surgery_risk(implant_data, surgery_type) if not implant_data.is_empty() else risk
	
	if randf() < risk:
		return {
			"success": false,
			"reason": "Complications lors du retrait",
			"damage": randi_range(10, 30)
		}
	
	# Retrait réussi
	installed_implants.erase(slot)
	active_subscriptions.erase(implant.id)
	
	# Récupérer un peu d'humanité
	_recover_humanity(implant_data)
	
	implant_removed.emit(implant.id)
	
	return {
		"success": true,
		"removed": implant.id,
		"message": "Implant retiré avec succès"
	}


# ==============================================================================
# HUMANITÉ FRAGMENTÉE
# ==============================================================================

func _apply_hidden_humanity_costs(implant: Dictionary) -> void:
	"""Applique les coûts cachés en humanité."""
	var hidden: Dictionary = implant.hidden_costs
	
	for key in hidden.keys():
		if key.begins_with("humanity_"):
			var humanity_type: String = key.replace("humanity_", "")
			var cost: float = hidden[key]
			_modify_humanity(humanity_type, cost)


func _modify_humanity(humanity_type: String, delta: float) -> void:
	"""Modifie un type d'humanité."""
	if not humanity.has(humanity_type):
		return
	
	var old_value: float = humanity[humanity_type]
	humanity[humanity_type] = clampf(old_value + delta, 0.0, 100.0)
	var new_value: float = humanity[humanity_type]
	
	if old_value != new_value:
		humanity_changed.emit(humanity_type, old_value, new_value)


func _recover_humanity(implant_data: Dictionary) -> void:
	"""Récupère partiellement l'humanité après retrait."""
	var hidden: Dictionary = implant_data.get("hidden_costs", {})
	
	for key in hidden.keys():
		if key.begins_with("humanity_"):
			var humanity_type: String = key.replace("humanity_", "")
			var cost: float = hidden[key]
			# Récupérer 50% de ce qui a été perdu
			_modify_humanity(humanity_type, -cost * 0.5)


func get_humanity_average() -> float:
	"""Retourne la moyenne d'humanité."""
	return (humanity.social + humanity.cognitive + humanity.corporeal) / 3.0


func get_humanity_status() -> Dictionary:
	"""Retourne le statut d'humanité détaillé."""
	return {
		"social": humanity.social,
		"cognitive": humanity.cognitive,
		"corporeal": humanity.corporeal,
		"average": get_humanity_average(),
		"description": _get_humanity_description()
	}


func _get_humanity_description() -> String:
	"""Génère une description basée sur l'humanité."""
	var desc := []
	
	if humanity.social > 70:
		desc.append("socialement adapté")
	elif humanity.social < 30:
		desc.append("isolé et craint")
	
	if humanity.cognitive > 70:
		desc.append("mentalement stable")
	elif humanity.cognitive < 30:
		desc.append("instable et imprévisible")
	
	if humanity.corporeal > 70:
		desc.append("encore humain")
	elif humanity.corporeal < 30:
		desc.append("plus machine qu'homme")
	
	if desc.is_empty():
		return "en équilibre précaire"
	
	return ", ".join(desc)


# ==============================================================================
# RÉVÉLATION DES COÛTS CACHÉS
# ==============================================================================

func reveal_hidden_cost(implant_id: String) -> void:
	"""Révèle un coût caché d'un implant."""
	if implant_id in revealed_hidden_costs:
		return
	
	if not IMPLANT_DATABASE.has(implant_id):
		return
	
	var implant: Dictionary = IMPLANT_DATABASE[implant_id]
	var hidden: Dictionary = implant.hidden_costs
	
	revealed_hidden_costs.append(implant_id)
	hidden_cost_revealed.emit(implant_id, hidden)


func check_hidden_effects() -> Array[Dictionary]:
	"""Vérifie et déclenche les effets cachés."""
	var triggered := []
	
	for slot in installed_implants.keys():
		var implant: Dictionary = installed_implants[slot]
		var data: Dictionary = IMPLANT_DATABASE.get(implant.id, {})
		var hidden: Dictionary = data.get("hidden_costs", {})
		
		# Chance de révéler si non révélé
		if implant.id not in revealed_hidden_costs:
			if randf() < 0.1:  # 10% chance par check
				reveal_hidden_cost(implant.id)
				triggered.append({
					"implant": implant.id,
					"effect": hidden.get("side_effect", "Effet secondaire inattendu")
				})
	
	return triggered


# ==============================================================================
# RÉACTIONS DES PNJ
# ==============================================================================

func check_npc_reaction(npc: Node3D) -> Dictionary:
	"""Vérifie la réaction d'un PNJ aux augmentations."""
	var total_fear_chance := 0.0
	var visible_augments := 0
	
	for slot in installed_implants.keys():
		var implant: Dictionary = installed_implants[slot]
		var data: Dictionary = IMPLANT_DATABASE.get(implant.id, {})
		var hidden: Dictionary = data.get("hidden_costs", {})
		
		if hidden.has("npc_fear_chance"):
			total_fear_chance += hidden.npc_fear_chance
		
		# Les implants visibles comptent
		if slot in [ImplantSlot.EYES, ImplantSlot.ARMS, ImplantSlot.SKIN]:
			visible_augments += 1
	
	var reaction := "neutral"
	
	if randf() < total_fear_chance:
		reaction = "fear"
	elif visible_augments >= 3:
		reaction = "distrust"
	elif humanity.social < 30:
		reaction = "hostility"
	
	if reaction != "neutral":
		npc_reaction_to_augments.emit(npc, reaction)
	
	return {
		"reaction": reaction,
		"fear_chance": total_fear_chance,
		"visible_augments": visible_augments
	}


# ==============================================================================
# ABONNEMENTS
# ==============================================================================

func process_subscriptions() -> Dictionary:
	"""Traite les abonnements mensuels."""
	var total_cost := 0
	var unpaid := []
	
	for implant_id in active_subscriptions.keys():
		var cost: int = active_subscriptions[implant_id]
		total_cost += cost
	
	return {
		"total_cost": total_cost,
		"subscriptions": active_subscriptions.keys(),
		"message": "Coût mensuel des implants: %d crédits" % total_cost
	}


func fail_subscription(implant_id: String) -> Dictionary:
	"""Échec de paiement d'abonnement."""
	# Trouver le slot
	for slot in installed_implants.keys():
		if installed_implants[slot].id == implant_id:
			# L'implant commence à dysfonctionner
			cyberware_malfunction.emit(implant_id, "subscription_lapse")
			return {
				"implant": implant_id,
				"consequence": "L'implant fonctionne mal. Les collecteurs arrivent bientôt."
			}
	
	return {}


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_installed_implants() -> Dictionary:
	"""Retourne les implants installés."""
	return installed_implants


func get_implant_in_slot(slot: int) -> Dictionary:
	"""Retourne l'implant dans un slot."""
	return installed_implants.get(slot, {})


func get_total_augment_level() -> int:
	"""Retourne le niveau total d'augmentation (0-100)."""
	return mini(100, installed_implants.size() * 15)


func get_available_implants() -> Array[Dictionary]:
	"""Retourne la liste des implants disponibles."""
	var available: Array[Dictionary] = []
	for id in IMPLANT_DATABASE.keys():
		var implant: Dictionary = IMPLANT_DATABASE[id].duplicate()
		implant["id"] = id
		implant["can_install"] = can_install_implant(id, SurgeryType.CLINIC).can_install
		available.append(implant)
	return available


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"installed_count": installed_implants.size(),
		"augment_level": get_total_augment_level(),
		"humanity": humanity.duplicate(),
		"humanity_average": get_humanity_average(),
		"subscriptions_cost": process_subscriptions().total_cost,
		"revealed_costs": revealed_hidden_costs.size()
	}
