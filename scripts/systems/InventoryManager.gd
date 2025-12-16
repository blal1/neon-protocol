# ==============================================================================
# InventoryManager.gd - Gestionnaire d'inventaire
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Autoload Singleton pour gérer les objets du joueur
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal item_added(item: InventoryItem)
signal item_removed(item_id: String)
signal item_used(item: InventoryItem)
signal item_equipped(item: InventoryItem, slot: String)
signal item_unequipped(slot: String)
signal inventory_full
signal credits_changed(new_amount: int)

# ==============================================================================
# CLASSES
# ==============================================================================

class InventoryItem:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon_path: String = ""
	var item_type: String = ""  # "consumable", "weapon", "armor", "key", "misc"
	var quantity: int = 1
	var max_stack: int = 99
	var is_usable: bool = false
	var is_equippable: bool = false
	var effects: Dictionary = {}  # Ex: {"heal": 50, "damage": 10}
	var value: int = 0  # Prix en crédits
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"description": description,
			"icon_path": icon_path,
			"item_type": item_type,
			"quantity": quantity,
			"max_stack": max_stack,
			"is_usable": is_usable,
			"is_equippable": is_equippable,
			"effects": effects,
			"value": value
		}
	
	static func from_dict(data: Dictionary) -> InventoryItem:
		var item := InventoryItem.new()
		item.id = data.get("id", "")
		item.name = data.get("name", "Objet")
		item.description = data.get("description", "")
		item.icon_path = data.get("icon_path", "")
		item.item_type = data.get("item_type", "misc")
		item.quantity = data.get("quantity", 1)
		item.max_stack = data.get("max_stack", 99)
		item.is_usable = data.get("is_usable", false)
		item.is_equippable = data.get("is_equippable", false)
		item.effects = data.get("effects", {})
		item.value = data.get("value", 0)
		return item

# ==============================================================================
# CONSTANTES
# ==============================================================================
const MAX_INVENTORY_SIZE := 20
const ITEM_DATABASE_PATH := "res://data/items.json"

# ==============================================================================
# VARIABLES
# ==============================================================================
var items: Array[InventoryItem] = []
var equipped: Dictionary = {}  # {"weapon": InventoryItem, "armor": InventoryItem}
var credits: int = 0
var _item_database: Dictionary = {}

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation de l'inventaire."""
	_load_item_database()


# ==============================================================================
# BASE DE DONNÉES D'OBJETS
# ==============================================================================

func _load_item_database() -> void:
	"""Charge la base de données d'objets."""
	if not FileAccess.file_exists(ITEM_DATABASE_PATH):
		_create_default_database()
		return
	
	var file := FileAccess.open(ITEM_DATABASE_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("InventoryManager: Erreur de parsing JSON: %s (ligne %d)" % [
			json.get_error_message(),
			json.get_error_line()
		])
		_create_default_database()
		return
	
	if json.data == null or not json.data is Array:
		push_error("InventoryManager: Format JSON invalide - array attendu")
		_create_default_database()
		return
	
	for item_data in json.data:
		if item_data is Dictionary and item_data.has("id"):
			_item_database[item_data["id"]] = item_data


func _create_default_database() -> void:
	"""Crée une base de données par défaut."""
	_item_database = {
		"health_patch_small": {
			"id": "health_patch_small",
			"name": "Patch Médical",
			"description": "Restaure 25 points de vie",
			"item_type": "consumable",
			"is_usable": true,
			"effects": {"heal": 25},
			"value": 50
		},
		"health_patch_large": {
			"id": "health_patch_large",
			"name": "Patch Médical+",
			"description": "Restaure 75 points de vie",
			"item_type": "consumable",
			"is_usable": true,
			"effects": {"heal": 75},
			"value": 150
		},
		"stim_pack": {
			"id": "stim_pack",
			"name": "Stim-Pack",
			"description": "Augmente la vitesse pendant 30 secondes",
			"item_type": "consumable",
			"is_usable": true,
			"effects": {"speed_boost": 1.5, "duration": 30},
			"value": 200
		},
		"data_chip": {
			"id": "data_chip",
			"name": "Data Chip",
			"description": "Données cryptées de NovaTech",
			"item_type": "key",
			"is_usable": false,
			"value": 0
		},
		"cyber_blade": {
			"id": "cyber_blade",
			"name": "Cyber-Lame",
			"description": "Arme de mêlée améliorée. +10 dégâts",
			"item_type": "weapon",
			"is_equippable": true,
			"effects": {"damage_bonus": 10},
			"value": 500
		},
		"nano_armor": {
			"id": "nano_armor",
			"name": "Nano-Armure",
			"description": "Réduction des dégâts de 20%",
			"item_type": "armor",
			"is_equippable": true,
			"effects": {"damage_reduction": 0.2},
			"value": 750
		}
	}


func get_item_template(item_id: String) -> Dictionary:
	"""Retourne le template d'un objet."""
	return _item_database.get(item_id, {})


# ==============================================================================
# GESTION DE L'INVENTAIRE
# ==============================================================================

func add_item(item_id: String, quantity: int = 1) -> bool:
	"""
	Ajoute un objet à l'inventaire.
	@return: true si ajouté avec succès
	"""
	var template := get_item_template(item_id)
	if template.is_empty():
		push_warning("InventoryManager: Item inconnu: " + item_id)
		return false
	
	# Chercher si l'objet existe déjà (pour stack)
	for existing_item in items:
		if existing_item.id == item_id and existing_item.quantity < existing_item.max_stack:
			var can_add := mini(quantity, existing_item.max_stack - existing_item.quantity)
			existing_item.quantity += can_add
			item_added.emit(existing_item)
			
			quantity -= can_add
			if quantity <= 0:
				return true
	
	# Créer un nouvel item si nécessaire
	if items.size() >= MAX_INVENTORY_SIZE:
		inventory_full.emit()
		return false
	
	var new_item := InventoryItem.from_dict(template)
	new_item.quantity = quantity
	items.append(new_item)
	item_added.emit(new_item)
	
	# Annoncer via TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.announce_item_pickup(new_item.name)
	
	return true


func remove_item(item_id: String, quantity: int = 1) -> bool:
	"""Retire un objet de l'inventaire."""
	for i in range(items.size() - 1, -1, -1):
		if items[i].id == item_id:
			if items[i].quantity > quantity:
				items[i].quantity -= quantity
				return true
			else:
				quantity -= items[i].quantity
				items.remove_at(i)
				item_removed.emit(item_id)
				
				if quantity <= 0:
					return true
	return false


func has_item(item_id: String, quantity: int = 1) -> bool:
	"""Vérifie si l'inventaire contient un objet."""
	var total := 0
	for item in items:
		if item.id == item_id:
			total += item.quantity
	return total >= quantity


func get_item_count(item_id: String) -> int:
	"""Retourne la quantité d'un objet."""
	var total := 0
	for item in items:
		if item.id == item_id:
			total += item.quantity
	return total


func get_all_items() -> Array:
	"""Retourne tous les objets sous forme de dictionnaires."""
	var result := []
	for item in items:
		result.append(item.to_dict())
	return result


# ==============================================================================
# UTILISATION D'OBJETS
# ==============================================================================

func use_item(item_id: String) -> bool:
	"""Utilise un objet consommable."""
	for item in items:
		if item.id == item_id and item.is_usable:
			_apply_item_effects(item)
			item_used.emit(item)
			remove_item(item_id, 1)
			return true
	return false


func _apply_item_effects(item: InventoryItem) -> void:
	"""Applique les effets d'un objet."""
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	
	var player := players[0]
	var health_comp = player.get_node_or_null("HealthComponent")
	
	for effect_key in item.effects:
		match effect_key:
			"heal":
				if health_comp and health_comp.has_method("heal"):
					health_comp.heal(item.effects[effect_key])
			"speed_boost":
				var multiplier: float = item.effects.get("speed_boost", 1.5)
				var duration: float = item.effects.get("duration", 30.0)
				_apply_speed_boost(player, multiplier, duration)


func _apply_speed_boost(player: Node3D, multiplier: float, duration: float) -> void:
	"""
	Applique un boost de vitesse temporaire au joueur.
	@param player: Le nœud joueur
	@param multiplier: Multiplicateur de vitesse (ex: 1.5 = +50%)
	@param duration: Durée en secondes
	"""
	if not player:
		return
	
	# Vérifier si le joueur a une propriété move_speed
	if not "move_speed" in player:
		push_warning("InventoryManager: Player n'a pas de propriété move_speed")
		return
	
	# Sauvegarder la vitesse originale si pas déjà fait
	if not player.has_meta("original_move_speed"):
		player.set_meta("original_move_speed", player.move_speed)
	
	var original_speed: float = player.get_meta("original_move_speed")
	
	# Appliquer le boost
	player.move_speed = original_speed * multiplier
	
	# Feedback visuel
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_notification("⚡ Vitesse augmentée!", toast.NotificationType.ACHIEVEMENT, duration)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Boost de vitesse activé")
	
	# Haptic
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic and haptic.has_method("vibrate_light"):
		haptic.vibrate_light()
	
	# Timer pour restaurer la vitesse
	await get_tree().create_timer(duration).timeout
	
	# Restaurer la vitesse originale
	if is_instance_valid(player) and player.has_meta("original_move_speed"):
		player.move_speed = player.get_meta("original_move_speed")
		player.remove_meta("original_move_speed")
		
		# Feedback fin du boost
		if toast:
			toast.show_notification("Vitesse normale", toast.NotificationType.INFO, 2.0)
		if tts:
			tts.speak("Boost terminé")


# ==============================================================================
# ÉQUIPEMENT
# ==============================================================================

func equip_item(item_id: String) -> bool:
	"""Équipe un objet."""
	for item in items:
		if item.id == item_id and item.is_equippable:
			var slot := item.item_type  # "weapon" ou "armor"
			
			# Déséquiper l'ancien si présent
			if equipped.has(slot):
				unequip_item(slot)
			
			equipped[slot] = item
			item_equipped.emit(item, slot)
			return true
	return false


func unequip_item(slot: String) -> bool:
	"""Déséquipe un objet."""
	if equipped.has(slot):
		equipped.erase(slot)
		item_unequipped.emit(slot)
		return true
	return false


func get_equipped(slot: String) -> InventoryItem:
	"""Retourne l'objet équipé dans un slot."""
	return equipped.get(slot, null)


func get_total_damage_bonus() -> float:
	"""Calcule le bonus de dégâts total."""
	var bonus := 0.0
	var weapon: InventoryItem = equipped.get("weapon", null)
	if weapon:
		bonus += weapon.effects.get("damage_bonus", 0)
	return bonus


func get_damage_reduction() -> float:
	"""Calcule la réduction de dégâts."""
	var reduction := 0.0
	var armor: InventoryItem = equipped.get("armor", null)
	if armor:
		reduction += armor.effects.get("damage_reduction", 0)
	return clamp(reduction, 0.0, 0.9)


# ==============================================================================
# CRÉDITS
# ==============================================================================

func add_credits(amount: int) -> void:
	"""Ajoute des crédits."""
	credits += amount
	credits_changed.emit(credits)


func remove_credits(amount: int) -> bool:
	"""Retire des crédits si possible."""
	if credits >= amount:
		credits -= amount
		credits_changed.emit(credits)
		return true
	return false


func get_credits() -> int:
	"""Retourne le montant de crédits."""
	return credits
