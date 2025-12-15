# ==============================================================================
# TimeDilationManager.gd - Gestion de la Dilatation Temporelle
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère le "Bullet Time" en solo et multijoueur.
# Solo: Ralentissement réel du temps.
# Multi: Effet visuel local + prédiction côté client.
# ==============================================================================

extends Node
class_name TimeDilationManager

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal time_dilation_started(factor: float, initiator: Node)
signal time_dilation_ended()
signal time_dilation_changed(old_factor: float, new_factor: float)
signal local_effect_applied(player_id: int)
signal global_slowmo_requested(player_id: int)
signal global_slowmo_denied(reason: String)

# ==============================================================================
# ENUMS
# ==============================================================================

enum Mode {
	SOLO,           ## Ralentissement réel
	MULTIPLAYER_LOCAL,   ## Effet visuel local uniquement
	MULTIPLAYER_GLOBAL,  ## Tous les joueurs ralentis (authorité serveur)
	DISABLED        ## Pas de ralentissement
}

enum DilationType {
	TACTICAL,       ## Mode tactique du joueur
	ABILITY,        ## Capacité spéciale
	CINEMATIC,      ## Cutscene
	HIT_CONFIRM,    ## Impact ralenti court
	DEATH           ## Mort dramatique
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Mode")
@export var mode: Mode = Mode.SOLO
@export var allow_stacking: bool = false

@export_group("Time Factors")
@export var tactical_factor: float = 0.25
@export var ability_factor: float = 0.5
@export var hit_confirm_factor: float = 0.3
@export var death_factor: float = 0.1
@export var cinematic_factor: float = 0.0  # Pause totale

@export_group("Durations")
@export var hit_confirm_duration: float = 0.15
@export var death_slowmo_duration: float = 1.5
@export var max_tactical_duration: float = 5.0

@export_group("Multiplayer")
@export var global_slowmo_vote_threshold: float = 0.5  # 50% des joueurs
@export var global_slowmo_cooldown: float = 30.0

# ==============================================================================
# VARIABLES
# ==============================================================================

var _current_factor: float = 1.0
var _target_factor: float = 1.0
var _active_dilations: Array[Dictionary] = []
var _is_transitioning: bool = false
var _transition_speed: float = 5.0

## Multiplayer state
var _is_multiplayer: bool = false
var _is_server: bool = false
var _local_player_id: int = 0
var _global_slowmo_votes: Dictionary = {}  # player_id -> bool
var _last_global_slowmo_time: float = 0.0

## Compensations locales (multi)
var _local_visual_factor: float = 1.0
var _physics_compensation: float = 1.0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_detect_multiplayer_mode()


func _detect_multiplayer_mode() -> void:
	"""Détecte si on est en multijoueur."""
	if multiplayer.has_multiplayer_peer():
		_is_multiplayer = true
		_is_server = multiplayer.is_server()
		_local_player_id = multiplayer.get_unique_id()
		
		if mode == Mode.SOLO:
			mode = Mode.MULTIPLAYER_LOCAL


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	_update_time_scale(delta)
	_update_active_dilations(delta)


func _update_time_scale(delta: float) -> void:
	"""Met à jour progressivement le time scale."""
	if abs(_current_factor - _target_factor) < 0.01:
		_current_factor = _target_factor
		_is_transitioning = false
		return
	
	_is_transitioning = true
	_current_factor = lerpf(_current_factor, _target_factor, _transition_speed * delta)
	
	# Appliquer selon le mode
	match mode:
		Mode.SOLO:
			Engine.time_scale = _current_factor
		Mode.MULTIPLAYER_LOCAL:
			# Ne pas toucher au time_scale global
			# Appliquer des effets visuels locaux
			_apply_local_visual_effects(_current_factor)
		Mode.MULTIPLAYER_GLOBAL:
			if _is_server:
				Engine.time_scale = _current_factor
				_sync_time_scale_to_clients.rpc(_current_factor)


func _update_active_dilations(delta: float) -> void:
	"""Met à jour les dilations actives."""
	var real_delta := delta / maxf(0.01, _current_factor)  # Delta temps réel
	
	var to_remove := []
	
	for i in range(_active_dilations.size()):
		var dilation: Dictionary = _active_dilations[i]
		if dilation.has("remaining_time"):
			dilation.remaining_time -= real_delta
			if dilation.remaining_time <= 0:
				to_remove.append(i)
	
	# Supprimer les dilations expirées (en ordre inverse)
	for i in range(to_remove.size() - 1, -1, -1):
		_active_dilations.remove_at(to_remove[i])
	
	# Recalculer le facteur cible
	if not to_remove.is_empty():
		_recalculate_target_factor()


func _recalculate_target_factor() -> void:
	"""Recalcule le facteur cible basé sur les dilations actives."""
	if _active_dilations.is_empty():
		_target_factor = 1.0
		time_dilation_ended.emit()
		return
	
	if allow_stacking:
		# Multiplie tous les facteurs
		_target_factor = 1.0
		for dilation in _active_dilations:
			_target_factor *= dilation.factor
	else:
		# Prend le facteur le plus petit (le plus ralenti)
		_target_factor = 1.0
		for dilation in _active_dilations:
			_target_factor = minf(_target_factor, dilation.factor)
	
	_target_factor = maxf(0.01, _target_factor)  # Minimum 1%


# ==============================================================================
# API PRINCIPALE
# ==============================================================================

func start_time_dilation(
	dilation_type: DilationType,
	duration: float = -1.0,
	custom_factor: float = -1.0,
	initiator: Node = null
) -> bool:
	"""Démarre une dilatation temporelle."""
	
	# Vérifier si autorisé en mode actuel
	if mode == Mode.DISABLED:
		return false
	
	# Déterminer le facteur
	var factor := _get_factor_for_type(dilation_type)
	if custom_factor > 0:
		factor = custom_factor
	
	# Déterminer la durée
	if duration < 0:
		duration = _get_default_duration(dilation_type)
	
	# En multijoueur global, demander l'approbation
	if mode == Mode.MULTIPLAYER_GLOBAL and not _is_server:
		_request_global_slowmo.rpc_id(1, _local_player_id, int(dilation_type), duration)
		return true  # En attente
	
	# Créer la dilation
	var dilation := {
		"type": dilation_type,
		"factor": factor,
		"remaining_time": duration if duration > 0 else INF,
		"initiator": initiator,
		"start_time": Time.get_ticks_msec() / 1000.0
	}
	
	_active_dilations.append(dilation)
	_recalculate_target_factor()
	
	time_dilation_started.emit(factor, initiator)
	
	return true


func stop_time_dilation(dilation_type: DilationType = -1) -> void:
	"""Arrête une ou toutes les dilations."""
	if dilation_type == -1:
		_active_dilations.clear()
	else:
		var to_remove := []
		for i in range(_active_dilations.size()):
			if _active_dilations[i].type == dilation_type:
				to_remove.append(i)
		
		for i in range(to_remove.size() - 1, -1, -1):
			_active_dilations.remove_at(to_remove[i])
	
	_recalculate_target_factor()


func _get_factor_for_type(dilation_type: DilationType) -> float:
	"""Retourne le facteur pour un type de dilation."""
	match dilation_type:
		DilationType.TACTICAL:
			return tactical_factor
		DilationType.ABILITY:
			return ability_factor
		DilationType.HIT_CONFIRM:
			return hit_confirm_factor
		DilationType.DEATH:
			return death_factor
		DilationType.CINEMATIC:
			return cinematic_factor
		_:
			return 1.0


func _get_default_duration(dilation_type: DilationType) -> float:
	"""Retourne la durée par défaut."""
	match dilation_type:
		DilationType.HIT_CONFIRM:
			return hit_confirm_duration
		DilationType.DEATH:
			return death_slowmo_duration
		DilationType.TACTICAL:
			return max_tactical_duration
		_:
			return 3.0


# ==============================================================================
# EFFETS VISUELS LOCAUX (MULTIJOUEUR)
# ==============================================================================

func _apply_local_visual_effects(factor: float) -> void:
	"""Applique des effets visuels de ralenti sans affecter le temps réel."""
	_local_visual_factor = factor
	
	# Modifier les animations du joueur local
	var player := _get_local_player()
	if player and player.has_method("set_animation_speed"):
		player.set_animation_speed(1.0 / factor)  # Animations plus lentes visuellement
	
	# Post-process
	if factor < 0.5:
		# Ajouter effets visuels (motion blur, saturation)
		_apply_slowmo_post_process(factor)
	
	local_effect_applied.emit(_local_player_id)


func _apply_slowmo_post_process(factor: float) -> void:
	"""Applique des effets post-process de ralenti."""
	# Chercher un ColorRect avec le shader de cyberpsychose
	var vp := get_viewport()
	if not vp:
		return
	
	# NOTE: À connecter avec le système de post-process existant


func _get_local_player() -> Node:
	"""Récupère le joueur local."""
	# TODO: Adapter au système de joueur du projet
	return get_tree().get_first_node_in_group("player")


# ==============================================================================
# MULTIJOUEUR RPC
# ==============================================================================

@rpc("any_peer", "call_remote", "reliable")
func _request_global_slowmo(requester_id: int, dilation_type: int, duration: float) -> void:
	"""Demande un slowmo global (serveur uniquement)."""
	if not _is_server:
		return
	
	# Vérifier le cooldown
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_global_slowmo_time < global_slowmo_cooldown:
		_deny_global_slowmo.rpc_id(requester_id, "Cooldown actif")
		return
	
	# Vote automatique ou approbation directe
	_global_slowmo_votes[requester_id] = true
	
	var total_players := multiplayer.get_peers().size() + 1
	var votes := _global_slowmo_votes.size()
	
	if float(votes) / total_players >= global_slowmo_vote_threshold:
		# Approuvé
		_last_global_slowmo_time = current_time
		_global_slowmo_votes.clear()
		start_time_dilation(dilation_type as DilationType, duration)


@rpc("authority", "call_remote", "reliable")
func _deny_global_slowmo(reason: String) -> void:
	"""Slowmo refusé par le serveur."""
	global_slowmo_denied.emit(reason)


@rpc("authority", "call_remote", "unreliable")
func _sync_time_scale_to_clients(factor: float) -> void:
	"""Synchronise le time scale depuis le serveur."""
	if not _is_server:
		Engine.time_scale = factor
		_current_factor = factor


# ==============================================================================
# HELPERS DE COMBAT
# ==============================================================================

func trigger_hit_confirm() -> void:
	"""Effet de ralenti court sur impact."""
	start_time_dilation(DilationType.HIT_CONFIRM)


func trigger_death_slowmo(dying_entity: Node = null) -> void:
	"""Ralenti dramatique pour une mort."""
	start_time_dilation(DilationType.DEATH, death_slowmo_duration, -1, dying_entity)


func enter_tactical_mode(player: Node) -> bool:
	"""Entre en mode tactique."""
	return start_time_dilation(DilationType.TACTICAL, max_tactical_duration, -1, player)


func exit_tactical_mode() -> void:
	"""Sort du mode tactique."""
	stop_time_dilation(DilationType.TACTICAL)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_current_time_factor() -> float:
	"""Retourne le facteur de temps actuel."""
	return _current_factor


func get_local_visual_factor() -> float:
	"""Retourne le facteur visuel local (multi)."""
	return _local_visual_factor


func is_time_dilated() -> bool:
	"""Vérifie si le temps est dilate."""
	return _current_factor < 0.99


func is_transitioning() -> bool:
	"""Vérifie si une transition est en cours."""
	return _is_transitioning


func get_mode() -> Mode:
	"""Retourne le mode actuel."""
	return mode


func set_mode(new_mode: Mode) -> void:
	"""Change le mode."""
	var old_mode := mode
	mode = new_mode
	
	# Reset si nécessaire
	if new_mode == Mode.DISABLED:
		stop_time_dilation()
		Engine.time_scale = 1.0


func get_physics_compensation() -> float:
	"""
	Retourne le facteur de compensation physique.
	Utiliser pour multiplier les vélocités en mode local.
	"""
	if mode == Mode.MULTIPLAYER_LOCAL:
		return 1.0 / maxf(0.1, _local_visual_factor)
	return 1.0


func get_system_summary() -> Dictionary:
	"""Retourne un résumé du système."""
	return {
		"mode": Mode.keys()[mode],
		"current_factor": _current_factor,
		"target_factor": _target_factor,
		"active_dilations": _active_dilations.size(),
		"is_multiplayer": _is_multiplayer,
		"is_transitioning": _is_transitioning
	}
