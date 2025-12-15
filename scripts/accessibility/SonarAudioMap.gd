# ==============================================================================
# SonarAudioMap.gd - Carte audio sonar pour joueurs non-voyants
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Système de ping audio pour localiser objets et ennemis
# Utilise audio 3D spatial pour la direction
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal ping_started
signal ping_completed
signal object_detected(object_type: String, distance: float, direction: Vector3)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MAX_PING_RANGE := 30.0  # Portée maximale du ping
const PING_COOLDOWN := 1.0  # Délai entre les pings
const MAX_OBJECTS_PER_PING := 8  # Nombre max d'objets annoncés

# Types d'objets détectables
enum ObjectType {
	ENEMY,
	ITEM,
	POI,  # Point d'intérêt (mission, NPC)
	DOOR,
	COVER
}

# Fréquences de base pour chaque type (Hz) - pour distinction audio
const AUDIO_FREQUENCIES := {
	ObjectType.ENEMY: 220.0,   # Grave, menaçant
	ObjectType.ITEM: 440.0,    # Moyen
	ObjectType.POI: 880.0,     # Aigu, important
	ObjectType.DOOR: 330.0,    # Entre grave et moyen
	ObjectType.COVER: 165.0    # Très grave
}

# ==============================================================================
# VARIABLES
# ==============================================================================
var player_ref: Node3D = null
var is_on_cooldown: bool = false
var _audio_players: Array[AudioStreamPlayer3D] = []

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système sonar."""
	await get_tree().process_frame
	_find_player()


func _input(event: InputEvent) -> void:
	"""Déclenche le ping sur action."""
	if event.is_action_pressed("sonar_ping"):
		trigger_ping()


# ==============================================================================
# PING SONAR
# ==============================================================================

func trigger_ping() -> void:
	"""Déclenche un scan sonar de l'environnement."""
	if is_on_cooldown:
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Sonar en recharge")
		return
	
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		if not player_ref:
			return
	
	is_on_cooldown = true
	ping_started.emit()
	
	# Collecter les objets
	var detected_objects := _scan_environment()
	
	# Trier par distance
	detected_objects.sort_custom(_sort_by_distance)
	
	# Jouer les sons et annoncer
	_play_ping_audio(detected_objects)
	_announce_results(detected_objects)
	
	ping_completed.emit()
	
	# Cooldown
	await get_tree().create_timer(PING_COOLDOWN).timeout
	is_on_cooldown = false


func _scan_environment() -> Array:
	"""Scanne l'environnement pour trouver les objets."""
	var results := []
	var player_pos := player_ref.global_position
	
	# Scanner les ennemis
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var dist := player_pos.distance_to(enemy.global_position)
		if dist <= MAX_PING_RANGE:
			results.append({
				"node": enemy,
				"type": ObjectType.ENEMY,
				"distance": dist,
				"position": enemy.global_position
			})
	
	# Scanner les objets interactifs
	for item in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(item) or not item is Node3D:
			continue
		var dist := player_pos.distance_to(item.global_position)
		if dist <= MAX_PING_RANGE:
			var obj_type := _determine_item_type(item)
			results.append({
				"node": item,
				"type": obj_type,
				"distance": dist,
				"position": item.global_position
			})
	
	# Scanner les POI (missions, NPCs)
	for poi in get_tree().get_nodes_in_group("poi"):
		if not is_instance_valid(poi) or not poi is Node3D:
			continue
		var dist := player_pos.distance_to(poi.global_position)
		if dist <= MAX_PING_RANGE:
			results.append({
				"node": poi,
				"type": ObjectType.POI,
				"distance": dist,
				"position": poi.global_position
			})
	
	# Scanner les couvertures
	for cover in get_tree().get_nodes_in_group("cover"):
		if not is_instance_valid(cover) or not cover is Node3D:
			continue
		var dist := player_pos.distance_to(cover.global_position)
		if dist <= MAX_PING_RANGE:
			results.append({
				"node": cover,
				"type": ObjectType.COVER,
				"distance": dist,
				"position": cover.global_position
			})
	
	return results


func _determine_item_type(item: Node) -> ObjectType:
	"""Détermine le type d'un objet interactif."""
	if item.is_in_group("door"):
		return ObjectType.DOOR
	elif item.is_in_group("item") or item.is_in_group("pickup"):
		return ObjectType.ITEM
	elif item.is_in_group("npc"):
		return ObjectType.POI
	return ObjectType.ITEM


func _sort_by_distance(a: Dictionary, b: Dictionary) -> bool:
	"""Tri par distance croissante."""
	return a["distance"] < b["distance"]


# ==============================================================================
# AUDIO
# ==============================================================================

func _play_ping_audio(objects: Array) -> void:
	"""Joue les sons de ping pour chaque objet détecté."""
	# Nettoyer les anciens players
	for player in _audio_players:
		if is_instance_valid(player):
			player.queue_free()
	_audio_players.clear()
	
	# Son de départ du ping (center)
	_play_ping_center_sound()
	
	# Sons pour chaque objet (limité)
	var count := 0
	for obj in objects:
		if count >= MAX_OBJECTS_PER_PING:
			break
		
		# Délai progressif pour distinguer les sons
		await get_tree().create_timer(0.15 * count).timeout
		_play_object_sound(obj)
		count += 1


func _play_ping_center_sound() -> void:
	"""Joue le son central du ping."""
	var audio := AudioStreamPlayer.new()
	audio.bus = "SFX"
	
	# Générer un bip court
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.1
	audio.stream = generator
	audio.volume_db = -10.0
	
	add_child(audio)
	audio.play()
	
	await get_tree().create_timer(0.2).timeout
	audio.queue_free()


func _play_object_sound(obj: Dictionary) -> void:
	"""Joue un son 3D pour un objet détecté."""
	var audio := AudioStreamPlayer3D.new()
	audio.bus = "SFX"
	audio.max_distance = MAX_PING_RANGE
	audio.unit_size = 5.0
	
	# Pitch basé sur le type d'objet
	var base_pitch := 1.0
	match obj["type"]:
		ObjectType.ENEMY:
			base_pitch = 0.6  # Grave
		ObjectType.ITEM:
			base_pitch = 1.0
		ObjectType.POI:
			base_pitch = 1.4  # Aigu
		ObjectType.DOOR:
			base_pitch = 0.8
		ObjectType.COVER:
			base_pitch = 0.5
	
	# Volume basé sur la distance
	var dist_ratio := 1.0 - (obj["distance"] / MAX_PING_RANGE)
	audio.volume_db = -5.0 + (dist_ratio * 10.0)
	audio.pitch_scale = base_pitch
	
	# Générer un bip
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.15
	audio.stream = generator
	
	add_child(audio)
	audio.global_position = obj["position"]
	audio.play()
	
	_audio_players.append(audio)
	
	# Émettre le signal
	var direction := (obj["position"] - player_ref.global_position).normalized()
	object_detected.emit(_get_type_name(obj["type"]), obj["distance"], direction)
	
	# Supprimer après
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(audio):
		audio.queue_free()


func _get_type_name(type: ObjectType) -> String:
	"""Retourne le nom lisible d'un type d'objet."""
	match type:
		ObjectType.ENEMY:
			return "ennemi"
		ObjectType.ITEM:
			return "objet"
		ObjectType.POI:
			return "point d'intérêt"
		ObjectType.DOOR:
			return "porte"
		ObjectType.COVER:
			return "couverture"
	return "inconnu"


# ==============================================================================
# ANNONCES TTS
# ==============================================================================

func _announce_results(objects: Array) -> void:
	"""Annonce les résultats du scan via TTS."""
	var tts = get_node_or_null("/root/TTSManager")
	if not tts:
		return
	
	if objects.is_empty():
		tts.speak("Aucun objet détecté à proximité.")
		return
	
	# Compter par type
	var counts := {
		ObjectType.ENEMY: 0,
		ObjectType.ITEM: 0,
		ObjectType.POI: 0,
		ObjectType.DOOR: 0,
		ObjectType.COVER: 0
	}
	
	for obj in objects:
		counts[obj["type"]] += 1
	
	# Construire l'annonce
	var announcement := "Scan: "
	var parts := []
	
	if counts[ObjectType.ENEMY] > 0:
		parts.append("%d ennemi%s" % [counts[ObjectType.ENEMY], "s" if counts[ObjectType.ENEMY] > 1 else ""])
	if counts[ObjectType.POI] > 0:
		parts.append("%d point%s d'intérêt" % [counts[ObjectType.POI], "s" if counts[ObjectType.POI] > 1 else ""])
	if counts[ObjectType.ITEM] > 0:
		parts.append("%d objet%s" % [counts[ObjectType.ITEM], "s" if counts[ObjectType.ITEM] > 1 else ""])
	if counts[ObjectType.DOOR] > 0:
		parts.append("%d porte%s" % [counts[ObjectType.DOOR], "s" if counts[ObjectType.DOOR] > 1 else ""])
	
	if parts.is_empty():
		announcement += "zone dégagée."
	else:
		announcement += ", ".join(parts) + "."
	
	# Annoncer l'objet le plus proche
	if objects.size() > 0:
		var closest := objects[0]
		var dir_name := _get_direction_name(closest["position"])
		announcement += " Plus proche: %s %s à %.0f mètres." % [
			_get_type_name(closest["type"]),
			dir_name,
			closest["distance"]
		]
	
	tts.speak(announcement)


func _get_direction_name(target_pos: Vector3) -> String:
	"""Retourne la direction vers une cible en texte."""
	if not player_ref:
		return ""
	
	var direction := (target_pos - player_ref.global_position).normalized()
	var player_forward := -player_ref.global_transform.basis.z
	var player_right := player_ref.global_transform.basis.x
	
	direction.y = 0
	direction = direction.normalized()
	player_forward.y = 0
	player_forward = player_forward.normalized()
	player_right.y = 0
	player_right = player_right.normalized()
	
	var forward_dot := direction.dot(player_forward)
	var right_dot := direction.dot(player_right)
	
	if forward_dot > 0.7:
		return "devant"
	elif forward_dot < -0.7:
		return "derrière"
	elif right_dot > 0.7:
		return "à droite"
	elif right_dot < -0.7:
		return "à gauche"
	elif forward_dot > 0 and right_dot > 0:
		return "devant à droite"
	elif forward_dot > 0 and right_dot < 0:
		return "devant à gauche"
	elif forward_dot < 0 and right_dot > 0:
		return "derrière à droite"
	else:
		return "derrière à gauche"


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as Node3D
