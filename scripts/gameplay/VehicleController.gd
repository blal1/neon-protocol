# ==============================================================================
# VehicleController.gd - Contrôleur de véhicule (Moto Cyberpunk)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Permet au joueur de conduire un véhicule
# ==============================================================================

extends CharacterBody3D
class_name VehicleController

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal vehicle_entered(driver: Node3D)
signal vehicle_exited(driver: Node3D)
signal speed_changed(current_speed: float, max_speed: float)
signal crashed(impact_force: float)
signal boosting

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Vitesse")
@export var max_speed: float = 30.0  ## m/s (~108 km/h)
@export var acceleration: float = 15.0
@export var deceleration: float = 8.0
@export var brake_force: float = 25.0
@export var boost_multiplier: float = 1.5
@export var boost_duration: float = 3.0
@export var boost_cooldown: float = 10.0

@export_group("Maniabilité")
@export var turn_speed: float = 2.5
@export var tilt_amount: float = 15.0  ## Inclinaison en virage
@export var wheelie_angle: float = 20.0

@export_group("Physique")
@export var gravity: float = 20.0
@export var ground_friction: float = 0.98
@export var air_drag: float = 0.02

@export_group("Interaction")
@export var enter_range: float = 2.0
@export var exit_offset: Vector3 = Vector3(1.5, 0, 0)

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_occupied: bool = false
var current_driver: Node3D = null
var current_speed: float = 0.0
var current_tilt: float = 0.0
var is_boosting: bool = false
var can_boost: bool = true
var is_grounded: bool = true

# Input
var _throttle: float = 0.0
var _steer: float = 0.0
var _brake: bool = false

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var mesh_pivot: Node3D = $MeshPivot if has_node("MeshPivot") else null
@onready var driver_seat: Node3D = $DriverSeat if has_node("DriverSeat") else null
@onready var camera_mount: Node3D = $CameraMount if has_node("CameraMount") else null
@onready var engine_audio: AudioStreamPlayer3D = $EngineAudio if has_node("EngineAudio") else null
@onready var interaction_area: Area3D = $InteractionArea if has_node("InteractionArea") else null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du véhicule."""
	add_to_group("vehicle")
	add_to_group("interactable")
	
	# Créer l'area d'interaction si elle n'existe pas
	if not interaction_area:
		_create_interaction_area()


func _physics_process(delta: float) -> void:
	"""Mise à jour physique du véhicule."""
	if not is_occupied:
		_when_empty(delta)
		return
	
	# Récupérer les inputs
	_get_input()
	
	# Appliquer la physique
	_apply_gravity(delta)
	_apply_throttle(delta)
	_apply_steering(delta)
	_apply_tilt(delta)
	
	# Déplacer le véhicule
	move_and_slide()
	
	# Vérifier les collisions après move_and_slide
	_check_collisions()
	
	# Mettre à jour l'audio
	_update_engine_sound()
	
	# Émettre le signal de vitesse
	speed_changed.emit(current_speed, max_speed)


func _input(event: InputEvent) -> void:
	"""Gestion des inputs spécifiques."""
	if not is_occupied:
		return
	
	# Boost
	if event.is_action_pressed("dash") and can_boost:
		_activate_boost()
	
	# Sortie du véhicule
	if event.is_action_pressed("interact"):
		exit_vehicle()


# ==============================================================================
# ENTRÉE/SORTIE
# ==============================================================================

func enter_vehicle(driver: Node3D) -> bool:
	"""
	Fait entrer un conducteur dans le véhicule.
	@return: true si réussi
	"""
	if is_occupied:
		return false
	
	current_driver = driver
	is_occupied = true
	
	# Cacher le joueur et le téléporter au siège
	if driver.has_method("set_visible"):
		driver.set_visible(false)
	driver.set_physics_process(false)
	driver.global_position = driver_seat.global_position if driver_seat else global_position
	
	# Reparenter la caméra si nécessaire
	var driver_camera = driver.get_node_or_null("SpringArm3D")
	if driver_camera and camera_mount:
		# Stocker la référence pour la restaurer
		driver.set_meta("original_camera_parent", driver_camera.get_parent())
		driver_camera.reparent(camera_mount)
	
	vehicle_entered.emit(driver)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Véhicule activé")
	
	return true


func exit_vehicle() -> void:
	"""Fait sortir le conducteur."""
	if not is_occupied or not current_driver:
		return
	
	var driver := current_driver
	
	# Restaurer la caméra
	if driver.has_meta("original_camera_parent"):
		var driver_camera = driver.get_node_or_null("SpringArm3D")
		if driver_camera:
			var original_parent = driver.get_meta("original_camera_parent")
			driver_camera.reparent(original_parent)
		driver.remove_meta("original_camera_parent")
	
	# Positionner le joueur à côté du véhicule
	var exit_pos := global_position + global_transform.basis * exit_offset
	driver.global_position = exit_pos
	
	# Réactiver le joueur
	if driver.has_method("set_visible"):
		driver.set_visible(true)
	driver.set_physics_process(true)
	
	vehicle_exited.emit(driver)
	
	current_driver = null
	is_occupied = false
	current_speed = 0.0
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Véhicule quitté")


# ==============================================================================
# PHYSIQUE
# ==============================================================================

func _get_input() -> void:
	"""Récupère les inputs du joueur."""
	# Joystick ou clavier
	_throttle = Input.get_axis("move_backward", "move_forward")
	_steer = Input.get_axis("move_right", "move_left")
	_brake = Input.is_action_pressed("crouch")  # Ou un autre bouton


func _apply_gravity(delta: float) -> void:
	"""Applique la gravité."""
	if not is_on_floor():
		velocity.y -= gravity * delta
		is_grounded = false
	else:
		is_grounded = true


func _apply_throttle(delta: float) -> void:
	"""Applique l'accélération/décélération."""
	var target_speed := 0.0
	var current_max := max_speed * (boost_multiplier if is_boosting else 1.0)
	
	if _throttle > 0:
		# Accélération
		target_speed = current_max * _throttle
		current_speed = lerp(current_speed, target_speed, acceleration * delta)
	elif _throttle < 0:
		# Marche arrière
		target_speed = max_speed * 0.3 * _throttle
		current_speed = lerp(current_speed, target_speed, acceleration * 0.5 * delta)
	else:
		# Décélération naturelle
		current_speed = lerp(current_speed, 0.0, deceleration * delta)
	
	# Freinage
	if _brake:
		current_speed = lerp(current_speed, 0.0, brake_force * delta)
	
	# Appliquer la vélocité dans la direction du véhicule
	var forward := -global_transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	
	# Friction
	velocity.x *= ground_friction
	velocity.z *= ground_friction


func _apply_steering(delta: float) -> void:
	"""Applique la direction."""
	if abs(current_speed) < 0.5:
		return  # Pas de rotation à l'arrêt
	
	# La rotation dépend de la vitesse
	var speed_factor := clamp(current_speed / max_speed, 0.3, 1.0)
	var turn := _steer * turn_speed * speed_factor * delta
	
	# Inverser le virage en marche arrière
	if current_speed < 0:
		turn = -turn
	
	rotate_y(turn)


func _apply_tilt(delta: float) -> void:
	"""Applique l'inclinaison en virage."""
	if not mesh_pivot:
		return
	
	var target_tilt := -_steer * tilt_amount * (current_speed / max_speed)
	current_tilt = lerp(current_tilt, target_tilt, 5.0 * delta)
	
	mesh_pivot.rotation_degrees.z = current_tilt
	
	# Wheelie lors du boost
	if is_boosting and current_speed > max_speed * 0.8:
		mesh_pivot.rotation_degrees.x = lerp(mesh_pivot.rotation_degrees.x, -wheelie_angle, 3.0 * delta)
	else:
		mesh_pivot.rotation_degrees.x = lerp(mesh_pivot.rotation_degrees.x, 0.0, 5.0 * delta)


func _when_empty(delta: float) -> void:
	"""Comportement quand le véhicule est vide."""
	# Appliquer la gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Friction au sol
	velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
	velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)
	
	move_and_slide()


# ==============================================================================
# BOOST
# ==============================================================================

func _activate_boost() -> void:
	"""Active le boost."""
	if not can_boost:
		return
	
	is_boosting = true
	can_boost = false
	boosting.emit()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Boost !")
	
	# Durée du boost
	await get_tree().create_timer(boost_duration).timeout
	is_boosting = false
	
	# Cooldown
	await get_tree().create_timer(boost_cooldown).timeout
	can_boost = true


# ==============================================================================
# AUDIO
# ==============================================================================

func _update_engine_sound() -> void:
	"""Met à jour le son du moteur."""
	if not engine_audio:
		return
	
	# Pitch basé sur la vitesse
	var speed_ratio := abs(current_speed) / max_speed
	engine_audio.pitch_scale = 0.8 + speed_ratio * 0.8
	
	# Volume basé sur l'accélération
	engine_audio.volume_db = -15 + speed_ratio * 10


# ==============================================================================
# COLLISION
# ==============================================================================

func _check_collisions() -> void:
	"""Vérifie les collisions après move_and_slide."""
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision:
			_on_collision(collision)


func _on_collision(collision: KinematicCollision3D) -> void:
	"""Gère les collisions."""
	if not collision:
		return
	
	var impact_velocity := velocity.length()
	var collider := collision.get_collider()
	
	# Seuil de vitesse pour déclencher un crash
	if impact_velocity > 10.0:
		crashed.emit(impact_velocity)
		
		# Feedback visuel et audio
		_play_crash_effects(impact_velocity)
		
		# Dégâts au conducteur si collision violente
		if current_driver and impact_velocity > 15.0:
			var damage := (impact_velocity - 15.0) * 0.5  # Dégâts progressifs
			
			var health = current_driver.get_node_or_null("HealthComponent")
			if health:
				health.take_damage(damage, self)
				
				# TTS pour crash grave
				if damage > 10:
					var tts = get_node_or_null("/root/TTSManager")
					if tts:
						tts.speak("Collision !")
		
		# Dégâts infligés à un piéton/ennemi touché
		if collider and collider.has_node("HealthComponent"):
			var target_health = collider.get_node("HealthComponent")
			var ram_damage := impact_velocity * 1.5  # Les véhicules font mal!
			target_health.take_damage(ram_damage, self)
		
		# Réduire la vitesse après l'impact
		current_speed *= 0.3
		velocity *= 0.3
		
		# Appliquer un recul
		var recoil_dir := -collision.get_normal()
		velocity += recoil_dir * 5.0


func _play_crash_effects(impact_force: float) -> void:
	"""Joue les effets de crash (son, vibration)."""
	# Haptic feedback
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		if impact_force > 20:
			if haptic.has_method("vibrate_heavy"):
				haptic.vibrate_heavy()
		else:
			if haptic.has_method("vibrate_medium"):
				haptic.vibrate_medium()
	
	# Son de crash (si AudioStreamPlayer disponible)
	var crash_audio = get_node_or_null("CrashAudio")
	if crash_audio and crash_audio is AudioStreamPlayer3D:
		crash_audio.pitch_scale = 0.8 + randf() * 0.4
		crash_audio.play()


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _create_interaction_area() -> void:
	"""Crée l'area d'interaction."""
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = enter_range
	collision.shape = sphere
	
	interaction_area.add_child(collision)
	add_child(interaction_area)


func get_speed_kmh() -> float:
	"""Retourne la vitesse en km/h."""
	return current_speed * 3.6


func get_speed_percent() -> float:
	"""Retourne la vitesse en pourcentage."""
	return (current_speed / max_speed) * 100.0


func is_moving() -> bool:
	"""Retourne true si le véhicule bouge."""
	return abs(current_speed) > 0.5


func can_enter(player: Node3D) -> bool:
	"""Vérifie si le joueur peut entrer."""
	if is_occupied:
		return false
	return global_position.distance_to(player.global_position) <= enter_range
