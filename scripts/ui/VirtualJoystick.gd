# ==============================================================================
# VirtualJoystick.gd - Joystick Virtuel Tactile
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Optimisé pour mobile (Android/iOS)
# Features : Zone morte, feedback visuel, accessibilité
# ==============================================================================

extends Control
class_name VirtualJoystick

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal joystick_input(direction: Vector2)  # Direction normalisée
signal joystick_pressed
signal joystick_released

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Références")
@export var player: Player  ## Référence au joueur

@export_group("Comportement")
@export var dead_zone: float = 0.2  ## Zone morte (0-1)
@export var max_distance: float = 100.0  ## Distance max du stick en pixels
@export var follow_finger: bool = true  ## Le joystick suit le doigt si true

@export_group("Visuel")
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var stick_color: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var active_color: Color = Color(0.0, 0.8, 1.0, 0.8)  # Cyan cyberpunk

@export_group("Accessibilité")
@export var haptic_feedback: bool = true  ## Vibration au toucher
@export var show_direction_indicators: bool = false  ## Indicateurs visuels de direction

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
@onready var base_circle: TextureRect = $Base
@onready var stick_circle: TextureRect = $Stick

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _is_pressed: bool = false
var _touch_index: int = -1
var _center_position: Vector2
var _current_direction: Vector2 = Vector2.ZERO
var _original_position: Vector2

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du joystick."""
	_original_position = global_position
	_center_position = size / 2.0
	
	# Configuration du style
	if base_circle:
		base_circle.modulate = base_color
	if stick_circle:
		stick_circle.modulate = stick_color
	
	# Trouver le joueur automatiquement si non assigné
	if not player:
		await get_tree().process_frame
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0] is Player:
			player = players[0] as Player


func _input(event: InputEvent) -> void:
	"""Gestion des événements tactiles."""
	# Touch events pour mobile
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	
	# Support souris pour debug PC
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _is_pressed:
		_handle_mouse_motion(event as InputEventMouseMotion)


# ==============================================================================
# GESTION TACTILE
# ==============================================================================

func _handle_touch(event: InputEventScreenTouch) -> void:
	"""Gère les appuis tactiles."""
	if event.pressed:
		# Vérifier si le toucher est dans la zone du joystick
		if _is_point_inside(event.position):
			_start_input(event.position, event.index)
	else:
		# Relâchement
		if event.index == _touch_index:
			_end_input()


func _handle_drag(event: InputEventScreenDrag) -> void:
	"""Gère le glissement tactile."""
	if event.index == _touch_index and _is_pressed:
		_update_stick_position(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	"""Support souris pour tests PC."""
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_point_inside(event.position):
			_start_input(event.position, 0)
		elif not event.pressed:
			_end_input()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	"""Support mouvement souris pour tests PC."""
	if _is_pressed:
		_update_stick_position(event.position)


# ==============================================================================
# LOGIQUE DU JOYSTICK
# ==============================================================================

func _start_input(touch_position: Vector2, index: int) -> void:
	"""Démarre l'input du joystick."""
	_is_pressed = true
	_touch_index = index
	
	# Si follow_finger, repositionner le joystick
	if follow_finger:
		global_position = touch_position - _center_position
	
	_update_stick_position(touch_position)
	
	# Feedback visuel
	if base_circle:
		base_circle.modulate = active_color
	
	# Haptic feedback (vibration légère)
	if haptic_feedback:
		Input.vibrate_handheld(50)  # 50ms vibration
	
	joystick_pressed.emit()


func _end_input() -> void:
	"""Termine l'input du joystick."""
	_is_pressed = false
	_touch_index = -1
	_current_direction = Vector2.ZERO
	
	# Retourner le stick au centre
	if stick_circle:
		stick_circle.position = _center_position - stick_circle.size / 2.0
	
	# Restaurer la position originale
	if follow_finger:
		global_position = _original_position
	
	# Feedback visuel
	if base_circle:
		base_circle.modulate = base_color
	if stick_circle:
		stick_circle.modulate = stick_color
	
	# Notifier le joueur
	_send_input_to_player(Vector2.ZERO)
	
	joystick_released.emit()
	joystick_input.emit(Vector2.ZERO)


func _update_stick_position(touch_position: Vector2) -> void:
	"""Met à jour la position du stick selon le toucher."""
	# Calculer le centre global du joystick
	var center_global := global_position + _center_position
	
	# Vecteur du centre vers le toucher
	var to_touch := touch_position - center_global
	
	# Limiter à la distance maximum
	var distance := to_touch.length()
	if distance > max_distance:
		to_touch = to_touch.normalized() * max_distance
		distance = max_distance
	
	# Mettre à jour la position visuelle du stick
	if stick_circle:
		stick_circle.position = _center_position + to_touch - stick_circle.size / 2.0
	
	# Calculer la direction normalisée
	var normalized_distance := distance / max_distance
	
	if normalized_distance > dead_zone:
		# Remapper pour que la zone morte soit [0, 1]
		var remapped := (normalized_distance - dead_zone) / (1.0 - dead_zone)
		_current_direction = to_touch.normalized() * remapped
	else:
		_current_direction = Vector2.ZERO
	
	# Envoyer l'input
	_send_input_to_player(_current_direction)
	joystick_input.emit(_current_direction)


func _send_input_to_player(direction: Vector2) -> void:
	"""Envoie la direction au joueur."""
	if player:
		player.set_movement_input(direction)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _is_point_inside(point: Vector2) -> bool:
	"""Vérifie si un point est dans la zone du joystick."""
	var local_point := point - global_position
	var center := _center_position
	var radius := size.x / 2.0
	
	return local_point.distance_to(center) <= radius


func get_direction() -> Vector2:
	"""Retourne la direction actuelle du joystick."""
	return _current_direction


func is_active() -> bool:
	"""Retourne true si le joystick est actuellement utilisé."""
	return _is_pressed


# ==============================================================================
# ACCESSIBILITÉ
# ==============================================================================

func set_joystick_size(scale_factor: float) -> void:
	"""
	Redimensionne le joystick (accessibilité).
	@param scale_factor: Multiplicateur de taille (1.0 = normal)
	"""
	scale = Vector2.ONE * clamp(scale_factor, 0.5, 2.0)
	max_distance = 100.0 * scale_factor


func set_opacity(alpha: float) -> void:
	"""Définit l'opacité du joystick."""
	modulate.a = clamp(alpha, 0.1, 1.0)


func set_position_preset(preset: String) -> void:
	"""
	Positionne le joystick selon un preset.
	@param preset: "bottom_left", "bottom_right", "custom"
	"""
	var viewport_size := get_viewport_rect().size
	var margin := 50.0
	
	match preset:
		"bottom_left":
			global_position = Vector2(margin, viewport_size.y - size.y - margin)
		"bottom_right":
			global_position = Vector2(viewport_size.x - size.x - margin, viewport_size.y - size.y - margin)
	
	_original_position = global_position
