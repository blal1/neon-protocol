# ==============================================================================
# SimpleJoystick.gd - Joystick Virtuel Minimaliste
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Version simplifiée et légère pour mobile
# ==============================================================================

extends Control
class_name SimpleJoystick

# ==============================================================================
# SIGNAL - Direction normalisée pour le script de mouvement
# ==============================================================================
signal direction_changed(direction: Vector2)

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export var dead_zone: float = 0.2  ## Zone morte (0-1)
@export var joystick_radius: float = 64.0  ## Rayon de la zone de déplacement

# ==============================================================================
# RÉFÉRENCES UI (TextureRect ou ColorRect)
# ==============================================================================
@onready var background: Control = $Background  # Cercle de fond
@onready var knob: Control = $Knob  # Bouton mobile

# ==============================================================================
# ÉTAT
# ==============================================================================
var _is_dragging: bool = false
var _touch_index: int = -1
var _center: Vector2
var _output: Vector2 = Vector2.ZERO  # Direction normalisée

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_center = size / 2.0
	_reset_knob()


# ==============================================================================
# GESTION DES ÉVÉNEMENTS TACTILES
# ==============================================================================

func _gui_input(event: InputEvent) -> void:
	# === OnPointerDown ===
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_pointer_down(touch.position, touch.index)
		else:
			if touch.index == _touch_index:
				_on_pointer_up()
	
	# === OnDrag ===
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_on_drag(drag.position)
	
	# === Support Souris (Debug PC) ===
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_on_pointer_down(mouse.position, 0)
			else:
				_on_pointer_up()
	
	elif event is InputEventMouseMotion and _is_dragging:
		_on_drag((event as InputEventMouseMotion).position)


# ==============================================================================
# CALLBACKS TACTILES
# ==============================================================================

func _on_pointer_down(local_pos: Vector2, index: int) -> void:
	"""Appelé quand le doigt touche le joystick."""
	_is_dragging = true
	_touch_index = index
	_update_knob_position(local_pos)


func _on_drag(local_pos: Vector2) -> void:
	"""Appelé quand le doigt glisse sur le joystick."""
	if _is_dragging:
		_update_knob_position(local_pos)


func _on_pointer_up() -> void:
	"""Appelé quand le doigt quitte l'écran."""
	_is_dragging = false
	_touch_index = -1
	_reset_knob()
	_output = Vector2.ZERO
	direction_changed.emit(_output)


# ==============================================================================
# LOGIQUE PRINCIPALE
# ==============================================================================

func _update_knob_position(touch_pos: Vector2) -> void:
	"""Met à jour la position du knob et calcule la direction."""
	# Vecteur du centre vers le toucher
	var delta := touch_pos - _center
	var distance := delta.length()
	
	# Limiter au rayon maximum
	if distance > joystick_radius:
		delta = delta.normalized() * joystick_radius
		distance = joystick_radius
	
	# Positionner le knob visuellement
	if knob:
		knob.position = _center + delta - knob.size / 2.0
	
	# Calculer la direction normalisée
	var normalized_distance := distance / joystick_radius
	
	if normalized_distance > dead_zone:
		# Remapper pour éliminer la zone morte
		var strength := (normalized_distance - dead_zone) / (1.0 - dead_zone)
		_output = delta.normalized() * strength
	else:
		_output = Vector2.ZERO
	
	# Émettre le signal
	direction_changed.emit(_output)


func _reset_knob() -> void:
	"""Recentre le knob."""
	if knob:
		knob.position = _center - knob.size / 2.0


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_direction() -> Vector2:
	"""Retourne le Vector2 normalisé actuel (-1 à 1 sur chaque axe)."""
	return _output


func is_active() -> bool:
	"""Retourne true si le joystick est utilisé."""
	return _is_dragging
