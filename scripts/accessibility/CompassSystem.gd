# ==============================================================================
# CompassSystem.gd - Système de boussole pour orientation
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Permet aux joueurs de s'orienter facilement vers les points cardinaux
# Utile pour les joueurs non-voyants qui peuvent perdre leur orientation
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal direction_changed(cardinal: String)
signal snapped_to_direction(cardinal: String)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const CARDINAL_DIRECTIONS := {
	"N": 0.0,      # Nord
	"NE": 45.0,    # Nord-Est
	"E": 90.0,     # Est
	"SE": 135.0,   # Sud-Est
	"S": 180.0,    # Sud
	"SW": 225.0,   # Sud-Ouest (SO)
	"W": 270.0,    # Ouest
	"NW": 315.0    # Nord-Ouest (NO)
}

const CARDINAL_NAMES := {
	"N": "Nord",
	"NE": "Nord-Est",
	"E": "Est",
	"SE": "Sud-Est",
	"S": "Sud",
	"SW": "Sud-Ouest",
	"W": "Ouest",
	"NW": "Nord-Ouest"
}

# ==============================================================================
# VARIABLES
# ==============================================================================
var player_ref: Node3D = null
var _last_announced_direction: String = ""
var _announce_cooldown: float = 0.0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système de boussole."""
	await get_tree().process_frame
	_find_player()


func _process(delta: float) -> void:
	"""Mise à jour du cooldown."""
	if _announce_cooldown > 0:
		_announce_cooldown -= delta


func _input(event: InputEvent) -> void:
	"""Gestion des entrées pour le snap de direction."""
	# Snap vers le Nord
	if event.is_action_pressed("compass_snap_north"):
		snap_to_direction("N")
	# Annoncer la direction actuelle
	elif event.is_action_pressed("compass_announce"):
		announce_current_direction()


# ==============================================================================
# FONCTIONS PRINCIPALES
# ==============================================================================

func get_current_direction() -> String:
	"""
	Retourne la direction cardinale actuelle du joueur.
	@return: Code de direction (N, NE, E, SE, S, SW, W, NW)
	"""
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		if not player_ref:
			return "N"
	
	# Obtenir la rotation Y du joueur (en degrés)
	var rotation_y := rad_to_deg(player_ref.rotation.y)
	
	# Normaliser entre 0 et 360
	rotation_y = fmod(rotation_y, 360.0)
	if rotation_y < 0:
		rotation_y += 360.0
	
	# Trouver la direction cardinale la plus proche
	var closest_direction := "N"
	var closest_diff := 360.0
	
	for dir_code in CARDINAL_DIRECTIONS:
		var dir_angle: float = CARDINAL_DIRECTIONS[dir_code]
		var diff := abs(rotation_y - dir_angle)
		# Gérer le wrap-around (ex: 350° est proche de 0°)
		if diff > 180:
			diff = 360 - diff
		
		if diff < closest_diff:
			closest_diff = diff
			closest_direction = dir_code
	
	return closest_direction


func get_current_angle() -> float:
	"""Retourne l'angle actuel en degrés (0-360)."""
	if not player_ref or not is_instance_valid(player_ref):
		return 0.0
	
	var rotation_y := rad_to_deg(player_ref.rotation.y)
	rotation_y = fmod(rotation_y, 360.0)
	if rotation_y < 0:
		rotation_y += 360.0
	return rotation_y


func snap_to_direction(cardinal: String) -> void:
	"""
	Fait tourner le joueur vers une direction cardinale.
	@param cardinal: Code de direction (N, NE, E, SE, S, SW, W, NW)
	"""
	if not CARDINAL_DIRECTIONS.has(cardinal):
		push_warning("CompassSystem: Direction invalide: " + cardinal)
		return
	
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		if not player_ref:
			return
	
	var target_angle: float = CARDINAL_DIRECTIONS[cardinal]
	player_ref.rotation.y = deg_to_rad(target_angle)
	
	snapped_to_direction.emit(cardinal)
	
	# Annonce TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Orienté vers " + CARDINAL_NAMES[cardinal])
	
	# Haptic
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic and haptic.has_method("vibrate_light"):
		haptic.vibrate_light()


func snap_to_nearest_cardinal() -> void:
	"""Aligne le joueur vers la direction cardinale la plus proche."""
	var current := get_current_direction()
	snap_to_direction(current)


func snap_to_next_direction(clockwise: bool = true) -> void:
	"""
	Fait tourner vers la direction cardinale suivante.
	@param clockwise: true pour sens horaire, false pour anti-horaire
	"""
	var directions := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var current := get_current_direction()
	var current_index := directions.find(current)
	
	if clockwise:
		current_index = (current_index + 1) % 8
	else:
		current_index = (current_index - 1 + 8) % 8
	
	snap_to_direction(directions[current_index])


# ==============================================================================
# ANNONCES
# ==============================================================================

func announce_current_direction() -> void:
	"""Annonce la direction actuelle via TTS."""
	if _announce_cooldown > 0:
		return
	
	var current := get_current_direction()
	var angle := get_current_angle()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Direction: %s, %.0f degrés" % [CARDINAL_NAMES[current], angle])
	
	direction_changed.emit(current)
	_last_announced_direction = current
	_announce_cooldown = 0.5


func get_direction_to_target(target_pos: Vector3) -> Dictionary:
	"""
	Retourne la direction et la distance vers une cible.
	@param target_pos: Position mondiale de la cible
	@return: {"cardinal": String, "angle": float, "distance": float}
	"""
	if not player_ref:
		return {"cardinal": "N", "angle": 0.0, "distance": 0.0}
	
	var player_pos := player_ref.global_position
	var direction := (target_pos - player_pos)
	direction.y = 0
	direction = direction.normalized()
	
	# Calculer l'angle par rapport au Nord (Z-)
	var angle := rad_to_deg(atan2(direction.x, -direction.z))
	if angle < 0:
		angle += 360
	
	# Distance
	var distance := player_pos.distance_to(target_pos)
	
	# Cardinal le plus proche
	var closest_dir := "N"
	var closest_diff := 360.0
	for dir_code in CARDINAL_DIRECTIONS:
		var dir_angle: float = CARDINAL_DIRECTIONS[dir_code]
		var diff := abs(angle - dir_angle)
		if diff > 180:
			diff = 360 - diff
		if diff < closest_diff:
			closest_diff = diff
			closest_dir = dir_code
	
	return {
		"cardinal": closest_dir,
		"cardinal_name": CARDINAL_NAMES[closest_dir],
		"angle": angle,
		"distance": distance
	}


func announce_direction_to_target(target_pos: Vector3, target_name: String = "") -> void:
	"""
	Annonce la direction vers une cible.
	@param target_pos: Position de la cible
	@param target_name: Nom optionnel de la cible
	"""
	var info := get_direction_to_target(target_pos)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		var message := ""
		if target_name != "":
			message = "%s: " % target_name
		message += "%s, %.0f mètres" % [info["cardinal_name"], info["distance"]]
		tts.speak(message)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as Node3D


func get_cardinal_list() -> Array:
	"""Retourne la liste des directions cardinales."""
	return CARDINAL_DIRECTIONS.keys()


func get_cardinal_name(code: String) -> String:
	"""Retourne le nom complet d'une direction."""
	return CARDINAL_NAMES.get(code, "Inconnu")
