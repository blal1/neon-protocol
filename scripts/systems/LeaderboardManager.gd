# ==============================================================================
# LeaderboardManager.gd - Système de classement local
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les scores et classements locaux (pas de serveur requis)
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal score_submitted(entry: LeaderboardEntry)
signal new_high_score(rank: int, entry: LeaderboardEntry)
signal leaderboard_loaded(leaderboard_id: String)

# ==============================================================================
# CLASSES
# ==============================================================================

class LeaderboardEntry:
	var player_name: String = ""
	var score: int = 0
	var timestamp: String = ""
	var stats: Dictionary = {}  # kills, time, missions, etc.
	
	func to_dict() -> Dictionary:
		return {
			"player_name": player_name,
			"score": score,
			"timestamp": timestamp,
			"stats": stats
		}
	
	static func from_dict(data: Dictionary) -> LeaderboardEntry:
		var entry := LeaderboardEntry.new()
		entry.player_name = data.get("player_name", "Anonyme")
		entry.score = data.get("score", 0)
		entry.timestamp = data.get("timestamp", "")
		entry.stats = data.get("stats", {})
		return entry

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SAVE_PATH := "user://leaderboards/"
const MAX_ENTRIES := 100
const DEFAULT_PLAYER_NAME := "Runner"

# ==============================================================================
# VARIABLES
# ==============================================================================
var leaderboards: Dictionary = {}  # leaderboard_id -> Array[LeaderboardEntry]
var player_name: String = DEFAULT_PLAYER_NAME

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du leaderboard."""
	_ensure_save_dir()
	_create_default_leaderboards()


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _ensure_save_dir() -> void:
	"""S'assure que le dossier existe."""
	if not DirAccess.dir_exists_absolute(SAVE_PATH):
		DirAccess.make_dir_recursive_absolute(SAVE_PATH)


func _create_default_leaderboards() -> void:
	"""Crée les leaderboards par défaut."""
	# High Scores généraux
	if not leaderboards.has("overall"):
		leaderboards["overall"] = []
		_load_leaderboard("overall")
	
	# Speedrun
	if not leaderboards.has("speedrun"):
		leaderboards["speedrun"] = []
		_load_leaderboard("speedrun")
	
	# Combat (kills)
	if not leaderboards.has("combat"):
		leaderboards["combat"] = []
		_load_leaderboard("combat")


# ==============================================================================
# SOUMISSION DE SCORE
# ==============================================================================

func submit_score(leaderboard_id: String, score: int, stats: Dictionary = {}) -> int:
	"""
	Soumet un score au leaderboard.
	@return: Rang obtenu (1 = premier), -1 si pas dans le top
	"""
	if not leaderboards.has(leaderboard_id):
		leaderboards[leaderboard_id] = []
	
	var entry := LeaderboardEntry.new()
	entry.player_name = player_name
	entry.score = score
	entry.timestamp = Time.get_datetime_string_from_system()
	entry.stats = stats
	
	var lb: Array = leaderboards[leaderboard_id]
	
	# Trouver la position
	var rank := -1
	for i in range(lb.size()):
		if score > lb[i].score:
			rank = i + 1
			lb.insert(i, entry)
			break
	
	# Si pas inséré et place disponible
	if rank == -1 and lb.size() < MAX_ENTRIES:
		lb.append(entry)
		rank = lb.size()
	
	# Limiter la taille
	while lb.size() > MAX_ENTRIES:
		lb.pop_back()
	
	# Sauvegarder
	_save_leaderboard(leaderboard_id)
	
	# Émettre les signaux
	score_submitted.emit(entry)
	
	if rank > 0 and rank <= 10:
		new_high_score.emit(rank, entry)
		
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Nouveau record ! Rang " + str(rank))
	
	return rank


func submit_overall_score(stats: Dictionary) -> int:
	"""Calcule et soumet un score global."""
	var score := _calculate_overall_score(stats)
	return submit_score("overall", score, stats)


func _calculate_overall_score(stats: Dictionary) -> int:
	"""Calcule un score basé sur les statistiques."""
	var score := 0
	
	# Points par kill
	score += stats.get("kills", 0) * 100
	
	# Points par mission complétée
	score += stats.get("missions_completed", 0) * 500
	
	# Points par crédits gagnés
	score += stats.get("credits_earned", 0)
	
	# Bonus si pas de mort
	if stats.get("deaths", 0) == 0:
		score = int(score * 1.5)
	
	return score


# ==============================================================================
# LECTURE DU LEADERBOARD
# ==============================================================================

func get_leaderboard(leaderboard_id: String, max_entries: int = 10) -> Array:
	"""Retourne les entrées d'un leaderboard."""
	if not leaderboards.has(leaderboard_id):
		return []
	
	var lb: Array = leaderboards[leaderboard_id]
	return lb.slice(0, mini(max_entries, lb.size()))


func get_player_rank(leaderboard_id: String) -> int:
	"""Retourne le rang du joueur actuel."""
	if not leaderboards.has(leaderboard_id):
		return -1
	
	var lb: Array = leaderboards[leaderboard_id]
	for i in range(lb.size()):
		if lb[i].player_name == player_name:
			return i + 1
	
	return -1


func get_player_best_score(leaderboard_id: String) -> int:
	"""Retourne le meilleur score du joueur."""
	if not leaderboards.has(leaderboard_id):
		return 0
	
	var lb: Array = leaderboards[leaderboard_id]
	for entry in lb:
		if entry.player_name == player_name:
			return entry.score
	
	return 0


# ==============================================================================
# SAUVEGARDE/CHARGEMENT
# ==============================================================================

func _save_leaderboard(leaderboard_id: String) -> void:
	"""Sauvegarde un leaderboard."""
	if not leaderboards.has(leaderboard_id):
		return
	
	var data := []
	for entry in leaderboards[leaderboard_id]:
		data.append(entry.to_dict())
	
	var path := SAVE_PATH + leaderboard_id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _load_leaderboard(leaderboard_id: String) -> void:
	"""Charge un leaderboard."""
	var path := SAVE_PATH + leaderboard_id + ".json"
	
	if not FileAccess.file_exists(path):
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		leaderboards[leaderboard_id] = []
		for entry_data in json.data:
			leaderboards[leaderboard_id].append(LeaderboardEntry.from_dict(entry_data))
	
	file.close()
	leaderboard_loaded.emit(leaderboard_id)


# ==============================================================================
# GESTION DU JOUEUR
# ==============================================================================

func set_player_name(name: String) -> void:
	"""Définit le nom du joueur."""
	player_name = name if not name.is_empty() else DEFAULT_PLAYER_NAME


func get_player_name() -> String:
	"""Retourne le nom du joueur."""
	return player_name


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func clear_leaderboard(leaderboard_id: String) -> void:
	"""Efface un leaderboard."""
	if leaderboards.has(leaderboard_id):
		leaderboards[leaderboard_id].clear()
		_save_leaderboard(leaderboard_id)


func get_available_leaderboards() -> Array:
	"""Retourne la liste des leaderboards disponibles."""
	return leaderboards.keys()


func format_rank(rank: int) -> String:
	"""Formate un rang pour affichage."""
	if rank == 1:
		return "🥇 1er"
	elif rank == 2:
		return "🥈 2ème"
	elif rank == 3:
		return "🥉 3ème"
	elif rank > 0:
		return str(rank) + "ème"
	return "Non classé"
