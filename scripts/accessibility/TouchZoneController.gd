# ==============================================================================
# TouchZoneController.gd - Contrôleur de zones tactiles pour non-voyants
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Divise l'écran en zones pour permettre le jeu sans vision
# Gère les gestes tactiles (tap, swipe, hold, double-tap)
# ==============================================================================

extends Control
class_name TouchZoneController

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal move_forward_requested
signal move_backward_requested
signal turn_left_requested
signal turn_right_requested
signal attack_requested
signal interact_requested
signal dash_requested
signal use_item_requested
signal menu_requested
signal announce_surroundings_requested
signal gesture_recognized(zone: Zone, gesture: Gesture)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum Zone {
	TOP,      # Menu / Annonces
	LEFT,     # Mouvement
	RIGHT,    # Actions
	BOTTOM    # Actions spéciales
}

enum Gesture {
	TAP,
	DOUBLE_TAP,
	HOLD,
	SWIPE_UP,
	SWIPE_DOWN,
	SWIPE_LEFT,
	SWIPE_RIGHT
}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const DOUBLE_TAP_TIME := 0.3  # Temps max entre deux taps
const HOLD_TIME := 0.5  # Temps pour un hold
const SWIPE_THRESHOLD := 50.0  # Distance min pour un swipe (pixels)
const HAPTIC_DURATION := 50  # Durée vibration en ms

# Zone proportions (en pourcentage de l'écran)
const TOP_ZONE_HEIGHT := 0.15
const BOTTOM_ZONE_HEIGHT := 0.15
const LEFT_ZONE_WIDTH := 0.4

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var player: Node3D  ## Référence au joueur
@export var haptic_feedback: bool = true  ## Activer vibrations
@export var audio_feedback: bool = true  ## Activer sons de feedback

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_active: bool = false
var _touches: Dictionary = {}  # touch_index -> TouchData
var _last_tap_time: float = 0.0
var _last_tap_zone: Zone = Zone.LEFT
var _movement_direction: Vector2 = Vector2.ZERO

# Structure pour tracker les touches
class TouchData:
	var start_position: Vector2
	var current_position: Vector2
	var start_time: float
	var zone: Zone
	var is_hold: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du contrôleur."""
	# Couvrir tout l'écran
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Trouver le joueur
	await get_tree().process_frame
	_find_player()


func _input(event: InputEvent) -> void:
	"""Gestion des événements tactiles."""
	if not is_active:
		return
	
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _process(delta: float) -> void:
	"""Mise à jour continue."""
	if not is_active:
		return
	
	# Vérifier les holds en cours
	var current_time := Time.get_ticks_msec() / 1000.0
	for touch_index in _touches:
		var touch: TouchData = _touches[touch_index]
		if not touch.is_hold and (current_time - touch.start_time) >= HOLD_TIME:
			touch.is_hold = true
			_on_hold_detected(touch.zone)
	
	# Envoyer le mouvement continu si en cours
	if _movement_direction != Vector2.ZERO and player:
		if player.has_method("set_movement_input"):
			player.set_movement_input(_movement_direction)


# ==============================================================================
# GESTION DES TOUCHES
# ==============================================================================

func _handle_touch(event: InputEventScreenTouch) -> void:
	"""Gère les événements de toucher."""
	var touch_index := event.index
	
	if event.pressed:
		# Nouveau toucher
		var zone := _get_zone_at_position(event.position)
		var touch_data := TouchData.new()
		touch_data.start_position = event.position
		touch_data.current_position = event.position
		touch_data.start_time = Time.get_ticks_msec() / 1000.0
		touch_data.zone = zone
		_touches[touch_index] = touch_data
		
		# Feedback haptique
		if haptic_feedback:
			Input.vibrate_handheld(HAPTIC_DURATION)
	else:
		# Relâchement
		if _touches.has(touch_index):
			var touch: TouchData = _touches[touch_index]
			_process_gesture(touch)
			_touches.erase(touch_index)
		
		# Arrêter le mouvement si plus de touche dans zone gauche
		var has_left_touch := false
		for t in _touches.values():
			if t.zone == Zone.LEFT:
				has_left_touch = true
				break
		if not has_left_touch:
			_movement_direction = Vector2.ZERO
			if player and player.has_method("set_movement_input"):
				player.set_movement_input(Vector2.ZERO)


func _handle_drag(event: InputEventScreenDrag) -> void:
	"""Gère le glissement."""
	var touch_index := event.index
	if _touches.has(touch_index):
		_touches[touch_index].current_position = event.position


func _process_gesture(touch: TouchData) -> void:
	"""Analyse la gesture effectuée."""
	var duration := (Time.get_ticks_msec() / 1000.0) - touch.start_time
	var delta := touch.current_position - touch.start_position
	var distance := delta.length()
	
	# Hold déjà traité dans _process
	if touch.is_hold:
		return
	
	# Détecter swipe
	if distance >= SWIPE_THRESHOLD:
		var gesture := _detect_swipe_direction(delta)
		_on_gesture(touch.zone, gesture)
		return
	
	# Détecter double-tap
	var current_time := Time.get_ticks_msec() / 1000.0
	if (current_time - _last_tap_time) < DOUBLE_TAP_TIME and _last_tap_zone == touch.zone:
		_on_gesture(touch.zone, Gesture.DOUBLE_TAP)
		_last_tap_time = 0.0  # Reset pour éviter triple-tap
	else:
		# Simple tap
		_on_gesture(touch.zone, Gesture.TAP)
		_last_tap_time = current_time
		_last_tap_zone = touch.zone


func _detect_swipe_direction(delta: Vector2) -> Gesture:
	"""Détecte la direction du swipe."""
	if abs(delta.x) > abs(delta.y):
		# Swipe horizontal
		return Gesture.SWIPE_RIGHT if delta.x > 0 else Gesture.SWIPE_LEFT
	else:
		# Swipe vertical
		return Gesture.SWIPE_UP if delta.y < 0 else Gesture.SWIPE_DOWN


# ==============================================================================
# TRAITEMENT DES GESTES
# ==============================================================================

func _on_gesture(zone: Zone, gesture: Gesture) -> void:
	"""Traite un geste reconnu."""
	gesture_recognized.emit(zone, gesture)
	
	match zone:
		Zone.TOP:
			_handle_top_zone_gesture(gesture)
		Zone.LEFT:
			_handle_left_zone_gesture(gesture)
		Zone.RIGHT:
			_handle_right_zone_gesture(gesture)
		Zone.BOTTOM:
			_handle_bottom_zone_gesture(gesture)


func _on_hold_detected(zone: Zone) -> void:
	"""Traite un hold détecté."""
	gesture_recognized.emit(zone, Gesture.HOLD)
	
	match zone:
		Zone.LEFT:
			# Hold gauche = avancer continu
			_movement_direction = Vector2(0, -1)  # Forward
			move_forward_requested.emit()
		Zone.RIGHT:
			# Hold droite = interaction
			interact_requested.emit()
			if player and player.has_method("request_interact"):
				player.request_interact()
			_speak_action("Interaction")


func _handle_top_zone_gesture(gesture: Gesture) -> void:
	"""Gère les gestes dans la zone supérieure."""
	match gesture:
		Gesture.TAP:
			# Annoncer l'environnement
			announce_surroundings_requested.emit()
			_speak_action("Analyse")
		Gesture.DOUBLE_TAP:
			# Ouvrir le menu
			menu_requested.emit()
			_speak_action("Menu")
		Gesture.SWIPE_DOWN:
			# Fermer le menu ou retour
			_speak_action("Retour")


func _handle_left_zone_gesture(gesture: Gesture) -> void:
	"""Gère les gestes dans la zone gauche (mouvement)."""
	match gesture:
		Gesture.TAP:
			# Avancer brièvement
			_movement_direction = Vector2(0, -1)
			move_forward_requested.emit()
			# Arrêter après un court délai
			await get_tree().create_timer(0.3).timeout
			_movement_direction = Vector2.ZERO
		Gesture.DOUBLE_TAP:
			# Reculer
			_movement_direction = Vector2(0, 1)
			move_backward_requested.emit()
			await get_tree().create_timer(0.3).timeout
			_movement_direction = Vector2.ZERO
		Gesture.SWIPE_LEFT:
			# Tourner à gauche
			turn_left_requested.emit()
			_rotate_player(-45)
			_speak_action("Gauche")
		Gesture.SWIPE_RIGHT:
			# Tourner à droite
			turn_right_requested.emit()
			_rotate_player(45)
			_speak_action("Droite")
		Gesture.SWIPE_UP:
			# Avancer
			_movement_direction = Vector2(0, -1)
			move_forward_requested.emit()
		Gesture.SWIPE_DOWN:
			# Reculer
			_movement_direction = Vector2(0, 1)
			move_backward_requested.emit()


func _handle_right_zone_gesture(gesture: Gesture) -> void:
	"""Gère les gestes dans la zone droite (actions)."""
	match gesture:
		Gesture.TAP:
			# Attaque simple
			attack_requested.emit()
			if player and player.has_method("request_attack"):
				player.request_attack()
			_speak_action("Attaque")
		Gesture.DOUBLE_TAP:
			# Attaque puissante / combo
			attack_requested.emit()
			if player and player.has_method("request_attack"):
				player.request_attack()
			_speak_action("Attaque double")
		Gesture.SWIPE_UP:
			# Dash
			dash_requested.emit()
			if player and player.has_method("request_dash"):
				player.request_dash()
			_speak_action("Dash")
		Gesture.SWIPE_DOWN:
			# Esquive / Accroupir
			_speak_action("Esquive")
		Gesture.SWIPE_LEFT, Gesture.SWIPE_RIGHT:
			# Changer de cible
			_speak_action("Changement de cible")


func _handle_bottom_zone_gesture(gesture: Gesture) -> void:
	"""Gère les gestes dans la zone inférieure."""
	match gesture:
		Gesture.TAP:
			# Utiliser objet
			use_item_requested.emit()
			_speak_action("Utilisation objet")
		Gesture.SWIPE_UP:
			# Objet suivant
			_speak_action("Objet suivant")
		Gesture.SWIPE_DOWN:
			# Objet précédent
			_speak_action("Objet précédent")


# ==============================================================================
# ZONES DE L'ÉCRAN
# ==============================================================================

func _get_zone_at_position(position: Vector2) -> Zone:
	"""Détermine la zone d'écran à une position donnée."""
	var viewport_size := get_viewport_rect().size
	
	# Calculer les limites
	var top_limit := viewport_size.y * TOP_ZONE_HEIGHT
	var bottom_limit := viewport_size.y * (1.0 - BOTTOM_ZONE_HEIGHT)
	var left_limit := viewport_size.x * LEFT_ZONE_WIDTH
	
	# Déterminer la zone
	if position.y < top_limit:
		return Zone.TOP
	elif position.y > bottom_limit:
		return Zone.BOTTOM
	elif position.x < left_limit:
		return Zone.LEFT
	else:
		return Zone.RIGHT


# ==============================================================================
# ACTIONS SUR LE JOUEUR
# ==============================================================================

func _rotate_player(degrees: float) -> void:
	"""Fait tourner le joueur."""
	if player and player.has_node("MeshPivot"):
		var mesh = player.get_node("MeshPivot")
		mesh.rotation.y += deg_to_rad(degrees)


# ==============================================================================
# FEEDBACK
# ==============================================================================

func _speak_action(action: String) -> void:
	"""Annonce une action via TTS."""
	if not audio_feedback:
		return
	
	# Utiliser BlindAccessibilityManager si disponible
	var blind_manager = get_node_or_null("/root/BlindAccessibilityManager")
	if blind_manager and blind_manager.has_method("speak"):
		blind_manager.speak(action, false)


# ==============================================================================
# ACTIVATION
# ==============================================================================

func activate() -> void:
	"""Active le contrôleur de zones tactiles."""
	is_active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func deactivate() -> void:
	"""Désactive le contrôleur."""
	is_active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_movement_direction = Vector2.ZERO
	if player and player.has_method("set_movement_input"):
		player.set_movement_input(Vector2.ZERO)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	if player:
		return
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node3D:
		player = players[0]


func get_zone_name(zone: Zone) -> String:
	"""Retourne le nom d'une zone."""
	match zone:
		Zone.TOP:
			return "Menu"
		Zone.LEFT:
			return "Mouvement"
		Zone.RIGHT:
			return "Actions"
		Zone.BOTTOM:
			return "Spécial"
	return "Inconnu"


func get_gesture_name(gesture: Gesture) -> String:
	"""Retourne le nom d'un geste."""
	match gesture:
		Gesture.TAP:
			return "Tap"
		Gesture.DOUBLE_TAP:
			return "Double Tap"
		Gesture.HOLD:
			return "Maintien"
		Gesture.SWIPE_UP:
			return "Glisser haut"
		Gesture.SWIPE_DOWN:
			return "Glisser bas"
		Gesture.SWIPE_LEFT:
			return "Glisser gauche"
		Gesture.SWIPE_RIGHT:
			return "Glisser droite"
	return "Inconnu"
