# ==============================================================================
# RandomEventManager.gd - Événements aléatoires d'exploration
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Génère des événements aléatoires pendant l'exploration
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal event_triggered(event_id: String, event_data: Dictionary)
signal event_completed(event_id: String, success: bool)
signal encounter_started(encounter_type: String)
signal loot_dropped(items: Array)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum EventType {
	AMBUSH,
	MERCHANT,
	LOOT_CACHE,
	DISTRESS_SIGNAL,
	GANG_WAR,
	HACKER_OFFER,
	DRONE_DROP,
	STREET_FIGHT,
	DATA_LEAK,
	CORPO_PATROL
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var event_check_interval: float = 30.0  ## Secondes
@export var base_event_chance: float = 0.15  ## 15%
@export var max_active_events: int = 2
@export var event_cooldown: float = 60.0

# ==============================================================================
# DONNÉES D'ÉVÉNEMENTS
# ==============================================================================
var event_templates: Dictionary = {
	EventType.AMBUSH: {
		"name": "Embuscade",
		"description": "Des gangers surgissent des ombres!",
		"enemy_count": [2, 4],
		"reward_credits": [50, 150],
		"xp": 25
	},
	EventType.MERCHANT: {
		"name": "Marchand ambulant",
		"description": "Un vendeur propose des articles rares.",
		"items": ["health_kit", "ammo_pack", "energy_cell"],
		"discount": [0, 30]
	},
	EventType.LOOT_CACHE: {
		"name": "Cache secrète",
		"description": "Vous découvrez une cache de fournitures.",
		"loot_count": [2, 5],
		"credits": [100, 300]
	},
	EventType.DISTRESS_SIGNAL: {
		"name": "Signal de détresse",
		"description": "Quelqu'un appelle à l'aide à proximité.",
		"time_limit": 60.0,
		"reward_rep": 10,
		"reward_credits": [200, 400]
	},
	EventType.GANG_WAR: {
		"name": "Guerre de gangs",
		"description": "Deux factions s'affrontent. Vous pouvez intervenir.",
		"factions": ["neon_tigers", "chrome_syndicate"],
		"enemy_count": [4, 8]
	},
	EventType.HACKER_OFFER: {
		"name": "Offre de hacker",
		"description": "Un hacker propose un job lucratif.",
		"hack_difficulty": [2, 4],
		"reward_credits": [300, 600],
		"reward_data": true
	},
	EventType.DRONE_DROP: {
		"name": "Largage aérien",
		"description": "Un drone de livraison a crashé!",
		"loot_quality": "high",
		"trap_chance": 0.3
	},
	EventType.STREET_FIGHT: {
		"name": "Combat de rue",
		"description": "Des civils sont attaqués!",
		"civilians_to_save": [1, 3],
		"enemy_count": [2, 4],
		"reward_rep": 15
	},
	EventType.DATA_LEAK: {
		"name": "Fuite de données",
		"description": "Des données sensibles sont accessibles.",
		"hack_difficulty": 3,
		"reward_xp": 50,
		"corpo_alert": true
	},
	EventType.CORPO_PATROL: {
		"name": "Patrouille corpo",
		"description": "Une patrouille de sécurité d'entreprise approche.",
		"enemy_count": [3, 6],
		"enemy_type": "elite",
		"can_avoid": true
	}
}

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var active_events: Array[Dictionary] = []
var completed_events: Array[String] = []
var _event_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _player: Node3D = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_find_player()


func _process(delta: float) -> void:
	"""Mise à jour."""
	# Cooldown global
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		return
	
	# Timer de vérification d'événement
	_event_timer += delta
	
	if _event_timer >= event_check_interval:
		_event_timer = 0.0
		_try_trigger_event()


# ==============================================================================
# GÉNÉRATION D'ÉVÉNEMENTS
# ==============================================================================

func _try_trigger_event() -> void:
	"""Tente de déclencher un événement."""
	if active_events.size() >= max_active_events:
		return
	
	# Chance modifiée par l'heure (plus d'événements la nuit)
	var chance := base_event_chance
	var day_night = get_node_or_null("/root/DayNightCycle")
	if day_night and day_night.has_method("is_night"):
		if day_night.is_night():
			chance *= 1.5
	
	if randf() > chance:
		return
	
	# Choisir un type d'événement
	var event_types := EventType.values()
	var random_type: EventType = event_types[randi() % event_types.size()]
	
	trigger_event(random_type)


func trigger_event(event_type: EventType) -> Dictionary:
	"""Déclenche un événement spécifique."""
	var template: Dictionary = event_templates.get(event_type, {})
	if template.is_empty():
		return {}
	
	# Générer les données de l'événement
	var event_data := {
		"id": str(event_type) + "_" + str(Time.get_unix_time_from_system()),
		"type": event_type,
		"name": template.get("name", "Événement"),
		"description": template.get("description", ""),
		"position": _get_event_position(),
		"start_time": Time.get_unix_time_from_system(),
		"active": true
	}
	
	# Ajouter les données spécifiques
	for key in template:
		if key not in ["name", "description"]:
			var value = template[key]
			if value is Array and value.size() == 2:
				# Range aléatoire
				event_data[key] = randi_range(value[0], value[1])
			else:
				event_data[key] = value
	
	active_events.append(event_data)
	event_triggered.emit(event_data["id"], event_data)
	
	# Notification
	_notify_event(event_data)
	
	# Spawns et logique spécifique
	_setup_event(event_data)
	
	return event_data


func _setup_event(event_data: Dictionary) -> void:
	"""Configure l'événement dans le monde."""
	var event_type: EventType = event_data.get("type", EventType.AMBUSH)
	var position: Vector3 = event_data.get("position", Vector3.ZERO)
	
	match event_type:
		EventType.AMBUSH, EventType.GANG_WAR, EventType.STREET_FIGHT, EventType.CORPO_PATROL:
			_spawn_event_enemies(event_data)
		
		EventType.LOOT_CACHE, EventType.DRONE_DROP:
			_spawn_loot(event_data)
		
		EventType.DISTRESS_SIGNAL:
			_start_timed_event(event_data)
		
		EventType.MERCHANT:
			_spawn_merchant(event_data)


func _spawn_event_enemies(event_data: Dictionary) -> void:
	"""Spawn les ennemis de l'événement."""
	var count: int = event_data.get("enemy_count", 2)
	var position: Vector3 = event_data.get("position", Vector3.ZERO)
	
	var spawn_manager = get_node_or_null("/root/SpawnManager")
	if not spawn_manager:
		return
	
	encounter_started.emit(event_data.get("name", ""))
	
	# Spawn des ennemis en cercle
	for i in range(count):
		var angle := (TAU / count) * i
		var offset := Vector3(cos(angle), 0, sin(angle)) * 5.0
		var spawn_pos := position + offset
		
		var enemy_type := "robot"
		if event_data.get("enemy_type") == "elite":
			enemy_type = "drone"
		
		spawn_manager.spawn_at_point("", enemy_type)


func _spawn_loot(event_data: Dictionary) -> void:
	"""Spawn du loot."""
	var position: Vector3 = event_data.get("position", Vector3.ZERO)
	var count: int = event_data.get("loot_count", 3)
	var credits: int = event_data.get("credits", 100)
	
	# Créer des pickups
	if ResourceLoader.exists("res://scripts/gameplay/Pickup.gd"):
		var Pickup = load("res://scripts/gameplay/Pickup.gd")
		
		# Crédits
		var credit_pickup = Pickup.create_credits(position, credits)
		get_tree().current_scene.add_child(credit_pickup)
		
		# Items aléatoires
		for i in range(count):
			var offset := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			var pickup = Pickup.new()
			pickup.pickup_type = randi() % 4  # Health, Ammo, Energy, Credits
			pickup.value = randi_range(10, 50)
			pickup.global_position = position + offset
			get_tree().current_scene.add_child(pickup)


func _spawn_merchant(event_data: Dictionary) -> void:
	"""Spawn un marchand."""
	var position: Vector3 = event_data.get("position", Vector3.ZERO)
	
	# Créer un NPC simple
	var merchant := StaticBody3D.new()
	merchant.global_position = position
	merchant.add_to_group("npc")
	merchant.add_to_group("merchant")
	merchant.add_to_group("interactable")
	
	# Visual minimal
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	mesh.mesh = capsule
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 0.3)
	mesh.set_surface_override_material(0, mat)
	merchant.add_child(mesh)
	
	# Indicateur
	var light := OmniLight3D.new()
	light.light_color = Color(0, 1, 0.5)
	light.light_energy = 1.5
	light.position.y = 2.0
	merchant.add_child(light)
	
	get_tree().current_scene.add_child(merchant)


func _start_timed_event(event_data: Dictionary) -> void:
	"""Démarre un événement à durée limitée."""
	var time_limit: float = event_data.get("time_limit", 60.0)
	
	# Timer
	await get_tree().create_timer(time_limit).timeout
	
	if event_data in active_events:
		complete_event(event_data["id"], false)


# ==============================================================================
# COMPLÉTION
# ==============================================================================

func complete_event(event_id: String, success: bool) -> void:
	"""Termine un événement."""
	var event_data: Dictionary
	var event_index := -1
	
	for i in range(active_events.size()):
		if active_events[i].get("id") == event_id:
			event_data = active_events[i]
			event_index = i
			break
	
	if event_index == -1:
		return
	
	active_events.remove_at(event_index)
	completed_events.append(event_id)
	
	if success:
		_give_rewards(event_data)
	
	event_completed.emit(event_id, success)
	
	# Cooldown
	_cooldown_timer = event_cooldown
	
	# Notification
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		if success:
			toast.show_success("✓ Événement complété!")
		else:
			toast.show_error("✕ Événement échoué")


func _give_rewards(event_data: Dictionary) -> void:
	"""Donne les récompenses de l'événement."""
	var credits: int = event_data.get("reward_credits", 0)
	var xp: int = event_data.get("xp", 0)
	var rep: int = event_data.get("reward_rep", 0)
	
	if credits > 0:
		var inventory = get_node_or_null("/root/InventoryManager")
		if inventory:
			inventory.add_credits(credits)
	
	if xp > 0:
		var skills = get_node_or_null("/root/SkillTreeManager")
		if skills and skills.has_method("add_experience"):
			skills.add_experience(xp)
	
	if rep > 0:
		var reputation = get_node_or_null("/root/ReputationManager")
		if reputation:
			reputation.change_reputation("street_cred", rep)


# ==============================================================================
# NOTIFICATIONS
# ==============================================================================

func _notify_event(event_data: Dictionary) -> void:
	"""Notifie le joueur d'un événement."""
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show("⚡ " + event_data.get("name", "Événement"), 3)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Événement: " + event_data.get("name", "") + ". " + event_data.get("description", ""))


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _get_event_position() -> Vector3:
	"""Retourne une position pour l'événement."""
	if not _player:
		_find_player()
	
	if _player:
		var angle := randf() * TAU
		var distance := randf_range(15.0, 30.0)
		return _player.global_position + Vector3(cos(angle), 0, sin(angle)) * distance
	
	return Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))


func get_active_events() -> Array[Dictionary]:
	"""Retourne les événements actifs."""
	return active_events


func force_trigger_event(event_type: EventType) -> void:
	"""Force le déclenchement d'un événement."""
	trigger_event(event_type)
