# ==============================================================================
# test_world_layers.gd - Tests Unitaires du Système de Couches
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends Node

# ==============================================================================
# TESTS
# ==============================================================================

func run_all_tests() -> Dictionary:
	"""Exécute tous les tests et retourne les résultats."""
	var results := {
		"passed": 0,
		"failed": 0,
		"tests": []
	}
	
	# Liste des tests
	var tests := [
		"test_layer_detection_by_altitude",
		"test_layer_data_retrieval",
		"test_layer_names",
		"test_danger_levels",
		"test_loot_multipliers",
		"test_hazard_lists",
		"test_police_response",
	]
	
	for test_name in tests:
		var result := _run_test(test_name)
		results.tests.append(result)
		if result.passed:
			results.passed += 1
		else:
			results.failed += 1
	
	return results


func _run_test(test_name: String) -> Dictionary:
	"""Exécute un test individuel."""
	var result := {"name": test_name, "passed": false, "message": ""}
	
	if has_method(test_name):
		var test_result = call(test_name)
		result.passed = test_result.passed
		result.message = test_result.message
	else:
		result.message = "Test method not found"
	
	return result


# ==============================================================================
# TEST: Détection de couche par altitude
# ==============================================================================

func test_layer_detection_by_altitude() -> Dictionary:
	var passed := true
	var messages := []
	
	# Test Sol Mort (0 à -50)
	var layer := WorldLayerTypes.get_layer_from_altitude(-25.0)
	if layer != WorldLayerTypes.LayerType.DEAD_GROUND:
		passed = false
		messages.append("Altitude -25 devrait être DEAD_GROUND, obtenu: %s" % layer)
	
	layer = WorldLayerTypes.get_layer_from_altitude(0.0)
	if layer != WorldLayerTypes.LayerType.DEAD_GROUND:
		passed = false
		messages.append("Altitude 0 devrait être DEAD_GROUND, obtenu: %s" % layer)
	
	# Test Ville Vivante (1 à 200)
	layer = WorldLayerTypes.get_layer_from_altitude(50.0)
	if layer != WorldLayerTypes.LayerType.LIVING_CITY:
		passed = false
		messages.append("Altitude 50 devrait être LIVING_CITY, obtenu: %s" % layer)
	
	layer = WorldLayerTypes.get_layer_from_altitude(200.0)
	if layer != WorldLayerTypes.LayerType.LIVING_CITY:
		passed = false
		messages.append("Altitude 200 devrait être LIVING_CITY, obtenu: %s" % layer)
	
	# Test Tours Corporatistes (201+)
	layer = WorldLayerTypes.get_layer_from_altitude(250.0)
	if layer != WorldLayerTypes.LayerType.CORPORATE_TOWERS:
		passed = false
		messages.append("Altitude 250 devrait être CORPORATE_TOWERS, obtenu: %s" % layer)
	
	# Test Sous-Réseau (< -50)
	layer = WorldLayerTypes.get_layer_from_altitude(-80.0)
	if layer != WorldLayerTypes.LayerType.SUBNETWORK:
		passed = false
		messages.append("Altitude -80 devrait être SUBNETWORK, obtenu: %s" % layer)
	
	return {
		"passed": passed,
		"message": "OK" if passed else "; ".join(messages)
	}


# ==============================================================================
# TEST: Récupération des données de couche
# ==============================================================================

func test_layer_data_retrieval() -> Dictionary:
	var passed := true
	var messages := []
	
	for layer_type in [
		WorldLayerTypes.LayerType.DEAD_GROUND,
		WorldLayerTypes.LayerType.LIVING_CITY,
		WorldLayerTypes.LayerType.CORPORATE_TOWERS,
		WorldLayerTypes.LayerType.SUBNETWORK
	]:
		var data := WorldLayerTypes.get_layer_data(layer_type)
		
		if data.is_empty():
			passed = false
			messages.append("Données vides pour couche %s" % layer_type)
			continue
		
		# Vérifier les champs obligatoires
		var required_fields := ["name", "description", "altitude_min", "altitude_max", "danger_level"]
		for field in required_fields:
			if not data.has(field):
				passed = false
				messages.append("Champ '%s' manquant pour couche %s" % [field, layer_type])
	
	return {
		"passed": passed,
		"message": "OK" if passed else "; ".join(messages)
	}


# ==============================================================================
# TEST: Noms de couches
# ==============================================================================

func test_layer_names() -> Dictionary:
	var passed := true
	var messages := []
	
	var expected_names := {
		WorldLayerTypes.LayerType.DEAD_GROUND: "Sol Mort",
		WorldLayerTypes.LayerType.LIVING_CITY: "Ville Vivante",
		WorldLayerTypes.LayerType.CORPORATE_TOWERS: "Tours Corporatistes",
		WorldLayerTypes.LayerType.SUBNETWORK: "Sous-Réseau"
	}
	
	for layer_type in expected_names.keys():
		var name := WorldLayerTypes.get_layer_name(layer_type)
		if name != expected_names[layer_type]:
			passed = false
			messages.append("Nom incorrect pour %s: attendu '%s', obtenu '%s'" % [
				layer_type, expected_names[layer_type], name
			])
	
	# Test noms anglais
	var name_en := WorldLayerTypes.get_layer_name(WorldLayerTypes.LayerType.DEAD_GROUND, true)
	if name_en != "Dead Ground":
		passed = false
		messages.append("Nom anglais incorrect: attendu 'Dead Ground', obtenu '%s'" % name_en)
	
	return {
		"passed": passed,
		"message": "OK" if passed else "; ".join(messages)
	}


# ==============================================================================
# TEST: Niveaux de danger
# ==============================================================================

func test_danger_levels() -> Dictionary:
	var passed := true
	var messages := []
	
	# Sol Mort et Sous-Réseau doivent être EXTREME
	var danger := WorldLayerTypes.get_danger_level(WorldLayerTypes.LayerType.DEAD_GROUND)
	if danger != WorldLayerTypes.DangerLevel.EXTREME:
		passed = false
		messages.append("DEAD_GROUND devrait être EXTREME, obtenu: %s" % danger)
	
	danger = WorldLayerTypes.get_danger_level(WorldLayerTypes.LayerType.SUBNETWORK)
	if danger != WorldLayerTypes.DangerLevel.EXTREME:
		passed = false
		messages.append("SUBNETWORK devrait être EXTREME, obtenu: %s" % danger)
	
	# Tours Corporatistes = HIGH
	danger = WorldLayerTypes.get_danger_level(WorldLayerTypes.LayerType.CORPORATE_TOWERS)
	if danger != WorldLayerTypes.DangerLevel.HIGH:
		passed = false
		messages.append("CORPORATE_TOWERS devrait être HIGH, obtenu: %s" % danger)
	
	return {
		"passed": passed,
		"message": "OK" if passed else "; ".join(messages)
	}


# ==============================================================================
# TEST: Multiplicateurs de loot
# ==============================================================================

func test_loot_multipliers() -> Dictionary:
	var passed := true
	var messages := []
	
	# Sous-Réseau a le meilleur loot (2.0x)
	var mult := WorldLayerTypes.get_loot_multiplier(WorldLayerTypes.LayerType.SUBNETWORK)
	if mult != 2.0:
		passed = false
		messages.append("SUBNETWORK loot mult devrait être 2.0, obtenu: %s" % mult)
	
	# Tours Corporatistes (1.5x)
	mult = WorldLayerTypes.get_loot_multiplier(WorldLayerTypes.LayerType.CORPORATE_TOWERS)
	if mult != 1.5:
		passed = false
		messages.append("CORPORATE_TOWERS loot mult devrait être 1.5, obtenu: %s" % mult)
	
	# Ville Vivante (1.0x)
	mult = WorldLayerTypes.get_loot_multiplier(WorldLayerTypes.LayerType.LIVING_CITY)
	if mult != 1.0:
		passed = false
		messages.append("LIVING_CITY loot mult devrait être 1.0, obtenu: %s" % mult)
	
	return {
		"passed": passed,
		"message": "OK" if passed else "; ".join(messages)
	}


# ==============================================================================
# TEST: Listes de dangers
# ==============================================================================

func test_hazard_lists() -> Dictionary:
	var passed := true
	var messages := []
	
	# Sol Mort doit avoir toxic_fog
	var hazards := WorldLayerTypes.get_hazards(WorldLayerTypes.LayerType.DEAD_GROUND)
	if "toxic_fog" not in hazards:
		passed = false
		messages.append("DEAD_GROUND devrait avoir 'toxic_fog' dans ses dangers")
	
	# Tours Corporatistes doit avoir security_turrets
	hazards = WorldLayerTypes.get_hazards(WorldLayerTypes.LayerType.CORPORATE_TOWERS)
	if "security_turrets" not in hazards:
		passed = false
		messages.append("CORPORATE_TOWERS devrait avoir 'security_turrets' dans ses dangers")
	
	return {
		"passed": passed,
		"message": "OK" if passed else "; ".join(messages)
	}


# ==============================================================================
# TEST: Réponse de la police
# ==============================================================================

func test_police_response() -> Dictionary:
	var passed := true
	var messages := []
	
	# Pas de police au Sol Mort
	if WorldLayerTypes.has_police_response(WorldLayerTypes.LayerType.DEAD_GROUND):
		passed = false
		messages.append("DEAD_GROUND ne devrait pas avoir de réponse police")
	
	# Pas de police au Sous-Réseau
	if WorldLayerTypes.has_police_response(WorldLayerTypes.LayerType.SUBNETWORK):
		passed = false
		messages.append("SUBNETWORK ne devrait pas avoir de réponse police")
	
	# Police dans la Ville Vivante
	if not WorldLayerTypes.has_police_response(WorldLayerTypes.LayerType.LIVING_CITY):
		passed = false
		messages.append("LIVING_CITY devrait avoir une réponse police")
	
	# Sécurité dans les Tours
	if not WorldLayerTypes.has_police_response(WorldLayerTypes.LayerType.CORPORATE_TOWERS):
		passed = false
		messages.append("CORPORATE_TOWERS devrait avoir une réponse sécurité")
	
	return {
		"passed": passed,
		"message": "OK" if passed else "; ".join(messages)
	}


# ==============================================================================
# EXÉCUTION
# ==============================================================================

func _ready() -> void:
	# Exécuter les tests automatiquement si lancé directement
	var results := run_all_tests()
	
	print("=" .repeat(60))
	print("TESTS WORLD LAYERS - Résultats")
	print("=" .repeat(60))
	
	for test in results.tests:
		var status := "✓ PASS" if test.passed else "✗ FAIL"
		print("%s: %s" % [status, test.name])
		if not test.passed:
			print("   → %s" % test.message)
	
	print("-" .repeat(60))
	print("Total: %d passés, %d échoués" % [results.passed, results.failed])
	print("=" .repeat(60))
