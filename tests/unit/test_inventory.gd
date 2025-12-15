# ==============================================================================
# test_inventory.gd - Tests unitaires pour l'inventaire
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# TESTS
# ==============================================================================

func test_inventory_manager_exists() -> Dictionary:
	"""Vérifie que InventoryManager est un autoload."""
	var inventory = Engine.get_main_loop().root.get_node_or_null("/root/InventoryManager")
	return runner.assert_not_null(inventory, "InventoryManager autoload non trouvé")


func test_inventory_script_exists() -> Dictionary:
	"""Vérifie que le script InventoryManager existe."""
	var exists := ResourceLoader.exists("res://scripts/systems/InventoryManager.gd")
	return runner.assert_true(exists, "InventoryManager.gd n'existe pas")


func test_inventory_has_add_item_method() -> Dictionary:
	"""Vérifie que InventoryManager a la méthode add_item."""
	var inventory = Engine.get_main_loop().root.get_node_or_null("/root/InventoryManager")
	if not inventory:
		return {"passed": false, "message": "InventoryManager non trouvé"}
	
	return runner.assert_has_method(inventory, "add_item")


func test_inventory_has_remove_item_method() -> Dictionary:
	"""Vérifie que InventoryManager a la méthode remove_item."""
	var inventory = Engine.get_main_loop().root.get_node_or_null("/root/InventoryManager")
	if not inventory:
		return {"passed": false, "message": "InventoryManager non trouvé"}
	
	return runner.assert_has_method(inventory, "remove_item")


func test_inventory_has_get_item_count_method() -> Dictionary:
	"""Vérifie que InventoryManager a la méthode get_item_count."""
	var inventory = Engine.get_main_loop().root.get_node_or_null("/root/InventoryManager")
	if not inventory:
		return {"passed": false, "message": "InventoryManager non trouvé"}
	
	return runner.assert_has_method(inventory, "get_item_count")


func test_inventory_currency_operations() -> Dictionary:
	"""Vérifie les opérations de monnaie."""
	var inventory = Engine.get_main_loop().root.get_node_or_null("/root/InventoryManager")
	if not inventory:
		return {"passed": false, "message": "InventoryManager non trouvé"}
	
	if not inventory.has_method("get_currency"):
		return {"passed": false, "message": "Méthode get_currency manquante"}
	
	if not inventory.has_method("add_currency"):
		return {"passed": false, "message": "Méthode add_currency manquante"}
	
	return {"passed": true}
