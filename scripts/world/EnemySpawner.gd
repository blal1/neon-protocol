# ==============================================================================
# EnemySpawner.gd - Popule la ville avec des menaces
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends Node
class_name EnemySpawner

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/SecurityRobot.tscn")
@export var spawn_density: float = 0.3  ## Probabilité de spawner un ennemi par bâtiment
@export var city_manager: CityManager

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	if not city_manager:
		city_manager = get_node_or_null("../CityManager")
		
	if city_manager:
		city_manager.city_generation_completed.connect(_on_city_generated)


func _on_city_generated(_count: int) -> void:
	"""Appelé quand la ville est prête. Place les ennemis."""
	var current_density = spawn_density
	
	# Ajuster selon le district
	if city_manager and city_manager.has_method("get_current_district_data"):
		var data = city_manager.get_current_district_data()
		if data.has("security_level"):
			current_density = lerp(0.1, 0.8, data.security_level)
			
	var buildings = city_manager.get_all_buildings()
	var spawned_count := 0
	
	for building in buildings:
		if randf() < current_density:
			_spawn_enemy_near(building.global_position)
			spawned_count += 1
			
	print("[EnemySpawner] %d ennemis placés dans la ville (Densité: %.2f)" % [spawned_count, current_density])


func _spawn_enemy_near(pos: Vector3) -> void:
	"""Spawn un ennemi à une position aléatoire autour d'un bâtiment."""
	if not enemy_scene:
		return
		
	var enemy = enemy_scene.instantiate() as Node3D
	# Positionner au sol avec un petit offset
	var offset := Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	enemy.global_position = pos + offset + Vector3(0, 0.5, 0)
	
	# Ajouter au groupe 'enemies' pour le GameManager
	enemy.add_to_group("enemies")
	
	# Connecter le signal de mort si présent
	if enemy.has_signal("died"):
		var gm = get_node_or_null("../GameManager")
		if gm and gm.has_method("_on_enemy_killed"):
			enemy.died.connect(func(): gm._on_enemy_killed(enemy))
	
	add_child(enemy)
