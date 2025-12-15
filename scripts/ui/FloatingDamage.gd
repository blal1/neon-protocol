# ==============================================================================
# FloatingDamage.gd - Système de texte de dégâts flottants
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Affiche les dégâts au-dessus des ennemis/joueur
# ==============================================================================

extends Node
class_name FloatingDamage

# ==============================================================================
# CONSTANTES
# ==============================================================================
const FLOAT_SPEED := 50.0
const FLOAT_DURATION := 1.0
const SPREAD_RANGE := 20.0

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var damage_color: Color = Color(1.0, 0.3, 0.3)
@export var heal_color: Color = Color(0.3, 1.0, 0.4)
@export var crit_color: Color = Color(1.0, 0.8, 0.0)
@export var font_size: int = 24
@export var crit_font_size: int = 36

# ==============================================================================
# POOL DE LABELS
# ==============================================================================
var _label_pool: Array[Label] = []
var _pool_size: int = 20
var _canvas_layer: CanvasLayer

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_create_ui_layer()
	_create_label_pool()


func _create_ui_layer() -> void:
	"""Crée le layer UI pour les labels."""
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	add_child(_canvas_layer)


func _create_label_pool() -> void:
	"""Crée le pool de labels."""
	for i in range(_pool_size):
		var label := Label.new()
		label.visible = false
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", damage_color)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_canvas_layer.add_child(label)
		_label_pool.append(label)


func _get_available_label() -> Label:
	"""Retourne un label disponible."""
	for label in _label_pool:
		if not label.visible:
			return label
	
	# Créer un nouveau si nécessaire
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	_canvas_layer.add_child(label)
	_label_pool.append(label)
	return label


# ==============================================================================
# AFFICHAGE DES DÉGÂTS
# ==============================================================================

func show_damage(world_position: Vector3, amount: float, is_crit: bool = false) -> void:
	"""
	Affiche un nombre de dégâts flottant.
	@param world_position: Position 3D mondiale
	@param amount: Montant des dégâts
	@param is_crit: Si c'est un coup critique
	"""
	var label := _get_available_label()
	
	# Configurer le texte
	label.text = str(int(amount))
	
	if is_crit:
		label.text = "💥 " + label.text + " !"
		label.add_theme_color_override("font_color", crit_color)
		label.add_theme_font_size_override("font_size", crit_font_size)
	else:
		label.add_theme_color_override("font_color", damage_color)
		label.add_theme_font_size_override("font_size", font_size)
	
	# Position initiale (à convertir en screen space)
	_animate_floating(label, world_position)


func show_heal(world_position: Vector3, amount: float) -> void:
	"""Affiche un montant de soin."""
	var label := _get_available_label()
	
	label.text = "+" + str(int(amount))
	label.add_theme_color_override("font_color", heal_color)
	label.add_theme_font_size_override("font_size", font_size)
	
	_animate_floating(label, world_position, true)


func show_text(world_position: Vector3, text: String, color: Color = Color.WHITE) -> void:
	"""Affiche un texte personnalisé."""
	var label := _get_available_label()
	
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	
	_animate_floating(label, world_position)


func show_miss(world_position: Vector3) -> void:
	"""Affiche 'MISS'."""
	show_text(world_position, "MISS", Color(0.7, 0.7, 0.7))


func show_blocked(world_position: Vector3) -> void:
	"""Affiche 'BLOQUÉ'."""
	show_text(world_position, "🛡️", Color(0.5, 0.7, 1.0))


# ==============================================================================
# ANIMATION
# ==============================================================================

func _animate_floating(label: Label, world_pos: Vector3, is_heal: bool = false) -> void:
	"""Anime le label flottant vers le haut."""
	label.visible = true
	label.modulate.a = 1.0
	label.scale = Vector2.ONE
	
	# Ajouter un peu de variation horizontale
	var offset_x := randf_range(-SPREAD_RANGE, SPREAD_RANGE)
	var start_screen_pos := _world_to_screen(world_pos)
	
	if start_screen_pos == Vector2.ZERO:
		label.visible = false
		return
	
	label.position = start_screen_pos + Vector2(offset_x, 0)
	
	# Animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Montée
	var float_direction := -1.0 if not is_heal else -1.0
	var end_y := label.position.y + (float_direction * FLOAT_SPEED * FLOAT_DURATION)
	
	# Scale pop pour les crits
	if label.text.contains("💥"):
		tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	
	# Float up
	tween.tween_property(label, "position:y", end_y, FLOAT_DURATION)
	
	# Fade out
	tween.parallel().tween_property(label, "modulate:a", 0.0, FLOAT_DURATION * 0.7).set_delay(FLOAT_DURATION * 0.3)
	
	# Cacher à la fin
	tween.tween_callback(func(): label.visible = false)


func _world_to_screen(world_pos: Vector3) -> Vector2:
	"""Convertit une position 3D en position écran."""
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector2.ZERO
	
	if not camera.is_position_behind(world_pos):
		return camera.unproject_position(world_pos)
	
	return Vector2.ZERO


# ==============================================================================
# SINGLETON
# ==============================================================================

static var _instance: FloatingDamage = null

static func get_instance() -> FloatingDamage:
	"""Retourne l'instance singleton."""
	if not _instance:
		_instance = FloatingDamage.new()
	return _instance
