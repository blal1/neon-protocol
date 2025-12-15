# ==============================================================================
# HitboxManager.gd - Gestion des Hitboxes de Combat
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les collisions physiques de combat.
# Hitboxes (infliger dégâts) et Hurtboxes (recevoir dégâts).
# ==============================================================================

extends Node
class_name HitboxManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal hitbox_connected(hitbox: Area3D, hurtbox: Area3D, hit_data: Dictionary)
signal hurtbox_hit(hurtbox: Area3D, damage_data: Dictionary)
signal parry_occurred(attacker: Node3D, defender: Node3D)
signal block_occurred(attacker: Node3D, defender: Node3D, damage_reduced: float)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Layers")
@export var hitbox_layer: int = 8
@export var hurtbox_layer: int = 9

@export_group("I-Frames")
@export var default_iframes_duration: float = 0.1
@export var dodge_iframes_duration: float = 0.3

@export_group("Debug")
@export var show_hitboxes: bool = false
@export var hitbox_color: Color = Color.RED
@export var hurtbox_color: Color = Color.GREEN

# ==============================================================================
# VARIABLES
# ==============================================================================

## Hitboxes actives
var _active_hitboxes: Array[Area3D] = []

## Hurtboxes enregistrées
var _registered_hurtboxes: Dictionary = {}  # owner_id -> hurtbox

## I-frames tracking
var _iframes: Dictionary = {}  # owner_id -> end_time

## Hit tracking (pour éviter multi-hits)
var _hit_tracking: Dictionary = {}  # hitbox_id -> [hit_hurtbox_ids]

# ==============================================================================
# CRÉATION DE HITBOXES
# ==============================================================================

func create_hitbox(
	parent: Node3D,
	shape: Shape3D,
	damage_data: Dictionary,
	duration: float = 0.2
) -> Area3D:
	"""Crée une hitbox temporaire."""
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox_%d" % randi()
	hitbox.collision_layer = hitbox_layer
	hitbox.collision_mask = hurtbox_layer
	hitbox.monitoring = true
	hitbox.monitorable = false
	
	# Collision shape
	var collision := CollisionShape3D.new()
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Stocker les données
	hitbox.set_meta("damage_data", damage_data)
	hitbox.set_meta("owner", parent)
	hitbox.set_meta("hit_entities", [])
	
	# Debug visual
	if show_hitboxes:
		_add_debug_visual(hitbox, shape, hitbox_color)
	
	parent.add_child(hitbox)
	_active_hitboxes.append(hitbox)
	_hit_tracking[hitbox.get_instance_id()] = []
	
	# Connexions
	hitbox.area_entered.connect(_on_hitbox_area_entered.bind(hitbox))
	
	# Timer de destruction
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(_destroy_hitbox.bind(hitbox))
	
	return hitbox


func create_projectile_hitbox(projectile: Node3D, radius: float, damage_data: Dictionary) -> Area3D:
	"""Crée une hitbox permanente pour un projectile."""
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	
	var hitbox := Area3D.new()
	hitbox.name = "ProjectileHitbox"
	hitbox.collision_layer = hitbox_layer
	hitbox.collision_mask = hurtbox_layer
	
	var collision := CollisionShape3D.new()
	collision.shape = sphere
	hitbox.add_child(collision)
	
	hitbox.set_meta("damage_data", damage_data)
	hitbox.set_meta("owner", projectile)
	hitbox.set_meta("is_projectile", true)
	
	projectile.add_child(hitbox)
	
	hitbox.area_entered.connect(_on_projectile_hit.bind(hitbox, projectile))
	
	return hitbox


func _destroy_hitbox(hitbox: Area3D) -> void:
	"""Détruit une hitbox."""
	var idx := _active_hitboxes.find(hitbox)
	if idx >= 0:
		_active_hitboxes.remove_at(idx)
	
	_hit_tracking.erase(hitbox.get_instance_id())
	
	if is_instance_valid(hitbox):
		hitbox.queue_free()


# ==============================================================================
# CRÉATION DE HURTBOXES
# ==============================================================================

func create_hurtbox(
	parent: Node3D,
	shape: Shape3D,
	on_hit_callback: Callable = Callable()
) -> Area3D:
	"""Crée une hurtbox pour un personnage."""
	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = hurtbox_layer
	hurtbox.collision_mask = hitbox_layer
	hurtbox.monitoring = false
	hurtbox.monitorable = true
	
	var collision := CollisionShape3D.new()
	collision.shape = shape
	hurtbox.add_child(collision)
	
	hurtbox.set_meta("owner", parent)
	hurtbox.set_meta("on_hit_callback", on_hit_callback)
	
	if show_hitboxes:
		_add_debug_visual(hurtbox, shape, hurtbox_color)
	
	parent.add_child(hurtbox)
	_registered_hurtboxes[parent.get_instance_id()] = hurtbox
	
	return hurtbox


func remove_hurtbox(parent: Node3D) -> void:
	"""Supprime la hurtbox d'un personnage."""
	var owner_id := parent.get_instance_id()
	if _registered_hurtboxes.has(owner_id):
		var hurtbox: Area3D = _registered_hurtboxes[owner_id]
		if is_instance_valid(hurtbox):
			hurtbox.queue_free()
		_registered_hurtboxes.erase(owner_id)


# ==============================================================================
# GESTION DES COLLISIONS
# ==============================================================================

func _on_hitbox_area_entered(area: Area3D, hitbox: Area3D) -> void:
	"""Callback quand une hitbox touche une hurtbox."""
	if not area.has_meta("owner"):
		return
	
	var hitbox_id := hitbox.get_instance_id()
	var hurtbox_id := area.get_instance_id()
	
	# Vérifier si déjà touché
	if _hit_tracking.has(hitbox_id):
		if hurtbox_id in _hit_tracking[hitbox_id]:
			return
		_hit_tracking[hitbox_id].append(hurtbox_id)
	
	var hitbox_owner: Node3D = hitbox.get_meta("owner")
	var hurtbox_owner: Node3D = area.get_meta("owner")
	
	# Ne pas se toucher soi-même
	if hitbox_owner == hurtbox_owner:
		return
	
	# Vérifier i-frames
	if _has_iframes(hurtbox_owner):
		return
	
	var damage_data: Dictionary = hitbox.get_meta("damage_data")
	
	# Vérifier block/parry
	if _check_block_parry(hitbox_owner, hurtbox_owner, damage_data):
		return
	
	# Calculer les données de hit
	var hit_data := _calculate_hit_data(hitbox, area, damage_data)
	
	hitbox_connected.emit(hitbox, area, hit_data)
	hurtbox_hit.emit(area, hit_data)
	
	# Appeler le callback si défini
	if area.has_meta("on_hit_callback"):
		var callback: Callable = area.get_meta("on_hit_callback")
		if callback.is_valid():
			callback.call(hit_data)


func _on_projectile_hit(area: Area3D, hitbox: Area3D, projectile: Node3D) -> void:
	"""Callback spécial pour les projectiles."""
	_on_hitbox_area_entered(area, hitbox)
	
	# Détruire le projectile après impact
	if is_instance_valid(projectile):
		projectile.queue_free()


func _calculate_hit_data(hitbox: Area3D, hurtbox: Area3D, damage_data: Dictionary) -> Dictionary:
	"""Calcule les données de hit."""
	var hitbox_owner: Node3D = hitbox.get_meta("owner")
	var hurtbox_owner: Node3D = hurtbox.get_meta("owner")
	
	var hit_direction := (hurtbox.global_position - hitbox.global_position).normalized()
	var hit_position := hurtbox.global_position
	
	# Déterminer la partie du corps touchée
	var body_part := _determine_body_part(hitbox.global_position, hurtbox)
	
	# Vérifier backstab
	var is_backstab := false
	if hurtbox_owner.has_method("get_forward_direction"):
		var forward: Vector3 = hurtbox_owner.get_forward_direction()
		is_backstab = hit_direction.dot(forward) > 0.5
	
	return {
		"attacker": hitbox_owner,
		"defender": hurtbox_owner,
		"damage": damage_data.get("damage", 10),
		"damage_type": damage_data.get("type", 0),
		"hit_position": hit_position,
		"hit_direction": hit_direction,
		"body_part": body_part,
		"is_backstab": is_backstab,
		"knockback": damage_data.get("knockback", 0.0),
		"stun_duration": damage_data.get("stun_duration", 0.2)
	}


func _determine_body_part(hit_pos: Vector3, hurtbox: Area3D) -> int:
	"""Détermine la partie du corps touchée."""
	var hurtbox_owner: Node3D = hurtbox.get_meta("owner")
	var owner_pos := hurtbox_owner.global_position
	
	var relative_height := hit_pos.y - owner_pos.y
	
	if relative_height > 1.5:
		return DamageCalculator.BodyPart.HEAD
	elif relative_height > 0.8:
		return DamageCalculator.BodyPart.TORSO
	elif relative_height > 0.3:
		return DamageCalculator.BodyPart.ARMS
	else:
		return DamageCalculator.BodyPart.LEGS


# ==============================================================================
# BLOCK & PARRY
# ==============================================================================

func _check_block_parry(attacker: Node3D, defender: Node3D, damage_data: Dictionary) -> bool:
	"""Vérifie si l'attaque est bloquée ou parée."""
	if not defender.has_method("is_blocking") or not defender.has_method("is_parrying"):
		return false
	
	# Parry (timing parfait)
	if defender.is_parrying():
		parry_occurred.emit(attacker, defender)
		
		# Le parry peut stun l'attaquant
		if attacker.has_method("receive_stun"):
			attacker.receive_stun(0.5)
		
		return true
	
	# Block
	if defender.is_blocking():
		var full_damage: float = damage_data.get("damage", 10)
		var block_efficiency: float = defender.get_block_efficiency() if defender.has_method("get_block_efficiency") else 0.5
		var reduced_damage := full_damage * (1.0 - block_efficiency)
		
		block_occurred.emit(attacker, defender, full_damage - reduced_damage)
		
		# Appliquer les dégâts réduits
		if defender.has_method("take_damage"):
			defender.take_damage(reduced_damage, damage_data.get("type", 0))
		
		return true
	
	return false


# ==============================================================================
# I-FRAMES
# ==============================================================================

func grant_iframes(entity: Node3D, duration: float = -1.0) -> void:
	"""Accorde des i-frames à une entité."""
	if duration < 0:
		duration = default_iframes_duration
	
	var end_time := Time.get_ticks_msec() / 1000.0 + duration
	_iframes[entity.get_instance_id()] = end_time


func _has_iframes(entity: Node3D) -> bool:
	"""Vérifie si une entité a des i-frames."""
	var owner_id := entity.get_instance_id()
	if not _iframes.has(owner_id):
		return false
	
	var current_time := Time.get_ticks_msec() / 1000.0
	var end_time: float = _iframes[owner_id]
	
	if current_time >= end_time:
		_iframes.erase(owner_id)
		return false
	
	return true


func clear_iframes(entity: Node3D) -> void:
	"""Supprime les i-frames d'une entité."""
	_iframes.erase(entity.get_instance_id())


# ==============================================================================
# DEBUG
# ==============================================================================

func _add_debug_visual(area: Area3D, shape: Shape3D, color: Color) -> void:
	"""Ajoute un visuel de debug."""
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DebugMesh"
	
	if shape is SphereShape3D:
		var sphere := SphereMesh.new()
		sphere.radius = shape.radius
		mesh_instance.mesh = sphere
	elif shape is BoxShape3D:
		var box := BoxMesh.new()
		box.size = shape.size
		mesh_instance.mesh = box
	elif shape is CapsuleShape3D:
		var capsule := CapsuleMesh.new()
		capsule.radius = shape.radius
		capsule.height = shape.height
		mesh_instance.mesh = capsule
	
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.3
	mesh_instance.material_override = material
	
	area.add_child(mesh_instance)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_active_hitbox_count() -> int:
	"""Retourne le nombre de hitboxes actives."""
	return _active_hitboxes.size()


func get_registered_hurtbox_count() -> int:
	"""Retourne le nombre de hurtboxes enregistrées."""
	return _registered_hurtboxes.size()


func clear_all_hitboxes() -> void:
	"""Supprime toutes les hitboxes actives."""
	for hitbox in _active_hitboxes.duplicate():
		_destroy_hitbox(hitbox)
