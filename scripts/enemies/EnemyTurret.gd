# ==============================================================================
# EnemyTurret.gd - Tourelle stationnaire
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Tourelle fixe avec rotation et tir automatique
# ==============================================================================

extends StaticBody3D
class_name EnemyTurret

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal target_acquired(target: Node3D)
signal target_lost
signal fired
signal destroyed

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum State { IDLE, SCANNING, TARGETING, FIRING, DISABLED }

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Combat")
@export var detection_range: float = 18.0
@export var fire_rate: float = 0.5  ## Temps entre les tirs
@export var projectile_damage: float = 8.0
@export var projectile_speed: float = 25.0
@export var burst_count: int = 3
@export var burst_delay: float = 0.1

@export_group("Mouvement")
@export var rotation_speed: float = 2.0
@export var scan_speed: float = 0.5
@export var aim_tolerance: float = 0.1  ## Radians

@export_group("Activation")
@export var activation_delay: float = 1.0
@export var can_be_hacked: bool = true
@export var is_hacked: bool = false

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_state: State = State.IDLE
var player_ref: Node3D = null
var can_fire: bool = true
var _scan_angle: float = 0.0
var _target_angle: float = 0.0

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var turret_head: Node3D = $TurretHead if has_node("TurretHead") else null
@onready var barrel: Node3D = $TurretHead/Barrel if has_node("TurretHead/Barrel") else null
@onready var health_component: Node = $HealthComponent if has_node("HealthComponent") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null
@onready var muzzle_flash: OmniLight3D = $TurretHead/Barrel/MuzzleFlash if has_node("TurretHead/Barrel/MuzzleFlash") else null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	add_to_group("enemy")
	add_to_group("turret")
	
	if can_be_hacked:
		add_to_group("hackable")
	
	# Trouver le joueur
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
	
	# Health
	if not health_component:
		_create_health_component()
	
	if health_component:
		health_component.died.connect(_on_died)
	
	# Muzzle flash off
	if muzzle_flash:
		muzzle_flash.visible = false
	
	current_state = State.SCANNING


func _process(delta: float) -> void:
	"""Mise à jour."""
	if is_hacked:
		_process_hacked(delta)
		return
	
	match current_state:
		State.IDLE:
			pass
		State.SCANNING:
			_state_scanning(delta)
		State.TARGETING:
			_state_targeting(delta)
		State.FIRING:
			_state_firing(delta)
		State.DISABLED:
			pass


# ==============================================================================
# ÉTATS
# ==============================================================================

func _state_scanning(delta: float) -> void:
	"""Balayage de la zone."""
	# Rotation de scan
	_scan_angle += scan_speed * delta
	if turret_head:
		turret_head.rotation.y = sin(_scan_angle) * PI * 0.5
	
	# Vérifier si le joueur est détecté
	if _is_player_in_range():
		current_state = State.TARGETING
		target_acquired.emit(player_ref)


func _state_targeting(delta: float) -> void:
	"""Verrouillage sur cible."""
	if not player_ref or not is_instance_valid(player_ref):
		current_state = State.SCANNING
		target_lost.emit()
		return
	
	# Perdu la cible
	if not _is_player_in_range():
		current_state = State.SCANNING
		target_lost.emit()
		return
	
	# Calculer l'angle vers le joueur
	var to_player := player_ref.global_position - global_position
	_target_angle = atan2(to_player.x, to_player.z)
	
	# Rotation vers la cible
	if turret_head:
		var current_angle := turret_head.rotation.y
		turret_head.rotation.y = lerp_angle(current_angle, _target_angle, rotation_speed * delta)
		
		# Vérifier si on est aligné
		var angle_diff := abs(angle_difference(current_angle, _target_angle))
		if angle_diff < aim_tolerance and can_fire:
			current_state = State.FIRING


func _state_firing(delta: float) -> void:
	"""Tir sur la cible."""
	if not player_ref or not _is_player_in_range():
		current_state = State.SCANNING
		return
	
	# Maintenir l'alignement
	var to_player := player_ref.global_position - global_position
	_target_angle = atan2(to_player.x, to_player.z)
	
	if turret_head:
		turret_head.rotation.y = lerp_angle(turret_head.rotation.y, _target_angle, rotation_speed * delta)
	
	# Tirer
	if can_fire:
		_fire_burst()


# ==============================================================================
# COMBAT
# ==============================================================================

func _fire_burst() -> void:
	"""Tire une rafale."""
	can_fire = false
	
	for i in range(burst_count):
		_fire_single()
		await get_tree().create_timer(burst_delay).timeout
	
	# Cooldown
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true
	
	# Retourner au ciblage
	if current_state == State.FIRING:
		current_state = State.TARGETING


func _fire_single() -> void:
	"""Tire un projectile."""
	fired.emit()
	
	# Muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		await get_tree().create_timer(0.05).timeout
		muzzle_flash.visible = false
	
	# Son
	if audio_player:
		audio_player.play()
	
	# Créer le projectile
	var projectile := _create_projectile()
	get_tree().current_scene.add_child(projectile)


func _create_projectile() -> Node3D:
	"""Crée un projectile."""
	var projectile := Area3D.new()
	
	var spawn_pos := global_position + Vector3(0, 1.5, 0)
	if barrel:
		spawn_pos = barrel.global_position
	
	projectile.global_position = spawn_pos
	
	# Direction
	var direction := Vector3.FORWARD
	if turret_head:
		direction = -turret_head.global_transform.basis.z
	
	# Mesh
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.08
	capsule.height = 0.4
	mesh.mesh = capsule
	mesh.rotation.x = PI / 2
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.5, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0)
	mat.emission_energy_multiplier = 4.0
	mesh.set_surface_override_material(0, mat)
	projectile.add_child(mesh)
	
	# Collision
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.08
	shape.height = 0.4
	collision.shape = shape
	collision.rotation.x = PI / 2
	projectile.add_child(collision)
	
	# Metadata
	projectile.set_meta("direction", direction)
	projectile.set_meta("speed", projectile_speed)
	projectile.set_meta("damage", projectile_damage)
	projectile.set_meta("lifetime", 4.0)
	projectile.set_meta("is_turret_projectile", true)
	
	# Script de mouvement simple
	var script := GDScript.new()
	script.source_code = """
extends Area3D
var direction: Vector3
var speed: float
var damage: float
var lifetime: float

func _ready():
	direction = get_meta("direction", Vector3.FORWARD)
	speed = get_meta("speed", 20.0)
	damage = get_meta("damage", 10.0)
	lifetime = get_meta("lifetime", 4.0)
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		var health = body.get_node_or_null("HealthComponent")
		if health:
			health.take_damage(damage, self)
		queue_free()
	elif not body.is_in_group("enemy") and not body.is_in_group("turret"):
		queue_free()
"""
	script.reload()
	projectile.set_script(script)
	
	return projectile


# ==============================================================================
# HACKING
# ==============================================================================

func _process_hacked(delta: float) -> void:
	"""Comportement quand hacké (attaque les ennemis)."""
	# Chercher des ennemis
	var enemies := get_tree().get_nodes_in_group("enemy")
	var closest: Node3D = null
	var closest_dist := detection_range
	
	for enemy in enemies:
		if enemy == self:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	
	if closest and turret_head:
		var to_enemy := closest.global_position - global_position
		var target := atan2(to_enemy.x, to_enemy.z)
		turret_head.rotation.y = lerp_angle(turret_head.rotation.y, target, rotation_speed * delta)
		
		# Tirer
		var angle_diff := abs(angle_difference(turret_head.rotation.y, target))
		if angle_diff < aim_tolerance and can_fire:
			_fire_single()
			can_fire = false
			await get_tree().create_timer(fire_rate).timeout
			can_fire = true


func hack() -> void:
	"""Hacke la tourelle."""
	if not can_be_hacked:
		return
	
	is_hacked = true
	remove_from_group("enemy")
	add_to_group("ally")
	
	# Changer la couleur
	var meshes := find_children("*", "MeshInstance3D")
	for mesh in meshes:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.8, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.6, 0.3)
		mesh.set_surface_override_material(0, mat)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _is_player_in_range() -> bool:
	"""Vérifie si le joueur est à portée."""
	if not player_ref or not is_instance_valid(player_ref):
		return false
	return global_position.distance_to(player_ref.global_position) <= detection_range


func _create_health_component() -> void:
	"""Crée le composant de santé."""
	if ResourceLoader.exists("res://scripts/components/HealthComponent.gd"):
		health_component = preload("res://scripts/components/HealthComponent.gd").new()
		health_component.name = "HealthComponent"
		health_component.max_health = 50.0
		add_child(health_component)


func _on_died() -> void:
	"""Destruction de la tourelle."""
	current_state = State.DISABLED
	destroyed.emit()
	
	# Explosion visuelle
	var explosion := OmniLight3D.new()
	explosion.light_color = Color(1, 0.5, 0)
	explosion.light_energy = 5.0
	explosion.omni_range = 5.0
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	
	var tween := create_tween()
	tween.tween_property(explosion, "light_energy", 0.0, 0.3)
	tween.tween_callback(explosion.queue_free)
	
	queue_free()


func disable() -> void:
	"""Désactive la tourelle."""
	current_state = State.DISABLED
