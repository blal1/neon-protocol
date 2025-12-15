# ==============================================================================
# BlindAccessibilityManager.gd - Gestionnaire d'accessibilité pour non-voyants
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Autoload Singleton gérant les fonctionnalités pour les joueurs aveugles
# TTS, Audio 3D, et coordination avec TouchZoneController
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal spoke(text: String)
signal speech_finished
signal blind_mode_activated
signal blind_mode_deactivated
signal enemy_detected(enemy: Node3D, direction: Vector3, distance: float)
signal item_detected(item: Node3D, item_type: String, direction: Vector3)
signal navigation_hint(direction: String, distance: float)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SCAN_INTERVAL := 0.5  # Intervalle de scan en secondes
const ENEMY_SCAN_RADIUS := 15.0  # Rayon de détection des ennemis
const ITEM_SCAN_RADIUS := 10.0  # Rayon de détection des objets
const DIRECTION_NAMES := {
	"front": "devant",
	"back": "derrière",
	"left": "à gauche",
	"right": "à droite",
	"front_left": "devant à gauche",
	"front_right": "devant à droite",
	"back_left": "derrière à gauche",
	"back_right": "derrière à droite"
}

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_active: bool = false
var player_ref: Node3D = null
var _scan_timer: float = 0.0
var _speech_queue: Array[String] = []
var _is_speaking: bool = false
var _tts_available: bool = false

# Références aux systèmes audio
var audio_cue_system: Node = null
var touch_zone_controller: Node = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du manager."""
	# Vérifier si TTS est disponible
	_tts_available = DisplayServer.tts_is_speaking() or true  # Godot 4 supporte TTS
	
	# Trouver le joueur
	await get_tree().process_frame
	_find_player()


func _process(delta: float) -> void:
	"""Mise à jour continue."""
	if not is_active:
		return
	
	# Scanner l'environnement périodiquement
	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_environment()
	
	# Traiter la file de parole
	_process_speech_queue()


# ==============================================================================
# ACTIVATION / DÉSACTIVATION
# ==============================================================================

func activate() -> void:
	"""Active le mode accessibilité pour non-voyants."""
	if is_active:
		return
	
	is_active = true
	blind_mode_activated.emit()
	
	# Annoncer l'activation
	speak("Mode accessibilité activé. Utilisez les gestes tactiles pour jouer.", true)
	
	# Décrire la situation initiale
	await get_tree().create_timer(2.0).timeout
	announce_surroundings()


func deactivate() -> void:
	"""Désactive le mode accessibilité pour non-voyants."""
	if not is_active:
		return
	
	is_active = false
	blind_mode_deactivated.emit()
	
	speak("Mode accessibilité désactivé.", true)


func toggle() -> void:
	"""Bascule le mode accessibilité."""
	if is_active:
		deactivate()
	else:
		activate()


# ==============================================================================
# TEXT-TO-SPEECH (TTS)
# ==============================================================================

func speak(text: String, interrupt: bool = false) -> void:
	"""
	Lit un texte à voix haute via TTS.
	@param text: Texte à lire
	@param interrupt: Si true, interrompt la parole en cours
	"""
	if not _tts_available:
		print("[TTS] ", text)
		spoke.emit(text)
		return
	
	if interrupt:
		# Arrêter la parole en cours
		DisplayServer.tts_stop()
		_speech_queue.clear()
		_is_speaking = false
	
	# Ajouter à la file
	_speech_queue.append(text)
	spoke.emit(text)


func speak_immediate(text: String) -> void:
	"""Lit immédiatement un texte, interrompant tout."""
	speak(text, true)


func _process_speech_queue() -> void:
	"""Traite la file d'attente de parole."""
	if _is_speaking or _speech_queue.is_empty():
		return
	
	if DisplayServer.tts_is_speaking():
		return
	
	_is_speaking = true
	var text: String = _speech_queue.pop_front()
	
	# Utiliser le TTS de Godot
	DisplayServer.tts_speak(text, DisplayServer.tts_get_voices()[0] if DisplayServer.tts_get_voices().size() > 0 else "")
	
	# Timer pour estimer la fin de la parole
	var estimated_duration: float = text.length() * 0.05  # ~50ms par caractère
	await get_tree().create_timer(estimated_duration).timeout
	_is_speaking = false
	speech_finished.emit()


# ==============================================================================
# SCAN DE L'ENVIRONNEMENT
# ==============================================================================

func _scan_environment() -> void:
	"""Scanne l'environnement pour détecter ennemis et objets."""
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		return
	
	# Scanner les ennemis
	_scan_enemies()
	
	# Scanner les objets
	_scan_items()


func _scan_enemies() -> void:
	"""Détecte les ennemis proches."""
	var enemies := get_tree().get_nodes_in_group("enemy")
	var closest_enemy: Node3D = null
	var closest_distance := ENEMY_SCAN_RADIUS
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		
		# Vérifier si l'ennemi est vivant
		var health = enemy.get_node_or_null("HealthComponent")
		if health and health.is_dead:
			continue
		
		var distance := player_ref.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	# Émettre signal si ennemi détecté
	if closest_enemy:
		var direction := _get_direction_to_target(closest_enemy)
		enemy_detected.emit(closest_enemy, direction, closest_distance)
		
		# Jouer un son spatial si AudioCueSystem disponible
		if audio_cue_system and audio_cue_system.has_method("play_enemy_cue"):
			audio_cue_system.play_enemy_cue(closest_enemy.global_position, closest_distance)


func _scan_items() -> void:
	"""Détecte les objets interactifs proches."""
	var items := get_tree().get_nodes_in_group("interactable")
	
	for item in items:
		if not is_instance_valid(item) or not item is Node3D:
			continue
		
		var distance := player_ref.global_position.distance_to(item.global_position)
		if distance <= ITEM_SCAN_RADIUS:
			var direction := _get_direction_to_target(item)
			var item_type := _get_item_type(item)
			item_detected.emit(item, item_type, direction)


func _get_direction_to_target(target: Node3D) -> Vector3:
	"""Calcule la direction vers une cible."""
	if not player_ref:
		return Vector3.FORWARD
	
	var direction := (target.global_position - player_ref.global_position).normalized()
	return direction


func _get_item_type(item: Node) -> String:
	"""Détermine le type d'un objet."""
	if item.is_in_group("weapon"):
		return "arme"
	elif item.is_in_group("health"):
		return "soin"
	elif item.is_in_group("door"):
		return "porte"
	elif item.is_in_group("npc"):
		return "personnage"
	else:
		return "objet"


# ==============================================================================
# ANNONCES CONTEXTUELLES
# ==============================================================================

func announce_surroundings() -> void:
	"""Annonce une description de l'environnement actuel."""
	if not player_ref:
		speak("Impossible de déterminer votre position.")
		return
	
	var announcement := "Analyse de l'environnement. "
	
	# Compter les ennemis
	var enemies := get_tree().get_nodes_in_group("enemy")
	var alive_enemies := 0
	var closest_enemy_distance := INF
	var closest_enemy_direction := ""
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var health = enemy.get_node_or_null("HealthComponent")
		if health and health.is_dead:
			continue
		
		alive_enemies += 1
		var distance := player_ref.global_position.distance_to(enemy.global_position)
		if distance < closest_enemy_distance:
			closest_enemy_distance = distance
			closest_enemy_direction = _get_direction_name(_get_direction_to_target(enemy))
	
	if alive_enemies == 0:
		announcement += "Aucun ennemi détecté. "
	elif alive_enemies == 1:
		announcement += "Un ennemi %s à %.0f mètres. " % [closest_enemy_direction, closest_enemy_distance]
	else:
		announcement += "%d ennemis détectés. Le plus proche est %s à %.0f mètres. " % [
			alive_enemies, closest_enemy_direction, closest_enemy_distance
		]
	
	# Objets interactifs
	var items := get_tree().get_nodes_in_group("interactable")
	var item_count := 0
	for item in items:
		if is_instance_valid(item) and item is Node3D:
			var distance := player_ref.global_position.distance_to(item.global_position)
			if distance <= ITEM_SCAN_RADIUS:
				item_count += 1
	
	if item_count > 0:
		announcement += "%d objet%s à portée. " % [item_count, "s" if item_count > 1 else ""]
	
	# État du joueur
	if player_ref.has_method("get_health_percentage"):
		var health_pct: float = player_ref.get_health_percentage() * 100
		announcement += "Santé à %.0f pourcent." % health_pct
	
	speak(announcement)


func announce_action_result(action: String, success: bool, details: String = "") -> void:
	"""Annonce le résultat d'une action."""
	var message := action
	if not success:
		message += " a échoué"
	if details != "":
		message += ". " + details
	
	speak(message)


func announce_damage_taken(amount: float, source_direction: Vector3) -> void:
	"""Annonce les dégâts reçus avec direction."""
	var direction_name := _get_direction_name(source_direction)
	speak("Dégâts reçus depuis %s. %.0f points." % [direction_name, amount])


func announce_enemy_killed() -> void:
	"""Annonce qu'un ennemi a été tué."""
	speak("Ennemi éliminé.")


# ==============================================================================
# UTILITAIRES DE DIRECTION
# ==============================================================================

func _get_direction_name(direction: Vector3) -> String:
	"""Convertit un vecteur direction en nom lisible."""
	if not player_ref:
		return "inconnu"
	
	# Obtenir la direction avant du joueur
	var player_forward := -player_ref.global_transform.basis.z
	var player_right := player_ref.global_transform.basis.x
	
	# Calculer les angles
	var forward_dot := player_forward.dot(direction)
	var right_dot := player_right.dot(direction)
	
	# Déterminer la direction
	var is_front := forward_dot > 0.3
	var is_back := forward_dot < -0.3
	var is_left := right_dot < -0.3
	var is_right := right_dot > 0.3
	
	if is_front and is_left:
		return DIRECTION_NAMES["front_left"]
	elif is_front and is_right:
		return DIRECTION_NAMES["front_right"]
	elif is_back and is_left:
		return DIRECTION_NAMES["back_left"]
	elif is_back and is_right:
		return DIRECTION_NAMES["back_right"]
	elif is_front:
		return DIRECTION_NAMES["front"]
	elif is_back:
		return DIRECTION_NAMES["back"]
	elif is_left:
		return DIRECTION_NAMES["left"]
	elif is_right:
		return DIRECTION_NAMES["right"]
	else:
		return DIRECTION_NAMES["front"]


# ==============================================================================
# RÉFÉRENCES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as Node3D


func set_audio_cue_system(system: Node) -> void:
	"""Définit le système d'indices audio."""
	audio_cue_system = system


func set_touch_zone_controller(controller: Node) -> void:
	"""Définit le contrôleur de zones tactiles."""
	touch_zone_controller = controller


# ==============================================================================
# VOICED GPS - Navigation vocale
# ==============================================================================

func announce_objective() -> void:
	"""
	Annonce la direction et distance vers l'objectif actuel.
	Utilise MissionManager pour trouver l'objectif.
	"""
	var mission_mgr = get_node_or_null("/root/MissionManager")
	if not mission_mgr:
		speak("Aucun système de mission disponible.")
		return
	
	if not mission_mgr.has_method("get_current_mission") or not mission_mgr.get_current_mission():
		speak("Aucune mission en cours.")
		return
	
	var mission = mission_mgr.get_current_mission()
	var target_pos: Vector3 = mission.get("target_position", Vector3.ZERO)
	
	if target_pos == Vector3.ZERO:
		# Essayer de trouver un marqueur d'objectif
		var markers := get_tree().get_nodes_in_group("objective_marker")
		if markers.size() > 0 and markers[0] is Node3D:
			target_pos = markers[0].global_position
	
	if target_pos == Vector3.ZERO:
		speak("Position de l'objectif inconnue.")
		return
	
	_announce_navigation_to(target_pos, mission.get("title", "Objectif"))


func announce_waypoint(waypoint_name: String, waypoint_pos: Vector3) -> void:
	"""
	Annonce la direction vers un waypoint spécifique.
	@param waypoint_name: Nom du waypoint (ex: "Point de rendez-vous")
	@param waypoint_pos: Position du waypoint
	"""
	_announce_navigation_to(waypoint_pos, waypoint_name)


func _announce_navigation_to(target_pos: Vector3, target_name: String) -> void:
	"""Annonce la navigation vers une position."""
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		if not player_ref:
			speak("Position du joueur inconnue.")
			return
	
	var player_pos := player_ref.global_position
	var distance := player_pos.distance_to(target_pos)
	var direction := (target_pos - player_pos).normalized()
	
	# Obtenir la direction en texte
	var dir_name := _get_direction_name(direction)
	
	# Construire l'annonce
	var announcement := "%s: %s, " % [target_name, dir_name]
	
	if distance < 5:
		announcement += "à quelques pas."
	elif distance < 20:
		announcement += "%.0f mètres." % distance
	elif distance < 100:
		announcement += "environ %.0f mètres." % (round(distance / 10) * 10)
	else:
		announcement += "environ %.0f mètres." % (round(distance / 50) * 50)
	
	speak(announcement)
	navigation_hint.emit(dir_name, distance)


func get_objective_direction() -> Dictionary:
	"""
	Retourne la direction et distance vers l'objectif actuel.
	@return: {"direction": String, "distance": float, "angle": float} ou dict vide
	"""
	var mission_mgr = get_node_or_null("/root/MissionManager")
	if not mission_mgr or not mission_mgr.has_method("get_current_mission"):
		return {}
	
	var mission = mission_mgr.get_current_mission()
	if not mission:
		return {}
	
	var target_pos: Vector3 = mission.get("target_position", Vector3.ZERO)
	if target_pos == Vector3.ZERO:
		return {}
	
	if not player_ref:
		_find_player()
		if not player_ref:
			return {}
	
	var player_pos := player_ref.global_position
	var distance := player_pos.distance_to(target_pos)
	var direction := (target_pos - player_pos).normalized()
	
	# Calculer l'angle
	var player_forward := -player_ref.global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()
	direction.y = 0
	direction = direction.normalized()
	
	var angle := rad_to_deg(acos(clamp(player_forward.dot(direction), -1.0, 1.0)))
	var cross := player_forward.cross(direction)
	if cross.y < 0:
		angle = -angle
	
	return {
		"direction": _get_direction_name(direction),
		"distance": distance,
		"angle": angle,
		"target_name": mission.get("title", "Objectif")
	}


func start_navigation_hints(interval: float = 10.0) -> void:
	"""
	Démarre les indications de navigation périodiques.
	@param interval: Intervalle entre les annonces (secondes)
	"""
	# Créer un timer si nécessaire
	var timer := get_node_or_null("NavigationHintTimer") as Timer
	if not timer:
		timer = Timer.new()
		timer.name = "NavigationHintTimer"
		timer.one_shot = false
		add_child(timer)
		timer.timeout.connect(_on_navigation_hint_timer)
	
	timer.wait_time = interval
	timer.start()
	speak("Indications de navigation activées.")


func stop_navigation_hints() -> void:
	"""Arrête les indications de navigation périodiques."""
	var timer := get_node_or_null("NavigationHintTimer") as Timer
	if timer:
		timer.stop()
		speak("Indications de navigation désactivées.")


func _on_navigation_hint_timer() -> void:
	"""Callback du timer de navigation."""
	if not is_active:
		return
	
	var objective_info := get_objective_direction()
	if objective_info.is_empty():
		return
	
	# Annonce simplifiée pour les hints périodiques
	var distance: float = objective_info["distance"]
	var dir_name: String = objective_info["direction"]
	
	if distance < 10:
		speak("Objectif très proche, %s." % dir_name)
	else:
		speak("%s, %.0f mètres." % [dir_name.capitalize(), distance])


func announce_nearby_pois() -> void:
	"""Annonce les points d'intérêt proches (NPCs, portes, objets importants)."""
	if not player_ref:
		_find_player()
		if not player_ref:
			speak("Position inconnue.")
			return
	
	var pois := []
	var player_pos := player_ref.global_position
	
	# NPCs
	for npc in get_tree().get_nodes_in_group("npc"):
		if not is_instance_valid(npc) or not npc is Node3D:
			continue
		var dist := player_pos.distance_to(npc.global_position)
		if dist <= 15.0:
			pois.append({
				"name": npc.get("npc_name") if "npc_name" in npc else "Personnage",
				"distance": dist,
				"direction": _get_direction_name((npc.global_position - player_pos).normalized())
			})
	
	# Portes
	for door in get_tree().get_nodes_in_group("door"):
		if not is_instance_valid(door) or not door is Node3D:
			continue
		var dist := player_pos.distance_to(door.global_position)
		if dist <= 10.0:
			pois.append({
				"name": "Porte",
				"distance": dist,
				"direction": _get_direction_name((door.global_position - player_pos).normalized())
			})
	
	# Construire l'annonce
	if pois.is_empty():
		speak("Aucun point d'intérêt à proximité.")
		return
	
	# Trier par distance
	pois.sort_custom(func(a, b): return a["distance"] < b["distance"])
	
	var announcement := "Points d'intérêt: "
	var parts := []
	for i in range(mini(3, pois.size())):
		var poi = pois[i]
		parts.append("%s %s à %.0f mètres" % [poi["name"], poi["direction"], poi["distance"]])
	
	announcement += ", ".join(parts) + "."
	speak(announcement)
