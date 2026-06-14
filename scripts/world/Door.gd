# ==============================================================================
# Door.gd - Portes interactives
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Portes avec différents modes de déverrouillage
# ==============================================================================

extends StaticBody3D
class_name Door

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal door_opened
signal door_closed
signal door_locked
signal door_unlocked
signal hack_started
signal hack_completed
signal hack_failed

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum DoorState { CLOSED, OPENING, OPEN, CLOSING }
enum LockType { NONE, KEY, HACK, SWITCH, MISSION }

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Configuration")
@export var door_id: String = "door_001"
@export var lock_type: LockType = LockType.NONE
@export var required_key_id: String = ""
@export var hack_difficulty: int = 1  ## 1-5
@export var auto_close: bool = true
@export var auto_close_delay: float = 5.0

@export_group("Mouvement")
@export var open_offset: Vector3 = Vector3(0, 3, 0)  ## Sliding up
@export var open_duration: float = 0.8
@export var open_rotation: float = 0.0  ## For swing doors (radians)

@export_group("Visuel")
@export var locked_color: Color = Color(1, 0.2, 0.2)
@export var unlocked_color: Color = Color(0.2, 1, 0.4)
@export var hacking_color: Color = Color(1, 0.8, 0)

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_state: DoorState = DoorState.CLOSED
var is_locked: bool = false
var is_being_hacked: bool = false
var _original_position: Vector3
var _original_rotation: float

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var door_mesh: MeshInstance3D = $DoorMesh if has_node("DoorMesh") else null
@onready var indicator_light: OmniLight3D = $IndicatorLight if has_node("IndicatorLight") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null
@onready var interaction_area: Area3D = $InteractionArea if has_node("InteractionArea") else null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	add_to_group("door")
	add_to_group("interactable")

	if lock_type == LockType.HACK:
		add_to_group("hackable")

	_original_position = global_position
	_original_rotation = rotation.y

	# Définir l'état initial
	is_locked = lock_type != LockType.NONE
	_update_indicator()

	# Créer les éléments manquants
	if not interaction_area:
		_create_interaction_area()


func _input(event: InputEvent) -> void:
	"""Gestion des inputs."""
	if event.is_action_pressed("interact"):
		_try_interact()


# ==============================================================================
# INTERACTION
# ==============================================================================

func _try_interact() -> void:
	"""Tente d'interagir avec la porte."""
	# Vérifier si le joueur est à portée
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: Node3D = players[0]
	if global_position.distance_to(player.global_position) > 3.0:
		return

	interact(player)


func interact(interactor: Node3D) -> void:
	"""Interaction principale."""
	if current_state == DoorState.OPENING or current_state == DoorState.CLOSING:
		return

	if is_locked:
		_try_unlock(interactor)
	else:
		toggle()


func _try_unlock(interactor: Node3D) -> void:
	"""Tente de déverrouiller la porte."""
	match lock_type:
		LockType.KEY:
			_try_key_unlock(interactor)
		LockType.HACK:
			_start_hack(interactor)
		LockType.SWITCH:
			_show_switch_required()
		LockType.MISSION:
			_show_mission_required()


func _try_key_unlock(interactor: Node3D) -> void:
	"""Vérifie si le joueur a la clé."""
	var save = get_node_or_null("/root/SaveManager")
	if not save:
		return

	var keys: Array = save.get_value("keys_obtained", [])

	if required_key_id in keys:
		unlock()

		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Porte déverrouillée avec la clé")
	else:
		door_locked.emit()

		var toast = get_node_or_null("/root/ToastNotification")
		if toast:
			toast.show_error("Clé requise: " + required_key_id)

		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Porte verrouillée. Clé nécessaire.")


func _start_hack(interactor: Node3D) -> void:
	"""Démarre le mini-jeu de hacking."""
	if is_being_hacked:
		return

	is_being_hacked = true
	hack_started.emit()

	# Changer la couleur de l'indicateur
	if indicator_light:
		indicator_light.light_color = hacking_color

	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Hacking en cours. Difficulté %d" % hack_difficulty)

	# Lancer le mini-jeu de hacking
	var hacking = get_node_or_null("/root/HackingMinigame")
	if hacking and hacking.has_method("start_hack"):
		hacking.hack_completed.connect(_on_hack_result, CONNECT_ONE_SHOT)
		hacking.start_hack(hack_difficulty)
	else:
		# Fallback: hack automatique basé sur la difficulté
		await get_tree().create_timer(2.0).timeout
		var success := randf() > (hack_difficulty * 0.15)
		_on_hack_result(success)


func _on_hack_result(success: bool) -> void:
	"""Résultat du hacking."""
	is_being_hacked = false

	if success:
		unlock()
		hack_completed.emit()

		var toast = get_node_or_null("/root/ToastNotification")
		if toast:
			toast.show_success("Hack réussi!")
	else:
		hack_failed.emit()

		var toast = get_node_or_null("/root/ToastNotification")
		if toast:
			toast.show_error("Hack échoué!")

		# Déclencher une alarme ?
		_trigger_alarm()

	_update_indicator()


func _show_switch_required() -> void:
	"""Affiche que la porte nécessite un interrupteur."""
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show("Activez l'interrupteur lié", 0)

	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Cette porte nécessite un interrupteur")


func _show_mission_required() -> void:
	"""Affiche que la porte nécessite une mission."""
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show("Mission requise pour accès", 0)

	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Accomplissez la mission pour ouvrir cette porte")


# ==============================================================================
# CONTRÔLE DE LA PORTE
# ==============================================================================

func open() -> void:
	"""Ouvre la porte."""
	if current_state != DoorState.CLOSED or is_locked:
		return

	current_state = DoorState.OPENING
	door_opened.emit()

	# Son d'ouverture
	if audio_player:
		audio_player.play()
	else:
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play_ui("door_open")

	# Animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)

	if open_offset != Vector3.ZERO:
		# Porte coulissante
		tween.tween_property(self, "global_position",
			_original_position + open_offset, open_duration)
	else:
		# Porte pivotante
		tween.tween_property(self, "rotation:y",
			_original_rotation + open_rotation, open_duration)

	await tween.finished
	current_state = DoorState.OPEN

	# Auto-fermeture
	if auto_close:
		await get_tree().create_timer(auto_close_delay).timeout
		close()


func close() -> void:
	"""Ferme la porte."""
	if current_state != DoorState.OPEN:
		return

	current_state = DoorState.CLOSING
	door_closed.emit()

	# Son de fermeture
	if audio_player:
		audio_player.play()
	else:
		var sfx = get_node_or_null("/root/SFXManager")
		if sfx:
			sfx.play_ui("door_close")

	# Animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)

	if open_offset != Vector3.ZERO:
		tween.tween_property(self, "global_position",
			_original_position, open_duration)
	else:
		tween.tween_property(self, "rotation:y",
			_original_rotation, open_duration)

	await tween.finished
	current_state = DoorState.CLOSED


func toggle() -> void:
	"""Bascule l'état de la porte."""
	if current_state == DoorState.CLOSED:
		open()
	elif current_state == DoorState.OPEN:
		close()


func unlock() -> void:
	"""Déverrouille la porte."""
	is_locked = false
	door_unlocked.emit()
	_update_indicator()


func lock() -> void:
	"""Verrouille la porte."""
	is_locked = true
	door_locked.emit()
	_update_indicator()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _update_indicator() -> void:
	"""Met à jour l'indicateur lumineux."""
	if not indicator_light:
		return

	if is_locked:
		indicator_light.light_color = locked_color
	else:
		indicator_light.light_color = unlocked_color


func _trigger_alarm() -> void:
	"""Déclenche une alarme après un hack raté."""
	# Alerter les ennemis proches
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < 20.0:
			if enemy.has_method("alert"):
				enemy.alert(global_position)


func _create_interaction_area() -> void:
	"""Crée l'area d'interaction."""
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	collision.shape = box

	interaction_area.add_child(collision)
	add_child(interaction_area)


# ==============================================================================
# SWITCH EXTERNE
# ==============================================================================

func activate_from_switch() -> void:
	"""Appelé par un interrupteur externe."""
	if lock_type == LockType.SWITCH:
		unlock()
		toggle()


func trigger_from_mission(mission_id: String) -> void:
	"""Appelé quand une mission est complétée."""
	if lock_type == LockType.MISSION:
		unlock()


# ==============================================================================
# ÉTAT
# ==============================================================================

func is_open() -> bool:
	"""Retourne si la porte est ouverte."""
	return current_state == DoorState.OPEN


func is_closed() -> bool:
	"""Retourne si la porte est fermée."""
	return current_state == DoorState.CLOSED
