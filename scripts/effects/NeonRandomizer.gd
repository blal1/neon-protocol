# ==============================================================================
# NeonRandomizer.gd - Générateur de néons aléatoires
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Attache ce script à un MeshInstance3D avec un ShaderMaterial neon_glow
# Génère des couleurs et effets de clignotement aléatoires
# ==============================================================================

extends MeshInstance3D
class_name NeonRandomizer

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal color_changed(new_color: Color)
signal flicker_started
signal flicker_stopped

# ==============================================================================
# PALETTES DE COULEURS CYBERPUNK
# ==============================================================================
@export_group("Couleurs")
@export var possible_colors: Array[Color] = [
	Color("00ffff"),  # Cyan
	Color("ff0055"),  # Magenta / Rose
	Color("ffff00"),  # Jaune
	Color("00ff66"),  # Vert Matrix
	Color("ff00ff"),  # Violet
	Color("ff6600"),  # Orange
	Color("0099ff"),  # Bleu électrique
	Color("ff3366"),  # Rose vif
]

@export_group("Clignotement")
@export var flicker_chance: float = 0.3  ## Chance (0-1) d'avoir un néon défectueux
@export var flicker_speed_min: float = 5.0  ## Vitesse minimum du flicker
@export var flicker_speed_max: float = 15.0  ## Vitesse maximum du flicker

@export_group("Luminosité")
@export var brightness_min: float = 2.0  ## Luminosité minimum
@export var brightness_max: float = 5.0  ## Luminosité maximum
@export var randomize_brightness: bool = true  ## Varier la luminosité

@export_group("Automatique")
@export var randomize_on_ready: bool = true  ## Appliquer au démarrage
@export var use_unique_material: bool = true  ## Créer une copie du matériau

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_color: Color = Color.CYAN
var current_flicker_speed: float = 0.0
var is_flickering: bool = false
var _material: ShaderMaterial = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation avec randomisation optionnelle."""
	if randomize_on_ready:
		randomize_neon()


# ==============================================================================
# RANDOMISATION
# ==============================================================================

func randomize_neon() -> void:
	"""Applique des paramètres aléatoires au néon."""
	# Créer une copie unique du matériau si demandé
	if use_unique_material:
		_create_unique_material()
	else:
		_material = get_active_material(0) as ShaderMaterial
	
	if not _material:
		push_warning("NeonRandomizer: Pas de ShaderMaterial trouvé sur " + name)
		return
	
	# Couleur aléatoire
	randomize_color()
	
	# Luminosité aléatoire
	if randomize_brightness:
		var brightness := randf_range(brightness_min, brightness_max)
		set_brightness(brightness)
	
	# Clignotement aléatoire
	randomize_flicker()


func randomize_color() -> void:
	"""Choisit une couleur aléatoire parmi la palette."""
	if possible_colors.is_empty():
		return
	
	current_color = possible_colors.pick_random()
	
	if _material:
		_material.set_shader_parameter("neon_color", current_color)
	
	color_changed.emit(current_color)


func randomize_flicker() -> void:
	"""Détermine aléatoirement si le néon clignote."""
	is_flickering = randf() < flicker_chance
	
	if is_flickering:
		current_flicker_speed = randf_range(flicker_speed_min, flicker_speed_max)
		flicker_started.emit()
	else:
		current_flicker_speed = 0.0
		flicker_stopped.emit()
	
	if _material:
		_material.set_shader_parameter("flicker_speed", current_flicker_speed)
		# Si le shader utilise flicker_enabled
		if _material.get_shader_parameter("flicker_enabled") != null:
			_material.set_shader_parameter("flicker_enabled", is_flickering)


# ==============================================================================
# SETTERS MANUELS
# ==============================================================================

func set_color(color: Color) -> void:
	"""Définit manuellement la couleur du néon."""
	current_color = color
	
	if not _material:
		_create_unique_material()
	
	if _material:
		_material.set_shader_parameter("neon_color", color)
	
	color_changed.emit(color)


func set_brightness(value: float) -> void:
	"""Définit la luminosité du néon."""
	if _material:
		# Le shader peut utiliser "brightness" ou "emission_strength"
		if _material.get_shader_parameter("brightness") != null:
			_material.set_shader_parameter("brightness", value)
		elif _material.get_shader_parameter("emission_strength") != null:
			_material.set_shader_parameter("emission_strength", value)


func set_flicker(enabled: bool, speed: float = 10.0) -> void:
	"""Active ou désactive le clignotement."""
	is_flickering = enabled
	current_flicker_speed = speed if enabled else 0.0
	
	if _material:
		_material.set_shader_parameter("flicker_speed", current_flicker_speed)
		if _material.get_shader_parameter("flicker_enabled") != null:
			_material.set_shader_parameter("flicker_enabled", enabled)
	
	if enabled:
		flicker_started.emit()
	else:
		flicker_stopped.emit()


# ==============================================================================
# EFFETS SPÉCIAUX
# ==============================================================================

func pulse(duration: float = 0.5, intensity: float = 2.0) -> void:
	"""Fait pulser le néon brièvement."""
	if not _material:
		return
	
	var original_brightness: float = _material.get_shader_parameter("emission_strength")
	if original_brightness == null:
		original_brightness = _material.get_shader_parameter("brightness")
	if original_brightness == null:
		original_brightness = 3.0
	
	set_brightness(original_brightness * intensity)
	
	await get_tree().create_timer(duration).timeout
	
	set_brightness(original_brightness)


func turn_off(fade_duration: float = 0.0) -> void:
	"""Éteint le néon."""
	if fade_duration > 0.0:
		# Fade out progressif
		var tween := create_tween()
		tween.tween_method(set_brightness, 3.0, 0.0, fade_duration)
	else:
		set_brightness(0.0)


func turn_on(fade_duration: float = 0.0, target_brightness: float = 3.0) -> void:
	"""Allume le néon."""
	if fade_duration > 0.0:
		var tween := create_tween()
		tween.tween_method(set_brightness, 0.0, target_brightness, fade_duration)
	else:
		set_brightness(target_brightness)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _create_unique_material() -> void:
	"""Crée une copie unique du matériau."""
	var original := get_active_material(0)
	if original:
		_material = original.duplicate() as ShaderMaterial
		set_surface_override_material(0, _material)


func get_current_color() -> Color:
	"""Retourne la couleur actuelle."""
	return current_color


func is_flicker_enabled() -> bool:
	"""Retourne true si le clignotement est actif."""
	return is_flickering
