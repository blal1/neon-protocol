# ==============================================================================
# LazyLoader.gd - Système de chargement paresseux
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Charge les systèmes lourds uniquement quand nécessaire pour économiser
# la mémoire et le temps de démarrage sur mobile.
# ==============================================================================

extends Node
class_name LazyLoader

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal system_loaded(system_name: String)
signal system_unloaded(system_name: String)
signal loading_started(system_name: String)
signal loading_failed(system_name: String, error: String)

# ==============================================================================
# CONFIGURATION DES SYSTÈMES LAZY-LOADABLES
# ==============================================================================

## Systèmes qui peuvent être chargés à la demande
const LAZY_SYSTEMS: Dictionary = {
	# Systèmes de gameplay (charger en jeu seulement)
	"CraftingSystem": {
		"script": "res://scripts/gameplay/CraftingSystem.gd",
		"category": "gameplay",
		"description": "Système de crafting d'items"
	},
	"ShopSystem": {
		"script": "res://scripts/systems/ShopSystem.gd",
		"category": "gameplay",
		"description": "Système de boutique"
	},
	"DialogueSystem": {
		"script": "res://scripts/ui/DialogueSystem.gd",
		"scene": "res://scenes/ui/DialogueSystem.tscn",
		"category": "gameplay",
		"description": "Système de dialogues"
	},
	
	# Systèmes avancés (charger à la demande)
	"HackingMinigame": {
		"script": "res://scripts/gameplay/HackingMinigame.gd",
		"scene": "res://scenes/ui/HackingMinigame.tscn",
		"category": "minigame",
		"description": "Mini-jeu de hacking"
	},
	"VehicleController": {
		"script": "res://scripts/gameplay/VehicleController.gd",
		"category": "gameplay",
		"description": "Contrôle des véhicules"
	},
	
	# UI lourdes
	"CraftingUI": {
		"scene": "res://scenes/ui/CraftingUI.tscn",
		"category": "ui",
		"description": "Interface de crafting"
	},
	"SkillTreeUI": {
		"scene": "res://scenes/ui/SkillTreeUI.tscn",
		"category": "ui",
		"description": "Interface de l'arbre de talents"
	}
}

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _loaded_systems: Dictionary = {}  # system_name -> Node instance
var _loading_in_progress: Dictionary = {}  # system_name -> bool
var _usage_counts: Dictionary = {}  # system_name -> int (pour auto-unload)
var _last_used: Dictionary = {}  # system_name -> timestamp

## Temps avant déchargement automatique (secondes)
@export var auto_unload_delay: float = 120.0

## Activer le déchargement automatique
@export var auto_unload_enabled: bool = true

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du LazyLoader."""
	print("LazyLoader: Initialisé avec %d systèmes lazy-loadables" % LAZY_SYSTEMS.size())


func _process(delta: float) -> void:
	"""Vérifie les systèmes à décharger."""
	if not auto_unload_enabled:
		return
	
	var current_time := Time.get_ticks_msec() / 1000.0
	var to_unload: Array[String] = []
	
	for system_name in _loaded_systems.keys():
		if _usage_counts.get(system_name, 0) <= 0:
			var last_use: float = _last_used.get(system_name, 0)
			if current_time - last_use > auto_unload_delay:
				to_unload.append(system_name)
	
	for system_name in to_unload:
		unload_system(system_name)


# ==============================================================================
# API PRINCIPALE
# ==============================================================================

func get_system(system_name: String) -> Node:
	"""
	Récupère un système, le chargeant si nécessaire.
	@param system_name: Nom du système (clé dans LAZY_SYSTEMS)
	@return: L'instance du système ou null si échec
	"""
	# Déjà chargé ?
	if _loaded_systems.has(system_name):
		_mark_used(system_name)
		return _loaded_systems[system_name]
	
	# Charger si pas en cours
	if not _loading_in_progress.get(system_name, false):
		return await load_system(system_name)
	
	# Attendre chargement en cours
	while _loading_in_progress.get(system_name, false):
		await get_tree().process_frame
	
	return _loaded_systems.get(system_name)


func load_system(system_name: String) -> Node:
	"""
	Charge un système à la demande.
	@return: L'instance chargée ou null
	"""
	if not LAZY_SYSTEMS.has(system_name):
		push_error("LazyLoader: Système inconnu: " + system_name)
		loading_failed.emit(system_name, "Système inconnu")
		return null
	
	if _loaded_systems.has(system_name):
		return _loaded_systems[system_name]
	
	_loading_in_progress[system_name] = true
	loading_started.emit(system_name)
	
	var config: Dictionary = LAZY_SYSTEMS[system_name]
	var instance: Node = null
	
	# Charger depuis une scène
	if config.has("scene"):
		var scene_path: String = config.scene
		if ResourceLoader.exists(scene_path):
			var scene := load(scene_path) as PackedScene
			if scene:
				instance = scene.instantiate()
		else:
			push_error("LazyLoader: Scène introuvable: " + scene_path)
	
	# Charger depuis un script
	elif config.has("script"):
		var script_path: String = config.script
		if ResourceLoader.exists(script_path):
			var script := load(script_path) as GDScript
			if script:
				instance = Node.new()
				instance.set_script(script)
		else:
			push_error("LazyLoader: Script introuvable: " + script_path)
	
	# Finaliser
	if instance:
		instance.name = system_name
		add_child(instance)
		_loaded_systems[system_name] = instance
		_mark_used(system_name)
		_usage_counts[system_name] = 1
		
		print("LazyLoader: %s chargé" % system_name)
		system_loaded.emit(system_name)
	else:
		loading_failed.emit(system_name, "Échec de l'instantiation")
	
	_loading_in_progress[system_name] = false
	return instance


func unload_system(system_name: String) -> bool:
	"""
	Décharge un système de la mémoire.
	@return: true si déchargé avec succès
	"""
	if not _loaded_systems.has(system_name):
		return false
	
	var instance: Node = _loaded_systems[system_name]
	
	# Appeler cleanup si disponible
	if instance.has_method("cleanup"):
		instance.cleanup()
	
	instance.queue_free()
	_loaded_systems.erase(system_name)
	_usage_counts.erase(system_name)
	_last_used.erase(system_name)
	
	print("LazyLoader: %s déchargé" % system_name)
	system_unloaded.emit(system_name)
	return true


func retain_system(system_name: String) -> void:
	"""Retient un système (ne sera pas auto-déchargé)."""
	_usage_counts[system_name] = _usage_counts.get(system_name, 0) + 1
	_mark_used(system_name)


func release_system(system_name: String) -> void:
	"""Libère un système (peut être auto-déchargé)."""
	_usage_counts[system_name] = maxi(0, _usage_counts.get(system_name, 0) - 1)


func _mark_used(system_name: String) -> void:
	"""Marque un système comme utilisé."""
	_last_used[system_name] = Time.get_ticks_msec() / 1000.0


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func is_loaded(system_name: String) -> bool:
	"""Vérifie si un système est chargé."""
	return _loaded_systems.has(system_name)


func is_loading(system_name: String) -> bool:
	"""Vérifie si un système est en cours de chargement."""
	return _loading_in_progress.get(system_name, false)


func get_loaded_systems() -> Array[String]:
	"""Retourne la liste des systèmes chargés."""
	var result: Array[String] = []
	for key in _loaded_systems.keys():
		result.append(key)
	return result


func get_memory_estimate() -> int:
	"""Estime la mémoire utilisée par les systèmes chargés (approximatif)."""
	# Estimation basique par système
	return _loaded_systems.size() * 1024 * 50  # ~50KB par système


func preload_category(category: String) -> void:
	"""Précharge tous les systèmes d'une catégorie."""
	for system_name in LAZY_SYSTEMS.keys():
		var config: Dictionary = LAZY_SYSTEMS[system_name]
		if config.get("category", "") == category:
			load_system(system_name)


func unload_category(category: String) -> void:
	"""Décharge tous les systèmes d'une catégorie."""
	var to_unload: Array[String] = []
	
	for system_name in _loaded_systems.keys():
		if LAZY_SYSTEMS.has(system_name):
			var config: Dictionary = LAZY_SYSTEMS[system_name]
			if config.get("category", "") == category:
				to_unload.append(system_name)
	
	for system_name in to_unload:
		unload_system(system_name)


func get_system_info(system_name: String) -> Dictionary:
	"""Retourne les informations sur un système."""
	if not LAZY_SYSTEMS.has(system_name):
		return {}
	
	var config: Dictionary = LAZY_SYSTEMS[system_name].duplicate()
	config["is_loaded"] = is_loaded(system_name)
	config["usage_count"] = _usage_counts.get(system_name, 0)
	config["last_used"] = _last_used.get(system_name, 0)
	
	return config
