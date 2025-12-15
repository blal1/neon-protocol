# ==============================================================================
# test_main_menu.gd - Tests d'intégration pour le menu principal
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# TESTS
# ==============================================================================

func test_main_menu_scene_exists() -> Dictionary:
	"""Vérifie que MainMenu.tscn existe."""
	var exists := ResourceLoader.exists("res://scenes/main/MainMenu.tscn")
	return runner.assert_true(exists, "MainMenu.tscn n'existe pas")


func test_main_menu_script_exists() -> Dictionary:
	"""Vérifie que le script MainMenu existe."""
	var exists := ResourceLoader.exists("res://scripts/ui/MainMenu.gd")
	return runner.assert_true(exists, "MainMenu.gd n'existe pas")


func test_main_menu_can_load() -> Dictionary:
	"""Vérifie que MainMenu peut être chargé."""
	var scene = load("res://scenes/main/MainMenu.tscn")
	return runner.assert_not_null(scene, "Impossible de charger MainMenu.tscn")


func test_main_menu_has_play_button() -> Dictionary:
	"""Vérifie que le bouton JOUER existe."""
	var scene = load("res://scenes/main/MainMenu.tscn")
	var menu = scene.instantiate()
	
	var play_button = menu.get_node_or_null("VBox/PlayButton")
	menu.queue_free()
	
	return runner.assert_not_null(play_button, "PlayButton non trouvé")


func test_main_menu_has_options_button() -> Dictionary:
	"""Vérifie que le bouton OPTIONS existe."""
	var scene = load("res://scenes/main/MainMenu.tscn")
	var menu = scene.instantiate()
	
	var options_button = menu.get_node_or_null("VBox/OptionsButton")
	menu.queue_free()
	
	return runner.assert_not_null(options_button, "OptionsButton non trouvé")


func test_main_menu_has_accessibility_button() -> Dictionary:
	"""Vérifie que le bouton ACCESSIBILITÉ existe."""
	var scene = load("res://scenes/main/MainMenu.tscn")
	var menu = scene.instantiate()
	
	var button = menu.get_node_or_null("VBox/AccessibilityButton")
	menu.queue_free()
	
	return runner.assert_not_null(button, "AccessibilityButton non trouvé")


func test_main_menu_has_quit_button() -> Dictionary:
	"""Vérifie que le bouton QUITTER existe."""
	var scene = load("res://scenes/main/MainMenu.tscn")
	var menu = scene.instantiate()
	
	var quit_button = menu.get_node_or_null("VBox/QuitButton")
	menu.queue_free()
	
	return runner.assert_not_null(quit_button, "QuitButton non trouvé")


func test_main_menu_has_script_attached() -> Dictionary:
	"""Vérifie que le script est attaché au menu."""
	var scene = load("res://scenes/main/MainMenu.tscn")
	var menu = scene.instantiate()
	
	var has_script := menu.get_script() != null
	menu.queue_free()
	
	return runner.assert_true(has_script, "Aucun script attaché au MainMenu")


func test_options_menu_scene_exists() -> Dictionary:
	"""Vérifie que OptionsMenu.tscn existe."""
	var exists := ResourceLoader.exists("res://scenes/ui/OptionsMenu.tscn")
	return runner.assert_true(exists, "OptionsMenu.tscn n'existe pas")
