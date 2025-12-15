# ==============================================================================
# TestRunner.gd - Framework de tests pour Godot 4
# Neon Protocol - Test Suite
# ==============================================================================
# Usage: Lancez tests/TestRunner.tscn pour exécuter tous les tests
# ==============================================================================

extends Control

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal all_tests_completed(passed: int, failed: int)
signal test_completed(test_name: String, passed: bool, message: String)

# ==============================================================================
# VARIABLES
# ==============================================================================
var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test_class: String = ""
var _test_results: Array[Dictionary] = []

# Références UI
@onready var results_label: RichTextLabel = $VBox/ResultsPanel/Results
@onready var status_label: Label = $VBox/StatusBar/Status
@onready var progress_bar: ProgressBar = $VBox/StatusBar/Progress
@onready var run_all_button: Button = $VBox/ButtonBar/RunAllButton
@onready var run_unit_button: Button = $VBox/ButtonBar/RunUnitButton
@onready var run_integration_button: Button = $VBox/ButtonBar/RunIntegrationButton

# ==============================================================================
# CLASSES DE TEST (à charger dynamiquement)
# ==============================================================================
var _unit_tests: Array[String] = [
	"res://tests/unit/test_player.gd",
	"res://tests/unit/test_inventory.gd",
	"res://tests/unit/test_skill_tree.gd",
	"res://tests/unit/test_combat.gd",
	"res://tests/unit/test_accessibility.gd"
]

var _integration_tests: Array[String] = [
	"res://tests/integration/test_main_menu.gd",
	"res://tests/integration/test_game_scene.gd"
]

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_log("[color=cyan]═══════════════════════════════════════[/color]")
	_log("[color=cyan]   NEON PROTOCOL - TEST SUITE[/color]")
	_log("[color=cyan]═══════════════════════════════════════[/color]")
	_log("")
	_update_status("Prêt. Cliquez sur un bouton pour lancer les tests.")


# ==============================================================================
# BOUTONS
# ==============================================================================

func _on_run_all_pressed() -> void:
	await _run_tests(_unit_tests + _integration_tests)


func _on_run_unit_pressed() -> void:
	await _run_tests(_unit_tests)


func _on_run_integration_pressed() -> void:
	await _run_tests(_integration_tests)


func _on_quit_pressed() -> void:
	get_tree().quit()


# ==============================================================================
# EXÉCUTION DES TESTS
# ==============================================================================

func _run_tests(test_paths: Array[String]) -> void:
	_tests_passed = 0
	_tests_failed = 0
	_test_results.clear()
	
	_log("")
	_log("[color=yellow]▶ Démarrage des tests...[/color]")
	_log("")
	
	var total_tests := test_paths.size()
	progress_bar.max_value = total_tests
	progress_bar.value = 0
	
	for i in range(test_paths.size()):
		var path := test_paths[i]
		_update_status("Exécution: " + path.get_file())
		progress_bar.value = i
		
		if not ResourceLoader.exists(path):
			_log("[color=orange]⚠ Fichier non trouvé: " + path + "[/color]")
			continue
		
		var script: GDScript = load(path)
		if not script:
			_log("[color=red]✗ Impossible de charger: " + path + "[/color]")
			_tests_failed += 1
			continue
		
		var test_instance = script.new()
		if test_instance.has_method("set_runner"):
			test_instance.set_runner(self)
		
		_current_test_class = path.get_file().replace(".gd", "")
		_log("[color=white]━━━ " + _current_test_class + " ━━━[/color]")
		
		# Exécuter toutes les méthodes qui commencent par "test_"
		var methods := script.get_script_method_list()
		for method in methods:
			var method_name: String = method["name"]
			if method_name.begins_with("test_"):
				await _run_single_test(test_instance, method_name)
		
		# Nettoyer
		if test_instance.has_method("cleanup"):
			test_instance.cleanup()
		
		await get_tree().process_frame
	
	progress_bar.value = total_tests
	_print_summary()


func _run_single_test(instance: Object, method_name: String) -> void:
	var full_name := _current_test_class + "." + method_name
	
	# Setup si disponible
	if instance.has_method("setup"):
		instance.setup()
	
	# Exécuter le test
	var result := {"name": full_name, "passed": true, "message": ""}
	
	# Appel du test avec gestion d'erreur
	if instance.has_method(method_name):
		var test_result = instance.call(method_name)
		if test_result is Dictionary:
			result = test_result
			result["name"] = full_name
	
	# Enregistrer le résultat
	_test_results.append(result)
	
	if result["passed"]:
		_tests_passed += 1
		_log("[color=green]  ✓ " + method_name + "[/color]")
	else:
		_tests_failed += 1
		_log("[color=red]  ✗ " + method_name + ": " + result.get("message", "Échec") + "[/color]")
	
	test_completed.emit(full_name, result["passed"], result.get("message", ""))


func _print_summary() -> void:
	_log("")
	_log("[color=cyan]═══════════════════════════════════════[/color]")
	_log("[color=cyan]   RÉSUMÉ DES TESTS[/color]")
	_log("[color=cyan]═══════════════════════════════════════[/color]")
	
	var total := _tests_passed + _tests_failed
	var pass_rate := 0.0
	if total > 0:
		pass_rate = float(_tests_passed) / float(total) * 100.0
	
	_log("[color=green]  ✓ Réussis: " + str(_tests_passed) + "[/color]")
	_log("[color=red]  ✗ Échoués: " + str(_tests_failed) + "[/color]")
	_log("  Total: " + str(total) + " (" + str(int(pass_rate)) + "%)")
	_log("")
	
	if _tests_failed == 0:
		_log("[color=green]🎉 TOUS LES TESTS SONT PASSÉS ![/color]")
		_update_status("✓ Tous les tests réussis!")
	else:
		_log("[color=red]⚠ CERTAINS TESTS ONT ÉCHOUÉ[/color]")
		_update_status("✗ " + str(_tests_failed) + " test(s) échoué(s)")
	
	all_tests_completed.emit(_tests_passed, _tests_failed)


# ==============================================================================
# ASSERTIONS (utilisées par les tests)
# ==============================================================================

func assert_true(condition: bool, message: String = "") -> Dictionary:
	if condition:
		return {"passed": true}
	return {"passed": false, "message": message if message else "Expected true, got false"}


func assert_false(condition: bool, message: String = "") -> Dictionary:
	if not condition:
		return {"passed": true}
	return {"passed": false, "message": message if message else "Expected false, got true"}


func assert_equals(expected, actual, message: String = "") -> Dictionary:
	if expected == actual:
		return {"passed": true}
	var msg := message if message else "Expected " + str(expected) + ", got " + str(actual)
	return {"passed": false, "message": msg}


func assert_not_null(value, message: String = "") -> Dictionary:
	if value != null:
		return {"passed": true}
	return {"passed": false, "message": message if message else "Expected non-null value"}


func assert_null(value, message: String = "") -> Dictionary:
	if value == null:
		return {"passed": true}
	return {"passed": false, "message": message if message else "Expected null value"}


func assert_greater(value: float, threshold: float, message: String = "") -> Dictionary:
	if value > threshold:
		return {"passed": true}
	var msg := message if message else str(value) + " is not greater than " + str(threshold)
	return {"passed": false, "message": msg}


func assert_has_method(obj: Object, method_name: String) -> Dictionary:
	if obj and obj.has_method(method_name):
		return {"passed": true}
	return {"passed": false, "message": "Object doesn't have method: " + method_name}


func assert_in_group(node: Node, group_name: String) -> Dictionary:
	if node and node.is_in_group(group_name):
		return {"passed": true}
	return {"passed": false, "message": "Node is not in group: " + group_name}


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _log(text: String) -> void:
	if results_label:
		results_label.append_text(text + "\n")
	print(text.replace("[color=", "").replace("[/color]", "").replace("]", ""))


func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text
