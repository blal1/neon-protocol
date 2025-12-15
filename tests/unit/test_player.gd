# ==============================================================================
# test_player.gd - Tests unitaires pour le joueur
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# TESTS
# ==============================================================================

func test_player_scene_exists() -> Dictionary:
	"""Vérifie que la scène Player existe."""
	var exists := ResourceLoader.exists("res://scenes/player/Player.tscn")
	return runner.assert_true(exists, "Player.tscn n'existe pas")


func test_player_script_exists() -> Dictionary:
	"""Vérifie que le script Player existe."""
	var exists := ResourceLoader.exists("res://scripts/player/Player.gd")
	return runner.assert_true(exists, "Player.gd n'existe pas")


func test_player_can_instantiate() -> Dictionary:
	"""Vérifie que le Player peut être instancié."""
	var scene = load("res://scenes/player/Player.tscn")
	if not scene:
		return {"passed": false, "message": "Impossible de charger Player.tscn"}
	
	var player = scene.instantiate()
	var valid := player != null
	if player:
		player.queue_free()
	return runner.assert_true(valid, "Impossible d'instancier Player")


func test_player_has_required_methods() -> Dictionary:
	"""Vérifie les méthodes publiques du Player."""
	var scene = load("res://scenes/player/Player.tscn")
	var player = scene.instantiate()
	
	var methods := [
		"set_movement_input",
		"request_dash",
		"request_interact",
		"request_attack",
		"is_moving",
		"is_alive"
	]
	
	for method in methods:
		if not player.has_method(method):
			player.queue_free()
			return {"passed": false, "message": "Méthode manquante: " + method}
	
	player.queue_free()
	return {"passed": true}


func test_player_in_group() -> Dictionary:
	"""Vérifie que le Player est dans le groupe 'player'."""
	var scene = load("res://scenes/player/Player.tscn")
	var player = scene.instantiate()
	
	# Ajouter temporairement à l'arbre pour déclencher _ready
	Engine.get_main_loop().root.add_child(player)
	await Engine.get_main_loop().process_frame
	
	var in_group := player.is_in_group("player")
	player.queue_free()
	
	return runner.assert_true(in_group, "Player n'est pas dans le groupe 'player'")


func test_player_has_health_component() -> Dictionary:
	"""Vérifie que le Player a un HealthComponent."""
	var scene = load("res://scenes/player/Player.tscn")
	var player = scene.instantiate()
	
	var health = player.get_node_or_null("HealthComponent")
	player.queue_free()
	
	return runner.assert_not_null(health, "HealthComponent manquant")


func test_player_has_combat_manager() -> Dictionary:
	"""Vérifie que le Player a un CombatManager."""
	var scene = load("res://scenes/player/Player.tscn")
	var player = scene.instantiate()
	
	var combat = player.get_node_or_null("CombatManager")
	player.queue_free()
	
	return runner.assert_not_null(combat, "CombatManager manquant")


func test_player_has_camera() -> Dictionary:
	"""Vérifie que le Player a une caméra."""
	var scene = load("res://scenes/player/Player.tscn")
	var player = scene.instantiate()
	
	var camera_pivot = player.get_node_or_null("CameraPivot")
	var camera = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	player.queue_free()
	
	if not camera_pivot:
		return {"passed": false, "message": "CameraPivot manquant"}
	if not camera:
		return {"passed": false, "message": "Camera3D manquante"}
	
	return {"passed": true}
