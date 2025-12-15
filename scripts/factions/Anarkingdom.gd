# ==============================================================================
# Anarkingdom.gd - Faction Anarchiste Paradoxale
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Anarchistes devenus quasi-monarchie. Roi élu par la violence.
# Gameplay: quêtes absurdes, choix contradictoires, implosion possible.
# ==============================================================================

extends Node
class_name Anarkingdom

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal king_challenged(challenger: Node3D)
signal king_defeated(old_king: String, new_king: String)
signal absurd_event_triggered(event_data: Dictionary)
signal contradiction_exploited(contradiction_id: String)
signal faction_imploding()

# ==============================================================================
# CONFIGURATION
# ==============================================================================

const FACTION_ID := "anarkingdom"

## Niveaux d'absurdité pour les quêtes (1-5)
enum AbsurdityLevel {
	MILD = 1,       ## Légèrement absurde
	MODERATE = 2,   ## Modérément absurde
	HIGH = 3,       ## Très absurde
	EXTREME = 4,    ## Extrêmement absurde
	MAXIMUM = 5     ## Logique inversée totale
}

# ==============================================================================
# DONNÉES
# ==============================================================================

## Le roi actuel
var current_king := {
	"name": "Rex le Nihiliste",
	"reign_start": 0,
	"kills_to_throne": 12,
	"contradictions_spoken": 47,
	"popularity": 60  # 0-100
}

## Liste des contradictions connues (exploitables)
var known_contradictions: Array[Dictionary] = [
	{
		"id": "hierarchy_in_anarchy",
		"description": "Un roi dans une anarchie?",
		"exploitation_level": 0,  # 0-100
		"discovered": false
	},
	{
		"id": "mandatory_freedom",
		"description": "Liberté obligatoire pour tous",
		"exploitation_level": 0,
		"discovered": false
	},
	{
		"id": "tax_without_state",
		"description": "Taxe 'volontaire' collectée par la force",
		"exploitation_level": 0,
		"discovered": false
	},
	{
		"id": "authority_against_authority",
		"description": "Autorité du roi qui hait l'autorité",
		"exploitation_level": 0,
		"discovered": false
	},
	{
		"id": "democratic_violence",
		"description": "Élections par combat à mort",
		"exploitation_level": 0,
		"discovered": false
	}
]

## Événements absurdes possibles
var absurd_events: Array[Dictionary] = [
	{
		"id": "mandatory_protest",
		"title": "Manifestation Obligatoire",
		"description": "Tu DOIS protester contre l'obligation de protester.",
		"absurdity": AbsurdityLevel.EXTREME
	},
	{
		"id": "freedom_tax",
		"title": "Impôt de Liberté",
		"description": "Paie pour le droit de ne pas payer.",
		"absurdity": AbsurdityLevel.HIGH
	},
	{
		"id": "election_day",
		"title": "Jour d'Élection",
		"description": "Vote avec tes poings. Le dernier debout gagne.",
		"absurdity": AbsurdityLevel.MAXIMUM
	},
	{
		"id": "anti_rule_rule",
		"title": "La Règle Anti-Règles",
		"description": "Nouvelle règle: il est interdit d'avoir des règles.",
		"absurdity": AbsurdityLevel.EXTREME
	}
]

## Compteur d'instabilité (mène à l'implosion)
var instability: float = 0.0  # 0-100
var implosion_threshold: float = 100.0

# ==============================================================================
# GÉNÉRATION DE QUÊTES
# ==============================================================================

func generate_absurd_quest(player_reputation: int) -> Dictionary:
	"""Génère une quête absurde basée sur la réputation."""
	var absurdity := _calculate_absurdity(player_reputation)
	
	var quest_templates := [
		{
			"title_template": "Mission: {action} {target} {reason}",
			"actions": ["Détruire", "Protéger", "Voler", "Libérer", "Taxer"],
			"targets": ["le symbole de liberté", "la statue du roi", "les tracts anarchistes", "le trésor du peuple"],
			"reasons": ["pour la liberté", "parce que c'est obligatoire", "au nom du chaos", "sans raison valable"]
		}
	]
	
	var template := quest_templates[0]
	var action: String = template.actions[randi() % template.actions.size()]
	var target: String = template.targets[randi() % template.targets.size()]
	var reason: String = template.reasons[randi() % template.reasons.size()]
	
	return {
		"id": "anark_random_%d" % randi(),
		"title": "%s %s" % [action, target],
		"description": "Tu dois %s %s %s." % [action.to_lower(), target, reason],
		"absurdity_level": absurdity,
		"reward_reputation": absurdity * 5,
		"reward_credits": absurdity * 200,
		"contradictory_objective": randf() < 0.3  # 30% chance d'objectif contradictoire
	}


func _calculate_absurdity(reputation: int) -> int:
	"""Plus la réputation est haute, plus les quêtes sont absurdes."""
	if reputation < 0:
		return AbsurdityLevel.MILD
	elif reputation < 25:
		return AbsurdityLevel.MODERATE
	elif reputation < 50:
		return AbsurdityLevel.HIGH
	elif reputation < 75:
		return AbsurdityLevel.EXTREME
	else:
		return AbsurdityLevel.MAXIMUM


# ==============================================================================
# SYSTÈME DU ROI
# ==============================================================================

func challenge_king(challenger: Node3D) -> Dictionary:
	"""Défie le roi actuel."""
	king_challenged.emit(challenger)
	
	return {
		"event": "king_challenge",
		"current_king": current_king.name,
		"king_strength": current_king.kills_to_throne * 10,
		"arena": "Throne of Bones",
		"rules": "Aucune. C'est l'anarchie après tout."
	}


func king_defeated_by(new_king_name: String, kills: int) -> void:
	"""Le roi a été vaincu."""
	var old_name: String = current_king.name
	
	current_king = {
		"name": new_king_name,
		"reign_start": Time.get_ticks_msec(),
		"kills_to_throne": kills,
		"contradictions_spoken": 0,
		"popularity": 80
	}
	
	king_defeated.emit(old_name, new_king_name)
	
	# Réduire l'instabilité (nouveau roi = reset partiel)
	instability = maxf(0, instability - 20)


func get_king_info() -> Dictionary:
	"""Retourne les infos du roi actuel."""
	return current_king.duplicate()


# ==============================================================================
# EXPLOITATION DES CONTRADICTIONS
# ==============================================================================

func discover_contradiction(contradiction_id: String) -> bool:
	"""Découvre une contradiction exploitable."""
	for contradiction in known_contradictions:
		if contradiction.id == contradiction_id:
			if not contradiction.discovered:
				contradiction.discovered = true
				return true
	return false


func exploit_contradiction(contradiction_id: String, exploitation_amount: int) -> bool:
	"""Exploite une contradiction pour augmenter l'instabilité."""
	for contradiction in known_contradictions:
		if contradiction.id == contradiction_id and contradiction.discovered:
			contradiction.exploitation_level = mini(100, contradiction.exploitation_level + exploitation_amount)
			
			# Augmenter l'instabilité
			var instability_gain := exploitation_amount * 0.5
			_add_instability(instability_gain)
			
			contradiction_exploited.emit(contradiction_id)
			return true
	return false


func get_discovered_contradictions() -> Array[Dictionary]:
	"""Retourne les contradictions découvertes."""
	var result: Array[Dictionary] = []
	for c in known_contradictions:
		if c.discovered:
			result.append(c)
	return result


func get_total_exploitation() -> float:
	"""Retourne le niveau total d'exploitation des contradictions."""
	var total := 0.0
	for c in known_contradictions:
		total += c.exploitation_level
	return total / (known_contradictions.size() * 100.0) * 100.0


# ==============================================================================
# INSTABILITÉ & IMPLOSION
# ==============================================================================

func _add_instability(amount: float) -> void:
	"""Ajoute de l'instabilité à la faction."""
	var old_instability := instability
	instability = minf(implosion_threshold, instability + amount)
	
	# Vérifier l'implosion
	if instability >= implosion_threshold and old_instability < implosion_threshold:
		_trigger_implosion()


func _trigger_implosion() -> void:
	"""Déclenche l'implosion de la faction."""
	faction_imploding.emit()
	
	# Notifier le FactionManager
	if FactionManager:
		FactionManager.destroy_faction(FACTION_ID)


func get_instability() -> float:
	"""Retourne le niveau d'instabilité (0-100)."""
	return instability


func is_near_implosion() -> bool:
	"""Vérifie si la faction est proche de l'implosion."""
	return instability >= implosion_threshold * 0.8


# ==============================================================================
# ÉVÉNEMENTS ABSURDES
# ==============================================================================

func trigger_random_absurd_event() -> Dictionary:
	"""Déclenche un événement absurde aléatoire."""
	var event := absurd_events[randi() % absurd_events.size()]
	absurd_event_triggered.emit(event)
	return event


func get_absurd_dialogue() -> String:
	"""Génère un dialogue absurde typique de la faction."""
	var dialogues := [
		"La liberté est obligatoire! Tu DOIS être libre!",
		"Longue vie au roi! Mort à toute autorité!",
		"Nous refusons les règles! C'est notre règle principale!",
		"Paie ta taxe volontaire ou on te libère... de ta vie.",
		"Le chaos a un ordre! Et l'ordre, c'est le roi!",
		"Tu votes pour qui aux élections? Moi je vote avec mon couteau.",
		"L'anarchie, c'est comme la démocratie, mais avec plus de sang.",
		"Personne ne nous dit quoi faire! Sauf le roi. Et les anciens. Et moi."
	]
	return dialogues[randi() % dialogues.size()]


# ==============================================================================
# POLITIQUE CONTRADICTOIRE
# ==============================================================================

func get_political_stance(topic: String) -> Dictionary:
	"""Retourne la position politique (toujours contradictoire)."""
	match topic:
		"authority":
			return {
				"official": "Nous rejetons toute autorité!",
				"reality": "Sauf celle du roi et du conseil.",
				"contradiction_level": 5
			}
		"freedom":
			return {
				"official": "Liberté totale pour tous!",
				"reality": "Ceux qui refusent seront punis.",
				"contradiction_level": 5
			}
		"taxation":
			return {
				"official": "Pas de taxes! L'État est un vol!",
				"reality": "Contribution volontaire obligatoire de 30%.",
				"contradiction_level": 4
			}
		"democracy":
			return {
				"official": "Le peuple décide!",
				"reality": "Le dernier survivant décide.",
				"contradiction_level": 5
			}
		_:
			return {
				"official": "Nous sommes contre ça!",
				"reality": "Mais nous le faisons quand même.",
				"contradiction_level": 3
			}


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_faction_summary() -> Dictionary:
	"""Retourne un résumé de la faction."""
	return {
		"id": FACTION_ID,
		"name": "Anarkingdom",
		"current_king": current_king.name,
		"instability": instability,
		"near_implosion": is_near_implosion(),
		"contradictions_discovered": get_discovered_contradictions().size(),
		"exploitation_level": get_total_exploitation()
	}
