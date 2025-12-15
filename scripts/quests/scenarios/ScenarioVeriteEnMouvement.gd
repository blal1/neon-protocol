# ==============================================================================
# ScenarioVeriteEnMouvement.gd - "La Vérité en Mouvement"
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Un bus pirate doit diffuser une révélation corpo.
# Escorte sous feu constant. Choix final: publier/censurer/monnayer.
# ==============================================================================

extends Node3D
class_name ScenarioVeriteEnMouvement

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal scenario_started()
signal scenario_ended(outcome: String)
signal bus_spawned(bus: Node3D)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal bus_damaged(current_health: int)
signal bus_destroyed()
signal broadcast_progress_updated(progress: float)
signal final_choice_presented()
signal truth_published()
signal truth_censored()
signal truth_sold()

# ==============================================================================
# ENUMS
# ==============================================================================

enum ScenarioState {
	BRIEFING,       ## Explication de la mission
	ESCORT,         ## Escorte en cours
	FINAL_CHOICE,   ## Choix final
	COMPLETED,      ## Terminé
	FAILED          ## Bus détruit
}

enum FinalChoice {
	NONE,
	PUBLISH,    ## Diffuser la vérité
	CENSOR,     ## Censurer pour les corpos
	SELL        ## Vendre au plus offrant
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Bus")
@export var bus_scene: PackedScene
@export var bus_max_health: int = 100
@export var bus_speed: float = 8.0

@export_group("Route")
@export var waypoints: Array[Vector3] = []
@export var broadcast_points: int = 5

@export_group("Combat")
@export var enemy_waves: int = 5
@export var enemies_per_wave: int = 4
@export var wave_interval: float = 30.0
@export var enemy_scene: PackedScene

@export_group("Révélation")
@export var revelation_title: String = "Expériences NovaTech"
@export var revelation_content: String = "NovaTech a testé des implants défectueux sur des civils."

@export_group("Récompenses")
@export var publish_reputation: int = 40
@export var censor_credits: int = 3000
@export var sell_credits: int = 5000

# ==============================================================================
# VARIABLES
# ==============================================================================

var _state: ScenarioState = ScenarioState.BRIEFING
var _final_choice: FinalChoice = FinalChoice.NONE
var _bus: Node3D = null
var _bus_health: int = 100
var _current_wave: int = 0
var _current_waypoint: int = 0
var _broadcast_progress: float = 0.0
var _active_enemies: Array[Node3D] = []
var _wave_timer: float = 0.0

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	_setup_default_waypoints()
	scenario_started.emit()


func _setup_default_waypoints() -> void:
	"""Configure les waypoints par défaut si non définis."""
	if waypoints.is_empty():
		waypoints = [
			Vector3(0, 0, 0),
			Vector3(50, 0, 0),
			Vector3(50, 0, 50),
			Vector3(100, 0, 50),
			Vector3(100, 0, 100),
			Vector3(150, 0, 100)
		]


# ==============================================================================
# DÉMARRAGE
# ==============================================================================

func start_mission() -> Dictionary:
	"""Démarre la mission d'escorte."""
	_state = ScenarioState.ESCORT
	_spawn_bus()
	_start_escort()
	
	# TTS
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Mission: Escorte le bus de diffusion. Protège-le des attaques.")
	
	return {
		"mission": "La Vérité en Mouvement",
		"objective": "Escorter le bus jusqu'au point final",
		"bus_health": _bus_health,
		"waves_total": enemy_waves,
		"revelation": revelation_title
	}


func _spawn_bus() -> void:
	"""Génère le bus de diffusion."""
	if bus_scene:
		_bus = bus_scene.instantiate() as Node3D
	else:
		_bus = Node3D.new()
		_bus.name = "BroadcastBus"
	
	_bus.position = waypoints[0] if waypoints.size() > 0 else Vector3.ZERO
	_bus.set_meta("is_broadcast_bus", true)
	_bus.set_meta("health", bus_max_health)
	_bus_health = bus_max_health
	
	add_child(_bus)
	bus_spawned.emit(_bus)


func _start_escort() -> void:
	"""Démarre l'escorte."""
	_current_waypoint = 0
	_current_wave = 0
	_wave_timer = wave_interval * 0.5  # Première vague plus rapide


# ==============================================================================
# PROCESS
# ==============================================================================

func _process(delta: float) -> void:
	if _state != ScenarioState.ESCORT:
		return
	
	_update_bus_movement(delta)
	_update_waves(delta)
	_update_broadcast_progress()


func _update_bus_movement(delta: float) -> void:
	"""Met à jour le mouvement du bus."""
	if not _bus or _current_waypoint >= waypoints.size():
		return
	
	var target := waypoints[_current_waypoint]
	var direction := (target - _bus.global_position).normalized()
	var distance := _bus.global_position.distance_to(target)
	
	if distance > 1.0:
		_bus.global_position += direction * bus_speed * delta
		_bus.look_at(target)
	else:
		_current_waypoint += 1
		if _current_waypoint >= waypoints.size():
			_reach_destination()


func _update_waves(delta: float) -> void:
	"""Gère les vagues d'ennemis."""
	if _current_wave >= enemy_waves:
		return
	
	_wave_timer -= delta
	if _wave_timer <= 0:
		_wave_timer = wave_interval
		_spawn_wave()


func _update_broadcast_progress() -> void:
	"""Met à jour la progression de la diffusion."""
	if waypoints.size() <= 1:
		return
	
	var progress := float(_current_waypoint) / (waypoints.size() - 1)
	if progress != _broadcast_progress:
		_broadcast_progress = progress
		broadcast_progress_updated.emit(_broadcast_progress)


# ==============================================================================
# COMBAT
# ==============================================================================

func _spawn_wave() -> void:
	"""Génère une vague d'ennemis."""
	_current_wave += 1
	wave_started.emit(_current_wave)
	
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Vague %d!" % _current_wave)
	
	if not enemy_scene:
		return
	
	for i in range(enemies_per_wave):
		var enemy := enemy_scene.instantiate() as Node3D
		
		# Position autour du bus
		var angle := randf() * TAU
		var distance := randf_range(15, 25)
		enemy.position = _bus.global_position + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		enemy.set_meta("target", _bus)
		add_child(enemy)
		_active_enemies.append(enemy)
		
		# Configurer l'IA pour attaquer le bus
		if enemy.has_method("set_target"):
			enemy.set_target(_bus)


func damage_bus(amount: int) -> void:
	"""Inflige des dégâts au bus."""
	_bus_health = maxi(0, _bus_health - amount)
	bus_damaged.emit(_bus_health)
	
	if _bus_health <= 0:
		_bus_destroyed()


func _bus_destroyed() -> void:
	"""Le bus est détruit."""
	_state = ScenarioState.FAILED
	bus_destroyed.emit()
	
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Mission échouée. Le bus est détruit.")
	
	scenario_ended.emit("failed")


func get_bus_health() -> int:
	"""Retourne la santé du bus."""
	return _bus_health


func get_bus_health_percent() -> float:
	"""Retourne le pourcentage de santé."""
	return float(_bus_health) / bus_max_health


# ==============================================================================
# DESTINATION & CHOIX FINAL
# ==============================================================================

func _reach_destination() -> void:
	"""Le bus atteint sa destination."""
	_state = ScenarioState.FINAL_CHOICE
	
	# Nettoyer les ennemis restants
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	
	# Présenter le choix final
	_present_final_choice()


func _present_final_choice() -> void:
	"""Présente le choix final au joueur."""
	final_choice_presented.emit()
	
	if TTSManager and TTSManager.has_method("speak"):
		TTSManager.speak("Le bus est en position. Que fais-tu de la vérité?")
	
	var choices := [
		{
			"id": "publish",
			"text": "Publier la vérité",
			"description": "Diffuser à toute la ville. Impact mondial.",
			"consequence": "+%d réputation Cryptopirates, -30 réputation NovaTech" % publish_reputation
		},
		{
			"id": "censor",
			"text": "Censurer pour NovaTech",
			"description": "Effacer les preuves. Récompense corpo.",
			"consequence": "+%d crédits, +20 réputation NovaTech, -40 réputation Cryptopirates" % censor_credits
		},
		{
			"id": "sell",
			"text": "Vendre au plus offrant",
			"description": "Monnayer l'information. Pur profit.",
			"consequence": "+%d crédits, -20 réputation tous groupes" % sell_credits
		}
	]
	
	# Afficher les choix via le système de dialogue
	if CutsceneManager and CutsceneManager.has_method("show_choices"):
		CutsceneManager.show_choices(choices)


func make_final_choice(choice_id: String) -> Dictionary:
	"""Le joueur fait son choix final."""
	if _state != ScenarioState.FINAL_CHOICE:
		return {"error": "Pas en phase de choix"}
	
	match choice_id:
		"publish":
			return _publish_truth()
		"censor":
			return _censor_truth()
		"sell":
			return _sell_truth()
		_:
			return {"error": "Choix invalide"}


func _publish_truth() -> Dictionary:
	"""Publie la vérité au monde."""
	_state = ScenarioState.COMPLETED
	_final_choice = FinalChoice.PUBLISH
	
	truth_published.emit()
	
	# Effets sur les factions
	if FactionManager:
		FactionManager.add_reputation("cryptopirates", publish_reputation)
		FactionManager.add_reputation("novatech", -30)
	
	# Impact sur le monde (via Cryptopirates si disponible)
	var cryptopirates := get_node_or_null("/root/Cryptopirates")
	if cryptopirates and cryptopirates.has_method("broadcast_truth"):
		cryptopirates.broadcast_truth(revelation_title)
	
	scenario_ended.emit("published")
	
	return {
		"outcome": "published",
		"message": "La vérité éclate. '%s' est maintenant connue de tous." % revelation_title,
		"reputation_change": {
			"cryptopirates": publish_reputation,
			"novatech": -30
		},
		"world_impact": true
	}


func _censor_truth() -> Dictionary:
	"""Censure la vérité pour les corpos."""
	_state = ScenarioState.COMPLETED
	_final_choice = FinalChoice.CENSOR
	
	truth_censored.emit()
	
	# Récompense
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("add_credits"):
		players[0].add_credits(censor_credits)
	
	# Réputation
	if FactionManager:
		FactionManager.add_reputation("novatech", 20)
		FactionManager.add_reputation("cryptopirates", -40)
	
	scenario_ended.emit("censored")
	
	return {
		"outcome": "censored",
		"message": "La vérité meurt dans l'ombre. NovaTech est reconnaissante.",
		"credits_earned": censor_credits,
		"reputation_change": {
			"novatech": 20,
			"cryptopirates": -40
		}
	}


func _sell_truth() -> Dictionary:
	"""Vend la vérité au plus offrant."""
	_state = ScenarioState.COMPLETED
	_final_choice = FinalChoice.SELL
	
	truth_sold.emit()
	
	# Gros profit
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("add_credits"):
		players[0].add_credits(sell_credits)
	
	# Réputation négative partout
	if FactionManager:
		FactionManager.add_reputation("cryptopirates", -20)
		FactionManager.add_reputation("novatech", -10)
		FactionManager.add_reputation("citizens", -15)
	
	scenario_ended.emit("sold")
	
	return {
		"outcome": "sold",
		"message": "La vérité a un prix. Et tu l'as encaissé.",
		"credits_earned": sell_credits,
		"reputation_change": {
			"cryptopirates": -20,
			"novatech": -10,
			"citizens": -15
		}
	}


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_state() -> ScenarioState:
	"""Retourne l'état du scénario."""
	return _state


func get_final_choice() -> FinalChoice:
	"""Retourne le choix final."""
	return _final_choice


func get_current_wave() -> int:
	"""Retourne la vague actuelle."""
	return _current_wave


func get_broadcast_progress() -> float:
	"""Retourne la progression de la diffusion."""
	return _broadcast_progress


func get_bus() -> Node3D:
	"""Retourne le bus."""
	return _bus


func get_scenario_summary() -> Dictionary:
	"""Retourne un résumé du scénario."""
	return {
		"name": "La Vérité en Mouvement",
		"state": ScenarioState.keys()[_state],
		"bus_health": _bus_health,
		"current_wave": _current_wave,
		"total_waves": enemy_waves,
		"broadcast_progress": _broadcast_progress,
		"final_choice": FinalChoice.keys()[_final_choice] if _final_choice != FinalChoice.NONE else "pending",
		"revelation": revelation_title
	}
