# ==============================================================================
# TutorialManager.gd - Système de tutoriel/onboarding
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Guide les nouveaux joueurs avec des étapes interactives
# Supporte l'accessibilité (TTS, contraste élevé)
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal tutorial_started
signal step_started(step: TutorialStep)
signal step_completed(step: TutorialStep)
signal tutorial_completed
signal tutorial_skipped

# ==============================================================================
# CLASSES
# ==============================================================================

class TutorialStep:
	var id: String = ""
	var title: String = ""
	var description: String = ""
	var action_required: String = ""  # "move", "attack", "dash", "interact", "none"
	var highlight_element: String = ""  # Chemin du nœud à mettre en surbrillance
	var position_hint: String = "center"  # "top", "bottom", "left", "right", "center"
	var auto_advance_delay: float = 0.0  # 0 = attendre action
	var tts_text: String = ""  # Texte pour TTS (peut être différent)
	var is_optional: bool = false
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"title": title,
			"description": description,
			"action_required": action_required,
			"tts_text": tts_text
		}

# ==============================================================================
# CONSTANTES
# ==============================================================================
const SAVE_KEY := "tutorial_completed"
const TUTORIAL_STEPS_PATH := "res://data/tutorial.json"

# ==============================================================================
# VARIABLES
# ==============================================================================
var steps: Array[TutorialStep] = []
var current_step_index: int = -1
var current_step: TutorialStep = null
var is_active: bool = false
var is_completed: bool = false

# UI Reference
var _ui_panel: Control = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système de tutoriel."""
	_load_tutorial_steps()
	_check_if_completed()


func _input(event: InputEvent) -> void:
	"""Détection des actions requises."""
	if not is_active or not current_step:
		return
	
	var action := current_step.action_required
	
	if action == "none":
		return
	
	# Vérifier si l'action a été effectuée
	if event.is_action_pressed(action):
		# Petite délai pour voir l'action
		await get_tree().create_timer(0.5).timeout
		advance_step()


# ==============================================================================
# CHARGEMENT
# ==============================================================================

func _load_tutorial_steps() -> void:
	"""Charge les étapes du tutoriel."""
	# Étapes par défaut si pas de fichier
	_create_default_steps()
	
	# Charger depuis JSON si disponible
	if FileAccess.file_exists(TUTORIAL_STEPS_PATH):
		var file := FileAccess.open(TUTORIAL_STEPS_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				_parse_steps(json.data)
			file.close()


func _create_default_steps() -> void:
	"""Crée les étapes par défaut."""
	steps.clear()
	
	# Étape 1 : Bienvenue
	var step1 := TutorialStep.new()
	step1.id = "welcome"
	step1.title = "Bienvenue dans Neon Protocol"
	step1.description = "Vous vous réveillez dans les bas-fonds de la mégapole. Vos implants cybernétiques redémarrent..."
	step1.action_required = "none"
	step1.auto_advance_delay = 5.0
	step1.tts_text = "Bienvenue dans Neon Protocol. Vous vous réveillez dans les bas-fonds de la mégapole."
	steps.append(step1)
	
	# Étape 2 : Mouvement
	var step2 := TutorialStep.new()
	step2.id = "movement"
	step2.title = "Déplacement"
	step2.description = "Utilisez le JOYSTICK GAUCHE pour vous déplacer.\n\n[Clavier: WASD]"
	step2.action_required = "move_forward"
	step2.highlight_element = "VirtualJoystick"
	step2.tts_text = "Utilisez le joystick gauche pour vous déplacer. Sur clavier, utilisez les touches WASD."
	steps.append(step2)
	
	# Étape 3 : Caméra
	var step3 := TutorialStep.new()
	step3.id = "camera"
	step3.title = "Caméra"
	step3.description = "Glissez sur la PARTIE DROITE de l'écran pour tourner la caméra."
	step3.action_required = "none"
	step3.auto_advance_delay = 4.0
	step3.tts_text = "Glissez sur la partie droite de l'écran pour tourner la caméra."
	steps.append(step3)
	
	# Étape 4 : Combat
	var step4 := TutorialStep.new()
	step4.id = "combat"
	step4.title = "Combat"
	step4.description = "Appuyez sur le bouton ATTAQUE pour frapper.\n\nLe ciblage automatique visera l'ennemi le plus proche."
	step4.action_required = "attack"
	step4.tts_text = "Appuyez sur le bouton attaque pour frapper. Le ciblage automatique visera l'ennemi le plus proche."
	steps.append(step4)
	
	# Étape 5 : Dash
	var step5 := TutorialStep.new()
	step5.id = "dash"
	step5.title = "Esquive"
	step5.description = "Appuyez sur DASH pour esquiver rapidement.\n\nUtilisez-le pour éviter les attaques ennemies."
	step5.action_required = "dash"
	step5.tts_text = "Appuyez sur dash pour esquiver rapidement. Utilisez-le pour éviter les attaques."
	steps.append(step5)
	
	# Étape 6 : Interaction
	var step6 := TutorialStep.new()
	step6.id = "interact"
	step6.title = "Interaction"
	step6.description = "Approchez-vous d'un objet brillant et appuyez sur INTERACTION (E)."
	step6.action_required = "interact"
	step6.tts_text = "Approchez-vous d'un objet et appuyez sur le bouton interaction."
	steps.append(step6)
	
	# Étape 7 : Mission
	var step7 := TutorialStep.new()
	step7.id = "mission"
	step7.title = "Missions"
	step7.description = "Votre objectif actuel s'affiche en haut à gauche.\n\nSuivez le son du RADAR pour vous orienter."
	step7.action_required = "none"
	step7.auto_advance_delay = 5.0
	step7.tts_text = "Votre objectif s'affiche en haut à gauche. Suivez le son du radar pour vous orienter."
	steps.append(step7)
	
	# Étape 8 : Fin
	var step8 := TutorialStep.new()
	step8.id = "complete"
	step8.title = "Prêt pour l'action !"
	step8.description = "Vous maîtrisez les bases. Bonne chance dans les rues de Neon Protocol."
	step8.action_required = "none"
	step8.auto_advance_delay = 3.0
	step8.tts_text = "Vous maîtrisez les bases. Bonne chance dans les rues de Neon Protocol."
	steps.append(step8)


func _parse_steps(data: Array) -> void:
	"""Parse les étapes depuis JSON."""
	steps.clear()
	for step_data in data:
		var step := TutorialStep.new()
		step.id = step_data.get("id", "")
		step.title = step_data.get("title", "")
		step.description = step_data.get("description", "")
		step.action_required = step_data.get("action_required", "none")
		step.highlight_element = step_data.get("highlight_element", "")
		step.auto_advance_delay = step_data.get("auto_advance_delay", 0.0)
		step.tts_text = step_data.get("tts_text", step.description)
		step.is_optional = step_data.get("is_optional", false)
		steps.append(step)


# ==============================================================================
# CONTRÔLE DU TUTORIEL
# ==============================================================================

func start_tutorial() -> void:
	"""Démarre le tutoriel."""
	if steps.is_empty():
		return
	
	is_active = true
	current_step_index = -1
	tutorial_started.emit()
	
	advance_step()


func advance_step() -> void:
	"""Passe à l'étape suivante."""
	# Compléter l'étape actuelle
	if current_step:
		step_completed.emit(current_step)
	
	# Passer à la suivante
	current_step_index += 1
	
	if current_step_index >= steps.size():
		complete_tutorial()
		return
	
	current_step = steps[current_step_index]
	step_started.emit(current_step)
	
	# Afficher l'UI
	_show_step_ui(current_step)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts and not current_step.tts_text.is_empty():
		tts.speak(current_step.tts_text)
	
	# Auto-advance si configuré
	if current_step.auto_advance_delay > 0:
		await get_tree().create_timer(current_step.auto_advance_delay).timeout
		if is_active and current_step == steps[current_step_index]:
			advance_step()


func skip_tutorial() -> void:
	"""Passe le tutoriel."""
	is_active = false
	current_step = null
	tutorial_skipped.emit()
	
	_hide_ui()
	_mark_completed()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Tutoriel passé")


func complete_tutorial() -> void:
	"""Termine le tutoriel."""
	is_active = false
	is_completed = true
	current_step = null
	
	_hide_ui()
	_mark_completed()
	
	tutorial_completed.emit()


func _mark_completed() -> void:
	"""Marque le tutoriel comme terminé."""
	var am = get_node_or_null("/root/AccessibilityManager")
	if am and am.has_method("save_settings"):
		# Sauvegarder dans les préférences
		pass
	
	is_completed = true


func _check_if_completed() -> void:
	"""Vérifie si le tutoriel a déjà été fait."""
	# Charger depuis les préférences via SaveManager
	var save = get_node_or_null("/root/SaveManager")
	if save:
		if save.has_method("get_setting"):
			is_completed = save.get_setting(SAVE_KEY, false)
		elif "current_save" in save:
			var save_data = save.current_save
			if save_data and "tutorial_completed" in save_data:
				is_completed = save_data.tutorial_completed
			else:
				is_completed = false
		else:
			is_completed = false
	else:
		is_completed = false


# ==============================================================================
# UI
# ==============================================================================

func _show_step_ui(step: TutorialStep) -> void:
	"""Affiche l'UI pour une étape."""
	# Supprimer l'ancien panneau si existant
	if _ui_panel and is_instance_valid(_ui_panel):
		_ui_panel.queue_free()
		_ui_panel = null
	
	# Créer le panneau dynamiquement
	_ui_panel = _create_tutorial_panel(step)
	
	# Ajouter au canvas layer pour être au-dessus
	var canvas := CanvasLayer.new()
	canvas.name = "TutorialCanvas"
	canvas.layer = 90
	canvas.add_child(_ui_panel)
	get_tree().current_scene.add_child(canvas)
	
	# Animation d'entrée
	_ui_panel.modulate.a = 0.0
	_ui_panel.position.y += 20
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_ui_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(_ui_panel, "position:y", _ui_panel.position.y - 20, 0.3).set_ease(Tween.EASE_OUT)


func _create_tutorial_panel(step: TutorialStep) -> Control:
	"""Crée le panneau UI du tutoriel avec style cyberpunk."""
	# Panneau principal
	var panel := PanelContainer.new()
	panel.name = "TutorialPanel"
	
	# Style cyberpunk
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.1, 0.95)
	style.border_color = Color(0, 0.9, 0.9)
	style.set_border_width_all(2)
	style.border_width_left = 4
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	# Positionner selon hint
	panel.anchors_preset = Control.PRESET_CENTER_BOTTOM
	panel.size = Vector2(500, 180)
	panel.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 500) / 2,
		get_viewport().get_visible_rect().size.y - 200
	)
	
	# Marge intérieure
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	# Contenu vertical
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Titre
	var title := Label.new()
	title.text = "🎮 " + step.title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	vbox.add_child(title)
	
	# Description
	var desc := RichTextLabel.new()
	desc.text = step.description
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.custom_minimum_size.y = 60
	desc.add_theme_color_override("default_color", Color.WHITE)
	vbox.add_child(desc)
	
	# Barre du bas avec action et skip
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	# Hint d'action
	if not step.action_required.is_empty() and step.action_required != "none":
		var action_hint := Label.new()
		action_hint.text = "▶ " + _get_action_label(step.action_required)
		action_hint.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		action_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(action_hint)
	elif step.auto_advance_delay > 0:
		var auto_hint := Label.new()
		auto_hint.text = "..."
		auto_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		auto_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(auto_hint)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)
	
	# Bouton Skip
	var skip_btn := Button.new()
	skip_btn.text = "Passer ▶▶"
	skip_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	skip_btn.pressed.connect(skip_tutorial)
	hbox.add_child(skip_btn)
	
	return panel


func _get_action_label(action: String) -> String:
	"""Retourne le label lisible pour une action."""
	match action:
		"move_forward", "move_backward", "move_left", "move_right":
			return "Déplacez-vous"
		"attack":
			return "Appuyez sur ATTAQUE"
		"dash":
			return "Appuyez sur DASH"
		"interact":
			return "Appuyez sur INTERACTION"
		"pause":
			return "Appuyez sur PAUSE"
		_:
			return "Appuyez sur " + action.to_upper()


func _hide_ui() -> void:
	"""Cache l'UI du tutoriel."""
	if _ui_panel and is_instance_valid(_ui_panel):
		# Animation de sortie
		var tween := create_tween()
		tween.tween_property(_ui_panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			if _ui_panel and is_instance_valid(_ui_panel):
				var parent = _ui_panel.get_parent()
				if parent:
					parent.queue_free()  # Supprimer le CanvasLayer aussi
			_ui_panel = null
		)


func set_ui_panel(panel: Control) -> void:
	"""Définit le panneau UI à utiliser."""
	_ui_panel = panel


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func is_tutorial_active() -> bool:
	"""Retourne true si le tutoriel est actif."""
	return is_active


func is_tutorial_completed() -> bool:
	"""Retourne true si le tutoriel a été terminé."""
	return is_completed


func get_current_step() -> TutorialStep:
	"""Retourne l'étape actuelle."""
	return current_step


func reset_tutorial() -> void:
	"""Réinitialise le tutoriel."""
	is_completed = false
	is_active = false
	current_step_index = -1
	current_step = null
