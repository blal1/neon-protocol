# ==============================================================================
# PlayerAnimationController.gd - Contrôleur d'animations joueur
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les animations du joueur via code (sans AnimationPlayer externe)
# Utilise des tweens et transformations pour simuler des animations
# ==============================================================================

extends Node
class_name PlayerAnimationController

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal animation_started(anim_name: String)
signal animation_finished(anim_name: String)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var mesh_pivot: Node3D
@export var player: CharacterBody3D

@export_group("Mouvement")
@export var bob_amount: float = 0.05  ## Amplitude du bob
@export var bob_speed: float = 10.0  ## Vitesse du bob
@export var tilt_amount: float = 5.0  ## Inclinaison en mouvement
@export var run_tilt: float = 10.0  ## Inclinaison en course

@export_group("Combat")
@export var attack_swing_angle: float = 45.0
@export var attack_duration: float = 0.3
@export var hit_flash_duration: float = 0.1

@export_group("Dash")
@export var dash_squash: float = 0.7
@export var dash_stretch: float = 1.4

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _current_animation: String = "idle"
var _is_playing: bool = false
var _bob_time: float = 0.0
var _original_position: Vector3
var _original_rotation: Vector3
var _original_scale: Vector3

# Références aux meshes du joueur
var _body_mesh: MeshInstance3D
var _weapon_pivot: Node3D

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	if not mesh_pivot:
		mesh_pivot = get_parent().get_node_or_null("MeshPivot")
	
	if not player:
		player = get_parent() as CharacterBody3D
	
	if mesh_pivot:
		_original_position = mesh_pivot.position
		_original_rotation = mesh_pivot.rotation
		_original_scale = mesh_pivot.scale
		
		# Trouver les meshes enfants
		_body_mesh = mesh_pivot.get_node_or_null("Mesh") as MeshInstance3D
		_weapon_pivot = mesh_pivot.get_node_or_null("WeaponPivot")


func _process(delta: float) -> void:
	"""Mise à jour des animations."""
	if not mesh_pivot:
		return
	
	match _current_animation:
		"idle":
			_animate_idle(delta)
		"walk", "run":
			_animate_move(delta)
		"attack":
			pass  # Géré par tween
		"dash":
			pass  # Géré par tween
		"hit":
			pass  # Géré par tween


# ==============================================================================
# ANIMATIONS DE BASE
# ==============================================================================

func _animate_idle(delta: float) -> void:
	"""Animation d'idle (respiration légère)."""
	_bob_time += delta * 2.0
	
	# Respiration subtile
	var breath := sin(_bob_time) * 0.01
	mesh_pivot.position.y = _original_position.y + breath
	
	# Très légère rotation
	mesh_pivot.rotation.z = sin(_bob_time * 0.5) * deg_to_rad(0.5)


func _animate_move(delta: float) -> void:
	"""Animation de marche/course."""
	if not player:
		return
	
	var velocity := player.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	
	if speed < 0.1:
		_current_animation = "idle"
		return
	
	# Vitesse du bob basée sur la vitesse de déplacement
	var bob_speed_mult := speed / 5.0
	_bob_time += delta * bob_speed * bob_speed_mult
	
	# Bob vertical
	var bob := abs(sin(_bob_time)) * bob_amount * bob_speed_mult
	mesh_pivot.position.y = _original_position.y + bob
	
	# Inclinaison latérale
	var move_dir := Vector2(velocity.x, velocity.z).normalized()
	var target_tilt := -move_dir.x * deg_to_rad(tilt_amount)
	mesh_pivot.rotation.z = lerp(mesh_pivot.rotation.z, target_tilt, 10.0 * delta)
	
	# Inclinaison avant en course
	if speed > 6.0:
		mesh_pivot.rotation.x = lerp(mesh_pivot.rotation.x, deg_to_rad(-run_tilt), 5.0 * delta)
	else:
		mesh_pivot.rotation.x = lerp(mesh_pivot.rotation.x, 0.0, 5.0 * delta)


# ==============================================================================
# ANIMATIONS D'ACTION
# ==============================================================================

func play_attack(combo_level: int = 0) -> void:
	"""Joue l'animation d'attaque."""
	if _is_playing and _current_animation == "attack":
		return
	
	_current_animation = "attack"
	_is_playing = true
	animation_started.emit("attack")
	
	# Direction du swing basée sur le niveau de combo
	var swing_direction := 1.0 if combo_level % 2 == 0 else -1.0
	var swing_angle := attack_swing_angle * (1.0 + combo_level * 0.2)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Phase 1: Préparation (rotation arrière rapide)
	tween.tween_property(mesh_pivot, "rotation:y", 
		mesh_pivot.rotation.y + deg_to_rad(-swing_angle * 0.3 * swing_direction), 
		attack_duration * 0.15)
	
	# Phase 2: Swing rapide
	tween.tween_property(mesh_pivot, "rotation:y", 
		mesh_pivot.rotation.y + deg_to_rad(swing_angle * swing_direction), 
		attack_duration * 0.25).set_ease(Tween.EASE_IN)
	
	# Phase 3: Retour
	tween.tween_property(mesh_pivot, "rotation:y", 
		_original_rotation.y, 
		attack_duration * 0.4).set_ease(Tween.EASE_OUT)
	
	# Léger step forward
	tween.parallel().tween_property(mesh_pivot, "position:z", 
		_original_position.z - 0.2, attack_duration * 0.3)
	tween.tween_property(mesh_pivot, "position:z", 
		_original_position.z, attack_duration * 0.3)
	
	await tween.finished
	_is_playing = false
	_current_animation = "idle"
	animation_finished.emit("attack")


func play_dash(direction: Vector3) -> void:
	"""Joue l'animation de dash."""
	_current_animation = "dash"
	_is_playing = true
	animation_started.emit("dash")
	
	var tween := create_tween()
	
	# Squash & stretch
	var stretch_scale := Vector3(
		1.0 / dash_stretch,
		1.0 / dash_stretch,
		dash_stretch
	)
	
	tween.tween_property(mesh_pivot, "scale", stretch_scale, 0.1)
	tween.tween_property(mesh_pivot, "scale", _original_scale, 0.2)
	
	# Inclinaison dans la direction du dash
	var tilt := Vector3(
		direction.z * deg_to_rad(30),
		0,
		-direction.x * deg_to_rad(20)
	)
	tween.parallel().tween_property(mesh_pivot, "rotation", 
		_original_rotation + tilt, 0.1)
	tween.tween_property(mesh_pivot, "rotation", 
		_original_rotation, 0.15)
	
	await tween.finished
	_is_playing = false
	_current_animation = "idle"
	animation_finished.emit("dash")


func play_hit() -> void:
	"""Joue l'animation de dégât reçu."""
	animation_started.emit("hit")
	
	var tween := create_tween()
	
	# Flash rouge sur le mesh
	if _body_mesh:
		var original_material = _body_mesh.get_surface_override_material(0)
		var flash_material := StandardMaterial3D.new()
		flash_material.albedo_color = Color(1, 0.3, 0.3)
		flash_material.emission_enabled = true
		flash_material.emission = Color(1, 0.2, 0.2)
		flash_material.emission_energy_multiplier = 2.0
		
		_body_mesh.set_surface_override_material(0, flash_material)
		
		await get_tree().create_timer(hit_flash_duration).timeout
		_body_mesh.set_surface_override_material(0, original_material)
	
	# Recul
	tween.tween_property(mesh_pivot, "position:z", 
		_original_position.z + 0.15, 0.05)
	tween.tween_property(mesh_pivot, "position:z", 
		_original_position.z, 0.1)
	
	# Tremblement
	for i in range(3):
		tween.tween_property(mesh_pivot, "position:x", 
			_original_position.x + 0.03, 0.02)
		tween.tween_property(mesh_pivot, "position:x", 
			_original_position.x - 0.03, 0.02)
	tween.tween_property(mesh_pivot, "position:x", _original_position.x, 0.02)
	
	await tween.finished
	animation_finished.emit("hit")


func play_death() -> void:
	"""Joue l'animation de mort."""
	_current_animation = "death"
	_is_playing = true
	animation_started.emit("death")
	
	var tween := create_tween()
	
	# Chute
	tween.tween_property(mesh_pivot, "rotation:x", deg_to_rad(90), 0.5)
	tween.parallel().tween_property(mesh_pivot, "position:y", 0.2, 0.5)
	
	# Fade out (si material le permet)
	if _body_mesh:
		var mat := _body_mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.parallel().tween_property(mat, "albedo_color:a", 0.3, 0.8)
	
	await tween.finished
	animation_finished.emit("death")


func play_respawn() -> void:
	"""Joue l'animation de respawn."""
	animation_started.emit("respawn")
	
	# Reset position
	mesh_pivot.position = _original_position + Vector3(0, 2, 0)
	mesh_pivot.rotation = _original_rotation
	mesh_pivot.scale = _original_scale * 0.1
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Descente + scale up
	tween.tween_property(mesh_pivot, "position", _original_position, 0.4)
	tween.parallel().tween_property(mesh_pivot, "scale", _original_scale, 0.3)
	
	# Petit rebond
	tween.tween_property(mesh_pivot, "position:y", _original_position.y + 0.1, 0.1)
	tween.tween_property(mesh_pivot, "position:y", _original_position.y, 0.1)
	
	await tween.finished
	_current_animation = "idle"
	_is_playing = false
	animation_finished.emit("respawn")


# ==============================================================================
# ANIMATIONS SPÉCIALES
# ==============================================================================

func play_interact() -> void:
	"""Animation d'interaction."""
	animation_started.emit("interact")
	
	var tween := create_tween()
	
	# Légère inclinaison avant
	tween.tween_property(mesh_pivot, "rotation:x", deg_to_rad(-15), 0.2)
	tween.tween_property(mesh_pivot, "rotation:x", 0.0, 0.3)
	
	await tween.finished
	animation_finished.emit("interact")


func play_hack() -> void:
	"""Animation de hacking."""
	animation_started.emit("hack")
	
	# Tremblement rapide (concentration)
	var tween := create_tween()
	for i in range(10):
		tween.tween_property(mesh_pivot, "position:x", 
			_original_position.x + randf_range(-0.01, 0.01), 0.05)
	tween.tween_property(mesh_pivot, "position:x", _original_position.x, 0.05)
	
	await tween.finished
	animation_finished.emit("hack")


# ==============================================================================
# CONTRÔLE
# ==============================================================================

func set_animation(anim_name: String) -> void:
	"""Définit l'animation courante."""
	if not _is_playing:
		_current_animation = anim_name


func stop() -> void:
	"""Arrête l'animation en cours."""
	_is_playing = false
	_current_animation = "idle"
	
	# Reset aux valeurs originales
	if mesh_pivot:
		mesh_pivot.position = _original_position
		mesh_pivot.rotation = _original_rotation
		mesh_pivot.scale = _original_scale


func is_playing() -> bool:
	"""Retourne si une animation est en cours."""
	return _is_playing


func get_current_animation() -> String:
	"""Retourne l'animation courante."""
	return _current_animation
