# ==============================================================================
# CutsceneManager.gd - Système de cutscenes et séquences scriptées
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les cinématiques, transitions, et moments narratifs
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal cutscene_started(cutscene_id: String)
signal cutscene_ended(cutscene_id: String)
signal cutscene_step_changed(step_index: int)
signal dialogue_triggered(speaker: String, text: String)
signal camera_moved(target_position: Vector3)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum StepType {
	DIALOGUE,       # Affiche un dialogue
	CAMERA_MOVE,    # Déplace la caméra
	WAIT,           # Pause
	ANIMATION,      # Joue une animation
	SOUND,          # Joue un son
	SPAWN,          # Fait apparaître un objet/NPC
	FADE,           # Fondu noir
	CALL            # Appelle une fonction
}

# ==============================================================================
# CLASSES
# ==============================================================================

class CutsceneStep:
	var type: StepType = StepType.DIALOGUE
	var data: Dictionary = {}
	var duration: float = 0.0
	var wait_for_input: bool = false
	var audio_description: String = ""  ## Description audio pour accessibilité

class Cutscene:
	var id: String = ""
	var name: String = ""
	var steps: Array[CutsceneStep] = []
	var can_skip: bool = true
	var pause_gameplay: bool = true
	var audio_description_enabled: bool = true  ## Active les descriptions audio

# ==============================================================================
# CONSTANTES
# ==============================================================================
const CUTSCENES_PATH := "res://data/cutscenes.json"

# ==============================================================================
# VARIABLES
# ==============================================================================
var cutscenes: Dictionary = {}  # id -> Cutscene
var current_cutscene: Cutscene = null
var current_step_index: int = 0
var is_playing: bool = false
var _skip_requested: bool = false

# Références
var _camera_original_transform: Transform3D
var _player_ref: Node3D = null

# UI
var _fade_overlay: ColorRect = null
var _cutscene_bars: Control = null  # Barres noires cinématiques

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_load_cutscenes()
	_create_ui()


func _input(event: InputEvent) -> void:
	"""Gestion du skip."""
	if not is_playing:
		return
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if current_cutscene and current_cutscene.can_skip:
			_skip_requested = true


# ==============================================================================
# CHARGEMENT DES CUTSCENES
# ==============================================================================

func _load_cutscenes() -> void:
	"""Charge les cutscenes depuis le JSON."""
	if not FileAccess.file_exists(CUTSCENES_PATH):
		_create_default_cutscenes()
		return
	
	var file := FileAccess.open(CUTSCENES_PATH, FileAccess.READ)
	if not file:
		_create_default_cutscenes()
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Dictionary = json.data
		for cutscene_id in data.get("cutscenes", {}):
			var cs_data: Dictionary = data["cutscenes"][cutscene_id]
			var cutscene := Cutscene.new()
			cutscene.id = cutscene_id
			cutscene.name = cs_data.get("name", "")
			cutscene.can_skip = cs_data.get("can_skip", true)
			cutscene.pause_gameplay = cs_data.get("pause_gameplay", true)
			
			for step_data in cs_data.get("steps", []):
				var step := CutsceneStep.new()
				step.type = _parse_step_type(step_data.get("type", "dialogue"))
				step.data = step_data.get("data", {})
				step.duration = step_data.get("duration", 0.0)
				step.wait_for_input = step_data.get("wait_for_input", false)
				cutscene.steps.append(step)
			
			cutscenes[cutscene_id] = cutscene
	
	file.close()
	print("CutsceneManager: %d cutscenes chargées" % cutscenes.size())


func _parse_step_type(type_str: String) -> StepType:
	"""Convertit une string en StepType."""
	match type_str.to_lower():
		"dialogue": return StepType.DIALOGUE
		"camera_move": return StepType.CAMERA_MOVE
		"wait": return StepType.WAIT
		"animation": return StepType.ANIMATION
		"sound": return StepType.SOUND
		"spawn": return StepType.SPAWN
		"fade": return StepType.FADE
		"call": return StepType.CALL
	return StepType.DIALOGUE


func _create_default_cutscenes() -> void:
	"""Crée les cutscenes par défaut (intro, etc.)."""
	
	# === INTRO ===
	var intro := Cutscene.new()
	intro.id = "intro"
	intro.name = "Prologue"
	intro.can_skip = true
	
	# Fondu depuis noir
	var fade_in := CutsceneStep.new()
	fade_in.type = StepType.FADE
	fade_in.data = {"from_black": true, "duration": 2.0}
	fade_in.duration = 2.0
	intro.steps.append(fade_in)
	
	# Dialogue intro
	var dialogue1 := CutsceneStep.new()
	dialogue1.type = StepType.DIALOGUE
	dialogue1.data = {"speaker": "ARIA", "text": "Réveil du système... Bienvenue, Runner."}
	dialogue1.wait_for_input = true
	intro.steps.append(dialogue1)
	
	var dialogue2 := CutsceneStep.new()
	dialogue2.type = StepType.DIALOGUE
	dialogue2.data = {"speaker": "ARIA", "text": "Neo-Kyoto, 2087. Le monde a changé. Tu dois t'adapter pour survivre."}
	dialogue2.wait_for_input = true
	intro.steps.append(dialogue2)
	
	var dialogue3 := CutsceneStep.new()
	dialogue3.type = StepType.DIALOGUE
	dialogue3.data = {"speaker": "ARIA", "text": "Ta première mission t'attend. Déplace-toi avec le joystick gauche."}
	dialogue3.wait_for_input = true
	intro.steps.append(dialogue3)
	
	cutscenes["intro"] = intro
	
	# === MISSION COMPLETE ===
	var mission_complete := Cutscene.new()
	mission_complete.id = "mission_complete"
	mission_complete.name = "Mission Accomplie"
	mission_complete.can_skip = true
	
	var success_sound := CutsceneStep.new()
	success_sound.type = StepType.SOUND
	success_sound.data = {"sound": "res://audio/sfx/ui/confirmation_001.ogg"}
	success_sound.duration = 0.5
	mission_complete.steps.append(success_sound)
	
	var success_dialogue := CutsceneStep.new()
	success_dialogue.type = StepType.DIALOGUE
	success_dialogue.data = {"speaker": "ARIA", "text": "Mission accomplie. Récompenses transférées."}
	success_dialogue.wait_for_input = true
	mission_complete.steps.append(success_dialogue)
	
	cutscenes["mission_complete"] = mission_complete


# ==============================================================================
# LECTURE DES CUTSCENES
# ==============================================================================

func play_cutscene(cutscene_id: String) -> void:
	"""
	Joue une cutscene.
	@param cutscene_id: ID de la cutscene
	"""
	if not cutscenes.has(cutscene_id):
		push_error("CutsceneManager: Cutscene inconnue: " + cutscene_id)
		return
	
	if is_playing:
		push_warning("CutsceneManager: Une cutscene est déjà en cours")
		return
	
	current_cutscene = cutscenes[cutscene_id]
	current_step_index = 0
	is_playing = true
	_skip_requested = false
	
	# Mettre le jeu en pause si nécessaire
	if current_cutscene.pause_gameplay:
		get_tree().paused = true
	
	# Afficher les barres cinématiques
	_show_cinematic_bars(true)
	
	# Sauvegarder la position de la caméra
	_save_camera_state()
	
	cutscene_started.emit(cutscene_id)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Cinématique: " + current_cutscene.name)
	
	# Démarrer la lecture
	_play_next_step()


func _play_next_step() -> void:
	"""Joue l'étape suivante de la cutscene."""
	if not current_cutscene:
		return
	
	# Vérifier le skip
	if _skip_requested:
		_end_cutscene()
		return
	
	# Vérifier si on a fini
	if current_step_index >= current_cutscene.steps.size():
		_end_cutscene()
		return
	
	var step: CutsceneStep = current_cutscene.steps[current_step_index]
	cutscene_step_changed.emit(current_step_index)
	
	# Lire la description audio si disponible (accessibilité)
	await _read_audio_description(step)
	
	# Exécuter l'étape selon son type
	match step.type:
		StepType.DIALOGUE:
			await _execute_dialogue(step)
		StepType.CAMERA_MOVE:
			await _execute_camera_move(step)
		StepType.WAIT:
			await _execute_wait(step)
		StepType.ANIMATION:
			await _execute_animation(step)
		StepType.SOUND:
			await _execute_sound(step)
		StepType.SPAWN:
			await _execute_spawn(step)
		StepType.FADE:
			await _execute_fade(step)
		StepType.CALL:
			await _execute_call(step)
	
	# Passer à l'étape suivante
	current_step_index += 1
	_play_next_step()


func _end_cutscene() -> void:
	"""Termine la cutscene en cours."""
	if not current_cutscene:
		return
	
	var cutscene_id := current_cutscene.id
	
	# Restaurer la caméra
	_restore_camera_state()
	
	# Masquer les barres cinématiques
	_show_cinematic_bars(false)
	
	# Reprendre le jeu
	if current_cutscene.pause_gameplay:
		get_tree().paused = false
	
	# Réinitialiser le fondu
	if _fade_overlay:
		_fade_overlay.color.a = 0.0
	
	is_playing = false
	current_cutscene = null
	current_step_index = 0
	
	cutscene_ended.emit(cutscene_id)


# ==============================================================================
# EXÉCUTION DES ÉTAPES
# ==============================================================================

func _execute_dialogue(step: CutsceneStep) -> void:
	"""Exécute une étape de dialogue."""
	var speaker: String = step.data.get("speaker", "")
	var text: String = step.data.get("text", "")
	
	dialogue_triggered.emit(speaker, text)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		var full_text := speaker + ": " + text if speaker else text
		tts.speak(full_text)
	
	# Attendre l'input ou un délai
	if step.wait_for_input:
		await _wait_for_input()
	elif step.duration > 0:
		await get_tree().create_timer(step.duration).timeout


func _execute_camera_move(step: CutsceneStep) -> void:
	"""
	Déplace la caméra vers une position avec animation Tween.
	Supporte: position (x,y,z), look_at (lx,ly,lz), duration, ease
	"""
	var camera := get_viewport().get_camera_3d()
	if not camera:
		push_warning("CutsceneManager: Aucune caméra 3D trouvée")
		await get_tree().create_timer(step.data.get("duration", 1.0)).timeout
		return
	
	# Position cible
	var target_pos := Vector3(
		step.data.get("x", camera.global_position.x),
		step.data.get("y", camera.global_position.y),
		step.data.get("z", camera.global_position.z)
	)
	
	# Look at target (optionnel)
	var look_at_pos: Variant = null
	if step.data.has("lx") or step.data.has("look_at_x"):
		look_at_pos = Vector3(
			step.data.get("lx", step.data.get("look_at_x", 0)),
			step.data.get("ly", step.data.get("look_at_y", 0)),
			step.data.get("lz", step.data.get("look_at_z", 0))
		)
	
	var duration: float = step.data.get("duration", 1.0)
	var ease_type: String = step.data.get("ease", "ease_out")
	
	camera_moved.emit(target_pos)
	
	# Créer le tween
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Configurer l'easing
	match ease_type.to_lower():
		"linear":
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.set_trans(Tween.TRANS_LINEAR)
		"ease_in":
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_QUAD)
		"ease_out":
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_QUAD)
		"ease_in_out":
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.set_trans(Tween.TRANS_QUAD)
		"bounce":
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BOUNCE)
		"elastic":
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_ELASTIC)
		_:
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_QUAD)
	
	# Animer la position
	tween.tween_property(camera, "global_position", target_pos, duration)
	
	# Animer le look_at si spécifié
	if look_at_pos != null:
		# Calculer la rotation cible
		var target_transform := camera.global_transform.looking_at(look_at_pos, Vector3.UP)
		tween.tween_property(camera, "global_rotation", target_transform.basis.get_euler(), duration)
	
	await tween.finished


func _execute_wait(step: CutsceneStep) -> void:
	"""Attend un délai."""
	await get_tree().create_timer(step.duration).timeout


func _execute_animation(step: CutsceneStep) -> void:
	"""Joue une animation sur un noeud."""
	var node_path: String = step.data.get("node", "")
	var anim_name: String = step.data.get("animation", "")
	
	var node := get_node_or_null(node_path)
	if node and node.has_node("AnimationPlayer"):
		var anim_player: AnimationPlayer = node.get_node("AnimationPlayer")
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
			await anim_player.animation_finished


func _execute_sound(step: CutsceneStep) -> void:
	"""Joue un son."""
	var sound_path: String = step.data.get("sound", "")
	
	if ResourceLoader.exists(sound_path):
		var audio := AudioStreamPlayer.new()
		audio.stream = load(sound_path)
		add_child(audio)
		audio.play()
		await audio.finished
		audio.queue_free()
	else:
		await get_tree().create_timer(step.duration).timeout


func _execute_spawn(step: CutsceneStep) -> void:
	"""Fait apparaître un objet."""
	var scene_path: String = step.data.get("scene", "")
	var pos := Vector3(step.data.get("x", 0), step.data.get("y", 0), step.data.get("z", 0))
	
	if ResourceLoader.exists(scene_path):
		var scene := load(scene_path) as PackedScene
		var instance := scene.instantiate()
		if instance is Node3D:
			instance.global_position = pos
		get_tree().current_scene.add_child(instance)
	
	if step.duration > 0:
		await get_tree().create_timer(step.duration).timeout


func _execute_fade(step: CutsceneStep) -> void:
	"""Effectue un fondu."""
	if not _fade_overlay:
		return
	
	var from_black: bool = step.data.get("from_black", false)
	var duration: float = step.data.get("duration", 1.0)
	
	var tween := create_tween()
	
	if from_black:
		_fade_overlay.color.a = 1.0
		tween.tween_property(_fade_overlay, "color:a", 0.0, duration)
	else:
		_fade_overlay.color.a = 0.0
		tween.tween_property(_fade_overlay, "color:a", 1.0, duration)
	
	await tween.finished


func _execute_call(step: CutsceneStep) -> void:
	"""Appelle une fonction."""
	var target_path: String = step.data.get("target", "")
	var method_name: String = step.data.get("method", "")
	var args: Array = step.data.get("args", [])
	
	var target := get_node_or_null(target_path)
	if target and target.has_method(method_name):
		target.callv(method_name, args)
	
	if step.duration > 0:
		await get_tree().create_timer(step.duration).timeout


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _wait_for_input() -> void:
	"""Attend que le joueur appuie sur un bouton."""
	while true:
		await get_tree().process_frame
		if _skip_requested:
			break
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("attack"):
			break
		# Touch input
		if Input.is_action_just_pressed("touch_tap"):
			break


func _save_camera_state() -> void:
	"""Sauvegarde l'état de la caméra."""
	var camera := get_viewport().get_camera_3d()
	if camera:
		_camera_original_transform = camera.global_transform


func _restore_camera_state() -> void:
	"""Restaure l'état de la caméra."""
	var camera := get_viewport().get_camera_3d()
	if camera and _camera_original_transform:
		camera.global_transform = _camera_original_transform


# ==============================================================================
# UI
# ==============================================================================

func _create_ui() -> void:
	"""Crée les éléments UI nécessaires."""
	# Overlay de fondu
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)
	
	# Barres cinématiques
	_cutscene_bars = Control.new()
	_cutscene_bars.anchors_preset = Control.PRESET_FULL_RECT
	_cutscene_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutscene_bars.visible = false
	add_child(_cutscene_bars)
	
	var top_bar := ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	top_bar.custom_minimum_size = Vector2(0, 80)
	_cutscene_bars.add_child(top_bar)
	
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color.BLACK
	bottom_bar.anchors_preset = Control.PRESET_BOTTOM_WIDE
	bottom_bar.custom_minimum_size = Vector2(0, 80)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cutscene_bars.add_child(bottom_bar)


func _show_cinematic_bars(show: bool) -> void:
	"""Affiche/masque les barres cinématiques."""
	if _cutscene_bars:
		_cutscene_bars.visible = show


# ==============================================================================
# MÉTHODES PUBLIQUES
# ==============================================================================

func is_cutscene_playing() -> bool:
	"""Retourne true si une cutscene est en cours."""
	return is_playing


func skip_current_cutscene() -> void:
	"""Force le skip de la cutscene actuelle."""
	if is_playing and current_cutscene and current_cutscene.can_skip:
		_skip_requested = true


func get_cutscene_list() -> Array:
	"""Retourne la liste des IDs de cutscenes disponibles."""
	return cutscenes.keys()


func _read_audio_description(step: CutsceneStep) -> void:
	"""
	Lit la description audio d'une étape si disponible.
	Pour l'accessibilité des joueurs malvoyants.
	"""
	if step.audio_description.is_empty():
		return
	
	# Vérifier si le mode accessibilité est activé
	var accessibility = get_node_or_null("/root/AccessibilityManager")
	var blind_mode := false
	if accessibility and accessibility.get("blind_mode_enabled"):
		blind_mode = accessibility.blind_mode_enabled
	
	# Aussi lire si la cutscene a les descriptions activées
	var cutscene_enabled := current_cutscene and current_cutscene.audio_description_enabled
	
	if blind_mode or cutscene_enabled:
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak(step.audio_description, true)  # Prioritaire
			# Petite pause pour laisser la description
			await get_tree().create_timer(0.5).timeout

