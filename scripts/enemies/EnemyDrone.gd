# ==============================================================================
# EnemyDrone.gd - Ennemi Drone volant
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Drone de surveillance avec attaques à distance
# ==============================================================================

extends CharacterBody3D
class_name EnemyDrone

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal target_acquired(target: Node3D)
signal target_lost
signal attack_fired
signal destroyed

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum State { IDLE, PATROL, CHASE, ATTACK, RETREAT, DISABLED }

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Mouvement")
@export var hover_height: float = 3.0
@export var move_speed: float = 5.0
@export var rotation_speed: float = 3.0
@export var bob_amount: float = 0.3
@export var bob_speed: float = 2.0

@export_group("Combat")
@export var detection_range: float = 15.0
@export var attack_range: float = 12.0
@export var attack_cooldown: float = 2.0
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 20.0

@export_group("Patrouille")
@export var patrol_radius: float = 8.0
@export var patrol_wait_time: float = 2.0

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_state: State = State.IDLE
var player_ref: Node3D = null
var can_attack: bool = true
var _patrol_point: Vector3
var _bob_time: float = 0.0
var _base_y: float = 0.0

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var health_component: Node = $HealthComponent if has_node("HealthComponent") else null
@onready var mesh_pivot: Node3D = $MeshPivot if has_node("MeshPivot") else null
@onready var detection_area: Area3D = $DetectionArea if has_node("DetectionArea") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	add_to_group("enemy")
	_base_y = global_position.y + hover_height
	_patrol_point = global_position
	
	# Trouver le joueur
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
	
	# Créer les composants manquants
	if not detection_area:
		_create_detection_area()
	
	if not health_component:
		_create_health_component()
	
	# Connecter le signal de mort
	if health_component:
		health_component.died.connect(_on_died)
	
	current_state = State.PATROL


func _physics_process(delta: float) -> void:
	"""Mise à jour physique."""
	# Bob effect
	_bob_time += delta * bob_speed
	var bob_offset := sin(_bob_time) * bob_amount
	
	# Maintenir la hauteur de vol
	var target_y := _base_y + bob_offset
	global_position.y = lerp(global_position.y, target_y, 5.0 * delta)
	
	# Machine à états
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RETREAT:
			_state_retreat(delta)
		State.DISABLED:
			pass
	
	move_and_slide()


# ==============================================================================
# ÉTATS
# ==============================================================================

func _state_idle(delta: float) -> void:
	"""État d'attente."""
	if _is_player_visible():
		current_state = State.CHASE
		target_acquired.emit(player_ref)


func _state_patrol(delta: float) -> void:
	"""Patrouille autour du point d'origine."""
	# Vérifier si le joueur est visible
	if _is_player_visible():
		current_state = State.CHASE
		target_acquired.emit(player_ref)
		return
	
	# Se déplacer vers le point de patrouille
	var to_target := _patrol_point - global_position
	to_target.y = 0
	
	if to_target.length() < 1.0:
		# Nouveau point de patrouille
		await get_tree().create_timer(patrol_wait_time).timeout
		_generate_patrol_point()
	else:
		var direction := to_target.normalized()
		velocity = direction * move_speed * 0.5
		_rotate_toward(direction, delta)


func _state_chase(delta: float) -> void:
	"""Poursuite du joueur."""
	if not player_ref or not is_instance_valid(player_ref):
		current_state = State.PATROL
		target_lost.emit()
		return
	
	var distance := global_position.distance_to(player_ref.global_position)
	
	# Perdu le joueur
	if distance > detection_range * 1.5:
		current_state = State.PATROL
		target_lost.emit()
		return
	
	# À portée d'attaque
	if distance <= attack_range:
		current_state = State.ATTACK
		return
	
	# Se rapprocher
	var to_player := player_ref.global_position - global_position
	to_player.y = 0
	var direction := to_player.normalized()
	
	velocity = direction * move_speed
	_rotate_toward(direction, delta)


func _state_attack(delta: float) -> void:
	"""Attaque le joueur."""
	if not player_ref or not is_instance_valid(player_ref):
		current_state = State.PATROL
		return
	
	var distance := global_position.distance_to(player_ref.global_position)
	
	# Hors de portée
	if distance > attack_range * 1.2:
		current_state = State.CHASE
		return
	
	# Regarder le joueur
	var to_player := player_ref.global_position - global_position
	to_player.y = 0
	_rotate_toward(to_player.normalized(), delta)
	
	# Tirer si possible
	if can_attack:
		_fire_projectile()
	
	# Rester à distance
	if distance < attack_range * 0.5:
		velocity = -to_player.normalized() * move_speed * 0.5
	else:
		velocity = Vector3.ZERO


func _state_retreat(delta: float) -> void:
	"""Retraite stratégique."""
	if not player_ref:
		current_state = State.PATROL
		return
	
	var away_from_player := (global_position - player_ref.global_position).normalized()
	away_from_player.y = 0
	
	velocity = away_from_player * move_speed
	_rotate_toward(-away_from_player, delta)
	
	# Reprendre l'attaque si assez loin
	if global_position.distance_to(player_ref.global_position) > attack_range * 0.8:
		current_state = State.ATTACK


# ==============================================================================
# COMBAT
# ==============================================================================

func _fire_projectile() -> void:
	"""Tire un projectile."""
	can_attack = false
	attack_fired.emit()
	
	# Créer le projectile
	var projectile := _create_projectile()
	get_tree().current_scene.add_child(projectile)
	
	# Son de tir
	if audio_player:
		audio_player.play()
	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _create_projectile() -> Node3D:
	"""Crée un projectile simple."""
	var projectile := CharacterBody3D.new()
	projectile.global_position = global_position + Vector3(0, -0.5, 0)
	
	# Direction vers le joueur
	var direction := Vector3.ZERO
	if player_ref:
		direction = (player_ref.global_position - projectile.global_position).normalized()
	
	# Mesh
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh.mesh = sphere
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.3, 0.1)
	mat.emission_energy_multiplier = 3.0
	mesh.set_surface_override_material(0, mat)
	projectile.add_child(mesh)
	
	# Lumière
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.3, 0.1)
	light.light_energy = 2.0
	light.omni_range = 3.0
	projectile.add_child(light)
	
	# Collision
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	collision.shape = shape
	projectile.add_child(collision)
	
	# Script inline pour le mouvement
	projectile.set_script(preload("res://scripts/gameplay/Projectile.gd") if ResourceLoader.exists("res://scripts/gameplay/Projectile.gd") else null)
	
	# Stocker les données
	projectile.set_meta("direction", direction)
	projectile.set_meta("speed", projectile_speed)
	projectile.set_meta("damage", projectile_damage)
	projectile.set_meta("lifetime", 5.0)
	
	return projectile


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _is_player_visible() -> bool:
	"""Vérifie si le joueur est visible."""
	if not player_ref or not is_instance_valid(player_ref):
		return false
	
	var distance := global_position.distance_to(player_ref.global_position)
	return distance <= detection_range


func _rotate_toward(direction: Vector3, delta: float) -> void:
	"""Rotation vers une direction."""
	if direction.length() < 0.1:
		return
	
	var target_angle := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)


func _generate_patrol_point() -> void:
	"""Génère un nouveau point de patrouille."""
	var angle := randf() * TAU
	var distance := randf_range(patrol_radius * 0.3, patrol_radius)
	_patrol_point = global_position + Vector3(cos(angle), 0, sin(angle)) * distance


func _create_detection_area() -> void:
	"""Crée l'area de détection."""
	detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = detection_range
	collision.shape = sphere
	
	detection_area.add_child(collision)
	add_child(detection_area)


func _create_health_component() -> void:
	"""Crée le composant de santé."""
	if ResourceLoader.exists("res://scripts/components/HealthComponent.gd"):
		health_component = preload("res://scripts/components/HealthComponent.gd").new()
		health_component.name = "HealthComponent"
		health_component.max_health = 30.0
		add_child(health_component)


func _on_died() -> void:
	"""Appelé à la mort."""
	current_state = State.DISABLED
	destroyed.emit()
	
	# Effet de destruction
	if mesh_pivot:
		var tween := create_tween()
		tween.tween_property(mesh_pivot, "scale", Vector3.ZERO, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func disable() -> void:
	"""Désactive le drone (EMP)."""
	current_state = State.DISABLED
	velocity = Vector3.ZERO
	
	# Tomber
	_base_y = global_position.y - 2.0
