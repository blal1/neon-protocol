# ==============================================================================
# WorldLayerManager.gd - Gestionnaire Global des Couches NEON DELTA
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Autoload singleton gérant les transitions verticales entre couches.
# Détecte automatiquement la couche actuelle via l'altitude du joueur (Y).
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================

## Émis quand le joueur change de couche
signal layer_changed(old_layer: WorldLayerTypes.LayerType, new_layer: WorldLayerTypes.LayerType)

## Émis quand les effets environnementaux doivent être mis à jour
signal environment_update(layer_data: Dictionary)

## Émis quand le joueur entre dans une zone de danger
signal hazard_entered(hazard_type: String)

## Émis quand le joueur sort d'une zone de danger
signal hazard_exited(hazard_type: String)

# ==============================================================================
# CONFIGURATION
# ==============================================================================

@export_group("Références")
## Référence au joueur (auto-détecté si vide)
@export var player: Node3D

@export_group("Mise à jour")
## Fréquence de vérification de la couche (secondes)
@export var update_interval: float = 0.25
## Hystérésis pour éviter les changements rapides aux frontières
@export var layer_hysteresis: float = 5.0

@export_group("Debug")
## Affiche les infos de couche dans la console
@export var debug_mode: bool = false

# ==============================================================================
# VARIABLES
# ==============================================================================

## Couche actuelle du joueur
var current_layer: WorldLayerTypes.LayerType = WorldLayerTypes.LayerType.LIVING_CITY

## Données de la couche actuelle (cache)
var current_layer_data: Dictionary = {}

## Dangers actifs affectant le joueur
var active_hazards: Array[String] = []

## Timer interne
var _timer: float = 0.0

## Dernière altitude enregistrée
var _last_altitude: float = 0.0

## Couche précédente (pour hystérésis)
var _previous_layer: WorldLayerTypes.LayerType = WorldLayerTypes.LayerType.LIVING_CITY

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	# Auto-détection du joueur
	if not player:
		await get_tree().process_frame
		_find_player()
	
	# Initialiser avec la couche par défaut
	current_layer_data = WorldLayerTypes.get_layer_data(current_layer)
	
	if debug_mode:
		print("[WorldLayerManager] Initialisé - Couche: ", WorldLayerTypes.get_layer_name(current_layer))


func _find_player() -> void:
	"""Recherche automatique du joueur dans le groupe 'player'."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node3D
		if debug_mode:
			print("[WorldLayerManager] Joueur trouvé: ", player.name)
	else:
		push_warning("[WorldLayerManager] Aucun joueur trouvé dans le groupe 'player'")


# ==============================================================================
# MISE À JOUR
# ==============================================================================

func _process(delta: float) -> void:
	if not player:
		_find_player()
		return
	
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	
	_check_layer_change()


func _check_layer_change() -> void:
	"""Vérifie si le joueur a changé de couche."""
	var altitude := player.global_position.y
	var new_layer := WorldLayerTypes.get_layer_from_altitude(altitude)
	
	# Appliquer hystérésis pour éviter le flickering aux frontières
	if new_layer != current_layer:
		var layer_data := WorldLayerTypes.get_layer_data(new_layer)
		var min_alt: float = layer_data.get("altitude_min", 0.0)
		var max_alt: float = layer_data.get("altitude_max", 0.0)
		
		# Vérifier si on est assez loin de la frontière
		var distance_from_min: float = absf(altitude - min_alt)
		var distance_from_max: float = absf(altitude - max_alt)
		var min_distance: float = minf(distance_from_min, distance_from_max)
		
		if min_distance >= layer_hysteresis or new_layer == _previous_layer:
			_transition_to_layer(new_layer)
	
	_last_altitude = altitude


func _transition_to_layer(new_layer: WorldLayerTypes.LayerType) -> void:
	"""Effectue la transition vers une nouvelle couche."""
	var old_layer := current_layer
	_previous_layer = old_layer
	current_layer = new_layer
	current_layer_data = WorldLayerTypes.get_layer_data(new_layer)
	
	if debug_mode:
		print("[WorldLayerManager] Transition: ", 
			WorldLayerTypes.get_layer_name(old_layer), " -> ",
			WorldLayerTypes.get_layer_name(new_layer))
	
	# Notifier les systèmes
	layer_changed.emit(old_layer, new_layer)
	environment_update.emit(current_layer_data)
	
	# Mettre à jour les dangers actifs
	_update_active_hazards()


func _update_active_hazards() -> void:
	"""Met à jour la liste des dangers environnementaux actifs."""
	var old_hazards := active_hazards.duplicate()
	active_hazards.clear()
	
	var new_hazards: Array = current_layer_data.get("hazards", [])
	for hazard in new_hazards:
		active_hazards.append(hazard)
		if hazard not in old_hazards:
			hazard_entered.emit(hazard)
	
	for old_hazard in old_hazards:
		if old_hazard not in active_hazards:
			hazard_exited.emit(old_hazard)


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

## Retourne la couche actuelle
func get_current_layer() -> WorldLayerTypes.LayerType:
	return current_layer


## Retourne les données de la couche actuelle
func get_current_layer_data() -> Dictionary:
	return current_layer_data


## Retourne le nom de la couche actuelle
func get_current_layer_name(english: bool = false) -> String:
	return WorldLayerTypes.get_layer_name(current_layer, english)


## Retourne le niveau de danger actuel
func get_current_danger_level() -> WorldLayerTypes.DangerLevel:
	return WorldLayerTypes.get_danger_level(current_layer)


## Vérifie si la police répond dans la zone actuelle
func has_police_response() -> bool:
	return WorldLayerTypes.has_police_response(current_layer)


## Retourne le multiplicateur de loot actuel
func get_loot_multiplier() -> float:
	return WorldLayerTypes.get_loot_multiplier(current_layer)


## Retourne le multiplicateur de crédits actuel
func get_credit_multiplier() -> float:
	return WorldLayerTypes.get_credit_multiplier(current_layer)


## Retourne les types d'ennemis de la couche actuelle
func get_current_enemy_types() -> Array:
	return WorldLayerTypes.get_enemy_types(current_layer)


## Vérifie si un danger spécifique est actif
func is_hazard_active(hazard_type: String) -> bool:
	return hazard_type in active_hazards


## Force une mise à jour immédiate de la couche
func force_update() -> void:
	if player:
		_check_layer_change()


## Téléporte le joueur vers une couche spécifique (utilitaire)
func teleport_to_layer(target_layer: WorldLayerTypes.LayerType) -> void:
	if not player:
		push_error("[WorldLayerManager] Impossible de téléporter: pas de joueur")
		return
	
	var layer_data := WorldLayerTypes.get_layer_data(target_layer)
	var target_y: float = (layer_data.get("altitude_min", 0.0) + layer_data.get("altitude_max", 0.0)) / 2.0
	
	# Garder X et Z actuels, changer Y
	var new_pos := player.global_position
	new_pos.y = target_y
	player.global_position = new_pos
	
	# Forcer la transition immédiate
	_transition_to_layer(target_layer)
	
	if debug_mode:
		print("[WorldLayerManager] Téléportation vers: ", WorldLayerTypes.get_layer_name(target_layer))


## Retourne l'altitude actuelle du joueur
func get_player_altitude() -> float:
	if player:
		return player.global_position.y
	return 0.0


## Retourne un dictionnaire avec toutes les infos de debug
func get_debug_info() -> Dictionary:
	return {
		"current_layer": WorldLayerTypes.get_layer_name(current_layer),
		"altitude": get_player_altitude(),
		"danger_level": get_current_danger_level(),
		"active_hazards": active_hazards,
		"police_response": has_police_response(),
		"loot_multiplier": get_loot_multiplier(),
		"credit_multiplier": get_credit_multiplier()
	}
