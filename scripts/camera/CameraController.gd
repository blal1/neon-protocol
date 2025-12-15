# ==============================================================================
# CameraController.gd - Contrôle tactile de caméra TPS
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Attache à un SpringArm3D pour contrôle mobile
# Le joueur utilise le côté droit de l'écran pour tourner la vue
# ==============================================================================

extends SpringArm3D
class_name CameraController

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal rotation_changed(horizontal: float, vertical: float)
signal touch_started
signal touch_ended

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Sensibilité")
@export var sensitivity_x: float = 0.5  ## Sensibilité horizontale
@export var sensitivity_y: float = 0.5  ## Sensibilité verticale
@export var invert_x: bool = false  ## Inverser l'axe X
@export var invert_y: bool = false  ## Inverser l'axe Y

@export_group("Limites verticales")
@export var min_pitch: float = -40.0  ## Angle minimum (regarder vers le haut)
@export var max_pitch: float = 60.0  ## Angle maximum (regarder vers le bas)

@export_group("Zone de contrôle")
@export var use_right_side_only: bool = true  ## Utiliser uniquement le côté droit
@export var control_zone_start: float = 0.5  ## Pourcentage de l'écran où commence la zone (0.5 = moitié droite)

@export_group("Comportement")
@export var rotate_player: bool = true  ## Faire tourner le joueur avec la caméra
@export var smooth_rotation: bool = true  ## Rotation lissée
@export var smooth_speed: float = 10.0  ## Vitesse de lissage

@export_group("SpringArm")
@export var default_length: float = 4.0  ## Longueur par défaut
@export var collision_margin: float = 0.5  ## Marge de collision

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _touch_index: int = -1
var _target_rotation: Vector2 = Vector2.ZERO
var _current_rotation: Vector2 = Vector2.ZERO
var _is_touching: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du contrôleur."""
	# Configuration du SpringArm
	spring_length = default_length
	margin = collision_margin
	
	# Initialiser la rotation actuelle
	_current_rotation = Vector2(rotation_degrees.x, rotation_degrees.y)
	_target_rotation = _current_rotation


func _input(event: InputEvent) -> void:
	"""Gestion des entrées tactiles et souris."""
	# Événements tactiles
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	
	# Support souris pour debug PC
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _is_touching:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _process(delta: float) -> void:
	"""Mise à jour de la rotation lissée."""
	if not smooth_rotation:
		return
	
	# Interpolation vers la rotation cible
	_current_rotation.x = lerp(_current_rotation.x, _target_rotation.x, smooth_speed * delta)
	_current_rotation.y = lerp(_current_rotation.y, _target_rotation.y, smooth_speed * delta)
	
	# Appliquer la rotation
	rotation_degrees.x = _current_rotation.x
	
	if rotate_player:
		var player := get_parent() as Node3D
		if player:
			player.rotation_degrees.y = _current_rotation.y
	else:
		rotation_degrees.y = _current_rotation.y


# ==============================================================================
# GESTION DES ENTRÉES
# ==============================================================================

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	"""Gère les appuis tactiles."""
	if event.pressed:
		# Vérifier si le toucher est dans la zone de contrôle
		if _is_in_control_zone(event.position):
			_touch_index = event.index
			_is_touching = true
			touch_started.emit()
	else:
		if event.index == _touch_index:
			_touch_index = -1
			_is_touching = false
			touch_ended.emit()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	"""Gère le glissement tactile."""
	if event.index == _touch_index:
		_apply_rotation(event.relative)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	"""Support souris pour tests PC."""
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and _is_in_control_zone(event.position):
			_is_touching = true
			touch_started.emit()
		else:
			_is_touching = false
			touch_ended.emit()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	"""Support mouvement souris."""
	if _is_touching:
		_apply_rotation(event.relative)


# ==============================================================================
# ROTATION
# ==============================================================================

func _apply_rotation(relative: Vector2) -> void:
	"""Applique la rotation basée sur le mouvement du doigt/souris."""
	# Inverser si demandé
	var delta_x := relative.x * sensitivity_x
	var delta_y := relative.y * sensitivity_y
	
	if invert_x:
		delta_x = -delta_x
	if invert_y:
		delta_y = -delta_y
	
	# Rotation horizontale
	_target_rotation.y -= delta_x
	
	# Rotation verticale (avec limites)
	_target_rotation.x -= delta_y
	_target_rotation.x = clamp(_target_rotation.x, min_pitch, max_pitch)
	
	# Si pas de lissage, appliquer directement
	if not smooth_rotation:
		_current_rotation = _target_rotation
		rotation_degrees.x = _current_rotation.x
		
		if rotate_player:
			var player := get_parent() as Node3D
			if player:
				player.rotation_degrees.y = _current_rotation.y
		else:
			rotation_degrees.y = _current_rotation.y
	
	rotation_changed.emit(_current_rotation.y, _current_rotation.x)


func _is_in_control_zone(position: Vector2) -> bool:
	"""Vérifie si la position est dans la zone de contrôle."""
	if not use_right_side_only:
		return true
	
	var viewport_size := get_viewport().get_visible_rect().size
	var zone_start := viewport_size.x * control_zone_start
	
	return position.x > zone_start


# ==============================================================================
# MÉTHODES PUBLIQUES
# ==============================================================================

func set_sensitivity(x: float, y: float) -> void:
	"""Définit la sensibilité des axes."""
	sensitivity_x = clamp(x, 0.1, 2.0)
	sensitivity_y = clamp(y, 0.1, 2.0)


func set_pitch_limits(min_angle: float, max_angle: float) -> void:
	"""Définit les limites de l'angle vertical."""
	min_pitch = min_angle
	max_pitch = max_angle


func reset_rotation() -> void:
	"""Réinitialise la rotation à zéro."""
	_target_rotation = Vector2(-25.0, 0.0)  # Angle par défaut
	_current_rotation = _target_rotation
	rotation_degrees.x = _current_rotation.x


func look_at_target(target_position: Vector3) -> void:
	"""Fait regarder la caméra vers une position cible."""
	var player := get_parent() as Node3D
	if not player:
		return
	
	var direction := target_position - player.global_position
	direction.y = 0.0
	
	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		_target_rotation.y = rad_to_deg(target_angle)


func get_forward_direction() -> Vector3:
	"""Retourne la direction avant de la caméra (plan XZ)."""
	var player := get_parent() as Node3D
	if player:
		return -player.global_transform.basis.z
	return Vector3.FORWARD


func get_right_direction() -> Vector3:
	"""Retourne la direction droite de la caméra."""
	var player := get_parent() as Node3D
	if player:
		return player.global_transform.basis.x
	return Vector3.RIGHT
