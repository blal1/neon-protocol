# ==============================================================================
# OppressiveAdvertisingSystem.gd - Publicité Oppressive
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Kiosques payant les pauvres pour regarder des pubs.
# Foules hypnotisées en AR. Combats ignorés par la foule.
# ==============================================================================

extends Node3D
class_name OppressiveAdvertisingSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal ad_started(kiosk: Node3D, ad_data: Dictionary)
signal ad_completed(kiosk: Node3D, credits_earned: int)
signal citizen_hypnotized(citizen: Node3D)
signal citizen_snapped_out(citizen: Node3D)
signal crowd_ignoring_combat(combat_location: Vector3)
signal propaganda_level_changed(new_level: float)

# ==============================================================================
# ENUMS
# ==============================================================================

enum AdType {
	PRODUCT,        ## Publicité produit classique
	CORPORATE,      ## Propagande corporatiste
	POLITICAL,      ## Message politique
	SUBLIMINAL,     ## Message subliminal
	INTERACTIVE     ## Pub interactive (mini-jeu)
}

enum KioskType {
	STANDARD,       ## Kiosque standard
	PREMIUM,        ## Kiosque premium (plus de crédits)
	MANDATORY,      ## Kiosque obligatoire (zones corpo)
	MOBILE          ## Drone publicitaire
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Kiosques")
@export var kiosk_scene: PackedScene
@export var kiosk_count: int = 10
@export var spawn_radius: float = 100.0

@export_group("Crédits")
@export var credits_per_ad: int = 5
@export var premium_multiplier: float = 2.0
@export var watch_duration: float = 15.0

@export_group("Hypnose")
@export var hypnosis_range: float = 10.0
@export var hypnosis_strength: float = 0.8  ## Chance d'hypnotiser un citoyen
@export var snap_out_chance: float = 0.1   ## Chance de se réveiller

@export_group("Audio")
@export var ad_jingles: Array[AudioStream] = []
@export var subliminal_sounds: Array[AudioStream] = []

# ==============================================================================
# VARIABLES
# ==============================================================================

var _kiosks: Array[Node3D] = []
var _hypnotized_citizens: Array[Node3D] = []
var _player_watching_ad: bool = false
var _current_ad_kiosk: Node3D = null
var _ad_watch_timer: float = 0.0
var _propaganda_level: float = 50.0  ## 0-100, niveau de propagande global

# Publicités actuelles
var _current_ads: Array[Dictionary] = []

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_generate_ads()
	_spawn_kiosks()


func _generate_ads() -> void:
	"""Génère les publicités du jour."""
	_current_ads = [
		{
			"id": "synthfood_deluxe",
			"type": AdType.PRODUCT,
			"brand": "SynthFood™",
			"slogan": "Le goût de demain, aujourd'hui!",
			"duration": 10.0,
			"credits": 3,
			"propaganda_value": 5
		},
		{
			"id": "novatech_future",
			"type": AdType.CORPORATE,
			"brand": "NovaTech",
			"slogan": "Construisons ensemble un avenir meilleur.",
			"duration": 15.0,
			"credits": 8,
			"propaganda_value": 15
		},
		{
			"id": "safe_city",
			"type": AdType.POLITICAL,
			"brand": "Sécurité Urbaine",
			"slogan": "Votre sécurité est notre priorité. Signalez les suspects.",
			"duration": 12.0,
			"credits": 5,
			"propaganda_value": 20
		},
		{
			"id": "cyber_upgrade",
			"type": AdType.PRODUCT,
			"brand": "CyberLife",
			"slogan": "Améliorez-vous. Soyez plus.",
			"duration": 8.0,
			"credits": 4,
			"propaganda_value": 10
		},
		{
			"id": "obey_consume",
			"type": AdType.SUBLIMINAL,
			"brand": "???",
			"slogan": "OBÉIS. CONSOMME. DORS.",
			"duration": 5.0,
			"credits": 10,
			"propaganda_value": 30,
			"hidden": true
		}
	]


func _spawn_kiosks() -> void:
	"""Génère les kiosques publicitaires."""
	if not kiosk_scene:
		return
	
	for i in range(kiosk_count):
		var kiosk := kiosk_scene.instantiate() as Node3D
		kiosk.name = "AdKiosk_%d" % i
		
		# Position aléatoire
		var angle := randf() * TAU
		var distance := randf() * spawn_radius
		kiosk.position = Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		# Type aléatoire
		var kiosk_type: int = randi() % 3  # Standard, Premium, ou Mandatory
		kiosk.set_meta("kiosk_type", kiosk_type)
		kiosk.set_meta("credits_multiplier", 2.0 if kiosk_type == KioskType.PREMIUM else 1.0)
		
		add_child(kiosk)
		_kiosks.append(kiosk)
		
		# Zone d'hypnose
		_setup_hypnosis_zone(kiosk)


func _setup_hypnosis_zone(kiosk: Node3D) -> void:
	"""Configure la zone d'hypnose autour d'un kiosque."""
	var area := Area3D.new()
	area.name = "HypnosisZone"
	area.collision_layer = 0
	area.collision_mask = 8  # NPCs layer
	
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = hypnosis_range
	shape.shape = sphere
	area.add_child(shape)
	kiosk.add_child(area)
	
	area.body_entered.connect(_on_citizen_entered_zone.bind(kiosk))
	area.body_exited.connect(_on_citizen_exited_zone.bind(kiosk))


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	# Timer de visionnage de pub
	if _player_watching_ad:
		_ad_watch_timer -= delta
		if _ad_watch_timer <= 0:
			_complete_ad_watch()
	
	# Mise à jour des citoyens hypnotisés
	_update_hypnotized_citizens(delta)


func _update_hypnotized_citizens(delta: float) -> void:
	"""Met à jour l'état des citoyens hypnotisés."""
	var to_remove: Array[Node3D] = []
	
	for citizen in _hypnotized_citizens:
		if not is_instance_valid(citizen):
			to_remove.append(citizen)
			continue
		
		# Chance de se réveiller
		if randf() < snap_out_chance * delta:
			_snap_citizen_out(citizen)
			to_remove.append(citizen)
	
	for citizen in to_remove:
		_hypnotized_citizens.erase(citizen)


# ==============================================================================
# GAMEPLAY - REGARDER DES PUBS
# ==============================================================================

func start_watching_ad(player: Node3D, kiosk: Node3D) -> Dictionary:
	"""Le joueur commence à regarder une pub."""
	if _player_watching_ad:
		return {"error": "Déjà en train de regarder"}
	
	var ad := _current_ads[randi() % _current_ads.size()]
	var kiosk_type: int = kiosk.get_meta("kiosk_type", KioskType.STANDARD)
	var multiplier: float = kiosk.get_meta("credits_multiplier", 1.0)
	
	_player_watching_ad = true
	_current_ad_kiosk = kiosk
	_ad_watch_timer = ad.duration
	
	ad_started.emit(kiosk, ad)
	
	# Augmenter la propagande
	_propaganda_level = minf(100.0, _propaganda_level + ad.propaganda_value * 0.1)
	propaganda_level_changed.emit(_propaganda_level)
	
	return {
		"ad": ad,
		"duration": ad.duration,
		"credits": int(ad.credits * multiplier),
		"type": AdType.keys()[ad.type]
	}


func cancel_ad_watch() -> void:
	"""Annule le visionnage de pub."""
	_player_watching_ad = false
	_current_ad_kiosk = null
	_ad_watch_timer = 0.0


func _complete_ad_watch() -> void:
	"""Termine le visionnage de pub et donne les crédits."""
	if not _player_watching_ad:
		return
	
	var kiosk := _current_ad_kiosk
	var multiplier: float = kiosk.get_meta("credits_multiplier", 1.0) if kiosk else 1.0
	var credits := int(credits_per_ad * multiplier)
	
	# Donner les crédits au joueur
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0]
		if player.has_method("add_credits"):
			player.add_credits(credits)
	
	ad_completed.emit(kiosk, credits)
	
	# Reset
	_player_watching_ad = false
	_current_ad_kiosk = null
	_ad_watch_timer = 0.0
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Publicité terminée. %d crédits gagnés." % credits)


func is_watching_ad() -> bool:
	"""Vérifie si le joueur regarde une pub."""
	return _player_watching_ad


func get_ad_progress() -> float:
	"""Retourne la progression du visionnage (0-1)."""
	if not _player_watching_ad:
		return 0.0
	# Note: besoin de la durée totale pour calculer, simplifié ici
	return 1.0 - (_ad_watch_timer / watch_duration)


# ==============================================================================
# GAMEPLAY - HYPNOSE DES CITOYENS
# ==============================================================================

func _on_citizen_entered_zone(body: Node3D, kiosk: Node3D) -> void:
	"""Appelé quand un citoyen entre dans la zone d'un kiosque."""
	if not body.is_in_group("citizen"):
		return
	
	if body in _hypnotized_citizens:
		return
	
	# Chance d'hypnotiser
	if randf() < hypnosis_strength:
		_hypnotize_citizen(body, kiosk)


func _on_citizen_exited_zone(body: Node3D, kiosk: Node3D) -> void:
	"""Appelé quand un citoyen sort de la zone."""
	# Les citoyens hypnotisés restent hypnotisés même hors zone
	pass


func _hypnotize_citizen(citizen: Node3D, kiosk: Node3D) -> void:
	"""Hypnotise un citoyen."""
	_hypnotized_citizens.append(citizen)
	
	# Arrêter le mouvement
	if citizen.has_method("stop_moving"):
		citizen.stop_moving()
	
	# Faire regarder le kiosque
	if citizen.has_method("look_at_target"):
		citizen.look_at_target(kiosk.global_position)
	
	# Marquer comme hypnotisé
	citizen.set_meta("hypnotized", true)
	citizen.set_meta("hypnosis_source", kiosk)
	
	citizen_hypnotized.emit(citizen)


func _snap_citizen_out(citizen: Node3D) -> void:
	"""Réveille un citoyen de l'hypnose."""
	citizen.set_meta("hypnotized", false)
	citizen.set_meta("hypnosis_source", null)
	
	if citizen.has_method("resume_normal_behavior"):
		citizen.resume_normal_behavior()
	
	citizen_snapped_out.emit(citizen)


func is_citizen_hypnotized(citizen: Node3D) -> bool:
	"""Vérifie si un citoyen est hypnotisé."""
	return citizen in _hypnotized_citizens


func get_hypnotized_count() -> int:
	"""Retourne le nombre de citoyens hypnotisés."""
	return _hypnotized_citizens.size()


# ==============================================================================
# GAMEPLAY - COMBATS IGNORÉS
# ==============================================================================

func notify_combat_started(location: Vector3) -> void:
	"""Notifie le système qu'un combat a commencé."""
	var nearby_hypnotized := _get_hypnotized_near_location(location, 20.0)
	
	if nearby_hypnotized.size() > 0:
		crowd_ignoring_combat.emit(location)
		
		# Les citoyens hypnotisés ignorent complètement le combat
		for citizen in nearby_hypnotized:
			if citizen.has_method("ignore_event"):
				citizen.ignore_event("combat")


func _get_hypnotized_near_location(location: Vector3, radius: float) -> Array[Node3D]:
	"""Retourne les citoyens hypnotisés près d'une position."""
	var nearby: Array[Node3D] = []
	for citizen in _hypnotized_citizens:
		if is_instance_valid(citizen):
			if citizen.global_position.distance_to(location) <= radius:
				nearby.append(citizen)
	return nearby


func will_citizens_react_to_combat(location: Vector3) -> bool:
	"""Vérifie si les citoyens réagiront à un combat."""
	var all_citizens := get_tree().get_nodes_in_group("citizen")
	var nearby_count := 0
	var hypnotized_count := 0
	
	for citizen in all_citizens:
		if citizen.global_position.distance_to(location) <= 20.0:
			nearby_count += 1
			if citizen in _hypnotized_citizens:
				hypnotized_count += 1
	
	# Si plus de 70% sont hypnotisés, personne ne réagit
	if nearby_count > 0 and float(hypnotized_count) / nearby_count > 0.7:
		return false
	
	return true


# ==============================================================================
# GAMEPLAY - DRONES PUBLICITAIRES
# ==============================================================================

func spawn_ad_drone(position: Vector3, patrol_radius: float = 30.0) -> Node3D:
	"""Génère un drone publicitaire mobile."""
	var drone := Node3D.new()
	drone.name = "AdDrone"
	drone.position = position
	drone.set_meta("kiosk_type", KioskType.MOBILE)
	drone.set_meta("patrol_radius", patrol_radius)
	drone.set_meta("patrol_center", position)
	
	# Le drone se déplace et hypnotise sur son passage
	_kiosks.append(drone)
	add_child(drone)
	
	# Zone d'hypnose mobile
	_setup_hypnosis_zone(drone)
	
	return drone


# ==============================================================================
# PROPAGANDE
# ==============================================================================

func get_propaganda_level() -> float:
	"""Retourne le niveau de propagande global."""
	return _propaganda_level


func reduce_propaganda(amount: float) -> void:
	"""Réduit le niveau de propagande (actions de résistance)."""
	var old_level := _propaganda_level
	_propaganda_level = maxf(0.0, _propaganda_level - amount)
	
	if old_level != _propaganda_level:
		propaganda_level_changed.emit(_propaganda_level)


func get_propaganda_effects() -> Dictionary:
	"""Retourne les effets de la propagande sur le gameplay."""
	return {
		"citizen_trust_modifier": _propaganda_level / 100.0 * -0.3,
		"corpo_trust_modifier": _propaganda_level / 100.0 * 0.2,
		"resistance_difficulty": _propaganda_level / 100.0,
		"crowd_reaction_threshold": 0.3 + (_propaganda_level / 100.0 * 0.5)
	}


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_kiosks() -> Array[Node3D]:
	"""Retourne tous les kiosques."""
	return _kiosks


func get_nearest_kiosk(position: Vector3) -> Node3D:
	"""Retourne le kiosque le plus proche."""
	var nearest: Node3D = null
	var min_dist := INF
	
	for kiosk in _kiosks:
		var dist := position.distance_to(kiosk.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = kiosk
	
	return nearest


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"kiosks_count": _kiosks.size(),
		"hypnotized_citizens": _hypnotized_citizens.size(),
		"propaganda_level": _propaganda_level,
		"player_watching_ad": _player_watching_ad,
		"ads_available": _current_ads.size()
	}
