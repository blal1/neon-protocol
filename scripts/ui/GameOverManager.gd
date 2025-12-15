# ==============================================================================
# GameOverManager.gd - Système de mort et respawn
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère l'écran de mort, respawn, et continue
# ==============================================================================

extends CanvasLayer

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal player_died
signal player_respawned
signal game_over_shown
signal continue_selected
signal quit_selected

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var respawn_delay: float = 2.0
@export var fade_duration: float = 0.5
@export var lives: int = 3
@export var respawn_position: Vector3 = Vector3.ZERO

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_lives: int = 3
var is_dead: bool = false
var _player: Node3D = null

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _stats_label: Label
var _continue_button: Button
var _quit_button: Button

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	current_lives = lives
	_create_ui()
	_find_player()
	
	# Écouter la mort du joueur
	if _player:
		var health = _player.get_node_or_null("HealthComponent")
		if health:
			health.died.connect(_on_player_died)


func _input(event: InputEvent) -> void:
	"""Gestion des inputs."""
	if is_dead and event.is_action_pressed("ui_accept"):
		_on_continue_pressed()


# ==============================================================================
# CRÉATION UI
# ==============================================================================

func _create_ui() -> void:
	"""Crée l'interface de game over."""
	# Overlay sombre
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	
	# Conteneur centré
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.visible = false
	add_child(center)
	
	# Panel principal
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 300)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.02, 0.02, 0.95)
	panel_style.border_color = Color(0.8, 0.1, 0.1, 1)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)
	
	# Conteneur vertical
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_child(vbox)
	_panel.add_child(margin)
	
	# Titre
	_title_label = Label.new()
	_title_label.text = "💀 SYSTÈME COMPROMIS"
	_title_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)
	
	# Stats
	_stats_label = Label.new()
	_stats_label.text = "Vies restantes: 3"
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_stats_label)
	
	# Séparateur
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.5, 0.1, 0.1, 0.5))
	vbox.add_child(sep)
	
	# Boutons
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	
	# Bouton continuer
	_continue_button = Button.new()
	_continue_button.text = "▶ CONTINUER"
	_continue_button.custom_minimum_size = Vector2(140, 50)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.2, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.3, 0.8, 0.3)
	btn_style.set_corner_radius_all(5)
	_continue_button.add_theme_stylebox_override("normal", btn_style)
	_continue_button.pressed.connect(_on_continue_pressed)
	buttons.add_child(_continue_button)
	
	# Bouton quitter
	_quit_button = Button.new()
	_quit_button.text = "✕ QUITTER"
	_quit_button.custom_minimum_size = Vector2(140, 50)
	var quit_style := StyleBoxFlat.new()
	quit_style.bg_color = Color(0.5, 0.2, 0.2, 0.9)
	quit_style.set_border_width_all(1)
	quit_style.border_color = Color(0.8, 0.3, 0.3)
	quit_style.set_corner_radius_all(5)
	_quit_button.add_theme_stylebox_override("normal", quit_style)
	_quit_button.pressed.connect(_on_quit_pressed)
	buttons.add_child(_quit_button)


# ==============================================================================
# GAME OVER
# ==============================================================================

func _on_player_died() -> void:
	"""Appelé quand le joueur meurt."""
	if is_dead:
		return
	
	is_dead = true
	current_lives -= 1
	player_died.emit()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Système compromis")
	
	# Fade in
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.8, fade_duration)
	await tween.finished
	
	# Afficher le panel
	_show_game_over()


func _show_game_over() -> void:
	"""Affiche l'écran de game over."""
	# Mettre à jour les stats
	if current_lives > 0:
		_stats_label.text = "Vies restantes: %d" % current_lives
		_continue_button.visible = true
		_title_label.text = "💀 SYSTÈME COMPROMIS"
	else:
		_stats_label.text = "GAME OVER - Aucune vie restante"
		_continue_button.visible = false
		_title_label.text = "☠️ GAME OVER"
	
	# Afficher le panel
	_panel.get_parent().visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Pause du jeu
	get_tree().paused = true
	
	game_over_shown.emit()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		if current_lives > 0:
			tts.speak("%d vies restantes. Appuyez pour continuer." % current_lives)
		else:
			tts.speak("Game over. Plus de vies.")


func _on_continue_pressed() -> void:
	"""Continue la partie."""
	if current_lives <= 0:
		return
	
	continue_selected.emit()
	
	# Cacher le panel
	_panel.get_parent().visible = false
	
	# Respawn
	_respawn_player()


func _on_quit_pressed() -> void:
	"""Retourne au menu principal."""
	quit_selected.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _respawn_player() -> void:
	"""Fait réapparaître le joueur."""
	if not _player:
		_find_player()
	
	if not _player:
		return
	
	# Fade out overlay
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, fade_duration)
	
	# Réactiver le joueur
	var health = _player.get_node_or_null("HealthComponent")
	if health and health.has_method("reset"):
		health.reset()
	elif health:
		health.current_health = health.max_health
		health.is_dead = false
	
	# Repositionner
	if respawn_position != Vector3.ZERO:
		_player.global_position = respawn_position
	
	# Reprendre le jeu
	is_dead = false
	get_tree().paused = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	player_respawned.emit()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Système réinitialisé")


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		
		# Re-connecter le signal de mort
		var health = _player.get_node_or_null("HealthComponent")
		if health and not health.died.is_connected(_on_player_died):
			health.died.connect(_on_player_died)


func reset_lives() -> void:
	"""Réinitialise les vies."""
	current_lives = lives
	is_dead = false


func add_life() -> void:
	"""Ajoute une vie."""
	current_lives += 1


func get_lives() -> int:
	"""Retourne le nombre de vies."""
	return current_lives
