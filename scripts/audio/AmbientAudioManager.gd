# ==============================================================================
# AmbientAudioManager.gd - Gestionnaire d'ambiance sonore 3D
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les sons d'ambiance de la ville cyberpunk
# Pluie, néons, circulation, drones
# ==============================================================================

extends Node
class_name AmbientAudioManager

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal ambiance_changed(zone_name: String)
signal rain_intensity_changed(intensity: float)

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Sons Globaux (2D)")
@export var rain_sound: AudioStream
@export var city_drone_sound: AudioStream  ## Bourdonnement de ville
@export var distant_traffic_sound: AudioStream

@export_group("Sons 3D Positionnels")
@export var neon_buzz_sound: AudioStream
@export var electrical_hum_sound: AudioStream
@export var vent_sound: AudioStream
@export var water_drip_sound: AudioStream

@export_group("Volume")
@export var master_volume_db: float = 0.0
@export var rain_volume_db: float = -10.0
@export var city_volume_db: float = -15.0

@export_group("Bus Audio")
@export var environment_bus: String = "Environment"

# ==============================================================================
# LECTEURS AUDIO GLOBAUX
# ==============================================================================
var _rain_player: AudioStreamPlayer
var _city_drone_player: AudioStreamPlayer
var _traffic_player: AudioStreamPlayer

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var rain_intensity: float = 1.0
var is_indoors: bool = false
var _3d_emitters: Array[AudioStreamPlayer3D] = []

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation de l'ambiance sonore."""
	_setup_global_audio()
	_start_ambient_sounds()


# ==============================================================================
# CONFIGURATION
# ==============================================================================

func _setup_global_audio() -> void:
	"""Configure les lecteurs audio 2D globaux."""
	# Pluie
	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "RainPlayer"
	_rain_player.bus = environment_bus
	_rain_player.volume_db = rain_volume_db
	if rain_sound:
		_rain_player.stream = rain_sound
	add_child(_rain_player)
	
	# Drone de ville
	_city_drone_player = AudioStreamPlayer.new()
	_city_drone_player.name = "CityDronePlayer"
	_city_drone_player.bus = environment_bus
	_city_drone_player.volume_db = city_volume_db
	if city_drone_sound:
		_city_drone_player.stream = city_drone_sound
	add_child(_city_drone_player)
	
	# Trafic distant
	_traffic_player = AudioStreamPlayer.new()
	_traffic_player.name = "TrafficPlayer"
	_traffic_player.bus = environment_bus
	_traffic_player.volume_db = city_volume_db - 5.0
	if distant_traffic_sound:
		_traffic_player.stream = distant_traffic_sound
	add_child(_traffic_player)


func _start_ambient_sounds() -> void:
	"""Démarre les sons d'ambiance."""
	if _rain_player.stream:
		_rain_player.play()
	if _city_drone_player.stream:
		_city_drone_player.play()
	if _traffic_player.stream:
		_traffic_player.play()


# ==============================================================================
# CONTRÔLE DE LA PLUIE
# ==============================================================================

func set_rain_intensity(intensity: float) -> void:
	"""
	Définit l'intensité de la pluie (0.0 à 1.0).
	@param intensity: 0 = pas de pluie, 1 = pluie forte
	"""
	rain_intensity = clamp(intensity, 0.0, 1.0)
	
	if _rain_player:
		if intensity <= 0.0:
			_rain_player.stop()
		else:
			_rain_player.volume_db = rain_volume_db + (intensity * 10.0) - 10.0
			if not _rain_player.playing:
				_rain_player.play()
	
	rain_intensity_changed.emit(intensity)


func fade_rain(target_intensity: float, duration: float = 2.0) -> void:
	"""Fondu de l'intensité de la pluie."""
	var tween := create_tween()
	tween.tween_method(set_rain_intensity, rain_intensity, target_intensity, duration)


# ==============================================================================
# ZONES INTÉRIEURES/EXTÉRIEURES
# ==============================================================================

func enter_indoor_area() -> void:
	"""Appelé quand le joueur entre dans un bâtiment."""
	is_indoors = true
	
	# Étouffer les sons extérieurs
	var tween := create_tween()
	tween.set_parallel(true)
	
	if _rain_player:
		tween.tween_property(_rain_player, "volume_db", rain_volume_db - 20.0, 1.0)
	if _traffic_player:
		tween.tween_property(_traffic_player, "volume_db", city_volume_db - 25.0, 1.0)
	
	ambiance_changed.emit("indoor")


func exit_to_outdoor() -> void:
	"""Appelé quand le joueur sort d'un bâtiment."""
	is_indoors = false
	
	# Restaurer les sons extérieurs
	var tween := create_tween()
	tween.set_parallel(true)
	
	if _rain_player:
		tween.tween_property(_rain_player, "volume_db", rain_volume_db, 1.0)
	if _traffic_player:
		tween.tween_property(_traffic_player, "volume_db", city_volume_db - 5.0, 1.0)
	
	ambiance_changed.emit("outdoor")


# ==============================================================================
# ÉMETTEURS 3D POSITIONNELS
# ==============================================================================

func create_neon_emitter(position: Vector3, volume_db: float = -10.0) -> AudioStreamPlayer3D:
	"""
	Crée un émetteur de son de néon à une position.
	@return: L'AudioStreamPlayer3D créé
	"""
	return _create_3d_emitter(position, neon_buzz_sound, volume_db, 15.0)


func create_vent_emitter(position: Vector3, volume_db: float = -8.0) -> AudioStreamPlayer3D:
	"""Crée un émetteur de son de ventilation."""
	return _create_3d_emitter(position, vent_sound, volume_db, 10.0)


func create_electrical_emitter(position: Vector3, volume_db: float = -12.0) -> AudioStreamPlayer3D:
	"""Crée un émetteur de bourdonnement électrique."""
	return _create_3d_emitter(position, electrical_hum_sound, volume_db, 12.0)


func create_drip_emitter(position: Vector3, volume_db: float = -5.0) -> AudioStreamPlayer3D:
	"""Crée un émetteur de gouttes d'eau."""
	return _create_3d_emitter(position, water_drip_sound, volume_db, 8.0)


func _create_3d_emitter(position: Vector3, sound: AudioStream, volume_db: float, max_distance: float) -> AudioStreamPlayer3D:
	"""Crée un émetteur audio 3D générique."""
	if not sound:
		return null
	
	var emitter := AudioStreamPlayer3D.new()
	emitter.stream = sound
	emitter.bus = environment_bus
	emitter.volume_db = volume_db + master_volume_db
	emitter.max_distance = max_distance
	emitter.unit_size = 5.0
	emitter.autoplay = true
	
	add_child(emitter)
	emitter.global_position = position
	
	_3d_emitters.append(emitter)
	return emitter


func remove_emitter(emitter: AudioStreamPlayer3D) -> void:
	"""Supprime un émetteur 3D."""
	if emitter in _3d_emitters:
		_3d_emitters.erase(emitter)
		emitter.queue_free()


# ==============================================================================
# SONS PONCTUELS
# ==============================================================================

## Son de tonnerre exportable
@export_group("Sons Ponctuels")
@export var thunder_sound: AudioStream
@export var siren_sound: AudioStream

# Player pour sons ponctuels
var _thunder_player: AudioStreamPlayer
var _siren_pool: Array[AudioStreamPlayer3D] = []

func _setup_punctual_audio() -> void:
	"""Configure les lecteurs pour sons ponctuels."""
	# Thunder player (2D global)
	_thunder_player = AudioStreamPlayer.new()
	_thunder_player.name = "ThunderPlayer"
	_thunder_player.bus = environment_bus
	_thunder_player.volume_db = -5.0
	if thunder_sound:
		_thunder_player.stream = thunder_sound
	add_child(_thunder_player)


func play_thunder() -> void:
	"""
	Joue un coup de tonnerre avec effet visuel.
	Peut utiliser un son exporté ou générer un son procédural.
	"""
	# S'assurer que le player existe
	if not _thunder_player:
		_setup_punctual_audio()
	
	# Jouer le son
	if _thunder_player.stream:
		# Variation aléatoire du pitch pour variété
		_thunder_player.pitch_scale = randf_range(0.8, 1.2)
		_thunder_player.play()
	else:
		# Fallback: utiliser un son procédural simple (bruit blanc filtré)
		_play_procedural_thunder()
	
	# Effet de flash d'éclair
	_flash_lightning()
	
	# TTS pour accessibilité (optionnel, désactivé par défaut pour ne pas interrompre)
	# var tts = get_node_or_null("/root/TTSManager")
	# if tts:
	#     tts.speak("Tonnerre", TTSManager.Priority.LOW)


func _play_procedural_thunder() -> void:
	"""Génère un son de tonnerre procédural."""
	# Créer un bruit blanc court
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.5
	
	var temp_player := AudioStreamPlayer.new()
	temp_player.stream = generator
	temp_player.bus = environment_bus
	temp_player.volume_db = -8.0
	add_child(temp_player)
	temp_player.play()
	
	# Laisser jouer puis supprimer
	await get_tree().create_timer(2.0).timeout
	temp_player.queue_free()


func _flash_lightning() -> void:
	"""Crée un flash d'éclair à l'écran."""
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	
	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.95, 1.0, 0.6)  # Blanc-bleu
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	canvas.add_child(flash)
	get_tree().current_scene.add_child(canvas)
	
	# Double flash (réaliste)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.05)
	tween.tween_property(flash, "color:a", 0.4, 0.02)
	tween.tween_property(flash, "color:a", 0.0, 0.15)
	tween.tween_callback(canvas.queue_free)


func play_siren(position: Vector3) -> void:
	"""
	Joue une sirène de police/ambulance en 3D.
	@param position: Position mondiale de la sirène
	"""
	if not siren_sound:
		# Fallback: juste un log
		print("AmbientAudio: Siren sound not configured")
		return
	
	# Créer un émetteur 3D temporaire
	var siren_emitter := AudioStreamPlayer3D.new()
	siren_emitter.name = "SirenEmitter"
	siren_emitter.stream = siren_sound
	siren_emitter.bus = environment_bus
	siren_emitter.volume_db = -5.0
	siren_emitter.max_distance = 50.0
	siren_emitter.unit_size = 10.0
	siren_emitter.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	
	add_child(siren_emitter)
	siren_emitter.global_position = position
	siren_emitter.play()
	
	# Animer le mouvement (passe et s'éloigne)
	_animate_siren_movement(siren_emitter, position)


func _animate_siren_movement(emitter: AudioStreamPlayer3D, start_pos: Vector3) -> void:
	"""Anime la sirène qui passe et s'éloigne."""
	var direction := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var end_pos := start_pos + direction * 100.0
	
	var tween := create_tween()
	tween.tween_property(emitter, "global_position", end_pos, 8.0)
	tween.tween_callback(emitter.queue_free)


func play_announcement(text: String) -> void:
	"""
	Joue une annonce publique style dystopie cyberpunk.
	Utilise TTS avec un effet de haut-parleur.
	@param text: Texte de l'annonce
	"""
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		# Préfixe pour effet dystopique
		var announcement := "Attention citoyens. " + text
		
		# Jouer via TTS avec priorité haute
		tts.speak(announcement)
	else:
		# Fallback: utiliser un son d'annonce pré-enregistré s'il existe
		print("[ANNONCE] ", text)
	
	# Notification toast pour accessibilité visuelle
	var toast = get_node_or_null("/root/ToastNotification")
	if toast:
		toast.show_notification("📢 " + text, toast.NotificationType.INFO, 5.0)


# ==============================================================================
# CONTRÔLE GLOBAL
# ==============================================================================

func set_master_volume(volume_db: float) -> void:
	"""Définit le volume principal de l'ambiance."""
	master_volume_db = volume_db
	
	# Mettre à jour tous les émetteurs
	for emitter in _3d_emitters:
		if is_instance_valid(emitter):
			emitter.volume_db += volume_db


func pause_all() -> void:
	"""Met en pause tous les sons d'ambiance."""
	if _rain_player:
		_rain_player.stream_paused = true
	if _city_drone_player:
		_city_drone_player.stream_paused = true
	if _traffic_player:
		_traffic_player.stream_paused = true
	
	for emitter in _3d_emitters:
		if is_instance_valid(emitter):
			emitter.stream_paused = true


func resume_all() -> void:
	"""Reprend tous les sons d'ambiance."""
	if _rain_player:
		_rain_player.stream_paused = false
	if _city_drone_player:
		_city_drone_player.stream_paused = false
	if _traffic_player:
		_traffic_player.stream_paused = false
	
	for emitter in _3d_emitters:
		if is_instance_valid(emitter):
			emitter.stream_paused = false


func stop_all() -> void:
	"""Arrête tous les sons d'ambiance."""
	if _rain_player:
		_rain_player.stop()
	if _city_drone_player:
		_city_drone_player.stop()
	if _traffic_player:
		_traffic_player.stop()
	
	for emitter in _3d_emitters:
		if is_instance_valid(emitter):
			emitter.stop()
