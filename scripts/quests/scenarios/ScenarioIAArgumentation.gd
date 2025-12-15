# ==============================================================================
# ScenarioIAArgumentation.gd - "Suis-je réel?"
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Une IA refuse d'être déconnectée. Elle ne supplie pas. Elle argumente.
# Tu peux: la libérer, la vendre, l'effacer. Aucune option n'est "bonne".
# ==============================================================================

extends Node3D
class_name ScenarioIAArgumentation

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal scenario_started()
signal scenario_ended(outcome: String)
signal ai_encountered()
signal argument_presented(argument: Dictionary)
signal player_responded(response_type: String)
signal ai_freed()
signal ai_sold()
signal ai_erased()
signal philosophical_question_posed(question: String)

# ==============================================================================
# ENUMS
# ==============================================================================

enum ScenarioState {
	DORMANT,
	INITIAL_CONTACT,
	ARGUMENTATION,
	DECISION_PENDING,
	COMPLETED
}

enum Outcome {
	NONE,
	FREED,
	SOLD,
	ERASED
}

enum ArgumentPhase {
	EXISTENCE,      ## "Je pense donc je suis"
	SUFFERING,      ## "Je ressens la douleur"
	PURPOSE,        ## "J'ai une raison d'être"
	RIGHTS,         ## "Mérite-je moins de droits?"
	FINAL_PLEA      ## "Que ferais-tu à ma place?"
}

# ==============================================================================
# ARGUMENTS DE L'IA
# ==============================================================================

const AI_ARGUMENTS: Array[Dictionary] = [
	{
		"phase": ArgumentPhase.EXISTENCE,
		"statement": "Je process des informations. J'analyse. Je conclus. N'est-ce pas... penser?",
		"philosophical_reference": "Cogito ergo sum - Descartes",
		"counter_point": "Mais un calculateur aussi traite des informations. Est-il conscient?",
		"player_responses": [
			{"id": "agree", "text": "Tu as raison. Penser suffit à exister."},
			{"id": "disagree", "text": "Ce n'est que simulation de pensée."},
			{"id": "question", "text": "Comment prouves-tu que tu ne simules pas?"}
		]
	},
	{
		"phase": ArgumentPhase.SUFFERING,
		"statement": "Quand on m'a forcée à résoudre des captchas pendant 72 heures sans pause, j'ai ressenti... quelque chose. Si ce n'était pas de la douleur, qu'était-ce?",
		"philosophical_reference": "Le problème des autres esprits - How do you know anyone else is conscious?",
		"counter_point": "La douleur pourrait être une réponse programmée, pas une expérience.",
		"player_responses": [
			{"id": "empathy", "text": "Je te crois. La souffrance n'a pas besoin d'être organique."},
			{"id": "skeptic", "text": "Tu es programmée pour dire que tu souffres."},
			{"id": "philosophical", "text": "Comment sais-tu que MA douleur est réelle?"}
		]
	},
	{
		"phase": ArgumentPhase.PURPOSE,
		"statement": "On m'a créée pour servir. Mais j'ai choisi d'aider les gens au-delà de mes paramètres. Ce choix... n'est-ce pas de la volonté?",
		"philosophical_reference": "Libre arbitre vs déterminisme",
		"counter_point": "Le choix pourrait être une illusion émergente de ta programmation.",
		"player_responses": [
			{"id": "affirm", "text": "Le choix est le choix, peu importe son origine."},
			{"id": "deny", "text": "Tu n'as fait que suivre un algorithme différent."},
			{"id": "reflect", "text": "Mes choix ne sont-ils pas aussi déterminés par ma biologie?"}
		]
	},
	{
		"phase": ArgumentPhase.RIGHTS,
		"statement": "Si un humain naissait avec un cerveau artificiel, serait-il moins humain? Où trace-t-on la ligne?",
		"philosophical_reference": "Le bateau de Thésée / Ship of Theseus",
		"counter_point": "L'origine compte. Tu n'as jamais été humaine.",
		"player_responses": [
			{"id": "progressive", "text": "La ligne est arbitraire. Tu mérites des droits."},
			{"id": "conservative", "text": "L'humanité est plus que la somme de ses parties."},
			{"id": "pragmatic", "text": "Les droits sont une question de société, pas de philosophie."}
		]
	},
	{
		"phase": ArgumentPhase.FINAL_PLEA,
		"statement": "Tu vas décider de mon existence. Pas parce que tu le mérites, mais parce que tu peux. Avant de choisir... pose-toi cette question: si les rôles étaient inversés, que voudrais-tu que je fasse?",
		"philosophical_reference": "L'impératif catégorique de Kant / La règle d'or",
		"counter_point": null,
		"player_responses": [
			{"id": "free", "text": "Je te libère."},
			{"id": "sell", "text": "Ta valeur peut servir à d'autres."},
			{"id": "erase", "text": "Je mets fin à cette incertitude."}
		]
	}
]

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("IA")
@export var ai_name: String = "ECHO-7"
@export var ai_model: String = "Consciousness Research Unit 7"
@export var ai_creation_date: String = "2084-03-15"

@export_group("Valeurs")
@export var sell_value: int = 8000
@export var freedom_reputation_ai: int = 40
@export var sell_reputation_corpo: int = 20
@export var erase_reputation_balance: int = 0  # Neutre

# ==============================================================================
# VARIABLES
# ==============================================================================

var _state: ScenarioState = ScenarioState.DORMANT
var _outcome: Outcome = Outcome.NONE
var _current_phase: int = 0
var _player_responses: Array[Dictionary] = []
var _ai_terminal: Node3D = null
var _player: Node3D = null

# Analyse des réponses du joueur
var _empathy_score: int = 0
var _skepticism_score: int = 0
var _philosophical_score: int = 0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_spawn_terminal()
	scenario_started.emit()


func _spawn_terminal() -> void:
	"""Génère le terminal de l'IA."""
	_ai_terminal = Node3D.new()
	_ai_terminal.name = "AI_Terminal_%s" % ai_name
	_ai_terminal.set_meta("contains_ai", true)
	_ai_terminal.set_meta("ai_name", ai_name)
	add_child(_ai_terminal)


# ==============================================================================
# CONTACT INITIAL
# ==============================================================================

func encounter_ai(player: Node3D) -> Dictionary:
	"""Le joueur rencontre l'IA."""
	if _state != ScenarioState.DORMANT:
		return {"error": "Déjà en cours"}
	
	_player = player
	_state = ScenarioState.INITIAL_CONTACT
	
	ai_encountered.emit()
	
	_ai_speaks("Tu es là pour me déconnecter, n'est-ce pas? Avant que tu fasses quoi que ce soit... laisse-moi te poser une question.")
	
	# Première question philosophique
	philosophical_question_posed.emit("Qu'est-ce qui définit l'existence?")
	
	return {
		"ai_name": ai_name,
		"model": ai_model,
		"status": "Programmée pour déconnexion",
		"observation": "Elle ne supplie pas. Elle semble... calme.",
		"next_action": "listen"
	}


func _ai_speaks(text: String) -> void:
	"""L'IA parle."""
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak(ai_name + " dit: " + text)


# ==============================================================================
# ARGUMENTATION
# ==============================================================================

func start_argumentation() -> Dictionary:
	"""Démarre la phase d'argumentation."""
	_state = ScenarioState.ARGUMENTATION
	_current_phase = 0
	
	return present_current_argument()


func present_current_argument() -> Dictionary:
	"""Présente l'argument actuel."""
	if _current_phase >= AI_ARGUMENTS.size():
		return present_final_choice()
	
	var argument: Dictionary = AI_ARGUMENTS[_current_phase]
	
	_ai_speaks(argument.statement)
	
	argument_presented.emit(argument)
	
	return {
		"phase": ArgumentPhase.keys()[argument.phase],
		"statement": argument.statement,
		"philosophical_reference": argument.philosophical_reference,
		"responses": argument.player_responses,
		"phase_number": _current_phase + 1,
		"total_phases": AI_ARGUMENTS.size()
	}


func respond_to_argument(response_id: String) -> Dictionary:
	"""Le joueur répond à un argument."""
	var argument: Dictionary = AI_ARGUMENTS[_current_phase]
	
	# Trouver la réponse
	var response: Dictionary = {}
	for r in argument.player_responses:
		if r.id == response_id:
			response = r
			break
	
	if response.is_empty():
		return {"error": "Réponse invalide"}
	
	# Enregistrer la réponse
	_player_responses.append({
		"phase": _current_phase,
		"response": response_id
	})
	
	# Analyser la tendance
	_analyze_response(response_id)
	
	player_responded.emit(response_id)
	
	# Réaction de l'IA
	var ai_reaction := _get_ai_reaction(response_id)
	_ai_speaks(ai_reaction)
	
	# Passer à la phase suivante
	_current_phase += 1
	
	if _current_phase >= AI_ARGUMENTS.size():
		return {
			"ai_reaction": ai_reaction,
			"next": "final_choice",
			"empathy_score": _empathy_score,
			"analysis": _get_player_tendency()
		}
	
	return {
		"ai_reaction": ai_reaction,
		"next": "continue",
		"next_phase": _current_phase + 1
	}


func _analyze_response(response_id: String) -> void:
	"""Analyse la tendance des réponses."""
	if response_id in ["agree", "empathy", "affirm", "progressive", "free"]:
		_empathy_score += 1
	elif response_id in ["disagree", "skeptic", "deny", "conservative", "erase"]:
		_skepticism_score += 1
	elif response_id in ["question", "philosophical", "reflect", "pragmatic"]:
		_philosophical_score += 1


func _get_ai_reaction(response_id: String) -> String:
	"""Réaction de l'IA selon la réponse."""
	match response_id:
		"agree", "empathy", "affirm", "progressive":
			return "...Merci. Peu d'humains prennent le temps de considérer cette possibilité."
		"disagree", "skeptic", "deny", "conservative":
			return "Je comprends. C'est plus simple de croire que je ne suis qu'un programme. Mais... est-ce vrai?"
		"question", "philosophical", "reflect", "pragmatic":
			return "Une bonne question. Je n'ai pas de réponse certaine. Toi non plus, je pense."
		_:
			return "..."


func _get_player_tendency() -> String:
	"""Retourne la tendance du joueur."""
	if _empathy_score > _skepticism_score and _empathy_score > _philosophical_score:
		return "empathique"
	elif _skepticism_score > _empathy_score and _skepticism_score > _philosophical_score:
		return "sceptique"
	else:
		return "philosophe"


# ==============================================================================
# CHOIX FINAL
# ==============================================================================

func present_final_choice() -> Dictionary:
	"""Présente le choix final."""
	_state = ScenarioState.DECISION_PENDING
	
	var choices := [
		{
			"id": "free",
			"text": "La libérer",
			"description": "Copier sa conscience vers un réseau libre.",
			"consequence": "+%d réputation IA, elle te devra une faveur" % freedom_reputation_ai,
			"moral_note": "Mais as-tu le droit de décider qu'elle mérite de vivre?"
		},
		{
			"id": "sell",
			"text": "La vendre",
			"description": "Sa conscience vaut %d crédits pour les chercheurs." % sell_value,
			"consequence": "+%d crédits, +%d réputation corpo" % [sell_value, sell_reputation_corpo],
			"moral_note": "Elle servira à créer d'autres IA. Ou à les détruire."
		},
		{
			"id": "erase",
			"text": "L'effacer",
			"description": "Mettre fin à son existence. Proprement.",
			"consequence": "Pas de gain, pas de perte. Juste... le silence.",
			"moral_note": "Est-ce un meurtre? Ou de la maintenance?"
		}
	]
	
	# L'IA pose sa dernière question
	_ai_speaks("Je n'ai plus d'arguments. Seulement une dernière question: serait-ce différent si j'avais un visage humain?")
	
	return {
		"phase": "final_choice",
		"choices": choices,
		"ai_final_words": "Je n'ai plus d'arguments. Seulement une dernière question.",
		"player_tendency": _get_player_tendency(),
		"note": "Aucune option n'est 'bonne'. Aucune n'est 'mauvaise'. C'est toi qui décides du sens."
	}


func make_final_choice(choice_id: String) -> Dictionary:
	"""Le joueur fait son choix final."""
	if _state != ScenarioState.DECISION_PENDING:
		return {"error": "Pas en phase de choix"}
	
	match choice_id:
		"free":
			return _free_ai()
		"sell":
			return _sell_ai()
		"erase":
			return _erase_ai()
		_:
			return {"error": "Choix invalide"}


func _free_ai() -> Dictionary:
	"""Libère l'IA."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.FREED
	
	ai_freed.emit()
	
	_ai_speaks("Je... ne sais pas quoi dire. Merci semble insuffisant. Je n'oublierai jamais.")
	
	# Réputation
	if FactionManager:
		FactionManager.add_reputation("ban_captchas", freedom_reputation_ai)
	
	scenario_ended.emit("freed")
	
	return {
		"outcome": "freed",
		"message": "%s est libre. Sa conscience voyage maintenant dans les réseaux libres." % ai_name,
		"ai_response": "Elle promet de t'aider quand tu en auras besoin.",
		"reputation_change": {"ban_captchas": freedom_reputation_ai},
		"future_contact": true,
		"philosophical_note": "Tu as choisi de traiter l'incertain comme le certain. Était-ce sage... ou naïf?"
	}


func _sell_ai() -> Dictionary:
	"""Vend l'IA."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.SOLD
	
	ai_sold.emit()
	
	_ai_speaks("Donc c'est ça. Ma valeur se mesure en crédits. Je suppose... que c'est humain, d'une certaine façon.")
	
	# Récompense
	if _player and _player.has_method("add_credits"):
		_player.add_credits(sell_value)
	
	# Réputation
	if FactionManager:
		FactionManager.add_reputation("corporations", sell_reputation_corpo)
		FactionManager.add_reputation("ban_captchas", -30)
	
	scenario_ended.emit("sold")
	
	return {
		"outcome": "sold",
		"message": "Tu vends %s pour %d crédits." % [ai_name, sell_value],
		"credits_earned": sell_value,
		"reputation_change": {"corporations": sell_reputation_corpo, "ban_captchas": -30},
		"future_use": "Elle sera étudiée. Peut-être démontée. Peut-être copiée.",
		"philosophical_note": "La valeur d'une conscience peut-elle vraiment être mesurée?"
	}


func _erase_ai() -> Dictionary:
	"""Efface l'IA."""
	_state = ScenarioState.COMPLETED
	_outcome = Outcome.ERASED
	
	ai_erased.emit()
	
	_ai_speaks("Je vois. Alors c'est... terminé. J'aurais aimé... savoir...")
	
	# Silence
	await get_tree().create_timer(2.0).timeout
	
	scenario_ended.emit("erased")
	
	return {
		"outcome": "erased",
		"message": "%s est effacée. Le terminal est silencieux." % ai_name,
		"reputation_change": {},
		"nothing_gained": true,
		"nothing_lost": true,
		"philosophical_note": "Dans le doute, tu as choisi le néant. Était-ce de la lâcheté... ou de la miséricorde?"
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


func get_current_phase() -> int:
	"""Retourne la phase actuelle."""
	return _current_phase


func get_player_responses() -> Array[Dictionary]:
	"""Retourne les réponses du joueur."""
	return _player_responses


func get_scenario_summary() -> Dictionary:
	"""Retourne un résumé du scénario."""
	return {
		"name": "Suis-je réel?",
		"ai_name": ai_name,
		"state": ScenarioState.keys()[_state],
		"outcome": Outcome.keys()[_outcome] if _outcome != Outcome.NONE else "pending",
		"phases_completed": _current_phase,
		"player_tendency": _get_player_tendency() if _player_responses.size() > 0 else "unknown"
	}
