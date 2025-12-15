# ==============================================================================
# HackingSystem.gd - Hacking Persistant avec Conséquences
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Réseau = architecture mentale, ICE agressifs, traces persistantes.
# Hacks ratés = marquage corpo, chasseurs, bugs HUD.
# ==============================================================================

extends Node
class_name HackingSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal hack_started(target: String, difficulty: int)
signal hack_progress_updated(progress: float)
signal hack_completed(success: bool, data: Dictionary)
signal hack_failed(reason: String, consequences: Array)
signal ice_encountered(ice_type: String, strength: int)
signal ice_defeated(ice_type: String)
signal ice_triggered_alarm()
signal digital_trace_left(target: String, trace_level: int)
signal hunter_spawned(hunter_data: Dictionary)
signal hud_corrupted(corruption_type: String)
signal corpo_alert_raised(corporation: String, alert_level: int)

# ==============================================================================
# ENUMS
# ==============================================================================

enum ICEType {
	NONE,
	FIREWALL,       ## Bloque l'accès
	TRACER,         ## Trace l'origine
	BLACK_ICE,      ## Attaque le hacker
	MAZE,           ## Désoriente
	HONEYPOT        ## Piège avec fausses données
}

enum HackType {
	DATA_THEFT,     ## Vol de données
	SYSTEM_CONTROL, ## Contrôle de système
	SURVEILLANCE,   ## Écoute/surveillance
	SABOTAGE,       ## Sabotage de système
	IDENTITY        ## Vol/modification d'identité
}

enum TraceLevel {
	NONE = 0,
	SUSPICIOUS = 1,   ## Activité suspecte détectée
	IDENTIFIED = 2,   ## Source localisée
	TARGETED = 3      ## Chasseurs déployés
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Difficulté")
@export var base_hack_time: float = 10.0
@export var difficulty_time_multiplier: float = 2.0
@export var failure_trace_chance: float = 0.7

@export_group("ICE")
@export var ice_damage_base: int = 10
@export var black_ice_damage_multiplier: float = 3.0

@export_group("Conséquences")
@export var trace_decay_time: float = 300.0  ## 5 minutes pour decay 1 niveau
@export var hunter_spawn_delay: float = 60.0

# ==============================================================================
# VARIABLES
# ==============================================================================

## Hack en cours
var _active_hack: Dictionary = {}
var _hack_progress: float = 0.0
var _hack_interrupted: bool = false

## Traces laissées (target_id -> trace_level)
var _digital_traces: Dictionary = {}

## Alertes par corporation (corpo_id -> alert_level)
var _corpo_alerts: Dictionary = {}

## Chasseurs actifs
var _active_hunters: Array[Dictionary] = []

## Corruptions HUD actives
var _hud_corruptions: Array[String] = []

## Historique des hacks (pour persistance)
var _hack_history: Array[Dictionary] = []

## Timer pour decay des traces
var _trace_decay_timer: float = 0.0

# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	# Decay des traces
	_trace_decay_timer += delta
	if _trace_decay_timer >= trace_decay_time:
		_trace_decay_timer = 0.0
		_decay_traces()


# ==============================================================================
# DÉMARRAGE DE HACK
# ==============================================================================

func start_hack(target_id: String, hack_type: HackType, difficulty: int) -> Dictionary:
	"""Démarre un hack."""
	if not _active_hack.is_empty():
		return {"error": "Hack déjà en cours"}
	
	_active_hack = {
		"target": target_id,
		"type": hack_type,
		"difficulty": difficulty,
		"start_time": Time.get_ticks_msec(),
		"total_time": base_hack_time * (1 + difficulty * difficulty_time_multiplier / 10.0),
		"ice_list": _generate_ice(difficulty),
		"current_ice_index": 0,
		"detected": false
	}
	
	_hack_progress = 0.0
	_hack_interrupted = false
	
	hack_started.emit(target_id, difficulty)
	
	return {
		"success": true,
		"target": target_id,
		"estimated_time": _active_hack.total_time,
		"ice_count": _active_hack.ice_list.size(),
		"message": "Connexion établie. ICE détecté: %d niveaux." % _active_hack.ice_list.size()
	}


func _generate_ice(difficulty: int) -> Array[Dictionary]:
	"""Génère les ICE basés sur la difficulté."""
	var ice_list: Array[Dictionary] = []
	var ice_count := 1 + difficulty / 2
	
	for i in range(ice_count):
		var ice_type: ICEType
		var roll := randf()
		
		if difficulty >= 8 and roll < 0.3:
			ice_type = ICEType.BLACK_ICE
		elif difficulty >= 5 and roll < 0.5:
			ice_type = ICEType.TRACER
		elif difficulty >= 3 and roll < 0.6:
			ice_type = ICEType.MAZE
		elif roll < 0.2:
			ice_type = ICEType.HONEYPOT
		else:
			ice_type = ICEType.FIREWALL
		
		ice_list.append({
			"type": ice_type,
			"strength": difficulty + randi_range(-1, 2),
			"defeated": false
		})
	
	return ice_list


# ==============================================================================
# PROGRESSION DU HACK
# ==============================================================================

func update_hack(delta: float, player_skill: int) -> Dictionary:
	"""Met à jour le hack en cours."""
	if _active_hack.is_empty():
		return {"error": "Aucun hack en cours"}
	
	if _hack_interrupted:
		return {"status": "interrupted"}
	
	var ice_list: Array = _active_hack.ice_list
	var current_idx: int = _active_hack.current_ice_index
	
	# Gestion de l'ICE actuel
	if current_idx < ice_list.size():
		var current_ice: Dictionary = ice_list[current_idx]
		if not current_ice.defeated:
			return _handle_ice(current_ice, player_skill, delta)
	
	# Progression normale
	var progress_rate := 1.0 / _active_hack.total_time
	progress_rate *= (1.0 + (player_skill - _active_hack.difficulty) * 0.1)
	
	_hack_progress += progress_rate * delta
	hack_progress_updated.emit(_hack_progress)
	
	if _hack_progress >= 1.0:
		return _complete_hack(true)
	
	return {
		"status": "in_progress",
		"progress": _hack_progress,
		"remaining_ice": ice_list.size() - current_idx
	}


func _handle_ice(ice: Dictionary, player_skill: int, delta: float) -> Dictionary:
	"""Gère la confrontation avec un ICE."""
	var ice_type: ICEType = ice.type
	var ice_strength: int = ice.strength
	
	ice_encountered.emit(ICEType.keys()[ice_type], ice_strength)
	
	# Chance de vaincre l'ICE
	var defeat_chance := (player_skill - ice_strength + 5) / 10.0
	defeat_chance = clampf(defeat_chance, 0.1, 0.9)
	
	if randf() < defeat_chance * delta:
		return _defeat_ice(ice)
	
	# L'ICE peut contre-attaquer
	match ice_type:
		ICEType.BLACK_ICE:
			return _black_ice_attack(ice_strength)
		ICEType.TRACER:
			return _tracer_detected()
		ICEType.MAZE:
			return _maze_confusion()
		ICEType.HONEYPOT:
			return _honeypot_trap()
		_:
			return {"status": "ice_blocking", "ice_type": ICEType.keys()[ice_type]}


func _defeat_ice(ice: Dictionary) -> Dictionary:
	"""Vainc un ICE."""
	ice.defeated = true
	_active_hack.current_ice_index += 1
	
	ice_defeated.emit(ICEType.keys()[ice.type])
	
	return {
		"status": "ice_defeated",
		"ice_type": ICEType.keys()[ice.type],
		"remaining_ice": _active_hack.ice_list.size() - _active_hack.current_ice_index
	}


# ==============================================================================
# TYPES D'ICE SPÉCIAUX
# ==============================================================================

func _black_ice_attack(strength: int) -> Dictionary:
	"""Le Black ICE attaque le hacker."""
	var damage := int(ice_damage_base * black_ice_damage_multiplier * (strength / 5.0))
	
	# Notifier le système de dégâts
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("take_damage"):
		players[0].take_damage(damage, "neural")
	
	return {
		"status": "ice_attack",
		"ice_type": "BLACK_ICE",
		"damage": damage,
		"message": "BLACK ICE! Dégâts neuraux: %d" % damage
	}


func _tracer_detected() -> Dictionary:
	"""Le Tracer a détecté le hacker."""
	_active_hack.detected = true
	
	# Augmenter le niveau de trace
	var target: String = _active_hack.target
	_increase_trace(target)
	
	return {
		"status": "traced",
		"message": "TRACER activé! Ta localisation est compromise."
	}


func _maze_confusion() -> Dictionary:
	"""Le Maze désoriente le hacker."""
	# Réduire la progression
	_hack_progress = maxf(0, _hack_progress - 0.1)
	
	# Corrompre le HUD
	_add_hud_corruption("direction_scramble")
	
	return {
		"status": "confused",
		"progress_lost": 0.1,
		"message": "MAZE ICE! Tu perds tes repères."
	}


func _honeypot_trap() -> Dictionary:
	"""Le Honeypot piège le hacker avec de fausses données."""
	# Le hack semble réussir mais les données sont fausses
	_active_hack["honeypot_active"] = true
	
	return {
		"status": "honeypot",
		"message": "Données accessibles..." # Ne pas révéler que c'est un piège
	}


# ==============================================================================
# COMPLÉTION DU HACK
# ==============================================================================

func _complete_hack(success: bool) -> Dictionary:
	"""Termine le hack."""
	var result: Dictionary
	
	if success:
		# Vérifier si c'était un honeypot
		if _active_hack.get("honeypot_active", false):
			result = _honeypot_result()
		else:
			result = _successful_hack()
	else:
		result = _failed_hack("interrupted")
	
	# Historique
	_hack_history.append({
		"target": _active_hack.target,
		"type": _active_hack.type,
		"success": success,
		"detected": _active_hack.detected,
		"time": Time.get_ticks_msec()
	})
	
	_active_hack.clear()
	_hack_progress = 0.0
	
	hack_completed.emit(success, result)
	return result


func _successful_hack() -> Dictionary:
	"""Hack réussi."""
	var data := _generate_hack_data()
	
	# Légère trace même en succès si détecté
	if _active_hack.detected:
		_increase_trace(_active_hack.target)
	
	return {
		"success": true,
		"data": data,
		"message": "Hack réussi. Données extraites."
	}


func _honeypot_result() -> Dictionary:
	"""Résultat du honeypot (fausses données)."""
	_increase_trace(_active_hack.target, 2)  # Trace plus forte
	
	var fake_data := {
		"type": "honeypot",
		"fake_credits": randi_range(5000, 20000),
		"fake_secrets": ["Fausse info 1", "Fausse info 2"],
		"virus_payload": true
	}
	
	# Corrompre le HUD
	_add_hud_corruption("false_data")
	
	return {
		"success": true,  # Le joueur ne sait pas encore
		"data": fake_data,
		"message": "Données extraites avec succès.",
		"actual_result": "honeypot"  # Pour le système
	}


func _failed_hack(reason: String) -> Dictionary:
	"""Hack échoué."""
	var consequences := []
	
	if randf() < failure_trace_chance:
		var trace_level := _increase_trace(_active_hack.target, 2)
		consequences.append("traced")
		
		if trace_level >= TraceLevel.TARGETED:
			_spawn_hunter(_active_hack.target)
			consequences.append("hunter_deployed")
	
	# Corruption HUD
	if randf() < 0.3:
		_add_hud_corruption("glitch")
		consequences.append("hud_corrupted")
	
	hack_failed.emit(reason, consequences)
	
	return {
		"success": false,
		"reason": reason,
		"consequences": consequences,
		"message": "Hack échoué. %s" % ", ".join(consequences)
	}


func _generate_hack_data() -> Dictionary:
	"""Génère les données volées."""
	var hack_type: HackType = _active_hack.type
	
	match hack_type:
		HackType.DATA_THEFT:
			return {
				"files": ["personnel_records.db", "financial_reports.xlsx"],
				"value": _active_hack.difficulty * 500
			}
		HackType.SYSTEM_CONTROL:
			return {
				"access_level": _active_hack.difficulty,
				"systems": ["doors", "cameras", "turrets"]
			}
		HackType.SURVEILLANCE:
			return {
				"audio_logs": 5,
				"video_feeds": 3,
				"communications": 10
			}
		HackType.SABOTAGE:
			return {
				"systems_disabled": ["security", "communications"],
				"duration": 300  # 5 minutes
			}
		HackType.IDENTITY:
			return {
				"identities_stolen": 1,
				"clearance_level": _active_hack.difficulty
			}
	
	return {}


# ==============================================================================
# TRACES PERSISTANTES
# ==============================================================================

func _increase_trace(target: String, amount: int = 1) -> int:
	"""Augmente le niveau de trace sur une cible."""
	var current: int = _digital_traces.get(target, TraceLevel.NONE)
	var new_level: int = mini(TraceLevel.TARGETED, current + amount)
	_digital_traces[target] = new_level
	
	digital_trace_left.emit(target, new_level)
	
	# Alerter la corporation associée
	_alert_corporation(target, new_level)
	
	return new_level


func _decay_traces() -> void:
	"""Réduit les traces avec le temps."""
	var to_remove := []
	
	for target in _digital_traces.keys():
		var current: int = _digital_traces[target]
		if current > TraceLevel.NONE:
			_digital_traces[target] = current - 1
			if _digital_traces[target] == TraceLevel.NONE:
				to_remove.append(target)
	
	for target in to_remove:
		_digital_traces.erase(target)


func get_trace_level(target: String) -> int:
	"""Retourne le niveau de trace sur une cible."""
	return _digital_traces.get(target, TraceLevel.NONE)


# ==============================================================================
# ALERTES CORPORATION
# ==============================================================================

func _alert_corporation(target: String, trace_level: int) -> void:
	"""Alerte une corporation."""
	# Déterminer la corpo associée à la cible
	var corpo := _get_target_corporation(target)
	if corpo.is_empty():
		return
	
	var current_alert: int = _corpo_alerts.get(corpo, 0)
	var new_alert: int = maxi(current_alert, trace_level)
	_corpo_alerts[corpo] = new_alert
	
	corpo_alert_raised.emit(corpo, new_alert)
	
	# Impact réputation
	if FactionManager and new_alert >= TraceLevel.IDENTIFIED:
		FactionManager.add_reputation(corpo, -10 * new_alert)


func _get_target_corporation(target: String) -> String:
	"""Détermine la corporation associée à une cible."""
	# Logique simplifiée - à personnaliser
	if "nova" in target.to_lower():
		return "novatech"
	elif "police" in target.to_lower():
		return "police"
	return "novatech"  # Par défaut


# ==============================================================================
# CHASSEURS NUMÉRIQUES
# ==============================================================================

func _spawn_hunter(target: String) -> void:
	"""Génère un chasseur numérique."""
	var hunter := {
		"id": "hunter_%d" % randi(),
		"origin": target,
		"spawn_time": Time.get_ticks_msec(),
		"strength": _digital_traces.get(target, 1) * 3,
		"status": "hunting"
	}
	
	_active_hunters.append(hunter)
	hunter_spawned.emit(hunter)
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Alerte: Chasseur numérique déployé!")


func get_active_hunters() -> Array[Dictionary]:
	"""Retourne les chasseurs actifs."""
	return _active_hunters


func defeat_hunter(hunter_id: String) -> bool:
	"""Marque un chasseur comme vaincu."""
	for i in range(_active_hunters.size()):
		if _active_hunters[i].id == hunter_id:
			_active_hunters.remove_at(i)
			return true
	return false


# ==============================================================================
# CORRUPTION HUD
# ==============================================================================

func _add_hud_corruption(corruption_type: String) -> void:
	"""Ajoute une corruption au HUD."""
	if corruption_type not in _hud_corruptions:
		_hud_corruptions.append(corruption_type)
		hud_corrupted.emit(corruption_type)


func get_hud_corruptions() -> Array[String]:
	"""Retourne les corruptions HUD actives."""
	return _hud_corruptions


func repair_hud_corruption(corruption_type: String) -> bool:
	"""Répare une corruption HUD."""
	var idx := _hud_corruptions.find(corruption_type)
	if idx >= 0:
		_hud_corruptions.remove_at(idx)
		return true
	return false


func repair_all_corruptions() -> int:
	"""Répare toutes les corruptions."""
	var count := _hud_corruptions.size()
	_hud_corruptions.clear()
	return count


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func is_hacking() -> bool:
	"""Vérifie si un hack est en cours."""
	return not _active_hack.is_empty()


func cancel_hack() -> void:
	"""Annule le hack en cours."""
	if not _active_hack.is_empty():
		_hack_interrupted = true
		_failed_hack("cancelled")


func get_hack_progress() -> float:
	"""Retourne la progression du hack."""
	return _hack_progress


func get_hack_history() -> Array[Dictionary]:
	"""Retourne l'historique des hacks."""
	return _hack_history


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"is_hacking": is_hacking(),
		"progress": _hack_progress,
		"traces": _digital_traces.size(),
		"alerts": _corpo_alerts.duplicate(),
		"hunters": _active_hunters.size(),
		"hud_corruptions": _hud_corruptions.size(),
		"total_hacks": _hack_history.size()
	}
