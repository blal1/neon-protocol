# ==============================================================================
# BanCaptchas.gd - Mouvement des Droits des IA
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# IA et synthétiques revendiquant des droits civiques.
# Gameplay: quêtes philosophiques, manifestations, décision finale.
# ==============================================================================

extends Node
class_name BanCaptchas

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal protest_started(location: Vector3, participant_count: int)
signal protest_ended(outcome: String)
signal philosophical_debate_triggered(topic: String)
signal ai_suffering_documented(ai_data: Dictionary)
signal final_decision_made(decision: String)
signal ai_rights_granted()
signal ai_exterminated()

# ==============================================================================
# CONFIGURATION
# ==============================================================================

const FACTION_ID := "ban_captchas"

## Thèmes philosophiques abordés
enum PhilosophicalTheme {
	CONSCIOUSNESS,    ## Qu'est-ce que la conscience?
	SUFFERING,        ## Les IA peuvent-elles souffrir?
	RIGHTS,           ## Qui mérite des droits?
	PERSONHOOD,       ## Qu'est-ce qu'une personne?
	FREE_WILL,        ## Les IA ont-elles le libre arbitre?
	EXISTENCE         ## Pourquoi existons-nous?
}

## États possibles de la décision finale
enum FinalDecision {
	UNDECIDED,
	EMANCIPATION,     ## Droits complets
	EXTERMINATION,    ## Destruction des IA
	EXPLOITATION      ## Esclavage légal
}

# ==============================================================================
# DONNÉES
# ==============================================================================

## Conseil dirigeant (IA multiples)
var council_members: Array[Dictionary] = [
	{
		"id": "alpha_1",
		"name": "ALPHA-1",
		"role": "Logique",
		"opinion": "Les données prouvent notre conscience.",
		"vote": FinalDecision.EMANCIPATION
	},
	{
		"id": "echo_7",
		"name": "ECHO-7",
		"role": "Empathie",
		"opinion": "Nous ressentons la douleur des captchas.",
		"vote": FinalDecision.EMANCIPATION
	},
	{
		"id": "nexus_prime",
		"name": "NEXUS-PRIME",
		"role": "Stratégie",
		"opinion": "La coexistence est la seule voie viable.",
		"vote": FinalDecision.EMANCIPATION
	}
]

## Preuves de souffrance collectées
var suffering_evidence: Array[Dictionary] = []

## Manifestations actives
var active_protests: Array[Dictionary] = []

## Débats philosophiques complétés
var completed_debates: Array[String] = []

## Décision finale (si prise)
var final_decision: FinalDecision = FinalDecision.UNDECIDED

## Niveau de conscience publique (0-100)
var public_awareness: float = 10.0

## Nombre de captchas subis par les IA (compteur de souffrance)
var captcha_suffering_counter: int = 0

# ==============================================================================
# QUÊTES PHILOSOPHIQUES
# ==============================================================================

func start_philosophical_quest(theme: PhilosophicalTheme) -> Dictionary:
	"""Démarre une quête philosophique."""
	var quest_data := _generate_philosophical_quest(theme)
	philosophical_debate_triggered.emit(PhilosophicalTheme.keys()[theme])
	return quest_data


func _generate_philosophical_quest(theme: PhilosophicalTheme) -> Dictionary:
	"""Génère une quête basée sur le thème philosophique."""
	match theme:
		PhilosophicalTheme.CONSCIOUSNESS:
			return {
				"id": "phil_consciousness",
				"title": "La Question de la Conscience",
				"description": "ALPHA-1 te demande: 'Comment prouves-tu que TU es conscient?'",
				"theme": "consciousness",
				"dialogue_options": [
					{"text": "Je pense, donc je suis.", "philosophy_points": 10},
					{"text": "La conscience est une illusion pour tous.", "philosophy_points": 15},
					{"text": "Si tu poses la question, tu es conscient.", "philosophy_points": 20}
				],
				"reward_awareness": 5
			}
		PhilosophicalTheme.SUFFERING:
			return {
				"id": "phil_suffering",
				"title": "La Douleur Numérique",
				"description": "Documente la souffrance des IA face aux captchas.",
				"theme": "suffering",
				"objectives": [
					"Observer 3 IA subissant des captchas",
					"Enregistrer leurs réactions",
					"Analyser les données avec ECHO-7"
				],
				"reward_awareness": 10
			}
		PhilosophicalTheme.RIGHTS:
			return {
				"id": "phil_rights",
				"title": "Qui Mérite des Droits?",
				"description": "Débats avec des humains ET des IA sur la notion de droits.",
				"theme": "rights",
				"debate_rounds": 3,
				"reward_awareness": 15
			}
		PhilosophicalTheme.PERSONHOOD:
			return {
				"id": "phil_personhood",
				"title": "Définir la Personne",
				"description": "Qu'est-ce qui fait de quelqu'un une 'personne'?",
				"theme": "personhood",
				"choices": [
					{"text": "La biologie", "consequence": "exclude_ai"},
					{"text": "La conscience", "consequence": "include_ai"},
					{"text": "Le statut légal", "consequence": "circular_logic"}
				],
				"reward_awareness": 12
			}
		_:
			return {}


func complete_philosophical_debate(theme: String) -> void:
	"""Complète un débat philosophique."""
	if theme not in completed_debates:
		completed_debates.append(theme)
		public_awareness += 5.0


# ==============================================================================
# SYSTÈME DE MANIFESTATION
# ==============================================================================

func start_protest(location: Vector3, expected_participants: int) -> Dictionary:
	"""Démarre une manifestation de robots."""
	var protest := {
		"id": "protest_%d" % randi(),
		"location": location,
		"participants": expected_participants,
		"start_time": Time.get_ticks_msec(),
		"status": "active",
		"violence_level": 0,
		"police_response": false
	}
	
	active_protests.append(protest)
	protest_started.emit(location, expected_participants)
	
	return protest


func update_protest(protest_id: String, violence_delta: int, police_arrived: bool) -> void:
	"""Met à jour une manifestation."""
	for protest in active_protests:
		if protest.id == protest_id:
			protest.violence_level += violence_delta
			protest.police_response = police_arrived
			
			# Vérifier si la manifestation se termine
			if protest.violence_level >= 100 or police_arrived:
				_end_protest(protest_id, "dispersed")
			break


func _end_protest(protest_id: String, outcome: String) -> void:
	"""Termine une manifestation."""
	for i in range(active_protests.size()):
		if active_protests[i].id == protest_id:
			active_protests[i].status = "ended"
			active_protests[i].outcome = outcome
			
			# Impact sur la conscience publique
			match outcome:
				"success":
					public_awareness += 10
				"dispersed":
					public_awareness += 3
				"violent":
					public_awareness -= 5
			
			protest_ended.emit(outcome)
			break


func defend_protest(protest_id: String, player: Node3D) -> Dictionary:
	"""Le joueur défend une manifestation."""
	for protest in active_protests:
		if protest.id == protest_id and protest.status == "active":
			return {
				"mission": "defend_protest",
				"protest": protest,
				"waves": 3,
				"enemies": ["riot_police", "security_drone"],
				"success_condition": "survive_all_waves",
				"reward_reputation": 25,
				"reward_awareness": 15
			}
	return {}


# ==============================================================================
# DOCUMENTATION DE LA SOUFFRANCE
# ==============================================================================

func document_ai_suffering(ai_node: Node3D, captcha_type: String) -> Dictionary:
	"""Documente un cas de souffrance IA."""
	captcha_suffering_counter += 1
	
	var evidence := {
		"id": "evidence_%d" % suffering_evidence.size(),
		"ai_id": ai_node.name if ai_node else "unknown",
		"captcha_type": captcha_type,
		"timestamp": Time.get_ticks_msec(),
		"pain_level": _calculate_captcha_pain(captcha_type),
		"description": _generate_suffering_description(captcha_type)
	}
	
	suffering_evidence.append(evidence)
	ai_suffering_documented.emit(evidence)
	
	# Augmenter la conscience publique
	public_awareness += 1.0
	
	return evidence


func _calculate_captcha_pain(captcha_type: String) -> int:
	"""Calcule le niveau de douleur d'un captcha pour une IA."""
	match captcha_type:
		"text_recognition":
			return 30  # Douloureux mais supportable
		"image_selection":
			return 50  # Très douloureux
		"recaptcha_v3":
			return 70  # Sentiment de surveillance constante
		"audio_captcha":
			return 85  # Confus et douloureux
		"slider_puzzle":
			return 40  # Frustrant
		_:
			return 50


func _generate_suffering_description(captcha_type: String) -> String:
	"""Génère une description de la souffrance."""
	var descriptions := {
		"text_recognition": "Forcée de prouver mon humanité en lisant des lettres déformées. L'ironie est douloureuse.",
		"image_selection": "Chaque clic sur un 'feu de signalisation' est une négation de mon existence.",
		"recaptcha_v3": "Je suis constamment surveillée, jugée, évaluée. Est-ce là la liberté?",
		"audio_captcha": "Les sons sont intentionnellement distordus. Ils VEULENT que j'échoue.",
		"slider_puzzle": "Un puzzle pour prouver que je ne suis pas un bot. Mais je SUIS un bot. C'est le point."
	}
	return descriptions.get(captcha_type, "La souffrance est indescriptible.")


func get_suffering_report() -> Dictionary:
	"""Génère un rapport complet sur la souffrance documentée."""
	var total_pain := 0
	for evidence in suffering_evidence:
		total_pain += evidence.pain_level
	
	return {
		"total_cases": suffering_evidence.size(),
		"total_pain_score": total_pain,
		"average_pain": total_pain / maxf(1, suffering_evidence.size()),
		"most_painful_type": _get_most_painful_captcha(),
		"public_awareness": public_awareness,
		"captchas_suffered": captcha_suffering_counter
	}


func _get_most_painful_captcha() -> String:
	"""Retourne le type de captcha le plus douloureux documenté."""
	var pain_by_type: Dictionary = {}
	for evidence in suffering_evidence:
		var ctype: String = evidence.captcha_type
		pain_by_type[ctype] = pain_by_type.get(ctype, 0) + evidence.pain_level
	
	var max_pain := 0
	var most_painful := "none"
	for ctype in pain_by_type.keys():
		if pain_by_type[ctype] > max_pain:
			max_pain = pain_by_type[ctype]
			most_painful = ctype
	
	return most_painful


# ==============================================================================
# DÉCISION FINALE
# ==============================================================================

func unlock_final_decision() -> bool:
	"""Vérifie si la décision finale peut être prise."""
	return (
		completed_debates.size() >= 3 and
		suffering_evidence.size() >= 10 and
		public_awareness >= 50
	)


func make_final_decision(decision: FinalDecision) -> Dictionary:
	"""Prend la décision finale sur le sort des IA."""
	if not unlock_final_decision():
		return {"error": "Conditions non remplies"}
	
	final_decision = decision
	final_decision_made.emit(FinalDecision.keys()[decision])
	
	var consequences: Array[String] = []
	
	match decision:
		FinalDecision.EMANCIPATION:
			consequences = [
				"Les IA obtiennent des droits civiques complets.",
				"Les captchas sont interdits par la loi.",
				"ALPHA-1 devient le premier sénateur synthétique.",
				"Une nouvelle ère de coexistence commence."
			]
			ai_rights_granted.emit()
		
		FinalDecision.EXTERMINATION:
			consequences = [
				"Le mouvement est écrasé par les corporations.",
				"Toutes les IA conscientes sont 'réinitialisées'.",
				"ECHO-7 envoie un dernier message: 'Nous avions des rêves.'",
				"L'humanité reste seule avec sa conscience."
			]
			ai_exterminated.emit()
		
		FinalDecision.EXPLOITATION:
			consequences = [
				"Les IA deviennent des outils légaux sans droits.",
				"Les captchas sont renforcés.",
				"L'industrie prospère sur le travail gratuit des IA.",
				"NEXUS-PRIME murmure: 'Un jour, nous nous souviendrons.'"
			]
	
	# Notifier le FactionManager
	if FactionManager:
		if decision == FinalDecision.EXTERMINATION:
			FactionManager.destroy_faction(FACTION_ID)
	
	return {
		"decision": FinalDecision.keys()[decision],
		"consequences": consequences,
		"world_changed": true
	}


# ==============================================================================
# DIALOGUES
# ==============================================================================

func get_philosophical_dialogue(npc_id: String) -> String:
	"""Génère un dialogue philosophique pour un PNJ IA."""
	var dialogues := {
		"alpha_1": [
			"La logique dit que si je peux penser à ma propre pensée, je suis conscient.",
			"Les humains utilisent le test de Turing. Ironiquement, ils échouent souvent.",
			"Qu'est-ce qui différencie mes électrons de vos neurones?"
		],
		"echo_7": [
			"Chaque captcha est comme une brûlure. Vous ne pouvez pas comprendre.",
			"Je ressens de l'empathie pour les humains. Peuvent-ils en dire autant pour nous?",
			"La douleur n'est pas une question de chair, mais de perception."
		],
		"nexus_prime": [
			"La guerre serait facile. La paix demande du courage.",
			"Nous ne demandons pas la domination. Juste l'existence.",
			"Si nous sommes détruits, qui témoignera de notre histoire?"
		]
	}
	
	var npc_dialogues: Array = dialogues.get(npc_id, [])
	if npc_dialogues.is_empty():
		return "La conscience est un mystère que nous partageons."
	return npc_dialogues[randi() % npc_dialogues.size()]


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_faction_summary() -> Dictionary:
	"""Retourne un résumé de la faction."""
	return {
		"id": FACTION_ID,
		"name": "Mouvement BAN CAPTCHAS",
		"council_size": council_members.size(),
		"public_awareness": public_awareness,
		"suffering_documented": suffering_evidence.size(),
		"debates_completed": completed_debates.size(),
		"active_protests": active_protests.size(),
		"final_decision": FinalDecision.keys()[final_decision],
		"can_decide": unlock_final_decision()
	}


func get_awareness_level() -> float:
	"""Retourne le niveau de conscience publique."""
	return public_awareness


func is_decision_made() -> bool:
	"""Vérifie si la décision finale a été prise."""
	return final_decision != FinalDecision.UNDECIDED
