# ==============================================================================
# PlatformUIController.gd - Gestion UI selon la plateforme
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Affiche/cache les contrôles UI selon la plateforme (Mobile vs Desktop).
# Gère le curseur souris et les indicateurs de contrôles clavier.
# ==============================================================================

extends Node
class_name PlatformUIController

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal platform_changed(is_mobile: bool)
signal input_mode_changed(mode: String)  # "keyboard", "mouse", "touch", "gamepad"

# ==============================================================================
# CONSTANTES
# ==============================================================================
enum InputMode {
	KEYBOARD_MOUSE,
	TOUCH,
	GAMEPAD
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Touch Controls")
@export var touch_joystick_left: Control  ## Joystick de mouvement
@export var touch_joystick_right: Control  ## Joystick de visée (optionnel)
@export var touch_buttons_container: Control  ## Container des boutons touch
@export var touch_dpad: Control  ## D-Pad alternatif (optionnel)

@export_group("Desktop UI")
@export var keyboard_hints_container: Control  ## Container des hints clavier
@export var crosshair: Control  ## Réticule de visée
@export var escape_menu_hint: Control  ## Hint "Appuyez sur ESC"

@export_group("Settings")
@export var capture_mouse_on_desktop: bool = true
@export var show_keyboard_hints: bool = true
@export var auto_detect_input_change: bool = true

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_mobile: bool = false
var current_input_mode: InputMode = InputMode.KEYBOARD_MOUSE
var _mouse_captured: bool = false
var _last_input_device: String = ""

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du contrôleur UI plateforme."""
	_detect_platform()
	_apply_platform_settings()
	_setup_mouse_capture()
	
	print("PlatformUIController: Plateforme = %s" % ("Mobile" if is_mobile else "Desktop"))


func _input(event: InputEvent) -> void:
	"""Détecte le changement de mode d'input."""
	if not auto_detect_input_change:
		return
	
	var new_mode := current_input_mode
	
	# Détection du type d'input
	if event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton:
		new_mode = InputMode.KEYBOARD_MOUSE
		_last_input_device = "keyboard"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		new_mode = InputMode.TOUCH
		_last_input_device = "touch"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_mode = InputMode.GAMEPAD
		_last_input_device = "gamepad"
	
	if new_mode != current_input_mode:
		current_input_mode = new_mode
		_on_input_mode_changed()


func _notification(what: int) -> void:
	"""Gestion des notifications système."""
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if not is_mobile and capture_mouse_on_desktop:
				_capture_mouse()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_release_mouse()


# ==============================================================================
# DÉTECTION PLATEFORME
# ==============================================================================

func _detect_platform() -> void:
	"""Détecte la plateforme actuelle."""
	var os_name := OS.get_name()
	
	match os_name:
		"Android", "iOS":
			is_mobile = true
			current_input_mode = InputMode.TOUCH
		"Windows", "Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			is_mobile = false
			current_input_mode = InputMode.KEYBOARD_MOUSE
		"Web":
			# Web: vérifier les capacités tactiles
			is_mobile = DisplayServer.is_touchscreen_available()
			current_input_mode = InputMode.TOUCH if is_mobile else InputMode.KEYBOARD_MOUSE
		_:
			is_mobile = DisplayServer.is_touchscreen_available()


func _apply_platform_settings() -> void:
	"""Applique les settings selon la plateforme."""
	if is_mobile:
		_setup_mobile_ui()
	else:
		_setup_desktop_ui()
	
	platform_changed.emit(is_mobile)


# ==============================================================================
# CONFIGURATION UI MOBILE
# ==============================================================================

func _setup_mobile_ui() -> void:
	"""Configure l'UI pour mobile."""
	# Afficher les contrôles tactiles
	_set_control_visible(touch_joystick_left, true)
	_set_control_visible(touch_joystick_right, true)
	_set_control_visible(touch_buttons_container, true)
	_set_control_visible(touch_dpad, true)
	
	# Cacher les éléments desktop
	_set_control_visible(keyboard_hints_container, false)
	_set_control_visible(crosshair, false)
	_set_control_visible(escape_menu_hint, false)
	
	# Désactiver la capture souris
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_desktop_ui() -> void:
	"""Configure l'UI pour desktop."""
	# Cacher les contrôles tactiles
	_set_control_visible(touch_joystick_left, false)
	_set_control_visible(touch_joystick_right, false)
	_set_control_visible(touch_buttons_container, false)
	_set_control_visible(touch_dpad, false)
	
	# Afficher les éléments desktop
	_set_control_visible(keyboard_hints_container, show_keyboard_hints)
	_set_control_visible(crosshair, true)
	_set_control_visible(escape_menu_hint, true)


func _set_control_visible(control: Control, visible: bool) -> void:
	"""Helper pour la visibilité des controls."""
	if control:
		control.visible = visible


# ==============================================================================
# GESTION SOURIS (DESKTOP)
# ==============================================================================

func _setup_mouse_capture() -> void:
	"""Configure la capture souris pour le desktop."""
	if is_mobile:
		return
	
	if capture_mouse_on_desktop:
		_capture_mouse()


func _capture_mouse() -> void:
	"""Capture la souris (mode FPS)."""
	if is_mobile:
		return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true


func _release_mouse() -> void:
	"""Libère la souris."""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false


func toggle_mouse_capture() -> void:
	"""Bascule la capture souris."""
	if _mouse_captured:
		_release_mouse()
	else:
		_capture_mouse()


func is_mouse_captured() -> bool:
	"""Retourne l'état de capture souris."""
	return _mouse_captured


# ==============================================================================
# CHANGEMENT DE MODE D'INPUT
# ==============================================================================

func _on_input_mode_changed() -> void:
	"""Appelé quand le mode d'input change."""
	match current_input_mode:
		InputMode.KEYBOARD_MOUSE:
			_setup_desktop_ui()
			input_mode_changed.emit("keyboard")
		InputMode.TOUCH:
			_setup_mobile_ui()
			input_mode_changed.emit("touch")
		InputMode.GAMEPAD:
			_setup_gamepad_ui()
			input_mode_changed.emit("gamepad")


func _setup_gamepad_ui() -> void:
	"""Configure l'UI pour manette."""
	# Cacher les contrôles tactiles
	_set_control_visible(touch_joystick_left, false)
	_set_control_visible(touch_joystick_right, false)
	_set_control_visible(touch_buttons_container, false)
	
	# Afficher les hints manette au lieu du clavier
	_set_control_visible(keyboard_hints_container, show_keyboard_hints)
	_set_control_visible(crosshair, true)
	
	# Libérer la souris pour les menus
	_release_mouse()


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_input_mode() -> InputMode:
	"""Retourne le mode d'input actuel."""
	return current_input_mode


func get_input_mode_name() -> String:
	"""Retourne le nom du mode d'input."""
	match current_input_mode:
		InputMode.KEYBOARD_MOUSE: return "keyboard_mouse"
		InputMode.TOUCH: return "touch"
		InputMode.GAMEPAD: return "gamepad"
		_: return "unknown"


func force_mobile_mode(enabled: bool) -> void:
	"""Force le mode mobile (pour les tests)."""
	is_mobile = enabled
	_apply_platform_settings()


func force_desktop_mode(enabled: bool) -> void:
	"""Force le mode desktop (pour les tests)."""
	is_mobile = not enabled
	_apply_platform_settings()


func refresh_platform_ui() -> void:
	"""Rafraîchit l'UI selon la plateforme actuelle."""
	_apply_platform_settings()


# ==============================================================================
# HELPERS POUR LES HINTS
# ==============================================================================

func get_action_hint(action: String) -> String:
	"""Retourne le texte d'aide pour une action selon le mode."""
	match current_input_mode:
		InputMode.KEYBOARD_MOUSE:
			return _get_keyboard_hint(action)
		InputMode.TOUCH:
			return _get_touch_hint(action)
		InputMode.GAMEPAD:
			return _get_gamepad_hint(action)
		_:
			return action


func _get_keyboard_hint(action: String) -> String:
	"""Retourne le hint clavier pour une action."""
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return action
	
	var event := events[0]
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return OS.get_keycode_string(key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode)
	elif event is InputEventMouseButton:
		var btn_event := event as InputEventMouseButton
		match btn_event.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "Mouse" + str(btn_event.button_index)
	
	return action


func _get_touch_hint(action: String) -> String:
	"""Retourne le hint tactile pour une action."""
	match action:
		"attack": return "Tap Right"
		"dash": return "Swipe"
		"interact": return "Tap Object"
		"pause": return "Menu Button"
		_: return "Touch"


func _get_gamepad_hint(action: String) -> String:
	"""Retourne le hint manette pour une action."""
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventJoypadButton:
			var btn := event as InputEventJoypadButton
			match btn.button_index:
				JOY_BUTTON_A: return "A"
				JOY_BUTTON_B: return "B"
				JOY_BUTTON_X: return "X"
				JOY_BUTTON_Y: return "Y"
				JOY_BUTTON_LEFT_SHOULDER: return "LB"
				JOY_BUTTON_RIGHT_SHOULDER: return "RB"
				_: return "Button"
	return action


# ==============================================================================
# INTÉGRATION AVEC ACCESSIBILITY
# ==============================================================================

func announce_platform() -> void:
	"""Annonce la plateforme via TTS."""
	var tts := get_node_or_null("/root/TTSManager")
	if tts and tts.has_method("speak"):
		var platform := "mobile" if is_mobile else "PC"
		tts.speak("Mode %s détecté" % platform)
