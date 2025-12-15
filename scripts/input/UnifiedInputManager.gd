# ==============================================================================
# UnifiedInputManager.gd - Abstraction Input Cross-Platform
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Couche d'abstraction unifiant Mobile (Touch) et Desktop (Keyboard/Mouse).
# Traduit tous les inputs en Actions logiques.
# ==============================================================================

extends Node
class_name UnifiedInputManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal action_pressed(action: StringName)
signal action_released(action: StringName)
signal action_just_pressed(action: StringName)
signal movement_changed(direction: Vector2)
signal look_changed(direction: Vector2)
signal touch_gesture_detected(gesture: String, data: Dictionary)

# ==============================================================================
# ACTIONS LOGIQUES
# ==============================================================================

enum GameAction {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	ATTACK,
	ATTACK_HEAVY,
	DODGE,
	INTERACT,
	PAUSE,
	TACTICAL_MODE,
	RELOAD,
	USE_ITEM,
	SONAR_PING,
	HACK,
	INVENTORY,
	MAP
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Platform Detection")
@export var force_mobile_mode: bool = false
@export var force_desktop_mode: bool = false

@export_group("Touch Settings")
@export var virtual_joystick_deadzone: float = 0.15
@export var tap_max_duration: float = 0.2
@export var double_tap_interval: float = 0.3
@export var swipe_min_distance: float = 50.0
@export var swipe_max_time: float = 0.5

@export_group("Mouse Settings")
@export var mouse_sensitivity: float = 0.003
@export var invert_y: bool = false

# ==============================================================================
# VARIABLES
# ==============================================================================

var is_mobile: bool = false
var _movement_direction: Vector2 = Vector2.ZERO
var _look_direction: Vector2 = Vector2.ZERO

## État des actions
var _action_states: Dictionary = {}  # action -> pressed

## Virtual Joystick référence
var _movement_joystick: Node = null
var _look_joystick: Node = null

## Touch tracking
var _touch_start_positions: Dictionary = {}  # touch_id -> position
var _touch_start_times: Dictionary = {}  # touch_id -> time
var _last_tap_time: float = 0.0
var _last_tap_position: Vector2 = Vector2.ZERO

## Remapping
var _input_remapping: Dictionary = {}

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_detect_platform()
	_initialize_action_states()
	_load_remapping()


func _detect_platform() -> void:
	"""Détecte la plateforme."""
	if force_mobile_mode:
		is_mobile = true
		return
	
	if force_desktop_mode:
		is_mobile = false
		return
	
	# Détection automatique
	var os_name := OS.get_name()
	is_mobile = os_name in ["Android", "iOS", "Web"]
	
	# Fallback: vérifier les capacités tactiles
	if not is_mobile:
		is_mobile = DisplayServer.is_touchscreen_available()


func _initialize_action_states() -> void:
	"""Initialise les états des actions."""
	for action in GameAction.values():
		_action_states[action] = false


func _load_remapping() -> void:
	"""Charge le remapping depuis les settings."""
	# TODO: Charger depuis SaveManager
	_input_remapping = {}


# ==============================================================================
# INPUT PROCESSING
# ==============================================================================

func _input(event: InputEvent) -> void:
	if is_mobile:
		_process_mobile_input(event)
	else:
		_process_desktop_input(event)


func _process_desktop_input(event: InputEvent) -> void:
	"""Traite les inputs desktop."""
	# Mouvement (WASD)
	_update_keyboard_movement()
	
	# Actions mappées
	_check_action_input("attack", GameAction.ATTACK, event)
	_check_action_input("dash", GameAction.DODGE, event)
	_check_action_input("interact", GameAction.INTERACT, event)
	_check_action_input("pause", GameAction.PAUSE, event)
	_check_action_input("ping_navigation", GameAction.SONAR_PING, event)
	
	# Souris pour look
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var look := motion.relative * mouse_sensitivity
		if invert_y:
			look.y *= -1
		_look_direction = look
		look_changed.emit(_look_direction)


func _update_keyboard_movement() -> void:
	"""Met à jour le mouvement clavier."""
	var direction := Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		direction.y -= 1
	if Input.is_action_pressed("move_backward"):
		direction.y += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	
	if direction.length() > 1:
		direction = direction.normalized()
	
	if direction != _movement_direction:
		_movement_direction = direction
		movement_changed.emit(_movement_direction)


func _check_action_input(input_action: String, game_action: GameAction, event: InputEvent) -> void:
	"""Vérifie et émet les actions."""
	if event.is_action_pressed(input_action):
		_set_action_pressed(game_action, true)
		action_just_pressed.emit(GameAction.keys()[game_action])
		action_pressed.emit(GameAction.keys()[game_action])
	elif event.is_action_released(input_action):
		_set_action_pressed(game_action, false)
		action_released.emit(GameAction.keys()[game_action])


func _set_action_pressed(action: GameAction, pressed: bool) -> void:
	"""Met à jour l'état d'une action."""
	_action_states[action] = pressed


# ==============================================================================
# MOBILE INPUT
# ==============================================================================

func _process_mobile_input(event: InputEvent) -> void:
	"""Traite les inputs mobile."""
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	"""Gère les touch events."""
	var touch_id := event.index
	
	if event.pressed:
		# Touch start
		_touch_start_positions[touch_id] = event.position
		_touch_start_times[touch_id] = Time.get_ticks_msec() / 1000.0
	else:
		# Touch end
		if _touch_start_positions.has(touch_id):
			var start_pos: Vector2 = _touch_start_positions[touch_id]
			var end_pos := event.position
			var start_time: float = _touch_start_times[touch_id]
			var duration := Time.get_ticks_msec() / 1000.0 - start_time
			
			_analyze_touch_gesture(start_pos, end_pos, duration)
			
			_touch_start_positions.erase(touch_id)
			_touch_start_times.erase(touch_id)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	"""Gère les drags."""
	# Le drag est géré par les VirtualJoysticks s'ils sont présents
	pass


func _analyze_touch_gesture(start: Vector2, end: Vector2, duration: float) -> void:
	"""Analyse et détecte les gestes."""
	var distance := start.distance_to(end)
	var direction := (end - start).normalized() if distance > 0 else Vector2.ZERO
	
	# Tap
	if duration < tap_max_duration and distance < 20:
		var current_time := Time.get_ticks_msec() / 1000.0
		
		# Double tap?
		if current_time - _last_tap_time < double_tap_interval:
			if start.distance_to(_last_tap_position) < 50:
				touch_gesture_detected.emit("double_tap", {"position": end})
				_last_tap_time = 0.0
				return
		
		_last_tap_time = current_time
		_last_tap_position = end
		touch_gesture_detected.emit("tap", {"position": end})
		
		# Tap dans la moitié droite = attaque
		if end.x > get_viewport().get_visible_rect().size.x / 2:
			action_just_pressed.emit(GameAction.keys()[GameAction.ATTACK])
		
		return
	
	# Swipe
	if distance >= swipe_min_distance and duration <= swipe_max_time:
		var swipe_direction := ""
		
		if abs(direction.x) > abs(direction.y):
			swipe_direction = "right" if direction.x > 0 else "left"
		else:
			swipe_direction = "down" if direction.y > 0 else "up"
		
		touch_gesture_detected.emit("swipe", {
			"direction": swipe_direction,
			"velocity": distance / duration,
			"start": start,
			"end": end
		})
		
		# Swipe = Dodge
		action_just_pressed.emit(GameAction.keys()[GameAction.DODGE])


# ==============================================================================
# VIRTUAL JOYSTICK INTEGRATION
# ==============================================================================

func register_movement_joystick(joystick: Node) -> void:
	"""Enregistre le joystick de mouvement."""
	_movement_joystick = joystick
	
	if joystick.has_signal("joystick_input"):
		joystick.joystick_input.connect(_on_movement_joystick_input)


func register_look_joystick(joystick: Node) -> void:
	"""Enregistre le joystick de visée."""
	_look_joystick = joystick
	
	if joystick.has_signal("joystick_input"):
		joystick.joystick_input.connect(_on_look_joystick_input)


func _on_movement_joystick_input(direction: Vector2) -> void:
	"""Callback du joystick de mouvement."""
	if direction.length() < virtual_joystick_deadzone:
		direction = Vector2.ZERO
	
	if direction != _movement_direction:
		_movement_direction = direction
		movement_changed.emit(_movement_direction)


func _on_look_joystick_input(direction: Vector2) -> void:
	"""Callback du joystick de visée."""
	_look_direction = direction
	look_changed.emit(_look_direction)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_movement_direction() -> Vector2:
	"""Retourne la direction de mouvement normalisée."""
	return _movement_direction


func get_look_direction() -> Vector2:
	"""Retourne la direction de visée."""
	return _look_direction


func is_action_pressed(action: GameAction) -> bool:
	"""Vérifie si une action est pressée."""
	return _action_states.get(action, false)


func is_action_just_pressed(action: GameAction) -> bool:
	"""Vérifie si une action vient d'être pressée."""
	var action_name := _game_action_to_input(action)
	return Input.is_action_just_pressed(action_name)


func is_action_just_released(action: GameAction) -> bool:
	"""Vérifie si une action vient d'être relâchée."""
	var action_name := _game_action_to_input(action)
	return Input.is_action_just_released(action_name)


func _game_action_to_input(action: GameAction) -> String:
	"""Convertit une GameAction en nom d'input Godot."""
	match action:
		GameAction.ATTACK: return "attack"
		GameAction.DODGE: return "dash"
		GameAction.INTERACT: return "interact"
		GameAction.PAUSE: return "pause"
		GameAction.SONAR_PING: return "ping_navigation"
		_: return ""


func get_movement_3d() -> Vector3:
	"""Retourne la direction de mouvement en 3D (pour le joueur)."""
	return Vector3(_movement_direction.x, 0, _movement_direction.y)


## Remapping
func remap_action(action: GameAction, new_input: InputEvent) -> void:
	"""Remappe une action."""
	var action_name := _game_action_to_input(action)
	if action_name.is_empty():
		return
	
	# Supprimer les anciens events
	InputMap.action_erase_events(action_name)
	
	# Ajouter le nouveau
	InputMap.action_add_event(action_name, new_input)
	
	_input_remapping[action] = new_input


func reset_remapping() -> void:
	"""Reset le remapping aux valeurs par défaut."""
	InputMap.load_from_project_settings()
	_input_remapping.clear()


func get_platform_type() -> String:
	"""Retourne le type de plateforme."""
	return "mobile" if is_mobile else "desktop"


func vibrate(duration_ms: int = 100) -> void:
	"""Vibration (mobile uniquement)."""
	if is_mobile:
		Input.vibrate_handheld(duration_ms)
