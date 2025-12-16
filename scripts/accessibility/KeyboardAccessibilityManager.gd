# ==============================================================================
# KeyboardAccessibilityManager.gd - Accessibilité clavier complète
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Permet aux joueurs aveugles de jouer entièrement au clavier sur PC.
# Gère le ciblage, les annonces TTS, et la navigation sans souris.
# ==============================================================================

extends Node
class_name KeyboardAccessibilityManager

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal target_changed(target: Node3D)
signal environment_scanned(results: Array)
signal action_announced(action: String)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SCAN_RADIUS: float = 15.0
const TARGET_SWITCH_COOLDOWN: float = 0.2

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Activation")
@export var enabled: bool = true
@export var auto_announce_actions: bool = true

@export_group("Targeting")
@export var auto_target_nearest: bool = true
@export var target_lock_on: bool = true
@export var max_target_distance: float = 20.0

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
var player: Node3D = null
var current_target: Node3D = null
var _nearby_targets: Array[Node3D] = []
var _nearby_interactables: Array[Node3D] = []
var _target_index: int = 0
var _last_target_switch: float = 0.0
var _last_tts_message: String = ""

# Référence TTS
var _tts: Node = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du gestionnaire d'accessibilité clavier."""
	_tts = get_node_or_null("/root/TTSManager")
	
	# Trouver le joueur
	await get_tree().process_frame
	_find_player()
	
	print("KeyboardAccessibilityManager: Initialisé")


func _process(delta: float) -> void:
	"""Mise à jour continue."""
	if not enabled or not player:
		return
	
	# Mettre à jour les cibles proches
	_update_nearby_targets()
	
	# Auto-target si activé
	if auto_target_nearest and current_target == null and _nearby_targets.size() > 0:
		_set_target(_nearby_targets[0])


func _input(event: InputEvent) -> void:
	"""Gestion des inputs clavier pour l'accessibilité."""
	if not enabled:
		return
	
	# Ciblage suivant (Tab ou T)
	if event.is_action_pressed("target_next"):
		_cycle_target(1)
		get_viewport().set_input_as_handled()
	
	# Ciblage précédent (G)
	if event.is_action_pressed("target_previous"):
		_cycle_target(-1)
		get_viewport().set_input_as_handled()
	
	# Scanner l'environnement (F)
	if event.is_action_pressed("scan_environment"):
		_scan_environment()
		get_viewport().set_input_as_handled()
	
	# Aide audio (F1)
	if event.is_action_pressed("help_audio"):
		_announce_help()
		get_viewport().set_input_as_handled()
	
	# Répéter dernier message (V)
	if event.is_action_pressed("repeat_last_message"):
		_repeat_last_message()
		get_viewport().set_input_as_handled()
	
	# Annonces d'actions
	if auto_announce_actions:
		_handle_action_announcements(event)


# ==============================================================================
# RECHERCHE JOUEUR
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


# ==============================================================================
# CIBLAGE
# ==============================================================================

func _update_nearby_targets() -> void:
	"""Met à jour la liste des cibles proches."""
	if not player:
		return
	
	_nearby_targets.clear()
	_nearby_interactables.clear()
	
	# Trouver les ennemis
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy is Node3D:
			var dist := player.global_position.distance_to(enemy.global_position)
			if dist <= max_target_distance:
				_nearby_targets.append(enemy)
	
	# Trouver les interactables
	var interactables := get_tree().get_nodes_in_group("interactable")
	for obj in interactables:
		if obj is Node3D:
			var dist := player.global_position.distance_to(obj.global_position)
			if dist <= max_target_distance:
				_nearby_interactables.append(obj)
	
	# Trier par distance
	_nearby_targets.sort_custom(_sort_by_distance)
	_nearby_interactables.sort_custom(_sort_by_distance)
	
	# Vérifier si la cible actuelle est toujours valide
	if current_target and not is_instance_valid(current_target):
		current_target = null
	elif current_target and player.global_position.distance_to(current_target.global_position) > max_target_distance:
		current_target = null


func _sort_by_distance(a: Node3D, b: Node3D) -> bool:
	"""Trie par distance au joueur."""
	if not player:
		return false
	var dist_a := player.global_position.distance_to(a.global_position)
	var dist_b := player.global_position.distance_to(b.global_position)
	return dist_a < dist_b


func _cycle_target(direction: int) -> void:
	"""Passe à la cible suivante/précédente."""
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_target_switch < TARGET_SWITCH_COOLDOWN:
		return
	_last_target_switch = current_time
	
	# Combiner ennemis et interactables
	var all_targets: Array[Node3D] = []
	all_targets.append_array(_nearby_targets)
	all_targets.append_array(_nearby_interactables)
	
	if all_targets.is_empty():
		_speak("Aucune cible à proximité")
		return
	
	# Trouver l'index actuel
	if current_target:
		_target_index = all_targets.find(current_target)
	
	# Changer d'index
	_target_index += direction
	if _target_index >= all_targets.size():
		_target_index = 0
	elif _target_index < 0:
		_target_index = all_targets.size() - 1
	
	# Définir la nouvelle cible
	_set_target(all_targets[_target_index])


func _set_target(new_target: Node3D) -> void:
	"""Définit une nouvelle cible."""
	current_target = new_target
	target_changed.emit(current_target)
	
	# Annoncer la cible
	if current_target:
		var target_name := _get_target_name(current_target)
		var distance := player.global_position.distance_to(current_target.global_position)
		var direction := _get_direction_to(current_target)
		
		var message := "%s, %.1f mètres, %s" % [target_name, distance, direction]
		_speak(message)
		
		# Jouer un son de ciblage
		_play_target_sound(current_target)


func _get_target_name(target: Node3D) -> String:
	"""Retourne le nom lisible d'une cible."""
	if target.has_meta("display_name"):
		return target.get_meta("display_name")
	
	# Déterminer le type
	if target.is_in_group("enemy"):
		if target.has_method("get_enemy_type"):
			return target.get_enemy_type()
		return "Ennemi"
	elif target.is_in_group("interactable"):
		if target.has_method("get_interaction_name"):
			return target.get_interaction_name()
		return "Objet interactif"
	elif target.is_in_group("pickup"):
		return "Ramassable"
	elif target.is_in_group("npc"):
		return "PNJ"
	
	return target.name


func _get_direction_to(target: Node3D) -> String:
	"""Retourne la direction vers une cible."""
	if not player:
		return ""
	
	var to_target := target.global_position - player.global_position
	to_target.y = 0
	to_target = to_target.normalized()
	
	# Direction du joueur (face)
	var player_forward := -player.global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()
	
	var player_right := player.global_transform.basis.x
	player_right.y = 0
	player_right = player_right.normalized()
	
	var dot_forward := to_target.dot(player_forward)
	var dot_right := to_target.dot(player_right)
	
	# Déterminer la direction
	if abs(dot_forward) > abs(dot_right):
		if dot_forward > 0.5:
			return "devant"
		elif dot_forward < -0.5:
			return "derrière"
	
	if dot_right > 0.5:
		return "à droite"
	elif dot_right < -0.5:
		return "à gauche"
	
	# Diagonales
	if dot_forward > 0 and dot_right > 0:
		return "devant à droite"
	elif dot_forward > 0 and dot_right < 0:
		return "devant à gauche"
	elif dot_forward < 0 and dot_right > 0:
		return "derrière à droite"
	else:
		return "derrière à gauche"


func _play_target_sound(target: Node3D) -> void:
	"""Joue un son de ciblage 3D."""
	# Utiliser le système audio si disponible
	var audio_mgr = get_node_or_null("/root/AmbientAudioManager")
	if audio_mgr and audio_mgr.has_method("play_positional_sound"):
		var sound_type := "target_enemy" if target.is_in_group("enemy") else "target_item"
		audio_mgr.play_positional_sound(sound_type, target.global_position)


# ==============================================================================
# SCAN ENVIRONNEMENT
# ==============================================================================

func _scan_environment() -> void:
	"""Scanne et annonce l'environnement."""
	if not player:
		return
	
	var results: Array = []
	
	# Compter les ennemis
	var enemy_count := _nearby_targets.size()
	if enemy_count > 0:
		results.append("%d ennemi%s" % [enemy_count, "s" if enemy_count > 1 else ""])
	
	# Compter les interactables
	var interact_count := _nearby_interactables.size()
	if interact_count > 0:
		results.append("%d objet%s interactif%s" % [
			interact_count, 
			"s" if interact_count > 1 else "",
			"s" if interact_count > 1 else ""
		])
	
	# Trouver les pickups
	var pickups := get_tree().get_nodes_in_group("pickup")
	var pickup_count := 0
	for p in pickups:
		if p is Node3D and player.global_position.distance_to(p.global_position) <= SCAN_RADIUS:
			pickup_count += 1
	if pickup_count > 0:
		results.append("%d ramassable%s" % [pickup_count, "s" if pickup_count > 1 else ""])
	
	# Détecter les murs proches
	var wall_info := _detect_nearby_walls()
	if not wall_info.is_empty():
		results.append(wall_info)
	
	# Annoncer les résultats
	if results.is_empty():
		_speak("Zone dégagée, rien à signaler")
	else:
		_speak("Scan: " + ", ".join(results))
	
	environment_scanned.emit(results)


func _detect_nearby_walls() -> String:
	"""Détecte les murs proches avec raycasts."""
	if not player:
		return ""
	
	var directions := {
		Vector3.FORWARD: "devant",
		Vector3.BACK: "derrière",
		Vector3.LEFT: "à gauche",
		Vector3.RIGHT: "à droite"
	}
	
	var space_state := player.get_world_3d().direct_space_state
	var walls_near: Array = []
	
	for dir in directions.keys():
		# Transformer la direction en world space
		var world_dir := player.global_transform.basis * dir
		world_dir.y = 0
		world_dir = world_dir.normalized()
		
		var from := player.global_position + Vector3(0, 1, 0)
		var to := from + world_dir * 3.0
		
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 1  # Layer World
		query.exclude = [player]
		
		var result := space_state.intersect_ray(query)
		if result:
			walls_near.append(directions[dir])
	
	if walls_near.size() > 0:
		return "Mur " + " et ".join(walls_near)
	return ""


# ==============================================================================
# AIDE ET ANNONCES
# ==============================================================================

func _announce_help() -> void:
	"""Annonce l'aide des contrôles."""
	var help_text := """
	Contrôles clavier accessibles:
	W A S D ou flèches pour se déplacer.
	J ou Espace pour attaquer.
	K pour attaque lourde.
	L ou Shift pour esquiver.
	E ou Entrée pour interagir.
	Tab ou T pour cibler l'ennemi suivant.
	G pour cibler l'ennemi précédent.
	F pour scanner l'environnement.
	Q pour ping de navigation audio.
	V pour répéter le dernier message.
	I pour inventaire.
	M pour carte.
	Échap pour pause.
	"""
	_speak(help_text)


func _repeat_last_message() -> void:
	"""Répète le dernier message TTS."""
	if not _last_tts_message.is_empty():
		_speak(_last_tts_message, true)
	else:
		_speak("Aucun message à répéter")


func _handle_action_announcements(event: InputEvent) -> void:
	"""Gère les annonces d'actions."""
	if event.is_action_pressed("attack"):
		action_announced.emit("attack")
		# L'annonce sera faite par le combat manager
	
	if event.is_action_pressed("dash"):
		action_announced.emit("dash")
	
	if event.is_action_pressed("interact"):
		# Vérifier s'il y a quelque chose à interagir
		if _nearby_interactables.size() > 0:
			var nearest := _nearby_interactables[0]
			var name := _get_target_name(nearest)
			_speak("Interaction: " + name)
		else:
			_speak("Rien à portée d'interaction")
		action_announced.emit("interact")
	
	if event.is_action_pressed("use_item"):
		_speak("Utilisation d'objet")
		action_announced.emit("use_item")
	
	if event.is_action_pressed("crouch"):
		_speak("Accroupi" if event.pressed else "Debout")
		action_announced.emit("crouch")


# ==============================================================================
# TTS
# ==============================================================================

func _speak(text: String, is_repeat: bool = false) -> void:
	"""Parle via TTS."""
	if not is_repeat:
		_last_tts_message = text
	
	if _tts and _tts.has_method("speak"):
		_tts.speak(text)
	elif _tts and _tts.has_method("speak_immediate"):
		_tts.speak_immediate(text)
	else:
		# Fallback: Godot TTS
		DisplayServer.tts_speak(text, "")


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_current_target() -> Node3D:
	"""Retourne la cible actuelle."""
	return current_target


func clear_target() -> void:
	"""Efface la cible actuelle."""
	current_target = null
	target_changed.emit(null)
	_speak("Cible effacée")


func announce_player_status() -> void:
	"""Annonce le statut du joueur."""
	if not player:
		return
	
	var status := "Statut: "
	
	# Santé
	if player.has_method("get_health_percent"):
		var hp := player.get_health_percent() * 100
		status += "%.0f pourcent de vie. " % hp
	
	# Position
	var pos := player.global_position
	status += "Position: %.0f, %.0f, %.0f." % [pos.x, pos.y, pos.z]
	
	_speak(status)


func announce_combat_feedback(damage: float, source_name: String) -> void:
	"""Annonce un retour de combat."""
	_speak("%.0f dégâts de %s" % [damage, source_name])
