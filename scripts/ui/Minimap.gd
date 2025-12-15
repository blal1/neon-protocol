# ==============================================================================
# Minimap.gd - Mini-carte UI
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Affiche une mini-carte avec joueur, ennemis, et objectifs
# ==============================================================================

extends Control
class_name Minimap

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal marker_clicked(marker_type: String, world_position: Vector3)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Affichage")
@export var map_radius: float = 50.0  ## Rayon visible sur la carte
@export var map_size: float = 150.0  ## Taille UI en pixels
@export var icon_size: float = 8.0

@export_group("Couleurs")
@export var player_color: Color = Color(0, 1, 1)
@export var enemy_color: Color = Color(1, 0.2, 0.2)
@export var ally_color: Color = Color(0.2, 1, 0.4)
@export var objective_color: Color = Color(1, 0.8, 0)
@export var pickup_color: Color = Color(0.8, 0.5, 1)
@export var background_color: Color = Color(0.05, 0.1, 0.15, 0.8)

# ==============================================================================
# VARIABLES
# ==============================================================================
var _player: Node3D = null
var _markers: Dictionary = {}  # node -> marker_data

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
var _background: ColorRect
var _mask: Control
var _markers_container: Control
var _player_icon: ColorRect
var _border: Control

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation de la minimap."""
	_create_ui()
	_find_player()


func _process(_delta: float) -> void:
	"""Mise à jour de la minimap."""
	if not _player:
		_find_player()
		return
	
	_update_markers()


# ==============================================================================
# CRÉATION UI
# ==============================================================================

func _create_ui() -> void:
	"""Crée l'interface de la minimap."""
	custom_minimum_size = Vector2(map_size, map_size)
	
	# Background circulaire
	_background = ColorRect.new()
	_background.color = background_color
	_background.size = Vector2(map_size, map_size)
	add_child(_background)
	
	# Conteneur pour les marqueurs
	_markers_container = Control.new()
	_markers_container.size = Vector2(map_size, map_size)
	_markers_container.clip_contents = true
	add_child(_markers_container)
	
	# Icône du joueur (toujours au centre)
	_player_icon = ColorRect.new()
	_player_icon.color = player_color
	_player_icon.size = Vector2(icon_size * 1.5, icon_size * 1.5)
	_player_icon.position = Vector2(map_size / 2, map_size / 2) - _player_icon.size / 2
	# Rotation pour montrer la direction
	_player_icon.pivot_offset = _player_icon.size / 2
	add_child(_player_icon)
	
	# Bordure
	_border = Control.new()
	_border.size = Vector2(map_size, map_size)
	add_child(_border)
	_border.draw.connect(_draw_border)


func _draw_border() -> void:
	"""Dessine la bordure de la minimap."""
	var center := Vector2(map_size / 2, map_size / 2)
	var radius := map_size / 2 - 2
	
	# Cercle de bordure
	_border.draw_arc(center, radius, 0, TAU, 64, Color(0, 0.8, 0.8, 0.8), 2.0)
	
	# Petits indicateurs cardinaux
	var cardinal_size := 5.0
	_border.draw_line(center + Vector2(0, -radius + cardinal_size), center + Vector2(0, -radius - cardinal_size), Color(0.8, 0.8, 0.8), 2.0)


# ==============================================================================
# MISE À JOUR DES MARQUEURS
# ==============================================================================

func _update_markers() -> void:
	"""Met à jour tous les marqueurs sur la carte."""
	# Rotation du joueur pour la "boussole"
	if _player:
		var player_rotation := 0.0
		var mesh = _player.get_node_or_null("MeshPivot")
		if mesh:
			player_rotation = -mesh.rotation.y
		_player_icon.rotation = player_rotation
	
	# Mettre à jour les ennemis
	_update_group_markers("enemy", enemy_color)
	
	# Mettre à jour les alliés
	_update_group_markers("ally", ally_color)
	
	# Mettre à jour les objectifs
	_update_group_markers("objective", objective_color)
	
	# Mettre à jour les pickups
	_update_group_markers("pickup", pickup_color)


func _update_group_markers(group_name: String, color: Color) -> void:
	"""Met à jour les marqueurs d'un groupe."""
	var nodes := get_tree().get_nodes_in_group(group_name)
	
	for node in nodes:
		if not node is Node3D:
			continue
		
		# Vérifier si le marqueur existe
		if not _markers.has(node):
			_create_marker(node, color, group_name)
		
		# Mettre à jour la position
		_update_marker_position(node)
	
	# Supprimer les marqueurs des nodes disparus
	var to_remove := []
	for node in _markers:
		if not is_instance_valid(node) or not nodes.has(node):
			to_remove.append(node)
	
	for node in to_remove:
		_remove_marker(node)


func _create_marker(node: Node3D, color: Color, marker_type: String) -> void:
	"""Crée un marqueur pour un node."""
	var marker := ColorRect.new()
	marker.color = color
	
	# Taille selon le type
	var size := icon_size
	if marker_type == "objective":
		size = icon_size * 1.5
	
	marker.size = Vector2(size, size)
	marker.pivot_offset = marker.size / 2
	_markers_container.add_child(marker)
	
	_markers[node] = {
		"marker": marker,
		"type": marker_type,
		"color": color
	}


func _update_marker_position(node: Node3D) -> void:
	"""Met à jour la position d'un marqueur."""
	if not _markers.has(node) or not _player:
		return
	
	var marker_data: Dictionary = _markers[node]
	var marker: ColorRect = marker_data["marker"]
	
	# Calculer la position relative au joueur
	var relative_pos: Vector3 = node.global_position - _player.global_position
	
	# Rotation selon l'orientation du joueur
	var player_rotation := 0.0
	var mesh = _player.get_node_or_null("MeshPivot")
	if mesh:
		player_rotation = mesh.rotation.y
	
	# Convertir en 2D (X et Z)
	var pos_2d := Vector2(relative_pos.x, relative_pos.z)
	pos_2d = pos_2d.rotated(-player_rotation)
	
	# Normaliser à la taille de la carte
	var scale_factor := (map_size / 2) / map_radius
	pos_2d *= scale_factor
	
	# Limiter au cercle de la carte
	var distance := pos_2d.length()
	var max_distance := map_size / 2 - icon_size
	if distance > max_distance:
		pos_2d = pos_2d.normalized() * max_distance
	
	# Positionner le marqueur
	marker.position = Vector2(map_size / 2, map_size / 2) + pos_2d - marker.size / 2
	marker.visible = true


func _remove_marker(node: Node3D) -> void:
	"""Supprime un marqueur."""
	if _markers.has(node):
		var marker_data: Dictionary = _markers[node]
		marker_data["marker"].queue_free()
		_markers.erase(node)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func set_map_radius(radius: float) -> void:
	"""Définit le rayon visible de la carte."""
	map_radius = radius


func add_custom_marker(world_position: Vector3, color: Color, marker_id: String) -> void:
	"""Ajoute un marqueur personnalisé."""
	var marker := ColorRect.new()
	marker.color = color
	marker.size = Vector2(icon_size, icon_size)
	marker.pivot_offset = marker.size / 2
	_markers_container.add_child(marker)
	
	# Stocker avec un ID unique
	var fake_node := RefCounted.new()
	fake_node.set_meta("world_position", world_position)
	fake_node.set_meta("marker_id", marker_id)
	
	_markers[fake_node] = {
		"marker": marker,
		"type": "custom",
		"color": color,
		"world_position": world_position
	}


func clear_markers() -> void:
	"""Supprime tous les marqueurs."""
	for node in _markers:
		_markers[node]["marker"].queue_free()
	_markers.clear()
