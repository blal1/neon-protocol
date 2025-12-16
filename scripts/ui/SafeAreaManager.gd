# ==============================================================================
# SafeAreaManager.gd - Gestion des zones sûres pour mobiles
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les encoches (notches), coins arrondis et zones système sur mobile.
# Adapte automatiquement l'UI pour rester dans la zone visible.
# ==============================================================================

extends Node
class_name SafeAreaManager

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal safe_area_changed(margins: Dictionary)
signal orientation_changed(is_landscape: bool)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const UPDATE_INTERVAL := 0.5  # Vérifier les changements toutes les 0.5s

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Paramètres")
@export var auto_apply_to_ui: bool = true  ## Appliquer automatiquement aux Controls
@export var debug_overlay: bool = false  ## Afficher les zones de debug

@export_group("Marges Supplémentaires")
@export var extra_margin_top: int = 0  ## Marge additionnelle en haut
@export var extra_margin_bottom: int = 0  ## Marge additionnelle en bas
@export var extra_margin_left: int = 0  ## Marge additionnelle à gauche
@export var extra_margin_right: int = 0  ## Marge additionnelle à droite

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_safe_area: Rect2 = Rect2()
var current_margins: Dictionary = {
	"top": 0,
	"bottom": 0,
	"left": 0,
	"right": 0
}
var is_mobile: bool = false
var is_landscape: bool = true
var _update_timer: float = 0.0
var _registered_controls: Array[Control] = []
var _debug_node: Control = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du gestionnaire de Safe Area."""
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Calcul initial
	_update_safe_area()
	
	# Connecter au signal de redimensionnement
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Créer l'overlay de debug si activé
	if debug_overlay:
		_create_debug_overlay()
	
	print("SafeAreaManager: Initialisé (Mobile: %s)" % is_mobile)


func _process(delta: float) -> void:
	"""Vérifie périodiquement les changements."""
	if not is_mobile:
		return
	
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_safe_area()


# ==============================================================================
# CALCUL DE LA SAFE AREA
# ==============================================================================

func _update_safe_area() -> void:
	"""Met à jour la zone sûre."""
	var screen_size := DisplayServer.screen_get_size()
	var new_safe_area := DisplayServer.get_display_safe_area()
	
	# Fallback si pas de safe area (desktop)
	if new_safe_area == Rect2():
		new_safe_area = Rect2(Vector2.ZERO, screen_size)
	
	# Calculer l'orientation
	var new_landscape := screen_size.x > screen_size.y
	if new_landscape != is_landscape:
		is_landscape = new_landscape
		orientation_changed.emit(is_landscape)
	
	# Si changement détecté
	if new_safe_area != current_safe_area:
		current_safe_area = new_safe_area
		
		# Calculer les marges
		current_margins = {
			"top": int(new_safe_area.position.y) + extra_margin_top,
			"bottom": int(screen_size.y - (new_safe_area.position.y + new_safe_area.size.y)) + extra_margin_bottom,
			"left": int(new_safe_area.position.x) + extra_margin_left,
			"right": int(screen_size.x - (new_safe_area.position.x + new_safe_area.size.x)) + extra_margin_right
		}
		
		safe_area_changed.emit(current_margins)
		
		# Appliquer aux controls enregistrés
		if auto_apply_to_ui:
			_apply_to_registered_controls()
		
		# Mettre à jour le debug
		if _debug_node:
			_update_debug_overlay()
		
		print("SafeAreaManager: Safe Area = %s, Margins = %s" % [current_safe_area, current_margins])


func _on_viewport_size_changed() -> void:
	"""Callback quand le viewport change de taille."""
	_update_safe_area()


# ==============================================================================
# API PUBLIQUE
# ==============================================================================

func get_safe_margins() -> Dictionary:
	"""Retourne les marges de sécurité actuelles."""
	return current_margins


func get_safe_rect() -> Rect2:
	"""Retourne le rectangle de zone sûre."""
	return current_safe_area


func is_in_safe_area(global_position: Vector2) -> bool:
	"""Vérifie si une position est dans la zone sûre."""
	return current_safe_area.has_point(global_position)


func register_control(control: Control) -> void:
	"""
	Enregistre un Control pour ajustement automatique.
	Le Control recevra des marges pour rester dans la zone sûre.
	"""
	if control and not _registered_controls.has(control):
		_registered_controls.append(control)
		_apply_margins_to_control(control)


func unregister_control(control: Control) -> void:
	"""Désenregistre un Control."""
	_registered_controls.erase(control)


func apply_to_container(container: Container) -> void:
	"""Applique les marges à un Container."""
	if not container:
		return
	
	container.add_theme_constant_override("margin_top", current_margins.top)
	container.add_theme_constant_override("margin_bottom", current_margins.bottom)
	container.add_theme_constant_override("margin_left", current_margins.left)
	container.add_theme_constant_override("margin_right", current_margins.right)


func create_safe_margin_container() -> MarginContainer:
	"""Crée un MarginContainer avec les bonnes marges."""
	var container := MarginContainer.new()
	container.name = "SafeMarginContainer"
	container.anchors_preset = Control.PRESET_FULL_RECT
	
	container.add_theme_constant_override("margin_top", current_margins.top)
	container.add_theme_constant_override("margin_bottom", current_margins.bottom)
	container.add_theme_constant_override("margin_left", current_margins.left)
	container.add_theme_constant_override("margin_right", current_margins.right)
	
	return container


# ==============================================================================
# APPLICATION AUX CONTROLS
# ==============================================================================

func _apply_to_registered_controls() -> void:
	"""Applique les marges à tous les controls enregistrés."""
	for control in _registered_controls:
		if is_instance_valid(control):
			_apply_margins_to_control(control)


func _apply_margins_to_control(control: Control) -> void:
	"""Applique les marges à un control selon son type."""
	if not control:
		return
	
	# MarginContainer - utiliser les overrides de theme
	if control is MarginContainer:
		control.add_theme_constant_override("margin_top", current_margins.top)
		control.add_theme_constant_override("margin_bottom", current_margins.bottom)
		control.add_theme_constant_override("margin_left", current_margins.left)
		control.add_theme_constant_override("margin_right", current_margins.right)
	
	# Autres Controls - ajuster les anchors
	elif control.anchors_preset == Control.PRESET_FULL_RECT:
		control.offset_top = current_margins.top
		control.offset_bottom = -current_margins.bottom
		control.offset_left = current_margins.left
		control.offset_right = -current_margins.right


# ==============================================================================
# UTILITAIRES POUR LES COINS
# ==============================================================================

func get_corner_safe_position(corner: int) -> Vector2:
	"""
	Retourne une position sûre pour un coin donné.
	corner: 0=TopLeft, 1=TopRight, 2=BottomLeft, 3=BottomRight
	"""
	match corner:
		0:  # Top Left
			return Vector2(current_margins.left, current_margins.top)
		1:  # Top Right
			return Vector2(
				get_viewport().get_visible_rect().size.x - current_margins.right,
				current_margins.top
			)
		2:  # Bottom Left
			return Vector2(
				current_margins.left,
				get_viewport().get_visible_rect().size.y - current_margins.bottom
			)
		3:  # Bottom Right
			return Vector2(
				get_viewport().get_visible_rect().size.x - current_margins.right,
				get_viewport().get_visible_rect().size.y - current_margins.bottom
			)
		_:
			return Vector2.ZERO


func is_corner_safe(corner: int, element_size: Vector2) -> bool:
	"""Vérifie si un élément de taille donnée tiendra dans un coin."""
	var margin_needed: Vector2
	match corner:
		0: margin_needed = Vector2(current_margins.left, current_margins.top)
		1: margin_needed = Vector2(current_margins.right, current_margins.top)
		2: margin_needed = Vector2(current_margins.left, current_margins.bottom)
		3: margin_needed = Vector2(current_margins.right, current_margins.bottom)
		_: margin_needed = Vector2.ZERO
	
	return element_size.x <= margin_needed.x * 2 or element_size.y <= margin_needed.y * 2


# ==============================================================================
# DEBUG OVERLAY
# ==============================================================================

func _create_debug_overlay() -> void:
	"""Crée un overlay de visualisation de la safe area."""
	_debug_node = Control.new()
	_debug_node.name = "SafeAreaDebug"
	_debug_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_node.anchors_preset = Control.PRESET_FULL_RECT
	_debug_node.z_index = 100
	
	add_child(_debug_node)
	_debug_node.draw.connect(_on_debug_draw)
	_update_debug_overlay()


func _update_debug_overlay() -> void:
	"""Met à jour l'overlay de debug."""
	if _debug_node:
		_debug_node.queue_redraw()


func _on_debug_draw() -> void:
	"""Dessine les zones de debug."""
	if not _debug_node:
		return
	
	var screen_size := _debug_node.get_rect().size
	var danger_color := Color(1, 0, 0, 0.3)  # Rouge transparent
	var safe_color := Color(0, 1, 0, 0.1)  # Vert transparent
	
	# Zone danger (hors safe area)
	# Top
	_debug_node.draw_rect(
		Rect2(0, 0, screen_size.x, current_margins.top),
		danger_color
	)
	# Bottom
	_debug_node.draw_rect(
		Rect2(0, screen_size.y - current_margins.bottom, screen_size.x, current_margins.bottom),
		danger_color
	)
	# Left
	_debug_node.draw_rect(
		Rect2(0, current_margins.top, current_margins.left, screen_size.y - current_margins.top - current_margins.bottom),
		danger_color
	)
	# Right
	_debug_node.draw_rect(
		Rect2(screen_size.x - current_margins.right, current_margins.top, current_margins.right, screen_size.y - current_margins.top - current_margins.bottom),
		danger_color
	)
	
	# Contour de la zone sûre
	var safe_rect := Rect2(
		current_margins.left,
		current_margins.top,
		screen_size.x - current_margins.left - current_margins.right,
		screen_size.y - current_margins.top - current_margins.bottom
	)
	_debug_node.draw_rect(safe_rect, Color.GREEN, false, 2.0)


func toggle_debug() -> void:
	"""Active/Désactive l'overlay de debug."""
	debug_overlay = not debug_overlay
	
	if debug_overlay and not _debug_node:
		_create_debug_overlay()
	elif not debug_overlay and _debug_node:
		_debug_node.queue_free()
		_debug_node = null
