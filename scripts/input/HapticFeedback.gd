# ==============================================================================
# HapticFeedback.gd - Retour haptique pour mobile
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les vibrations sur appareils mobiles
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal haptic_triggered(intensity: float)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const VIBRATION_LIGHT := 20
const VIBRATION_MEDIUM := 50
const VIBRATION_HEAVY := 100
const VIBRATION_IMPACT := 150

# ==============================================================================
# VARIABLES
# ==============================================================================
var enabled: bool = true
var intensity_multiplier: float = 1.0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	# Charger les préférences
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("get_setting"):
		enabled = save.get_setting("haptic_enabled", true)
		intensity_multiplier = save.get_setting("haptic_intensity", 1.0)


# ==============================================================================
# VIBRATIONS PRÉDÉFINIES
# ==============================================================================

func vibrate_light() -> void:
	"""Vibration légère (UI, collecte)."""
	_vibrate(VIBRATION_LIGHT)


func vibrate_medium() -> void:
	"""Vibration moyenne (attaque, interaction)."""
	_vibrate(VIBRATION_MEDIUM)


func vibrate_heavy() -> void:
	"""Vibration forte (dégâts, impact)."""
	_vibrate(VIBRATION_HEAVY)


func vibrate_impact() -> void:
	"""Vibration d'impact (grosse explosion, mort)."""
	_vibrate(VIBRATION_IMPACT)


# ==============================================================================
# PATTERNS PRÉDÉFINIS
# ==============================================================================

func vibrate_attack() -> void:
	"""Pattern pour attaque."""
	_vibrate(40)


func vibrate_hit() -> void:
	"""Pattern pour dégâts reçus."""
	_vibrate(80)
	await get_tree().create_timer(0.1).timeout
	_vibrate(30)


func vibrate_dash() -> void:
	"""Pattern pour dash."""
	_vibrate(30)


func vibrate_combo(combo_level: int) -> void:
	"""Pattern pour combo (intensité croissante)."""
	var intensity := 30 + (combo_level * 15)
	_vibrate(min(intensity, 150))


func vibrate_critical() -> void:
	"""Pattern pour coup critique."""
	_vibrate(60)
	await get_tree().create_timer(0.05).timeout
	_vibrate(100)


func vibrate_death() -> void:
	"""Pattern pour mort du joueur."""
	_vibrate(150)
	await get_tree().create_timer(0.15).timeout
	_vibrate(100)
	await get_tree().create_timer(0.15).timeout
	_vibrate(50)


func vibrate_level_up() -> void:
	"""Pattern pour level up."""
	_vibrate(40)
	await get_tree().create_timer(0.1).timeout
	_vibrate(60)
	await get_tree().create_timer(0.1).timeout
	_vibrate(80)


func vibrate_achievement() -> void:
	"""Pattern pour achievement."""
	_vibrate(50)
	await get_tree().create_timer(0.15).timeout
	_vibrate(50)


func vibrate_notification() -> void:
	"""Pattern pour notification."""
	_vibrate(25)


func vibrate_error() -> void:
	"""Pattern pour erreur."""
	_vibrate(30)
	await get_tree().create_timer(0.08).timeout
	_vibrate(30)
	await get_tree().create_timer(0.08).timeout
	_vibrate(30)


# ==============================================================================
# PATTERNS PERSONNALISÉS
# ==============================================================================

func vibrate_pattern(durations: Array[int], pause_ms: int = 50) -> void:
	"""
	Exécute un pattern de vibration personnalisé.
	@param durations: Tableau de durées en ms
	@param pause_ms: Pause entre les vibrations
	"""
	for duration in durations:
		_vibrate(duration)
		await get_tree().create_timer(float(duration + pause_ms) / 1000.0).timeout


func vibrate_custom(duration_ms: int) -> void:
	"""Vibration personnalisée avec durée."""
	_vibrate(duration_ms)


# ==============================================================================
# FONCTION PRINCIPALE
# ==============================================================================

func _vibrate(duration_ms: int) -> void:
	"""Exécute la vibration."""
	if not enabled:
		return
	
	# Appliquer le multiplicateur
	var adjusted_duration := int(duration_ms * intensity_multiplier)
	
	# Vérifier si on est sur mobile
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(adjusted_duration)
		haptic_triggered.emit(float(adjusted_duration) / 150.0)
	else:
		# Sur PC, on peut simuler avec un effet visuel ou audio
		haptic_triggered.emit(float(adjusted_duration) / 150.0)


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func set_enabled(value: bool) -> void:
	"""Active/désactive le retour haptique."""
	enabled = value
	
	# Sauvegarder
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("set_setting"):
		save.set_setting("haptic_enabled", value)


func set_intensity(value: float) -> void:
	"""Définit l'intensité (0.0 - 2.0)."""
	intensity_multiplier = clamp(value, 0.0, 2.0)
	
	# Sauvegarder
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("set_setting"):
		save.set_setting("haptic_intensity", intensity_multiplier)


func is_enabled() -> bool:
	"""Retourne si le haptique est activé."""
	return enabled


func get_intensity() -> float:
	"""Retourne l'intensité actuelle."""
	return intensity_multiplier


func is_supported() -> bool:
	"""Vérifie si le haptique est supporté."""
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
