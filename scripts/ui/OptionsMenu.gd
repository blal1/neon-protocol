# ==============================================================================
# OptionsMenu.gd - Menu d'options avec accessibilité
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================

extends Control

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal closed

# ==============================================================================
# RÉFÉRENCES UI
# ==============================================================================
@onready var text_size_option: OptionButton = $Panel/Tabs/Accessibility/VBox/TextSizeOption
@onready var colorblind_option: OptionButton = $Panel/Tabs/Accessibility/VBox/ColorblindOption
@onready var dyslexia_toggle: CheckButton = $Panel/Tabs/Accessibility/VBox/DyslexiaToggle
@onready var blind_mode_toggle: CheckButton = $Panel/Tabs/Accessibility/VBox/BlindModeToggle
@onready var game_speed_slider: HSlider = $Panel/Tabs/Accessibility/VBox/GameSpeedSlider
@onready var game_speed_label: Label = $Panel/Tabs/Accessibility/VBox/GameSpeedLabel

@onready var master_volume_slider: HSlider = $Panel/Tabs/Audio/VBox/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $Panel/Tabs/Audio/VBox/MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = $Panel/Tabs/Audio/VBox/SFXVolumeSlider

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du menu options."""
	_setup_accessibility_options()
	_setup_audio_options()
	_load_current_settings()


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _setup_accessibility_options() -> void:
	"""Configure les options d'accessibilité."""
	# Taille du texte
	if text_size_option:
		text_size_option.clear()
		text_size_option.add_item("Normal", 0)
		text_size_option.add_item("Grand", 1)
		text_size_option.add_item("Très Grand", 2)
	
	# Mode daltonien
	if colorblind_option:
		colorblind_option.clear()
		colorblind_option.add_item("Désactivé", 0)
		colorblind_option.add_item("Deutéranopie (Rouge-Vert)", 1)
		colorblind_option.add_item("Protanopie (Rouge)", 2)
		colorblind_option.add_item("Tritanopie (Bleu-Jaune)", 3)


func _setup_audio_options() -> void:
	"""Configure les options audio."""
	if master_volume_slider:
		master_volume_slider.min_value = 0.0
		master_volume_slider.max_value = 1.0
		master_volume_slider.step = 0.05
	
	if music_volume_slider:
		music_volume_slider.min_value = 0.0
		music_volume_slider.max_value = 1.0
		music_volume_slider.step = 0.05
	
	if sfx_volume_slider:
		sfx_volume_slider.min_value = 0.0
		sfx_volume_slider.max_value = 1.0
		sfx_volume_slider.step = 0.05


func _load_current_settings() -> void:
	"""Charge les paramètres actuels dans l'UI."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if not am:
		return
	
	# Accessibilité
	if text_size_option:
		text_size_option.selected = am.current_text_size
	
	if colorblind_option:
		colorblind_option.selected = am.current_colorblind_mode
	
	if dyslexia_toggle:
		dyslexia_toggle.button_pressed = am.dyslexia_mode_enabled
	
	if blind_mode_toggle:
		blind_mode_toggle.button_pressed = am.blind_mode_enabled
	
	if game_speed_slider:
		game_speed_slider.value = am.current_game_speed
		_update_game_speed_label(am.current_game_speed)
	
	# Audio
	if master_volume_slider:
		var master_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
		master_volume_slider.value = db_to_linear(master_db)
	
	if music_volume_slider:
		var music_idx := AudioServer.get_bus_index("Music")
		if music_idx >= 0:
			music_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
	
	if sfx_volume_slider:
		var sfx_idx := AudioServer.get_bus_index("SFX")
		if sfx_idx >= 0:
			sfx_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))


# ==============================================================================
# CALLBACKS ACCESSIBILITÉ
# ==============================================================================

func _on_text_size_selected(index: int) -> void:
	"""Change la taille du texte."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am:
		am.set_text_size(index)
	
	_speak("Taille du texte: " + ["Normal", "Grand", "Très grand"][index])


func _on_colorblind_selected(index: int) -> void:
	"""Change le mode daltonien."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am:
		am.set_colorblind_mode(index)
	
	var modes := ["Désactivé", "Deutéranopie", "Protanopie", "Tritanopie"]
	_speak("Mode daltonien: " + modes[index])


func _on_dyslexia_toggled(enabled: bool) -> void:
	"""Toggle mode dyslexie."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am:
		am.set_dyslexia_mode(enabled)
	
	_speak("Police dyslexie " + ("activée" if enabled else "désactivée"))


func _on_blind_mode_toggled(enabled: bool) -> void:
	"""Toggle mode aveugle."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am:
		am.set_blind_mode(enabled)
	
	var bam = get_node_or_null("/root/BlindAccessibilityManager")
	if bam:
		if enabled:
			bam.activate()
		else:
			bam.deactivate()
	
	_speak("Mode accessibilité aveugle " + ("activé" if enabled else "désactivé"))


func _on_game_speed_changed(value: float) -> void:
	"""Change la vitesse du jeu."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am:
		am.set_game_speed(value)
	
	_update_game_speed_label(value)


func _update_game_speed_label(value: float) -> void:
	"""Met à jour le label de vitesse."""
	if game_speed_label:
		game_speed_label.text = "Vitesse: %.0f%%" % (value * 100)


# ==============================================================================
# CALLBACKS AUDIO
# ==============================================================================

func _on_master_volume_changed(value: float) -> void:
	"""Change le volume principal."""
	var db := linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


func _on_music_volume_changed(value: float) -> void:
	"""Change le volume musique."""
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))


func _on_sfx_volume_changed(value: float) -> void:
	"""Change le volume SFX."""
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))


# ==============================================================================
# NAVIGATION
# ==============================================================================

func _on_back_pressed() -> void:
	"""Ferme le menu options."""
	closed.emit()
	hide()


func _speak(text: String) -> void:
	"""Lit un texte via TTS."""
	var tts = get_node_or_null("/root/TTSManager")
	if tts and tts.has_method("speak"):
		tts.speak(text)
