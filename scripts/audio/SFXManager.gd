# ==============================================================================
# SFXManager.gd - Gestionnaire de sons d'interface et de combat
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Joue les sons UI (2D, bus "UI") et les sons de combat positionnels
# (3D, bus "SFX") à partir des bibliothèques audio/sfx/.
# ==============================================================================

extends Node

# ==============================================================================
# BIBLIOTHÈQUES DE SONS UI
# ==============================================================================
var ui_sounds: Dictionary = {
	"click": [
		"res://audio/sfx/ui/click_001.ogg",
		"res://audio/sfx/ui/click_002.ogg",
		"res://audio/sfx/ui/click_003.ogg",
		"res://audio/sfx/ui/click_004.ogg",
		"res://audio/sfx/ui/click_005.ogg",
	],
	"hover": [
		"res://audio/sfx/ui/select_001.ogg",
		"res://audio/sfx/ui/select_002.ogg",
		"res://audio/sfx/ui/select_003.ogg",
		"res://audio/sfx/ui/select_004.ogg",
	],
	"back": [
		"res://audio/sfx/ui/back_001.ogg",
		"res://audio/sfx/ui/back_002.ogg",
		"res://audio/sfx/ui/back_003.ogg",
		"res://audio/sfx/ui/back_004.ogg",
	],
	"confirm": [
		"res://audio/sfx/ui/confirmation_001.ogg",
		"res://audio/sfx/ui/confirmation_002.ogg",
		"res://audio/sfx/ui/confirmation_003.ogg",
		"res://audio/sfx/ui/confirmation_004.ogg",
	],
	"error": [
		"res://audio/sfx/ui/error_001.ogg",
		"res://audio/sfx/ui/error_002.ogg",
		"res://audio/sfx/ui/error_003.ogg",
		"res://audio/sfx/ui/error_004.ogg",
		"res://audio/sfx/ui/error_005.ogg",
		"res://audio/sfx/ui/error_006.ogg",
		"res://audio/sfx/ui/error_007.ogg",
		"res://audio/sfx/ui/error_008.ogg",
	],
	"open": [
		"res://audio/sfx/ui/open_001.ogg",
		"res://audio/sfx/ui/open_002.ogg",
		"res://audio/sfx/ui/open_003.ogg",
		"res://audio/sfx/ui/open_004.ogg",
	],
	"close": [
		"res://audio/sfx/ui/close_001.ogg",
		"res://audio/sfx/ui/close_002.ogg",
		"res://audio/sfx/ui/close_003.ogg",
		"res://audio/sfx/ui/close_004.ogg",
	],
	"pickup": [
		"res://audio/sfx/ui/pluck_001.ogg",
		"res://audio/sfx/ui/pluck_002.ogg",
	],
	"toggle": [
		"res://audio/sfx/ui/toggle_001.ogg",
		"res://audio/sfx/ui/toggle_002.ogg",
		"res://audio/sfx/ui/toggle_003.ogg",
		"res://audio/sfx/ui/toggle_004.ogg",
	],
	"notification": [
		"res://audio/sfx/ui/bong_001.ogg",
		"res://audio/sfx/ui/scroll_001.ogg",
		"res://audio/sfx/ui/scroll_002.ogg",
		"res://audio/sfx/ui/scroll_003.ogg",
		"res://audio/sfx/ui/scroll_004.ogg",
		"res://audio/sfx/ui/scroll_005.ogg",
	],
	"door_open": [
		"res://audio/sfx/env/doorOpen_000.ogg",
		"res://audio/sfx/env/doorOpen_001.ogg",
		"res://audio/sfx/env/doorOpen_002.ogg",
	],
	"door_close": [
		"res://audio/sfx/env/doorClose_000.ogg",
		"res://audio/sfx/env/doorClose_001.ogg",
		"res://audio/sfx/env/doorClose_002.ogg",
	],
}

# ==============================================================================
# SONS DE COMBAT (joueur)
# ==============================================================================
var combat_sounds: Dictionary = {
	"player_attack": [
		"res://audio/sfx/combat/laserSmall_000.ogg",
		"res://audio/sfx/combat/laserSmall_001.ogg",
		"res://audio/sfx/combat/laserSmall_002.ogg",
		"res://audio/sfx/combat/laserSmall_003.ogg",
		"res://audio/sfx/combat/laserSmall_004.ogg",
	],
	"player_hit": [
		"res://audio/sfx/combat/impactMetal_000.ogg",
		"res://audio/sfx/combat/impactMetal_001.ogg",
		"res://audio/sfx/combat/impactMetal_002.ogg",
		"res://audio/sfx/combat/impactMetal_003.ogg",
		"res://audio/sfx/combat/impactMetal_004.ogg",
	],
	"player_combo_finisher": [
		"res://audio/sfx/combat/laserLarge_000.ogg",
		"res://audio/sfx/combat/laserLarge_001.ogg",
		"res://audio/sfx/combat/laserLarge_002.ogg",
		"res://audio/sfx/combat/laserLarge_003.ogg",
		"res://audio/sfx/combat/laserLarge_004.ogg",
	],
	"explosion": [
		"res://audio/sfx/combat/explosionCrunch_000.ogg",
		"res://audio/sfx/combat/explosionCrunch_001.ogg",
		"res://audio/sfx/combat/explosionCrunch_002.ogg",
		"res://audio/sfx/combat/explosionCrunch_003.ogg",
		"res://audio/sfx/combat/explosionCrunch_004.ogg",
	],
	"heavy_impact": [
		"res://audio/sfx/combat/Impact_1.wav",
		"res://audio/sfx/combat/Impact_2.wav",
	],
}

# ==============================================================================
# SONS D'ENVIRONNEMENT ET TECH
# ==============================================================================
var env_sounds: Dictionary = {
	"footstep_concrete": [
		"res://audio/sfx/env/footstep_concrete_000.ogg",
		"res://audio/sfx/env/footstep_concrete_001.ogg",
		"res://audio/sfx/env/footstep_concrete_002.ogg",
		"res://audio/sfx/env/footstep_concrete_003.ogg",
		"res://audio/sfx/env/footstep_concrete_004.ogg",
	],
	"glitch": [
		"res://audio/sfx/tech/glitch_001.ogg",
		"res://audio/sfx/tech/glitch_002.ogg",
		"res://audio/sfx/tech/glitch_003.ogg",
		"res://audio/sfx/tech/glitch_004.ogg",
	],
	"computer_noise": [
		"res://audio/sfx/tech/computerNoise_000.ogg",
		"res://audio/sfx/tech/computerNoise_001.ogg",
		"res://audio/sfx/tech/computerNoise_002.ogg",
		"res://audio/sfx/tech/computerNoise_003.ogg",
	]
}

# ==============================================================================
# POOLS DE LECTEURS AUDIO
# ==============================================================================
const UI_POOL_SIZE: int = 4
const SFX3D_POOL_SIZE: int = 8

var _ui_players: Array[AudioStreamPlayer] = []
var _ui_next: int = 0

var _sfx3d_players: Array[AudioStreamPlayer3D] = []
var _sfx3d_next: int = 0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Crée les pools de lecteurs audio."""
	for i in range(UI_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "UI"
		add_child(player)
		_ui_players.append(player)

	for i in range(SFX3D_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = 30.0
		player.unit_size = 4.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_sfx3d_players.append(player)


# ==============================================================================
# MÉTHODES PUBLIQUES
# ==============================================================================

func play_ui(category: String) -> void:
	"""Joue un son UI aléatoire de la catégorie donnée (click, hover, back, ...)."""
	if not ui_sounds.has(category):
		return

	var paths: Array = ui_sounds[category]
	if paths.is_empty():
		return

	var path: String = paths.pick_random()
	if not ResourceLoader.exists(path):
		return

	var player := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()

	player.stream = load(path)
	player.play()


func play_combat(category: String, position: Vector3) -> void:
	"""Joue un son de combat positionnel aléatoire à l'emplacement donné."""
	if not combat_sounds.has(category):
		return

	var paths: Array = combat_sounds[category]
	if paths.is_empty():
		return

	var path: String = paths.pick_random()
	if not ResourceLoader.exists(path):
		return

	var player := _sfx3d_players[_sfx3d_next]
	_sfx3d_next = (_sfx3d_next + 1) % _sfx3d_players.size()

	player.stream = load(path)
	player.global_position = position
	player.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
	player.play()


func play_env(category: String, position: Vector3) -> void:
	"""Joue un son d'environnement positionnel (pas, glitch, etc)."""
	if not env_sounds.has(category):
		return

	var paths: Array = env_sounds[category]
	if paths.is_empty():
		return

	var path: String = paths.pick_random()
	if not ResourceLoader.exists(path):
		return

	var player := _sfx3d_players[_sfx3d_next]
	_sfx3d_next = (_sfx3d_next + 1) % _sfx3d_players.size()

	player.stream = load(path)
	player.global_position = position
	player.pitch_scale = 1.0 + randf_range(-0.1, 0.1)
	player.play()
