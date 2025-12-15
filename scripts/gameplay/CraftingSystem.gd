# ==============================================================================
# CraftingSystem.gd - Système de crafting
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Permet de combiner des items pour créer de nouveaux objets
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal recipe_learned(recipe_id: String)
signal item_crafted(item_id: String, quantity: int)
signal crafting_failed(reason: String)
signal crafting_started(recipe_id: String)
signal ingredients_missing(missing: Array)

# ==============================================================================
# CLASSES
# ==============================================================================
class Recipe:
	var id: String
	var result_item: String
	var result_quantity: int = 1
	var ingredients: Dictionary = {}  ## item_id -> quantity
	var craft_time: float = 1.0
	var required_station: String = ""  ## "" = craftable partout
	var required_skill: String = ""
	var required_skill_level: int = 0
	var unlock_condition: String = ""
	var category: String = "general"
	
	func _init(_id: String, _result: String, _quantity: int = 1) -> void:
		id = _id
		result_item = _result
		result_quantity = _quantity
	
	func add_ingredient(item_id: String, quantity: int) -> Recipe:
		ingredients[item_id] = quantity
		return self
	
	func set_station(station: String) -> Recipe:
		required_station = station
		return self
	
	func set_skill(skill: String, level: int) -> Recipe:
		required_skill = skill
		required_skill_level = level
		return self

# ==============================================================================
# CATÉGORIES
# ==============================================================================
enum Category {
	CONSUMABLES,
	AMMO,
	UPGRADES,
	EQUIPMENT,
	HACKING,
	SPECIAL
}

# ==============================================================================
# VARIABLES
# ==============================================================================
var recipes: Dictionary = {}  ## recipe_id -> Recipe
var known_recipes: Array[String] = []
var _is_crafting: bool = false

# ==============================================================================
# ITEMS DATABASE
# ==============================================================================
var items_db: Dictionary = {
	# Matériaux de base
	"scrap_metal": {"name": "Ferraille", "type": "material"},
	"circuit_board": {"name": "Circuit imprimé", "type": "material"},
	"wire": {"name": "Câble", "type": "material"},
	"chemical": {"name": "Composé chimique", "type": "material"},
	"battery": {"name": "Batterie", "type": "material"},
	"cyber_component": {"name": "Composant cyber", "type": "material"},
	"data_shard": {"name": "Fragment de données", "type": "material"},
	
	# Consommables
	"health_kit": {"name": "Kit de soins", "type": "consumable", "effect": "heal", "value": 50},
	"health_kit_plus": {"name": "Kit de soins+", "type": "consumable", "effect": "heal", "value": 100},
	"energy_cell": {"name": "Cellule énergétique", "type": "consumable", "effect": "energy", "value": 30},
	"stim_pack": {"name": "Stim Pack", "type": "consumable", "effect": "boost", "value": 20},
	
	# Munitions
	"ammo_pistol": {"name": "Balles Pistolet", "type": "ammo", "weapon": "pistol"},
	"ammo_rifle": {"name": "Chargeur Plasma", "type": "ammo", "weapon": "plasma_rifle"},
	"emp_grenade": {"name": "Grenade EMP", "type": "throwable", "effect": "emp"},
	
	# Upgrades
	"damage_chip": {"name": "Puce de dégâts", "type": "upgrade", "stat": "damage", "value": 10},
	"defense_chip": {"name": "Puce de défense", "type": "upgrade", "stat": "defense", "value": 10},
	"speed_chip": {"name": "Puce de vitesse", "type": "upgrade", "stat": "speed", "value": 5},
	
	# Hacking
	"hack_key_basic": {"name": "Clé hack basique", "type": "hacking", "level": 1},
	"hack_key_advanced": {"name": "Clé hack avancée", "type": "hacking", "level": 2}
}

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_create_recipes()
	
	# Charger les recettes connues
	var save = get_node_or_null("/root/SaveManager")
	if save:
		known_recipes = save.get_value("known_recipes", ["health_kit", "ammo_pistol"])


func open_crafting_ui(category: String = "consumables") -> void:
	"""
	Ouvre l'interface de crafting.
	@param category: Catégorie à afficher par défaut
	"""
	var ui_scene := load("res://scenes/ui/CraftingUI.tscn")
	if ui_scene:
		var ui := ui_scene.instantiate()
		get_tree().root.add_child(ui)
		if ui.has_method("open_to_category"):
			ui.open_to_category(category)



func _create_recipes() -> void:
	"""Crée toutes les recettes."""
	# ========================
	# CONSOMMABLES
	# ========================
	var recipe_health := Recipe.new("health_kit", "health_kit", 1)
	recipe_health.add_ingredient("chemical", 2).add_ingredient("wire", 1)
	recipe_health.category = "consumables"
	recipes["health_kit"] = recipe_health
	
	var recipe_health_plus := Recipe.new("health_kit_plus", "health_kit_plus", 1)
	recipe_health_plus.add_ingredient("health_kit", 2).add_ingredient("cyber_component", 1)
	recipe_health_plus.category = "consumables"
	recipes["health_kit_plus"] = recipe_health_plus
	
	var recipe_energy := Recipe.new("energy_cell", "energy_cell", 2)
	recipe_energy.add_ingredient("battery", 1).add_ingredient("wire", 2)
	recipe_energy.category = "consumables"
	recipes["energy_cell"] = recipe_energy
	
	var recipe_stim := Recipe.new("stim_pack", "stim_pack", 1)
	recipe_stim.add_ingredient("chemical", 3).add_ingredient("cyber_component", 1)
	recipe_stim.set_skill("survival", 1)
	recipe_stim.category = "consumables"
	recipes["stim_pack"] = recipe_stim
	
	# ========================
	# MUNITIONS
	# ========================
	var recipe_ammo_pistol := Recipe.new("ammo_pistol", "ammo_pistol", 20)
	recipe_ammo_pistol.add_ingredient("scrap_metal", 2)
	recipe_ammo_pistol.category = "ammo"
	recipes["ammo_pistol"] = recipe_ammo_pistol
	
	var recipe_ammo_rifle := Recipe.new("ammo_rifle", "ammo_rifle", 10)
	recipe_ammo_rifle.add_ingredient("scrap_metal", 2).add_ingredient("battery", 1)
	recipe_ammo_rifle.category = "ammo"
	recipes["ammo_rifle"] = recipe_ammo_rifle
	
	var recipe_emp := Recipe.new("emp_grenade", "emp_grenade", 1)
	recipe_emp.add_ingredient("battery", 2).add_ingredient("circuit_board", 1).add_ingredient("wire", 2)
	recipe_emp.set_skill("hacking", 2)
	recipe_emp.category = "ammo"
	recipes["emp_grenade"] = recipe_emp
	
	# ========================
	# UPGRADES
	# ========================
	var recipe_damage := Recipe.new("damage_chip", "damage_chip", 1)
	recipe_damage.add_ingredient("circuit_board", 2).add_ingredient("cyber_component", 2)
	recipe_damage.set_station("workbench")
	recipe_damage.category = "upgrades"
	recipes["damage_chip"] = recipe_damage
	
	var recipe_defense := Recipe.new("defense_chip", "defense_chip", 1)
	recipe_defense.add_ingredient("circuit_board", 2).add_ingredient("scrap_metal", 3)
	recipe_defense.set_station("workbench")
	recipe_defense.category = "upgrades"
	recipes["defense_chip"] = recipe_defense
	
	var recipe_speed := Recipe.new("speed_chip", "speed_chip", 1)
	recipe_speed.add_ingredient("circuit_board", 1).add_ingredient("cyber_component", 3)
	recipe_speed.set_station("workbench")
	recipe_speed.category = "upgrades"
	recipes["speed_chip"] = recipe_speed
	
	# ========================
	# HACKING
	# ========================
	var recipe_hack_basic := Recipe.new("hack_key_basic", "hack_key_basic", 1)
	recipe_hack_basic.add_ingredient("data_shard", 2).add_ingredient("circuit_board", 1)
	recipe_hack_basic.category = "hacking"
	recipes["hack_key_basic"] = recipe_hack_basic
	
	var recipe_hack_advanced := Recipe.new("hack_key_advanced", "hack_key_advanced", 1)
	recipe_hack_advanced.add_ingredient("data_shard", 4).add_ingredient("cyber_component", 2)
	recipe_hack_advanced.set_skill("hacking", 3)
	recipe_hack_advanced.category = "hacking"
	recipes["hack_key_advanced"] = recipe_hack_advanced


# ==============================================================================
# CRAFTING
# ==============================================================================

func craft(recipe_id: String) -> bool:
	"""Craft un item."""
	if _is_crafting:
		crafting_failed.emit("Crafting en cours")
		return false
	
	# Vérifier la recette
	if not recipes.has(recipe_id):
		crafting_failed.emit("Recette inconnue")
		return false
	
	if not known_recipes.has(recipe_id):
		crafting_failed.emit("Recette non apprise")
		return false
	
	var recipe: Recipe = recipes[recipe_id]
	
	# Vérifier les ingrédients
	var missing := _check_ingredients(recipe)
	if not missing.is_empty():
		ingredients_missing.emit(missing)
		crafting_failed.emit("Ingrédients manquants")
		return false
	
	# Vérifier les skills
	if not recipe.required_skill.is_empty():
		var skills = get_node_or_null("/root/SkillTreeManager")
		if skills and skills.has_method("get_skill_level"):
			var level: int = skills.get_skill_level(recipe.required_skill)
			if level < recipe.required_skill_level:
				crafting_failed.emit("Skill insuffisant: %s niveau %d requis" % [recipe.required_skill, recipe.required_skill_level])
				return false
	
	# Vérifier la station de crafting
	if not recipe.required_station.is_empty():
		if not is_near_station(recipe.required_station):
			crafting_failed.emit("Station requise: " + recipe.required_station)
			var tts = get_node_or_null("/root/TTSManager")
			if tts:
				tts.speak("Station de crafting requise: " + recipe.required_station)
			return false
	
	# Commencer le crafting
	_is_crafting = true
	crafting_started.emit(recipe_id)
	
	# Consommer les ingrédients
	_consume_ingredients(recipe)
	
	# Attendre le temps de craft
	await get_tree().create_timer(recipe.craft_time).timeout
	
	# Donner le résultat
	var inventory = get_node_or_null("/root/InventoryManager")
	if inventory and inventory.has_method("add_item"):
		inventory.add_item(recipe.result_item, recipe.result_quantity)
	
	_is_crafting = false
	item_crafted.emit(recipe.result_item, recipe.result_quantity)
	
	# Notification
	var item_name: String = items_db.get(recipe.result_item, {}).get("name", recipe.result_item)
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_success("🔧 Crafté: %s x%d" % [item_name, recipe.result_quantity])
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Craft réussi: %s" % item_name)
	
	# Stats
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		stats.increment("items_crafted")
	
	return true


func _check_ingredients(recipe: Recipe) -> Array:
	"""Vérifie les ingrédients disponibles."""
	var missing: Array = []
	var inventory = get_node_or_null("/root/InventoryManager")
	
	if not inventory:
		return recipe.ingredients.keys()
	
	for item_id in recipe.ingredients:
		var required: int = recipe.ingredients[item_id]
		var available: int = 0
		
		if inventory.has_method("get_item_count"):
			available = inventory.get_item_count(item_id)
		
		if available < required:
			missing.append({
				"item": item_id,
				"required": required,
				"available": available
			})
	
	return missing


func _consume_ingredients(recipe: Recipe) -> void:
	"""Consomme les ingrédients."""
	var inventory = get_node_or_null("/root/InventoryManager")
	if not inventory:
		return
	
	for item_id in recipe.ingredients:
		var quantity: int = recipe.ingredients[item_id]
		if inventory.has_method("remove_item"):
			inventory.remove_item(item_id, quantity)


# ==============================================================================
# RECETTES
# ==============================================================================

func learn_recipe(recipe_id: String) -> bool:
	"""Apprend une recette."""
	if not recipes.has(recipe_id):
		return false
	
	if known_recipes.has(recipe_id):
		return false
	
	known_recipes.append(recipe_id)
	recipe_learned.emit(recipe_id)
	
	# Sauvegarder
	var save = get_node_or_null("/root/SaveManager")
	if save:
		save.set_value("known_recipes", known_recipes)
	
	var recipe: Recipe = recipes[recipe_id]
	var item_name: String = items_db.get(recipe.result_item, {}).get("name", recipe.result_item)
	
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_achievement("📖 Recette apprise", item_name)
	
	return true


func get_known_recipes() -> Array[String]:
	"""Retourne les recettes connues."""
	return known_recipes


func get_recipe(recipe_id: String) -> Recipe:
	"""Retourne une recette."""
	return recipes.get(recipe_id)


func get_recipes_by_category(category: String) -> Array[Recipe]:
	"""Retourne les recettes d'une catégorie."""
	var result: Array[Recipe] = []
	for recipe_id in known_recipes:
		var recipe: Recipe = recipes.get(recipe_id)
		if recipe and recipe.category == category:
			result.append(recipe)
	return result


func can_craft(recipe_id: String) -> bool:
	"""Vérifie si on peut crafter une recette."""
	if not recipes.has(recipe_id):
		return false
	if not known_recipes.has(recipe_id):
		return false
	
	var recipe: Recipe = recipes[recipe_id]
	var missing := _check_ingredients(recipe)
	return missing.is_empty()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_item_info(item_id: String) -> Dictionary:
	"""Retourne les infos d'un item."""
	return items_db.get(item_id, {})


func get_all_materials() -> Array[String]:
	"""Retourne tous les matériaux."""
	var materials: Array[String] = []
	for item_id in items_db:
		if items_db[item_id].get("type") == "material":
			materials.append(item_id)
	return materials


# ==============================================================================
# STATIONS DE CRAFTING
# ==============================================================================

var current_station: String = ""  ## Station à portée ("", "workbench", etc.)
const STATION_RANGE := 3.0  ## Portée d'interaction avec une station

func is_near_station(station_type: String) -> bool:
	"""
	Vérifie si le joueur est à portée d'une station.
	@param station_type: Type de station ("workbench", etc.)
	@return: true si à portée
	"""
	# Si aucune station requise, toujours OK
	if station_type.is_empty():
		return true
	
	# Vérifier la station actuelle
	if current_station == station_type:
		return true
	
	# Chercher une station à portée
	var player = _find_player()
	if not player:
		return false
	
	var stations := get_tree().get_nodes_in_group("crafting_station")
	for station in stations:
		if not station is Node3D:
			continue
		
		var station_name: String = station.get("station_type") if "station_type" in station else station.name.to_lower()
		if station_name.contains(station_type):
			var distance := player.global_position.distance_to(station.global_position)
			if distance <= STATION_RANGE:
				return true
	
	return false


func set_current_station(station_type: String) -> void:
	"""
	Définit la station à portée (appelé par l'Area3D de la station).
	"""
	current_station = station_type


func clear_current_station() -> void:
	"""Efface la station actuelle (sortie de zone)."""
	current_station = ""


func _find_player() -> Node3D:
	"""Trouve le joueur dans la scène."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node3D:
		return players[0]
	return null

