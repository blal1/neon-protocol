# ==============================================================================
# test_combat_advanced.gd - Tests pour HitboxManager et TacticalCombatSystem
# ==============================================================================

extends RefCounted

var runner: Node = null

func set_runner(r: Node) -> void:
	runner = r

# ==============================================================================
# HITBOXMANAGER
# ==============================================================================

func test_hitbox_manager_exists() -> Dictionary:
	"""Vérifie que le script HitboxManager existe."""
	var exists := ResourceLoader.exists("res://scripts/combat/HitboxManager.gd")
	return runner.assert_true(exists, "HitboxManager.gd n'existe pas")


func test_hitbox_manager_methods() -> Dictionary:
	"""Vérifie les méthodes publiques du HitboxManager."""
	var script = load("res://scripts/combat/HitboxManager.gd")
	if not script:
		return {"passed": false, "message": "Impossible de charger HitboxManager.gd"}

	var instance = script.new()
	var methods := ["create_hitbox", "create_hurtbox", "remove_hurtbox", "grant_iframes",
		"clear_iframes", "get_active_hitbox_count", "get_registered_hurtbox_count", "clear_all_hitboxes"]
	for method in methods:
		if not instance.has_method(method):
			return {"passed": false, "message": "Méthode manquante: " + method}

	return {"passed": true}


func test_hurtbox_registration() -> Dictionary:
	"""Crée une hurtbox et vérifie son enregistrement/suppression."""
	var script = load("res://scripts/combat/HitboxManager.gd")
	var hitbox_manager: HitboxManager = script.new()
	runner.add_child(hitbox_manager)

	var dummy := Node3D.new()
	runner.add_child(dummy)

	var shape := CapsuleShape3D.new()
	hitbox_manager.create_hurtbox(dummy, shape)

	var result := runner.assert_equals(1, hitbox_manager.get_registered_hurtbox_count(),
		"La hurtbox n'a pas été enregistrée")

	hitbox_manager.remove_hurtbox(dummy)
	if result["passed"]:
		result = runner.assert_equals(0, hitbox_manager.get_registered_hurtbox_count(),
			"La hurtbox n'a pas été désenregistrée")

	dummy.queue_free()
	hitbox_manager.queue_free()
	return result


func test_hitbox_creation_and_tracking() -> Dictionary:
	"""Crée une hitbox temporaire et vérifie le compteur actif."""
	var script = load("res://scripts/combat/HitboxManager.gd")
	var hitbox_manager: HitboxManager = script.new()
	runner.add_child(hitbox_manager)

	var attacker := Node3D.new()
	runner.add_child(attacker)

	var shape := SphereShape3D.new()
	shape.radius = 1.0
	hitbox_manager.create_hitbox(attacker, shape, {"damage": 10}, 5.0)

	var result := runner.assert_equals(1, hitbox_manager.get_active_hitbox_count(),
		"La hitbox n'a pas été créée")

	hitbox_manager.clear_all_hitboxes()
	if result["passed"]:
		result = runner.assert_equals(0, hitbox_manager.get_active_hitbox_count(),
			"clear_all_hitboxes() n'a pas vidé les hitboxes actives")

	attacker.queue_free()
	hitbox_manager.queue_free()
	return result


func test_iframes_lifecycle() -> Dictionary:
	"""Vérifie l'octroi et l'expiration des i-frames."""
	var script = load("res://scripts/combat/HitboxManager.gd")
	var hitbox_manager: HitboxManager = script.new()
	runner.add_child(hitbox_manager)

	var entity := Node3D.new()
	runner.add_child(entity)

	hitbox_manager.grant_iframes(entity, 10.0)
	var has_iframes_active: bool = hitbox_manager.call("_has_iframes", entity)

	hitbox_manager.grant_iframes(entity, 0.0)
	var has_iframes_expired: bool = hitbox_manager.call("_has_iframes", entity)

	entity.queue_free()
	hitbox_manager.queue_free()

	if not has_iframes_active:
		return {"passed": false, "message": "I-frames non actives avec une durée de 10s"}
	if has_iframes_expired:
		return {"passed": false, "message": "I-frames toujours actives avec une durée de 0s"}

	return {"passed": true}


# ==============================================================================
# TACTICALCOMBATSYSTEM
# ==============================================================================

func test_tactical_combat_system_exists() -> Dictionary:
	"""Vérifie que le script TacticalCombatSystem existe."""
	var exists := ResourceLoader.exists("res://scripts/combat/TacticalCombatSystem.gd")
	return runner.assert_true(exists, "TacticalCombatSystem.gd n'existe pas")


func test_tactical_combat_methods() -> Dictionary:
	"""Vérifie les méthodes publiques du TacticalCombatSystem."""
	var script = load("res://scripts/combat/TacticalCombatSystem.gd")
	if not script:
		return {"passed": false, "message": "Impossible de charger TacticalCombatSystem.gd"}

	var instance = script.new()
	var methods := ["toggle_combat_mode", "enter_tactical_mode", "exit_tactical_mode",
		"get_current_accuracy", "set_stress_level", "start_target_analysis", "update_target_analysis"]
	for method in methods:
		if not instance.has_method(method):
			return {"passed": false, "message": "Méthode manquante: " + method}

	return {"passed": true}


func test_tactical_mode_toggle_time_scale() -> Dictionary:
	"""Vérifie que le mode tactique modifie Engine.time_scale et le restaure à la sortie."""
	var script = load("res://scripts/combat/TacticalCombatSystem.gd")
	var tactical: TacticalCombatSystem = script.new()
	runner.add_child(tactical)

	var entered := tactical.enter_tactical_mode()
	var time_scale_in_tactical := Engine.time_scale
	var mode_in_tactical := tactical.current_mode

	tactical.exit_tactical_mode()
	var time_scale_after_exit := Engine.time_scale
	var mode_after_exit := tactical.current_mode

	tactical.queue_free()
	Engine.time_scale = 1.0

	if not entered:
		return {"passed": false, "message": "enter_tactical_mode() a échoué"}
	if mode_in_tactical != TacticalCombatSystem.CombatMode.TACTICAL:
		return {"passed": false, "message": "Mode non passé à TACTICAL"}
	if not is_equal_approx(time_scale_in_tactical, tactical.time_scale_tactical):
		return {"passed": false, "message": "Engine.time_scale non appliqué en mode tactique"}
	if mode_after_exit != TacticalCombatSystem.CombatMode.REFLEX:
		return {"passed": false, "message": "Mode non revenu à REFLEX après exit"}
	if not is_equal_approx(time_scale_after_exit, 1.0):
		return {"passed": false, "message": "Engine.time_scale non restauré à 1.0"}

	return {"passed": true}


func test_tactical_resource_drain() -> Dictionary:
	"""Vérifie le drain de la ressource tactique en mode tactique."""
	var script = load("res://scripts/combat/TacticalCombatSystem.gd")
	var tactical: TacticalCombatSystem = script.new()
	runner.add_child(tactical)

	tactical.enter_tactical_mode()
	var resource_before := tactical.tactical_resource
	tactical.call("_update_tactical_mode", 1.0)
	var resource_after := tactical.tactical_resource

	tactical.exit_tactical_mode()
	tactical.queue_free()
	Engine.time_scale = 1.0

	return runner.assert_true(resource_after < resource_before,
		"La ressource tactique n'a pas diminué après _update_tactical_mode()")


func test_accuracy_bonus_in_tactical_mode() -> Dictionary:
	"""Vérifie que le mode tactique augmente la précision de visée."""
	var script = load("res://scripts/combat/TacticalCombatSystem.gd")
	var tactical: TacticalCombatSystem = script.new()
	runner.add_child(tactical)

	var accuracy_reflex := tactical.get_current_accuracy()
	tactical.enter_tactical_mode()
	var accuracy_tactical := tactical.get_current_accuracy()

	tactical.exit_tactical_mode()
	tactical.queue_free()
	Engine.time_scale = 1.0

	return runner.assert_true(accuracy_tactical > accuracy_reflex,
		"La précision n'augmente pas en mode tactique")
