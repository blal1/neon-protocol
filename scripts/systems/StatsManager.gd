# ==============================================================================
# StatsManager.gd - Système de statistiques détaillées
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Suit les statistiques du joueur : kills, deaths, temps, etc.
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal stat_updated(stat_name: String, new_value: Variant)
signal milestone_reached(milestone_name: String, value: int)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SAVE_PATH := "user://player_stats.json"

# ==============================================================================
# STATISTIQUES DE SESSION
# ==============================================================================
var session_stats: Dictionary = {
	"session_start_time": 0,
	"enemies_killed": 0,
	"damage_dealt": 0.0,
	"damage_taken": 0.0,
	"deaths": 0,
	"missions_completed": 0,
	"credits_earned": 0,
	"credits_spent": 0,
	"items_collected": 0,
	"distance_traveled": 0.0,
	"combos_performed": 0,
	"max_combo": 0,
	"hacks_completed": 0,
	"stealth_takedowns": 0,
	"headshots": 0,
	"critical_hits": 0,
	"skills_unlocked": 0,
	"achievements_unlocked": 0
}

# ==============================================================================
# STATISTIQUES GLOBALES (Cumulées)
# ==============================================================================
var global_stats: Dictionary = {
	"total_playtime": 0,  # En secondes
	"total_enemies_killed": 0,
	"total_damage_dealt": 0.0,
	"total_damage_taken": 0.0,
	"total_deaths": 0,
	"total_missions_completed": 0,
	"total_credits_earned": 0,
	"total_distance_traveled": 0.0,
	"games_played": 0,
	"highest_level": 0,
	"fastest_mission_time": 999999.0,
	"longest_session": 0.0,
	"total_combos": 0,
	"best_combo": 0,
	"total_hacks": 0,
	"total_stealth_takedowns": 0
}

# ==============================================================================
# STATISTIQUES PAR ZONE
# ==============================================================================
var zone_stats: Dictionary = {}  # zone_id -> {time_spent, enemies_killed, deaths}

# ==============================================================================
# VARIABLES
# ==============================================================================
var _last_player_position: Vector3 = Vector3.ZERO
var _current_zone: String = "unknown"
var _player: Node3D = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	session_stats["session_start_time"] = Time.get_unix_time_from_system()
	_load_stats()
	global_stats["games_played"] += 1


func _process(delta: float) -> void:
	"""Mise à jour continue."""
	# Suivi de la distance parcourue
	if _player and is_instance_valid(_player):
		var current_pos := _player.global_position
		var distance := _last_player_position.distance_to(current_pos)
		
		# Éviter les téléportations
		if distance < 10.0 and distance > 0.01:
			session_stats["distance_traveled"] += distance
		
		_last_player_position = current_pos


func _notification(what: int) -> void:
	"""Gestion des notifications système."""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_stats()


# ==============================================================================
# INCRÉMENTATION DES STATS
# ==============================================================================

func increment(stat_name: String, amount: int = 1) -> void:
	"""Incrémente une statistique."""
	if session_stats.has(stat_name):
		session_stats[stat_name] += amount
		stat_updated.emit(stat_name, session_stats[stat_name])
		
		# Vérifier les milestones
		_check_milestones(stat_name, session_stats[stat_name])


func add_float(stat_name: String, amount: float) -> void:
	"""Ajoute une valeur float à une statistique."""
	if session_stats.has(stat_name):
		session_stats[stat_name] += amount
		stat_updated.emit(stat_name, session_stats[stat_name])


func set_stat(stat_name: String, value: Variant) -> void:
	"""Définit une statistique."""
	session_stats[stat_name] = value
	stat_updated.emit(stat_name, value)


func set_max(stat_name: String, value: int) -> void:
	"""Met à jour une stat si la nouvelle valeur est plus grande."""
	if session_stats.has(stat_name):
		if value > session_stats[stat_name]:
			session_stats[stat_name] = value
			stat_updated.emit(stat_name, value)


# ==============================================================================
# ACTIONS DE JEU
# ==============================================================================

func on_enemy_killed(enemy: Node3D = null) -> void:
	"""Appelé quand un ennemi est tué."""
	increment("enemies_killed")
	
	# Mettre à jour la zone
	if zone_stats.has(_current_zone):
		zone_stats[_current_zone]["enemies_killed"] += 1


func on_player_death() -> void:
	"""Appelé quand le joueur meurt."""
	increment("deaths")
	
	# Zone stats
	if zone_stats.has(_current_zone):
		zone_stats[_current_zone]["deaths"] += 1


func on_damage_dealt(amount: float, is_critical: bool = false) -> void:
	"""Appelé quand le joueur inflige des dégâts."""
	add_float("damage_dealt", amount)
	if is_critical:
		increment("critical_hits")


func on_damage_taken(amount: float) -> void:
	"""Appelé quand le joueur subit des dégâts."""
	add_float("damage_taken", amount)


func on_mission_completed(mission_time: float = 0.0) -> void:
	"""Appelé quand une mission est terminée."""
	increment("missions_completed")
	
	# Temps record
	if mission_time > 0 and mission_time < global_stats["fastest_mission_time"]:
		global_stats["fastest_mission_time"] = mission_time


func on_credits_earned(amount: int) -> void:
	"""Appelé quand le joueur gagne des crédits."""
	increment("credits_earned", amount)


func on_credits_spent(amount: int) -> void:
	"""Appelé quand le joueur dépense des crédits."""
	increment("credits_spent", amount)


func on_combo(combo_count: int) -> void:
	"""Appelé lors d'un combo."""
	increment("combos_performed")
	set_max("max_combo", combo_count)


func on_hack_completed() -> void:
	"""Appelé quand un hack est réussi."""
	increment("hacks_completed")


func on_stealth_takedown() -> void:
	"""Appelé lors d'une élimination furtive."""
	increment("stealth_takedowns")


# ==============================================================================
# ZONES
# ==============================================================================

func enter_zone(zone_id: String) -> void:
	"""Appelé quand le joueur entre dans une zone."""
	_current_zone = zone_id
	
	if not zone_stats.has(zone_id):
		zone_stats[zone_id] = {
			"time_spent": 0.0,
			"enemies_killed": 0,
			"deaths": 0,
			"visits": 0
		}
	
	zone_stats[zone_id]["visits"] += 1


func update_zone_time(delta: float) -> void:
	"""Met à jour le temps passé dans la zone."""
	if zone_stats.has(_current_zone):
		zone_stats[_current_zone]["time_spent"] += delta


# ==============================================================================
# MILESTONES
# ==============================================================================

func _check_milestones(stat_name: String, value: int) -> void:
	"""Vérifie les milestones atteints."""
	var milestones := [10, 25, 50, 100, 250, 500, 1000]
	
	for milestone in milestones:
		if value == milestone:
			milestone_reached.emit(stat_name + "_" + str(milestone), value)
			
			# Notification
			var toast = get_node_or_null("/root/ToastNotification")
			if toast:
				toast.show_achievement("%s: %d!" % [stat_name.replace("_", " ").capitalize(), value])


# ==============================================================================
# GETTERS
# ==============================================================================

func get_stat(stat_name: String) -> Variant:
	"""Retourne une statistique de session."""
	return session_stats.get(stat_name, 0)


func get_global_stat(stat_name: String) -> Variant:
	"""Retourne une statistique globale."""
	return global_stats.get(stat_name, 0)


func get_session_time() -> float:
	"""Retourne le temps de session en secondes."""
	return Time.get_unix_time_from_system() - session_stats["session_start_time"]


func get_formatted_time(seconds: float) -> String:
	"""Formate un temps en HH:MM:SS."""
	var hours := int(seconds / 3600)
	var minutes := int(fmod(seconds, 3600) / 60)
	var secs := int(fmod(seconds, 60))
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	else:
		return "%02d:%02d" % [minutes, secs]


func get_all_session_stats() -> Dictionary:
	"""Retourne toutes les stats de session."""
	var stats := session_stats.duplicate()
	stats["session_time"] = get_session_time()
	return stats


# ==============================================================================
# SAUVEGARDE / CHARGEMENT
# ==============================================================================

func _save_stats() -> void:
	"""Sauvegarde les statistiques."""
	# Fusionner les stats de session dans les stats globales
	global_stats["total_playtime"] += get_session_time()
	global_stats["total_enemies_killed"] += session_stats["enemies_killed"]
	global_stats["total_damage_dealt"] += session_stats["damage_dealt"]
	global_stats["total_damage_taken"] += session_stats["damage_taken"]
	global_stats["total_deaths"] += session_stats["deaths"]
	global_stats["total_missions_completed"] += session_stats["missions_completed"]
	global_stats["total_credits_earned"] += session_stats["credits_earned"]
	global_stats["total_distance_traveled"] += session_stats["distance_traveled"]
	global_stats["total_combos"] += session_stats["combos_performed"]
	global_stats["total_hacks"] += session_stats["hacks_completed"]
	global_stats["total_stealth_takedowns"] += session_stats["stealth_takedowns"]
	
	if session_stats["max_combo"] > global_stats["best_combo"]:
		global_stats["best_combo"] = session_stats["max_combo"]
	
	var session_time := get_session_time()
	if session_time > global_stats["longest_session"]:
		global_stats["longest_session"] = session_time
	
	# Sauvegarder
	var data := {
		"global_stats": global_stats,
		"zone_stats": zone_stats
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	
	print("StatsManager: Statistiques sauvegardées")


func _load_stats() -> void:
	"""Charge les statistiques."""
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.data
		
		# Merger avec les valeurs par défaut
		for key in data.get("global_stats", {}):
			if global_stats.has(key):
				global_stats[key] = data["global_stats"][key]
		
		zone_stats = data.get("zone_stats", {})
	
	file.close()
	print("StatsManager: Statistiques chargées")


func set_player(player: Node3D) -> void:
	"""Définit la référence au joueur."""
	_player = player
	_last_player_position = player.global_position if player else Vector3.ZERO
