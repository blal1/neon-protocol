# ==============================================================================
# LODManager.gd - Système LOD (Level of Detail) Simple
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Alterne entre différents niveaux de détail selon la distance
# Plus sophistiqué que le simple culling, mais reste léger
# ==============================================================================

extends Node
class_name LODManager

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export_group("Distances LOD")
@export var lod0_distance: float = 20.0  ## Haute qualité (0-20m)
@export var lod1_distance: float = 40.0  ## Qualité moyenne (20-40m)
@export var lod2_distance: float = 60.0  ## Basse qualité (40-60m)
## Au-delà de lod2_distance : objet désactivé

@export_group("Performance")
@export var update_interval: float = 0.25  ## Intervalle de mise à jour
@export var batch_size: int = 15  ## Objets traités par frame

@export_group("Références")
@export var player: Node3D

# ==============================================================================
# CLASSES INTERNES
# ==============================================================================

class LODObject:
	var node: Node3D
	var lod_meshes: Array[MeshInstance3D]  # [LOD0, LOD1, LOD2]
	var current_lod: int = 0
	
	func _init(n: Node3D) -> void:
		node = n
		_find_lod_meshes()
	
	func _find_lod_meshes() -> void:
		"""Cherche les enfants nommés LOD0, LOD1, LOD2."""
		lod_meshes.clear()
		for i in range(3):
			var lod_node := node.get_node_or_null("LOD%d" % i) as MeshInstance3D
			if lod_node:
				lod_meshes.append(lod_node)
			else:
				lod_meshes.append(null)
	
	func set_lod_level(level: int) -> void:
		"""Active uniquement le mesh du niveau LOD spécifié."""
		if level == current_lod:
			return
		
		current_lod = level
		
		for i in range(lod_meshes.size()):
			if lod_meshes[i]:
				lod_meshes[i].visible = (i == level)
	
	func set_visible(visible: bool) -> void:
		"""Active/désactive complètement l'objet."""
		node.visible = visible
		node.set_process(visible)
		node.set_physics_process(visible)

# ==============================================================================
# VARIABLES
# ==============================================================================
var _lod_objects: Array[LODObject] = []
var _timer: float = 0.0
var _current_index: int = 0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	if not player:
		await get_tree().process_frame
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0] as Node3D
	
	_collect_lod_objects()


func _collect_lod_objects() -> void:
	"""Collecte tous les objets avec des meshes LOD."""
	_lod_objects.clear()
	
	for node in get_tree().get_nodes_in_group("lod_object"):
		if node is Node3D:
			var lod_obj := LODObject.new(node)
			_lod_objects.append(lod_obj)
	
	print("LODManager: %d objets LOD trackés" % _lod_objects.size())


# ==============================================================================
# MISE À JOUR
# ==============================================================================

func _process(delta: float) -> void:
	if not player or _lod_objects.is_empty():
		return
	
	_timer += delta
	if _timer < update_interval:
		return
	
	_timer = 0.0
	_update_lod_batch()


func _update_lod_batch() -> void:
	"""Met à jour un lot d'objets LOD."""
	var player_pos := player.global_position
	var processed := 0
	
	while processed < batch_size and processed < _lod_objects.size():
		var lod_obj := _lod_objects[_current_index]
		
		if is_instance_valid(lod_obj.node):
			var distance := lod_obj.node.global_position.distance_to(player_pos)
			
			# Déterminer le niveau LOD
			if distance > lod2_distance:
				lod_obj.set_visible(false)
			else:
				lod_obj.set_visible(true)
				
				if distance <= lod0_distance:
					lod_obj.set_lod_level(0)
				elif distance <= lod1_distance:
					lod_obj.set_lod_level(1)
				else:
					lod_obj.set_lod_level(2)
		
		_current_index = (_current_index + 1) % _lod_objects.size()
		processed += 1


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func register_lod_object(node: Node3D) -> void:
	"""Enregistre un nouvel objet LOD."""
	var lod_obj := LODObject.new(node)
	_lod_objects.append(lod_obj)


func set_quality_preset(preset: String) -> void:
	"""Applique un preset de qualité graphique."""
	match preset:
		"low":
			lod0_distance = 10.0
			lod1_distance = 25.0
			lod2_distance = 40.0
		"medium":
			lod0_distance = 20.0
			lod1_distance = 40.0
			lod2_distance = 60.0
		"high":
			lod0_distance = 35.0
			lod1_distance = 60.0
			lod2_distance = 100.0
