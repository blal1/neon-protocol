# ==============================================================================
# GameOverMenu.gd - Écran de Game Over
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Menu affiché quand le joueur meurt
# Options: Respawn, Charger, Menu Principal, Quitter
# ==============================================================================

extends CanvasLayer

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal respawn_requested
signal main_menu_requested
signal quit_requested

# ==============================================================================
# CONSTANTES
# ==============================================================================
const RESPAWN_SCENE := "res://scenes/main/Main.tscn"
const MAIN_MENU_SCENE := "res://scenes/main/MainMenu.tscn"

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
var _container: Control
var _title_label: Label
var _stats_container: VBoxContainer
var _buttons_container: VBoxContainer

# Statistiques
var _kills: int = 0
var _time_survived: float = 0.0
var _credits: int = 0

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du menu game over."""
	process_mode = Node.PROCESS_MODE_ALWAYS  # Fonctionne même en pause
	layer = 50
	
	_create_ui()
	_load_stats()
	_animate_entrance()
	
	# TTS announcement
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Game Over. " + _get_stats_summary())


func _input(event: InputEvent) -> void:
	"""Gestion des inputs."""
	if event.is_action_pressed("pause"):
		_on_respawn_pressed()


# ==============================================================================
# CRÉATION UI
# ==============================================================================

func _create_ui() -> void:
	"""Crée l'interface du menu."""
	# Fond sombre
	var background := ColorRect.new()
	background.color = Color(0.02, 0.02, 0.05, 0.9)
	background.anchors_preset = Control.PRESET_FULL_RECT
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	
	# Conteneur principal centré
	_container = CenterContainer.new()
	_container.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_container)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_child(vbox)
	
	# Titre GAME OVER
	_title_label = Label.new()
	_title_label.text = "GAME OVER"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	vbox.add_child(_title_label)
	
	# Sous-titre
	var subtitle := Label.new()
	subtitle.text = "Votre run se termine ici..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(subtitle)
	
	# Stats panel
	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 10)
	vbox.add_child(_stats_container)
	
	# Boutons
	_buttons_container = VBoxContainer.new()
	_buttons_container.add_theme_constant_override("separation", 15)
	_buttons_container.custom_minimum_size.x = 300
	vbox.add_child(_buttons_container)
	
	_add_button("🔄 Réessayer", _on_respawn_pressed)
	_add_button("💾 Charger Partie", _on_load_pressed)
	_add_button("🏠 Menu Principal", _on_main_menu_pressed)
	_add_button("🚪 Quitter", _on_quit_pressed)


func _add_button(text: String, callback: Callable) -> Button:
	"""Ajoute un bouton stylisé."""
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 50
	
	# Style cyberpunk
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	style.border_color = Color(0, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0, 0.3, 0.3)
	hover_style.border_color = Color(0, 1, 1)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0, 0.5, 0.5)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)
	
	button.pressed.connect(callback)
	_buttons_container.add_child(button)
	
	return button


func _add_stat_line(label: String, value: String) -> void:
	"""Ajoute une ligne de statistique."""
	var hbox := HBoxContainer.new()
	
	var label_node := Label.new()
	label_node.text = label
	label_node.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label_node)
	
	var value_node := Label.new()
	value_node.text = value
	value_node.add_theme_color_override("font_color", Color(0, 0.9, 0.9))
	value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_node)
	
	_stats_container.add_child(hbox)


# ==============================================================================
# STATISTIQUES
# ==============================================================================

func _load_stats() -> void:
	"""Charge les statistiques de la session."""
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		if stats.has_method("get_stat"):
			_kills = stats.get_stat("enemies_killed")
			_time_survived = stats.get_stat("session_time")
			_credits = stats.get_stat("credits_earned")
	
	# Afficher les stats
	_add_stat_line("Ennemis éliminés", str(_kills))
	_add_stat_line("Temps survécu", _format_time(_time_survived))
	_add_stat_line("Crédits gagnés", str(_credits) + " ₡")


func _format_time(seconds: float) -> String:
	"""Formate le temps en minutes:secondes."""
	var mins := int(seconds / 60)
	var secs := int(fmod(seconds, 60))
	return "%d:%02d" % [mins, secs]


func _get_stats_summary() -> String:
	"""Retourne un résumé des stats pour TTS."""
	return "%d ennemis éliminés. %s survécu." % [_kills, _format_time(_time_survived)]


# ==============================================================================
# ANIMATION
# ==============================================================================

func _animate_entrance() -> void:
	"""Animation d'entrée du menu."""
	_container.modulate.a = 0.0
	_container.scale = Vector2(0.8, 0.8)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_container, "modulate:a", 1.0, 0.5)
	tween.tween_property(_container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _animate_exit(callback: Callable) -> void:
	"""Animation de sortie du menu."""
	var tween := create_tween()
	tween.tween_property(_container, "modulate:a", 0.0, 0.2)
	tween.tween_callback(callback)


# ==============================================================================
# CALLBACKS BOUTONS
# ==============================================================================

func _on_respawn_pressed() -> void:
	"""Relance le jeu."""
	# Haptic
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_light()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Nouvelle tentative")
	
	_animate_exit(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)


func _on_load_pressed() -> void:
	"""Charge la dernière sauvegarde."""
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_light()
	
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("load_game"):
		_animate_exit(func():
			get_tree().paused = false
			save.load_game(0)
		)
	else:
		var toast = get_node_or_null("/root/ToastNotification")
		if toast:
			toast.show_error("Aucune sauvegarde trouvée")


func _on_main_menu_pressed() -> void:
	"""Retourne au menu principal."""
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_light()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Retour au menu principal")
	
	_animate_exit(func():
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	)


func _on_quit_pressed() -> void:
	"""Quitte le jeu."""
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_light()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Au revoir")
	
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
