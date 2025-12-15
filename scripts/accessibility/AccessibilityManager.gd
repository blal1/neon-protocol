# ==============================================================================
# AccessibilityManager.gd - Gestionnaire d'accessibilité global
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Autoload Singleton gérant toutes les préférences d'accessibilité
# Sauvegarde/Charge les paramètres en JSON
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal text_size_changed(new_size: TextSize)
signal font_scale_changed(new_scale: float)
signal colorblind_mode_changed(new_mode: ColorblindMode)
signal contrast_changed(new_level: float)
signal game_speed_changed(new_speed: float)
signal blind_mode_changed(enabled: bool)
signal dyslexia_mode_changed(enabled: bool)
signal fov_changed(new_fov: float)
signal ui_scale_changed(new_scale: float)
signal volume_changed(bus_name: String, new_volume: float)
signal settings_loaded
signal settings_saved

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum TextSize {
	NORMAL,
	LARGE,
	EXTRA_LARGE
}

enum ColorblindMode {
	NONE,
	DEUTERANOPIA,  # Rouge-Vert (le plus commun)
	PROTANOPIA,    # Rouge
	TRITANOPIA     # Bleu-Jaune
}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SETTINGS_PATH := "user://accessibility_settings.json"
const TEXT_SIZE_MULTIPLIERS := {
	TextSize.NORMAL: 1.0,
	TextSize.LARGE: 1.5,
	TextSize.EXTRA_LARGE: 2.0
}
const GAME_SPEED_OPTIONS := [1.0, 0.8]

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_text_size: TextSize = TextSize.NORMAL
var current_font_scale: float = 1.0  # 1.0 - 3.0
var current_colorblind_mode: ColorblindMode = ColorblindMode.NONE
var current_contrast: float = 1.0  # 0.5 - 2.0
var current_game_speed: float = 1.0
var blind_mode_enabled: bool = false
var dyslexia_mode_enabled: bool = false
var high_contrast_enabled: bool = false
var screen_shake_enabled: bool = true
var haptic_feedback_enabled: bool = true
var current_fov: float = 75.0  # 60 - 120 degrees
var current_ui_scale: float = 1.0  # 1.0 - 2.0
var reduce_motion: bool = false

# Volume settings (0.0 - 1.0)
var volume_master: float = 1.0
var volume_music: float = 0.8
var volume_sfx: float = 1.0
var volume_voice: float = 1.0
var volume_ambient: float = 0.7

# Contrast shader
var _contrast_overlay: ColorRect = null
var _contrast_shader_material: ShaderMaterial = null

# Référence au shader de daltonisme
var _colorblind_shader_material: ShaderMaterial = null
var _camera_overlay: ColorRect = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du manager d'accessibilité."""
	# Charger les paramètres sauvegardés
	load_settings()
	
	# Appliquer les paramètres au démarrage
	_apply_all_settings()


func _enter_tree() -> void:
	"""Appelé quand le noeud entre dans l'arbre."""
	# S'assurer que c'est un singleton
	if get_tree().root.has_node("AccessibilityManager"):
		queue_free()


# ==============================================================================
# GESTION DE LA TAILLE DU TEXTE
# ==============================================================================

func set_text_size(size: TextSize) -> void:
	"""
	Définit la taille du texte pour toute l'interface.
	@param size: TextSize.NORMAL, LARGE, ou EXTRA_LARGE
	"""
	if current_text_size == size:
		return
	
	current_text_size = size
	text_size_changed.emit(size)
	
	# Appliquer à toute la scène
	apply_text_size_to_scene(get_tree().root)
	
	save_settings()


func get_text_size_multiplier() -> float:
	"""Retourne le multiplicateur de taille actuel."""
	return TEXT_SIZE_MULTIPLIERS[current_text_size]


func apply_text_size_to_scene(root: Node) -> void:
	"""
	Applique la taille du texte à tous les éléments UI d'une scène.
	@param root: Noeud racine à partir duquel appliquer
	"""
	var multiplier := get_text_size_multiplier()
	_apply_text_size_recursive(root, multiplier)


func _apply_text_size_recursive(node: Node, multiplier: float) -> void:
	"""Applique récursivement la taille du texte."""
	# Labels
	if node is Label:
		_scale_label_font(node as Label, multiplier)
	
	# RichTextLabels
	elif node is RichTextLabel:
		_scale_rich_text_font(node as RichTextLabel, multiplier)
	
	# Buttons (ont aussi du texte)
	elif node is Button:
		_scale_button_font(node as Button, multiplier)
	
	# LineEdit
	elif node is LineEdit:
		_scale_line_edit_font(node as LineEdit, multiplier)
	
	# Récursion sur les enfants
	for child in node.get_children():
		_apply_text_size_recursive(child, multiplier)


func _scale_label_font(label: Label, multiplier: float) -> void:
	"""Redimensionne la police d'un Label."""
	# Stocker la taille originale si pas déjà fait
	if not label.has_meta("original_font_size"):
		var current_size := label.get_theme_font_size("font_size")
		if current_size <= 0:
			current_size = 16  # Taille par défaut
		label.set_meta("original_font_size", current_size)
	
	var original_size: int = label.get_meta("original_font_size")
	var new_size := int(original_size * multiplier)
	label.add_theme_font_size_override("font_size", new_size)


func _scale_rich_text_font(rtl: RichTextLabel, multiplier: float) -> void:
	"""Redimensionne la police d'un RichTextLabel."""
	if not rtl.has_meta("original_font_size"):
		var current_size := rtl.get_theme_font_size("normal_font_size")
		if current_size <= 0:
			current_size = 16
		rtl.set_meta("original_font_size", current_size)
	
	var original_size: int = rtl.get_meta("original_font_size")
	var new_size := int(original_size * multiplier)
	rtl.add_theme_font_size_override("normal_font_size", new_size)
	rtl.add_theme_font_size_override("bold_font_size", new_size)
	rtl.add_theme_font_size_override("italics_font_size", new_size)


func _scale_button_font(button: Button, multiplier: float) -> void:
	"""Redimensionne la police d'un Button."""
	if not button.has_meta("original_font_size"):
		var current_size := button.get_theme_font_size("font_size")
		if current_size <= 0:
			current_size = 16
		button.set_meta("original_font_size", current_size)
	
	var original_size: int = button.get_meta("original_font_size")
	var new_size := int(original_size * multiplier)
	button.add_theme_font_size_override("font_size", new_size)


func _scale_line_edit_font(line_edit: LineEdit, multiplier: float) -> void:
	"""Redimensionne la police d'un LineEdit."""
	if not line_edit.has_meta("original_font_size"):
		var current_size := line_edit.get_theme_font_size("font_size")
		if current_size <= 0:
			current_size = 16
		line_edit.set_meta("original_font_size", current_size)
	
	var original_size: int = line_edit.get_meta("original_font_size")
	var new_size := int(original_size * multiplier)
	line_edit.add_theme_font_size_override("font_size", new_size)


# ==============================================================================
# GESTION DU MODE DALTONIEN
# ==============================================================================

func set_colorblind_mode(mode: ColorblindMode) -> void:
	"""
	Active un mode daltonien avec filtre sur la caméra.
	@param mode: Type de daltonisme à simuler/corriger
	"""
	if current_colorblind_mode == mode:
		return
	
	current_colorblind_mode = mode
	colorblind_mode_changed.emit(mode)
	
	_apply_colorblind_filter()
	save_settings()


func _apply_colorblind_filter() -> void:
	"""Applique le shader de daltonisme à la caméra."""
	# Chercher ou créer l'overlay
	if not _camera_overlay:
		_create_camera_overlay()
	
	if not _camera_overlay:
		push_warning("AccessibilityManager: Impossible de créer l'overlay caméra")
		return
	
	# Activer/désactiver selon le mode
	if current_colorblind_mode == ColorblindMode.NONE:
		_camera_overlay.visible = false
	else:
		_camera_overlay.visible = true
		if _colorblind_shader_material:
			_colorblind_shader_material.set_shader_parameter("mode", int(current_colorblind_mode))


func _create_camera_overlay() -> void:
	"""Crée un ColorRect overlay pour le shader de daltonisme."""
	# Chercher un CanvasLayer existant ou en créer un
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "AccessibilityOverlay"
	canvas_layer.layer = 100  # Au-dessus de tout
	get_tree().root.add_child(canvas_layer)
	
	# Créer le ColorRect
	_camera_overlay = ColorRect.new()
	_camera_overlay.name = "ColorblindFilter"
	_camera_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Charger ou créer le shader
	var shader := load("res://shaders/colorblind_filter.gdshader")
	if shader:
		_colorblind_shader_material = ShaderMaterial.new()
		_colorblind_shader_material.shader = shader
		_camera_overlay.material = _colorblind_shader_material
	else:
		push_warning("AccessibilityManager: Shader colorblind_filter.gdshader non trouvé")
	
	canvas_layer.add_child(_camera_overlay)
	_camera_overlay.visible = false


# ==============================================================================
# GESTION DE LA VITESSE DU JEU
# ==============================================================================

func set_game_speed(speed: float) -> void:
	"""
	Définit la vitesse du jeu.
	@param speed: 1.0 (normal) ou 0.8 (ralenti)
	"""
	speed = clamp(speed, 0.5, 1.5)
	
	if abs(current_game_speed - speed) < 0.01:
		return
	
	current_game_speed = speed
	Engine.time_scale = speed
	game_speed_changed.emit(speed)
	
	save_settings()


func toggle_slow_mode() -> void:
	"""Bascule entre vitesse normale et ralentie."""
	if current_game_speed >= 1.0:
		set_game_speed(0.8)
	else:
		set_game_speed(1.0)


# ==============================================================================
# MODE AVEUGLE
# ==============================================================================

func set_blind_mode(enabled: bool) -> void:
	"""
	Active/désactive le mode pour non-voyants.
	@param enabled: true pour activer
	"""
	if blind_mode_enabled == enabled:
		return
	
	blind_mode_enabled = enabled
	blind_mode_changed.emit(enabled)
	
	save_settings()


# ==============================================================================
# MODE DYSLEXIE
# ==============================================================================

func set_dyslexia_mode(enabled: bool) -> void:
	"""
	Active/désactive le mode dyslexie (police OpenDyslexic).
	@param enabled: true pour activer
	"""
	if dyslexia_mode_enabled == enabled:
		return
	
	dyslexia_mode_enabled = enabled
	dyslexia_mode_changed.emit(enabled)
	
	save_settings()


func is_dyslexia_mode_enabled() -> bool:
	"""Retourne true si le mode dyslexie est activé."""
	return dyslexia_mode_enabled


# ==============================================================================
# AUTRES PARAMÈTRES
# ==============================================================================

func set_high_contrast(enabled: bool) -> void:
	"""Active/désactive le mode contraste élevé."""
	high_contrast_enabled = enabled
	save_settings()


func set_screen_shake(enabled: bool) -> void:
	"""Active/désactive les secousses d'écran."""
	screen_shake_enabled = enabled
	save_settings()


func set_haptic_feedback(enabled: bool) -> void:
	"""Active/désactive le retour haptique."""
	haptic_feedback_enabled = enabled
	save_settings()


# ==============================================================================
# SAUVEGARDE / CHARGEMENT
# ==============================================================================

func save_settings() -> void:
	"""Sauvegarde les paramètres d'accessibilité en JSON."""
	var settings := {
		"text_size": current_text_size,
		"font_scale": current_font_scale,
		"colorblind_mode": current_colorblind_mode,
		"contrast": current_contrast,
		"game_speed": current_game_speed,
		"fov": current_fov,
		"ui_scale": current_ui_scale,
		"blind_mode": blind_mode_enabled,
		"dyslexia_mode": dyslexia_mode_enabled,
		"high_contrast": high_contrast_enabled,
		"screen_shake": screen_shake_enabled,
		"haptic_feedback": haptic_feedback_enabled,
		"reduce_motion": reduce_motion,
		"volume_master": volume_master,
		"volume_music": volume_music,
		"volume_sfx": volume_sfx,
		"volume_voice": volume_voice,
		"volume_ambient": volume_ambient,
		"version": 2
	}
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
		settings_saved.emit()
	else:
		push_error("AccessibilityManager: Impossible de sauvegarder les paramètres")


func load_settings() -> void:
	"""Charge les paramètres d'accessibilité depuis le JSON."""
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("AccessibilityManager: Erreur de parsing JSON")
		return
	
	var settings: Dictionary = json.data
	
	# Appliquer les paramètres chargés
	if settings.has("text_size"):
		current_text_size = settings["text_size"] as TextSize
	if settings.has("font_scale"):
		current_font_scale = settings["font_scale"]
	if settings.has("colorblind_mode"):
		current_colorblind_mode = settings["colorblind_mode"] as ColorblindMode
	if settings.has("contrast"):
		current_contrast = settings["contrast"]
	if settings.has("game_speed"):
		current_game_speed = settings["game_speed"]
	if settings.has("fov"):
		current_fov = settings["fov"]
	if settings.has("ui_scale"):
		current_ui_scale = settings["ui_scale"]
	if settings.has("blind_mode"):
		blind_mode_enabled = settings["blind_mode"]
	if settings.has("dyslexia_mode"):
		dyslexia_mode_enabled = settings["dyslexia_mode"]
	if settings.has("high_contrast"):
		high_contrast_enabled = settings["high_contrast"]
	if settings.has("screen_shake"):
		screen_shake_enabled = settings["screen_shake"]
	if settings.has("haptic_feedback"):
		haptic_feedback_enabled = settings["haptic_feedback"]
	if settings.has("reduce_motion"):
		reduce_motion = settings["reduce_motion"]
	
	# Volumes
	if settings.has("volume_master"):
		volume_master = settings["volume_master"]
	if settings.has("volume_music"):
		volume_music = settings["volume_music"]
	if settings.has("volume_sfx"):
		volume_sfx = settings["volume_sfx"]
	if settings.has("volume_voice"):
		volume_voice = settings["volume_voice"]
	if settings.has("volume_ambient"):
		volume_ambient = settings["volume_ambient"]
	
	# Appliquer les volumes
	_apply_volume_settings()
	
	settings_loaded.emit()


func _apply_all_settings() -> void:
	"""Applique tous les paramètres actuels."""
	# Vitesse du jeu
	Engine.time_scale = current_game_speed
	
	# Filtre daltonien (créé à la demande)
	if current_colorblind_mode != ColorblindMode.NONE:
		_apply_colorblind_filter()
	
	# Taille du texte (appliquée quand les scènes chargent)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_text_size_name() -> String:
	"""Retourne le nom de la taille de texte actuelle."""
	match current_text_size:
		TextSize.NORMAL:
			return "Normal"
		TextSize.LARGE:
			return "Grand"
		TextSize.EXTRA_LARGE:
			return "Très Grand"
	return "Normal"


func get_colorblind_mode_name() -> String:
	"""Retourne le nom du mode daltonien actuel."""
	match current_colorblind_mode:
		ColorblindMode.NONE:
			return "Désactivé"
		ColorblindMode.DEUTERANOPIA:
			return "Deutéranopie (Rouge-Vert)"
		ColorblindMode.PROTANOPIA:
			return "Protanopie (Rouge)"
		ColorblindMode.TRITANOPIA:
			return "Tritanopie (Bleu-Jaune)"
	return "Désactivé"


func reset_to_defaults() -> void:
	"""Réinitialise tous les paramètres par défaut."""
	current_text_size = TextSize.NORMAL
	current_font_scale = 1.0
	current_colorblind_mode = ColorblindMode.NONE
	current_contrast = 1.0
	current_game_speed = 1.0
	current_fov = 75.0
	current_ui_scale = 1.0
	blind_mode_enabled = false
	dyslexia_mode_enabled = false
	high_contrast_enabled = false
	screen_shake_enabled = true
	haptic_feedback_enabled = true
	reduce_motion = false
	volume_master = 1.0
	volume_music = 0.8
	volume_sfx = 1.0
	volume_voice = 1.0
	volume_ambient = 0.7
	
	_apply_all_settings()
	_apply_volume_settings()
	save_settings()


# ==============================================================================
# TAILLE DE POLICE PERSONNALISÉE
# ==============================================================================

func set_font_scale(scale: float) -> void:
	"""
	Définit l'échelle de police personnalisée (1.0 - 3.0).
	@param scale: Multiplicateur de taille de police
	"""
	scale = clamp(scale, 1.0, 3.0)
	if abs(current_font_scale - scale) < 0.01:
		return
	
	current_font_scale = scale
	font_scale_changed.emit(scale)
	apply_text_size_to_scene(get_tree().root)
	save_settings()


func get_font_scale() -> float:
	"""Retourne l'échelle de police actuelle."""
	return current_font_scale


# ==============================================================================
# RÉGLAGE DU CONTRASTE
# ==============================================================================

func set_contrast(level: float) -> void:
	"""
	Définit le niveau de contraste (0.5 - 2.0).
	@param level: 1.0 = normal, >1 = plus contrasté, <1 = moins contrasté
	"""
	level = clamp(level, 0.5, 2.0)
	if abs(current_contrast - level) < 0.01:
		return
	
	current_contrast = level
	contrast_changed.emit(level)
	_apply_contrast_filter()
	save_settings()


func _apply_contrast_filter() -> void:
	"""Applique le filtre de contraste."""
	if not _contrast_overlay:
		_create_contrast_overlay()
	
	if not _contrast_overlay:
		return
	
	if abs(current_contrast - 1.0) < 0.01:
		_contrast_overlay.visible = false
	else:
		_contrast_overlay.visible = true
		if _contrast_overlay.material:
			_contrast_overlay.material.set_shader_parameter("contrast", current_contrast)


func _create_contrast_overlay() -> void:
	"""Crée l'overlay pour le contraste."""
	var canvas := get_tree().root.get_node_or_null("AccessibilityOverlay")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "AccessibilityOverlay"
		canvas.layer = 100
		get_tree().root.add_child(canvas)
	
	_contrast_overlay = ColorRect.new()
	_contrast_overlay.name = "ContrastFilter"
	_contrast_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contrast_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Créer shader de contraste inline
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color.rgb = ((color.rgb - 0.5) * contrast) + 0.5;
	COLOR = color;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_contrast_overlay.material = mat
	
	canvas.add_child(_contrast_overlay)
	_contrast_overlay.visible = false


# ==============================================================================
# CHAMP DE VISION (FOV)
# ==============================================================================

func set_fov(fov: float) -> void:
	"""
	Définit le champ de vision de la caméra (60 - 120 degrés).
	@param fov: FOV en degrés
	"""
	fov = clamp(fov, 60.0, 120.0)
	if abs(current_fov - fov) < 0.5:
		return
	
	current_fov = fov
	fov_changed.emit(fov)
	_apply_fov_to_camera()
	save_settings()


func _apply_fov_to_camera() -> void:
	"""Applique le FOV à la caméra active."""
	var camera := get_viewport().get_camera_3d()
	if camera:
		camera.fov = current_fov


func get_fov() -> float:
	"""Retourne le FOV actuel."""
	return current_fov


# ==============================================================================
# MISE À L'ÉCHELLE UI
# ==============================================================================

func set_ui_scale(scale: float) -> void:
	"""
	Définit l'échelle de l'interface utilisateur (1.0 - 2.0).
	@param scale: Multiplicateur de taille UI
	"""
	scale = clamp(scale, 1.0, 2.0)
	if abs(current_ui_scale - scale) < 0.01:
		return
	
	current_ui_scale = scale
	ui_scale_changed.emit(scale)
	save_settings()


func get_ui_scale() -> float:
	"""Retourne l'échelle UI actuelle."""
	return current_ui_scale


# ==============================================================================
# RÉDUCTION DE MOUVEMENT
# ==============================================================================

func set_reduce_motion(enabled: bool) -> void:
	"""Active/désactive la réduction de mouvement (animations de fond)."""
	if reduce_motion == enabled:
		return
	reduce_motion = enabled
	save_settings()


func is_reduce_motion_enabled() -> bool:
	"""Retourne true si la réduction de mouvement est activée."""
	return reduce_motion


# ==============================================================================
# CONTRÔLES DE VOLUME
# ==============================================================================

func set_volume(bus_name: String, volume: float) -> void:
	"""
	Définit le volume d'un bus audio (0.0 - 1.0).
	@param bus_name: "master", "music", "sfx", "voice", "ambient"
	@param volume: Niveau de volume (0.0 = muet, 1.0 = max)
	"""
	volume = clamp(volume, 0.0, 1.0)
	
	match bus_name.to_lower():
		"master":
			volume_master = volume
		"music":
			volume_music = volume
		"sfx":
			volume_sfx = volume
		"voice":
			volume_voice = volume
		"ambient":
			volume_ambient = volume
		_:
			push_warning("AccessibilityManager: Bus audio inconnu: " + bus_name)
			return
	
	_apply_volume_to_bus(bus_name, volume)
	volume_changed.emit(bus_name, volume)
	save_settings()


func get_volume(bus_name: String) -> float:
	"""Retourne le volume d'un bus audio."""
	match bus_name.to_lower():
		"master":
			return volume_master
		"music":
			return volume_music
		"sfx":
			return volume_sfx
		"voice":
			return volume_voice
		"ambient":
			return volume_ambient
	return 1.0


func _apply_volume_to_bus(bus_name: String, volume: float) -> void:
	"""Applique le volume à un bus audio."""
	var bus_index := AudioServer.get_bus_index(bus_name.capitalize())
	if bus_index == -1:
		# Essayer avec "Master" exact
		if bus_name.to_lower() == "master":
			bus_index = 0
		else:
			return
	
	# Convertir 0-1 en dB (-80 à 0)
	var db := linear_to_db(volume) if volume > 0.0 else -80.0
	AudioServer.set_bus_volume_db(bus_index, db)


func _apply_volume_settings() -> void:
	"""Applique tous les volumes aux bus audio."""
	_apply_volume_to_bus("master", volume_master)
	_apply_volume_to_bus("music", volume_music)
	_apply_volume_to_bus("sfx", volume_sfx)
	_apply_volume_to_bus("voice", volume_voice)
	_apply_volume_to_bus("ambient", volume_ambient)


# ==============================================================================
# CURSEUR / RÉTICULE
# ==============================================================================

var crosshair_color: Color = Color.WHITE
var crosshair_size: float = 1.0  # 0.5 - 2.0
var crosshair_style: int = 0  # 0=default, 1=dot, 2=circle, 3=cross

func set_crosshair_color(color: Color) -> void:
	"""Définit la couleur du réticule."""
	crosshair_color = color
	save_settings()


func set_crosshair_size(size: float) -> void:
	"""Définit la taille du réticule (0.5-2.0)."""
	crosshair_size = clamp(size, 0.5, 2.0)
	save_settings()


func set_crosshair_style(style: int) -> void:
	"""Définit le style du réticule (0-3)."""
	crosshair_style = clamp(style, 0, 3)
	save_settings()


func get_crosshair_settings() -> Dictionary:
	"""Retourne les paramètres du réticule."""
	return {
		"color": crosshair_color,
		"size": crosshair_size,
		"style": crosshair_style
	}


# ==============================================================================
# AUDIO 3D / SURROUND
# ==============================================================================

var hrtf_enabled: bool = true  # Head-Related Transfer Function pour audio binaural
var surround_enabled: bool = true

func set_hrtf_enabled(enabled: bool) -> void:
	"""Active/désactive l'audio HRTF (binaural)."""
	hrtf_enabled = enabled
	# Godot gère HRTF automatiquement avec AudioListener3D
	save_settings()


func set_surround_enabled(enabled: bool) -> void:
	"""Active/désactive l'audio surround/3D."""
	surround_enabled = enabled
	save_settings()


func is_hrtf_enabled() -> bool:
	"""Retourne true si HRTF est activé."""
	return hrtf_enabled


func is_surround_enabled() -> bool:
	"""Retourne true si le surround est activé."""
	return surround_enabled


# ==============================================================================
# TTS - SYNTHÈSE VOCALE SIMPLIFIÉE
# ==============================================================================

func speak(text: String, interrupt: bool = true) -> void:
	"""
	Lit un texte à voix haute via le TTS intégré de Godot.
	@param text: Texte à lire
	@param interrupt: Si true, interrompt la parole en cours (défaut)
	"""
	if not blind_mode_enabled:
		return
	
	if interrupt:
		DisplayServer.tts_stop()
	
	# Obtenir la première voix disponible
	var voices := DisplayServer.tts_get_voices()
	var voice_id := ""
	
	# Chercher une voix française si disponible
	for voice in voices:
		if voice.has("language") and voice["language"].begins_with("fr"):
			voice_id = voice["id"]
			break
	
	# Fallback sur la première voix disponible
	if voice_id == "" and voices.size() > 0:
		voice_id = voices[0]["id"]
	
	DisplayServer.tts_speak(text, voice_id)


func play_ui_sound(stream: AudioStream) -> void:
	"""
	Joue un son d'interface utilisateur.
	Le son est automatiquement nettoyé après lecture.
	@param stream: AudioStream à jouer
	"""
	if stream == null:
		return
	
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "UI"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
