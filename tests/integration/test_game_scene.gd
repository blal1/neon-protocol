# ==============================================================================
# test_game_scene.gd - Tests d'intégration pour la scène de jeu
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# TESTS
# ==============================================================================

func test_main_scene_exists() -> Dictionary:
	"""Vérifie que Main.tscn existe."""
	var exists := ResourceLoader.exists("res://scenes/main/Main.tscn")
	return runner.assert_true(exists, "Main.tscn n'existe pas")


func test_main_scene_can_load() -> Dictionary:
	"""Vérifie que Main.tscn peut être chargé."""
	var scene = load("res://scenes/main/Main.tscn")
	return runner.assert_not_null(scene, "Impossible de charger Main.tscn")


func test_main_scene_has_player() -> Dictionary:
	"""Vérifie que Main.tscn contient un Player."""
	var scene = load("res://scenes/main/Main.tscn")
	var main = scene.instantiate()
	
	var player = main.get_node_or_null("Player")
	main.queue_free()
	
	return runner.assert_not_null(player, "Player non trouvé dans Main.tscn")


func test_main_scene_has_environment() -> Dictionary:
	"""Vérifie que Main.tscn a un WorldEnvironment."""
	var scene = load("res://scenes/main/Main.tscn")
	var main = scene.instantiate()
	
	var env = main.get_node_or_null("WorldEnvironment")
	main.queue_free()
	
	return runner.assert_not_null(env, "WorldEnvironment non trouvé")


func test_main_scene_has_light() -> Dictionary:
	"""Vérifie que Main.tscn a un DirectionalLight3D."""
	var scene = load("res://scenes/main/Main.tscn")
	var main = scene.instantiate()
	
	var light = main.get_node_or_null("DirectionalLight3D")
	main.queue_free()
	
	return runner.assert_not_null(light, "DirectionalLight3D non trouvé")


func test_main_scene_has_floor() -> Dictionary:
	"""Vérifie que Main.tscn a un sol."""
	var scene = load("res://scenes/main/Main.tscn")
	var main = scene.instantiate()
	
	var floor = main.get_node_or_null("TestLevel/Floor")
	main.queue_free()
	
	return runner.assert_not_null(floor, "Floor non trouvé dans TestLevel")


func test_project_main_scene_configured() -> Dictionary:
	"""Vérifie que la scène principale est configurée dans project.godot."""
	var main_scene := ProjectSettings.get_setting("application/run/main_scene", "")
	var has_main := main_scene != ""
	return runner.assert_true(has_main, "Aucune scène principale configurée")


func test_all_autoloads_loaded() -> Dictionary:
	"""Vérifie que tous les autoloads critiques sont chargés."""
	var autoloads := [
		"/root/AccessibilityManager",
		"/root/TTSManager",
		"/root/SaveManager",
		"/root/InventoryManager",
		"/root/MusicManager"
	]
	
	for autoload in autoloads:
		var node = Engine.get_main_loop().root.get_node_or_null(autoload)
		if not node:
			return {"passed": false, "message": "Autoload manquant: " + autoload}
	
	return {"passed": true}


func test_game_hud_exists() -> Dictionary:
	"""Vérifie que GameHUD.tscn existe."""
	var exists := ResourceLoader.exists("res://scenes/ui/GameHUD.tscn")
	return runner.assert_true(exists, "GameHUD.tscn n'existe pas")


func test_pause_menu_exists() -> Dictionary:
	"""Vérifie que PauseMenu.tscn existe."""
	var exists := ResourceLoader.exists("res://scenes/ui/PauseMenu.tscn")
	return runner.assert_true(exists, "PauseMenu.tscn n'existe pas")
