# ==============================================================================
# SaveManager.gd - Gestionnaire de sauvegarde globale
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Autoload Singleton pour sauvegarder/charger la progression du joueur
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_deleted(slot: int)
signal save_failed(error: String)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SAVE_DIR := "user://saves/"
const SAVE_EXTENSION := ".sav"
const MAX_SLOTS := 3
const CURRENT_VERSION := 1

# ==============================================================================
# STRUCTURE DE DONNÉES
# ==============================================================================

class SaveData:
	var version: int = CURRENT_VERSION
	var timestamp: String = ""
	var playtime_seconds: float = 0.0
	
	# Progression joueur
	var player_position: Vector3 = Vector3.ZERO
	var player_rotation: float = 0.0
	var player_health: float = 100.0
	var player_max_health: float = 100.0
	var player_credits: int = 0
	
	# Missions
	var current_mission_id: int = -1
	var completed_mission_ids: Array = []
	var mission_progress: Dictionary = {}
	
	# Inventaire
	var inventory_items: Array = []
	var equipped_items: Dictionary = {}
	
	# Stats
	var kills: int = 0
	var deaths: int = 0
	var distance_walked: float = 0.0
	
	func to_dict() -> Dictionary:
		return {
			"version": version,
			"timestamp": timestamp,
			"playtime_seconds": playtime_seconds,
			"player": {
				"position": {"x": player_position.x, "y": player_position.y, "z": player_position.z},
				"rotation": player_rotation,
				"health": player_health,
				"max_health": player_max_health,
				"credits": player_credits
			},
			"missions": {
				"current_id": current_mission_id,
				"completed_ids": completed_mission_ids,
				"progress": mission_progress
			},
			"inventory": {
				"items": inventory_items,
				"equipped": equipped_items
			},
			"stats": {
				"kills": kills,
				"deaths": deaths,
				"distance_walked": distance_walked
			}
		}
	
	func from_dict(data: Dictionary) -> void:
		version = data.get("version", 1)
		timestamp = data.get("timestamp", "")
		playtime_seconds = data.get("playtime_seconds", 0.0)
		
		var player_data: Dictionary = data.get("player", {})
		var pos: Dictionary = player_data.get("position", {})
		player_position = Vector3(pos.get("x", 0), pos.get("y", 0), pos.get("z", 0))
		player_rotation = player_data.get("rotation", 0.0)
		player_health = player_data.get("health", 100.0)
		player_max_health = player_data.get("max_health", 100.0)
		player_credits = player_data.get("credits", 0)
		
		var missions_data: Dictionary = data.get("missions", {})
		current_mission_id = missions_data.get("current_id", -1)
		completed_mission_ids = missions_data.get("completed_ids", [])
		mission_progress = missions_data.get("progress", {})
		
		var inv_data: Dictionary = data.get("inventory", {})
		inventory_items = inv_data.get("items", [])
		equipped_items = inv_data.get("equipped", {})
		
		var stats_data: Dictionary = data.get("stats", {})
		kills = stats_data.get("kills", 0)
		deaths = stats_data.get("deaths", 0)
		distance_walked = stats_data.get("distance_walked", 0.0)

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_save: SaveData = SaveData.new()
var _session_start_time: float = 0.0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du gestionnaire."""
	_ensure_save_dir_exists()
	_session_start_time = Time.get_unix_time_from_system()


# ==============================================================================
# SAUVEGARDE
# ==============================================================================

func save_game(slot: int = 0) -> bool:
	"""
	Sauvegarde la partie dans un slot.
	@param slot: Numéro de slot (0-2)
	@return: true si succès
	"""
	if slot < 0 or slot >= MAX_SLOTS:
		save_failed.emit("Slot invalide: " + str(slot))
		return false
	
	# Collecter les données
	_collect_game_data()
	
	# Mettre à jour timestamp et playtime
	current_save.timestamp = Time.get_datetime_string_from_system()
	current_save.playtime_seconds += Time.get_unix_time_from_system() - _session_start_time
	_session_start_time = Time.get_unix_time_from_system()
	
	# Sérialiser
	var json_string := JSON.stringify(current_save.to_dict(), "\t")
	
	var path := _get_save_path(slot)
	var backup_path := path + ".bak"
	
	# Créer une backup du fichier existant
	if FileAccess.file_exists(path):
		var existing := FileAccess.open(path, FileAccess.READ)
		if existing:
			var existing_content := existing.get_as_text()
			existing.close()
			
			var backup := FileAccess.open(backup_path, FileAccess.WRITE)
			if backup:
				backup.store_string(existing_content)
				backup.close()
	
	# Écrire le nouveau fichier
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		# Tentative de restauration depuis backup
		if FileAccess.file_exists(backup_path):
			push_warning("SaveManager: Échec écriture, backup préservée")
		save_failed.emit("Impossible d'écrire: " + path)
		return false
	
	file.store_string(json_string)
	file.close()
	
	# Vérifier l'intégrité après écriture
	if not _verify_save_integrity(path):
		# Restaurer depuis backup
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(backup_path, path)
			push_warning("SaveManager: Corruption détectée, backup restaurée")
		save_failed.emit("Corruption détectée lors de la sauvegarde")
		return false
	
	save_completed.emit(slot)
	print("SaveManager: Partie sauvegardée dans slot ", slot)
	return true


func _verify_save_integrity(path: String) -> bool:
	"""Vérifie l'intégrité d'un fichier de sauvegarde."""
	if not FileAccess.file_exists(path):
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	
	var content := file.get_as_text()
	file.close()
	
	# Vérifier que c'est du JSON valide
	var json := JSON.new()
	if json.parse(content) != OK:
		return false
	
	# Vérifier les champs essentiels
	var data: Dictionary = json.data
	if not data.has("version") or not data.has("player"):
		return false
	
	return true


func _collect_game_data() -> void:
	"""Collecte les données de jeu actuelles."""
	# Joueur
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node3D = players[0]
		current_save.player_position = player.global_position
		current_save.player_rotation = player.rotation.y
		
		var health_comp = player.get_node_or_null("HealthComponent")
		if health_comp:
			current_save.player_health = health_comp.current_health
			current_save.player_max_health = health_comp.max_health
	
	# Missions
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		if mm.active_mission:
			current_save.current_mission_id = mm.active_mission.id
		current_save.completed_mission_ids = mm.completed_mission_ids.duplicate()
		current_save.player_credits = mm.total_credits_earned
	
	# Inventaire
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("get_all_items"):
		current_save.inventory_items = inv.get_all_items()


# ==============================================================================
# CHARGEMENT
# ==============================================================================

func load_game(slot: int = 0) -> bool:
	"""
	Charge une partie depuis un slot.
	@param slot: Numéro de slot (0-2)
	@return: true si succès
	"""
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return false
	
	current_save.from_dict(json.data)
	_apply_loaded_data()
	
	_session_start_time = Time.get_unix_time_from_system()
	load_completed.emit(slot)
	print("SaveManager: Partie chargée depuis slot ", slot)
	return true


func _apply_loaded_data() -> void:
	"""Applique les données chargées au jeu."""
	# Cette fonction sera appelée après le changement de scène
	# Les données sont stockées dans current_save
	pass


func apply_to_player(player: Node3D) -> void:
	"""Applique les données sauvegardées à un joueur."""
	player.global_position = current_save.player_position
	player.rotation.y = current_save.player_rotation
	
	var health_comp = player.get_node_or_null("HealthComponent")
	if health_comp:
		health_comp.current_health = current_save.player_health
		health_comp.max_health = current_save.player_max_health


# ==============================================================================
# GESTION DES SLOTS
# ==============================================================================

func get_save_info(slot: int) -> Dictionary:
	"""Retourne les infos d'une sauvegarde."""
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"exists": false}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {"exists": false}
	
	var data: Dictionary = json.data
	return {
		"exists": true,
		"timestamp": data.get("timestamp", "Inconnu"),
		"playtime": _format_playtime(data.get("playtime_seconds", 0)),
		"mission_id": data.get("missions", {}).get("current_id", -1),
		"credits": data.get("player", {}).get("credits", 0)
	}


func delete_save(slot: int) -> bool:
	"""Supprime une sauvegarde."""
	var path := _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		save_deleted.emit(slot)
		return true
	return false


func has_save(slot: int) -> bool:
	"""Vérifie si un slot contient une sauvegarde."""
	return FileAccess.file_exists(_get_save_path(slot))


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _get_save_path(slot: int) -> String:
	"""Retourne le chemin du fichier de sauvegarde."""
	return SAVE_DIR + "save_" + str(slot) + SAVE_EXTENSION


func _ensure_save_dir_exists() -> void:
	"""S'assure que le dossier de sauvegarde existe."""
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)


func _format_playtime(seconds: float) -> String:
	"""Formate le temps de jeu."""
	var hours := int(seconds / 3600)
	var mins := int(fmod(seconds, 3600) / 60)
	return "%dh %02dm" % [hours, mins]


func get_current_save() -> SaveData:
	"""Retourne les données de sauvegarde actuelles."""
	return current_save
