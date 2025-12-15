# ==============================================================================
# AchievementManager.gd - Système de succès/achievements
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les achievements avec progression et récompenses
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal achievement_unlocked(achievement: Achievement)
signal achievement_progress(achievement: Achievement, current: int, target: int)
signal all_achievements_unlocked

# ==============================================================================
# CLASSES
# ==============================================================================

class Achievement:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon_path: String = ""
	var category: String = ""  # "combat", "exploration", "story", "misc"
	var is_hidden: bool = false  # Caché jusqu'à déblocage
	var is_unlocked: bool = false
	var unlock_date: String = ""
	
	# Progression
	var progress_current: int = 0
	var progress_target: int = 1
	var stat_to_track: String = ""  # "kills", "distance", "missions", etc.
	
	# Récompenses
	var reward_credits: int = 0
	var reward_item_id: String = ""
	
	func get_progress_percent() -> float:
		if progress_target <= 0:
			return 100.0 if is_unlocked else 0.0
		return (float(progress_current) / float(progress_target)) * 100.0
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"is_unlocked": is_unlocked,
			"unlock_date": unlock_date,
			"progress_current": progress_current
		}
	
	func from_save(data: Dictionary) -> void:
		is_unlocked = data.get("is_unlocked", false)
		unlock_date = data.get("unlock_date", "")
		progress_current = data.get("progress_current", 0)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SAVE_PATH := "user://achievements.json"

# ==============================================================================
# VARIABLES
# ==============================================================================
var achievements: Dictionary = {}  # id -> Achievement
var _stats: Dictionary = {}  # Statistiques trackées

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation des achievements."""
	_create_achievements()
	_load_progress()
	_connect_signals()


# ==============================================================================
# CRÉATION DES ACHIEVEMENTS
# ==============================================================================

func _create_achievements() -> void:
	"""Crée tous les achievements."""
	
	# === COMBAT ===
	_add_achievement({
		"id": "first_blood",
		"name": "Premier Sang",
		"description": "Éliminez votre premier ennemi",
		"category": "combat",
		"progress_target": 1,
		"stat_to_track": "kills",
		"reward_credits": 50
	})
	
	_add_achievement({
		"id": "robot_hunter",
		"name": "Chasseur de Robots",
		"description": "Éliminez 10 robots de sécurité",
		"category": "combat",
		"progress_target": 10,
		"stat_to_track": "kills",
		"reward_credits": 200
	})
	
	_add_achievement({
		"id": "exterminator",
		"name": "Exterminateur",
		"description": "Éliminez 50 ennemis",
		"category": "combat",
		"progress_target": 50,
		"stat_to_track": "kills",
		"reward_credits": 500
	})
	
	_add_achievement({
		"id": "untouchable",
		"name": "Intouchable",
		"description": "Terminez un combat sans prendre de dégâts",
		"category": "combat",
		"progress_target": 1,
		"stat_to_track": "flawless_combats",
		"reward_credits": 300
	})
	
	# === EXPLORATION ===
	_add_achievement({
		"id": "first_steps",
		"name": "Premiers Pas",
		"description": "Parcourez 100 mètres",
		"category": "exploration",
		"progress_target": 100,
		"stat_to_track": "distance_walked",
		"reward_credits": 25
	})
	
	_add_achievement({
		"id": "marathon",
		"name": "Marathon",
		"description": "Parcourez 1 kilomètre",
		"category": "exploration",
		"progress_target": 1000,
		"stat_to_track": "distance_walked",
		"reward_credits": 150
	})
	
	_add_achievement({
		"id": "district_explorer",
		"name": "Explorateur",
		"description": "Visitez tous les districts",
		"category": "exploration",
		"progress_target": 4,
		"stat_to_track": "districts_visited",
		"reward_credits": 400
	})
	
	# === HISTOIRE ===
	_add_achievement({
		"id": "awakening",
		"name": "Éveil",
		"description": "Terminez la première mission",
		"category": "story",
		"progress_target": 1,
		"stat_to_track": "story_missions_completed",
		"reward_credits": 100
	})
	
	_add_achievement({
		"id": "conspiracy",
		"name": "Conspiration",
		"description": "Découvrez les secrets de NovaTech",
		"category": "story",
		"progress_target": 5,
		"stat_to_track": "story_missions_completed",
		"reward_credits": 300
	})
	
	_add_achievement({
		"id": "revolution",
		"name": "Révolution",
		"description": "Terminez l'histoire principale",
		"category": "story",
		"progress_target": 10,
		"stat_to_track": "story_missions_completed",
		"reward_credits": 1000,
		"is_hidden": true
	})
	
	# === MISC ===
	_add_achievement({
		"id": "shopaholic",
		"name": "Accro au Shopping",
		"description": "Dépensez 1000 crédits en magasin",
		"category": "misc",
		"progress_target": 1000,
		"stat_to_track": "credits_spent",
		"reward_credits": 100
	})
	
	_add_achievement({
		"id": "collector",
		"name": "Collectionneur",
		"description": "Ramassez 25 objets",
		"category": "misc",
		"progress_target": 25,
		"stat_to_track": "items_collected",
		"reward_credits": 200
	})
	
	_add_achievement({
		"id": "survivor",
		"name": "Survivant",
		"description": "Survivez 1 heure de jeu",
		"category": "misc",
		"progress_target": 3600,
		"stat_to_track": "playtime_seconds",
		"reward_credits": 250
	})


func _add_achievement(data: Dictionary) -> void:
	"""Ajoute un achievement."""
	var ach := Achievement.new()
	ach.id = data.get("id", "")
	ach.name = data.get("name", "")
	ach.description = data.get("description", "")
	ach.icon_path = data.get("icon_path", "")
	ach.category = data.get("category", "misc")
	ach.is_hidden = data.get("is_hidden", false)
	ach.progress_target = data.get("progress_target", 1)
	ach.stat_to_track = data.get("stat_to_track", "")
	ach.reward_credits = data.get("reward_credits", 0)
	ach.reward_item_id = data.get("reward_item_id", "")
	
	achievements[ach.id] = ach


# ==============================================================================
# PROGRESSION
# ==============================================================================

func update_stat(stat_name: String, value: int) -> void:
	"""Met à jour une statistique et vérifie les achievements."""
	_stats[stat_name] = value
	
	# Vérifier tous les achievements liés
	for ach in achievements.values():
		if ach.is_unlocked:
			continue
		
		if ach.stat_to_track == stat_name:
			ach.progress_current = value
			
			if ach.progress_current >= ach.progress_target:
				_unlock_achievement(ach)
			else:
				achievement_progress.emit(ach, ach.progress_current, ach.progress_target)


func increment_stat(stat_name: String, amount: int = 1) -> void:
	"""Incrémente une statistique."""
	var current: int = _stats.get(stat_name, 0)
	update_stat(stat_name, current + amount)


func _unlock_achievement(achievement: Achievement) -> void:
	"""Débloque un achievement."""
	if achievement.is_unlocked:
		return
	
	achievement.is_unlocked = true
	achievement.unlock_date = Time.get_datetime_string_from_system()
	achievement.progress_current = achievement.progress_target
	
	# Donner les récompenses
	if achievement.reward_credits > 0:
		var inv = get_node_or_null("/root/InventoryManager")
		if inv:
			inv.add_credits(achievement.reward_credits)
	
	if not achievement.reward_item_id.is_empty():
		var inv = get_node_or_null("/root/InventoryManager")
		if inv:
			inv.add_item(achievement.reward_item_id)
	
	# Annoncer
	achievement_unlocked.emit(achievement)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Succès débloqué : " + achievement.name)
	
	# Sauvegarder
	_save_progress()
	
	# Vérifier si tous débloqués
	_check_all_unlocked()


# ==============================================================================
# SAUVEGARDE/CHARGEMENT
# ==============================================================================

func _save_progress() -> void:
	"""Sauvegarde la progression."""
	var save_data := {}
	
	for id in achievements:
		save_data[id] = achievements[id].to_dict()
	
	save_data["stats"] = _stats
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
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
		
		_stats = data.get("stats", {})
		
		for id in achievements:
			if data.has(id):
				achievements[id].from_save(data[id])
	
	file.close()


# ==============================================================================
# CONNEXION AUX SIGNAUX
# ==============================================================================

func _connect_signals() -> void:
	"""Connecte aux signaux du jeu."""
	# Connexion au MissionManager
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		if mm.has_signal("mission_completed"):
			mm.mission_completed.connect(_on_mission_completed)
	
	# Connexion à l'InventoryManager
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		if inv.has_signal("item_added"):
			inv.item_added.connect(_on_item_collected)
		if inv.has_signal("credits_changed"):
			inv.credits_changed.connect(_on_credits_changed)


func _on_mission_completed(mission) -> void:
	"""Callback de mission complétée."""
	increment_stat("missions_completed")
	if mission and mission.get("is_main_story", false):
		increment_stat("story_missions_completed")


func _on_item_collected(_item) -> void:
	"""Callback d'objet ramassé."""
	increment_stat("items_collected")


func _on_credits_changed(_new_amount: int) -> void:
	"""Callback de changement de crédits."""
	# Calculer les dépenses si on en a moins qu'avant
	pass


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_all_achievements() -> Array:
	"""Retourne tous les achievements."""
	return achievements.values()


func get_unlocked_achievements() -> Array:
	"""Retourne les achievements débloqués."""
	var result := []
	for ach in achievements.values():
		if ach.is_unlocked:
			result.append(ach)
	return result


func get_locked_achievements() -> Array:
	"""Retourne les achievements non débloqués (non cachés)."""
	var result := []
	for ach in achievements.values():
		if not ach.is_unlocked and not ach.is_hidden:
			result.append(ach)
	return result


func get_achievement(id: String) -> Achievement:
	"""Retourne un achievement par ID."""
	return achievements.get(id, null)


func get_unlock_percentage() -> float:
	"""Retourne le pourcentage de complétion."""
	var total := achievements.size()
	if total == 0:
		return 0.0
	
	var unlocked := 0
	for ach in achievements.values():
		if ach.is_unlocked:
			unlocked += 1
	
	return (float(unlocked) / float(total)) * 100.0


func _check_all_unlocked() -> void:
	"""Vérifie si tous les achievements sont débloqués."""
	for ach in achievements.values():
		if not ach.is_unlocked:
			return
	
	all_achievements_unlocked.emit()
