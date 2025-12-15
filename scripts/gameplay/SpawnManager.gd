# ==============================================================================
# SpawnManager.gd - Gestionnaire de spawn d'ennemis
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les vagues d'ennemis et spawns progressifs
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node3D)
signal all_waves_completed
signal spawn_point_activated(spawn_point: Node3D)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum SpawnMode { WAVE, CONTINUOUS, TRIGGERED, ARENA }

# ==============================================================================
# CLASSES
# ==============================================================================
class WaveData:
	var enemies: Array[Dictionary] = []  # {scene, count, delay}
	var spawn_delay: float = 0.5
	var bonus_credits: int = 100
	
	func add_enemy(scene_path: String, count: int, spawn_delay: float = 0.5) -> void:
		enemies.append({
			"scene": scene_path,
			"count": count,
			"delay": spawn_delay
		})

# ==============================================================================
# CONSTANTES ENNEMIS
# ==============================================================================
const ENEMY_SCENES := {
	"robot": "res://scenes/enemies/SecurityRobot.tscn",
	"drone": "res://scenes/enemies/EnemyDrone.tscn",
	"turret": "res://scenes/enemies/EnemyTurret.tscn",
	"boss": "res://scenes/enemies/BossEnemy.tscn"
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var spawn_mode: SpawnMode = SpawnMode.WAVE
@export var max_waves: int = 5
@export var enemies_per_wave_base: int = 3
@export var enemies_per_wave_increase: int = 2
@export var time_between_waves: float = 10.0
@export var spawn_radius: float = 15.0
@export var max_active_enemies: int = 10

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_wave: int = 0
var active_enemies: Array[Node3D] = []
var spawn_points: Array[Node3D] = []
var is_spawning: bool = false
var _predefined_waves: Array[WaveData] = []

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_find_spawn_points()
	_setup_default_waves()


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _find_spawn_points() -> void:
	"""Trouve tous les points de spawn dans la scène."""
	spawn_points = []
	var points := get_tree().get_nodes_in_group("spawn_point")
	for point in points:
		if point is Node3D:
			spawn_points.append(point)
	
	print("SpawnManager: %d points de spawn trouvés" % spawn_points.size())


func _setup_default_waves() -> void:
	"""Configure les vagues par défaut."""
	_predefined_waves.clear()
	
	# Vague 1: Robots basiques
	var wave1 := WaveData.new()
	wave1.add_enemy("robot", 3, 0.5)
	wave1.bonus_credits = 50
	_predefined_waves.append(wave1)
	
	# Vague 2: Robots + Drones
	var wave2 := WaveData.new()
	wave2.add_enemy("robot", 3, 0.5)
	wave2.add_enemy("drone", 2, 0.5)
	wave2.bonus_credits = 100
	_predefined_waves.append(wave2)
	
	# Vague 3: Mix + Turrets
	var wave3 := WaveData.new()
	wave3.add_enemy("robot", 4, 0.5)
	wave3.add_enemy("drone", 3, 0.5)
	wave3.add_enemy("turret", 1, 0.5)
	wave3.bonus_credits = 150
	_predefined_waves.append(wave3)
	
	# Vague 4: Intense
	var wave4 := WaveData.new()
	wave4.add_enemy("robot", 5, 0.3)
	wave4.add_enemy("drone", 4, 0.3)
	wave4.add_enemy("turret", 2, 0.5)
	wave4.bonus_credits = 200
	_predefined_waves.append(wave4)
	
	# Vague 5: Boss
	var wave5 := WaveData.new()
	wave5.add_enemy("robot", 2, 0.5)
	wave5.add_enemy("boss", 1, 1.0)
	wave5.bonus_credits = 500
	_predefined_waves.append(wave5)
	
	max_waves = _predefined_waves.size()


# ==============================================================================
# GESTION DES VAGUES
# ==============================================================================

func start_waves() -> void:
	"""Démarre le système de vagues."""
	if is_spawning:
		return
	
	is_spawning = true
	current_wave = 0
	_start_next_wave()


func _start_next_wave() -> void:
	"""Démarre la prochaine vague."""
	if current_wave >= max_waves:
		_complete_all_waves()
		return
	
	current_wave += 1
	wave_started.emit(current_wave)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Vague %d sur %d" % [current_wave, max_waves])
	
	# Toast
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show("⚔️ Vague %d / %d" % [current_wave, max_waves], 3)
	
	# Spawner les ennemis de la vague
	if current_wave <= _predefined_waves.size():
		await _spawn_wave(_predefined_waves[current_wave - 1])
	else:
		await _spawn_procedural_wave()


func _spawn_wave(wave_data: WaveData) -> void:
	"""Spawn une vague prédéfinie."""
	for enemy_data in wave_data.enemies:
		var scene_key: String = enemy_data["scene"]
		var count: int = enemy_data["count"]
		var delay: float = enemy_data["delay"]
		
		var scene_path: String = ENEMY_SCENES.get(scene_key, "")
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			continue
		
		for i in range(count):
			# Attendre s'il y a trop d'ennemis actifs
			while active_enemies.size() >= max_active_enemies:
				await get_tree().create_timer(0.5).timeout
			
			_spawn_enemy(scene_path)
			await get_tree().create_timer(delay).timeout
	
	# Attendre que tous les ennemis soient morts
	while active_enemies.size() > 0:
		await get_tree().create_timer(0.5).timeout
	
	_complete_wave(wave_data.bonus_credits)


func _spawn_procedural_wave() -> void:
	"""Spawn une vague générée procéduralement."""
	var enemy_count := enemies_per_wave_base + (current_wave - 1) * enemies_per_wave_increase
	
	for i in range(enemy_count):
		while active_enemies.size() >= max_active_enemies:
			await get_tree().create_timer(0.5).timeout
		
		# Choisir un type d'ennemi aléatoirement
		var types := ["robot", "drone"]
		if current_wave >= 3:
			types.append("turret")
		
		var random_type: String = types[randi() % types.size()]
		var scene_path: String = ENEMY_SCENES.get(random_type, "")
		
		if scene_path and ResourceLoader.exists(scene_path):
			_spawn_enemy(scene_path)
		
		await get_tree().create_timer(0.5).timeout
	
	# Attendre que tous soient morts
	while active_enemies.size() > 0:
		await get_tree().create_timer(0.5).timeout
	
	_complete_wave(current_wave * 50)


func _complete_wave(bonus_credits: int) -> void:
	"""Termine une vague."""
	wave_completed.emit(current_wave)
	
	# Bonus de crédits
	var inventory = get_node_or_null("/root/InventoryManager")
	if inventory:
		inventory.add_credits(bonus_credits)
	
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_success("✓ Vague %d terminée! +%d ¥" % [current_wave, bonus_credits])
	
	# Pause avant la prochaine vague
	if current_wave < max_waves:
		await get_tree().create_timer(time_between_waves).timeout
		_start_next_wave()
	else:
		_complete_all_waves()


func _complete_all_waves() -> void:
	"""Toutes les vagues terminées."""
	is_spawning = false
	all_waves_completed.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Toutes les vagues terminées! Victoire!")
	
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_achievement("Toutes les vagues terminées!")
	
	# Musique victoire
	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.play_victory()


# ==============================================================================
# SPAWN D'ENNEMIS
# ==============================================================================

func _spawn_enemy(scene_path: String) -> Node3D:
	"""Spawn un ennemi."""
	if not ResourceLoader.exists(scene_path):
		push_warning("SpawnManager: Scène introuvable: " + scene_path)
		return null
	
	var scene := load(scene_path) as PackedScene
	var enemy := scene.instantiate()
	
	# Position de spawn
	var spawn_pos := _get_spawn_position()
	enemy.global_position = spawn_pos
	
	# Ajouter à la scène
	get_tree().current_scene.add_child(enemy)
	
	# Tracking
	active_enemies.append(enemy)
	
	# Connecter le signal de mort
	if enemy.has_node("HealthComponent"):
		var health := enemy.get_node("HealthComponent")
		health.died.connect(_on_enemy_died.bind(enemy))
	elif enemy.has_signal("destroyed"):
		enemy.destroyed.connect(_on_enemy_died.bind(enemy))
	
	enemy_spawned.emit(enemy)
	
	# Stats
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		stats.increment("enemies_spawned")
	
	return enemy


func _get_spawn_position() -> Vector3:
	"""Retourne une position de spawn."""
	# Utiliser un point de spawn s'il y en a
	if spawn_points.size() > 0:
		var point: Node3D = spawn_points[randi() % spawn_points.size()]
		spawn_point_activated.emit(point)
		return point.global_position
	
	# Sinon, spawner dans un rayon autour de l'origine
	var angle := randf() * TAU
	var distance := randf_range(spawn_radius * 0.5, spawn_radius)
	return Vector3(cos(angle) * distance, 1, sin(angle) * distance)


func _on_enemy_died(enemy: Node3D) -> void:
	"""Appelé quand un ennemi meurt."""
	if active_enemies.has(enemy):
		active_enemies.erase(enemy)
	
	# Stats
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		stats.on_enemy_killed(enemy)


# ==============================================================================
# MODES SPÉCIAUX
# ==============================================================================

func start_continuous_spawn(interval: float = 5.0) -> void:
	"""Démarre un spawn continu."""
	spawn_mode = SpawnMode.CONTINUOUS
	is_spawning = true
	
	while is_spawning:
		if active_enemies.size() < max_active_enemies:
			var types := ENEMY_SCENES.keys()
			var random_type: String = types[randi() % (types.size() - 1)]  # Exclure boss
			var scene_path: String = ENEMY_SCENES.get(random_type, "")
			
			if scene_path:
				_spawn_enemy(scene_path)
		
		await get_tree().create_timer(interval).timeout


func stop_spawning() -> void:
	"""Arrête le spawn."""
	is_spawning = false


func spawn_at_point(point_name: String, enemy_type: String = "robot") -> Node3D:
	"""Spawn un ennemi à un point spécifique."""
	var scene_path: String = ENEMY_SCENES.get(enemy_type, "")
	if scene_path.is_empty():
		return null
	
	var point: Node3D = null
	for sp in spawn_points:
		if sp.name == point_name:
			point = sp
			break
	
	if not point:
		return null
	
	var enemy := _spawn_enemy(scene_path)
	if enemy:
		enemy.global_position = point.global_position
	
	return enemy


func clear_all_enemies() -> void:
	"""Supprime tous les ennemis actifs."""
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_enemy_count() -> int:
	"""Retourne le nombre d'ennemis actifs."""
	return active_enemies.size()


func get_current_wave() -> int:
	"""Retourne la vague actuelle."""
	return current_wave


func add_spawn_point(point: Node3D) -> void:
	"""Ajoute un point de spawn."""
	if point and point not in spawn_points:
		spawn_points.append(point)


func remove_spawn_point(point: Node3D) -> void:
	"""Retire un point de spawn."""
	spawn_points.erase(point)
