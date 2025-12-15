# ==============================================================================
# AudioTutorial.gd - Tutoriel 100% Audio pour accessibilité
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Système de tutoriel entièrement accessible par audio/TTS
# ==============================================================================

extends Node

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal tutorial_started
signal step_narrated(step_index: int)
signal step_completed(step_index: int)
signal tutorial_completed
signal hint_given(hint_text: String)

# ==============================================================================
# CONSTANTES
# ==============================================================================
const REPEAT_HINT_DELAY := 15.0  ## Répéter l'instruction après X secondes

# ==============================================================================
# ÉTAPES DU TUTORIEL
# ==============================================================================
var tutorial_steps: Array[Dictionary] = [
	{
		"id": "welcome",
		"narration": "Bienvenue dans Neo-Kyoto, Runner. Je suis ARIA, ton interface d'assistance neurale. Ce tutoriel te guidera vocalement à travers les bases du jeu. Tu peux naviguer en utilisant le son spatial comme guide. Appuie sur n'importe quelle touche pour continuer.",
		"wait_for": "any_input",
		"audio_cue": "tutorial_start"
	},
	{
		"id": "audio_navigation",
		"narration": "Dans ce jeu, le son est ton meilleur allié. Les ennemis émettent des sons distinctifs. Plus ils sont proches, plus le son est fort. Utilise ces indices audio pour te repérer. Appuie sur une touche pour continuer.",
		"wait_for": "any_input",
		"audio_cue": "info"
	},
	{
		"id": "movement",
		"narration": "Déplaçons-nous. Utilise le joystick gauche ou les touches WASD pour te déplacer. Un son de pas confirmera ton mouvement. Déplace-toi dans n'importe quelle direction.",
		"wait_for": "movement",
		"hint": "Utilise le joystick gauche ou les touches W, A, S, D pour te déplacer.",
		"audio_cue": "objective"
	},
	{
		"id": "spatial_audio",
		"narration": "Excellent! Tu entends ce bip? C'est un objectif. Le son vient de ta droite ou de ta gauche selon sa position. Tourne-toi vers le son et avance vers lui.",
		"wait_for": "reach_objective",
		"hint": "Suis le son du bip pour trouver l'objectif.",
		"audio_cue": "objective_ping",
		"spawn_beacon": true
	},
	{
		"id": "attack",
		"narration": "Parfait! Maintenant, le combat. Appuie sur le bouton d'attaque pour frapper. Un son de frappe confirmera l'action. Effectue trois attaques.",
		"wait_for": "attack_count",
		"required_count": 3,
		"hint": "Appuie sur le bouton d'attaque ou la touche J pour attaquer.",
		"audio_cue": "combat_ready"
	},
	{
		"id": "combo",
		"narration": "Les combos sont puissants. Enchaîne rapidement plusieurs attaques. Le son devient plus intense avec chaque coup. Essaie un combo de trois coups.",
		"wait_for": "combo",
		"required_count": 3,
		"hint": "Attaque rapidement trois fois de suite pour un combo.",
		"audio_cue": "combo_hint"
	},
	{
		"id": "dash",
		"narration": "Le dash est vital pour esquiver. Appuie sur le bouton de dash pour effectuer une esquive rapide. Un son de glissement confirme l'action. Effectue deux dash.",
		"wait_for": "dash_count",
		"required_count": 2,
		"hint": "Appuie sur le bouton de dash ou la touche K pour esquiver.",
		"audio_cue": "dash_hint"
	},
	{
		"id": "enemy_detection",
		"narration": "Un ennemi approche! Écoute son bruit de pas métallique. Il vient de devant. Les ennemis émettent un son aigu quand ils t'attaquent. Prépare-toi!",
		"wait_for": "enemy_killed",
		"hint": "Un ennemi est proche. Écoute ses mouvements et attaque-le.",
		"audio_cue": "enemy_alert",
		"spawn_enemy": true
	},
	{
		"id": "health_warning",
		"narration": "Si ta santé est basse, un battement de cœur t'avertira. Plus il est rapide, plus tu es en danger. Les kits de soins émettent un son de pulsation verte.",
		"wait_for": "any_input",
		"audio_cue": "health_low"
	},
	{
		"id": "menu_navigation",
		"narration": "Pour naviguer dans les menus, utilise les flèches ou le joystick. Chaque option est lue à voix haute. Appuie sur entrée ou le bouton A pour sélectionner. Appuie sur échap ou B pour revenir.",
		"wait_for": "any_input",
		"audio_cue": "menu_hint"
	},
	{
		"id": "complete",
		"narration": "Félicitations, Runner! Tu maîtrises les bases. Le monde de Neo-Kyoto t'attend. Souviens-toi: le son est ta vision. Bonne chance!",
		"wait_for": "none",
		"audio_cue": "tutorial_complete"
	}
]

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_step: int = -1
var is_active: bool = false
var _attack_count: int = 0
var _dash_count: int = 0
var _combo_count: int = 0
var _hint_timer: float = 0.0
var _current_beacon: Node3D = null
var _spawned_enemy: Node3D = null

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
var tts: Node = null
var audio_cue: Node = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	tts = get_node_or_null("/root/TTSManager")
	audio_cue = get_node_or_null("/root/AudioCueSystem")


func _process(delta: float) -> void:
	"""Mise à jour."""
	if not is_active or current_step < 0:
		return
	
	# Timer pour répéter l'hint
	_hint_timer += delta
	if _hint_timer >= REPEAT_HINT_DELAY:
		_hint_timer = 0.0
		_repeat_current_hint()


func _input(event: InputEvent) -> void:
	"""Gestion des inputs."""
	if not is_active or current_step < 0:
		return
	
	var step: Dictionary = tutorial_steps[current_step]
	var wait_for: String = step.get("wait_for", "any_input")
	
	match wait_for:
		"any_input":
			if event is InputEventKey and event.pressed:
				_complete_current_step()
			elif event is InputEventScreenTouch and event.pressed:
				_complete_current_step()
			elif event is InputEventJoypadButton and event.pressed:
				_complete_current_step()
		
		"movement":
			if _is_movement_input(event):
				_complete_current_step()
		
		"attack_count":
			if event.is_action_pressed("attack"):
				_attack_count += 1
				_play_feedback("attack")
				if _attack_count >= step.get("required_count", 1):
					_complete_current_step()
		
		"combo":
			if event.is_action_pressed("attack"):
				_combo_count += 1
				if _combo_count >= step.get("required_count", 3):
					_complete_current_step()
		
		"dash_count":
			if event.is_action_pressed("dash"):
				_dash_count += 1
				_play_feedback("dash")
				if _dash_count >= step.get("required_count", 1):
					_complete_current_step()


# ==============================================================================
# CONTRÔLE DU TUTORIEL
# ==============================================================================

func start_tutorial() -> void:
	"""Démarre le tutoriel audio."""
	is_active = true
	current_step = -1
	tutorial_started.emit()
	
	# Musique calme
	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.set_volume(-10.0)  # Plus bas pour laisser place au TTS
	
	_advance_to_next_step()


func _advance_to_next_step() -> void:
	"""Passe à l'étape suivante."""
	current_step += 1
	
	if current_step >= tutorial_steps.size():
		_complete_tutorial()
		return
	
	var step: Dictionary = tutorial_steps[current_step]
	
	# Reset compteurs
	_reset_counters()
	_hint_timer = 0.0
	
	# Jouer le cue audio
	if audio_cue and step.has("audio_cue"):
		audio_cue.play_cue(step["audio_cue"])
	
	# Attendre un peu avant la narration
	await get_tree().create_timer(0.5).timeout
	
	# Narration TTS
	_narrate(step.get("narration", ""))
	step_narrated.emit(current_step)
	
	# Actions spéciales
	if step.get("spawn_beacon", false):
		_spawn_audio_beacon()
	
	if step.get("spawn_enemy", false):
		_spawn_tutorial_enemy()
	
	# Si pas d'attente, passer directement
	if step.get("wait_for") == "none":
		await get_tree().create_timer(5.0).timeout
		_complete_current_step()


func _complete_current_step() -> void:
	"""Termine l'étape actuelle."""
	if current_step < 0 or current_step >= tutorial_steps.size():
		return
	
	# Nettoyer les spawns
	if _current_beacon:
		_current_beacon.queue_free()
		_current_beacon = null
	
	# Feedback audio
	_play_feedback("step_complete")
	
	step_completed.emit(current_step)
	
	# Petite pause avant la suite
	await get_tree().create_timer(1.0).timeout
	
	_advance_to_next_step()


func _complete_tutorial() -> void:
	"""Termine le tutoriel."""
	is_active = false
	tutorial_completed.emit()
	
	# Restaurer la musique
	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.set_volume(0.0)
	
	# Sauvegarder
	var save = get_node_or_null("/root/SaveManager")
	if save and save.has_method("set_setting"):
		save.set_setting("audio_tutorial_completed", true)
	
	# Toast
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_achievement("Tutoriel Audio Complété!")


func skip_tutorial() -> void:
	"""Passe le tutoriel."""
	if audio_cue:
		audio_cue.play_cue("menu_back")
	
	if tts:
		tts.speak("Tutoriel passé")
	
	is_active = false
	tutorial_completed.emit()


# ==============================================================================
# NARRATION
# ==============================================================================

func _narrate(text: String) -> void:
	"""Narre un texte via TTS."""
	if tts:
		tts.speak(text)


func _repeat_current_hint() -> void:
	"""Répète l'instruction actuelle."""
	if current_step < 0 or current_step >= tutorial_steps.size():
		return
	
	var step: Dictionary = tutorial_steps[current_step]
	var hint: String = step.get("hint", "")
	
	if not hint.is_empty():
		_narrate(hint)
		hint_given.emit(hint)
		
		if audio_cue:
			audio_cue.play_cue("hint")


# ==============================================================================
# SPAWNS
# ==============================================================================

func _spawn_audio_beacon() -> void:
	"""Spawn un beacon audio à trouver."""
	# Créer un beacon qui émet un son
	_current_beacon = Node3D.new()
	
	# Position aléatoire à ~10m du joueur
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node3D = players[0]
		var angle := randf() * TAU
		var offset := Vector3(cos(angle), 0, sin(angle)) * 10.0
		_current_beacon.global_position = player.global_position + offset
	
	# Audio player
	var audio := AudioStreamPlayer3D.new()
	audio.max_distance = 30.0
	audio.unit_size = 2.0
	_current_beacon.add_child(audio)
	
	# Charger un son de bip
	if ResourceLoader.exists("res://audio/sfx/ui/bong_001.ogg"):
		audio.stream = load("res://audio/sfx/ui/bong_001.ogg")
	
	get_tree().current_scene.add_child(_current_beacon)
	
	# Boucle de son
	_beacon_sound_loop(audio)
	
	# Connecter pour détecter l'arrivée
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	collision.shape = sphere
	area.add_child(collision)
	_current_beacon.add_child(area)
	
	area.body_entered.connect(_on_beacon_reached)


func _beacon_sound_loop(audio: AudioStreamPlayer3D) -> void:
	"""Boucle le son du beacon."""
	while is_instance_valid(audio) and is_instance_valid(_current_beacon):
		audio.play()
		await get_tree().create_timer(1.5).timeout


func _on_beacon_reached(body: Node3D) -> void:
	"""Appelé quand le joueur atteint le beacon."""
	if body.is_in_group("player"):
		var step: Dictionary = tutorial_steps[current_step]
		if step.get("wait_for") == "reach_objective":
			_play_feedback("objective_reached")
			_complete_current_step()


func _spawn_tutorial_enemy() -> void:
	"""Spawn un ennemi du tutoriel."""
	var spawn_manager = get_node_or_null("/root/SpawnManager")
	if spawn_manager:
		# Utiliser le spawn manager
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player: Node3D = players[0]
			# Spawn devant le joueur
			var spawn_pos := player.global_position + player.global_transform.basis.z * -8.0
			
			_spawned_enemy = spawn_manager.spawn_at_point("", "robot")
			if _spawned_enemy:
				_spawned_enemy.global_position = spawn_pos
				
				# Connecter la mort
				if _spawned_enemy.has_node("HealthComponent"):
					var health := _spawned_enemy.get_node("HealthComponent")
					health.died.connect(_on_tutorial_enemy_killed)


func _on_tutorial_enemy_killed() -> void:
	"""Appelé quand l'ennemi du tutoriel est tué."""
	var step: Dictionary = tutorial_steps[current_step]
	if step.get("wait_for") == "enemy_killed":
		_play_feedback("enemy_killed")
		_complete_current_step()


# ==============================================================================
# FEEDBACK AUDIO
# ==============================================================================

func _play_feedback(feedback_type: String) -> void:
	"""Joue un feedback audio."""
	if not audio_cue:
		return
	
	match feedback_type:
		"step_complete":
			audio_cue.play_cue("success")
		"attack":
			audio_cue.play_cue("attack_hit")
		"dash":
			audio_cue.play_cue("dash")
		"objective_reached":
			audio_cue.play_cue("pickup")
		"enemy_killed":
			audio_cue.play_cue("enemy_death")


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _is_movement_input(event: InputEvent) -> bool:
	"""Vérifie si c'est un input de mouvement."""
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		return true
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		return true
	if event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		return true
	return false


func _reset_counters() -> void:
	"""Reset les compteurs d'actions."""
	_attack_count = 0
	_dash_count = 0
	_combo_count = 0


func is_tutorial_active() -> bool:
	"""Retourne si le tutoriel est actif."""
	return is_active


func get_current_step() -> int:
	"""Retourne l'étape actuelle."""
	return current_step
