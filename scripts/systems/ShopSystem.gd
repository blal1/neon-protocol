# ==============================================================================
# ShopSystem.gd - Système de boutique/vendeur
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les achats et ventes avec les marchands
# ==============================================================================

extends Node
class_name ShopSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal shop_opened(shop_name: String)
signal shop_closed
signal item_purchased(item_id: String, price: int)
signal item_sold(item_id: String, price: int)
signal purchase_failed(reason: String)

# ==============================================================================
# CLASSES
# ==============================================================================

class ShopItem:
	var item_id: String = ""
	var base_price: int = 0
	var stock: int = -1  # -1 = illimité
	var discount: float = 0.0  # 0.0 à 1.0
	
	func get_price() -> int:
		return int(base_price * (1.0 - discount))

class Shop:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var items: Array[ShopItem] = []
	var buy_price_multiplier: float = 1.0  # Prix d'achat
	var sell_price_multiplier: float = 0.5  # Prix de vente (50% de la valeur)

# ==============================================================================
# VARIABLES
# ==============================================================================
var current_shop: Shop = null
var _shops: Dictionary = {}  # shop_id -> Shop

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation des boutiques."""
	_create_default_shops()


# ==============================================================================
# BOUTIQUES PAR DÉFAUT
# ==============================================================================

func _create_default_shops() -> void:
	"""Crée les boutiques par défaut."""
	
	# Boutique du marché noir
	var black_market := Shop.new()
	black_market.id = "black_market"
	black_market.name = "Marché Noir"
	black_market.description = "Équipement illégal de qualité supérieure"
	black_market.buy_price_multiplier = 1.2
	black_market.sell_price_multiplier = 0.6
	
	var item1 := ShopItem.new()
	item1.item_id = "health_patch_small"
	item1.base_price = 50
	item1.stock = -1
	black_market.items.append(item1)
	
	var item2 := ShopItem.new()
	item2.item_id = "health_patch_large"
	item2.base_price = 150
	item2.stock = 5
	black_market.items.append(item2)
	
	var item3 := ShopItem.new()
	item3.item_id = "stim_pack"
	item3.base_price = 200
	item3.stock = 3
	black_market.items.append(item3)
	
	var item4 := ShopItem.new()
	item4.item_id = "cyber_blade"
	item4.base_price = 500
	item4.stock = 1
	black_market.items.append(item4)
	
	var item5 := ShopItem.new()
	item5.item_id = "nano_armor"
	item5.base_price = 750
	item5.stock = 1
	black_market.items.append(item5)
	
	_shops["black_market"] = black_market
	
	# Boutique médicale
	var med_vendor := Shop.new()
	med_vendor.id = "med_vendor"
	med_vendor.name = "MedTech Supplies"
	med_vendor.description = "Fournitures médicales officielles"
	med_vendor.buy_price_multiplier = 1.0
	med_vendor.sell_price_multiplier = 0.4
	
	var med_item1 := ShopItem.new()
	med_item1.item_id = "health_patch_small"
	med_item1.base_price = 40
	med_item1.stock = -1
	med_vendor.items.append(med_item1)
	
	var med_item2 := ShopItem.new()
	med_item2.item_id = "health_patch_large"
	med_item2.base_price = 120
	med_item2.stock = -1
	med_vendor.items.append(med_item2)
	
	_shops["med_vendor"] = med_vendor


# ==============================================================================
# OUVERTURE/FERMETURE
# ==============================================================================

func open_shop(shop_id: String) -> bool:
	"""Ouvre une boutique."""
	if not _shops.has(shop_id):
		push_warning("ShopSystem: Boutique inconnue: " + shop_id)
		return false
	
	current_shop = _shops[shop_id]
	shop_opened.emit(current_shop.name)
	
	# TTS pour accessibilité
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Boutique : " + current_shop.name + ". " + current_shop.description)
	
	return true


func close_shop() -> void:
	"""Ferme la boutique actuelle."""
	current_shop = null
	shop_closed.emit()


func is_shop_open() -> bool:
	"""Vérifie si une boutique est ouverte."""
	return current_shop != null


# ==============================================================================
# ACHAT
# ==============================================================================

func buy_item(item_index: int) -> bool:
	"""
	Achète un objet de la boutique.
	@param item_index: Index de l'objet dans la liste
	@return: true si acheté avec succès
	"""
	if not current_shop:
		purchase_failed.emit("Aucune boutique ouverte")
		return false
	
	if item_index < 0 or item_index >= current_shop.items.size():
		purchase_failed.emit("Objet invalide")
		return false
	
	var shop_item := current_shop.items[item_index]
	
	# Vérifier le stock
	if shop_item.stock == 0:
		purchase_failed.emit("Stock épuisé")
		return false
	
	# Calculer le prix
	var price := int(shop_item.get_price() * current_shop.buy_price_multiplier)
	
	# Vérifier les crédits
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return false
	
	if inv.credits < price:
		purchase_failed.emit("Crédits insuffisants")
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Crédits insuffisants. Il vous manque " + str(price - inv.credits) + " crédits.")
		return false
	
	# Effectuer l'achat
	if inv.add_item(shop_item.item_id, 1):
		inv.remove_credits(price)
		
		# Réduire le stock
		if shop_item.stock > 0:
			shop_item.stock -= 1
		
		item_purchased.emit(shop_item.item_id, price)
		
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			var template := inv.get_item_template(shop_item.item_id)
			tts.speak("Acheté : " + template.get("name", "objet") + " pour " + str(price) + " crédits")
		
		return true
	else:
		purchase_failed.emit("Inventaire plein")
		return false


func buy_item_by_id(item_id: String) -> bool:
	"""Achète un objet par son ID."""
	if not current_shop:
		return false
	
	for i in range(current_shop.items.size()):
		if current_shop.items[i].item_id == item_id:
			return buy_item(i)
	return false


# ==============================================================================
# VENTE
# ==============================================================================

func sell_item(item_id: String, quantity: int = 1) -> bool:
	"""
	Vend un objet de l'inventaire.
	@return: true si vendu avec succès
	"""
	if not current_shop:
		purchase_failed.emit("Aucune boutique ouverte")
		return false
	
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return false
	
	if not inv.has_item(item_id, quantity):
		purchase_failed.emit("Vous ne possédez pas cet objet")
		return false
	
	# Calculer le prix de vente
	var template := inv.get_item_template(item_id)
	var base_value: int = template.get("value", 0)
	var sell_price := int(base_value * current_shop.sell_price_multiplier * quantity)
	
	if sell_price <= 0:
		purchase_failed.emit("Cet objet n'a pas de valeur")
		return false
	
	# Effectuer la vente
	if inv.remove_item(item_id, quantity):
		inv.add_credits(sell_price)
		item_sold.emit(item_id, sell_price)
		
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Vendu pour " + str(sell_price) + " crédits")
		
		return true
	
	return false


# ==============================================================================
# INFORMATIONS
# ==============================================================================

func get_shop_items() -> Array:
	"""Retourne la liste des objets de la boutique actuelle."""
	if not current_shop:
		return []
	
	var result := []
	var inv = get_node_or_null("/root/InventoryManager")
	
	for shop_item in current_shop.items:
		var template := {}
		if inv:
			template = inv.get_item_template(shop_item.item_id)
		
		result.append({
			"item_id": shop_item.item_id,
			"name": template.get("name", shop_item.item_id),
			"description": template.get("description", ""),
			"price": int(shop_item.get_price() * current_shop.buy_price_multiplier),
			"stock": shop_item.stock,
			"available": shop_item.stock != 0
		})
	
	return result


func get_sell_price(item_id: String) -> int:
	"""Calcule le prix de vente d'un objet."""
	if not current_shop:
		return 0
	
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return 0
	
	var template := inv.get_item_template(item_id)
	var base_value: int = template.get("value", 0)
	return int(base_value * current_shop.sell_price_multiplier)


func get_current_shop_name() -> String:
	"""Retourne le nom de la boutique actuelle."""
	if current_shop:
		return current_shop.name
	return ""
