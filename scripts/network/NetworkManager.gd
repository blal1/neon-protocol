# ==============================================================================
# NetworkManager.gd - Gestionnaire réseau multijoueur
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les connexions, synchronisation et lobby
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal connection_started
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal all_players_loaded
signal game_started

# ==============================================================================
# CONSTANTES
# ==============================================================================
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const PLAYER_SCENE := "res://scenes/player/Player.tscn"

# ==============================================================================
# VARIABLES
# ==============================================================================
var peer: ENetMultiplayerPeer = null
var players_info: Dictionary = {}  # peer_id -> player_info
var players_loaded: Array[int] = []
var local_player_info: Dictionary = {
	"name": "Runner",
	"color": Color.CYAN,
	"ready": false
}

var is_server: bool = false
var is_connected: bool = false
var server_ip: String = "127.0.0.1"
var server_port: int = DEFAULT_PORT

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du gestionnaire réseau."""
	# Connecter les signaux du multiplayer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ==============================================================================
# HÉBERGEMENT & CONNEXION
# ==============================================================================

func host_game(port: int = DEFAULT_PORT, max_clients: int = MAX_PLAYERS) -> Error:
	"""
	Héberge une partie en tant que serveur.
	@return: Error.OK si réussi
	"""
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	
	if error != OK:
		push_error("NetworkManager: Impossible de créer le serveur: " + str(error))
		connection_failed.emit()
		return error
	
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_connected = true
	server_port = port
	
	# Ajouter le serveur comme joueur
	players_info[1] = local_player_info.duplicate()
	
	connection_started.emit()
	print("NetworkManager: Serveur démarré sur le port %d" % port)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Serveur créé. En attente de joueurs.")
	
	return OK


func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	"""
	Rejoint une partie existante.
	@return: Error.OK si connexion lancée
	"""
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, port)
	
	if error != OK:
		push_error("NetworkManager: Impossible de se connecter: " + str(error))
		connection_failed.emit()
		return error
	
	multiplayer.multiplayer_peer = peer
	is_server = false
	server_ip = ip
	server_port = port
	
	connection_started.emit()
	print("NetworkManager: Tentative de connexion à %s:%d" % [ip, port])
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Connexion en cours")
	
	return OK


func disconnect_from_game() -> void:
	"""Déconnexion du jeu."""
	if peer:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	is_server = false
	is_connected = false
	players_info.clear()
	players_loaded.clear()
	
	print("NetworkManager: Déconnecté")


# ==============================================================================
# CALLBACKS RÉSEAU
# ==============================================================================

func _on_peer_connected(peer_id: int) -> void:
	"""Appelé quand un joueur se connecte."""
	print("NetworkManager: Joueur %d connecté" % peer_id)
	
	# Envoyer nos infos au nouveau joueur
	_send_player_info.rpc_id(peer_id, local_player_info)


func _on_peer_disconnected(peer_id: int) -> void:
	"""Appelé quand un joueur se déconnecte."""
	print("NetworkManager: Joueur %d déconnecté" % peer_id)
	
	if players_info.has(peer_id):
		players_info.erase(peer_id)
	
	if players_loaded.has(peer_id):
		players_loaded.erase(peer_id)
	
	player_disconnected.emit(peer_id)
	
	# Supprimer le joueur de la scène
	var player_node = get_node_or_null("/root/Main/Players/" + str(peer_id))
	if player_node:
		player_node.queue_free()


func _on_connected_to_server() -> void:
	"""Appelé quand on se connecte au serveur (côté client)."""
	print("NetworkManager: Connecté au serveur")
	is_connected = true
	
	# Ajouter notre info locale
	players_info[multiplayer.get_unique_id()] = local_player_info.duplicate()
	
	connection_succeeded.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Connecté au serveur")


func _on_connection_failed() -> void:
	"""Appelé quand la connexion échoue."""
	print("NetworkManager: Connexion échouée")
	is_connected = false
	peer = null
	
	connection_failed.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Connexion échouée")


func _on_server_disconnected() -> void:
	"""Appelé quand le serveur se déconnecte."""
	print("NetworkManager: Serveur déconnecté")
	is_connected = false
	peer = null
	
	server_disconnected.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Déconnecté du serveur")


# ==============================================================================
# RPC - SYNCHRONISATION
# ==============================================================================

@rpc("any_peer", "reliable")
func _send_player_info(info: Dictionary) -> void:
	"""Reçoit les infos d'un joueur."""
	var sender_id := multiplayer.get_remote_sender_id()
	players_info[sender_id] = info
	
	player_connected.emit(sender_id, info)
	
	print("NetworkManager: Reçu infos du joueur %d: %s" % [sender_id, info.get("name", "???")])
	
	# Si on est le serveur, renvoyer les infos à tous
	if is_server:
		for peer_id in players_info:
			if peer_id != sender_id and peer_id != 1:
				_send_player_info.rpc_id(peer_id, info)


@rpc("any_peer", "reliable")
func _player_loaded() -> void:
	"""Signale que le joueur a fini de charger."""
	var sender_id := multiplayer.get_remote_sender_id()
	
	if sender_id not in players_loaded:
		players_loaded.append(sender_id)
	
	print("NetworkManager: Joueur %d chargé (%d/%d)" % [sender_id, players_loaded.size(), players_info.size()])
	
	# Vérifier si tous les joueurs sont chargés
	if is_server and players_loaded.size() >= players_info.size():
		all_players_loaded.emit()
		_start_game.rpc()


@rpc("authority", "reliable", "call_local")
func _start_game() -> void:
	"""Démarre la partie pour tous."""
	game_started.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("La partie commence !")


@rpc("authority", "reliable")
func _spawn_player(peer_id: int, spawn_pos: Vector3) -> void:
	"""Fait apparaître un joueur (appelé par le serveur)."""
	if not ResourceLoader.exists(PLAYER_SCENE):
		push_error("NetworkManager: Scène joueur introuvable")
		return
	
	var player_scene := load(PLAYER_SCENE) as PackedScene
	var player := player_scene.instantiate()
	player.name = str(peer_id)
	player.global_position = spawn_pos
	
	# Configurer l'autorité
	player.set_multiplayer_authority(peer_id)
	
	# Ajouter à la scène
	var players_container = get_node_or_null("/root/Main/Players")
	if players_container:
		players_container.add_child(player)
	else:
		get_tree().current_scene.add_child(player)


# ==============================================================================
# GESTION DE PARTIE
# ==============================================================================

func start_multiplayer_game() -> void:
	"""Démarre la partie (appelé par le serveur)."""
	if not is_server:
		return
	
	# Définir les positions de spawn
	var spawn_positions := [
		Vector3(0, 1, 0),
		Vector3(5, 1, 0),
		Vector3(0, 1, 5),
		Vector3(5, 1, 5)
	]
	
	var idx := 0
	for peer_id in players_info:
		var spawn_pos: Vector3 = spawn_positions[idx % spawn_positions.size()]
		_spawn_player.rpc(peer_id, spawn_pos)
		idx += 1


func notify_loaded() -> void:
	"""Notifie au serveur que le joueur local est chargé."""
	if is_server:
		players_loaded.append(1)
		if players_loaded.size() >= players_info.size():
			all_players_loaded.emit()
	else:
		_player_loaded.rpc_id(1)


# ==============================================================================
# CONFIGURATION LOCALE
# ==============================================================================

func set_player_name(player_name: String) -> void:
	"""Définit le nom du joueur local."""
	local_player_info["name"] = player_name


func set_player_color(color: Color) -> void:
	"""Définit la couleur du joueur local."""
	local_player_info["color"] = color


func set_player_ready(ready: bool) -> void:
	"""Définit l'état prêt du joueur local."""
	local_player_info["ready"] = ready
	
	# Synchroniser
	if is_connected:
		_send_player_info.rpc(local_player_info)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_player_count() -> int:
	"""Retourne le nombre de joueurs connectés."""
	return players_info.size()


func get_player_info(peer_id: int) -> Dictionary:
	"""Retourne les infos d'un joueur."""
	return players_info.get(peer_id, {})


func get_local_peer_id() -> int:
	"""Retourne l'ID du joueur local."""
	if multiplayer.multiplayer_peer:
		return multiplayer.get_unique_id()
	return 0


func is_host() -> bool:
	"""Retourne true si on est le serveur."""
	return is_server


func are_all_ready() -> bool:
	"""Vérifie si tous les joueurs sont prêts."""
	for info in players_info.values():
		if not info.get("ready", false):
			return false
	return true


# ==============================================================================
# RPC - SYNCHRONISATION MISSIONS
# ==============================================================================

@rpc("authority", "reliable", "call_local")
func sync_mission_start(mission_id: String, mission_data: Dictionary) -> void:
	"""
	Synchronise le démarrage d'une mission à tous les joueurs.
	@param mission_id: ID de la mission
	@param mission_data: Données de la mission (titre, objectifs, etc.)
	"""
	print("NetworkManager: Mission %s démarrée" % mission_id)
	
	var mission_mgr = get_node_or_null("/root/MissionManager")
	if mission_mgr and mission_mgr.has_method("set_current_mission_from_network"):
		mission_mgr.set_current_mission_from_network(mission_id, mission_data)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Nouvelle mission: " + mission_data.get("title", "Mission"))


func broadcast_mission_start(mission_id: String, mission_data: Dictionary) -> void:
	"""Envoie le démarrage d'une mission (appelé par le serveur)."""
	if is_server:
		sync_mission_start.rpc(mission_id, mission_data)


@rpc("authority", "reliable", "call_local")
func sync_mission_progress(mission_id: String, objective_type: String, current: int, target: int) -> void:
	"""
	Synchronise la progression d'un objectif de mission.
	@param mission_id: ID de la mission
	@param objective_type: Type d'objectif (kill, collect, goto)
	@param current: Progression actuelle
	@param target: Objectif cible
	"""
	print("NetworkManager: Mission %s - %s: %d/%d" % [mission_id, objective_type, current, target])
	
	var mission_mgr = get_node_or_null("/root/MissionManager")
	if mission_mgr and mission_mgr.has_method("update_progress_from_network"):
		mission_mgr.update_progress_from_network(mission_id, objective_type, current, target)


func broadcast_mission_progress(mission_id: String, objective_type: String, current: int, target: int) -> void:
	"""Envoie la progression d'une mission (appelé par le serveur)."""
	if is_server:
		sync_mission_progress.rpc(mission_id, objective_type, current, target)


@rpc("authority", "reliable", "call_local")
func sync_mission_complete(mission_id: String, rewards: Dictionary) -> void:
	"""
	Synchronise la complétion d'une mission.
	@param mission_id: ID de la mission
	@param rewards: Récompenses obtenues
	"""
	print("NetworkManager: Mission %s terminée" % mission_id)
	
	var mission_mgr = get_node_or_null("/root/MissionManager")
	if mission_mgr and mission_mgr.has_method("complete_mission_from_network"):
		mission_mgr.complete_mission_from_network(mission_id, rewards)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Mission accomplie")


func broadcast_mission_complete(mission_id: String, rewards: Dictionary) -> void:
	"""Envoie la complétion d'une mission (appelé par le serveur)."""
	if is_server:
		sync_mission_complete.rpc(mission_id, rewards)


# ==============================================================================
# RPC - SYNCHRONISATION ENNEMIS
# ==============================================================================

var _synced_enemies: Dictionary = {}  # enemy_id -> enemy_node

@rpc("authority", "reliable")
func sync_enemy_spawn(enemy_id: String, enemy_type: String, position: Vector3, rotation_y: float) -> void:
	"""
	Synchronise le spawn d'un ennemi.
	@param enemy_id: ID unique de l'ennemi
	@param enemy_type: Type d'ennemi (SecurityRobot, etc.)
	@param position: Position de spawn
	@param rotation_y: Rotation Y initiale
	"""
	if is_server:
		return  # Le serveur crée ses propres ennemis
	
	# Charger et spawner l'ennemi localement
	var scene_path := "res://scenes/enemies/%s.tscn" % enemy_type
	if not ResourceLoader.exists(scene_path):
		push_warning("NetworkManager: Scène ennemi introuvable: " + scene_path)
		return
	
	var enemy_scene := load(scene_path) as PackedScene
	var enemy := enemy_scene.instantiate()
	enemy.name = enemy_id
	enemy.global_position = position
	enemy.rotation.y = rotation_y
	
	# Désactiver l'IA pour les clients (le serveur gère)
	if enemy.has_method("set_ai_enabled"):
		enemy.set_ai_enabled(false)
	
	# Ajouter au monde
	var enemies_container = get_tree().current_scene.get_node_or_null("Enemies")
	if enemies_container:
		enemies_container.add_child(enemy)
	else:
		get_tree().current_scene.add_child(enemy)
	
	_synced_enemies[enemy_id] = enemy


func broadcast_enemy_spawn(enemy_id: String, enemy_type: String, position: Vector3, rotation_y: float) -> void:
	"""Envoie le spawn d'un ennemi aux clients."""
	if is_server:
		sync_enemy_spawn.rpc(enemy_id, enemy_type, position, rotation_y)


@rpc("authority", "unreliable_ordered")
func sync_enemy_state(enemy_id: String, position: Vector3, rotation_y: float, health: float) -> void:
	"""Synchronise l'état d'un ennemi (position, rotation, santé)."""
	if is_server:
		return
	
	if not _synced_enemies.has(enemy_id):
		return
	
	var enemy = _synced_enemies[enemy_id]
	if is_instance_valid(enemy):
		enemy.global_position = position
		enemy.rotation.y = rotation_y
		
		var health_comp = enemy.get_node_or_null("HealthComponent")
		if health_comp:
			health_comp.set_health(health)


@rpc("authority", "reliable")
func sync_enemy_damage(enemy_id: String, damage: float, from_peer: int) -> void:
	"""Synchronise les dégâts infligés à un ennemi."""
	# Sur le serveur, appliquer les dégâts
	if is_server:
		var enemy = _synced_enemies.get(enemy_id)
		if not enemy:
			# Chercher dans le groupe
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.name == enemy_id:
					enemy = e
					break
		
		if enemy and is_instance_valid(enemy):
			var health = enemy.get_node_or_null("HealthComponent")
			if health:
				health.take_damage(damage, null, false)  # false = ne pas re-sync


@rpc("authority", "reliable")
func sync_enemy_death(enemy_id: String) -> void:
	"""Synchronise la mort d'un ennemi."""
	if is_server:
		return
	
	if _synced_enemies.has(enemy_id):
		var enemy = _synced_enemies[enemy_id]
		if is_instance_valid(enemy):
			var health = enemy.get_node_or_null("HealthComponent")
			if health:
				health.is_dead = true
				health.died.emit()
		_synced_enemies.erase(enemy_id)


func broadcast_enemy_death(enemy_id: String) -> void:
	"""Envoie la mort d'un ennemi aux clients."""
	if is_server:
		sync_enemy_death.rpc(enemy_id)
