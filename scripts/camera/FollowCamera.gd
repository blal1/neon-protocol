# ==============================================================================
# FollowCamera.gd - Caméra Third-Person avec collision
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Optimisé pour mobile (Android/iOS)
# Features : Smooth follow, collision murs, accessible
# ==============================================================================

extends Node3D
class_name FollowCamera

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal camera_collided  # Émis quand la caméra touche un mur
signal zoom_changed(new_distance: float)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MIN_PITCH: float = -60.0  # Angle minimum (regarder vers le haut)
const MAX_PITCH: float = 10.0   # Angle maximum (regarder vers le bas)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Cible")
@export var target: Node3D  ## Le joueur à suivre
@export var target_offset: Vector3 = Vector3(0.0, 1.5, 0.0)  ## Décalage par rapport au joueur

@export_group("Distance et Position")
@export var default_distance: float = 6.0  ## Distance par défaut de la caméra
@export var min_distance: float = 2.0  ## Distance minimum (zoom max)
@export var max_distance: float = 12.0  ## Distance maximum (zoom min)
@export var height_offset: float = 2.0  ## Hauteur au-dessus du joueur

@export_group("Lissage (Smooth Damp)")
@export_range(0.01, 1.0) var position_smoothing: float = 0.15  ## Lissage position (plus bas = plus lent)
@export_range(0.01, 1.0) var rotation_smoothing: float = 0.1  ## Lissage rotation

@export_group("Collision")
@export var collision_margin: float = 0.3  ## Marge pour éviter le clipping
@export var collision_mask: int = 1  ## Masque de collision (layer des murs)

@export_group("Accessibilité")
@export var camera_sensitivity: float = 1.0  ## Multiplicateur de sensibilité

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

# Variables internes pour smooth damp
var _current_distance: float
var _target_position: Vector3
var _velocity: Vector3 = Vector3.ZERO  # Pour smooth damp manuel
var _pitch: float = -25.0  # Angle vertical initial
var _yaw: float = 0.0  # Angle horizontal

# Desktop camera control
var _mouse_captured: bool = false
@export_group("Desktop Controls")
@export var mouse_sensitivity: float = 0.003  ## Sensibilité souris
@export var gamepad_sensitivity: float = 2.0  ## Sensibilité stick droit
@export var invert_y: bool = false  ## Inverser l'axe Y
@export var enable_mouse_look: bool = true  ## Activer la rotation souris

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation de la caméra."""
	_current_distance = default_distance
	
	# Configuration du SpringArm3D pour collision
	if spring_arm:
		spring_arm.spring_length = default_distance
		spring_arm.margin = collision_margin
		spring_arm.collision_mask = collision_mask
	
	# Trouver automatiquement le joueur si non assigné
	if not target:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
			print("FollowCamera: Joueur trouvé automatiquement")
		else:
			push_warning("FollowCamera: Aucune cible assignée!")
	
	# Position initiale
	if target:
		global_position = target.global_position + target_offset
		_target_position = global_position


func _physics_process(delta: float) -> void:
	"""Mise à jour physique de la caméra."""
	if not target:
		return
	
	# 1. Calculer la position cible
	_update_target_position()
	
	# 2. Appliquer smooth damp à la position
	_smooth_follow(delta)
	
	# 3. Gérer les collisions via SpringArm
	_handle_collision()
	
	# 4. Faire regarder la caméra vers le joueur
	_update_camera_look()
	
	# 5. Gérer la rotation gamepad (stick droit)
	_handle_gamepad_look(delta)


func _input(event: InputEvent) -> void:
	"""Gestion des inputs pour la rotation caméra."""
	if not enable_mouse_look:
		return
	
	# Mouse look (desktop)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_apply_camera_rotation(motion.relative * mouse_sensitivity)
	
	# Capture/release mouse with Escape
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_mouse_captured = false
	
	# Click to capture mouse
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				# Check if we're not clicking UI
				var viewport := get_viewport()
				if viewport:
					var gui_path := viewport.gui_get_focus_owner()
					if gui_path == null:
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
						_mouse_captured = true


func _handle_gamepad_look(delta: float) -> void:
	"""Gère la rotation via stick droit de manette."""
	var look_input := Vector2.ZERO
	
	# Check gamepad right stick
	look_input.x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	look_input.y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	# Apply deadzone
	if look_input.length() < 0.2:
		return
	
	_apply_camera_rotation(look_input * gamepad_sensitivity * delta * 60.0)


func _apply_camera_rotation(delta_look: Vector2) -> void:
	"""Applique la rotation de la caméra."""
	# Yaw (rotation horizontale)
	_yaw -= delta_look.x
	
	# Pitch (rotation verticale)
	var pitch_delta := delta_look.y
	if invert_y:
		pitch_delta *= -1
	_pitch -= pitch_delta
	_pitch = clamp(_pitch, MIN_PITCH, MAX_PITCH)
	
	# Appliquer au pivot (ce node)
	rotation_degrees.y = _yaw
	
	# Appliquer au spring arm
	if spring_arm:
		spring_arm.rotation_degrees.x = _pitch


# ==============================================================================
# SUIVI DU JOUEUR
# ==============================================================================

func _update_target_position() -> void:
	"""Calcule la position cible de la caméra."""
	if not target:
		return
	
	# Position de base = position joueur + offset
	_target_position = target.global_position + target_offset


func _smooth_follow(delta: float) -> void:
	"""
	Implémentation du smooth damp pour un suivi fluide.
	Plus performant qu'un simple lerp, donne un mouvement naturel.
	"""
	# Smooth damp manuel (plus de contrôle que lerp)
	var smooth_time := position_smoothing
	var omega := 2.0 / smooth_time
	var x := omega * delta
	var exp_factor := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	
	var delta_pos := global_position - _target_position
	var temp := (_velocity + omega * delta_pos) * delta
	_velocity = (_velocity - omega * temp) * exp_factor
	global_position = _target_position + (delta_pos + temp) * exp_factor


func _handle_collision() -> void:
	"""Gère la collision de la caméra avec les murs via SpringArm."""
	if not spring_arm or not camera:
		return
	
	# Le SpringArm3D gère automatiquement les collisions
	# On vérifie juste si la distance a changé
	var actual_length := spring_arm.get_hit_length()
	
	if actual_length < spring_arm.spring_length - 0.1:
		camera_collided.emit()
	
	# Mettre à jour la distance actuelle
	if abs(_current_distance - actual_length) > 0.01:
		_current_distance = actual_length
		zoom_changed.emit(_current_distance)


func _update_camera_look() -> void:
	"""Oriente la caméra pour regarder le joueur."""
	if not target or not camera:
		return
	
	# La caméra regarde toujours vers le joueur
	var look_target := target.global_position + target_offset
	
	if camera.global_position.distance_to(look_target) > 0.1:
		camera.look_at(look_target)


# ==============================================================================
# CONTRÔLE CAMÉRA (pour implémentation future)
# ==============================================================================

func set_pitch(angle: float) -> void:
	"""
	Définit l'angle vertical de la caméra.
	@param angle: Angle en degrés (négatif = regarder vers le bas)
	"""
	_pitch = clamp(angle, MIN_PITCH, MAX_PITCH)
	if spring_arm:
		spring_arm.rotation_degrees.x = _pitch


func adjust_distance(delta_distance: float) -> void:
	"""
	Ajuste la distance de la caméra (zoom).
	@param delta_distance: Changement de distance (positif = éloigner)
	"""
	var new_distance: float = clamp(
		default_distance + delta_distance,
		min_distance,
		max_distance
	)
	
	default_distance = new_distance
	if spring_arm:
		spring_arm.spring_length = new_distance


func set_target(new_target: Node3D) -> void:
	"""Change la cible de la caméra."""
	target = new_target
	if target:
		# Snap immédiat à la nouvelle cible
		global_position = target.global_position + target_offset
		_velocity = Vector3.ZERO


# ==============================================================================
# ACCESSIBILITÉ
# ==============================================================================

func set_sensitivity(value: float) -> void:
	"""
	Définit la sensibilité de la caméra.
	@param value: Multiplicateur (0.5 = lent, 2.0 = rapide)
	"""
	camera_sensitivity = clamp(value, 0.1, 3.0)


func get_forward_direction() -> Vector3:
	"""
	Retourne la direction avant de la caméra (pour mouvement relatif).
	Utile pour que le joueur se déplace par rapport à la vue caméra.
	"""
	if camera:
		var forward := -camera.global_transform.basis.z
		forward.y = 0
		return forward.normalized()
	return Vector3.FORWARD


func get_right_direction() -> Vector3:
	"""Retourne la direction droite de la caméra."""
	if camera:
		var right := camera.global_transform.basis.x
		right.y = 0
		return right.normalized()
	return Vector3.RIGHT


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func shake(intensity: float = 0.5, duration: float = 0.3) -> void:
	"""
	Effet de tremblement de caméra (pour impacts, explosions).
	@param intensity: Force du shake (0.1 = léger, 1.0 = fort)
	@param duration: Durée en secondes
	"""
	if not camera:
		return
	
	var original_offset := camera.position
	var tween := create_tween()
	
	# Calculer le nombre de shakes (30 par seconde pour un effet fluide)
	var shake_count := int(duration * 30)
	
	for i in range(shake_count):
		# Diminuer l'intensité progressivement
		var progress := float(i) / float(shake_count)
		var current_intensity := intensity * (1.0 - progress)
		
		var offset := Vector3(
			randf_range(-1, 1) * current_intensity * 0.1,
			randf_range(-1, 1) * current_intensity * 0.05,
			0
		)
		tween.tween_property(camera, "position", original_offset + offset, duration / shake_count)
	
	# Retour à la position originale
	tween.tween_property(camera, "position", original_offset, 0.05)


func get_current_distance() -> float:
	"""Retourne la distance actuelle de la caméra."""
	return _current_distance

