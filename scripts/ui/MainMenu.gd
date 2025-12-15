# ==============================================================================
# MainMenu.gd - Script du menu principal
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends Control

func _ready() -> void:
	"""Initialisation du menu."""
	# Annoncer via TTS pour accessibilité
	var tts = get_node_or_null("/root/TTSManager")
	if tts and tts.has_method("speak"):
		tts.speak("Menu principal. Neon Protocol.")


func _on_play_pressed() -> void:
	"""Lance le jeu."""
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _on_options_pressed() -> void:
	"""Ouvre les options."""
	# Charger et afficher le menu options
	var options_scene := load("res://scenes/ui/OptionsMenu.tscn")
	if options_scene:
		var options_menu := options_scene.instantiate()
		add_child(options_menu)
		
		# TTS feedback
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Menu options ouvert")
	else:
		push_warning("MainMenu: OptionsMenu.tscn non trouvé")


func _on_accessibility_pressed() -> void:
	"""Ouvre le menu accessibilité."""
	# Créer le menu accessibilité dynamiquement
	_show_accessibility_menu()


func _show_accessibility_menu() -> void:
	"""Affiche un menu flottant d'accessibilité."""
	# Créer le panneau
	var panel := PanelContainer.new()
	panel.name = "AccessibilityMenu"
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	style.border_color = Color(0, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	# Centrer le panneau
	panel.anchors_preset = Control.PRESET_CENTER
	panel.size = Vector2(400, 350)
	panel.position = get_viewport_rect().size / 2 - panel.size / 2
	
	# Conteneur avec marge
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Titre
	var title := Label.new()
	title.text = "♿ Accessibilité"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0, 0.9, 0.9))
	vbox.add_child(title)
	
	# Options d'accessibilité
	var accessibility_manager = get_node_or_null("/root/AccessibilityManager")
	var blind_manager = get_node_or_null("/root/BlindAccessibilityManager")
	
	# Toggle Mode Aveugle
	var blind_toggle := _create_toggle("🔊 Mode Audio (Non-voyants)", 
		blind_manager != null and blind_manager.is_active if blind_manager and "is_active" in blind_manager else false,
		func(toggled_on: bool):
			if blind_manager:
				blind_manager.toggle()
	)
	vbox.add_child(blind_toggle)
	
	# Toggle Mode Dyslexie
	var dyslexia_enabled := false
	if accessibility_manager and accessibility_manager.has_method("is_dyslexia_mode_enabled"):
		dyslexia_enabled = accessibility_manager.is_dyslexia_mode_enabled()
	var dyslexia_toggle := _create_toggle("📖 Police Dyslexie", dyslexia_enabled,
		func(toggled_on: bool):
			if accessibility_manager and accessibility_manager.has_method("set_dyslexia_mode"):
				accessibility_manager.set_dyslexia_mode(toggled_on)
	)
	vbox.add_child(dyslexia_toggle)
	
	# Toggle TTS
	var tts = get_node_or_null("/root/TTSManager")
	var tts_enabled := true
	if tts and "enabled" in tts:
		tts_enabled = tts.enabled
	var tts_toggle := _create_toggle("🗣️ Synthèse Vocale (TTS)", tts_enabled,
		func(toggled_on: bool):
			if tts and "enabled" in tts:
				tts.enabled = toggled_on
	)
	vbox.add_child(tts_toggle)
	
	# Toggle Haptique
	var haptic = get_node_or_null("/root/HapticFeedback")
	var haptic_enabled := true
	if haptic and haptic.has_method("is_enabled"):
		haptic_enabled = haptic.is_enabled()
	var haptic_toggle := _create_toggle("📳 Retour Haptique", haptic_enabled,
		func(toggled_on: bool):
			if haptic and haptic.has_method("set_enabled"):
				haptic.set_enabled(toggled_on)
	)
	vbox.add_child(haptic_toggle)
	
	# Bouton Fermer
	var close_button := Button.new()
	close_button.text = "Fermer"
	close_button.custom_minimum_size.y = 45
	close_button.pressed.connect(func(): panel.queue_free())
	vbox.add_child(close_button)
	
	add_child(panel)
	
	# TTS announcement
	if tts:
		tts.speak("Menu accessibilité. Utilisez les touches pour naviguer.")
	
	# Focus sur le premier toggle pour accessibilité
	if blind_toggle:
		blind_toggle.get_child(1).grab_focus()  # Le CheckButton


func _create_toggle(label_text: String, initial_value: bool, callback: Callable) -> HBoxContainer:
	"""Crée un toggle avec label."""
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(label)
	
	var toggle := CheckButton.new()
	toggle.button_pressed = initial_value
	toggle.toggled.connect(callback)
	hbox.add_child(toggle)
	
	return hbox


func _on_quit_pressed() -> void:
	"""Quitte le jeu."""
	get_tree().quit()


func _input(event: InputEvent) -> void:
	"""Gestion des entrées pour accessibilité."""
	# Navigation au clavier pour accessibilité
	if event.is_action_pressed("ui_accept"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")
