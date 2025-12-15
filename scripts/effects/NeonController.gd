# ==============================================================================
# NeonController.gd - Contrôleur de Shader Néon
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Permet de contrôler le shader neon_glow depuis GDScript
# Gère les effets de pulsation, changement de couleur, etc.
# ==============================================================================

extends Node3D
class_name NeonController

# ==============================================================================
# CONFIGURATION
# ==============================================================================
@export_group("Cible")
@export var target_mesh: MeshInstance3D  ## Le mesh avec le shader néon

@export_group("Couleurs Présets")
@export var color_cyan: Color = Color(0.0, 1.0, 1.0)
@export var color_magenta: Color = Color(1.0, 0.0, 0.8)
@export var color_yellow: Color = Color(1.0, 0.9, 0.0)
@export var color_red: Color = Color(1.0, 0.1, 0.1)

@export_group("Animation")
@export var auto_flicker: bool = true  ## Activer le flicker automatique
@export var random_offset: bool = true  ## Décalage aléatoire entre néons

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
var _material: ShaderMaterial

# ==============================================================================
# INITIALISATION
# ==============================================================================

func _ready() -> void:
	if target_mesh:
		_material = target_mesh.get_surface_override_material(0) as ShaderMaterial
		if not _material:
			_material = target_mesh.mesh.surface_get_material(0) as ShaderMaterial
	
	if not _material:
		push_warning("NeonController: Aucun ShaderMaterial trouvé sur le mesh cible")
		return
	
	# Décalage aléatoire pour désynchroniser les néons
	if random_offset:
		set_time_offset(randf() * 10.0)
	
	# Activer/désactiver le flicker
	set_flicker_enabled(auto_flicker)


# ==============================================================================
# API PUBLIQUE - Contrôle du Shader
# ==============================================================================

func set_neon_color(color: Color) -> void:
	"""Change la couleur du néon."""
	if _material:
		_material.set_shader_parameter("neon_color", Vector3(color.r, color.g, color.b))


func set_emission_strength(strength: float) -> void:
	"""Définit l'intensité de l'émission (1.0 - 10.0)."""
	if _material:
		_material.set_shader_parameter("emission_strength", clamp(strength, 1.0, 10.0))


func set_flicker_enabled(enabled: bool) -> void:
	"""Active ou désactive le scintillement."""
	if _material:
		_material.set_shader_parameter("flicker_enabled", enabled)


func set_flicker_speed(speed: float) -> void:
	"""Définit la vitesse de pulsation (0.1 - 20.0)."""
	if _material:
		_material.set_shader_parameter("flicker_speed", clamp(speed, 0.1, 20.0))


func set_flicker_intensity(intensity: float) -> void:
	"""Définit l'amplitude du flicker (0.0 - 1.0)."""
	if _material:
		_material.set_shader_parameter("flicker_intensity", clamp(intensity, 0.0, 1.0))


func set_time_offset(offset: float) -> void:
	"""Définit le décalage temporel (désynchronise plusieurs néons)."""
	if _material:
		_material.set_shader_parameter("time_offset", offset)


# ==============================================================================
# EFFETS SPÉCIAUX
# ==============================================================================

func flash(duration: float = 0.2) -> void:
	"""Fait flasher le néon brièvement."""
	if not _material:
		return
	
	var original_strength: float = _material.get_shader_parameter("emission_strength")
	set_emission_strength(10.0)
	
	await get_tree().create_timer(duration).timeout
	set_emission_strength(original_strength)


func pulse_color(target_color: Color, duration: float = 1.0) -> void:
	"""Transition douce vers une nouvelle couleur."""
	if not _material:
		return
	
	var current_color_vec: Vector3 = _material.get_shader_parameter("neon_color")
	var current_color := Color(current_color_vec.x, current_color_vec.y, current_color_vec.z)
	
	var tween := create_tween()
	tween.tween_method(
		func(c: Color): set_neon_color(c),
		current_color,
		target_color,
		duration
	)


func simulate_damage() -> void:
	"""Simule un néon endommagé (flicker intense puis stabilisation)."""
	if not _material:
		return
	
	# Sauvegarder les paramètres actuels
	var original_intensity: float = _material.get_shader_parameter("flicker_intensity")
	var original_speed: float = _material.get_shader_parameter("flicker_speed")
	
	# Flicker intense
	set_flicker_intensity(0.9)
	set_flicker_speed(15.0)
	
	await get_tree().create_timer(0.5).timeout
	
	# Retour progressif à la normale
	var tween := create_tween()
	tween.tween_method(
		func(v: float): set_flicker_intensity(v),
		0.9,
		original_intensity,
		1.0
	)
	tween.parallel().tween_method(
		func(v: float): set_flicker_speed(v),
		15.0,
		original_speed,
		1.0
	)


func turn_off() -> void:
	"""Éteint le néon."""
	set_emission_strength(0.0)


func turn_on(strength: float = 3.0) -> void:
	"""Allume le néon."""
	set_emission_strength(strength)
