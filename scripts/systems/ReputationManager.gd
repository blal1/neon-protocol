# ==============================================================================
# ReputationManager.gd - Système de réputation avec factions
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les relations avec les différentes factions
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal reputation_changed(faction_id: String, old_value: int, new_value: int)
signal faction_rank_changed(faction_id: String, new_rank: FactionRank)
signal faction_unlocked(faction_id: String)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum FactionRank {
	HOSTILE = -2,    # Attaque à vue
	UNFRIENDLY = -1, # Méfiant
	NEUTRAL = 0,     # Indifférent
	FRIENDLY = 1,    # Amical
	ALLIED = 2       # Allié
}

# ==============================================================================
# CLASSES
# ==============================================================================

class Faction:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var color: Color = Color.WHITE
	var reputation: int = 0  # -100 à 100
	var is_unlocked: bool = false
	var enemy_factions: Array[String] = []  # Factions hostiles
	var ally_factions: Array[String] = []   # Factions alliées
	
	func get_rank() -> FactionRank:
		if reputation <= -50:
			return FactionRank.HOSTILE
		elif reputation < 0:
			return FactionRank.UNFRIENDLY
		elif reputation < 25:
			return FactionRank.NEUTRAL
		elif reputation < 75:
			return FactionRank.FRIENDLY
		else:
			return FactionRank.ALLIED
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"reputation": reputation,
			"is_unlocked": is_unlocked
		}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SAVE_PATH := "user://reputation.json"

# Seuils de réputation
const REP_HOSTILE := -50
const REP_FRIENDLY := 25
const REP_ALLIED := 75

# ==============================================================================
# VARIABLES
# ==============================================================================
var factions: Dictionary = {}  # id -> Faction

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_create_factions()
	_load_progress()


# ==============================================================================
# CRÉATION DES FACTIONS
# ==============================================================================

func _create_factions() -> void:
	"""Crée toutes les factions."""
	
	# NOVATECH - Mégacorporation
	var novatech := Faction.new()
	novatech.id = "novatech"
	novatech.name = "NovaTech Industries"
	novatech.description = "La mégacorporation dominante. Contrôle la technologie et la sécurité."
	novatech.color = Color(0.2, 0.5, 1.0)
	novatech.reputation = -20  # Légèrement hostile au début
	novatech.is_unlocked = true
	novatech.enemy_factions = ["resistance", "hackers"]
	novatech.ally_factions = ["enforcers"]
	factions[novatech.id] = novatech
	
	# STREET GANGS - Gangs de rue
	var street := Faction.new()
	street.id = "street"
	street.name = "Street Runners"
	street.description = "Les gangs de rue unifiés. Contrôlent le marché noir."
	street.color = Color(1.0, 0.4, 0.2)
	street.reputation = 10
	street.is_unlocked = true
	street.enemy_factions = ["enforcers"]
	street.ally_factions = ["resistance"]
	factions[street.id] = street
	
	# HACKERS - Collectif hacker
	var hackers := Faction.new()
	hackers.id = "hackers"
	hackers.name = "Ghost Protocol"
	hackers.description = "Collectif de hackers underground. Information is power."
	hackers.color = Color(0.2, 1.0, 0.4)
	hackers.reputation = 0
	hackers.is_unlocked = true
	hackers.enemy_factions = ["novatech"]
	hackers.ally_factions = ["resistance"]
	factions[hackers.id] = hackers
	
	# RESISTANCE - Mouvement de résistance
	var resistance := Faction.new()
	resistance.id = "resistance"
	resistance.name = "Neon Liberators"
	resistance.description = "Combattants pour la liberté contre l'oppression corpo."
	resistance.color = Color(1.0, 0.8, 0.0)
	resistance.reputation = 0
	resistance.is_unlocked = false  # Débloquée pendant l'histoire
	resistance.enemy_factions = ["novatech", "enforcers"]
	resistance.ally_factions = ["street", "hackers"]
	factions[resistance.id] = resistance
	
	# ENFORCERS - Forces de sécurité privées
	var enforcers := Faction.new()
	enforcers.id = "enforcers"
	enforcers.name = "Chrome Enforcers"
	enforcers.description = "Mercenaires augmentés. Travaillent pour le plus offrant."
	enforcers.color = Color(0.5, 0.5, 0.5)
	enforcers.reputation = -10
	enforcers.is_unlocked = true
	enforcers.enemy_factions = ["street", "resistance"]
	enforcers.ally_factions = ["novatech"]
	factions[enforcers.id] = enforcers


# ==============================================================================
# MODIFICATION DE RÉPUTATION
# ==============================================================================

func change_reputation(faction_id: String, amount: int) -> void:
	"""
	Modifie la réputation avec une faction.
	@param faction_id: ID de la faction
	@param amount: Changement (positif ou négatif)
	"""
	if not factions.has(faction_id):
		return
	
	var faction: Faction = factions[faction_id]
	var old_value := faction.reputation
	var old_rank := faction.get_rank()
	
	faction.reputation = clamp(faction.reputation + amount, -100, 100)
	
	reputation_changed.emit(faction_id, old_value, faction.reputation)
	
	# Vérifier si le rang a changé
	var new_rank := faction.get_rank()
	if new_rank != old_rank:
		faction_rank_changed.emit(faction_id, new_rank)
		_announce_rank_change(faction, new_rank)
	
	# Effet sur les factions alliées/ennemies
	_propagate_reputation(faction, amount)
	
	_save_progress()


func _propagate_reputation(faction: Faction, base_amount: int) -> void:
	"""Propage le changement de réputation aux factions liées."""
	# Les alliés gagnent une partie de la réputation
	for ally_id in faction.ally_factions:
		if factions.has(ally_id):
			var ally: Faction = factions[ally_id]
			var propagated := int(base_amount * 0.3)
			if propagated != 0:
				ally.reputation = clamp(ally.reputation + propagated, -100, 100)
	
	# Les ennemis perdent de la réputation
	for enemy_id in faction.enemy_factions:
		if factions.has(enemy_id):
			var enemy: Faction = factions[enemy_id]
			var propagated := int(-base_amount * 0.2)
			if propagated != 0:
				enemy.reputation = clamp(enemy.reputation + propagated, -100, 100)


func _announce_rank_change(faction: Faction, new_rank: FactionRank) -> void:
	"""Annonce le changement de rang."""
	var tts = get_node_or_null("/root/TTSManager")
	if not tts:
		return
	
	var rank_names := {
		FactionRank.HOSTILE: "hostile",
		FactionRank.UNFRIENDLY: "méfiant",
		FactionRank.NEUTRAL: "neutre",
		FactionRank.FRIENDLY: "amical",
		FactionRank.ALLIED: "allié"
	}
	
	tts.speak(faction.name + " est maintenant " + rank_names[new_rank])


# ==============================================================================
# ACTIONS ET CONSÉQUENCES
# ==============================================================================

func on_enemy_killed(enemy: Node3D) -> void:
	"""Appelé quand un ennemi est tué."""
	# Déterminer la faction de l'ennemi
	var faction_id: String = ""
	if enemy.has_meta("faction"):
		faction_id = enemy.get_meta("faction")
	elif enemy.is_in_group("novatech"):
		faction_id = "novatech"
	elif enemy.is_in_group("enforcers"):
		faction_id = "enforcers"
	
	if faction_id.is_empty():
		return
	
	# Perdre de la réputation avec cette faction
	change_reputation(faction_id, -5)


func on_mission_completed(mission_data: Dictionary) -> void:
	"""Appelé quand une mission est terminée."""
	var faction_id: String = mission_data.get("faction", "")
	var rep_reward: int = mission_data.get("reputation_reward", 10)
	
	if faction_id.is_empty():
		return
	
	change_reputation(faction_id, rep_reward)


func on_item_given(faction_id: String, item_value: int) -> void:
	"""Appelé quand un objet est donné à une faction."""
	var rep_gain := int(item_value / 10)  # 10 crédits = 1 rep
	change_reputation(faction_id, rep_gain)


# ==============================================================================
# SAUVEGARDE/CHARGEMENT
# ==============================================================================

func _save_progress() -> void:
	"""Sauvegarde la progression."""
	var data := {}
	for faction_id in factions:
		data[faction_id] = factions[faction_id].to_dict()
	
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
		for faction_id in data:
			if factions.has(faction_id):
				factions[faction_id].reputation = data[faction_id].get("reputation", 0)
				factions[faction_id].is_unlocked = data[faction_id].get("is_unlocked", false)
	
	file.close()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_faction(faction_id: String) -> Faction:
	"""Retourne une faction."""
	return factions.get(faction_id, null)


func get_reputation(faction_id: String) -> int:
	"""Retourne la réputation avec une faction."""
	if factions.has(faction_id):
		return factions[faction_id].reputation
	return 0


func get_rank(faction_id: String) -> FactionRank:
	"""Retourne le rang avec une faction."""
	if factions.has(faction_id):
		return factions[faction_id].get_rank()
	return FactionRank.NEUTRAL


func is_hostile(faction_id: String) -> bool:
	"""Vérifie si une faction est hostile."""
	return get_rank(faction_id) == FactionRank.HOSTILE


func is_friendly(faction_id: String) -> bool:
	"""Vérifie si une faction est amicale."""
	var rank := get_rank(faction_id)
	return rank == FactionRank.FRIENDLY or rank == FactionRank.ALLIED


func unlock_faction(faction_id: String) -> void:
	"""Débloque une faction."""
	if factions.has(faction_id):
		if not factions[faction_id].is_unlocked:
			factions[faction_id].is_unlocked = true
			faction_unlocked.emit(faction_id)
			_save_progress()


func get_all_factions() -> Array:
	"""Retourne toutes les factions."""
	return factions.values()


func get_unlocked_factions() -> Array:
	"""Retourne les factions débloquées."""
	var result := []
	for faction in factions.values():
		if faction.is_unlocked:
			result.append(faction)
	return result
