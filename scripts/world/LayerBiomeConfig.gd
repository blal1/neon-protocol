# ==============================================================================
# LayerBiomeConfig.gd - Configuration de Biome par Couche
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Resource exportable pour configurer chaque biome de manière modulaire.
# Peut être créée dans l'éditeur comme fichier .tres
# ==============================================================================

extends Resource
class_name LayerBiomeConfig

# ==============================================================================
# IDENTIFICATION
# ==============================================================================

## Type de couche associée
@export var layer_type: WorldLayerTypes.LayerType = WorldLayerTypes.LayerType.LIVING_CITY

## Nom affiché du biome
@export var display_name: String = "Unnamed Biome"

## Description pour le joueur
@export_multiline var description: String = ""

# ==============================================================================
# ENVIRONNEMENT VISUEL
# ==============================================================================

@export_group("Visuel")

## Couleur ambiante de la couche
@export var ambient_color: Color = Color(0.1, 0.15, 0.25, 1.0)

## Couleur du brouillard
@export var fog_color: Color = Color(0.05, 0.05, 0.1, 1.0)

## Densité du brouillard (0 = pas de brouillard)
@export_range(0.0, 0.2, 0.01) var fog_density: float = 0.02

## Distance de début du brouillard
@export var fog_start_distance: float = 20.0

## Distance de fin du brouillard
@export var fog_end_distance: float = 100.0

## Intensité de la lumière directionnelle
@export_range(0.0, 2.0, 0.1) var sun_intensity: float = 1.0

## Couleur de la lumière directionnelle
@export var sun_color: Color = Color.WHITE

## Shader d'effets post-process (optionnel)
@export var post_process_shader: Shader

# ==============================================================================
# ENVIRONNEMENT AUDIO
# ==============================================================================

@export_group("Audio")

## Piste audio ambiante principale
@export var ambient_music: AudioStream

## Sons d'ambiance additionnels (loop)
@export var ambient_sounds: Array[AudioStream] = []

## Volume de la musique ambiante (dB)
@export_range(-40.0, 0.0, 1.0) var music_volume_db: float = -10.0

## Volume des sons d'ambiance (dB)
@export_range(-40.0, 0.0, 1.0) var ambient_volume_db: float = -15.0

# ==============================================================================
# GAMEPLAY - ENNEMIS
# ==============================================================================

@export_group("Ennemis")

## Types d'ennemis pouvant spawner
@export var enemy_types: Array[String] = []

## Scenes d'ennemis à instancier
@export var enemy_scenes: Array[PackedScene] = []

## Probabilité de spawn (par seconde)
@export_range(0.0, 1.0, 0.01) var spawn_rate: float = 0.1

## Nombre maximum d'ennemis simultanés
@export var max_enemies: int = 10

## Niveau minimum des ennemis (affecte stats)
@export var enemy_level_min: int = 1

## Niveau maximum des ennemis
@export var enemy_level_max: int = 5

# ==============================================================================
# GAMEPLAY - LOOT
# ==============================================================================

@export_group("Loot")

## Multiplicateur de drop rate
@export_range(0.1, 3.0, 0.1) var loot_multiplier: float = 1.0

## Multiplicateur de crédits gagnés
@export_range(0.1, 3.0, 0.1) var credit_multiplier: float = 1.0

## Rareté minimum des drops
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var min_rarity: int = 0

## Types de loot spéciaux à cette couche
@export var special_loot_types: Array[String] = []

# ==============================================================================
# GAMEPLAY - DANGERS
# ==============================================================================

@export_group("Dangers")

## Types de dangers environnementaux
@export var hazard_types: Array[String] = []

## Dégâts par seconde du danger principal (si applicable)
@export var hazard_damage_per_second: float = 0.0

## Intervalle entre les ticks de dégâts
@export var hazard_tick_interval: float = 1.0

## Effet de statut appliqué par les dangers
@export var hazard_status_effect: String = ""

# ==============================================================================
# GAMEPLAY - RÈGLES SOCIALES
# ==============================================================================

@export_group("Règles Sociales")

## Type de règles sociales
@export var social_rules: WorldLayerTypes.SocialRules = WorldLayerTypes.SocialRules.CIVILIAN

## La police/sécurité répond-elle aux crimes?
@export var police_response: bool = true

## Temps avant que la police n'arrive (secondes)
@export var police_response_time: float = 30.0

## Niveau de réputation requis pour accès
@export var required_reputation: int = 0

## Factions dominantes dans cette zone
@export var dominant_factions: Array[String] = []

# ==============================================================================
# GÉNÉRATION PROCÉDURALE
# ==============================================================================

@export_group("Génération")

## Scenes de bâtiments/structures à placer
@export var structure_prefabs: Array[PackedScene] = []

## Probabilités de chaque structure (doit correspondre à structure_prefabs)
@export var structure_weights: Array[float] = []

## Scenes de décorations/props
@export var decoration_prefabs: Array[PackedScene] = []

## Densité de décorations
@export_range(0.0, 1.0, 0.05) var decoration_density: float = 0.3

## Scenes de points d'intérêt (shops, marchés, etc.)
@export var poi_prefabs: Array[PackedScene] = []

## Nombre de POIs par chunk
@export var pois_per_chunk: int = 2

# ==============================================================================
# MÉTHODES UTILITAIRES
# ==============================================================================

## Retourne un ennemi aléatoire pondéré
func get_random_enemy_scene() -> PackedScene:
	if enemy_scenes.is_empty():
		return null
	return enemy_scenes[randi() % enemy_scenes.size()]


## Retourne une structure aléatoire pondérée
func get_weighted_structure() -> PackedScene:
	if structure_prefabs.is_empty():
		return null
	
	if structure_weights.is_empty() or structure_weights.size() != structure_prefabs.size():
		return structure_prefabs[randi() % structure_prefabs.size()]
	
	var total_weight := 0.0
	for w in structure_weights:
		total_weight += w
	
	var roll := randf() * total_weight
	var cumulative := 0.0
	
	for i in range(structure_weights.size()):
		cumulative += structure_weights[i]
		if roll <= cumulative:
			return structure_prefabs[i]
	
	return structure_prefabs[0]


## Retourne une décoration aléatoire
func get_random_decoration() -> PackedScene:
	if decoration_prefabs.is_empty():
		return null
	return decoration_prefabs[randi() % decoration_prefabs.size()]


## Retourne un POI aléatoire
func get_random_poi() -> PackedScene:
	if poi_prefabs.is_empty():
		return null
	return poi_prefabs[randi() % poi_prefabs.size()]


## Vérifie si le joueur peut accéder à cette zone
func can_player_access(player_reputation: int) -> bool:
	return player_reputation >= required_reputation


## Retourne le niveau d'ennemi aléatoire dans la plage configurée
func get_random_enemy_level() -> int:
	return randi_range(enemy_level_min, enemy_level_max)
