# ==============================================================================
# SkillTreeManager.gd - Système d'arbre de talents cybernétiques
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les compétences, points de talent, et upgrades du joueur
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal skill_unlocked(skill: Skill)
signal skill_upgraded(skill: Skill, new_level: int)
signal skill_points_changed(new_total: int)
signal branch_unlocked(branch_name: String)

# ==============================================================================
# CLASSES
# ==============================================================================

class Skill:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon_path: String = ""
	var branch: String = ""  # "combat", "hacking", "stealth", "survival"
	var tier: int = 1  # 1-3, niveau dans l'arbre
	var max_level: int = 3
	var current_level: int = 0
	var cost_per_level: Array[int] = [1, 2, 3]
	var prerequisite_ids: Array[String] = []
	var effects: Array[Dictionary] = []  # [{type: "damage_bonus", value_per_level: 5}]
	
	func is_unlocked() -> bool:
		return current_level > 0
	
	func can_upgrade() -> bool:
		return current_level < max_level
	
	func get_upgrade_cost() -> int:
		if current_level >= cost_per_level.size():
			return 999
		return cost_per_level[current_level]
	
	func get_effect_value(effect_type: String) -> float:
		for effect in effects:
			if effect.get("type") == effect_type:
				return effect.get("value_per_level", 0) * current_level
		return 0.0
	
	func to_dict() -> Dictionary:
		return {"id": id, "current_level": current_level}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SAVE_PATH := "user://skills.json"
const BRANCHES := ["combat", "hacking", "stealth", "survival"]

# ==============================================================================
# VARIABLES
# ==============================================================================
var skills: Dictionary = {}  # id -> Skill
var skill_points: int = 0
var total_skill_points_earned: int = 0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système de compétences."""
	_create_skill_tree()
	_load_progress()


# ==============================================================================
# CRÉATION DE L'ARBRE DE TALENTS
# ==============================================================================

func _create_skill_tree() -> void:
	"""Crée toutes les compétences."""
	
	# === BRANCHE COMBAT ===
	_add_skill({
		"id": "combat_damage_1",
		"name": "Force Augmentée",
		"description": "+5 dégâts par niveau",
		"branch": "combat",
		"tier": 1,
		"max_level": 3,
		"effects": [{"type": "damage_bonus", "value_per_level": 5}]
	})
	
	_add_skill({
		"id": "combat_speed_1",
		"name": "Réflexes Cybernétiques",
		"description": "-10% cooldown attaque par niveau",
		"branch": "combat",
		"tier": 1,
		"max_level": 3,
		"effects": [{"type": "attack_cooldown_reduction", "value_per_level": 0.1}]
	})
	
	_add_skill({
		"id": "combat_combo_1",
		"name": "Maître du Combo",
		"description": "+1 hit maximum au combo",
		"branch": "combat",
		"tier": 2,
		"max_level": 2,
		"prerequisite_ids": ["combat_damage_1"],
		"effects": [{"type": "max_combo_bonus", "value_per_level": 1}]
	})
	
	_add_skill({
		"id": "combat_crit_1",
		"name": "Précision Mortelle",
		"description": "+10% chance de critique par niveau",
		"branch": "combat",
		"tier": 2,
		"max_level": 3,
		"prerequisite_ids": ["combat_speed_1"],
		"effects": [{"type": "crit_chance", "value_per_level": 0.1}]
	})
	
	_add_skill({
		"id": "combat_ultimate",
		"name": "Berserker Chrome",
		"description": "Double les dégâts pendant 5s après un kill",
		"branch": "combat",
		"tier": 3,
		"max_level": 1,
		"cost_per_level": [5],
		"prerequisite_ids": ["combat_combo_1", "combat_crit_1"],
		"effects": [{"type": "kill_damage_boost", "value_per_level": 1.0}]
	})
	
	# === BRANCHE HACKING ===
	_add_skill({
		"id": "hack_range_1",
		"name": "Portée Étendue",
		"description": "+2m de portée de piratage par niveau",
		"branch": "hacking",
		"tier": 1,
		"max_level": 3,
		"effects": [{"type": "hack_range_bonus", "value_per_level": 2.0}]
	})
	
	_add_skill({
		"id": "hack_speed_1",
		"name": "Processeur Overclocké",
		"description": "-15% temps de piratage par niveau",
		"branch": "hacking",
		"tier": 1,
		"max_level": 3,
		"effects": [{"type": "hack_speed_bonus", "value_per_level": 0.15}]
	})
	
	_add_skill({
		"id": "hack_turrets",
		"name": "Contrôle de Tourelles",
		"description": "Permet de pirater les tourelles ennemies",
		"branch": "hacking",
		"tier": 2,
		"max_level": 1,
		"prerequisite_ids": ["hack_range_1"],
		"effects": [{"type": "can_hack_turrets", "value_per_level": 1}]
	})
	
	_add_skill({
		"id": "hack_robots",
		"name": "Virus Neural",
		"description": "Permet de pirater les robots ennemis",
		"branch": "hacking",
		"tier": 3,
		"max_level": 1,
		"cost_per_level": [5],
		"prerequisite_ids": ["hack_turrets"],
		"effects": [{"type": "can_hack_robots", "value_per_level": 1}]
	})
	
	# === BRANCHE FURTIVITÉ ===
	_add_skill({
		"id": "stealth_speed_1",
		"name": "Pas de Fantôme",
		"description": "+10% vitesse en mode furtif par niveau",
		"branch": "stealth",
		"tier": 1,
		"max_level": 3,
		"effects": [{"type": "stealth_speed_bonus", "value_per_level": 0.1}]
	})
	
	_add_skill({
		"id": "stealth_detection_1",
		"name": "Camouflage Optique",
		"description": "-20% rayon de détection par niveau",
		"branch": "stealth",
		"tier": 1,
		"max_level": 3,
		"effects": [{"type": "detection_radius_reduction", "value_per_level": 0.2}]
	})
	
	_add_skill({
		"id": "stealth_takedown",
		"name": "Élimination Silencieuse",
		"description": "Permet les takedowns silencieux depuis derrière",
		"branch": "stealth",
		"tier": 2,
		"max_level": 1,
		"prerequisite_ids": ["stealth_speed_1"],
		"effects": [{"type": "can_stealth_takedown", "value_per_level": 1}]
	})
	
	# === BRANCHE SURVIE ===
	_add_skill({
		"id": "survival_health_1",
		"name": "Constitution Augmentée",
		"description": "+20 PV max par niveau",
		"branch": "survival",
		"tier": 1,
		"max_level": 5,
		"effects": [{"type": "max_health_bonus", "value_per_level": 20}]
	})
	
	_add_skill({
		"id": "survival_regen_1",
		"name": "Nano-Régénération",
		"description": "Régénère 1 PV/s par niveau",
		"branch": "survival",
		"tier": 1,
		"max_level": 3,
		"effects": [{"type": "health_regen", "value_per_level": 1.0}]
	})
	
	_add_skill({
		"id": "survival_armor_1",
		"name": "Plaque Dermique",
		"description": "-5% dégâts reçus par niveau",
		"branch": "survival",
		"tier": 2,
		"max_level": 3,
		"prerequisite_ids": ["survival_health_1"],
		"effects": [{"type": "damage_reduction", "value_per_level": 0.05}]
	})


func _add_skill(data: Dictionary) -> void:
	"""Ajoute une compétence."""
	var skill := Skill.new()
	skill.id = data.get("id", "")
	skill.name = data.get("name", "")
	skill.description = data.get("description", "")
	skill.icon_path = data.get("icon_path", "")
	skill.branch = data.get("branch", "combat")
	skill.tier = data.get("tier", 1)
	skill.max_level = data.get("max_level", 3)
	
	# Convertir les arrays pour éviter les erreurs de type
	var costs: Array = data.get("cost_per_level", [1, 2, 3])
	skill.cost_per_level.clear()
	for c in costs:
		skill.cost_per_level.append(int(c))
	
	var prereqs: Array = data.get("prerequisite_ids", [])
	skill.prerequisite_ids.clear()
	for p in prereqs:
		skill.prerequisite_ids.append(str(p))
	
	var fx: Array = data.get("effects", [])
	skill.effects.clear()
	for e in fx:
		skill.effects.append(e)
	
	skills[skill.id] = skill


# ==============================================================================
# DÉBLOCAGE ET UPGRADE
# ==============================================================================

func can_unlock_skill(skill_id: String) -> bool:
	"""Vérifie si une compétence peut être débloquée."""
	if not skills.has(skill_id):
		return false
	
	var skill: Skill = skills[skill_id]
	
	# Déjà au max
	if not skill.can_upgrade():
		return false
	
	# Vérifier le coût
	if skill_points < skill.get_upgrade_cost():
		return false
	
	# Vérifier les prérequis
	for prereq_id in skill.prerequisite_ids:
		if skills.has(prereq_id):
			if not skills[prereq_id].is_unlocked():
				return false
	
	return true


func unlock_skill(skill_id: String) -> bool:
	"""Débloque ou améliore une compétence."""
	if not can_unlock_skill(skill_id):
		return false
	
	var skill: Skill = skills[skill_id]
	var cost := skill.get_upgrade_cost()
	
	skill_points -= cost
	skill.current_level += 1
	
	skill_points_changed.emit(skill_points)
	
	if skill.current_level == 1:
		skill_unlocked.emit(skill)
	else:
		skill_upgraded.emit(skill, skill.current_level)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Compétence améliorée: " + skill.name + " niveau " + str(skill.current_level))
	
	_save_progress()
	return true


# ==============================================================================
# POINTS DE COMPÉTENCE
# ==============================================================================

func add_skill_points(amount: int) -> void:
	"""Ajoute des points de compétence."""
	skill_points += amount
	total_skill_points_earned += amount
	skill_points_changed.emit(skill_points)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak(str(amount) + " point" + ("s" if amount > 1 else "") + " de compétence")


func get_skill_points() -> int:
	"""Retourne les points disponibles."""
	return skill_points


# ==============================================================================
# EFFETS DES COMPÉTENCES
# ==============================================================================

func get_effect_total(effect_type: String) -> float:
	"""Calcule le total d'un type d'effet."""
	var total := 0.0
	for skill in skills.values():
		total += skill.get_effect_value(effect_type)
	return total


func has_ability(ability_name: String) -> bool:
	"""Vérifie si une capacité spéciale est débloquée."""
	# Capacités spéciales (valeur > 0 = débloqué)
	return get_effect_total(ability_name) > 0


func get_damage_bonus() -> float:
	return get_effect_total("damage_bonus")


func get_attack_cooldown_multiplier() -> float:
	return 1.0 - get_effect_total("attack_cooldown_reduction")


func get_max_health_bonus() -> float:
	return get_effect_total("max_health_bonus")


func get_damage_reduction() -> float:
	return get_effect_total("damage_reduction")


func get_crit_chance() -> float:
	return get_effect_total("crit_chance")


# ==============================================================================
# SAUVEGARDE/CHARGEMENT
# ==============================================================================

func _save_progress() -> void:
	"""Sauvegarde la progression."""
	var data := {
		"skill_points": skill_points,
		"total_earned": total_skill_points_earned,
		"skills": {}
	}
	
	for skill_id in skills:
		if skills[skill_id].current_level > 0:
			data["skills"][skill_id] = skills[skill_id].to_dict()
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _load_progress() -> void:
	"""Charge la progression."""
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.data
		skill_points = data.get("skill_points", 0)
		total_skill_points_earned = data.get("total_earned", 0)
		
		var saved_skills: Dictionary = data.get("skills", {})
		for skill_id in saved_skills:
			if skills.has(skill_id):
				skills[skill_id].current_level = saved_skills[skill_id].get("current_level", 0)
	
	file.close()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_skills_by_branch(branch: String) -> Array:
	"""Retourne les compétences d'une branche."""
	var result := []
	for skill in skills.values():
		if skill.branch == branch:
			result.append(skill)
	result.sort_custom(func(a, b): return a.tier < b.tier)
	return result


func get_all_skills() -> Array:
	"""Retourne toutes les compétences."""
	return skills.values()


func reset_skills() -> void:
	"""Réinitialise toutes les compétences (remboursement)."""
	for skill in skills.values():
		skill.current_level = 0
	skill_points = total_skill_points_earned
	skill_points_changed.emit(skill_points)
	_save_progress()
