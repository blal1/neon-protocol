# ==============================================================================
# DistanceCuller.gd - Système de Culling par Distance (LOD Simple)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Désactive les objets éloignés pour sauver la batterie mobile
# Alternative légère à l'Occlusion Culling (qui nécessite des baked data)
# ==============================================================================

extends Node
class_name DistanceCuller

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export_group("Distances")
@export var cull_distance: float = 50.0  ## Distance de désactivation (mètres)
@export var hysteresis: float = 5.0  ## Marge anti-flickering
## Note: Un objet à 50m sera désactivé, mais réactivé seulement à 45m

@export_group("Performance")
@export var update_interval: float = 0.2  ## Intervalle de mise à jour (secondes)
@export var objects_per_frame: int = 20  ## Objets traités par frame (évite les spikes)

@export_group("Cible")
@export var player: Node3D  ## Référence au joueur
@export var target_group: String = "cullable"  ## Groupe des objets à gérer

@export_group("Debug")
@export var show_debug: bool = false  ## Afficher les stats en console

# ==============================================================================
# VARIABLES INTERNES
# ==============================================================================
var _tracked_objects: Array[Node3D] = []
var _timer: float = 0.0
var _current_index: int = 0
var _stats_visible: int = 0
var _stats_hidden: int = 0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	# Trouver le joueur automatiquement
	if not player:
		await get_tree().process_frame
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0] as Node3D
	
	# Collecter les objets à gérer
	_collect_cullable_objects()
	
	# S'abonner aux nouveaux objets ajoutés
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _collect_cullable_objects() -> void:
	"""Collecte tous les objets dans le groupe cible."""
	_tracked_objects.clear()
	
	for node in get_tree().get_nodes_in_group(target_group):
		if node is Node3D:
			_tracked_objects.append(node)
	
	if show_debug:
		print("DistanceCuller: %d objets trackés" % _tracked_objects.size())


# ==============================================================================
# MISE À JOUR
# ==============================================================================

func _process(delta: float) -> void:
	if not player or _tracked_objects.is_empty():
		return
	
	_timer += delta
	
	if _timer < update_interval:
		return
	
	_timer = 0.0
	_update_culling()


func _update_culling() -> void:
	"""Met à jour la visibilité des objets par lots."""
	var player_pos := player.global_position
	var processed := 0
	
	_stats_visible = 0
	_stats_hidden = 0
	
	# Traiter un lot d'objets par frame
	while processed < objects_per_frame and processed < _tracked_objects.size():
		var obj := _tracked_objects[_current_index]
		
		if is_instance_valid(obj):
			_update_object_visibility(obj, player_pos)
		
		# Index circulaire
		_current_index = (_current_index + 1) % _tracked_objects.size()
		processed += 1
	
	if show_debug and processed > 0:
		print("DistanceCuller: %d visible, %d hidden" % [_stats_visible, _stats_hidden])


func _update_object_visibility(obj: Node3D, player_pos: Vector3) -> void:
	"""Met à jour la visibilité d'un objet unique."""
	var distance := obj.global_position.distance_to(player_pos)
	var is_visible := obj.visible
	
	# Hysteresis : évite le flickering aux limites
	if is_visible:
		# Visible -> Hidden si au-delà de cull_distance
		if distance > cull_distance:
			_set_object_active(obj, false)
			_stats_hidden += 1
		else:
			_stats_visible += 1
	else:
		# Hidden -> Visible si en dessous de (cull_distance - hysteresis)
		if distance < cull_distance - hysteresis:
			_set_object_active(obj, true)
			_stats_visible += 1
		else:
			_stats_hidden += 1


func _set_object_active(obj: Node3D, active: bool) -> void:
	"""Active ou désactive un objet (équivalent SetActive Unity)."""
	# Méthode 1 : Visibilité simple
	obj.visible = active
	
	# Méthode 2 : Désactiver aussi le process (économise CPU)
	obj.set_process(active)
	obj.set_physics_process(active)
	
	# Optionnel : Notifier l'objet
	if obj.has_method("on_culling_changed"):
		obj.on_culling_changed(active)


# ==============================================================================
# GESTION DYNAMIQUE DES OBJETS
# ==============================================================================

func _on_node_added(node: Node) -> void:
	"""Appelé quand un nouveau node est ajouté à la scène."""
	if node is Node3D and node.is_in_group(target_group):
		if not _tracked_objects.has(node):
			_tracked_objects.append(node)


func _on_node_removed(node: Node) -> void:
	"""Appelé quand un node est retiré de la scène."""
	if node in _tracked_objects:
		_tracked_objects.erase(node)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func register_object(obj: Node3D) -> void:
	"""Ajoute manuellement un objet au système de culling."""
	if obj and not _tracked_objects.has(obj):
		_tracked_objects.append(obj)
		obj.add_to_group(target_group)


func unregister_object(obj: Node3D) -> void:
	"""Retire un objet du système de culling."""
	_tracked_objects.erase(obj)


func set_cull_distance(distance: float) -> void:
	"""Change la distance de culling (pour paramètres graphiques)."""
	cull_distance = max(10.0, distance)


func force_update() -> void:
	"""Force une mise à jour complète immédiate."""
	if not player:
		return
	
	var player_pos := player.global_position
	
	for obj in _tracked_objects:
		if is_instance_valid(obj):
			_update_object_visibility(obj, player_pos)


func get_visible_count() -> int:
	"""Retourne le nombre d'objets actuellement visibles."""
	var count := 0
	for obj in _tracked_objects:
		if is_instance_valid(obj) and obj.visible:
			count += 1
	return count


func get_total_count() -> int:
	"""Retourne le nombre total d'objets trackés."""
	return _tracked_objects.size()
