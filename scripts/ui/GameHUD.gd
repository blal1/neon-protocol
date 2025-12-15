# ==============================================================================
# GameHUD.gd - Interface de jeu principale
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Affiche la mission actuelle, la santé, et les infos importantes
# À placer dans un CanvasLayer
# ==============================================================================

extends CanvasLayer
class_name GameHUD

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal mission_panel_clicked
signal health_low_warning

# ==============================================================================
# RÉFÉRENCES UI (à configurer dans l'éditeur ou via @onready)
# ==============================================================================
@export_group("Mission Panel")
@export var mission_panel: Control
@export var mission_title_label: Label
@export var mission_description_label: Label
@export var mission_progress_label: Label

@export_group("Health Bar")
@export var health_bar: ProgressBar
@export var health_label: Label

@export_group("Credits")
@export var credits_label: Label

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _current_mission_title: String = ""
var _current_mission_desc: String = ""
var _player_health: float = 100.0
var _player_max_health: float = 100.0
var _player_credits: int = 0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du HUD."""
	# Connecter au MissionManager si disponible
	var mission_manager = get_node_or_null("/root/MissionManager")
	if mission_manager:
		if mission_manager.has_signal("mission_started"):
			mission_manager.mission_started.connect(_on_mission_started)
		if mission_manager.has_signal("mission_completed"):
			mission_manager.mission_completed.connect(_on_mission_completed)
		if mission_manager.has_signal("mission_progress_updated"):
			mission_manager.mission_progress_updated.connect(_on_mission_progress)
	
	# Afficher état initial
	_update_ui()


# ==============================================================================
# MISE À JOUR DE LA MISSION
# ==============================================================================

func show_mission(title: String, description: String, is_main_story: bool = false) -> void:
	"""
	Affiche une mission à l'écran.
	@param title: Titre de la mission
	@param description: Description/objectif
	@param is_main_story: True si mission principale (couleur différente)
	"""
	_current_mission_title = title
	_current_mission_desc = description
	
	if mission_title_label:
		mission_title_label.text = "[MISSION] " + title
		# Couleur selon type de mission
		if is_main_story:
			mission_title_label.add_theme_color_override("font_color", Color("ffcc00"))  # Or
		else:
			mission_title_label.add_theme_color_override("font_color", Color("00ffff"))  # Cyan
	
	if mission_description_label:
		mission_description_label.text = "> " + description
	
	if mission_panel:
		mission_panel.visible = true
		# Animation d'apparition
		_animate_panel_in(mission_panel)


func update_mission_progress(current: int, total: int) -> void:
	"""Met à jour la progression de la mission."""
	if mission_progress_label:
		mission_progress_label.text = "Progression: %d / %d" % [current, total]
		mission_progress_label.visible = total > 1


func hide_mission() -> void:
	"""Cache le panneau de mission."""
	if mission_panel:
		mission_panel.visible = false


func show_mission_complete(title: String, reward_credits: int) -> void:
	"""Affiche un message de mission complétée."""
	if mission_title_label:
		mission_title_label.text = "✓ MISSION COMPLÉTÉE"
		mission_title_label.add_theme_color_override("font_color", Color("00ff66"))  # Vert
	
	if mission_description_label:
		mission_description_label.text = title + "\n+ " + str(reward_credits) + " crédits"
	
	# Cacher après quelques secondes
	await get_tree().create_timer(3.0).timeout
	hide_mission()


# ==============================================================================
# MISE À JOUR DE LA SANTÉ
# ==============================================================================

func update_health(current: float, max_health: float) -> void:
	"""
	Met à jour l'affichage de la santé.
	@param current: Santé actuelle
	@param max_health: Santé maximum
	"""
	_player_health = current
	_player_max_health = max_health
	
	var percentage := (current / max_health) * 100.0 if max_health > 0 else 0.0
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current
		
		# Couleur selon niveau
		if percentage > 60:
			health_bar.modulate = Color("00ff66")  # Vert
		elif percentage > 30:
			health_bar.modulate = Color("ffcc00")  # Jaune
		else:
			health_bar.modulate = Color("ff3333")  # Rouge
			health_low_warning.emit()
	
	if health_label:
		health_label.text = "%d / %d" % [int(current), int(max_health)]


# ==============================================================================
# MISE À JOUR DES CRÉDITS
# ==============================================================================

func update_credits(amount: int) -> void:
	"""Met à jour l'affichage des crédits."""
	_player_credits = amount
	
	if credits_label:
		credits_label.text = "₿ " + str(amount)


func add_credits(amount: int) -> void:
	"""Ajoute des crédits avec animation."""
	_player_credits += amount
	update_credits(_player_credits)
	
	# Flash visuel
	if credits_label:
		var original_color := credits_label.modulate
		credits_label.modulate = Color("00ff66")
		await get_tree().create_timer(0.3).timeout
		credits_label.modulate = original_color


# ==============================================================================
# ANIMATIONS
# ==============================================================================

func _animate_panel_in(panel: Control) -> void:
	"""Animation d'apparition d'un panneau."""
	if not panel:
		return
	
	panel.modulate.a = 0.0
	panel.position.x -= 50
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "position:x", panel.position.x + 50, 0.3).set_ease(Tween.EASE_OUT)


func flash_damage() -> void:
	"""Flash rouge quand le joueur prend des dégâts."""
	var flash := ColorRect.new()
	flash.color = Color(1, 0, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)


# ==============================================================================
# CALLBACKS MISSION MANAGER
# ==============================================================================

func _on_mission_started(mission) -> void:
	"""Callback quand une mission démarre."""
	var title: String = mission.title if "title" in mission else str(mission)
	var desc: String = mission.description if "description" in mission else ""
	var is_main: bool = false
	
	show_mission(title, desc, is_main)


func _on_mission_completed(mission) -> void:
	"""Callback quand une mission est complétée."""
	var title: String = mission.title if "title" in mission else str(mission)
	var reward: int = mission.reward_credits if "reward_credits" in mission else 0
	
	show_mission_complete(title, reward)
	add_credits(reward)


func _on_mission_progress(mission, current: int, target: int) -> void:
	"""Callback de progression."""
	update_mission_progress(current, target)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _update_ui() -> void:
	"""Met à jour tout l'UI."""
	update_health(_player_health, _player_max_health)
	update_credits(_player_credits)
	
	if _current_mission_title == "":
		if mission_description_label:
			mission_description_label.text = "En attente de mission..."


func show_notification(text: String, duration: float = 2.0) -> void:
	"""Affiche une notification temporaire."""
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("ffffff"))
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 100
	add_child(label)
	
	# Animation
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
