# ==============================================================================
# test_accessibility.gd - Tests unitaires pour l'accessibilité
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# TESTS
# ==============================================================================

func test_accessibility_manager_exists() -> Dictionary:
	"""Vérifie que AccessibilityManager est un autoload."""
	var manager = Engine.get_main_loop().root.get_node_or_null("/root/AccessibilityManager")
	return runner.assert_not_null(manager, "AccessibilityManager autoload non trouvé")


func test_blind_accessibility_manager_exists() -> Dictionary:
	"""Vérifie que BlindAccessibilityManager est un autoload."""
	var manager = Engine.get_main_loop().root.get_node_or_null("/root/BlindAccessibilityManager")
	return runner.assert_not_null(manager, "BlindAccessibilityManager autoload non trouvé")


func test_tts_manager_exists() -> Dictionary:
	"""Vérifie que TTSManager est un autoload."""
	var tts = Engine.get_main_loop().root.get_node_or_null("/root/TTSManager")
	return runner.assert_not_null(tts, "TTSManager autoload non trouvé")


func test_tts_manager_has_speak_method() -> Dictionary:
	"""Vérifie que TTSManager a la méthode speak."""
	var tts = Engine.get_main_loop().root.get_node_or_null("/root/TTSManager")
	if not tts:
		return {"passed": false, "message": "TTSManager non trouvé"}
	
	return runner.assert_has_method(tts, "speak")


func test_haptic_feedback_exists() -> Dictionary:
	"""Vérifie que HapticFeedback est un autoload."""
	var haptic = Engine.get_main_loop().root.get_node_or_null("/root/HapticFeedback")
	return runner.assert_not_null(haptic, "HapticFeedback autoload non trouvé")


func test_audio_compass_script_exists() -> Dictionary:
	"""Vérifie que le script AudioCompass existe."""
	var exists := ResourceLoader.exists("res://scripts/audio/AudioCompass.gd")
	return runner.assert_true(exists, "AudioCompass.gd n'existe pas")


func test_colorblind_shader_exists() -> Dictionary:
	"""Vérifie que le shader daltonien existe."""
	var exists := ResourceLoader.exists("res://shaders/colorblind_filter.gdshader")
	return runner.assert_true(exists, "colorblind_filter.gdshader n'existe pas")


func test_accessibility_script_exists() -> Dictionary:
	"""Vérifie que le script AccessibilityManager existe."""
	var exists := ResourceLoader.exists("res://scripts/accessibility/AccessibilityManager.gd")
	return runner.assert_true(exists, "AccessibilityManager.gd n'existe pas")
