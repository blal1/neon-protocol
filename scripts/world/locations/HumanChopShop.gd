# ==============================================================================
# HumanChopShop.gd - Cliniques de Récupération Humaine
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Marché noir d'organes biologiques et cybernétiques.
# Gameplay: infiltration, extraction, choix moraux, commerce illégal.
# ==============================================================================

extends Node3D
class_name HumanChopShop

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal shop_entered(player: Node3D)
signal shop_exited(player: Node3D)
signal victim_discovered(victim_data: Dictionary)
signal moral_choice_presented(choice_data: Dictionary)
signal implant_acquired(implant_data: Dictionary)
signal trade_completed(transaction: Dictionary)

# ==============================================================================
# ENUMS
# ==============================================================================

enum ShopType {
	BACK_ALLEY,       ## Petite clinique de rue
	UNDERGROUND,      ## Grande opération souterraine
	CORPORATE_FRONT,  ## Façade légale, arrière-boutique illégale
	MOBILE            ## Clinique mobile (camion/container)
}

enum NPCRole {
	SURGEON,          ## Chirurgien - peut devenir boss ou allié
	GUARD,            ## Garde armé
	VICTIM,           ## Victime à sauver
	MERCHANT,         ## Marchand d'implants
	INFORMANT         ## Informateur
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Identité")
@export var shop_name: String = "Clinic Sans Nom"
@export var shop_type: ShopType = ShopType.BACK_ALLEY
@export var faction_owner: String = ""
@export var reputation_required: int = -50  ## Réputation minimum pour accès

@export_group("Inventaire")
@export var available_implants: Array[Dictionary] = []
@export var organ_prices: Dictionary = {
	"kidney": 500,
	"liver": 800,
	"eye": 1200,
	"heart": 3000,
	"neural_cortex": 5000,
	"cyber_arm": 2500,
	"cyber_eye": 1800
}

@export_group("NPCs")
@export var surgeon_scene: PackedScene
@export var guard_scene: PackedScene
@export var merchant_scene: PackedScene
@export var num_guards: int = 2

@export_group("Missions")
@export var has_active_victim: bool = false
@export var victim_data: Dictionary = {}
@export var infiltration_difficulty: int = 3  ## 1-5

@export_group("Zones")
@export var entry_area: Area3D
@export var surgery_room: Node3D
@export var storage_room: Node3D

# ==============================================================================
# VARIABLES
# ==============================================================================

var _player_inside: bool = false
var _current_player: Node3D = null
var _npcs: Array[Node3D] = []
var _is_hostile: bool = false
var _alarm_triggered: bool = false

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_setup_entry_area()
	_spawn_npcs()
	_initialize_inventory()


func _setup_entry_area() -> void:
	"""Configure la zone d'entrée."""
	if not entry_area:
		entry_area = Area3D.new()
		entry_area.name = "EntryArea"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(10, 5, 10)
		shape.shape = box
		entry_area.add_child(shape)
		add_child(entry_area)
	
	entry_area.body_entered.connect(_on_body_entered)
	entry_area.body_exited.connect(_on_body_exited)


func _spawn_npcs() -> void:
	"""Génère les PNJs de la clinique."""
	# Chirurgien principal
	if surgeon_scene:
		var surgeon := surgeon_scene.instantiate() as Node3D
		surgeon.set_meta("role", NPCRole.SURGEON)
		surgeon.set_meta("shop", self)
		if surgery_room:
			surgery_room.add_child(surgeon)
		else:
			add_child(surgeon)
		_npcs.append(surgeon)
	
	# Gardes
	if guard_scene:
		for i in range(num_guards):
			var guard := guard_scene.instantiate() as Node3D
			guard.set_meta("role", NPCRole.GUARD)
			guard.position = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			add_child(guard)
			_npcs.append(guard)
	
	# Marchand
	if merchant_scene:
		var merchant := merchant_scene.instantiate() as Node3D
		merchant.set_meta("role", NPCRole.MERCHANT)
		if storage_room:
			storage_room.add_child(merchant)
		else:
			add_child(merchant)
		_npcs.append(merchant)


func _initialize_inventory() -> void:
	"""Initialise l'inventaire d'implants."""
	if available_implants.is_empty():
		available_implants = [
			{"id": "cyber_eye_basic", "name": "Œil Cyber Basique", "price": 1500, "rarity": "common"},
			{"id": "reflex_booster", "name": "Booster de Réflexes", "price": 2800, "rarity": "uncommon"},
			{"id": "dermal_armor", "name": "Armure Dermique", "price": 3500, "rarity": "rare"},
			{"id": "neural_link", "name": "Lien Neural", "price": 5000, "rarity": "rare"},
		]


# ==============================================================================
# GAMEPLAY - COMMERCE
# ==============================================================================

func get_available_implants() -> Array[Dictionary]:
	"""Retourne les implants disponibles à l'achat."""
	return available_implants


func buy_implant(implant_id: String, player: Node3D) -> bool:
	"""Achète un implant."""
	for implant in available_implants:
		if implant.get("id") == implant_id:
			var price: int = implant.get("price", 0)
			
			# Vérifier crédits du joueur
			if player.has_method("get_credits"):
				var credits: int = player.get_credits()
				if credits >= price:
					player.remove_credits(price)
					
					# Ajouter à l'inventaire
					if player.has_method("add_implant"):
						player.add_implant(implant)
					elif InventoryManager:
						InventoryManager.add_item(implant)
					
					trade_completed.emit({
						"type": "buy",
						"item": implant,
						"price": price
					})
					implant_acquired.emit(implant)
					return true
			break
	return false


func sell_organ(organ_type: String, player: Node3D) -> int:
	"""Vend un organe (gameplay sombre)."""
	if not organ_prices.has(organ_type):
		return 0
	
	var price: int = organ_prices[organ_type]
	
	# Appliquer multiplicateur de réputation
	if ReputationManager:
		var rep: int = ReputationManager.get_reputation(faction_owner)
		price = int(price * (1.0 + rep / 200.0))
	
	if player.has_method("add_credits"):
		player.add_credits(price)
	
	trade_completed.emit({
		"type": "sell",
		"item": organ_type,
		"price": price
	})
	
	return price


# ==============================================================================
# GAMEPLAY - MISSIONS
# ==============================================================================

func discover_victim() -> Dictionary:
	"""Découvre une victime à sauver (mission)."""
	if not has_active_victim:
		return {}
	
	victim_discovered.emit(victim_data)
	return victim_data


func present_moral_choice() -> void:
	"""Présente un choix moral au joueur."""
	var choice_data := {
		"type": "victim_or_implant",
		"description": "Sauver la victime ou voler l'implant rare?",
		"options": [
			{
				"id": "save_victim",
				"text": "Sauver la victime",
				"karma": 50,
				"reward": {"reputation": 25, "credits": 0}
			},
			{
				"id": "steal_implant",
				"text": "Voler l'implant rare",
				"karma": -50,
				"reward": {"reputation": -10, "credits": 0, "item": "rare_neural_implant"}
			}
		]
	}
	
	moral_choice_presented.emit(choice_data)


func resolve_moral_choice(choice_id: String, player: Node3D) -> void:
	"""Résout le choix moral du joueur."""
	match choice_id:
		"save_victim":
			_save_victim(player)
		"steal_implant":
			_steal_implant(player)


func _save_victim(player: Node3D) -> void:
	"""Le joueur choisit de sauver la victime."""
	has_active_victim = false
	
	# Karma positif
	if player.has_method("add_karma"):
		player.add_karma(50)
	
	# Réputation avec faction de la victime
	if ReputationManager and victim_data.has("faction"):
		ReputationManager.add_reputation(victim_data["faction"], 25)
	
	# La clinique devient hostile
	_trigger_alarm()


func _steal_implant(player: Node3D) -> void:
	"""Le joueur choisit de voler l'implant."""
	has_active_victim = false
	
	# Karma négatif
	if player.has_method("add_karma"):
		player.add_karma(-50)
	
	# Donner l'implant
	var rare_implant := {
		"id": "stolen_neural_implant",
		"name": "Implant Neural Volé",
		"price": 8000,
		"rarity": "legendary",
		"stolen": true
	}
	
	if player.has_method("add_implant"):
		player.add_implant(rare_implant)
	elif InventoryManager:
		InventoryManager.add_item(rare_implant)
	
	implant_acquired.emit(rare_implant)


# ==============================================================================
# GAMEPLAY - COMBAT & ALARME
# ==============================================================================

func _trigger_alarm() -> void:
	"""Déclenche l'alarme de la clinique."""
	_alarm_triggered = true
	_is_hostile = true
	
	# Tous les gardes deviennent hostiles
	for npc in _npcs:
		var role = npc.get_meta("role", -1)
		if role == NPCRole.GUARD or role == NPCRole.SURGEON:
			if npc.has_method("set_hostile"):
				npc.set_hostile(true)
			if npc.has_method("attack_target"):
				npc.attack_target(_current_player)


func is_hostile() -> bool:
	"""Vérifie si la clinique est hostile."""
	return _is_hostile


func get_surgeon() -> Node3D:
	"""Retourne le chirurgien (potentiel boss)."""
	for npc in _npcs:
		if npc.get_meta("role", -1) == NPCRole.SURGEON:
			return npc
	return null


func convert_surgeon_to_ally() -> bool:
	"""Convertit le chirurgien en allié (après quête)."""
	var surgeon := get_surgeon()
	if surgeon and surgeon.has_method("set_ally"):
		surgeon.set_ally(true)
		return true
	return false


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_body_entered(body: Node3D) -> void:
	"""Appelé quand un corps entre dans la clinique."""
	if body.is_in_group("player"):
		_player_inside = true
		_current_player = body
		shop_entered.emit(body)
		
		# Vérifier réputation
		if ReputationManager:
			var rep: int = ReputationManager.get_reputation(faction_owner)
			if rep < reputation_required:
				_trigger_alarm()


func _on_body_exited(body: Node3D) -> void:
	"""Appelé quand un corps sort de la clinique."""
	if body.is_in_group("player"):
		_player_inside = false
		_current_player = null
		shop_exited.emit(body)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_shop_info() -> Dictionary:
	"""Retourne les infos de la clinique."""
	return {
		"name": shop_name,
		"type": ShopType.keys()[shop_type],
		"faction": faction_owner,
		"hostile": _is_hostile,
		"has_victim": has_active_victim,
		"implants_count": available_implants.size()
	}


func is_player_inside() -> bool:
	"""Vérifie si le joueur est dans la clinique."""
	return _player_inside
