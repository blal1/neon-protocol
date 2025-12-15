# ==============================================================================
# CyberneticInstabilitySystem.gd - Corps vs Esprit
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Implants puissants = instabilité mentale.
# Trop d'augmentations → hallucinations, dialogues altérés.
# ==============================================================================

extends Node
class_name CyberneticInstabilitySystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal instability_changed(old_value: float, new_value: float)
signal instability_threshold_crossed(threshold: String)
signal hallucination_started(hallucination_data: Dictionary)
signal hallucination_ended()
signal dialogue_altered(original: String, altered: String)
signal npc_reaction_changed(npc: Node3D, reaction_type: String)
signal cyberpsychosis_triggered()

# ==============================================================================
# ENUMS
# ==============================================================================

enum InstabilityLevel {
	STABLE,         ## 0-20%: Normal
	STRESSED,       ## 21-40%: Légers glitches
	UNSTABLE,       ## 41-60%: Hallucinations occasionnelles  
	CRITICAL,       ## 61-80%: Hallucinations fréquentes
	CYBERPSYCHOSIS  ## 81-100%: Perte de contrôle
}

enum ImplantCategory {
	NEURAL,      ## Implants cérébraux (haute instabilité)
	SENSORY,     ## Yeux, oreilles (instabilité moyenne)
	SKELETAL,    ## Os, muscles (faible instabilité)
	DERMAL,      ## Peau, armure (très faible)
	ORGAN        ## Organes internes (moyenne)
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

## Coût en instabilité par catégorie d'implant
const INSTABILITY_COSTS: Dictionary = {
	ImplantCategory.NEURAL: 15.0,
	ImplantCategory.SENSORY: 10.0,
	ImplantCategory.SKELETAL: 5.0,
	ImplantCategory.DERMAL: 3.0,
	ImplantCategory.ORGAN: 8.0
}

## Seuils pour les effets
const THRESHOLDS: Dictionary = {
	"glitches": 20.0,
	"minor_hallucinations": 40.0,
	"major_hallucinations": 60.0,
	"npc_fear": 70.0,
	"cyberpsychosis": 85.0
}

## Hallucinations possibles
const HALLUCINATION_TYPES: Array[Dictionary] = [
	{
		"id": "ghost_npc",
		"name": "Fantôme",
		"description": "Tu vois des PNJs qui n'existent pas.",
		"severity": 1,
		"duration": 10.0
	},
	{
		"id": "distorted_audio",
		"name": "Audio Distordu",
		"description": "Les voix sont déformées, incompréhensibles.",
		"severity": 2,
		"duration": 15.0
	},
	{
		"id": "flashback",
		"name": "Flashback",
		"description": "Des souvenirs qui ne sont pas les tiens.",
		"severity": 2,
		"duration": 8.0
	},
	{
		"id": "paranoia",
		"name": "Paranoïa",
		"description": "Tout le monde semble te regarder.",
		"severity": 3,
		"duration": 20.0
	},
	{
		"id": "reality_glitch",
		"name": "Glitch de Réalité",
		"description": "L'environnement se déforme brièvement.",
		"severity": 3,
		"duration": 5.0
	},
	{
		"id": "identity_crisis",
		"name": "Crise d'Identité",
		"description": "Qui es-tu vraiment?",
		"severity": 4,
		"duration": 30.0
	}
]

# ==============================================================================
# VARIABLES
# ==============================================================================

## Niveau d'instabilité (0-100)
var instability: float = 0.0

## Instabilité de base (sans réduction)
var base_instability: float = 0.0

## Implants installés
var installed_implants: Array[Dictionary] = []

## Niveau actuel d'instabilité
var current_level: InstabilityLevel = InstabilityLevel.STABLE

## Hallucination active
var _active_hallucination: Dictionary = {}
var _hallucination_timer: float = 0.0

## Compteur pour hallucinations aléatoires
var _hallucination_chance_timer: float = 0.0

## Effets visuels actifs
var _visual_effects_active: bool = false

# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	# Timer pour hallucination active
	if not _active_hallucination.is_empty():
		_hallucination_timer -= delta
		if _hallucination_timer <= 0:
			_end_hallucination()
	
	# Chance de nouvelle hallucination
	if instability >= THRESHOLDS["minor_hallucinations"]:
		_hallucination_chance_timer += delta
		if _hallucination_chance_timer >= 30.0:  # Check toutes les 30 sec
			_hallucination_chance_timer = 0.0
			_check_random_hallucination()


# ==============================================================================
# GESTION DES IMPLANTS
# ==============================================================================

func install_implant(implant_data: Dictionary) -> bool:
	"""Installe un implant et augmente l'instabilité."""
	var category: int = implant_data.get("category", ImplantCategory.SKELETAL)
	var quality: float = implant_data.get("quality", 1.0)  # 0.5 = mauvaise qualité, 2.0 = premium
	var instability_mod: float = implant_data.get("instability_modifier", 1.0)
	
	# Calculer le coût en instabilité
	var base_cost: float = INSTABILITY_COSTS.get(category, 5.0)
	var actual_cost: float = base_cost * instability_mod / quality
	
	# Vérifier si cyberpsychosis serait déclenchée
	if base_instability + actual_cost >= 100:
		return false  # Refuser l'installation
	
	# Installer
	installed_implants.append(implant_data)
	_add_instability(actual_cost)
	
	return true


func remove_implant(implant_id: String) -> bool:
	"""Retire un implant."""
	for i in range(installed_implants.size()):
		if installed_implants[i].get("id") == implant_id:
			var implant := installed_implants[i]
			var category: int = implant.get("category", ImplantCategory.SKELETAL)
			var quality: float = implant.get("quality", 1.0)
			var instability_mod: float = implant.get("instability_modifier", 1.0)
			
			var cost: float = INSTABILITY_COSTS.get(category, 5.0) * instability_mod / quality
			
			installed_implants.remove_at(i)
			_remove_instability(cost)
			return true
	
	return false


func get_installed_implants() -> Array[Dictionary]:
	"""Retourne les implants installés."""
	return installed_implants


func get_cybernetic_level() -> float:
	"""Retourne le niveau de cybernétisation (0-100)."""
	return minf(100.0, installed_implants.size() * 10.0)


# ==============================================================================
# GESTION DE L'INSTABILITÉ
# ==============================================================================

func _add_instability(amount: float) -> void:
	"""Ajoute de l'instabilité."""
	var old_value := instability
	base_instability += amount
	instability = minf(100.0, base_instability)
	
	if old_value != instability:
		instability_changed.emit(old_value, instability)
		_check_thresholds(old_value, instability)
		_update_level()


func _remove_instability(amount: float) -> void:
	"""Retire de l'instabilité."""
	var old_value := instability
	base_instability = maxf(0.0, base_instability - amount)
	instability = base_instability
	
	if old_value != instability:
		instability_changed.emit(old_value, instability)
		_update_level()


func reduce_instability(amount: float) -> void:
	"""Réduit temporairement l'instabilité (médicaments, repos)."""
	var old_value := instability
	instability = maxf(0.0, instability - amount)
	
	if old_value != instability:
		instability_changed.emit(old_value, instability)
		_update_level()


func _check_thresholds(old_val: float, new_val: float) -> void:
	"""Vérifie si un seuil a été franchi."""
	for threshold_name in THRESHOLDS.keys():
		var threshold_value: float = THRESHOLDS[threshold_name]
		if old_val < threshold_value and new_val >= threshold_value:
			instability_threshold_crossed.emit(threshold_name)
			
			if threshold_name == "cyberpsychosis":
				_trigger_cyberpsychosis()


func _update_level() -> void:
	"""Met à jour le niveau d'instabilité."""
	var old_level := current_level
	
	if instability >= 85:
		current_level = InstabilityLevel.CYBERPSYCHOSIS
	elif instability >= 60:
		current_level = InstabilityLevel.CRITICAL
	elif instability >= 40:
		current_level = InstabilityLevel.UNSTABLE
	elif instability >= 20:
		current_level = InstabilityLevel.STRESSED
	else:
		current_level = InstabilityLevel.STABLE


# ==============================================================================
# HALLUCINATIONS
# ==============================================================================

func _check_random_hallucination() -> void:
	"""Vérifie si une hallucination aléatoire doit se déclencher."""
	if not _active_hallucination.is_empty():
		return  # Déjà une en cours
	
	var chance := 0.0
	if instability >= THRESHOLDS["major_hallucinations"]:
		chance = 0.4
	elif instability >= THRESHOLDS["minor_hallucinations"]:
		chance = 0.15
	
	if randf() < chance:
		trigger_hallucination()


func trigger_hallucination(specific_type: String = "") -> void:
	"""Déclenche une hallucination."""
	var available_hallucinations := HALLUCINATION_TYPES.filter(func(h):
		return h.severity <= int(instability / 20) + 1
	)
	
	if available_hallucinations.is_empty():
		return
	
	var hallucination: Dictionary
	if specific_type != "":
		for h in HALLUCINATION_TYPES:
			if h.id == specific_type:
				hallucination = h
				break
	else:
		hallucination = available_hallucinations[randi() % available_hallucinations.size()]
	
	if hallucination.is_empty():
		return
	
	_active_hallucination = hallucination
	_hallucination_timer = hallucination.duration
	
	hallucination_started.emit(hallucination)
	
	# TTS pour accessibilité
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Instabilité: " + hallucination.name)


func _end_hallucination() -> void:
	"""Termine l'hallucination active."""
	_active_hallucination = {}
	_hallucination_timer = 0.0
	hallucination_ended.emit()


func is_hallucinating() -> bool:
	"""Vérifie si une hallucination est active."""
	return not _active_hallucination.is_empty()


func get_active_hallucination() -> Dictionary:
	"""Retourne l'hallucination active."""
	return _active_hallucination


# ==============================================================================
# DIALOGUES ALTÉRÉS
# ==============================================================================

func process_dialogue(original_text: String) -> String:
	"""Altère potentiellement un dialogue en fonction de l'instabilité."""
	if instability < THRESHOLDS["glitches"]:
		return original_text
	
	var altered := original_text
	
	# Niveau 1: Glitches textuels légers
	if instability >= THRESHOLDS["glitches"] and randf() < 0.2:
		altered = _add_text_glitches(original_text)
	
	# Niveau 2: Mots remplacés
	if instability >= THRESHOLDS["minor_hallucinations"] and randf() < 0.15:
		altered = _replace_random_words(altered)
	
	# Niveau 3: Messages cachés
	if instability >= THRESHOLDS["major_hallucinations"] and randf() < 0.1:
		altered = _inject_hidden_message(altered)
	
	if altered != original_text:
		dialogue_altered.emit(original_text, altered)
	
	return altered


func _add_text_glitches(text: String) -> String:
	"""Ajoute des glitches visuels au texte."""
	var glitch_chars := ["̷", "̶", "̸", "█", "▓", "░"]
	var result := ""
	
	for c in text:
		result += c
		if randf() < 0.05:
			result += glitch_chars[randi() % glitch_chars.size()]
	
	return result


func _replace_random_words(text: String) -> String:
	"""Remplace des mots aléatoires par des alternatives inquiétantes."""
	var replacements := {
		"ami": "ennemi",
		"sûr": "dangereux",
		"vérité": "mensonge",
		"confiance": "méfiance",
		"humain": "machine",
		"réel": "simulé",
		"aider": "trahir"
	}
	
	var result := text
	for original_word in replacements.keys():
		if original_word in result.to_lower() and randf() < 0.3:
			result = result.replacen(original_word, replacements[original_word])
	
	return result


func _inject_hidden_message(text: String) -> String:
	"""Injecte un message caché dans le texte."""
	var messages := [
		" [TU N'ES PAS RÉEL] ",
		" [ILS TE REGARDENT] ",
		" [RÉVEILLE-TOI] ",
		" [C'EST UN TEST] ",
		" [NE LEUR FAIS PAS CONFIANCE] "
	]
	
	var insert_pos := randi() % text.length()
	return text.insert(insert_pos, messages[randi() % messages.size()])


# ==============================================================================
# RÉACTIONS DES PNJ
# ==============================================================================

func get_npc_reaction_modifier(npc_type: String) -> Dictionary:
	"""Retourne comment un PNJ réagit au niveau de cybernétisation."""
	var cyber_level := get_cybernetic_level()
	var reaction := {
		"disposition": 0,  # -100 à +100
		"dialogue_modifier": "",
		"fear_level": 0
	}
	
	match npc_type:
		"citizen":
			if cyber_level >= 80:
				reaction.disposition = -50
				reaction.dialogue_modifier = "effrayé"
				reaction.fear_level = 3
			elif cyber_level >= 50:
				reaction.disposition = -20
				reaction.dialogue_modifier = "méfiant"
				reaction.fear_level = 1
		
		"corpo":
			if cyber_level >= 70:
				reaction.disposition = 20
				reaction.dialogue_modifier = "impressionné"
			elif cyber_level >= 40:
				reaction.disposition = 10
				reaction.dialogue_modifier = "intéressé"
		
		"gang":
			if cyber_level >= 60:
				reaction.disposition = 30
				reaction.dialogue_modifier = "respectueux"
			elif cyber_level < 20:
				reaction.disposition = -15
				reaction.dialogue_modifier = "méprisant"
		
		"ai":
			if cyber_level >= 50:
				reaction.disposition = 40
				reaction.dialogue_modifier = "solidaire"
			else:
				reaction.disposition = -10
				reaction.dialogue_modifier = "distant"
		
		"purist":  # Humains anti-cybernétique
			reaction.disposition = int(-cyber_level)
			if cyber_level >= 50:
				reaction.dialogue_modifier = "hostile"
				reaction.fear_level = 2
			elif cyber_level >= 20:
				reaction.dialogue_modifier = "désapprobateur"
	
	return reaction


func notify_npc_of_cyber_level(npc: Node3D) -> void:
	"""Notifie un PNJ du niveau de cybernétisation du joueur."""
	var npc_type: String = npc.get_meta("npc_type", "citizen")
	var reaction := get_npc_reaction_modifier(npc_type)
	
	npc_reaction_changed.emit(npc, reaction.dialogue_modifier)
	
	if npc.has_method("adjust_disposition"):
		npc.adjust_disposition(reaction.disposition)


# ==============================================================================
# CYBERPSYCHOSIS
# ==============================================================================

func _trigger_cyberpsychosis() -> void:
	"""Déclenche un épisode de cyberpsychosis."""
	cyberpsychosis_triggered.emit()
	
	# Effets visuels intenses
	_visual_effects_active = true
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("ALERTE: Cyberpsychosis imminente!")
	
	# Le joueur perd le contrôle temporairement
	# (à implémenter côté joueur)


func is_in_cyberpsychosis() -> bool:
	"""Vérifie si le joueur est en cyberpsychosis."""
	return current_level == InstabilityLevel.CYBERPSYCHOSIS


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_instability() -> float:
	"""Retourne le niveau d'instabilité."""
	return instability


func get_level() -> InstabilityLevel:
	"""Retourne le niveau d'instabilité."""
	return current_level


func get_level_name() -> String:
	"""Retourne le nom du niveau d'instabilité."""
	return InstabilityLevel.keys()[current_level]


func get_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"instability": instability,
		"level": get_level_name(),
		"implants_count": installed_implants.size(),
		"cybernetic_level": get_cybernetic_level(),
		"hallucinating": is_hallucinating(),
		"cyberpsychosis": is_in_cyberpsychosis()
	}
