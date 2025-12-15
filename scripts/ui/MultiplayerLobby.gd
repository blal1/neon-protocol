# ==============================================================================
# MultiplayerLobby.gd - Contrôleur du lobby multijoueur
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère l'interface du lobby et les actions host/join
# ==============================================================================

extends Control

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
@onready var name_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ConfigSection/NameHBox/NameInput
@onready var ip_input: LineEdit = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ConfigSection/IPHBox/IPInput
@onready var port_input: SpinBox = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ConfigSection/PortHBox/PortInput

@onready var host_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonsHBox/HostButton
@onready var join_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonsHBox/JoinButton

@onready var players_list: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/PlayersList
@onready var no_players_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/PlayersList/NoPlayersLabel
@onready var status_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StatusLabel

@onready var ready_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomHBox/ReadyButton
@onready var start_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomHBox/StartButton
@onready var disconnect_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomHBox/DisconnectButton
@onready var back_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BackButton

@onready var config_section: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ConfigSection

# ==============================================================================
# VARIABLES
# ==============================================================================
var _player_items: Dictionary = {}  # peer_id -> Control

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du lobby."""
	# Connecter les boutons
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	ready_button.toggled.connect(_on_ready_toggled)
	start_button.pressed.connect(_on_start_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Connecter les signaux du NetworkManager
	var network = get_node_or_null("/root/NetworkManager")
	if network:
		network.player_connected.connect(_on_player_connected)
		network.player_disconnected.connect(_on_player_disconnected)
		network.connection_succeeded.connect(_on_connection_succeeded)
		network.connection_failed.connect(_on_connection_failed)
		network.server_disconnected.connect(_on_server_disconnected)
		network.game_started.connect(_on_game_started)
	
	# Charger le pseudo depuis save
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("get_setting"):
		name_input.text = save.get_setting("player_name", "Runner_%d" % randi_range(100, 999))


# ==============================================================================
# CALLBACKS BOUTONS
# ==============================================================================

func _on_host_pressed() -> void:
	"""Héberge une partie."""
	_apply_player_name()
	
	var network = get_node_or_null("/root/NetworkManager")
	if not network:
		_set_status("Erreur: NetworkManager non trouvé", Color.RED)
		return
	
	var port := int(port_input.value)
	var error := network.host_game(port)
	
	if error == OK:
		_set_status("Serveur créé sur le port %d" % port, Color.GREEN)
		_set_lobby_mode(true, true)
	else:
		_set_status("Erreur lors de la création du serveur", Color.RED)


func _on_join_pressed() -> void:
	"""Rejoint une partie."""
	_apply_player_name()
	
	var network = get_node_or_null("/root/NetworkManager")
	if not network:
		_set_status("Erreur: NetworkManager non trouvé", Color.RED)
		return
	
	var ip := ip_input.text.strip_edges()
	var port := int(port_input.value)
	
	if ip.is_empty():
		_set_status("Veuillez entrer une adresse IP", Color.YELLOW)
		return
	
	var error := network.join_game(ip, port)
	
	if error == OK:
		_set_status("Connexion en cours...", Color.YELLOW)
	else:
		_set_status("Impossible de se connecter", Color.RED)


func _on_ready_toggled(is_ready: bool) -> void:
	"""Bascule l'état prêt."""
	var network = get_node_or_null("/root/NetworkManager")
	if network:
		network.set_player_ready(is_ready)
	
	ready_button.text = "✓ PRÊT!" if is_ready else "✓ PRÊT"
	
	# Vérifier si tous sont prêts (serveur seulement)
	if network and network.is_host():
		start_button.disabled = not network.are_all_ready()


func _on_start_pressed() -> void:
	"""Démarre la partie (hôte seulement)."""
	var network = get_node_or_null("/root/NetworkManager")
	if network and network.is_host():
		network.start_multiplayer_game()
		_set_status("Lancement de la partie...", Color.CYAN)


func _on_disconnect_pressed() -> void:
	"""Se déconnecte du serveur."""
	var network = get_node_or_null("/root/NetworkManager")
	if network:
		network.disconnect_from_game()
	
	_reset_lobby()
	_set_status("Déconnecté", Color.GRAY)


func _on_back_pressed() -> void:
	"""Retourne au menu principal."""
	var network = get_node_or_null("/root/NetworkManager")
	if network and network.is_connected:
		network.disconnect_from_game()
	
	# Retourner au menu
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


# ==============================================================================
# CALLBACKS RÉSEAU
# ==============================================================================

func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	"""Appelé quand un joueur se connecte."""
	_add_player_to_list(peer_id, player_info)
	_set_status("Joueur connecté: %s" % player_info.get("name", "???"), Color.GREEN)


func _on_player_disconnected(peer_id: int) -> void:
	"""Appelé quand un joueur se déconnecte."""
	_remove_player_from_list(peer_id)
	_set_status("Un joueur a quitté", Color.ORANGE)


func _on_connection_succeeded() -> void:
	"""Connexion réussie."""
	_set_status("Connecté au serveur!", Color.GREEN)
	_set_lobby_mode(true, false)


func _on_connection_failed() -> void:
	"""Connexion échouée."""
	_set_status("Connexion échouée", Color.RED)
	_reset_lobby()


func _on_server_disconnected() -> void:
	"""Serveur déconnecté."""
	_set_status("Serveur déconnecté", Color.RED)
	_reset_lobby()


func _on_game_started() -> void:
	"""La partie démarre."""
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


# ==============================================================================
# GESTION UI
# ==============================================================================

func _set_status(text: String, color: Color = Color.WHITE) -> void:
	"""Met à jour le label de statut."""
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak(text)


func _set_lobby_mode(connected: bool, is_host: bool) -> void:
	"""Configure le mode lobby (connecté/déconnecté, hôte/client)."""
	# Masquer/afficher les éléments
	config_section.visible = not connected
	host_button.visible = not connected
	join_button.visible = not connected
	back_button.visible = not connected
	
	ready_button.visible = connected
	disconnect_button.visible = connected
	start_button.visible = connected and is_host
	
	if is_host:
		start_button.disabled = true  # Attendre que tous soient prêts
	
	# Rafraîchir la liste des joueurs
	_refresh_players_list()


func _reset_lobby() -> void:
	"""Réinitialise le lobby."""
	_set_lobby_mode(false, false)
	_clear_players_list()


func _add_player_to_list(peer_id: int, info: Dictionary) -> void:
	"""Ajoute un joueur à la liste."""
	if _player_items.has(peer_id):
		return
	
	no_players_label.visible = false
	
	var item := HBoxContainer.new()
	item.name = "Player_" + str(peer_id)
	
	# Indicateur couleur
	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(20, 20)
	color_rect.color = info.get("color", Color.WHITE)
	item.add_child(color_rect)
	
	# Nom
	var name_label := Label.new()
	name_label.text = info.get("name", "Joueur " + str(peer_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(name_label)
	
	# Statut prêt
	var ready_label := Label.new()
	ready_label.text = "✓" if info.get("ready", false) else "○"
	ready_label.add_theme_color_override("font_color", Color.GREEN if info.get("ready", false) else Color.GRAY)
	item.add_child(ready_label)
	
	players_list.add_child(item)
	_player_items[peer_id] = item


func _remove_player_from_list(peer_id: int) -> void:
	"""Retire un joueur de la liste."""
	if _player_items.has(peer_id):
		_player_items[peer_id].queue_free()
		_player_items.erase(peer_id)
	
	if _player_items.is_empty():
		no_players_label.visible = true


func _clear_players_list() -> void:
	"""Vide la liste des joueurs."""
	for item in _player_items.values():
		item.queue_free()
	_player_items.clear()
	no_players_label.visible = true


func _refresh_players_list() -> void:
	"""Rafraîchit la liste des joueurs."""
	_clear_players_list()
	
	var network = get_node_or_null("/root/NetworkManager")
	if network:
		for peer_id in network.players_info:
			_add_player_to_list(peer_id, network.players_info[peer_id])


func _apply_player_name() -> void:
	"""Applique le pseudo au NetworkManager."""
	var network = get_node_or_null("/root/NetworkManager")
	if network:
		var player_name := name_input.text.strip_edges()
		if player_name.is_empty():
			player_name = "Runner_%d" % randi_range(100, 999)
		network.set_player_name(player_name)
	
	# Sauvegarder
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("set_setting"):
		save.set_setting("player_name", name_input.text)
