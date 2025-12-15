# ==============================================================================
# ProjectileManager.gd - Gestion des Projectiles
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère la création, le mouvement et les impacts des projectiles.
# Balistique, homing, ricochet.
# ==============================================================================

extends Node
class_name ProjectileManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal projectile_spawned(projectile: Node3D)
signal projectile_hit(projectile: Node3D, target: Node3D, hit_data: Dictionary)
signal projectile_destroyed(projectile: Node3D)
signal projectile_ricocheted(projectile: Node3D, surface_normal: Vector3)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Pooling")
@export var initial_pool_size: int = 50
@export var max_projectiles: int = 100

@export_group("Physics")
@export var gravity: float = 9.8
@export var air_resistance: float = 0.02

@export_group("Performance")
@export var cull_distance: float = 100.0
@export var max_lifetime: float = 5.0

# ==============================================================================
# PRELOADS
# ==============================================================================

var _projectile_scenes: Dictionary = {}

# ==============================================================================
# VARIABLES
# ==============================================================================

var _active_projectiles: Array[Node3D] = []
var _projectile_pool: Array[Node3D] = []
var _projectile_data: Dictionary = {}  # projectile_id -> data

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_initialize_pool()


func _initialize_pool() -> void:
	"""Initialise le pool de projectiles."""
	for i in range(initial_pool_size):
		var projectile := _create_base_projectile()
		projectile.visible = false
		projectile.set_physics_process(false)
		_projectile_pool.append(projectile)


func _create_base_projectile() -> Node3D:
	"""Crée un projectile de base."""
	var projectile := Node3D.new()
	projectile.name = "Projectile"
	
	# Visual par défaut (sphère lumineuse)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	mesh.mesh = sphere
	
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(1, 0.5, 0)
	material.emission_energy_multiplier = 2.0
	mesh.material_override = material
	
	projectile.add_child(mesh)
	
	# RayCast pour les collisions
	var raycast := RayCast3D.new()
	raycast.name = "RayCast"
	raycast.target_position = Vector3(0, 0, -2)  # Direction forward
	raycast.collision_mask = 1 | 4  # World + Enemy
	projectile.add_child(raycast)
	
	add_child(projectile)
	return projectile


# ==============================================================================
# PROCESS
# ==============================================================================

func _physics_process(delta: float) -> void:
	_update_projectiles(delta)
	_cull_distant_projectiles()


func _update_projectiles(delta: float) -> void:
	"""Met à jour tous les projectiles actifs."""
	for projectile in _active_projectiles.duplicate():
		if not is_instance_valid(projectile):
			_active_projectiles.erase(projectile)
			continue
		
		var data: Dictionary = _projectile_data.get(projectile.get_instance_id(), {})
		if data.is_empty():
			continue
		
		# Mouvement
		_update_projectile_movement(projectile, data, delta)
		
		# Vérifier collision
		_check_projectile_collision(projectile, data)
		
		# Lifetime
		data.lifetime += delta
		if data.lifetime >= max_lifetime:
			_return_to_pool(projectile)


func _update_projectile_movement(projectile: Node3D, data: Dictionary, delta: float) -> void:
	"""Met à jour le mouvement d'un projectile."""
	var velocity: Vector3 = data.velocity
	
	# Homing
	if data.get("is_homing", false) and data.has("target"):
		var target: Node3D = data.target
		if is_instance_valid(target):
			var to_target := (target.global_position - projectile.global_position).normalized()
			var homing_strength: float = data.get("homing_strength", 5.0)
			velocity = velocity.lerp(to_target * velocity.length(), homing_strength * delta)
	
	# Gravité (si affecté)
	if data.get("affected_by_gravity", false):
		velocity.y -= gravity * delta
	
	# Résistance de l'air
	velocity *= (1.0 - air_resistance * delta)
	
	# Appliquer le mouvement
	projectile.global_position += velocity * delta
	data.velocity = velocity
	
	# Orienter vers la direction
	if velocity.length() > 0.1:
		projectile.look_at(projectile.global_position + velocity.normalized())


func _check_projectile_collision(projectile: Node3D, data: Dictionary) -> void:
	"""Vérifie les collisions du projectile."""
	var raycast: RayCast3D = projectile.get_node_or_null("RayCast")
	if not raycast:
		return
	
	# Mettre à jour la direction du raycast
	raycast.target_position = data.velocity.normalized() * 1.0
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider := raycast.get_collider()
		var hit_position := raycast.get_collision_point()
		var hit_normal := raycast.get_collision_normal()
		
		# Ricochet?
		if data.get("ricochets", 0) > 0 and collider.is_in_group("world"):
			_ricochet_projectile(projectile, data, hit_normal)
			return
		
		# Impact
		_handle_projectile_impact(projectile, data, collider, hit_position, hit_normal)


func _ricochet_projectile(projectile: Node3D, data: Dictionary, surface_normal: Vector3) -> void:
	"""Fait ricocher un projectile."""
	var velocity: Vector3 = data.velocity
	data.velocity = velocity.bounce(surface_normal) * 0.8  # 20% de perte
	data.ricochets -= 1
	
	projectile_ricocheted.emit(projectile, surface_normal)


func _handle_projectile_impact(
	projectile: Node3D, 
	data: Dictionary, 
	collider: Node, 
	hit_position: Vector3,
	hit_normal: Vector3
) -> void:
	"""Gère l'impact d'un projectile."""
	var hit_data := {
		"damage": data.get("damage", 10),
		"damage_type": data.get("damage_type", 0),
		"hit_position": hit_position,
		"hit_normal": hit_normal,
		"hit_direction": data.velocity.normalized(),
		"attacker": data.get("owner")
	}
	
	# Appliquer les dégâts si c'est une cible valide
	if collider is Node3D:
		if collider.has_method("take_damage"):
			collider.take_damage(hit_data.damage, hit_data.damage_type)
		
		projectile_hit.emit(projectile, collider, hit_data)
	
	# Effet d'explosion si explosif
	if data.get("is_explosive", false):
		_create_explosion(hit_position, data)
	
	# Retourner au pool
	_return_to_pool(projectile)


func _create_explosion(position: Vector3, data: Dictionary) -> void:
	"""Crée une explosion."""
	var radius: float = data.get("explosion_radius", 5.0)
	var damage: float = data.get("explosion_damage", data.get("damage", 10) * 2)
	
	# Trouver les cibles dans le rayon
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 2 | 4  # Player + Enemy
	
	var results := space_state.intersect_shape(query)
	
	for result in results:
		var collider := result.collider
		if collider is Node3D and collider.has_method("take_damage"):
			var distance := position.distance_to(collider.global_position)
			var falloff := 1.0 - (distance / radius)
			var final_damage := damage * falloff
			collider.take_damage(final_damage, DamageCalculator.DamageType.EXPLOSIVE)


# ==============================================================================
# SPAWNING
# ==============================================================================

func spawn_projectile(config: Dictionary) -> Node3D:
	"""
	Spawn un projectile.
	
	config: {
		position: Vector3,
		direction: Vector3,
		speed: float,
		damage: float,
		damage_type: int,
		owner: Node3D,
		is_homing: bool,
		target: Node3D,
		affected_by_gravity: bool,
		is_explosive: bool,
		explosion_radius: float,
		ricochets: int
	}
	"""
	if _active_projectiles.size() >= max_projectiles:
		return null
	
	var projectile := _get_from_pool()
	if not projectile:
		projectile = _create_base_projectile()
	
	# Configurer
	projectile.global_position = config.get("position", Vector3.ZERO)
	var direction: Vector3 = config.get("direction", Vector3.FORWARD).normalized()
	var speed: float = config.get("speed", 50.0)
	
	projectile.look_at(projectile.global_position + direction)
	projectile.visible = true
	projectile.set_physics_process(true)
	
	# Données
	var data := {
		"velocity": direction * speed,
		"damage": config.get("damage", 10),
		"damage_type": config.get("damage_type", 0),
		"owner": config.get("owner"),
		"is_homing": config.get("is_homing", false),
		"target": config.get("target"),
		"homing_strength": config.get("homing_strength", 5.0),
		"affected_by_gravity": config.get("affected_by_gravity", false),
		"is_explosive": config.get("is_explosive", false),
		"explosion_radius": config.get("explosion_radius", 5.0),
		"explosion_damage": config.get("explosion_damage"),
		"ricochets": config.get("ricochets", 0),
		"lifetime": 0.0
	}
	
	_projectile_data[projectile.get_instance_id()] = data
	_active_projectiles.append(projectile)
	
	projectile_spawned.emit(projectile)
	
	return projectile


# ==============================================================================
# POOLING
# ==============================================================================

func _get_from_pool() -> Node3D:
	"""Récupère un projectile du pool."""
	if _projectile_pool.is_empty():
		return null
	return _projectile_pool.pop_back()


func _return_to_pool(projectile: Node3D) -> void:
	"""Retourne un projectile au pool."""
	if not is_instance_valid(projectile):
		return
	
	var idx := _active_projectiles.find(projectile)
	if idx >= 0:
		_active_projectiles.remove_at(idx)
	
	_projectile_data.erase(projectile.get_instance_id())
	
	projectile.visible = false
	projectile.set_physics_process(false)
	projectile.global_position = Vector3(0, -1000, 0)  # Hors vue
	
	_projectile_pool.append(projectile)
	
	projectile_destroyed.emit(projectile)


func _cull_distant_projectiles() -> void:
	"""Supprime les projectiles trop éloignés."""
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	
	var camera_pos := camera.global_position
	
	for projectile in _active_projectiles.duplicate():
		if projectile.global_position.distance_to(camera_pos) > cull_distance:
			_return_to_pool(projectile)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_active_count() -> int:
	"""Retourne le nombre de projectiles actifs."""
	return _active_projectiles.size()


func get_pool_size() -> int:
	"""Retourne la taille du pool."""
	return _projectile_pool.size()


func clear_all_projectiles() -> void:
	"""Supprime tous les projectiles actifs."""
	for projectile in _active_projectiles.duplicate():
		_return_to_pool(projectile)
