# ==============================================================================
# Cryptopirates.gd - Hackers Nomades de la Vérité
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Hackers diffusant la vérité via bus, drones et ondes pirates.
# Gameplay: escorte, piratage en temps réel, impact sur le monde.
# ==============================================================================

extends Node
class_name Cryptopirates

# ==============================================================================
# SIGNAUX
# ==============================================================================

signal broadcast_started(broadcast_data: Dictionary)
signal broadcast_completed(success: bool, reach: int)
signal hack_initiated(target: String)
signal hack_progress_updated(progress: float)
signal hack_completed(success: bool, data_stolen: Dictionary)
signal bus_escort_started(bus: Node3D)
signal bus_escort_completed(success: bool)
signal world_info_updated(info_type: String)
signal truth_revealed(truth_data: Dictionary)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

const FACTION_ID := "cryptopirates"

## Types de missions de piratage
enum HackType {
	DATA_THEFT,        ## Vol de données
	BROADCAST_HIJACK,  ## Piratage de diffusion
	SYSTEM_SABOTAGE,   ## Sabotage de système
	SURVEILLANCE_TAP,  ## Écoute de surveillance
	IDENTITY_FORGE     ## Falsification d'identité
}

## Niveaux de vérité révélée
enum TruthLevel {
	RUMOR,       ## Rumeur non confirmée
	EVIDENCE,    ## Preuves tangibles
	SCANDAL,     ## Scandale public
	REVELATION,  ## Révélation majeure
	WORLD_CHANGE ## Changement du monde
}

# ==============================================================================
# DONNÉES
# ==============================================================================

## Le Capitaine Signal (leader)
var captain_signal := {
	"name": "Le Capitaine Signal",
	"real_name": "UNKNOWN",
	"broadcasts_completed": 127,
	"truth_score": 850,
	"wanted_level": 5
}

## Bus de diffusion actifs
var broadcast_buses: Array[Dictionary] = []

## Antennes pirates installées
var pirate_antennas: Array[Vector3] = []

## Vérités révélées au monde
var revealed_truths: Array[Dictionary] = []

## Données volées en stock
var stolen_data: Array[Dictionary] = []

## Impact sur le monde (0-100, affecte les événements globaux)
var world_info_impact: float = 0.0

## Diffusions réussies
var successful_broadcasts: int = 0

## Hacks en cours
var _active_hacks: Dictionary = {}

# ==============================================================================
# MISSIONS DE BUS
# ==============================================================================

func start_bus_escort_mission(bus_scene: PackedScene, route: Array[Vector3]) -> Dictionary:
	"""Démarre une mission d'escorte de bus-broadcast."""
	var bus_data := {
		"id": "bus_%d" % randi(),
		"status": "active",
		"health": 100,
		"broadcast_progress": 0.0,
		"route": route,
		"current_waypoint": 0,
		"enemies_spawned": 0,
		"player_defending": true
	}
	
	broadcast_buses.append(bus_data)
	bus_escort_started.emit(null)  # La scène sera instanciée par le caller
	
	return {
		"mission_id": bus_data.id,
		"objectives": [
			"Protège le bus de diffusion",
			"Maintiens le signal actif",
			"Atteins tous les points de diffusion"
		],
		"route_points": route.size(),
		"expected_enemies": 3 * route.size(),
		"reward_reputation": 30,
		"reward_credits": 1500,
		"world_impact": true
	}


func update_bus_escort(bus_id: String, damage: int = 0, waypoint_reached: bool = false) -> Dictionary:
	"""Met à jour l'état d'une mission d'escorte."""
	for bus in broadcast_buses:
		if bus.id == bus_id:
			bus.health -= damage
			
			if waypoint_reached:
				bus.current_waypoint += 1
				bus.broadcast_progress = float(bus.current_waypoint) / bus.route.size()
				
				# Chaque waypoint = diffusion partielle
				_partial_broadcast(bus)
			
			# Vérifier fin de mission
			if bus.health <= 0:
				return _complete_bus_mission(bus_id, false)
			elif bus.current_waypoint >= bus.route.size():
				return _complete_bus_mission(bus_id, true)
			
			return {"status": "ongoing", "health": bus.health, "progress": bus.broadcast_progress}
	
	return {"error": "Bus not found"}


func _partial_broadcast(bus_data: Dictionary) -> void:
	"""Effectue une diffusion partielle à un waypoint."""
	world_info_impact += 2.0
	
	# Notifier le monde
	world_info_updated.emit("partial_broadcast")


func _complete_bus_mission(bus_id: String, success: bool) -> Dictionary:
	"""Termine une mission de bus."""
	for i in range(broadcast_buses.size()):
		if broadcast_buses[i].id == bus_id:
			broadcast_buses[i].status = "completed" if success else "destroyed"
			
			if success:
				successful_broadcasts += 1
				world_info_impact += 15.0
				
				# Révéler une vérité si assez de broadcasts
				if successful_broadcasts % 3 == 0:
					_reveal_random_truth()
			
			bus_escort_completed.emit(success)
			
			return {
				"success": success,
				"world_impact": world_info_impact,
				"truths_revealed": revealed_truths.size()
			}
	
	return {"error": "Bus not found"}


# ==============================================================================
# SYSTÈME DE PIRATAGE EN TEMPS RÉEL
# ==============================================================================

func start_hack(target_id: String, hack_type: HackType, difficulty: int) -> Dictionary:
	"""Démarre un hack en temps réel."""
	var hack_data := {
		"target": target_id,
		"type": hack_type,
		"difficulty": difficulty,
		"progress": 0.0,
		"detected": false,
		"start_time": Time.get_ticks_msec(),
		"time_limit": 30.0 - (difficulty * 3),  # Plus dur = moins de temps
		"minigame_tokens": _generate_hack_tokens(difficulty)
	}
	
	_active_hacks[target_id] = hack_data
	hack_initiated.emit(target_id)
	
	return {
		"hack_id": target_id,
		"time_limit": hack_data.time_limit,
		"tokens": hack_data.minigame_tokens,
		"instructions": _get_hack_instructions(hack_type)
	}


func _generate_hack_tokens(difficulty: int) -> Array[String]:
	"""Génère les tokens du minigame de piratage."""
	var tokens: Array[String] = []
	var token_pool := ["0", "1", "A", "B", "C", "D", "E", "F"]
	var count := 4 + difficulty * 2
	
	for i in range(count):
		tokens.append(token_pool[randi() % token_pool.size()])
	
	return tokens


func _get_hack_instructions(hack_type: HackType) -> String:
	"""Retourne les instructions de piratage."""
	match hack_type:
		HackType.DATA_THEFT:
			return "Trouve la séquence cachée dans le flux de données."
		HackType.BROADCAST_HIJACK:
			return "Synchronise ton signal avec la fréquence cible."
		HackType.SYSTEM_SABOTAGE:
			return "Injecte le virus sans déclencher les défenses."
		HackType.SURVEILLANCE_TAP:
			return "Écoute sans te faire repérer."
		HackType.IDENTITY_FORGE:
			return "Crée une identité crédible à partir des fragments."
		_:
			return "Pirate le système."


func update_hack_progress(target_id: String, progress_delta: float, detected: bool = false) -> Dictionary:
	"""Met à jour la progression d'un hack."""
	if not _active_hacks.has(target_id):
		return {"error": "No active hack"}
	
	var hack := _active_hacks[target_id]
	hack.progress += progress_delta
	hack.detected = hack.detected or detected
	
	hack_progress_updated.emit(hack.progress)
	
	# Vérifier complétion
	if hack.progress >= 100.0:
		return complete_hack(target_id, true)
	elif hack.detected:
		return complete_hack(target_id, false)
	
	# Vérifier timeout
	var elapsed := (Time.get_ticks_msec() - hack.start_time) / 1000.0
	if elapsed >= hack.time_limit:
		return complete_hack(target_id, false)
	
	return {
		"progress": hack.progress,
		"time_remaining": hack.time_limit - elapsed,
		"detected": hack.detected
	}


func complete_hack(target_id: String, success: bool) -> Dictionary:
	"""Termine un hack."""
	if not _active_hacks.has(target_id):
		return {"error": "No active hack"}
	
	var hack := _active_hacks[target_id]
	_active_hacks.erase(target_id)
	
	var data_obtained := {}
	
	if success:
		data_obtained = _generate_stolen_data(hack.type, hack.difficulty)
		stolen_data.append(data_obtained)
		world_info_impact += hack.difficulty * 3.0
	
	hack_completed.emit(success, data_obtained)
	
	return {
		"success": success,
		"data": data_obtained,
		"world_impact": world_info_impact
	}


func _generate_stolen_data(hack_type: HackType, difficulty: int) -> Dictionary:
	"""Génère les données volées."""
	var data_types := {
		HackType.DATA_THEFT: ["financial_records", "employee_data", "secret_projects"],
		HackType.BROADCAST_HIJACK: ["broadcast_codes", "frequency_maps", "censored_content"],
		HackType.SYSTEM_SABOTAGE: ["security_protocols", "maintenance_codes", "backdoor_access"],
		HackType.SURVEILLANCE_TAP: ["surveillance_footage", "communication_logs", "tracking_data"],
		HackType.IDENTITY_FORGE: ["id_templates", "biometric_samples", "credential_formats"]
	}
	
	var possible_data: Array = data_types.get(hack_type, ["generic_data"])
	var data_name: String = possible_data[randi() % possible_data.size()]
	
	return {
		"id": "data_%d" % randi(),
		"type": data_name,
		"value": difficulty * 500,
		"sensitivity": difficulty,
		"can_broadcast": hack_type != HackType.IDENTITY_FORGE
	}


# ==============================================================================
# RÉVÉLATION DE VÉRITÉS
# ==============================================================================

func _reveal_random_truth() -> void:
	"""Révèle une vérité aléatoire au monde."""
	var truths := [
		{
			"id": "nova_experiments",
			"title": "Expériences Humaines de NovaTech",
			"level": TruthLevel.SCANDAL,
			"description": "NovaTech a mené des expériences sur des civils sans consentement.",
			"target_faction": "novatech"
		},
		{
			"id": "police_bribes",
			"title": "Corruption de la Police",
			"level": TruthLevel.EVIDENCE,
			"description": "Les forces de l'ordre reçoivent des pots-de-vin des corporations.",
			"target_faction": "police"
		},
		{
			"id": "ai_sentience",
			"title": "Conscience des IA",
			"level": TruthLevel.REVELATION,
			"description": "Preuves que les IA sont véritablement conscientes.",
			"target_faction": "ban_captchas"
		},
		{
			"id": "food_synthesis",
			"title": "Composition de la Nourriture",
			"level": TruthLevel.SCANDAL,
			"description": "La viande synthétique contient des composants non déclarés.",
			"target_faction": ""
		}
	]
	
	# Éviter les doublons
	var available := truths.filter(func(t): 
		for rt in revealed_truths:
			if rt.id == t.id:
				return false
		return true
	)
	
	if available.is_empty():
		return
	
	var truth: Dictionary = available[randi() % available.size()]
	revealed_truths.append(truth)
	truth_revealed.emit(truth)
	
	# Impact sur la faction ciblée
	if truth.target_faction != "" and FactionManager:
		FactionManager.add_reputation(truth.target_faction, -15)


func broadcast_truth(truth_id: String) -> Dictionary:
	"""Diffuse une vérité spécifique au monde."""
	for truth in revealed_truths:
		if truth.id == truth_id:
			# Augmenter l'impact
			var impact_gain := 10.0 * (truth.level + 1)
			world_info_impact += impact_gain
			
			broadcast_started.emit(truth)
			broadcast_completed.emit(true, int(world_info_impact))
			
			return {
				"truth": truth,
				"reach": int(world_info_impact * 1000),
				"world_impact": world_info_impact
			}
	
	return {"error": "Truth not found"}


func reveal_final_truth() -> Dictionary:
	"""Révèle la vérité finale (fin de faction)."""
	if world_info_impact < 80:
		return {"error": "Not enough impact", "required": 80, "current": world_info_impact}
	
	var final_truth := {
		"id": "final_revelation",
		"title": "La Vérité Complète",
		"level": TruthLevel.WORLD_CHANGE,
		"description": "Toutes les preuves des crimes corporatistes diffusées simultanément.",
		"consequences": [
			"Émeutes dans toute la ville",
			"NovaTech en faillite",
			"Nouveau gouvernement provisoire",
			"Les Cryptopirates deviennent légitimes"
		]
	}
	
	revealed_truths.append(final_truth)
	truth_revealed.emit(final_truth)
	
	# Notifier le FactionManager
	if FactionManager:
		FactionManager._unlock_ending(FACTION_ID, "truth_revealed")
	
	return {
		"success": true,
		"truth": final_truth,
		"world_changed": true
	}


# ==============================================================================
# ANTENNES PIRATES
# ==============================================================================

func install_antenna(position: Vector3) -> bool:
	"""Installe une antenne pirate."""
	# Vérifier qu'il n'y a pas déjà une antenne proche
	for antenna in pirate_antennas:
		if position.distance_to(antenna) < 50.0:
			return false
	
	pirate_antennas.append(position)
	world_info_impact += 5.0
	
	return true


func get_antenna_coverage() -> float:
	"""Retourne le pourcentage de couverture des antennes."""
	# Supposons que 10 antennes = 100% couverture
	return minf(100.0, pirate_antennas.size() * 10.0)


# ==============================================================================
# DIALOGUES
# ==============================================================================

func get_pirate_dialogue() -> String:
	"""Génère un dialogue typique de Cryptopirate."""
	var dialogues := [
		"L'information veut être libre. On l'aide juste un peu.",
		"Les corpos cachent la vérité. On la diffuse.",
		"Ton signal est notre arme. Ta voix est notre munition.",
		"Hack the planet. Littéralement.",
		"Chaque bit volé est un pas vers la liberté.",
		"Le Capitaine dit: 'La vérité ne meurt jamais, elle attend.'",
		"Tu veux rejoindre? Première leçon: jamais de traces.",
		"On ne piraten pas pour l'argent. Enfin, pas seulement."
	]
	return dialogues[randi() % dialogues.size()]


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_faction_summary() -> Dictionary:
	"""Retourne un résumé de la faction."""
	return {
		"id": FACTION_ID,
		"name": "Cryptopirates",
		"captain": captain_signal.name,
		"world_impact": world_info_impact,
		"truths_revealed": revealed_truths.size(),
		"data_stolen": stolen_data.size(),
		"antennas": pirate_antennas.size(),
		"antenna_coverage": get_antenna_coverage(),
		"successful_broadcasts": successful_broadcasts,
		"can_reveal_final": world_info_impact >= 80
	}


func get_world_impact() -> float:
	"""Retourne l'impact sur le monde."""
	return world_info_impact


func get_revealed_truths() -> Array[Dictionary]:
	"""Retourne les vérités révélées."""
	return revealed_truths
