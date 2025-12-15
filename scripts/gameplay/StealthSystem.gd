# ==============================================================================
# StealthSystem.gd - Système de furtivité
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère le mode furtif, détection, et éliminations silencieuses
# ==============================================================================

extends Node
class_name StealthSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal stealth_mode_entered
signal stealth_mode_exited
signal detected_by(enemy: Node3D)
signal hidden_from(enemy: Node3D)
signal takedown_performed(enemy: Node3D)
signal alert_level_changed(level: AlertLevel)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum AlertLevel {
	UNDETECTED,   # Personne ne sait
	SUSPICIOUS,   # Ennemis méfiants
	ALERTED,      # En recherche active
	COMBAT        # Combat ouvert
}

enum CoverType {
	NONE,
	LIGHT,    # Ombres légères
	MEDIUM,   # Derrière un objet bas
	HEAVY     # Totalement caché
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Détection")
@export var base_detection_radius: float = 8.0
@export var peripheral_vision_angle: float = 60.0
@export var light_detection_multiplier: float = 1.5
@export var movement_detection_multiplier: float = 1.3

@export_group("Furtivité")
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_noise_reduction: float = 0.7
@export var takedown_range: float = 1.5
@export var takedown_angle: float = 45.0  # Angle derrière l'ennemi

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var is_crouching: bool = false
var is_hidden: bool = false
var current_alert_level: AlertLevel = AlertLevel.UNDETECTED
var current_cover: CoverType = CoverType.NONE

var _detection_cooldown: float = 0.0
var _alert_decay_timer: float = 0.0
var _enemies_detecting: Array[Node3D] = []

# Références
var player: Node3D = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	player = get_parent()


func _process(delta: float) -> void:
	"""Mise à jour de la furtivité."""
	_update_alert_decay(delta)
	_check_visibility()


# ==============================================================================
# MODE FURTIF
# ==============================================================================

func enter_stealth_mode() -> void:
	"""Active le mode furtif (accroupi)."""
	if is_crouching:
		return
	
	is_crouching = true
	stealth_mode_entered.emit()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Mode furtif activé")


func exit_stealth_mode() -> void:
	"""Désactive le mode furtif."""
	if not is_crouching:
		return
	
	is_crouching = false
	stealth_mode_exited.emit()


func toggle_stealth() -> void:
	"""Bascule le mode furtif."""
	if is_crouching:
		exit_stealth_mode()
	else:
		enter_stealth_mode()


# ==============================================================================
# DÉTECTION
# ==============================================================================

func get_visibility() -> float:
	"""
	Calcule la visibilité du joueur (0.0 = invisible, 1.0 = totalement visible).
	"""
	var visibility := 1.0
	
	# Réduction si accroupi
	if is_crouching:
		visibility *= 0.5
	
	# Réduction selon la couverture
	match current_cover:
		CoverType.LIGHT:
			visibility *= 0.8
		CoverType.MEDIUM:
			visibility *= 0.5
		CoverType.HEAVY:
			visibility *= 0.2
	
	# Bonus de nuit
	var day_night = get_node_or_null("/root/DayNightCycle")
	if day_night and day_night.is_night():
		visibility *= 0.6
	
	# Bonus du skill tree
	var skills = get_node_or_null("/root/SkillTreeManager")
	if skills:
		var reduction := skills.get_effect_total("detection_radius_reduction")
		visibility *= (1.0 - reduction)
	
	return clamp(visibility, 0.05, 1.0)


func get_noise_level() -> float:
	"""Calcule le niveau de bruit du joueur."""
	var noise := 1.0
	
	if is_crouching:
		noise *= crouch_noise_reduction
	
	# Bonus de compétence
	var skills = get_node_or_null("/root/SkillTreeManager")
	if skills:
		var speed_bonus := skills.get_effect_total("stealth_speed_bonus")
		# Plus de vitesse = moins de bruit avec la compétence
		noise *= (1.0 - speed_bonus * 0.3)
	
	return clamp(noise, 0.1, 1.0)


func get_detection_radius() -> float:
	"""Retourne le rayon de détection effectif."""
	return base_detection_radius * get_visibility()


func can_be_detected_by(enemy: Node3D) -> bool:
	"""Vérifie si le joueur peut être détecté par un ennemi."""
	if not player or not is_instance_valid(enemy):
		return false
	
	var distance := player.global_position.distance_to(enemy.global_position)
	var detection_range := get_detection_radius()
	
	# Hors de portée
	if distance > detection_range:
		return false
	
	# Vérifier l'angle de vision
	if enemy.has_method("get_forward_direction"):
		var to_player: Vector3 = (player.global_position - enemy.global_position).normalized()
		var enemy_forward: Vector3 = enemy.get_forward_direction()
		var angle := rad_to_deg(acos(clamp(to_player.dot(enemy_forward), -1.0, 1.0)))
		
		if angle > peripheral_vision_angle:
			return false
	
	# Raycast pour vérifier la ligne de vue
	if not _has_line_of_sight(enemy, player):
		return false
	
	return true


func _has_line_of_sight(from_node: Node3D, to_node: Node3D) -> bool:
	"""
	Vérifie si from_node a une ligne de vue directe vers to_node.
	Utilise un raycast pour détecter les obstacles.
	@return: true si aucun obstacle entre les deux
	"""
	if not from_node or not to_node:
		return false
	
	# Obtenir le space state pour le raycast
	var space_state := from_node.get_world_3d().direct_space_state
	if not space_state:
		return true  # Fallback: considérer visible si pas de space state
	
	# Position des yeux (environ 1.5m de hauteur pour humanoïde)
	var eye_height := Vector3(0, 1.5, 0)
	var from_pos := from_node.global_position + eye_height
	var to_pos := to_node.global_position + eye_height
	
	# Configurer le raycast
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1  # Layer "World" uniquement
	query.exclude = [from_node, to_node]  # Exclure les deux entités
	
	# Exclure aussi les colliders enfants
	if from_node.has_method("get_rid"):
		query.exclude.append(from_node.get_rid())
	if to_node.has_method("get_rid"):
		query.exclude.append(to_node.get_rid())
	
	# Effectuer le raycast
	var result := space_state.intersect_ray(query)
	
	# Si aucun hit, ligne de vue dégagée
	return result.is_empty()


func on_detected(enemy: Node3D) -> void:
	"""Appelé quand un ennemi détecte le joueur."""
	if enemy not in _enemies_detecting:
		_enemies_detecting.append(enemy)
	
	detected_by.emit(enemy)
	_raise_alert_level()
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Détecté !")


func on_lost(enemy: Node3D) -> void:
	"""Appelé quand un ennemi perd le joueur."""
	_enemies_detecting.erase(enemy)
	hidden_from.emit(enemy)
	
	if _enemies_detecting.is_empty():
		is_hidden = true


# ==============================================================================
# NIVEAU D'ALERTE
# ==============================================================================

func _raise_alert_level() -> void:
	"""Augmente le niveau d'alerte."""
	var old_level := current_alert_level
	
	match current_alert_level:
		AlertLevel.UNDETECTED:
			current_alert_level = AlertLevel.SUSPICIOUS
			_alert_decay_timer = 10.0
		AlertLevel.SUSPICIOUS:
			current_alert_level = AlertLevel.ALERTED
			_alert_decay_timer = 30.0
		AlertLevel.ALERTED:
			current_alert_level = AlertLevel.COMBAT
			_alert_decay_timer = 0.0  # Pas de decay en combat
	
	if old_level != current_alert_level:
		alert_level_changed.emit(current_alert_level)


func _update_alert_decay(delta: float) -> void:
	"""Fait décroître le niveau d'alerte avec le temps."""
	if current_alert_level == AlertLevel.COMBAT:
		# En combat, vérifier si des ennemis sont toujours en vie
		if _enemies_detecting.is_empty():
			_alert_decay_timer = 15.0
			current_alert_level = AlertLevel.ALERTED
			alert_level_changed.emit(current_alert_level)
		return
	
	if current_alert_level == AlertLevel.UNDETECTED:
		return
	
	_alert_decay_timer -= delta
	
	if _alert_decay_timer <= 0:
		var old_level := current_alert_level
		
		match current_alert_level:
			AlertLevel.SUSPICIOUS:
				current_alert_level = AlertLevel.UNDETECTED
			AlertLevel.ALERTED:
				current_alert_level = AlertLevel.SUSPICIOUS
				_alert_decay_timer = 10.0
		
		if old_level != current_alert_level:
			alert_level_changed.emit(current_alert_level)
			
			if current_alert_level == AlertLevel.UNDETECTED:
				var tts = get_node_or_null("/root/TTSManager")
				if tts:
					tts.speak("Retour en mode furtif")


func reset_alert() -> void:
	"""Réinitialise le niveau d'alerte."""
	current_alert_level = AlertLevel.UNDETECTED
	_enemies_detecting.clear()
	alert_level_changed.emit(current_alert_level)


# ==============================================================================
# TAKEDOWN
# ==============================================================================

func can_perform_takedown(enemy: Node3D) -> bool:
	"""Vérifie si un takedown silencieux est possible."""
	if not player or not is_instance_valid(enemy):
		return false
	
	# Vérifier la compétence
	var skills = get_node_or_null("/root/SkillTreeManager")
	if skills and not skills.has_ability("can_stealth_takedown"):
		return false
	
	# Vérifier la distance
	var distance := player.global_position.distance_to(enemy.global_position)
	if distance > takedown_range:
		return false
	
	# Vérifier qu'on est derrière l'ennemi
	var to_player: Vector3 = (player.global_position - enemy.global_position).normalized()
	var enemy_forward := -enemy.global_transform.basis.z.normalized()
	var angle := rad_to_deg(acos(to_player.dot(enemy_forward)))
	
	if angle < 180 - takedown_angle:
		return false  # Pas assez derrière
	
	return true


func perform_takedown(enemy: Node3D) -> bool:
	"""Effectue un takedown silencieux."""
	if not can_perform_takedown(enemy):
		return false
	
	# Éliminer l'ennemi silencieusement
	var health = enemy.get_node_or_null("HealthComponent")
	if health:
		health.take_damage(9999, player)  # One-shot
	
	takedown_performed.emit(enemy)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Élimination silencieuse")
	
	# Achievement
	var ach = get_node_or_null("/root/AchievementManager")
	if ach:
		ach.increment_stat("stealth_takedowns")
	
	return true


# ==============================================================================
# COUVERTURE
# ==============================================================================

func _check_visibility() -> void:
	"""
	Vérifie la couverture actuelle en utilisant des raycasts.
	Détecte automatiquement les objets de couverture à proximité.
	"""
	if not player:
		return
	
	var space_state := player.get_world_3d().direct_space_state
	if not space_state:
		return
	
	var player_pos := player.global_position
	var cover_check_radius := 1.5  # Rayon de vérification de couverture
	var cover_score := 0  # Score de couverture (0-3)
	
	# Raycasts dans 8 directions horizontales
	var directions := [
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(0, 0, -1),
		Vector3(0.707, 0, 0.707),
		Vector3(-0.707, 0, 0.707),
		Vector3(0.707, 0, -0.707),
		Vector3(-0.707, 0, -0.707)
	]
	
	var covers_found := 0
	
	for direction in directions:
		var from_pos := player_pos + Vector3(0, 0.5, 0)  # Mi-hauteur
		var to_pos := from_pos + direction * cover_check_radius
		
		var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		query.collision_mask = 1  # Layer "World"
		query.exclude = [player]
		
		var result := space_state.intersect_ray(query)
		
		if not result.is_empty():
			# Vérifier si l'objet touché est un objet de couverture
			var hit_object = result.get("collider")
			if hit_object:
				if hit_object.is_in_group("cover_heavy"):
					covers_found += 3
				elif hit_object.is_in_group("cover_medium"):
					covers_found += 2
				elif hit_object.is_in_group("cover") or hit_object.is_in_group("cover_light"):
					covers_found += 1
				else:
					# Objet statique générique = couverture légère
					covers_found += 1
	
	# Raycast vers le haut pour vérifier si sous un toit/plafond
	var above_query := PhysicsRayQueryParameters3D.create(
		player_pos + Vector3(0, 1.8, 0),
		player_pos + Vector3(0, 4.0, 0)
	)
	above_query.collision_mask = 1
	above_query.exclude = [player]
	
	var above_result := space_state.intersect_ray(above_query)
	if not above_result.is_empty():
		covers_found += 2  # Bonus pour être sous un toit
	
	# Déterminer le type de couverture basé sur le score
	var old_cover := current_cover
	
	if covers_found >= 6:
		current_cover = CoverType.HEAVY
	elif covers_found >= 3:
		current_cover = CoverType.MEDIUM
	elif covers_found >= 1:
		current_cover = CoverType.LIGHT
	else:
		current_cover = CoverType.NONE
	
	# Bonus si accroupi
	if is_crouching and current_cover != CoverType.NONE:
		# Améliorer d'un niveau si accroupi
		match current_cover:
			CoverType.LIGHT:
				current_cover = CoverType.MEDIUM
			CoverType.MEDIUM:
				current_cover = CoverType.HEAVY


func set_cover(cover: CoverType) -> void:
	"""Définit la couverture actuelle manuellement."""
	current_cover = cover


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func is_in_stealth() -> bool:
	"""Retourne true si en mode furtif."""
	return is_crouching


func is_detected() -> bool:
	"""Retourne true si détecté."""
	return not _enemies_detecting.is_empty()


func get_alert_level() -> AlertLevel:
	"""Retourne le niveau d'alerte."""
	return current_alert_level


func get_speed_multiplier() -> float:
	"""Retourne le multiplicateur de vitesse."""
	if is_crouching:
		var base := crouch_speed_multiplier
		
		# Bonus de compétence
		var skills = get_node_or_null("/root/SkillTreeManager")
		if skills:
			base += skills.get_effect_total("stealth_speed_bonus") * 0.5
		
		return min(base, 1.0)
	
	return 1.0
