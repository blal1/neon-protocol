# ==============================================================================
# VerticalFarm.gd - Fermes Verticales & Viande Synthétique
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Écologiquement "propre", socialement catastrophique.
# Gameplay: sabotage, défense de convois, libération de travailleurs.
# ==============================================================================

extends Node3D
class_name VerticalFarm

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal farm_entered(player: Node3D)
signal farm_exited(player: Node3D)
signal sabotage_started(sabotage_data: Dictionary)
signal sabotage_completed(success: bool)
signal convoy_spawned(convoy: Node3D)
signal workers_liberated(count: int)
signal alarm_triggered()

# ==============================================================================
# ENUMS
# ==============================================================================

enum FarmType {
	HYDROPONIC,      ## Cultures hydroponiques
	SYNTH_MEAT,      ## Production de viande synthétique
	ALGAE_FARM,      ## Ferme d'algues
	PROTEIN_FACTORY, ## Usine de protéines
	MIXED            ## Mixte
}

enum FarmOwner {
	NOVATECH,
	AGROGENESIS,
	CORPOFOODS,
	INDEPENDENT
}

enum SecurityLevel {
	LOW,       ## Peu de gardes
	MEDIUM,    ## Drones + gardes
	HIGH,      ## Tourelles + drones + gardes
	MAXIMUM    ## IA sécurité + tout
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Identité")
@export var farm_name: String = "AgroTower Alpha"
@export var farm_type: FarmType = FarmType.HYDROPONIC
@export var farm_owner: FarmOwner = FarmOwner.NOVATECH
@export var num_floors: int = 10

@export_group("Sécurité")
@export var security_level: SecurityLevel = SecurityLevel.MEDIUM
@export var guard_count: int = 5
@export var drone_count: int = 3
@export var has_turrets: bool = true
@export var guard_scene: PackedScene
@export var drone_scene: PackedScene
@export var turret_scene: PackedScene

@export_group("Travailleurs")
@export var human_workers: int = 0  ## Humains remplacés par drones
@export var drone_workers: int = 20
@export var worker_drones_scene: PackedScene
@export var can_liberate_workers: bool = true

@export_group("Convois")
@export var convoy_route: Curve3D
@export var convoy_interval: float = 180.0  ## Spawn toutes les 3 min
@export var convoy_scene: PackedScene

@export_group("Sabotage")
@export var sabotage_points: Array[Node3D] = []
@export var sabotage_time: float = 15.0
@export var alarm_delay: float = 30.0

# ==============================================================================
# VARIABLES
# ==============================================================================

var _player_inside: bool = false
var _current_player: Node3D = null
var _guards: Array[Node3D] = []
var _drones: Array[Node3D] = []
var _turrets: Array[Node3D] = []
var _worker_drones: Array[Node3D] = []
var _liberated_workers: int = 0
var _sabotage_in_progress: bool = false
var _sabotage_progress: float = 0.0
var _alarm_active: bool = false
var _convoy_timer: float = 0.0
var _active_convoys: Array[Node3D] = []

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_setup_entry_area()
	_spawn_security()
	_spawn_worker_drones()
	_setup_sabotage_points()


func _setup_entry_area() -> void:
	"""Configure la zone d'entrée."""
	var area := Area3D.new()
	area.name = "FarmArea"
	area.collision_layer = 0
	area.collision_mask = 2
	
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, num_floors * 10.0, 50)
	shape.shape = box
	shape.position.y = num_floors * 5.0
	area.add_child(shape)
	add_child(area)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _spawn_security() -> void:
	"""Génère les unités de sécurité."""
	# Gardes
	if guard_scene:
		for i in range(guard_count):
			var guard := guard_scene.instantiate() as Node3D
			guard.position = Vector3(
				randf_range(-20, 20),
				(i % num_floors) * 10.0,
				randf_range(-20, 20)
			)
			add_child(guard)
			_guards.append(guard)
	
	# Drones
	if drone_scene:
		for i in range(drone_count):
			var drone := drone_scene.instantiate() as Node3D
			drone.position = Vector3(
				randf_range(-15, 15),
				randf_range(10, num_floors * 10.0 - 10),
				randf_range(-15, 15)
			)
			add_child(drone)
			_drones.append(drone)
	
	# Tourelles
	if has_turrets and turret_scene:
		var turret_positions := [
			Vector3(20, 5, 20),
			Vector3(-20, 5, 20),
			Vector3(20, 5, -20),
			Vector3(-20, 5, -20),
		]
		for pos in turret_positions:
			var turret := turret_scene.instantiate() as Node3D
			turret.position = pos
			add_child(turret)
			_turrets.append(turret)


func _spawn_worker_drones() -> void:
	"""Génère les drones travailleurs."""
	if not worker_drones_scene:
		return
	
	for i in range(drone_workers):
		var worker := worker_drones_scene.instantiate() as Node3D
		worker.position = Vector3(
			randf_range(-18, 18),
			(i % num_floors) * 10.0 + 1,
			randf_range(-18, 18)
		)
		worker.set_meta("is_worker", true)
		add_child(worker)
		_worker_drones.append(worker)


func _setup_sabotage_points() -> void:
	"""Configure les points de sabotage."""
	if sabotage_points.is_empty():
		# Créer des points par défaut
		var default_points := [
			Vector3(0, 10, 0),
			Vector3(0, 30, 0),
			Vector3(0, 50, 0),
		]
		for pos in default_points:
			var point := Node3D.new()
			point.name = "SabotagePoint"
			point.position = pos
			add_child(point)
			sabotage_points.append(point)


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	# Gestion des convois
	_convoy_timer += delta
	if _convoy_timer >= convoy_interval:
		_convoy_timer = 0.0
		_spawn_convoy()
	
	# Progression du sabotage
	if _sabotage_in_progress:
		_update_sabotage(delta)


# ==============================================================================
# GAMEPLAY - SABOTAGE
# ==============================================================================

func start_sabotage(sabotage_point: Node3D) -> bool:
	"""Démarre un sabotage à un point donné."""
	if _sabotage_in_progress:
		return false
	
	if sabotage_point not in sabotage_points:
		return false
	
	_sabotage_in_progress = true
	_sabotage_progress = 0.0
	
	sabotage_started.emit({
		"point": sabotage_point,
		"time_required": sabotage_time,
		"difficulty": security_level
	})
	
	# Démarrer timer d'alarme
	await get_tree().create_timer(alarm_delay).timeout
	if _sabotage_in_progress:
		_trigger_alarm()
	
	return true


func _update_sabotage(delta: float) -> void:
	"""Met à jour la progression du sabotage."""
	_sabotage_progress += delta
	
	if _sabotage_progress >= sabotage_time:
		_complete_sabotage(true)


func cancel_sabotage() -> void:
	"""Annule le sabotage en cours."""
	_sabotage_in_progress = false
	_sabotage_progress = 0.0


func _complete_sabotage(success: bool) -> void:
	"""Termine le sabotage."""
	_sabotage_in_progress = false
	_sabotage_progress = 0.0
	
	sabotage_completed.emit(success)
	
	if success:
		# Désactiver une partie des systèmes
		_disable_random_systems()
		
		# Récompenses
		if _current_player and _current_player.has_method("add_experience"):
			_current_player.add_experience(200)
		
		# Impact réputation
		if ReputationManager:
			ReputationManager.add_reputation(FarmOwner.keys()[farm_owner], -30)


func _disable_random_systems() -> void:
	"""Désactive des systèmes aléatoires après sabotage."""
	# Désactiver quelques drones
	var drones_to_disable := mini(_drones.size(), 3)
	for i in range(drones_to_disable):
		if _drones[i].has_method("shutdown"):
			_drones[i].shutdown()
		else:
			_drones[i].visible = false
			_drones[i].set_process(false)
	
	# Désactiver des tourelles
	for turret in _turrets:
		if randf() < 0.5:
			if turret.has_method("disable"):
				turret.disable()


# ==============================================================================
# GAMEPLAY - CONVOIS
# ==============================================================================

func _spawn_convoy() -> void:
	"""Génère un convoi automatisé."""
	if not convoy_scene:
		return
	
	var convoy := convoy_scene.instantiate() as Node3D
	convoy.position = global_position + Vector3(50, 0, 0)
	
	# Configurer la route si disponible
	if convoy.has_method("set_route") and convoy_route:
		convoy.set_route(convoy_route)
	
	get_parent().add_child(convoy)
	_active_convoys.append(convoy)
	
	convoy_spawned.emit(convoy)


func get_active_convoys() -> Array[Node3D]:
	"""Retourne les convois actifs."""
	# Nettoyer les convois invalides
	_active_convoys = _active_convoys.filter(func(c): return is_instance_valid(c))
	return _active_convoys


func attack_convoy(convoy: Node3D) -> void:
	"""Attaque un convoi (pour missions de gangs)."""
	if convoy in _active_convoys and convoy.has_method("set_under_attack"):
		convoy.set_under_attack(true)
		_trigger_alarm()


func defend_convoy(convoy: Node3D) -> void:
	"""Défend un convoi (pour missions corpo)."""
	if convoy in _active_convoys:
		# Le joueur défend le convoi - spawner des attaquants
		_spawn_convoy_attackers(convoy)


func _spawn_convoy_attackers(convoy: Node3D) -> void:
	"""Génère des attaquants pour le convoi."""
	# Utiliser le système de spawn d'ennemis si disponible
	pass


# ==============================================================================
# GAMEPLAY - LIBÉRATION DES TRAVAILLEURS
# ==============================================================================

func can_liberate() -> bool:
	"""Vérifie si des travailleurs peuvent être libérés."""
	return can_liberate_workers and human_workers > _liberated_workers


func liberate_workers(count: int = 1) -> int:
	"""Libère des travailleurs humains."""
	if not can_liberate():
		return 0
	
	var to_liberate := mini(count, human_workers - _liberated_workers)
	_liberated_workers += to_liberate
	
	workers_liberated.emit(to_liberate)
	
	# Karma positif
	if _current_player and _current_player.has_method("add_karma"):
		_current_player.add_karma(20 * to_liberate)
	
	# Réputation négative avec proprio
	if ReputationManager:
		ReputationManager.add_reputation(FarmOwner.keys()[farm_owner], -10 * to_liberate)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("%d travailleurs libérés" % to_liberate)
	
	return to_liberate


func get_liberation_status() -> Dictionary:
	"""Retourne le statut de libération."""
	return {
		"total_workers": human_workers,
		"liberated": _liberated_workers,
		"remaining": human_workers - _liberated_workers,
		"can_liberate": can_liberate()
	}


# ==============================================================================
# GAMEPLAY - ALARME & COMBAT
# ==============================================================================

func _trigger_alarm() -> void:
	"""Déclenche l'alarme de la ferme."""
	if _alarm_active:
		return
	
	_alarm_active = true
	alarm_triggered.emit()
	
	# Alerter toutes les unités de sécurité
	for guard in _guards:
		if guard.has_method("alert"):
			guard.alert(_current_player)
	
	for drone in _drones:
		if drone.has_method("alert"):
			drone.alert(_current_player)
	
	for turret in _turrets:
		if turret.has_method("activate"):
			turret.activate()
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Alarme! Sécurité alertée!")


func reset_alarm() -> void:
	"""Réinitialise l'alarme."""
	_alarm_active = false


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_body_entered(body: Node3D) -> void:
	"""Appelé quand le joueur entre."""
	if body.is_in_group("player"):
		_player_inside = true
		_current_player = body
		farm_entered.emit(body)
		
		if TTSManager and TTSManager.has_method("speak"):
			var security_text := SecurityLevel.keys()[security_level]
			TTSManager.speak("Entrée dans %s. Sécurité: %s" % [farm_name, security_text])


func _on_body_exited(body: Node3D) -> void:
	"""Appelé quand le joueur sort."""
	if body.is_in_group("player"):
		_player_inside = false
		_current_player = null
		farm_exited.emit(body)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_farm_info() -> Dictionary:
	"""Retourne les infos de la ferme."""
	return {
		"name": farm_name,
		"type": FarmType.keys()[farm_type],
		"owner": FarmOwner.keys()[farm_owner],
		"floors": num_floors,
		"security": SecurityLevel.keys()[security_level],
		"alarm_active": _alarm_active,
		"workers_to_liberate": human_workers - _liberated_workers
	}


func get_sabotage_progress() -> float:
	"""Retourne la progression du sabotage (0-1)."""
	if not _sabotage_in_progress:
		return 0.0
	return _sabotage_progress / sabotage_time


func is_player_inside() -> bool:
	"""Vérifie si le joueur est dans la ferme."""
	return _player_inside
