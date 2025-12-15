# ==============================================================================
# MetroSystem.gd - Métro & Rails Aériens
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Artères de la ville. Combat en mouvement, événements dynamiques.
# Gameplay: combats, attaques de gangs, événements (pannes, attentats, contrôles).
# ==============================================================================

extends Node3D
class_name MetroSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal train_arrived(station: Node3D, train: Node3D)
signal train_departed(station: Node3D, train: Node3D)
signal player_boarded(train: Node3D)
signal player_exited(train: Node3D)
signal combat_started_on_train(train: Node3D, enemies: Array)
signal dynamic_event_triggered(event_data: Dictionary)
signal gang_attack_started(gang_id: String, train: Node3D)

# ==============================================================================
# ENUMS
# ==============================================================================

enum TransportType {
	METRO,        ## Métro souterrain
	AERIAL_RAIL,  ## Rail aérien
	MONORAIL,     ## Monorail urbain
	MAGLEV        ## Train magnétique express
}

enum EventType {
	NONE,
	GANG_ATTACK,     ## Attaque de gang
	CORPO_CHECKPOINT,## Contrôle corporatiste
	BREAKDOWN,       ## Panne technique
	TERRORIST_ATTACK,## Attentat
	POLICE_RAID      ## Descente de police
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Réseau")
@export var transport_type: TransportType = TransportType.METRO
@export var line_name: String = "Ligne Alpha"
@export var line_color: Color = Color.CYAN

@export_group("Stations")
@export var stations: Array[Node3D] = []
@export var station_names: Array[String] = []

@export_group("Trains")
@export var train_scene: PackedScene
@export var train_count: int = 3
@export var train_speed: float = 20.0
@export var stop_duration: float = 10.0

@export_group("Route")
@export var route_path: Path3D
@export var is_circular: bool = true

@export_group("Événements Dynamiques")
@export var event_probability: float = 0.15  ## Chance d'événement par trajet
@export var gang_attack_gangs: Array[String] = ["neon_dragons", "chrome_vipers"]
@export var checkpoint_corporation: String = "NovaTech"
@export var enemy_scene: PackedScene

# ==============================================================================
# VARIABLES
# ==============================================================================

var _trains: Array[Node3D] = []
var _player_on_train: Node3D = null
var _current_event: EventType = EventType.NONE
var _active_enemies: Array[Node3D] = []
var _event_in_progress: bool = false

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_spawn_trains()
	_setup_stations()


func _spawn_trains() -> void:
	"""Génère les trains sur la ligne."""
	if not train_scene or not route_path:
		return
	
	var path_length := route_path.curve.get_baked_length()
	var spacing := path_length / train_count
	
	for i in range(train_count):
		var train := train_scene.instantiate() as Node3D
		train.name = "Train_%d" % i
		
		# Créer un PathFollow3D pour chaque train
		var path_follow := PathFollow3D.new()
		path_follow.name = "TrainFollow_%d" % i
		path_follow.progress = spacing * i
		path_follow.loop = is_circular
		route_path.add_child(path_follow)
		path_follow.add_child(train)
		
		# Stocker les références
		train.set_meta("path_follow", path_follow)
		train.set_meta("is_stopped", false)
		train.set_meta("current_station", -1)
		
		_trains.append(train)
		
		# Connecter les signaux si le train en a
		if train.has_signal("player_entered"):
			train.player_entered.connect(_on_train_player_entered.bind(train))
		if train.has_signal("player_exited"):
			train.player_exited.connect(_on_train_player_exited.bind(train))


func _setup_stations() -> void:
	"""Configure les stations."""
	for i in range(stations.size()):
		var station := stations[i]
		station.set_meta("station_index", i)
		station.set_meta("station_name", station_names[i] if i < station_names.size() else "Station %d" % i)
		
		# Configurer une zone d'arrêt
		if not station.has_node("StopArea"):
			var area := Area3D.new()
			area.name = "StopArea"
			area.collision_layer = 0
			area.collision_mask = 4  # Train layer
			
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(15, 5, 5)
			shape.shape = box
			area.add_child(shape)
			station.add_child(area)
			
			area.body_entered.connect(_on_train_at_station.bind(station))


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	_update_trains(delta)


func _update_trains(delta: float) -> void:
	"""Met à jour le mouvement des trains."""
	for train in _trains:
		var path_follow: PathFollow3D = train.get_meta("path_follow")
		var is_stopped: bool = train.get_meta("is_stopped", false)
		
		if not is_stopped:
			path_follow.progress += train_speed * delta


# ==============================================================================
# GAMEPLAY - STATIONS
# ==============================================================================

func _on_train_at_station(body: Node3D, station: Node3D) -> void:
	"""Appelé quand un train arrive à une station."""
	if body not in _trains:
		return
	
	var train := body
	var station_index: int = station.get_meta("station_index", -1)
	
	# Arrêter le train
	train.set_meta("is_stopped", true)
	train.set_meta("current_station", station_index)
	
	train_arrived.emit(station, train)
	
	# TTS pour accessibilité
	if TTSManager and TTSManager.has_method("speak"):
		var station_name: String = station.get_meta("station_name", "Station")
		TTSManager.speak("Arrivée à %s" % station_name)
	
	# Redémarrer après un délai
	await get_tree().create_timer(stop_duration).timeout
	_depart_from_station(train, station)


func _depart_from_station(train: Node3D, station: Node3D) -> void:
	"""Le train quitte la station."""
	train.set_meta("is_stopped", false)
	train_departed.emit(station, train)
	
	# Vérifier si un événement doit se produire
	if _player_on_train == train and randf() < event_probability:
		_trigger_random_event(train)


# ==============================================================================
# GAMEPLAY - EMBARQUEMENT
# ==============================================================================

func board_train(player: Node3D, train: Node3D) -> bool:
	"""Le joueur monte dans un train."""
	if train not in _trains:
		return false
	
	var is_stopped: bool = train.get_meta("is_stopped", false)
	if not is_stopped:
		return false  # Ne peut monter que si arrêté
	
	_player_on_train = train
	player_boarded.emit(train)
	
	# Attacher le joueur au train
	if player.has_method("attach_to_vehicle"):
		player.attach_to_vehicle(train)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Embarquement dans le %s" % line_name)
	
	return true


func exit_train(player: Node3D) -> bool:
	"""Le joueur descend du train."""
	if not _player_on_train:
		return false
	
	var train := _player_on_train
	var is_stopped: bool = train.get_meta("is_stopped", false)
	
	if not is_stopped:
		return false  # Ne peut descendre que si arrêté
	
	_player_on_train = null
	player_exited.emit(train)
	
	# Détacher le joueur
	if player.has_method("detach_from_vehicle"):
		player.detach_from_vehicle()
	
	return true


func _on_train_player_entered(player: Node3D, train: Node3D) -> void:
	"""Callback quand le joueur entre dans un train."""
	board_train(player, train)


func _on_train_player_exited(player: Node3D, train: Node3D) -> void:
	"""Callback quand le joueur sort d'un train."""
	if _player_on_train == train:
		_player_on_train = null


# ==============================================================================
# GAMEPLAY - ÉVÉNEMENTS DYNAMIQUES
# ==============================================================================

func _trigger_random_event(train: Node3D) -> void:
	"""Déclenche un événement aléatoire."""
	if _event_in_progress:
		return
	
	var events := [
		EventType.GANG_ATTACK,
		EventType.CORPO_CHECKPOINT,
		EventType.BREAKDOWN,
		EventType.POLICE_RAID
	]
	
	# Pondération (attaques de gang plus fréquentes)
	var weights := [0.4, 0.25, 0.2, 0.15]
	var roll := randf()
	var cumulative := 0.0
	
	for i in range(events.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			_current_event = events[i]
			break
	
	_event_in_progress = true
	_execute_event(train)


func _execute_event(train: Node3D) -> void:
	"""Exécute l'événement actuel."""
	var event_data := {
		"type": EventType.keys()[_current_event],
		"train": train,
		"line": line_name
	}
	
	dynamic_event_triggered.emit(event_data)
	
	match _current_event:
		EventType.GANG_ATTACK:
			_execute_gang_attack(train)
		EventType.CORPO_CHECKPOINT:
			_execute_checkpoint(train)
		EventType.BREAKDOWN:
			_execute_breakdown(train)
		EventType.POLICE_RAID:
			_execute_police_raid(train)


func _execute_gang_attack(train: Node3D) -> void:
	"""Exécute une attaque de gang."""
	var gang := gang_attack_gangs[randi() % gang_attack_gangs.size()]
	
	gang_attack_started.emit(gang, train)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Alerte! Attaque de gang dans le train!")
	
	# Spawner des ennemis
	_spawn_enemies_on_train(train, 3, gang)


func _spawn_enemies_on_train(train: Node3D, count: int, faction: String) -> void:
	"""Génère des ennemis sur le train."""
	if not enemy_scene:
		return
	
	for i in range(count):
		var enemy := enemy_scene.instantiate() as Node3D
		enemy.set_meta("faction", faction)
		enemy.position = Vector3(randf_range(-5, 5), 1, randf_range(-3, 3))
		train.add_child(enemy)
		_active_enemies.append(enemy)
	
	combat_started_on_train.emit(train, _active_enemies)


func _execute_checkpoint(train: Node3D) -> void:
	"""Exécute un contrôle corporatiste."""
	# Arrêter le train
	train.set_meta("is_stopped", true)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Contrôle de sécurité %s. Préparez vos identifiants." % checkpoint_corporation)
	
	# Vérifier réputation du joueur
	if ReputationManager and _player_on_train == train:
		var rep: int = ReputationManager.get_reputation(checkpoint_corporation)
		if rep < -20:
			# Le joueur est recherché
			_spawn_enemies_on_train(train, 4, "security")
		else:
			# Contrôle simple - laisser passer après délai
			await get_tree().create_timer(5.0).timeout
			train.set_meta("is_stopped", false)
			_event_in_progress = false


func _execute_breakdown(train: Node3D) -> void:
	"""Exécute une panne."""
	# Arrêter le train
	train.set_meta("is_stopped", true)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Panne technique. Veuillez patienter.")
	
	# Effets visuels (lumières clignotantes)
	_flicker_train_lights(train)
	
	# Réparer après un délai aléatoire
	var repair_time := randf_range(15.0, 45.0)
	await get_tree().create_timer(repair_time).timeout
	
	train.set_meta("is_stopped", false)
	_event_in_progress = false
	
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Panne résolue. Le train repart.")


func _execute_police_raid(train: Node3D) -> void:
	"""Exécute une descente de police."""
	train.set_meta("is_stopped", true)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Descente de police! Restez calme!")
	
	# Spawner des policiers
	_spawn_enemies_on_train(train, 5, "police")


func _flicker_train_lights(train: Node3D) -> void:
	"""Fait clignoter les lumières du train."""
	var lights := train.find_children("*", "Light3D")
	for light in lights:
		var tween := create_tween()
		tween.set_loops(10)
		tween.tween_property(light, "light_energy", 0.2, 0.2)
		tween.tween_property(light, "light_energy", 1.0, 0.2)


# ==============================================================================
# GAMEPLAY - COMBAT EN MOUVEMENT
# ==============================================================================

func is_combat_active() -> bool:
	"""Vérifie si un combat est en cours."""
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))
	return _active_enemies.size() > 0


func end_combat() -> void:
	"""Termine le combat en cours."""
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	_event_in_progress = false
	_current_event = EventType.NONE


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_line_info() -> Dictionary:
	"""Retourne les infos de la ligne."""
	return {
		"name": line_name,
		"type": TransportType.keys()[transport_type],
		"stations_count": stations.size(),
		"trains_count": _trains.size(),
		"player_on_board": _player_on_train != null,
		"event_active": _event_in_progress
	}


func get_next_station(train: Node3D) -> Node3D:
	"""Retourne la prochaine station du train."""
	var current_idx: int = train.get_meta("current_station", -1)
	var next_idx := (current_idx + 1) % stations.size()
	return stations[next_idx] if next_idx < stations.size() else null


func get_all_trains() -> Array[Node3D]:
	"""Retourne tous les trains."""
	return _trains


func get_player_train() -> Node3D:
	"""Retourne le train du joueur (ou null)."""
	return _player_on_train


func get_nearest_station(position: Vector3) -> Node3D:
	"""Retourne la station la plus proche."""
	var nearest: Node3D = null
	var min_dist := INF
	
	for station in stations:
		var dist := position.distance_to(station.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = station
	
	return nearest
