# ==============================================================================
# MissionManager.gd - Gestionnaire de missions
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Charge et gère les missions depuis le fichier JSON
# Suit la progression du joueur
# ==============================================================================

extends Node
# class_name MissionManager removed - conflicts with autoload singleton

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal mission_started(mission: Mission)
signal mission_completed(mission: Mission)
signal mission_failed(mission: Mission)
signal mission_progress_updated(mission: Mission, current: int, target: int)
signal all_missions_loaded(count: int)

# ==============================================================================
# CLASSES INTERNES
# ==============================================================================

class Mission:
	var id: int
	var title: String
	var description: String
	var objective_type: String  # "GoTo", "Kill", "Collect"
	var target_coordinates: Vector3
	var target_count: int = 1
	var reward_credits: int
	var story_context: String
	var is_active: bool = false
	var is_completed: bool = false
	var current_progress: int = 0
	
	func _init(data: Dictionary) -> void:
		id = data.get("id", 0)
		title = data.get("title", "Mission Inconnue")
		description = data.get("description", "")
		objective_type = data.get("objective_type", "GoTo")
		
		var coords: Dictionary = data.get("target_coordinates", {})
		target_coordinates = Vector3(
			coords.get("x", 0.0),
			coords.get("y", 0.0),
			coords.get("z", 0.0)
		)
		
		target_count = data.get("target_count", 1)
		reward_credits = data.get("reward_credits", 100)
		story_context = data.get("story_context", "")
	
	func is_objective_complete() -> bool:
		return current_progress >= target_count
	
	func get_progress_text() -> String:
		match objective_type:
			"GoTo":
				return "Atteindre la destination"
			"Kill":
				return "%d / %d éliminés" % [current_progress, target_count]
			"Collect":
				return "%d / %d collectés" % [current_progress, target_count]
		return ""

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MISSIONS_PATH := "res://data/missions.json"
const SAVE_PATH := "user://mission_progress.json"

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var campaign_name: String = ""
var corporation_name: String = ""
var campaign_tagline: String = ""
var missions: Array[Mission] = []
var active_mission: Mission = null
var completed_mission_ids: Array[int] = []
var total_credits_earned: int = 0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Charge les missions au démarrage."""
	load_missions()
	load_progress()


# ==============================================================================
# CHARGEMENT DES MISSIONS
# ==============================================================================

func load_missions() -> void:
	"""Charge les missions depuis le fichier JSON."""
	if not FileAccess.file_exists(MISSIONS_PATH):
		push_error("MissionManager: Fichier missions.json non trouvé")
		return
	
	var file := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	if not file:
		push_error("MissionManager: Impossible d'ouvrir missions.json")
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("MissionManager: Erreur de parsing JSON: " + json.get_error_message())
		return
	
	var data: Dictionary = json.data
	
	# Charger les infos de campagne
	if data.has("campaign"):
		var campaign: Dictionary = data["campaign"]
		campaign_name = campaign.get("name", "")
		corporation_name = campaign.get("corporation", "")
		campaign_tagline = campaign.get("tagline", "")
	
	# Charger les missions
	missions.clear()
	if data.has("missions"):
		for mission_data in data["missions"]:
			var mission := Mission.new(mission_data)
			missions.append(mission)
	
	all_missions_loaded.emit(missions.size())
	print("MissionManager: %d missions chargées" % missions.size())


# ==============================================================================
# GESTION DES MISSIONS
# ==============================================================================

func start_mission(mission_id: int) -> bool:
	"""
	Démarre une mission par son ID.
	@return: true si la mission a démarré
	"""
	var mission := get_mission_by_id(mission_id)
	if not mission:
		push_warning("MissionManager: Mission %d non trouvée" % mission_id)
		return false
	
	if mission.is_completed:
		push_warning("MissionManager: Mission %d déjà complétée" % mission_id)
		return false
	
	# Désactiver la mission active précédente
	if active_mission:
		active_mission.is_active = false
	
	# Activer la nouvelle mission
	mission.is_active = true
	mission.current_progress = 0
	active_mission = mission
	
	mission_started.emit(mission)
	return true


func complete_mission(mission_id: int) -> void:
	"""Marque une mission comme complétée."""
	var mission := get_mission_by_id(mission_id)
	if not mission:
		return
	
	mission.is_completed = true
	mission.is_active = false
	
	if not completed_mission_ids.has(mission_id):
		completed_mission_ids.append(mission_id)
		total_credits_earned += mission.reward_credits
	
	if active_mission == mission:
		active_mission = null
	
	mission_completed.emit(mission)
	save_progress()


func fail_mission(mission_id: int) -> void:
	"""Marque une mission comme échouée."""
	var mission := get_mission_by_id(mission_id)
	if not mission:
		return
	
	mission.is_active = false
	
	if active_mission == mission:
		active_mission = null
	
	mission_failed.emit(mission)


func update_progress(amount: int = 1) -> void:
	"""Met à jour la progression de la mission active."""
	if not active_mission:
		return
	
	active_mission.current_progress += amount
	mission_progress_updated.emit(
		active_mission, 
		active_mission.current_progress, 
		active_mission.target_count
	)
	
	# Vérifier si objectif atteint
	if active_mission.is_objective_complete():
		complete_mission(active_mission.id)


func check_goto_objective(player_position: Vector3, threshold: float = 5.0) -> bool:
	"""
	Vérifie si le joueur a atteint la destination pour un objectif GoTo.
	@return: true si objectif atteint
	"""
	if not active_mission or active_mission.objective_type != "GoTo":
		return false
	
	var distance := player_position.distance_to(active_mission.target_coordinates)
	if distance <= threshold:
		complete_mission(active_mission.id)
		return true
	
	return false


# ==============================================================================
# ACCESSEURS
# ==============================================================================

func get_mission_by_id(mission_id: int) -> Mission:
	"""Retourne une mission par son ID."""
	for mission in missions:
		if mission.id == mission_id:
			return mission
	return null


func get_available_missions() -> Array[Mission]:
	"""Retourne les missions non complétées."""
	var available: Array[Mission] = []
	for mission in missions:
		if not mission.is_completed:
			available.append(mission)
	return available


func get_next_mission() -> Mission:
	"""Retourne la prochaine mission disponible."""
	for mission in missions:
		if not mission.is_completed:
			return mission
	return null


func get_active_mission() -> Mission:
	"""Retourne la mission active."""
	return active_mission


func is_mission_completed(mission_id: int) -> bool:
	"""Vérifie si une mission est complétée."""
	return completed_mission_ids.has(mission_id)


func get_completion_percentage() -> float:
	"""Retourne le pourcentage de missions complétées."""
	if missions.size() == 0:
		return 0.0
	return float(completed_mission_ids.size()) / float(missions.size()) * 100.0


# ==============================================================================
# SAUVEGARDE / CHARGEMENT
# ==============================================================================

func save_progress() -> void:
	"""Sauvegarde la progression des missions."""
	var save_data := {
		"completed_missions": completed_mission_ids,
		"total_credits": total_credits_earned,
		"active_mission_id": active_mission.id if active_mission else -1
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func load_progress() -> void:
	"""Charge la progression des missions."""
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return
	
	var data: Dictionary = json.data
	
	if data.has("completed_missions"):
		completed_mission_ids = []
		for id in data["completed_missions"]:
			completed_mission_ids.append(int(id))
			# Marquer comme complétée
			var mission := get_mission_by_id(int(id))
			if mission:
				mission.is_completed = true
	
	if data.has("total_credits"):
		total_credits_earned = data["total_credits"]
	
	if data.has("active_mission_id") and data["active_mission_id"] >= 0:
		start_mission(data["active_mission_id"])


func reset_progress() -> void:
	"""Réinitialise toute la progression."""
	completed_mission_ids.clear()
	total_credits_earned = 0
	active_mission = null
	
	for mission in missions:
		mission.is_completed = false
		mission.is_active = false
		mission.current_progress = 0
	
	# Supprimer le fichier de sauvegarde
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ==============================================================================
# SYNCHRONISATION MULTIJOUEUR
# ==============================================================================

func get_current_mission() -> Mission:
	"""Retourne la mission active (pour GPS vocal)."""
	return active_mission


func set_current_mission_from_network(mission_id: String, mission_data: Dictionary) -> void:
	"""
	Définit la mission active depuis une sync réseau.
	Appelé par NetworkManager.sync_mission_start()
	"""
	var id := int(mission_id)
	var mission := get_mission_by_id(id)
	
	if not mission:
		# Créer une mission temporaire si non trouvée
		mission = Mission.new({
			"id": id,
			"title": mission_data.get("title", "Mission"),
			"description": mission_data.get("description", ""),
			"objective_type": mission_data.get("objective_type", "GoTo"),
			"target_count": mission_data.get("target_count", 1),
			"reward_credits": mission_data.get("reward_credits", 100)
		})
		missions.append(mission)
	
	if active_mission:
		active_mission.is_active = false
	
	active_mission = mission
	mission.is_active = true
	mission.current_progress = 0
	
	mission_started.emit(mission)


func update_progress_from_network(mission_id: String, objective_type: String, current: int, target: int) -> void:
	"""
	Met à jour la progression depuis une sync réseau.
	Appelé par NetworkManager.sync_mission_progress()
	"""
	if not active_mission:
		return
	
	if str(active_mission.id) != mission_id:
		return
	
	active_mission.current_progress = current
	active_mission.target_count = target
	
	mission_progress_updated.emit(active_mission, current, target)


func complete_mission_from_network(mission_id: String, rewards: Dictionary) -> void:
	"""
	Marque une mission comme complétée depuis une sync réseau.
	Appelé par NetworkManager.sync_mission_complete()
	"""
	var id := int(mission_id)
	var mission := get_mission_by_id(id)
	
	if not mission:
		return
	
	mission.is_completed = true
	mission.is_active = false
	
	if mission == active_mission:
		active_mission = null
	
	if id not in completed_mission_ids:
		completed_mission_ids.append(id)
	
	# Appliquer les récompenses
	var credits: int = rewards.get("credits", 0)
	if credits > 0:
		total_credits_earned += credits
		var player_stats = get_node_or_null("/root/PlayerStats")
		if player_stats and player_stats.has_method("add_credits"):
			player_stats.add_credits(credits)
	
	mission_completed.emit(mission)
