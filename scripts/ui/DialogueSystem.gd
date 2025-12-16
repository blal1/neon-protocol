# ==============================================================================
# DialogueSystem.gd - Système de dialogue avec effet machine à écrire
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Affiche le texte lettre par lettre
# Support de la police Dyslexie via AccessibilityManager
# ==============================================================================

extends Control
class_name DialogueSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal dialogue_started
signal dialogue_finished
signal text_fully_displayed
signal character_displayed(char: String)
signal choice_selected(choice_index: int)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const DEFAULT_CHAR_DELAY := 0.03  # Délai entre chaque caractère (secondes)
const FAST_CHAR_DELAY := 0.01  # Délai rapide (quand on appuie)
const PUNCTUATION_DELAY := 0.15  # Pause après ponctuation

# Polices
const DYSLEXIA_FONT_PATH := "res://assets/fonts/Rajdhani-Regular.ttf"  # OpenDyslexic non disponible
const DEFAULT_FONT_PATH := "res://assets/fonts/Rajdhani-Medium.ttf"

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("UI")
@export var dialogue_panel: PanelContainer
@export var speaker_label: Label
@export var text_label: RichTextLabel
@export var continue_indicator: Control
@export var portrait_texture: TextureRect

@export_group("Timing")
@export var char_delay: float = 0.03  ## Délai entre caractères
@export var auto_advance: bool = false  ## Avancer automatiquement
@export var auto_advance_delay: float = 2.0  ## Délai avant auto-avance

@export_group("Audio")
@export var typing_sound: AudioStream  ## Son de frappe
@export var sound_interval: int = 3  ## Jouer un son tous les N caractères

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_active: bool = false
var is_typing: bool = false
var current_text: String = ""
var displayed_text: String = ""
var char_index: int = 0
var skip_requested: bool = false
var _timer: float = 0.0
var _current_delay: float = 0.03
var _char_count_for_sound: int = 0
var _dialogue_queue: Array[Dictionary] = []
var _dyslexia_font: Font = null
var _default_font: Font = null

# Base de données des dialogues
const DIALOGUES_PATH := "res://data/dialogues.json"
var _dialogues_database: Dictionary = {}
var _current_dialogue_id: String = ""
var _current_node_id: String = ""

# Audio
@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système de dialogue."""
	# Ajouter le lecteur audio
	add_child(audio_player)
	if typing_sound:
		audio_player.stream = typing_sound
	
	# Charger les polices
	_load_fonts()
	
	# Charger la base de données des dialogues
	_load_dialogues_database()
	
	# Cacher le panneau au démarrage
	if dialogue_panel:
		dialogue_panel.visible = false
	if continue_indicator:
		continue_indicator.visible = false
	
	# Écouter les changements d'accessibilité
	var accessibility_manager = get_node_or_null("/root/AccessibilityManager")
	if accessibility_manager:
		if accessibility_manager.has_signal("dyslexia_mode_changed"):
			accessibility_manager.dyslexia_mode_changed.connect(_on_dyslexia_mode_changed)


func _process(delta: float) -> void:
	"""Mise à jour de l'effet machine à écrire."""
	if not is_typing:
		return
	
	_timer += delta
	
	# Afficher le prochain caractère
	if _timer >= _current_delay:
		_timer = 0.0
		_display_next_character()


func _input(event: InputEvent) -> void:
	"""Gestion des entrées."""
	if not is_active:
		return
	
	# Tap/clic pour accélérer ou avancer
	if event is InputEventScreenTouch and event.pressed:
		_handle_advance_input()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_advance_input()
	elif event.is_action_pressed("ui_accept"):
		_handle_advance_input()


# ==============================================================================
# AFFICHAGE DU TEXTE
# ==============================================================================

func show_dialogue(speaker: String, text: String, portrait: Texture2D = null) -> void:
	"""
	Affiche un dialogue avec effet machine à écrire.
	@param speaker: Nom du personnage qui parle
	@param text: Texte à afficher
	@param portrait: Portrait optionnel
	"""
	is_active = true
	dialogue_started.emit()
	
	# Afficher le panneau
	if dialogue_panel:
		dialogue_panel.visible = true
	
	# Configurer le speaker
	if speaker_label:
		speaker_label.text = speaker
	
	# Configurer le portrait
	if portrait_texture:
		if portrait:
			portrait_texture.texture = portrait
			portrait_texture.visible = true
		else:
			portrait_texture.visible = false
	
	# Appliquer la police dyslexie si nécessaire
	_apply_dyslexia_font()
	
	# Démarrer l'effet machine à écrire
	current_text = text
	displayed_text = ""
	char_index = 0
	is_typing = true
	skip_requested = false
	_current_delay = char_delay
	_char_count_for_sound = 0
	
	if text_label:
		text_label.text = ""
	
	if continue_indicator:
		continue_indicator.visible = false


func show_mission_dialogue(mission_data: Dictionary) -> void:
	"""
	Affiche un dialogue de mission.
	@param mission_data: Dictionnaire contenant title, description, story_context
	"""
	var title: String = mission_data.get("title", "Mission")
	var description: String = mission_data.get("description", "")
	var context: String = mission_data.get("story_context", "")
	
	# Construire le texte complet
	var full_text := ""
	if context != "":
		full_text = context + "\n\n"
	full_text += "[b]Objectif:[/b] " + description
	
	show_dialogue("MISSION: " + title, full_text)


func queue_dialogue(speaker: String, text: String, portrait: Texture2D = null) -> void:
	"""Ajoute un dialogue à la file d'attente."""
	_dialogue_queue.append({
		"speaker": speaker,
		"text": text,
		"portrait": portrait
	})
	
	# Si pas de dialogue en cours, démarrer
	if not is_active:
		_show_next_queued_dialogue()


func _show_next_queued_dialogue() -> void:
	"""Affiche le prochain dialogue de la file."""
	if _dialogue_queue.is_empty():
		hide_dialogue()
		return
	
	var next_dialogue: Dictionary = _dialogue_queue.pop_front()
	show_dialogue(
		next_dialogue["speaker"],
		next_dialogue["text"],
		next_dialogue.get("portrait")
	)


# ==============================================================================
# EFFET MACHINE À ÉCRIRE
# ==============================================================================

func _display_next_character() -> void:
	"""Affiche le prochain caractère."""
	if char_index >= current_text.length():
		_finish_typing()
		return
	
	var char := current_text[char_index]
	displayed_text += char
	char_index += 1
	
	# Mettre à jour le label
	if text_label:
		text_label.text = displayed_text
	
	character_displayed.emit(char)
	
	# Jouer un son de frappe
	_char_count_for_sound += 1
	if _char_count_for_sound >= sound_interval:
		_char_count_for_sound = 0
		_play_typing_sound()
	
	# Ajuster le délai selon la ponctuation
	if char in ".!?":
		_current_delay = PUNCTUATION_DELAY
	elif char in ",;:":
		_current_delay = PUNCTUATION_DELAY * 0.5
	else:
		_current_delay = FAST_CHAR_DELAY if skip_requested else char_delay


func _finish_typing() -> void:
	"""Termine l'effet de frappe."""
	is_typing = false
	text_fully_displayed.emit()
	
	if continue_indicator:
		continue_indicator.visible = true
	
	# Auto-avance si activée
	if auto_advance:
		await get_tree().create_timer(auto_advance_delay).timeout
		_advance_dialogue()


func skip_typing() -> void:
	"""Affiche immédiatement tout le texte."""
	if not is_typing:
		return
	
	displayed_text = current_text
	char_index = current_text.length()
	
	if text_label:
		text_label.text = displayed_text
	
	_finish_typing()


func _handle_advance_input() -> void:
	"""Gère l'input pour avancer."""
	if is_typing:
		# Accélérer ou skip
		skip_requested = true
		skip_typing()
	else:
		# Passer au dialogue suivant
		_advance_dialogue()


func _advance_dialogue() -> void:
	"""Avance au dialogue suivant."""
	if not _dialogue_queue.is_empty():
		_show_next_queued_dialogue()
	else:
		hide_dialogue()


# ==============================================================================
# CACHER LE DIALOGUE
# ==============================================================================

func hide_dialogue() -> void:
	"""Cache le panneau de dialogue."""
	is_active = false
	is_typing = false
	
	if dialogue_panel:
		dialogue_panel.visible = false
	
	dialogue_finished.emit()


# ==============================================================================
# POLICE DYSLEXIE
# ==============================================================================

func _load_fonts() -> void:
	"""Charge les polices."""
	# Police dyslexie
	if ResourceLoader.exists(DYSLEXIA_FONT_PATH):
		_dyslexia_font = load(DYSLEXIA_FONT_PATH)
	
	# Police par défaut
	if ResourceLoader.exists(DEFAULT_FONT_PATH):
		_default_font = load(DEFAULT_FONT_PATH)


func _apply_dyslexia_font() -> void:
	"""Applique la police dyslexie si activée."""
	var accessibility_manager = get_node_or_null("/root/AccessibilityManager")
	if not accessibility_manager:
		return
	
	var use_dyslexia := false
	if accessibility_manager.has_method("is_dyslexia_mode_enabled"):
		use_dyslexia = accessibility_manager.is_dyslexia_mode_enabled()
	elif "dyslexia_mode_enabled" in accessibility_manager:
		use_dyslexia = accessibility_manager.dyslexia_mode_enabled
	
	if use_dyslexia and _dyslexia_font:
		if text_label:
			text_label.add_theme_font_override("normal_font", _dyslexia_font)
		if speaker_label:
			speaker_label.add_theme_font_override("font", _dyslexia_font)
	elif _default_font:
		if text_label:
			text_label.remove_theme_font_override("normal_font")
		if speaker_label:
			speaker_label.remove_theme_font_override("font")


func _on_dyslexia_mode_changed(enabled: bool) -> void:
	"""Callback quand le mode dyslexie change."""
	_apply_dyslexia_font()


# ==============================================================================
# AUDIO
# ==============================================================================

func _play_typing_sound() -> void:
	"""Joue un son de frappe."""
	if typing_sound and not audio_player.playing:
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Variation
		audio_player.play()


# ==============================================================================
# TTS (ACCESSIBILITÉ)
# ==============================================================================

func speak_dialogue() -> void:
	"""Lit le dialogue via TTS pour les non-voyants."""
	var blind_manager = get_node_or_null("/root/BlindAccessibilityManager")
	if blind_manager and blind_manager.has_method("speak"):
		var full_text := ""
		if speaker_label:
			full_text = speaker_label.text + ". "
		full_text += current_text
		blind_manager.speak(full_text)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func is_dialogue_active() -> bool:
	"""Retourne true si un dialogue est affiché."""
	return is_active


func get_current_text() -> String:
	"""Retourne le texte actuel."""
	return current_text


func set_typing_speed(speed: float) -> void:
	"""Définit la vitesse de frappe."""
	char_delay = clamp(speed, 0.01, 0.2)


# ==============================================================================
# SYSTÈME DE CHOIX MULTIPLES
# ==============================================================================

var _choice_container: VBoxContainer = null
var _current_choices: Array = []
var _choice_buttons: Array[Button] = []
var _selected_choice_index: int = -1

func show_dialogue_with_choices(speaker: String, text: String, choices: Array, portrait: Texture2D = null) -> void:
	"""
	Affiche un dialogue avec des choix de réponse.
	@param speaker: Nom du personnage
	@param text: Texte du dialogue
	@param choices: Array de dictionnaires [{text: "", next_id: ""}]
	@param portrait: Portrait optionnel
	"""
	show_dialogue(speaker, text, portrait)
	_current_choices = choices
	
	# Attendre que le texte soit affiché
	await text_fully_displayed
	
	# Afficher les boutons de choix
	_create_choice_buttons(choices)


func _create_choice_buttons(choices: Array) -> void:
	"""Crée les boutons de choix."""
	# Nettoyer les anciens boutons
	_clear_choice_buttons()
	
	# Créer un conteneur si nécessaire
	if not _choice_container:
		_choice_container = VBoxContainer.new()
		_choice_container.name = "ChoiceContainer"
		if dialogue_panel:
			dialogue_panel.add_child(_choice_container)
	
	_choice_container.visible = true
	
	# Style des boutons
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	normal_style.set_corner_radius_all(6)
	normal_style.border_color = Color(0, 0.8, 0.8, 0.8)
	normal_style.set_border_width_all(2)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0, 0.3, 0.3, 0.9)
	hover_style.set_corner_radius_all(6)
	hover_style.border_color = Color(0, 1, 1, 1)
	hover_style.set_border_width_all(2)
	
	# Créer les boutons
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.text = str(i + 1) + ". " + choice.get("text", "...")
		button.custom_minimum_size = Vector2(400, 50)
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.pressed.connect(_on_choice_selected.bind(i))
		
		_choice_container.add_child(button)
		_choice_buttons.append(button)
	
	# Focus sur le premier bouton pour accessibilité
	if _choice_buttons.size() > 0:
		_choice_buttons[0].grab_focus()
	
	# Annoncer les choix via TTS
	_announce_choices(choices)


func _announce_choices(choices: Array) -> void:
	"""Annonce les choix via TTS."""
	var tts = get_node_or_null("/root/TTSManager")
	if not tts:
		return
	
	var announcement := "Choix disponibles: "
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		announcement += str(i + 1) + ", " + choice.get("text", "") + ". "
	
	tts.speak(announcement)


func _on_choice_selected(choice_index: int) -> void:
	"""Callback quand un choix est sélectionné."""
	_selected_choice_index = choice_index
	
	# Émettre le signal
	choice_selected.emit(choice_index)
	
	# Annoncer le choix
	var tts = get_node_or_null("/root/TTSManager")
	if tts and choice_index < _current_choices.size():
		var choice: Dictionary = _current_choices[choice_index]
		tts.speak("Choix: " + choice.get("text", ""))
	
	# Nettoyer et passer à la suite
	_clear_choice_buttons()
	
	# Traiter le choix selon le next_id
	if choice_index < _current_choices.size():
		var choice: Dictionary = _current_choices[choice_index]
		var next_id: String = choice.get("next_id", "")
		var consequence: String = choice.get("consequence", "")
		
		if not consequence.is_empty():
			# Afficher la conséquence du choix
			show_dialogue("", consequence)
		elif not next_id.is_empty():
			# Aller au dialogue suivant
			_go_to_dialogue(next_id)
		else:
			# Fin de la branche
			_advance_dialogue()


func _go_to_dialogue(dialogue_id: String) -> void:
	"""
	Navigue vers un dialogue ou noeud spécifique.
	@param dialogue_id: ID du dialogue ou format "dialogue_id.node_id"
	"""
	# Vérifier si c'est un format compound (dialogue_id.node_id)
	if "." in dialogue_id:
		var parts := dialogue_id.split(".")
		var target_dialogue := parts[0]
		var target_node := parts[1] if parts.size() > 1 else "start"
		
		if _dialogues_database.has(target_dialogue):
			_current_dialogue_id = target_dialogue
			var dialogue_data: Dictionary = _dialogues_database[target_dialogue]
			_play_dialogue_node(dialogue_data, target_node)
			return
	
	# Vérifier si c'est un noeud dans le dialogue actuel
	if _current_dialogue_id and _dialogues_database.has(_current_dialogue_id):
		var current_data: Dictionary = _dialogues_database[_current_dialogue_id]
		var nodes: Dictionary = current_data.get("nodes", {})
		
		if nodes.has(dialogue_id):
			_play_dialogue_node(current_data, dialogue_id)
			return
	
	# Sinon, essayer comme nouveau dialogue
	if _dialogues_database.has(dialogue_id):
		start_npc_dialogue(dialogue_id)
		return
	
	# Non trouvé
	push_warning("DialogueSystem: Dialogue/noeud non trouvé: " + dialogue_id)
	hide_dialogue()


func _clear_choice_buttons() -> void:
	"""Supprime les boutons de choix."""
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()
	
	if _choice_container:
		_choice_container.visible = false


func get_selected_choice() -> int:
	"""Retourne l'index du dernier choix sélectionné."""
	return _selected_choice_index


func has_active_choices() -> bool:
	"""Retourne true si des choix sont affichés."""
	return _choice_buttons.size() > 0


# ==============================================================================
# BASE DE DONNÉES DES DIALOGUES
# ==============================================================================

func _load_dialogues_database() -> void:
	"""Charge la base de données des dialogues depuis le JSON."""
	if not FileAccess.file_exists(DIALOGUES_PATH):
		push_warning("DialogueSystem: Fichier dialogues.json non trouvé")
		return
	
	var file := FileAccess.open(DIALOGUES_PATH, FileAccess.READ)
	if not file:
		return
	
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	
	if parse_result != OK:
		push_error("DialogueSystem: Erreur de parsing JSON: %s (ligne %d)" % [
			json.get_error_message(), 
			json.get_error_line()
		])
		return
	
	if json.data == null or not json.data is Dictionary:
		push_error("DialogueSystem: Format JSON invalide - dictionnaire attendu")
		return
	
	var data: Dictionary = json.data
	_dialogues_database = data.get("dialogues", {})
	print("DialogueSystem: %d dialogues chargés" % _dialogues_database.size())


func start_npc_dialogue(dialogue_id: String) -> void:
	"""
	Démarre un dialogue depuis la base de données.
	@param dialogue_id: ID du dialogue (ex: "npc_vendor_01")
	"""
	if not _dialogues_database.has(dialogue_id):
		push_error("DialogueSystem: Dialogue inconnu: " + dialogue_id)
		return
	
	var dialogue_data: Dictionary = _dialogues_database[dialogue_id]
	_current_dialogue_id = dialogue_id
	_current_node_id = "start"
	
	# Jouer le premier noeud
	_play_dialogue_node(dialogue_data, "start")


func _play_dialogue_node(dialogue_data: Dictionary, node_id: String) -> void:
	"""Joue un noeud de dialogue."""
	var nodes: Dictionary = dialogue_data.get("nodes", {})
	if not nodes.has(node_id):
		hide_dialogue()
		return
	
	var node: Dictionary = nodes[node_id]
	_current_node_id = node_id
	
	# Vérifier si fin du dialogue
	if node.get("end", false):
		if node.get("text", "").is_empty():
			hide_dialogue()
			return
	
	# Charger le portrait
	var portrait: Texture2D = null
	var portrait_path: String = dialogue_data.get("portrait", "")
	if portrait_path and ResourceLoader.exists(portrait_path):
		portrait = load(portrait_path)
	
	# Afficher le texte
	var speaker_name: String = dialogue_data.get("name", "???")
	var text: String = node.get("text", "")
	
	# Vérifier si il y a des choix
	var choices: Array = node.get("choices", [])
	
	if choices.size() > 0:
		show_dialogue_with_choices(speaker_name, text, choices, portrait)
	else:
		show_dialogue(speaker_name, text, portrait)
		
		# Configurer l'avance automatique ou attendre input
		if node.get("auto_advance", false):
			await text_fully_displayed
			await get_tree().create_timer(1.5).timeout
			_on_dialogue_node_complete(node)
		else:
			await text_fully_displayed
			# Attendre l'input pour continuer
			await dialogue_finished
			_on_dialogue_node_complete(node)
	
	# Exécuter les actions du noeud
	_execute_node_actions(node)


func _execute_node_actions(node: Dictionary) -> void:
	"""Exécute les actions associées à un noeud."""
	# Action: ouvrir la boutique
	if node.get("action") == "open_shop":
		var shop = get_node_or_null("/root/ShopSystem")
		if shop and shop.has_method("open_shop"):
			shop.open_shop()
	
	# Changement de réputation
	var rep_change: Dictionary = node.get("reputation_change", {})
	if not rep_change.is_empty():
		var rep_manager = get_node_or_null("/root/ReputationManager")
		if rep_manager:
			var faction: String = rep_change.get("faction", "")
			var amount: int = rep_change.get("amount", 0)
			rep_manager.change_reputation(faction, amount)
	
	# Démarrer une mission
	var mission_id: String = node.get("start_mission", "")
	if not mission_id.is_empty():
		var mission_manager = get_node_or_null("/root/MissionManager")
		if mission_manager:
			# Chercher la mission par ID (string ou int)
			mission_manager.start_mission(mission_id.to_int() if mission_id.is_valid_int() else 0)
	
	# Débloquer du lore/info
	var unlock: String = node.get("unlock", "")
	if not unlock.is_empty():
		# Stocker dans SaveManager ou un système de codex
		var save = get_node_or_null("/root/SaveManager")
		if save and save.has_method("unlock_lore"):
			save.unlock_lore(unlock)


func _on_dialogue_node_complete(node: Dictionary) -> void:
	"""Appelé quand un noeud de dialogue est terminé."""
	# Vérifier si fin
	if node.get("end", false):
		hide_dialogue()
		return
	
	# Passer au noeud suivant
	var next_id: String = node.get("next", "")
	if not next_id.is_empty() and _current_dialogue_id:
		var dialogue_data: Dictionary = _dialogues_database[_current_dialogue_id]
		_play_dialogue_node(dialogue_data, next_id)
	else:
		hide_dialogue()


func get_dialogue_data(dialogue_id: String) -> Dictionary:
	"""Retourne les données d'un dialogue."""
	return _dialogues_database.get(dialogue_id, {})


