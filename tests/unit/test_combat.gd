# ==============================================================================
# test_combat.gd - Tests unitaires pour le système de combat
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# TESTS
# ==============================================================================

func test_health_component_exists() -> Dictionary:
	"""Vérifie que le script HealthComponent existe."""
	var exists := ResourceLoader.exists("res://scripts/components/HealthComponent.gd")
	return runner.assert_true(exists, "HealthComponent.gd n'existe pas")


func test_combat_manager_exists() -> Dictionary:
	"""Vérifie que le script CombatManager existe."""
	var exists := ResourceLoader.exists("res://scripts/player/CombatManager.gd")
	return runner.assert_true(exists, "CombatManager.gd n'existe pas")


func test_health_component_methods() -> Dictionary:
	"""Vérifie les méthodes du HealthComponent."""
	var script = load("res://scripts/components/HealthComponent.gd")
	if not script:
		return {"passed": false, "message": "Impossible de charger HealthComponent.gd"}
	
	var instance = script.new()
	
	var methods := ["take_damage", "heal", "get_health_percentage"]
	for method in methods:
		if not instance.has_method(method):
			return {"passed": false, "message": "Méthode manquante: " + method}
	
	return {"passed": true}


func test_combat_manager_methods() -> Dictionary:
	"""Vérifie les méthodes du CombatManager."""
	var script = load("res://scripts/player/CombatManager.gd")
	if not script:
		return {"passed": false, "message": "Impossible de charger CombatManager.gd"}
	
	var instance = script.new()
	
	if not instance.has_method("request_attack"):
		return {"passed": false, "message": "Méthode request_attack manquante"}
	
	return {"passed": true}


func test_enemy_script_exists() -> Dictionary:
	"""Vérifie que le script Enemy existe."""
	var exists := ResourceLoader.exists("res://scripts/enemies/EnemyBase.gd")
	return runner.assert_true(exists, "EnemyBase.gd n'existe pas")


func test_impact_effects_exists() -> Dictionary:
	"""Vérifie que le script ImpactEffects existe."""
	var exists := ResourceLoader.exists("res://scripts/effects/ImpactEffects.gd")
	return runner.assert_true(exists, "ImpactEffects.gd n'existe pas")
