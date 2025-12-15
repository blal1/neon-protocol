# ==============================================================================
# WorldLayerTypes.gd - Définition des Couches du Monde NEON DELTA
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Chaque couche est un biome de gameplay avec ses propres règles:
# - Ennemis spécifiques
# - Tables de loot distinctes
# - Ambiance audio/visuelle unique
# - Règles sociales différentes
# ==============================================================================

extends RefCounted
class_name WorldLayerTypes

# ==============================================================================
# TYPES DE COUCHES
# ==============================================================================

## Les 4 couches verticales de NEON DELTA
enum LayerType {
	DEAD_GROUND = 0,      ## Niveau 0 - Sol Mort
	LIVING_CITY = 1,      ## Niveau +1 à +20 - Ville Vivante
	CORPORATE_TOWERS = 2, ## Niveau +21+ - Tours Corporatistes
	SUBNETWORK = 3        ## Sous-réseau souterrain
}

## Niveau de danger par couche (affecte difficulté et récompenses)
enum DangerLevel {
	EXTREME = 0,   ## Sol Mort & Sous-réseau
	HIGH = 1,      ## Tours Corporatistes
	MODERATE = 2,  ## Ville Vivante (quartiers dangereux)
	LOW = 3        ## Ville Vivante (quartiers sûrs)
}

## Type de règles sociales
enum SocialRules {
	LAWLESS = 0,    ## Aucune loi - Sol Mort
	GANG_TERRITORY = 1,  ## Territoire de gang
	CIVILIAN = 2,   ## Zone civile normale
	CORPORATE = 3,  ## Loi corporatiste stricte
	ABANDONED = 4   ## Zone abandonnée
}

# ==============================================================================
# DONNÉES STATIQUES DES COUCHES
# ==============================================================================

## Configuration statique de chaque couche
const LAYER_DATA: Dictionary = {
	LayerType.DEAD_GROUND: {
		"name": "Sol Mort",
		"name_en": "Dead Ground",
		"description": "Décharges, brume toxique, bidonvilles mobiles, gangs, marchés gris.",
		"altitude_min": -50.0,
		"altitude_max": 0.0,
		"danger_level": DangerLevel.EXTREME,
		"social_rules": SocialRules.LAWLESS,
		"ambient_color": Color(0.2, 0.15, 0.1, 1.0),  # Brun toxique
		"fog_density": 0.08,
		"hazards": ["toxic_fog", "radiation_pockets", "unstable_ground"],
		"enemy_types": ["gang_member", "mutant_rat", "scavenger_drone"],
		"loot_multiplier": 0.8,
		"credit_multiplier": 0.5,
		"police_response": false,
	},
	LayerType.LIVING_CITY: {
		"name": "Ville Vivante",
		"name_en": "Living City",
		"description": "Rails aériens, food stalls, cliniques cyber, bars AR, quartiers résidentiels.",
		"altitude_min": 1.0,
		"altitude_max": 200.0,  # ~20 étages de 10m
		"danger_level": DangerLevel.MODERATE,
		"social_rules": SocialRules.CIVILIAN,
		"ambient_color": Color(0.1, 0.15, 0.25, 1.0),  # Bleu néon
		"fog_density": 0.02,
		"hazards": ["pickpockets", "traffic"],
		"enemy_types": ["street_thug", "rogue_drone", "cyber_junkie"],
		"loot_multiplier": 1.0,
		"credit_multiplier": 1.0,
		"police_response": true,
	},
	LayerType.CORPORATE_TOWERS: {
		"name": "Tours Corporatistes",
		"name_en": "Corporate Towers",
		"description": "Arcologies autonomes, fermes verticales, IA propriétaires, zones interdites.",
		"altitude_min": 201.0,
		"altitude_max": 1000.0,  # Infiniment haut
		"danger_level": DangerLevel.HIGH,
		"social_rules": SocialRules.CORPORATE,
		"ambient_color": Color(0.15, 0.2, 0.3, 1.0),  # Bleu froid corporate
		"fog_density": 0.0,  # Air pur
		"hazards": ["security_turrets", "id_scanners", "lockdown_zones"],
		"enemy_types": ["security_drone", "corporate_guard", "combat_synth"],
		"loot_multiplier": 1.5,
		"credit_multiplier": 2.0,
		"police_response": true,  # Sécurité privée
	},
	LayerType.SUBNETWORK: {
		"name": "Sous-Réseau",
		"name_en": "Subnetwork",
		"description": "Métro abandonné, serveurs oubliés, sanctuaires IA, marchés d'organes.",
		"altitude_min": -200.0,
		"altitude_max": -51.0,
		"danger_level": DangerLevel.EXTREME,
		"social_rules": SocialRules.ABANDONED,
		"ambient_color": Color(0.05, 0.08, 0.12, 1.0),  # Noir-bleu sombre
		"fog_density": 0.05,
		"hazards": ["collapsed_tunnels", "rogue_ai", "organ_harvesters"],
		"enemy_types": ["tunnel_crawler", "rogue_ai_drone", "organ_harvester"],
		"loot_multiplier": 2.0,  # Meilleur loot
		"credit_multiplier": 0.3,  # Peu de crédits, plus de troc
		"police_response": false,
	}
}

# ==============================================================================
# FONCTIONS UTILITAIRES STATIQUES
# ==============================================================================

## Retourne le type de couche basé sur l'altitude Y
static func get_layer_from_altitude(altitude: float) -> LayerType:
	if altitude < -50.0:
		return LayerType.SUBNETWORK
	elif altitude <= 0.0:
		return LayerType.DEAD_GROUND
	elif altitude <= 200.0:
		return LayerType.LIVING_CITY
	else:
		return LayerType.CORPORATE_TOWERS


## Retourne les données d'une couche
static func get_layer_data(layer: LayerType) -> Dictionary:
	return LAYER_DATA.get(layer, LAYER_DATA[LayerType.LIVING_CITY])


## Retourne le nom localisé d'une couche
static func get_layer_name(layer: LayerType, english: bool = false) -> String:
	var data := get_layer_data(layer)
	return data.get("name_en" if english else "name", "Unknown")


## Retourne le niveau de danger d'une couche
static func get_danger_level(layer: LayerType) -> DangerLevel:
	var data := get_layer_data(layer)
	return data.get("danger_level", DangerLevel.MODERATE)


## Vérifie si la police répond dans cette couche
static func has_police_response(layer: LayerType) -> bool:
	var data := get_layer_data(layer)
	return data.get("police_response", false)


## Retourne la couleur ambiante de la couche
static func get_ambient_color(layer: LayerType) -> Color:
	var data := get_layer_data(layer)
	return data.get("ambient_color", Color.WHITE)


## Retourne la densité de brouillard
static func get_fog_density(layer: LayerType) -> float:
	var data := get_layer_data(layer)
	return data.get("fog_density", 0.0)


## Retourne les types d'ennemis de la couche
static func get_enemy_types(layer: LayerType) -> Array:
	var data := get_layer_data(layer)
	return data.get("enemy_types", [])


## Retourne les dangers environnementaux
static func get_hazards(layer: LayerType) -> Array:
	var data := get_layer_data(layer)
	return data.get("hazards", [])


## Retourne le multiplicateur de loot
static func get_loot_multiplier(layer: LayerType) -> float:
	var data := get_layer_data(layer)
	return data.get("loot_multiplier", 1.0)


## Retourne le multiplicateur de crédits
static func get_credit_multiplier(layer: LayerType) -> float:
	var data := get_layer_data(layer)
	return data.get("credit_multiplier", 1.0)
