# ==============================================================================
# FoodStall.gd - Food Trucks & Noodle Stalls
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Lieux sociaux ultra-importants dans une ville fragmentée.
# Gameplay: rumeurs, buffs, informateurs, points de rendez-vous.
# ==============================================================================

extends Node3D
class_name FoodStall

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal customer_arrived(player: Node3D)
signal food_purchased(food_data: Dictionary)
signal buff_applied(buff_data: Dictionary)
signal rumor_heard(rumor_data: Dictionary)
signal secret_revealed(secret_type: String)
signal faction_meeting_triggered(factions: Array)

# ==============================================================================
# ENUMS
# ==============================================================================

enum StallType {
	NOODLE_STAND,   ## Stand de nouilles classique
	FOOD_TRUCK,     ## Camion mobile
	RAMEN_SHOP,     ## Petit restaurant
	STREET_VENDOR,  ## Vendeur ambulant
	SYNTH_MEAT_BAR  ## Bar à viande synthétique
}

enum VendorRole {
	NORMAL,         ## Vendeur normal
	INFORMANT,      ## Informateur secret
	FACTION_CONTACT,## Contact de faction
	UNDERCOVER,     ## Agent infiltré
	TARGET          ## Cible de mission
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Identité")
@export var stall_name: String = "Noodles Express"
@export var stall_type: StallType = StallType.NOODLE_STAND
@export var is_mobile: bool = false  ## Se déplace-t-il?

@export_group("Vendeur")
@export var vendor_name: String = "Chen"
@export var vendor_role: VendorRole = VendorRole.NORMAL
@export var vendor_faction: String = ""
@export var vendor_scene: PackedScene

@export_group("Menu")
@export var menu_items: Array[Dictionary] = []

@export_group("Rumeurs")
@export var available_rumors: Array[Dictionary] = []
@export var rumor_refresh_time: float = 300.0  ## Nouvelles rumeurs toutes les 5 min

@export_group("Factions")
@export var faction_meeting_point: bool = false
@export var meeting_factions: Array[String] = []
@export var meeting_time_range: Vector2 = Vector2(18.0, 22.0)  ## Heures de réunion

# ==============================================================================
# VARIABLES
# ==============================================================================

var _vendor: Node3D = null
var _current_customer: Node3D = null
var _active_buffs: Dictionary = {}
var _heard_rumors: Array[String] = []
var _rumor_timer: float = 0.0
var _current_rumor_index: int = 0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_initialize_menu()
	_initialize_rumors()
	_spawn_vendor()
	_setup_interaction_area()


func _initialize_menu() -> void:
	"""Initialise le menu si vide."""
	if menu_items.is_empty():
		menu_items = [
			{
				"id": "synth_noodles",
				"name": "Nouilles Synthétiques",
				"price": 15,
				"buff": {"type": "stamina_regen", "value": 1.5, "duration": 120.0}
			},
			{
				"id": "mystery_ramen",
				"name": "Ramen Mystère",
				"price": 25,
				"buff": {"type": "health_regen", "value": 2.0, "duration": 180.0}
			},
			{
				"id": "cyber_coffee",
				"name": "Cyber Café",
				"price": 10,
				"buff": {"type": "focus", "value": 1.2, "duration": 300.0}
			},
			{
				"id": "protein_shake",
				"name": "Shake Protéiné",
				"price": 20,
				"buff": {"type": "damage_boost", "value": 1.1, "duration": 150.0}
			},
			{
				"id": "lucky_dumpling",
				"name": "Ravioli Chanceux",
				"price": 50,
				"buff": {"type": "luck", "value": 1.5, "duration": 600.0}
			}
		]


func _initialize_rumors() -> void:
	"""Initialise les rumeurs disponibles."""
	if available_rumors.is_empty():
		available_rumors = [
			{
				"id": "corpo_scandal",
				"text": "J'ai entendu dire que NovaTech teste des implants sur des civils...",
				"faction": "novatech",
				"importance": "high"
			},
			{
				"id": "gang_war",
				"text": "Les Neon Dragons et les Chrome Vipers vont s'affronter ce soir.",
				"location": "sector_7",
				"importance": "medium"
			},
			{
				"id": "hidden_shop",
				"text": "Il y a une clinique cachée sous le vieux métro. Ils vendent des trucs rares.",
				"poi": "human_chop_shop_secret",
				"importance": "high"
			},
			{
				"id": "police_raid",
				"text": "La corpo prépare une descente dans le Sol Mort demain.",
				"layer": "DEAD_GROUND",
				"importance": "medium"
			}
		]


func _spawn_vendor() -> void:
	"""Génère le vendeur."""
	if vendor_scene:
		_vendor = vendor_scene.instantiate() as Node3D
	else:
		# Créer un placeholder
		_vendor = Node3D.new()
		_vendor.name = "Vendor"
	
	_vendor.set_meta("vendor_name", vendor_name)
	_vendor.set_meta("vendor_role", vendor_role)
	_vendor.set_meta("vendor_faction", vendor_faction)
	add_child(_vendor)


func _setup_interaction_area() -> void:
	"""Configure la zone d'interaction."""
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 0
	area.collision_mask = 2  # Player
	
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 4.0
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	# Actualiser les rumeurs
	_rumor_timer += delta
	if _rumor_timer >= rumor_refresh_time:
		_rumor_timer = 0.0
		_current_rumor_index = (_current_rumor_index + 1) % available_rumors.size()
	
	# Vérifier meeting de factions
	if faction_meeting_point:
		_check_faction_meeting()


# ==============================================================================
# GAMEPLAY - COMMERCE
# ==============================================================================

func get_menu() -> Array[Dictionary]:
	"""Retourne le menu."""
	return menu_items


func purchase_food(food_id: String, player: Node3D) -> bool:
	"""Achète un plat."""
	for item in menu_items:
		if item.get("id") == food_id:
			var price: int = item.get("price", 0)
			
			# Vérifier crédits
			if player.has_method("get_credits"):
				var credits: int = player.get_credits()
				if credits >= price:
					player.remove_credits(price)
					
					# Appliquer le buff
					var buff: Dictionary = item.get("buff", {})
					if not buff.is_empty():
						_apply_buff(player, buff)
					
					food_purchased.emit(item)
					
					# Chance d'entendre une rumeur
					if randf() < 0.4:
						_share_rumor()
					
					return true
			break
	return false


func _apply_buff(player: Node3D, buff_data: Dictionary) -> void:
	"""Applique un buff au joueur."""
	var buff_type: String = buff_data.get("type", "")
	var buff_value: float = buff_data.get("value", 1.0)
	var duration: float = buff_data.get("duration", 60.0)
	
	if player.has_method("apply_buff"):
		player.apply_buff(buff_type, buff_value, duration)
	
	# Stocker le buff actif
	_active_buffs[buff_type] = {
		"value": buff_value,
		"duration": duration,
		"start_time": Time.get_ticks_msec() / 1000.0
	}
	
	buff_applied.emit(buff_data)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Buff %s activé pour %d secondes" % [buff_type, int(duration)])


# ==============================================================================
# GAMEPLAY - RUMEURS
# ==============================================================================

func _share_rumor() -> void:
	"""Partage une rumeur au joueur."""
	if available_rumors.is_empty():
		return
	
	var rumor := available_rumors[_current_rumor_index]
	var rumor_id: String = rumor.get("id", "")
	
	# Ne pas répéter les rumeurs déjà entendues
	if rumor_id in _heard_rumors:
		return
	
	_heard_rumors.append(rumor_id)
	rumor_heard.emit(rumor)
	
	# Afficher/dire la rumeur
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak(vendor_name + " murmure: " + rumor.get("text", ""))
	
	# Notifier le système de quêtes si rumeur importante
	if rumor.get("importance") == "high":
		if MissionManager and MissionManager.has_method("add_intel"):
			MissionManager.add_intel(rumor)


func get_new_rumor() -> Dictionary:
	"""Demande explicitement une nouvelle rumeur."""
	if available_rumors.is_empty():
		return {}
	
	# Trouver une rumeur non entendue
	for rumor in available_rumors:
		var rumor_id: String = rumor.get("id", "")
		if rumor_id not in _heard_rumors:
			_heard_rumors.append(rumor_id)
			rumor_heard.emit(rumor)
			return rumor
	
	# Toutes les rumeurs ont été entendues
	return {"id": "no_more", "text": "Je n'ai rien de nouveau pour toi aujourd'hui."}


# ==============================================================================
# GAMEPLAY - INFORMATEUR
# ==============================================================================

func is_informant() -> bool:
	"""Vérifie si le vendeur est un informateur."""
	return vendor_role == VendorRole.INFORMANT or vendor_role == VendorRole.FACTION_CONTACT


func get_secret_intel(player: Node3D) -> Dictionary:
	"""Obtient des informations secrètes (si informateur)."""
	if not is_informant():
		return {}
	
	# Vérifier réputation avec la faction
	if vendor_faction != "" and ReputationManager:
		var rep: int = ReputationManager.get_reputation(vendor_faction)
		if rep < 0:
			return {"error": "trust_too_low", "text": "Je ne te fais pas assez confiance."}
	
	# Générer l'intel
	var intel := {
		"type": "secret",
		"source": vendor_name,
		"faction": vendor_faction,
		"data": _generate_secret_intel()
	}
	
	secret_revealed.emit("intel")
	return intel


func _generate_secret_intel() -> Dictionary:
	"""Génère des informations secrètes."""
	var intel_types := [
		{"type": "location", "name": "Cachette secrète", "coordinates": Vector3(randi() % 400, 0, randi() % 400)},
		{"type": "target", "name": "Cible VIP", "health": 500, "reward": 2000},
		{"type": "code", "name": "Code d'accès", "value": str(randi() % 10000).pad_zeros(4)},
	]
	return intel_types[randi() % intel_types.size()]


# ==============================================================================
# GAMEPLAY - POINT DE RENDEZ-VOUS FACTIONS
# ==============================================================================

func _check_faction_meeting() -> void:
	"""Vérifie si c'est l'heure d'une réunion de factions."""
	if meeting_factions.size() < 2:
		return
	
	# Simuler l'heure du jeu (utiliser DayNightCycle si disponible)
	var current_hour := fmod(Time.get_ticks_msec() / 1000.0 / 60.0, 24.0)
	
	if current_hour >= meeting_time_range.x and current_hour <= meeting_time_range.y:
		faction_meeting_triggered.emit(meeting_factions)


func trigger_faction_event() -> void:
	"""Déclenche un événement de faction au food truck."""
	# Le food truck devient un lieu de tension
	if meeting_factions.size() >= 2:
		# Notifier le système d'événements
		if MissionManager and MissionManager.has_method("trigger_dynamic_event"):
			MissionManager.trigger_dynamic_event({
				"type": "faction_meeting",
				"location": global_position,
				"factions": meeting_factions,
				"tension": "high"
			})


# ==============================================================================
# GAMEPLAY - MOBILITÉ
# ==============================================================================

func move_to_new_location(new_position: Vector3) -> void:
	"""Déplace le food truck (si mobile)."""
	if not is_mobile:
		return
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", new_position, 5.0)


func get_next_location() -> Vector3:
	"""Retourne la prochaine position du food truck mobile."""
	if not is_mobile:
		return global_position
	
	# Générer une nouvelle position aléatoire dans la zone
	return Vector3(
		global_position.x + randf_range(-50, 50),
		global_position.y,
		global_position.z + randf_range(-50, 50)
	)


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_body_entered(body: Node3D) -> void:
	"""Appelé quand le joueur s'approche."""
	if body.is_in_group("player"):
		_current_customer = body
		customer_arrived.emit(body)
		
		# TTS
		if TTSManager and TTSManager.has_method("speak"):
			TTSManager.speak("Bienvenue chez %s!" % stall_name)


func _on_body_exited(body: Node3D) -> void:
	"""Appelé quand le joueur s'éloigne."""
	if body.is_in_group("player"):
		_current_customer = null


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_stall_info() -> Dictionary:
	"""Retourne les infos du stand."""
	return {
		"name": stall_name,
		"type": StallType.keys()[stall_type],
		"vendor": vendor_name,
		"is_informant": is_informant(),
		"menu_size": menu_items.size(),
		"rumors_available": available_rumors.size() - _heard_rumors.size()
	}


func get_vendor() -> Node3D:
	"""Retourne le vendeur."""
	return _vendor
