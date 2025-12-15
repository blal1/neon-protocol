# ==============================================================================
# ScenarioJasmin.gd - "Tu ne sauves pas le monde"
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# PNJ centrale: manipulatrice, idéaliste, dangereuse.
# Le jeu te permet RÉELLEMENT de la tuer.
# Le monde change. Certaines quêtes disparaissent. D'autres empirent.
# ==============================================================================

extends Node3D
class_name ScenarioJasmin

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal jasmin_encountered()
signal jasmin_mission_offered(mission: Dictionary)
signal jasmin_trust_changed(old_level: int, new_level: int)
signal jasmin_killed()
signal jasmin_betrayed()
signal jasmin_allied()
signal world_state_changed(changes: Array)
signal quest_line_locked(quest_ids: Array)
signal quest_line_unlocked(quest_ids: Array)

# ==============================================================================
# ENUMS
# ==============================================================================

enum JasminState {
	UNKNOWN,          ## Pas encore rencontrée
	MET,              ## Premier contact
	WORKING_TOGETHER, ## Alliés temporaires
	TRUSTED,          ## Confiance établie
	BETRAYED,         ## Trahie mais vivante
	ENEMY,            ## Ennemie déclarée
	DEAD              ## Tuée (permanent)
}

enum Outcome {
	NONE,
	ALLY,             ## Alliée de confiance
	USED,             ## Utilisée puis abandonnée
	KILLED,           ## Tuée par le joueur
	KILLED_BY_OTHERS  ## Morte à cause du joueur
}

# ==============================================================================
# DONNÉES DU PERSONNAGE
# ==============================================================================

const JASMIN_DATA: Dictionary = {
	"name": "Jasmin Reyes",
	"alias": "Signal",
	"age": 28,
	"faction": "cryptopirates",
	"occupation": "Information Broker / Révolutionnaire",
	"description": "Manipulatrice, idéaliste, dangereuse. Elle croit changer le monde.",
	
	"personality": {
		"manipulative": 0.8,
		"idealistic": 0.9,
		"dangerous": 0.7,
		"charismatic": 0.9
	},
	
	"skills": {
		"hacking": 85,
		"persuasion": 90,
		"combat": 50,
		"intelligence": 95
	},
	
	"goals": [
		"Exposer les crimes des corporations",
		"Libérer l'information",
		"Créer une révolution"
	],
	
	"secrets": [
		"A sacrifié des innocents pour ses missions",
		"Son 'idéalisme' cache une soif de pouvoir",
		"Utilise les gens comme des outils"
	]
}

# ==============================================================================
# QUÊTES AFFECTÉES PAR SA MORT
# ==============================================================================

const QUESTS_LOCKED_IF_DEAD: Array[String] = [
	"truth_broadcast_finale",
	"corpo_takedown_insider",
	"resistance_network_expansion",
	"underground_news_network",
	"jasmin_personal_revelation"
]

const QUESTS_UNLOCKED_IF_DEAD: Array[String] = [
	"power_vacuum_gang_war",
	"leaderless_resistance_chaos",
	"corpo_crackdown_unchecked",
	"jasmin_replacement_cult"
]

const QUESTS_WORSE_IF_DEAD: Dictionary = {
	"slum_protection": {
		"normal_difficulty": 2,
		"dead_difficulty": 4,
		"reason": "Sans Jasmin, personne ne coordonne la résistance"
	},
	"info_broker_network": {
		"normal_difficulty": 3,
		"dead_difficulty": 5,
		"reason": "Son réseau s'effondre, les infos sont plus dures à obtenir"
	}
}

# ==============================================================================
# VARIABLES
# ==============================================================================

var state: JasminState = JasminState.UNKNOWN
var trust_level: int = 0  # -100 à +100
var _outcome: Outcome = Outcome.NONE
var _missions_completed: Array[String] = []
var _jasmin_npc: Node3D = null
var _is_killable: bool = true
var _player: Node3D = null

# Dialogue alteré selon les actions
var _dialogue_modifiers: Dictionary = {}

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_spawn_jasmin()


func _spawn_jasmin() -> void:
	"""Génère Jasmin."""
	_jasmin_npc = Node3D.new()
	_jasmin_npc.name = "Jasmin_Reyes"
	_jasmin_npc.set_meta("npc_name", JASMIN_DATA.name)
	_jasmin_npc.set_meta("npc_type", "central_character")
	_jasmin_npc.set_meta("is_killable", true)
	_jasmin_npc.set_meta("faction", JASMIN_DATA.faction)
	add_child(_jasmin_npc)


# ==============================================================================
# PREMIER CONTACT
# ==============================================================================

func meet_jasmin(player: Node3D) -> Dictionary:
	"""Premier contact avec Jasmin."""
	if state != JasminState.UNKNOWN:
		return {"error": "Déjà rencontrée"}
	
	_player = player
	state = JasminState.MET
	
	jasmin_encountered.emit()
	
	_jasmin_speaks("Tu as l'air de quelqu'un qui cherche des réponses. Moi, je cherche des gens prêts à agir.")
	
	return {
		"npc": JASMIN_DATA.name,
		"first_impression": "Charismatique mais tu sens qu'elle évalue chaque mot que tu dis.",
		"trust_level": trust_level,
		"warning": "Quelque chose dans ses yeux suggère qu'elle est prête à tout."
	}


func _jasmin_speaks(text: String) -> void:
	"""Jasmin parle."""
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Jasmin dit: " + text)


# ==============================================================================
# MISSIONS & CONFIANCE
# ==============================================================================

func get_available_mission() -> Dictionary:
	"""Retourne une mission de Jasmin."""
	if state == JasminState.DEAD:
		return {"error": "Jasmin est morte"}
	
	if state == JasminState.ENEMY:
		return {"error": "Jasmin est ton ennemie"}
	
	var mission := _generate_jasmin_mission()
	jasmin_mission_offered.emit(mission)
	return mission


func _generate_jasmin_mission() -> Dictionary:
	"""Génère une mission selon le niveau de confiance."""
	if trust_level < 20:
		return {
			"id": "jasmin_test_1",
			"name": "Preuve de Loyauté",
			"description": "Jasmin veut voir si tu es digne de confiance. Vol de données simple.",
			"type": "test",
			"trust_reward": 15,
			"manipulation_hint": "Elle t'observe plus que nécessaire..."
		}
	elif trust_level < 50:
		return {
			"id": "jasmin_network",
			"name": "Étendre le Réseau",
			"description": "Place des relais pour son réseau d'information pirate.",
			"type": "expansion",
			"trust_reward": 20,
			"moral_choice": true,
			"manipulation_hint": "Tu commences à voir comment elle utilise les gens."
		}
	else:
		return {
			"id": "jasmin_revelation",
			"name": "La Grande Révélation",
			"description": "L'opération finale pour exposer les crimes corpo à la ville entière.",
			"type": "finale",
			"trust_reward": 30,
			"warning": "Elle est prête à sacrifier beaucoup de gens pour ça. Toi y compris?",
			"can_betray_jasmin": true
		}


func complete_jasmin_mission(mission_id: String, success: bool) -> Dictionary:
	"""Complète une mission de Jasmin."""
	if not success:
		_modify_trust(-15)
		return {"success": false, "trust_change": -15}
	
	_missions_completed.append(mission_id)
	
	var trust_gain := 15
	if "finale" in mission_id:
		trust_gain = 30
		state = JasminState.TRUSTED
	elif state == JasminState.MET:
		state = JasminState.WORKING_TOGETHER
	
	_modify_trust(trust_gain)
	
	return {
		"success": true,
		"trust_change": trust_gain,
		"state": JasminState.keys()[state],
		"jasmin_response": _get_completion_response(mission_id)
	}


func _get_completion_response(mission_id: String) -> String:
	"""Réponse de Jasmin selon la mission."""
	if "finale" in mission_id:
		return "Tu as prouvé que tu es plus qu'un mercenaire. Tu es un allié."
	elif trust_level > 30:
		return "Bien joué. Tu deviens quelqu'un sur qui je peux compter."
	else:
		return "Pas mal. On verra si tu tiens sur la durée."


func _modify_trust(delta: int) -> void:
	"""Modifie le niveau de confiance."""
	var old_level := trust_level
	trust_level = clampi(trust_level + delta, -100, 100)
	
	if old_level != trust_level:
		jasmin_trust_changed.emit(old_level, trust_level)


# ==============================================================================
# TUER JASMIN
# ==============================================================================

func can_kill_jasmin() -> bool:
	"""Vérifie si Jasmin peut être tuée."""
	return state != JasminState.DEAD and _is_killable


func attempt_kill_jasmin(method: String = "combat") -> Dictionary:
	"""Tente de tuer Jasmin."""
	if not can_kill_jasmin():
		return {"error": "Impossible de tuer Jasmin"}
	
	# Jasmin peut se défendre
	var success_chance := 0.7  # 70% de base
	
	if method == "stealth":
		success_chance = 0.9
	elif method == "betrayal":
		success_chance = 0.95  # Confiance exploitée
	elif trust_level > 50:
		success_chance = 0.5  # Elle se méfie moins, mais est plus préparée
	
	# Dialogue de confrontation
	if method != "stealth":
		_jasmin_speaks("Tu crois vraiment pouvoir m'arrêter? Tout ce que j'ai fait, c'était pour—")
	
	var success := randf() < success_chance
	
	if success:
		return _kill_jasmin(method)
	else:
		return _jasmin_escapes()


func _kill_jasmin(method: String) -> Dictionary:
	"""Jasmin est tuée."""
	state = JasminState.DEAD
	_outcome = Outcome.KILLED
	
	jasmin_killed.emit()
	
	# Appliquer les changements au monde
	var world_changes := _apply_death_world_changes()
	
	# Animation de mort
	if _jasmin_npc:
		var tween := create_tween()
		tween.tween_property(_jasmin_npc, "modulate:a", 0.0, 2.0)
		tween.tween_callback(_jasmin_npc.queue_free)
	
	return {
		"success": true,
		"outcome": "killed",
		"method": method,
		"message": "Jasmin est morte. Le monde ne sera plus jamais le même.",
		"world_changes": world_changes,
		"quests_locked": QUESTS_LOCKED_IF_DEAD,
		"quests_unlocked": QUESTS_UNLOCKED_IF_DEAD,
		"warning": "Certaines histoires se ferment à jamais. D'autres s'ouvrent."
	}


func _jasmin_escapes() -> Dictionary:
	"""Jasmin s'échappe."""
	state = JasminState.ENEMY
	_modify_trust(-100)
	
	_jasmin_speaks("Tu as fait ton choix. Maintenant tu es mon ennemi.")
	
	return {
		"success": false,
		"outcome": "escaped",
		"message": "Jasmin t'échappe. Elle sait ce que tu as tenté.",
		"new_state": "enemy",
		"consequence": "Elle travaillera contre toi désormais"
	}


func _apply_death_world_changes() -> Array[Dictionary]:
	"""Applique les changements au monde après sa mort."""
	var changes: Array[Dictionary] = []
	
	# Verrouiller les quêtes
	for quest_id in QUESTS_LOCKED_IF_DEAD:
		changes.append({
			"type": "quest_locked",
			"quest_id": quest_id,
			"reason": "Jasmin était nécessaire pour cette quête"
		})
	
	# Débloquer de nouvelles quêtes
	for quest_id in QUESTS_UNLOCKED_IF_DEAD:
		changes.append({
			"type": "quest_unlocked",
			"quest_id": quest_id,
			"reason": "Sa mort crée de nouvelles situations"
		})
	
	# Quêtes devenues plus difficiles
	for quest_id in QUESTS_WORSE_IF_DEAD.keys():
		var data: Dictionary = QUESTS_WORSE_IF_DEAD[quest_id]
		changes.append({
			"type": "quest_difficulty_increased",
			"quest_id": quest_id,
			"new_difficulty": data.dead_difficulty,
			"reason": data.reason
		})
	
	# Impact réputation
	if FactionManager:
		FactionManager.add_reputation("cryptopirates", -50)
		FactionManager.add_reputation("corporations", 30)
	
	changes.append({
		"type": "faction_impact",
		"cryptopirates": -50,
		"corporations": 30
	})
	
	# Le réseau de résistance s'effondre
	changes.append({
		"type": "world_state",
		"resistance_network": "collapsed",
		"info_availability": -0.3
	})
	
	world_state_changed.emit(changes)
	quest_line_locked.emit(QUESTS_LOCKED_IF_DEAD)
	quest_line_unlocked.emit(QUESTS_UNLOCKED_IF_DEAD)
	
	return changes


# ==============================================================================
# TRAHISON (ALTERNATIVE)
# ==============================================================================

func betray_jasmin_to_corpos() -> Dictionary:
	"""Trahit Jasmin aux corporations."""
	if state == JasminState.DEAD:
		return {"error": "Jasmin est déjà morte"}
	
	state = JasminState.BETRAYED
	_outcome = Outcome.USED
	
	jasmin_betrayed.emit()
	
	# Récompense corpo
	var reward := 5000
	if _player and _player.has_method("add_credits"):
		_player.add_credits(reward)
	
	# Réputation
	if FactionManager:
		FactionManager.add_reputation("corporations", 40)
		FactionManager.add_reputation("cryptopirates", -60)
	
	_jasmin_speaks("Tu... après tout ce qu'on a traversé? Je te faisais confiance!")
	
	# Elle sera capturée mais pourrait s'échapper plus tard
	return {
		"outcome": "betrayed",
		"message": "Tu vends Jasmin aux corpos. %d crédits." % reward,
		"credits_earned": reward,
		"reputation_change": {"corporations": 40, "cryptopirates": -60},
		"future": "Elle pourrait s'échapper et chercher vengeance..."
	}


# ==============================================================================
# DEVENIR ALLIÉ
# ==============================================================================

func become_true_ally() -> Dictionary:
	"""Devient un véritable allié de Jasmin."""
	if trust_level < 70:
		return {"error": "Confiance insuffisante"}
	
	state = JasminState.TRUSTED
	_outcome = Outcome.ALLY
	
	jasmin_allied.emit()
	
	_jasmin_speaks("Tu es le premier à qui je peux vraiment faire confiance. Ensemble, on peut tout changer.")
	
	# Débloquer contenu spécial
	return {
		"outcome": "allied",
		"message": "Tu es maintenant un allié de confiance de Jasmin.",
		"unlocked_content": [
			"jasmin_personal_story",
			"resistance_inner_circle",
			"final_revelation_quest"
		],
		"warning": "Mais rappelez-vous: elle reste dangereuse et prête à tout."
	}


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_state() -> JasminState:
	"""Retourne l'état de Jasmin."""
	return state


func get_outcome() -> Outcome:
	"""Retourne l'issue."""
	return _outcome


func is_alive() -> bool:
	"""Vérifie si Jasmin est vivante."""
	return state != JasminState.DEAD


func is_enemy() -> bool:
	"""Vérifie si Jasmin est ennemie."""
	return state in [JasminState.ENEMY, JasminState.BETRAYED]


func get_trust_level() -> int:
	"""Retourne le niveau de confiance."""
	return trust_level


func get_scenario_summary() -> Dictionary:
	"""Retourne un résumé du scénario."""
	return {
		"name": JASMIN_DATA.name,
		"alias": JASMIN_DATA.alias,
		"state": JasminState.keys()[state],
		"trust_level": trust_level,
		"outcome": Outcome.keys()[_outcome] if _outcome != Outcome.NONE else "pending",
		"missions_completed": _missions_completed.size(),
		"is_alive": is_alive()
	}
