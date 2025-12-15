# ==============================================================================
# TacticalCombatSystem.gd - Combat Réflexe / Tactique
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Mode Réflexe: temps réel, imprécis, stressant
# Mode Tactique: temps ralenti, analyse, coûte ressource
# ==============================================================================

extends Node
class_name TacticalCombatSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal mode_changed(new_mode: int)
signal tactical_resource_changed(current: float, maximum: float)
signal tactical_resource_depleted()
signal target_analyzed(target: Node3D, analysis: Dictionary)
signal augmented_enemy_detected(enemy: Node3D, augment_level: int)
signal aim_assist_updated(accuracy_modifier: float)

# ==============================================================================
# ENUMS
# ==============================================================================

enum CombatMode {
	REFLEX,     ## Temps réel, stressant
	TACTICAL    ## Temps ralenti, précis
}

enum TargetType {
	ORGANIC,          ## Humain non-augmenté
	LIGHT_AUGMENTED,  ## Quelques implants
	HEAVY_AUGMENTED,  ## Très augmenté
	FULL_CYBORG,      ## Presque machine
	DRONE,            ## Robot/drone
	UNKNOWN           ## Brouillé/inconnu
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Mode Tactique")
@export var tactical_max_resource: float = 100.0
@export var tactical_drain_rate: float = 20.0  ## Par seconde en mode tactique
@export var tactical_regen_rate: float = 5.0   ## Par seconde hors combat
@export var time_scale_tactical: float = 0.25  ## 25% vitesse
@export var cooldown_after_depletion: float = 5.0

@export_group("Mode Réflexe")
@export var base_accuracy: float = 0.6  ## 60% précision de base
@export var stress_accuracy_penalty: float = 0.2
@export var movement_accuracy_penalty: float = 0.15

@export_group("Analyse")
@export var analysis_time: float = 1.5  ## Temps pour analyser une cible
@export var analysis_range: float = 30.0

# ==============================================================================
# VARIABLES
# ==============================================================================

var current_mode: CombatMode = CombatMode.REFLEX
var tactical_resource: float = 100.0
var _is_in_combat: bool = false
var _cooldown_timer: float = 0.0
var _analysis_progress: Dictionary = {}  ## target_id -> progress
var _analyzed_targets: Dictionary = {}   ## target_id -> analysis_data
var _current_stress: float = 0.0
var _player_augment_level: int = 0

# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	match current_mode:
		CombatMode.TACTICAL:
			_update_tactical_mode(delta)
		CombatMode.REFLEX:
			_update_reflex_mode(delta)
	
	# Cooldown après épuisement
	if _cooldown_timer > 0:
		_cooldown_timer -= delta


func _update_tactical_mode(delta: float) -> void:
	"""Met à jour le mode tactique."""
	# Drainer la ressource
	tactical_resource -= tactical_drain_rate * delta
	tactical_resource_changed.emit(tactical_resource, tactical_max_resource)
	
	if tactical_resource <= 0:
		tactical_resource = 0
		_exit_tactical_mode()
		tactical_resource_depleted.emit()
		_cooldown_timer = cooldown_after_depletion


func _update_reflex_mode(delta: float) -> void:
	"""Met à jour le mode réflexe."""
	# Régénérer la ressource hors combat
	if not _is_in_combat and tactical_resource < tactical_max_resource:
		tactical_resource = minf(tactical_max_resource, tactical_resource + tactical_regen_rate * delta)
		tactical_resource_changed.emit(tactical_resource, tactical_max_resource)


# ==============================================================================
# CHANGEMENT DE MODE
# ==============================================================================

func toggle_combat_mode() -> bool:
	"""Bascule entre les modes de combat."""
	if current_mode == CombatMode.REFLEX:
		return enter_tactical_mode()
	else:
		exit_tactical_mode()
		return true


func enter_tactical_mode() -> bool:
	"""Entre en mode tactique."""
	if tactical_resource <= 0:
		return false
	
	if _cooldown_timer > 0:
		return false
	
	current_mode = CombatMode.TACTICAL
	Engine.time_scale = time_scale_tactical
	mode_changed.emit(CombatMode.TACTICAL)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Mode tactique activé")
	
	return true


func exit_tactical_mode() -> void:
	"""Sort du mode tactique."""
	_exit_tactical_mode()


func _exit_tactical_mode() -> void:
	"""Sort du mode tactique (interne)."""
	current_mode = CombatMode.REFLEX
	Engine.time_scale = 1.0
	mode_changed.emit(CombatMode.REFLEX)


# ==============================================================================
# PRÉCISION & VISÉE
# ==============================================================================

func get_current_accuracy(is_moving: bool = false, target: Node3D = null) -> float:
	"""Calcule la précision actuelle."""
	var accuracy := base_accuracy
	
	# Mode tactique = bonus de précision
	if current_mode == CombatMode.TACTICAL:
		accuracy += 0.3  # +30% en mode tactique
	
	# Pénalités
	if is_moving:
		accuracy -= movement_accuracy_penalty
	
	accuracy -= _current_stress * stress_accuracy_penalty
	
	# Cibles augmentées peuvent brouiller
	if target:
		var target_type: int = _get_target_type(target)
		if target_type >= TargetType.HEAVY_AUGMENTED:
			accuracy -= 0.15 * (target_type - TargetType.LIGHT_AUGMENTED)
	
	aim_assist_updated.emit(accuracy)
	return clampf(accuracy, 0.1, 0.95)


func set_stress_level(stress: float) -> void:
	"""Définit le niveau de stress (0-1)."""
	_current_stress = clampf(stress, 0.0, 1.0)


func _get_target_type(target: Node3D) -> TargetType:
	"""Détermine le type de cible."""
	if target.has_meta("target_type"):
		return target.get_meta("target_type")
	
	if target.has_meta("augment_level"):
		var level: int = target.get_meta("augment_level")
		if level <= 0:
			return TargetType.ORGANIC
		elif level <= 30:
			return TargetType.LIGHT_AUGMENTED
		elif level <= 70:
			return TargetType.HEAVY_AUGMENTED
		else:
			return TargetType.FULL_CYBORG
	
	if target.is_in_group("drone"):
		return TargetType.DRONE
	
	return TargetType.UNKNOWN


# ==============================================================================
# ANALYSE DE CIBLES
# ==============================================================================

func start_target_analysis(target: Node3D) -> void:
	"""Démarre l'analyse d'une cible."""
	if current_mode != CombatMode.TACTICAL:
		return
	
	var target_id := target.get_instance_id()
	if _analyzed_targets.has(target_id):
		return  # Déjà analysée
	
	_analysis_progress[target_id] = 0.0


func update_target_analysis(target: Node3D, delta: float) -> float:
	"""Met à jour l'analyse d'une cible. Retourne le progrès (0-1)."""
	var target_id := target.get_instance_id()
	
	if not _analysis_progress.has(target_id):
		return 0.0
	
	_analysis_progress[target_id] += delta / analysis_time
	
	if _analysis_progress[target_id] >= 1.0:
		_complete_analysis(target)
		return 1.0
	
	return _analysis_progress[target_id]


func _complete_analysis(target: Node3D) -> void:
	"""Complète l'analyse d'une cible."""
	var target_id := target.get_instance_id()
	_analysis_progress.erase(target_id)
	
	var analysis := _generate_target_analysis(target)
	_analyzed_targets[target_id] = analysis
	
	target_analyzed.emit(target, analysis)


func _generate_target_analysis(target: Node3D) -> Dictionary:
	"""Génère les données d'analyse d'une cible."""
	var target_type := _get_target_type(target)
	
	var analysis := {
		"type": TargetType.keys()[target_type],
		"health_percent": 1.0,
		"armor_rating": 0,
		"implants": [],
		"weaknesses": [],
		"mental_state": "normal",
		"unpredictable": false
	}
	
	# Récupérer les vraies données si disponibles
	if target.has_method("get_health_percent"):
		analysis.health_percent = target.get_health_percent()
	
	if target.has_meta("armor"):
		analysis.armor_rating = target.get_meta("armor")
	
	# Implants visibles
	if target.has_meta("visible_implants"):
		analysis.implants = target.get_meta("visible_implants")
	
	# État mental
	if target.has_meta("mental_state"):
		analysis.mental_state = target.get_meta("mental_state")
	
	# Ennemis très augmentés = imprévisibles
	if target_type >= TargetType.HEAVY_AUGMENTED:
		analysis.unpredictable = true
		if target_type == TargetType.FULL_CYBORG:
			analysis.weaknesses.append("EMP")
		
		augmented_enemy_detected.emit(target, target_type)
	
	# Faiblesses basées sur le type
	match target_type:
		TargetType.ORGANIC:
			analysis.weaknesses = ["tête", "organes vitaux"]
		TargetType.LIGHT_AUGMENTED:
			analysis.weaknesses = ["organes naturels", "jonctions implants"]
		TargetType.HEAVY_AUGMENTED:
			analysis.weaknesses = ["processeur central", "alimentation"]
		TargetType.DRONE:
			analysis.weaknesses = ["antenne", "batterie", "capteurs"]
	
	return analysis


func get_target_analysis(target: Node3D) -> Dictionary:
	"""Retourne l'analyse d'une cible (si disponible)."""
	var target_id := target.get_instance_id()
	return _analyzed_targets.get(target_id, {})


func is_target_analyzed(target: Node3D) -> bool:
	"""Vérifie si une cible est analysée."""
	return _analyzed_targets.has(target.get_instance_id())


# ==============================================================================
# ENNEMIS AUGMENTÉS IMPRÉVISIBLES
# ==============================================================================

func set_player_augment_level(level: int) -> void:
	"""Définit le niveau d'augmentation du joueur."""
	_player_augment_level = level


func should_spawn_augmented_enemy() -> bool:
	"""Détermine si un ennemi augmenté devrait spawn."""
	# Plus le joueur est augmenté, plus il rencontre d'ennemis augmentés
	var base_chance := 0.1  # 10% de base
	var augment_bonus := _player_augment_level / 100.0 * 0.5  # +50% max
	return randf() < (base_chance + augment_bonus)


func get_enemy_unpredictability(enemy: Node3D) -> Dictionary:
	"""Retourne les caractéristiques d'imprévisibilité d'un ennemi."""
	var target_type := _get_target_type(enemy)
	
	if target_type < TargetType.HEAVY_AUGMENTED:
		return {"level": 0, "effects": []}
	
	var unpredictability := {
		"level": target_type - TargetType.LIGHT_AUGMENTED,
		"effects": []
	}
	
	# Effets basés sur le niveau
	if unpredictability.level >= 1:
		unpredictability.effects.append("erratic_movement")  # Mouvements erratiques
	if unpredictability.level >= 2:
		unpredictability.effects.append("unknown_resistance")  # Résistances inconnues
	if unpredictability.level >= 3:
		unpredictability.effects.append("aim_jamming")  # Brouille la visée
	
	return unpredictability


# ==============================================================================
# COMBAT STATE
# ==============================================================================

func enter_combat() -> void:
	"""Entre en état de combat."""
	_is_in_combat = true
	_current_stress = 0.3  # Stress initial


func exit_combat() -> void:
	"""Sort de l'état de combat."""
	_is_in_combat = false
	_current_stress = 0.0
	
	# Forcer le retour au mode réflexe
	if current_mode == CombatMode.TACTICAL:
		_exit_tactical_mode()


func is_in_combat() -> bool:
	"""Vérifie si en combat."""
	return _is_in_combat


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_current_mode() -> CombatMode:
	"""Retourne le mode actuel."""
	return current_mode


func get_tactical_resource() -> float:
	"""Retourne la ressource tactique actuelle."""
	return tactical_resource


func get_tactical_resource_percent() -> float:
	"""Retourne le pourcentage de ressource tactique."""
	return tactical_resource / tactical_max_resource


func can_enter_tactical() -> bool:
	"""Vérifie si le mode tactique est disponible."""
	return tactical_resource > 0 and _cooldown_timer <= 0


func get_combat_summary() -> Dictionary:
	"""Retourne un résumé du système de combat."""
	return {
		"mode": CombatMode.keys()[current_mode],
		"tactical_resource": tactical_resource,
		"tactical_max": tactical_max_resource,
		"in_combat": _is_in_combat,
		"stress": _current_stress,
		"accuracy": get_current_accuracy(),
		"analyzed_targets": _analyzed_targets.size(),
		"can_tactical": can_enter_tactical()
	}
