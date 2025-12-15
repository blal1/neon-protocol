# ==============================================================================
# EnemyAudioController.gd - Contrôleur audio pour ennemis
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les sons spatiaux des ennemis pour accessibilité
# ==============================================================================

extends Node
class_name EnemyAudioController

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal enemy_audio_played(enemy: Node3D, sound_type: String)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var enabled: bool = true
@export var footstep_interval: float = 0.5
@export var idle_sound_interval: float = 3.0
@export var volume_db: float = -3.0

# ==============================================================================
# SONS PAR TYPE D'ENNEMI
# ==============================================================================
var enemy_sounds: Dictionary = {
	"robot": {
		"footstep": "res://audio/sfx/ui/click_003.ogg",
		"idle": "res://audio/sfx/combat/computerNoise_000.ogg",
		"alert": "res://audio/sfx/ui/error_001.ogg",
		"attack": "res://audio/sfx/combat/impactMetal_000.ogg",
		"death": "res://audio/sfx/combat/explosionCrunch_000.ogg"
	},
	"drone": {
		"footstep": "res://audio/sfx/combat/spaceEngine_000.ogg",
		"idle": "res://audio/sfx/combat/engineCircular_000.ogg",
		"alert": "res://audio/sfx/ui/error_003.ogg",
		"attack": "res://audio/sfx/combat/laserSmall_000.ogg",
		"death": "res://audio/sfx/combat/lowFrequency_explosion_000.ogg"
	},
	"turret": {
		"idle": "res://audio/sfx/combat/forceField_000.ogg",
		"alert": "res://audio/sfx/ui/maximize_001.ogg",
		"attack": "res://audio/sfx/combat/laserLarge_000.ogg"
	},
	"boss": {
		"footstep": "res://audio/sfx/combat/impactMetal_001.ogg",
		"idle": "res://audio/sfx/combat/thrusterFire_000.ogg",
		"alert": "res://audio/navigation/493162__breviceps__submarine-sonar.wav",
		"attack": "res://audio/sfx/combat/laserLarge_001.ogg",
		"death": "res://audio/sfx/combat/explosionCrunch_001.ogg"
	}
}

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _enemy_audio_players: Dictionary = {}  # enemy -> AudioStreamPlayer3D
var _enemy_timers: Dictionary = {}  # enemy -> {footstep: float, idle: float}

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _process(delta: float) -> void:
	"""Mise à jour des sons d'ennemis."""
	if not enabled:
		return
	
	var enemies := get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		
		# Créer le player audio si nécessaire
		if not _enemy_audio_players.has(enemy):
			_setup_enemy_audio(enemy)
		
		# Mettre à jour les timers
		_update_enemy_sounds(enemy, delta)


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _setup_enemy_audio(enemy: Node3D) -> void:
	"""Configure l'audio pour un ennemi."""
	var audio := AudioStreamPlayer3D.new()
	audio.max_distance = 25.0
	audio.unit_size = 2.0
	audio.volume_db = volume_db
	audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	enemy.add_child(audio)
	
	_enemy_audio_players[enemy] = audio
	_enemy_timers[enemy] = {
		"footstep": 0.0,
		"idle": randf() * idle_sound_interval  # Décalage aléatoire
	}
	
	# Connecter les signaux de mort
	if enemy.has_node("HealthComponent"):
		var health := enemy.get_node("HealthComponent")
		if not health.died.is_connected(_on_enemy_died.bind(enemy)):
			health.died.connect(_on_enemy_died.bind(enemy))


func _update_enemy_sounds(enemy: Node3D, delta: float) -> void:
	"""Met à jour les sons d'un ennemi."""
	if not _enemy_timers.has(enemy):
		return
	
	var timers: Dictionary = _enemy_timers[enemy]
	var enemy_type := _get_enemy_type(enemy)
	var sounds: Dictionary = enemy_sounds.get(enemy_type, enemy_sounds["robot"])
	
	# Vérifier si l'ennemi bouge
	var is_moving := false
	if enemy is CharacterBody3D:
		is_moving = enemy.velocity.length() > 0.5
	
	# Sons de pas
	if is_moving and sounds.has("footstep"):
		timers["footstep"] += delta
		if timers["footstep"] >= footstep_interval:
			timers["footstep"] = 0.0
			_play_enemy_sound(enemy, "footstep")
	
	# Sons d'idle
	if sounds.has("idle"):
		timers["idle"] += delta
		if timers["idle"] >= idle_sound_interval:
			timers["idle"] = 0.0
			_play_enemy_sound(enemy, "idle")


# ==============================================================================
# LECTURE
# ==============================================================================

func _play_enemy_sound(enemy: Node3D, sound_type: String) -> void:
	"""Joue un son pour un ennemi."""
	if not _enemy_audio_players.has(enemy):
		return
	
	var audio: AudioStreamPlayer3D = _enemy_audio_players[enemy]
	var enemy_type := _get_enemy_type(enemy)
	var sounds: Dictionary = enemy_sounds.get(enemy_type, enemy_sounds["robot"])
	
	if not sounds.has(sound_type):
		return
	
	var path: String = sounds[sound_type]
	if not ResourceLoader.exists(path):
		return
	
	audio.stream = load(path)
	audio.pitch_scale = 1.0 + randf_range(-0.1, 0.1)
	audio.play()
	
	enemy_audio_played.emit(enemy, sound_type)


func play_alert(enemy: Node3D) -> void:
	"""Joue le son d'alerte."""
	_play_enemy_sound(enemy, "alert")


func play_attack(enemy: Node3D) -> void:
	"""Joue le son d'attaque."""
	_play_enemy_sound(enemy, "attack")


func play_death(enemy: Node3D) -> void:
	"""Joue le son de mort."""
	_play_enemy_sound(enemy, "death")


# ==============================================================================
# ÉVÉNEMENTS
# ==============================================================================

func _on_enemy_died(enemy: Node3D) -> void:
	"""Appelé quand un ennemi meurt."""
	play_death(enemy)
	
	# Nettoyer après un délai
	await get_tree().create_timer(2.0).timeout
	
	if _enemy_audio_players.has(enemy):
		_enemy_audio_players.erase(enemy)
	if _enemy_timers.has(enemy):
		_enemy_timers.erase(enemy)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _get_enemy_type(enemy: Node3D) -> String:
	"""Détermine le type d'ennemi."""
	if enemy.is_in_group("drone"):
		return "drone"
	elif enemy.is_in_group("turret"):
		return "turret"
	elif enemy.is_in_group("boss"):
		return "boss"
	else:
		return "robot"


func cleanup_dead_enemies() -> void:
	"""Nettoie les références aux ennemis morts."""
	var to_remove: Array = []
	
	for enemy in _enemy_audio_players:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
	
	for enemy in to_remove:
		_enemy_audio_players.erase(enemy)
		_enemy_timers.erase(enemy)
