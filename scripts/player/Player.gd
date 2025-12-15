# ==============================================================================
# Player.gd - Script de déplacement du joueur (MVP)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Optimisé pour mobile (Android/iOS)
# Contrôles : Joystick virtuel UI + Boutons d'action
# ==============================================================================

extends CharacterBody3D
class_name Player

# ==============================================================================
# SIGNAUX (pour découplage et accessibilité)
# ==============================================================================
signal dash_started
signal dash_ended
signal interaction_triggered(target: Node3D)
signal movement_started
signal movement_stopped
signal attack_started
signal attack_hit(target: Node3D)
signal player_died

# ==============================================================================
# CONSTANTES (évite les magic numbers, facilite le tuning)
# ==============================================================================
const ROTATION_SPEED: float = 10.0  # Vitesse de rotation vers direction mouvement
const GRAVITY_MULTIPLIER: float = 2.0  # Gravité plus réactive sur mobile

# ==============================================================================
# VARIABLES EXPORTÉES (modifiables dans l'inspecteur)
# ==============================================================================
@export_group("Mouvement")
@export var move_speed: float = 5.0  ## Vitesse de déplacement en m/s
@export var acceleration: float = 8.0  ## Accélération (lissage du mouvement)
@export var friction: float = 10.0  ## Friction au sol (décélération)

@export_group("Dash")
@export var dash_speed: float = 12.0  ## Vitesse pendant le dash
@export var dash_duration: float = 0.2  ## Durée du dash en secondes
@export var dash_cooldown: float = 1.0  ## Temps de recharge du dash

@export_group("Interaction")
@export var interaction_range: float = 2.0  ## Portée d'interaction en mètres

@export_group("Accessibilité")
@export var input_dead_zone: float = 0.15  ## Zone morte du joystick (filtre bruit)

# ==============================================================================
# RÉFÉRENCES (assignées via @onready ou dans l'inspecteur)
# ==============================================================================
@onready var mesh: Node3D = $MeshPivot  # Pivot pour la rotation du mesh
@onready var interaction_area: Area3D = $InteractionArea  # Zone de détection
@onready var health_component: HealthComponent = $HealthComponent  # Composant santé
@onready var combat_manager: CombatManager = $CombatManager  # Gestionnaire combat
@onready var spring_arm: Node3D = get_node_or_null("SpringArm3D")  # Bras de ressort caméra (optionnel)

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _input_direction: Vector2 = Vector2.ZERO  # Direction du joystick
var _is_dashing: bool = false
var _can_dash: bool = true
var _was_moving: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _last_obstacle_warning_time: int = 0  # Pour debounce des avertissements obstacles

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du joueur."""
	# Ajouter au groupe "player" pour détection par ennemis
	add_to_group("player")
	
	# Configure la zone d'interaction si elle existe
	if interaction_area:
		var collision_shape = interaction_area.get_node_or_null("CollisionShape3D")
		if collision_shape and collision_shape.shape is SphereShape3D:
			collision_shape.shape.radius = interaction_range
	
	# Connecter les signaux du composant santé
	if health_component:
		health_component.died.connect(_on_player_died)
		health_component.damage_taken.connect(_on_damage_taken)
	
	# Connecter les signaux du gestionnaire de combat
	if combat_manager:
		combat_manager.attack_started.connect(_on_attack_started)
		combat_manager.attack_hit.connect(_on_attack_hit)


func _physics_process(delta: float) -> void:
	"""Boucle physique principale - optimisée pour mobile."""
	# 1. Appliquer la gravité
	_apply_gravity(delta)
	
	# 2. Gérer le mouvement horizontal
	_handle_movement(delta)
	
	# 3. Rotation vers la direction du mouvement
	_handle_rotation(delta)
	
	# 4. Appliquer le mouvement final
	move_and_slide()
	
	# 5. Émettre signaux de mouvement (pour audio/animations)
	_emit_movement_signals()
	
	# 6. Vérifier les obstacles pour l'accessibilité
	_check_obstacles_accessibility()


# ==============================================================================
# INPUT - Méthodes publiques pour le Joystick Virtuel
# ==============================================================================

func set_movement_input(direction: Vector2) -> void:
	"""
	Appelée par le Joystick Virtuel UI.
	@param direction: Vector2 normalisé (-1 à 1 sur chaque axe)
	"""
	# Appliquer zone morte pour filtrer le bruit tactile
	if direction.length() < input_dead_zone:
		_input_direction = Vector2.ZERO
	else:
		_input_direction = direction.normalized()


func request_dash() -> void:
	"""Appelée par le bouton Dash UI."""
	if _can_dash and not _is_dashing:
		_perform_dash()


func request_interact() -> void:
	"""Appelée par le bouton Interact UI."""
	_perform_interact()


func request_attack() -> void:
	"""Appelée par le bouton Attaque UI. Utilise l'auto-targeting."""
	if combat_manager:
		combat_manager.request_attack()


# ==============================================================================
# MOUVEMENT PRIVÉ
# ==============================================================================

func _apply_gravity(delta: float) -> void:
	"""Applique la gravité si le joueur n'est pas au sol."""
	if not is_on_floor():
		velocity.y -= _gravity * GRAVITY_MULTIPLIER * delta


func _handle_movement(delta: float) -> void:
	"""Gère le déplacement horizontal basé sur l'input du joystick."""
	# Convertir input 2D en direction 3D (plan XZ)
	var target_velocity := Vector3(
		_input_direction.x,
		0.0,
		_input_direction.y  # Y du joystick -> Z du monde
	)
	
	# Ajuster vitesse selon état (normal ou dash)
	var current_speed := dash_speed if _is_dashing else move_speed
	target_velocity = target_velocity * current_speed
	
	# Lissage du mouvement (accélération/décélération)
	if target_velocity.length() > 0.1:
		# Accélération vers la vitesse cible
		velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)
	else:
		# Friction quand pas d'input
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)


func _handle_rotation(delta: float) -> void:
	"""Fait tourner le mesh vers la direction du mouvement."""
	# Ne pas tourner si pas de mouvement significatif
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length() < 0.5:
		return
	
	# Calculer l'angle cible
	var target_angle := atan2(horizontal_velocity.x, horizontal_velocity.z)
	
	# Rotation lissée du mesh (pas du CharacterBody3D entier)
	if mesh:
		var current_rotation := mesh.rotation.y
		mesh.rotation.y = lerp_angle(current_rotation, target_angle, ROTATION_SPEED * delta)


func _emit_movement_signals() -> void:
	"""Émet les signaux de début/fin de mouvement."""
	var is_moving := velocity.length() > 0.5
	
	if is_moving and not _was_moving:
		movement_started.emit()
	elif not is_moving and _was_moving:
		movement_stopped.emit()
	
	_was_moving = is_moving


# ==============================================================================
# DASH - Système complet avec effets visuels et invincibilité
# ==============================================================================

var _is_invincible: bool = false
var _dash_trail_timer: float = 0.0

func _perform_dash() -> void:
	"""
	Exécute le dash du joueur avec effets complets.
	- Invincibilité pendant le dash
	- Boost de vélocité
	- Trail visuel
	- Screen shake
	"""
	if _input_direction.length() < 0.1:
		return  # Pas de dash sans direction
	
	_is_dashing = true
	_can_dash = false
	_is_invincible = true
	dash_started.emit()
	
	# Calculer la direction du dash
	var cam_rotation := 0.0
	if spring_arm:
		cam_rotation = spring_arm.rotation.y
	var dash_direction := Vector3(_input_direction.x, 0, _input_direction.y).rotated(Vector3.UP, cam_rotation).normalized()
	
	# Appliquer le boost de vélocité
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed
	
	# Effet visuel: modifier le shader du mesh
	_apply_dash_visual_effect(true)
	
	# Audio feedback
	_play_dash_sound()
	
	# Screen shake léger
	_trigger_screen_shake(0.15, 5.0)
	
	# Spawn trail effect pendant le dash
	_spawn_dash_trail()
	
	# Timer pour la durée du dash
	await get_tree().create_timer(dash_duration).timeout
	
	# Fin du dash
	_is_dashing = false
	_is_invincible = false
	dash_ended.emit()
	
	# Retirer l'effet visuel
	_apply_dash_visual_effect(false)
	
	# Timer pour le cooldown
	await get_tree().create_timer(dash_cooldown).timeout
	_can_dash = true


func _apply_dash_visual_effect(active: bool) -> void:
	"""Applique/retire l'effet visuel de dash sur le mesh."""
	if not mesh:
		return
	
	# Chercher le material du mesh
	var mesh_instance: MeshInstance3D = null
	if mesh is MeshInstance3D:
		mesh_instance = mesh
	else:
		mesh_instance = mesh.get_node_or_null("MeshInstance3D")
	
	if not mesh_instance:
		return
	
	if active:
		# Créer un material de dash (cyan glow)
		var dash_material := StandardMaterial3D.new()
		dash_material.albedo_color = Color(0, 1, 1, 0.8)
		dash_material.emission_enabled = true
		dash_material.emission = Color(0, 1, 1)
		dash_material.emission_energy_multiplier = 3.0
		dash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_instance.set_surface_override_material(0, dash_material)
	else:
		# Retirer le material override
		mesh_instance.set_surface_override_material(0, null)


func _spawn_dash_trail() -> void:
	"""Crée un trail visuel derrière le joueur pendant le dash."""
	# Créer plusieurs "ghost" images pendant le dash
	for i in range(3):
		await get_tree().create_timer(dash_duration / 4.0).timeout
		if not _is_dashing:
			break
		
		# Créer un ghost mesh
		var ghost := MeshInstance3D.new()
		ghost.mesh = BoxMesh.new()
		ghost.mesh.size = Vector3(0.6, 1.8, 0.6)
		ghost.global_position = global_position
		ghost.rotation = mesh.rotation if mesh else rotation
		
		# Material transparent
		var ghost_mat := StandardMaterial3D.new()
		ghost_mat.albedo_color = Color(0, 0.8, 0.8, 0.5)
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.emission_enabled = true
		ghost_mat.emission = Color(0, 0.5, 0.5)
		ghost.set_surface_override_material(0, ghost_mat)
		
		get_parent().add_child(ghost)
		
		# Fade out et suppression
		var tween := create_tween()
		tween.tween_property(ghost_mat, "albedo_color:a", 0.0, 0.3)
		tween.tween_callback(ghost.queue_free)


func _play_dash_sound() -> void:
	"""Joue le son de dash."""
	# Chercher un AudioStreamPlayer enfant nommé "DashAudio"
	var audio_player: AudioStreamPlayer3D = get_node_or_null("DashAudio")
	if audio_player and audio_player.stream:
		audio_player.play()


func _trigger_screen_shake(duration: float, intensity: float) -> void:
	"""Déclenche un screen shake via la caméra."""
	if spring_arm:
		var original_offset: Vector3 = spring_arm.position
		var shake_tween := create_tween()
		
		for i in range(int(duration * 30)):
			var offset := Vector3(
				randf_range(-1, 1) * intensity * 0.01,
				randf_range(-1, 1) * intensity * 0.01,
				0
			)
			shake_tween.tween_property(spring_arm, "position", original_offset + offset, 0.02)
		
		shake_tween.tween_property(spring_arm, "position", original_offset, 0.05)


func is_invincible() -> bool:
	"""Retourne true si le joueur est invincible (pendant dash)."""
	return _is_invincible


# ==============================================================================
# INTERACTION - Système complet avec feedback
# ==============================================================================

func _perform_interact() -> void:
	"""
	Déclenche une interaction avec l'objet le plus proche.
	Inclut feedback audio, haptique et TTS.
	"""
	if not interaction_area:
		push_warning("Player: InteractionArea non configurée")
		return
	
	# Trouver tous les corps dans la zone d'interaction
	var bodies := interaction_area.get_overlapping_bodies()
	var interactable: Node3D = null
	var closest_distance := INF
	
	for body in bodies:
		# Chercher les objets avec le groupe "interactable"
		if body.is_in_group("interactable"):
			var distance := global_position.distance_to(body.global_position)
			if distance < closest_distance:
				closest_distance = distance
				interactable = body
	
	if interactable:
		# Audio feedback
		_play_interaction_sound()
		
		# Haptic feedback
		var haptic = get_node_or_null("/root/HapticFeedback")
		if haptic:
			haptic.vibrate_light()
		
		# TTS announcement
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			var obj_name := _get_interactable_name(interactable)
			tts.speak("Interaction avec " + obj_name)
		
		interaction_triggered.emit(interactable)
		# L'objet interactable devrait avoir une méthode interact()
		if interactable.has_method("interact"):
			interactable.interact(self)
	else:
		# Aucune cible - feedback audio
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Rien à proximité")


# ==============================================================================
# ACCESSIBILITÉ - Méthodes utilitaires
# ==============================================================================

func get_current_speed() -> float:
	"""Retourne la vitesse actuelle (pour UI/audio feedback)."""
	return Vector3(velocity.x, 0.0, velocity.z).length()


func is_moving() -> bool:
	"""Retourne true si le joueur se déplace."""
	return velocity.length() > 0.5


func get_facing_direction() -> Vector3:
	"""Retourne la direction vers laquelle le joueur regarde."""
	if mesh:
		return -mesh.global_transform.basis.z
	return -global_transform.basis.z


func get_health_percentage() -> float:
	"""Retourne le pourcentage de santé du joueur."""
	if health_component:
		return health_component.get_health_percentage()
	return 1.0


func is_alive() -> bool:
	"""Retourne true si le joueur est en vie."""
	if health_component:
		return not health_component.is_dead
	return true


# ==============================================================================
# CALLBACKS - Santé et Combat
# ==============================================================================

func _on_player_died() -> void:
	"""Appelée quand le joueur meurt."""
	player_died.emit()
	
	# Haptic death pattern
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_death()
	
	# TTS announcement
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Vous êtes mort")
	
	# Show game over screen
	_show_game_over_screen()


func _on_damage_taken(amount: float, source: Node) -> void:
	"""Appelée quand le joueur prend des dégâts."""
	# Skip if invincible (during dash)
	if _is_invincible:
		return
	
	# Screen flash effect
	_flash_damage_screen()
	
	# Haptic feedback
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_hit()
	
	# TTS with direction
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		var direction := _get_damage_direction(source)
		tts.announce_damage_received(amount, direction)
	
	# Camera shake
	_trigger_damage_camera_shake()


func _on_attack_started() -> void:
	"""Appelée quand une attaque commence."""
	attack_started.emit()
	
	# Haptic feedback
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_attack()
	
	# Slash visual effect
	_spawn_attack_effect()


func _on_attack_hit(target: Node3D, damage: float) -> void:
	"""Appelée quand une attaque touche une cible."""
	attack_hit.emit(target)
	
	# Impact particles
	var impact_effects = ImpactEffects.get_instance()
	if impact_effects:
		var hit_pos := target.global_position + Vector3(0, 1, 0)
		impact_effects.spawn_hit_effect(hit_pos, Vector3.UP, "cyber")
	
	# Haptic combo feedback
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic and combat_manager:
		var combo_count := 1
		if combat_manager.has_method("get_combo_count"):
			combo_count = combat_manager.get_combo_count()
		haptic.vibrate_combo(combo_count)
	
	# Camera shake on hit
	_trigger_hit_camera_shake()


# ==============================================================================
# HELPER METHODS - Feedback et effets
# ==============================================================================

func _play_interaction_sound() -> void:
	"""Joue le son d'interaction."""
	var audio_player: AudioStreamPlayer3D = get_node_or_null("InteractionAudio")
	if audio_player and audio_player.stream:
		audio_player.play()


func _get_interactable_name(node: Node3D) -> String:
	"""Retourne le nom lisible d'un objet interactable."""
	if node.has_method("get_display_name"):
		return node.get_display_name()
	
	# Fallback basé sur le groupe
	if node.is_in_group("vehicle"):
		return "véhicule"
	elif node.is_in_group("npc"):
		return "personnage"
	elif node.is_in_group("pickup"):
		return "objet"
	elif node.is_in_group("door"):
		return "porte"
	else:
		return node.name


func _show_game_over_screen() -> void:
	"""Affiche l'écran de game over."""
	# Pause du jeu
	get_tree().paused = true
	
	# Charger et afficher le menu game over
	var game_over_scene := preload("res://scenes/ui/GameOverMenu.tscn") if ResourceLoader.exists("res://scenes/ui/GameOverMenu.tscn") else null
	if game_over_scene:
		var game_over := game_over_scene.instantiate()
		get_tree().current_scene.add_child(game_over)
	else:
		# Fallback: notification toast
		var toast = get_node_or_null("/root/ToastNotification")
		if toast:
			toast.show_error("GAME OVER - Appuyez sur Pause pour continuer")
		print("Player: GameOverMenu.tscn non trouvé")


func _flash_damage_screen() -> void:
	"""Affiche un flash rouge de dégâts à l'écran."""
	# Créer un overlay rouge temporaire
	var overlay := ColorRect.new()
	overlay.color = Color(0.8, 0.1, 0.1, 0.4)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Ajouter au canvas layer pour être au-dessus de tout
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(overlay)
	get_tree().current_scene.add_child(canvas)
	
	# Fade out et suppression
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 0.3)
	tween.tween_callback(canvas.queue_free)


func _get_damage_direction(source: Node) -> String:
	"""Retourne la direction d'où provient les dégâts."""
	if not source or not source is Node3D:
		return "inconnu"
	
	var to_source: Vector3 = (source.global_position - global_position).normalized()
	var forward := get_facing_direction()
	var right := forward.cross(Vector3.UP)
	
	var forward_dot := to_source.dot(forward)
	var right_dot := to_source.dot(right)
	
	if forward_dot > 0.5:
		return "devant"
	elif forward_dot < -0.5:
		return "derrière"
	elif right_dot > 0.5:
		return "droite"
	else:
		return "gauche"


func _trigger_damage_camera_shake() -> void:
	"""Déclenche un shake de caméra pour les dégâts."""
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method("shake"):
		camera.shake(0.3, 0.2)


func _spawn_attack_effect() -> void:
	"""Génère l'effet visuel d'attaque (slash)."""
	var impact_effects = ImpactEffects.get_instance()
	if impact_effects:
		var attack_pos := global_position + get_facing_direction() * 1.0 + Vector3(0, 1, 0)
		impact_effects.spawn_slash_effect(attack_pos, get_facing_direction())


func _trigger_hit_camera_shake() -> void:
	"""Déclenche un shake de caméra pour un hit réussi."""
	var camera := get_viewport().get_camera_3d()
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 0.15)


# ==============================================================================
# ACCESSIBILITÉ - DÉTECTION D'OBSTACLES
# ==============================================================================

func _check_obstacles_accessibility() -> void:
	"""Vérifie les obstacles via RayCasts pour l'accessibilité."""
	var accessibility_mgr = get_node_or_null("/root/AccessibilityManager")
	if not accessibility_mgr or not accessibility_mgr.blind_mode_enabled:
		return
	
	# Vérifier uniquement le rayon avant pour éviter le spam
	var ray_front: RayCast3D = get_node_or_null("RayFront")
	if ray_front and ray_front.is_colliding():
		_announce_obstacle("Mur devant")


func _announce_obstacle(message: String) -> void:
	"""Annonce un obstacle avec debounce de 1.5 secondes."""
	if Time.get_ticks_msec() - _last_obstacle_warning_time > 1500:
		var accessibility_mgr = get_node_or_null("/root/AccessibilityManager")
		if accessibility_mgr and accessibility_mgr.has_method("speak"):
			accessibility_mgr.speak(message)
		_last_obstacle_warning_time = Time.get_ticks_msec()
