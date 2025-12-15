# ==============================================================================
# SecurityRobot.gd - IA d'ennemi avec Machine à États
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Robot de sécurité utilisant NavigationAgent3D
# États : PATROL, CHASE, ATTACK, RETURN
# ==============================================================================

extends CharacterBody3D
class_name SecurityRobot

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal state_changed(new_state: State)
signal attack_started
signal attack_finished
signal player_detected
signal player_lost

# ==============================================================================
# ÉNUMÉRATION DES ÉTATS
# ==============================================================================
enum State {
	PATROL,   # Patrouille entre les waypoints
	CHASE,    # Poursuite du joueur
	ATTACK,   # Attaque du joueur
	RETURN,   # Retour à la patrouille
	SEARCH    # Recherche du joueur (furtivité)
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Patrouille")
@export var patrol_speed: float = 3.0  ## Vitesse de patrouille en m/s
@export var waypoints: Array[Node3D] = []  ## Points de patrouille (3 points)
@export var waypoint_threshold: float = 1.0  ## Distance pour valider un waypoint

@export_group("Détection")
@export var detection_range: float = 10.0  ## Rayon de détection du joueur (mètres)
@export var attack_range: float = 2.0  ## Rayon d'attaque (mètres)
@export var lose_range: float = 20.0  ## Distance pour perdre le joueur (mètres)

@export_group("Combat")
@export var chase_speed: float = 5.0  ## Vitesse de poursuite en m/s
@export var attack_damage: float = 20.0  ## Dégâts par attaque
@export var attack_cooldown: float = 1.5  ## Temps entre les attaques

@export_group("Apparence")
@export var rotation_speed: float = 5.0  ## Vitesse de rotation

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_component: HealthComponent = $HealthComponent
@onready var mesh: Node3D = $MeshPivot
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_state: State = State.PATROL
var current_waypoint_index: int = 0
var player_ref: Node3D = null
var can_attack: bool = true
var return_position: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Variables Stealth
var _last_known_position: Vector3 = Vector3.ZERO
var _search_timer: float = 0.0
var _search_duration: float = 8.0  # Temps de recherche avant abandon
var _suspicion_level: float = 0.0

# Stuck detection
var _stuck_timer: float = 0.0
var _last_position_2d: Vector2 = Vector2.ZERO  # 0-100, 100 = détecté

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du robot de sécurité."""
	# Sauvegarder position de départ pour le retour
	return_position = global_position
	
	# Trouver le joueur dans la scène
	_find_player()
	
	# Configurer le NavigationAgent
	if navigation_agent:
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = waypoint_threshold
	
	# Connecter les signaux de santé
	if health_component:
		health_component.died.connect(_on_died)
	
	# Démarrer la patrouille si waypoints configurés
	if waypoints.size() > 0:
		_set_navigation_target(waypoints[0].global_position)


func _physics_process(delta: float) -> void:
	"""Boucle physique principale avec machine à états."""
	# Appliquer la gravité
	if not is_on_floor():
		velocity.y -= _gravity * delta
	
	# Machine à états (Switch/Case via match)
	match current_state:
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RETURN:
			_state_return(delta)
		State.SEARCH:
			_state_search(delta)
	
	# Appliquer le mouvement
	move_and_slide()


# ==============================================================================
# MACHINE À ÉTATS - Implémentation des états
# ==============================================================================

func _state_patrol(delta: float) -> void:
	"""État PATROL : Se déplace entre les waypoints."""
	# Vérifier si le joueur est détecté
	if _is_player_in_range(detection_range):
		_change_state(State.CHASE)
		return
	
	# Pas de waypoints, rester sur place
	if waypoints.size() == 0:
		return
	
	# Navigation vers le waypoint actuel
	if navigation_agent.is_navigation_finished():
		# Passer au waypoint suivant
		current_waypoint_index = (current_waypoint_index + 1) % waypoints.size()
		_set_navigation_target(waypoints[current_waypoint_index].global_position)
	else:
		_move_toward_target(patrol_speed, delta)


func _state_chase(delta: float) -> void:
	"""État CHASE : Poursuit le joueur."""
	if not player_ref or not is_instance_valid(player_ref):
		_change_state(State.RETURN)
		return
	
	var distance_to_player := global_position.distance_to(player_ref.global_position)
	
	# Vérifier si assez proche pour attaquer
	if distance_to_player <= attack_range:
		_change_state(State.ATTACK)
		return
	
	# Vérifier si le joueur est trop loin
	if distance_to_player > lose_range:
		player_lost.emit()
		_change_state(State.RETURN)
		return
	
	# Poursuivre le joueur
	_set_navigation_target(player_ref.global_position)
	_move_toward_target(chase_speed, delta)


func _state_attack(delta: float) -> void:
	"""État ATTACK : Attaque le joueur si à portée."""
	if not player_ref or not is_instance_valid(player_ref):
		_change_state(State.RETURN)
		return
	
	var distance_to_player := global_position.distance_to(player_ref.global_position)
	
	# Vérifier si le joueur s'est éloigné
	if distance_to_player > attack_range:
		_change_state(State.CHASE)
		return
	
	# Regarder le joueur
	_look_at_target(player_ref.global_position, delta)
	
	# Attaquer si possible
	if can_attack:
		_perform_attack()


func _state_return(delta: float) -> void:
	"""État RETURN : Retourne à la position de patrouille."""
	# Vérifier si le joueur est détecté pendant le retour
	if _is_player_in_range(detection_range):
		_change_state(State.CHASE)
		return
	
	# Définir la cible de retour (premier waypoint ou position initiale)
	var target_pos: Vector3
	if waypoints.size() > 0:
		target_pos = waypoints[current_waypoint_index].global_position
	else:
		target_pos = return_position
	
	# Vérifier si arrivé à destination
	if global_position.distance_to(target_pos) < waypoint_threshold:
		_change_state(State.PATROL)
		return
	
	# Se déplacer vers la cible
	_set_navigation_target(target_pos)
	_move_toward_target(patrol_speed, delta)


# ==============================================================================
# MÉTHODES DE NAVIGATION ET MOUVEMENT
# ==============================================================================

func _move_toward_target(speed: float, delta: float) -> void:
	"""Déplace le robot vers la cible de navigation."""
	if navigation_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		_stuck_timer = 0.0
		return
	
	var next_path_position := navigation_agent.get_next_path_position()
	var direction := (next_path_position - global_position).normalized()
	direction.y = 0.0  # Garder le mouvement horizontal
	
	# Détection de blocage (stuck prevention)
	var current_pos_2d := Vector2(global_position.x, global_position.z)
	if _last_position_2d.distance_to(current_pos_2d) < 0.1:
		_stuck_timer += delta
		if _stuck_timer > 2.0:
			# Recalculer le chemin ou mouvement direct
			if navigation_agent:
				navigation_agent.target_position = navigation_agent.target_position
			_stuck_timer = 0.0
			# Essayer un mouvement latéral pour se débloquer
			direction = direction.rotated(Vector3.UP, deg_to_rad(45.0 * (1 if randf() > 0.5 else -1)))
	else:
		_stuck_timer = 0.0
	_last_position_2d = current_pos_2d
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	# Tourner vers la direction du mouvement
	_look_at_target(next_path_position, delta)


func _set_navigation_target(target: Vector3) -> void:
	"""Définit la cible de navigation."""
	if navigation_agent:
		navigation_agent.target_position = target


func _look_at_target(target: Vector3, delta: float) -> void:
	"""Fait tourner le mesh vers la cible."""
	var direction := (target - global_position)
	direction.y = 0.0
	
	if direction.length() < 0.1:
		return
	
	var target_angle := atan2(direction.x, direction.z)
	
	if mesh:
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, rotation_speed * delta)


# ==============================================================================
# MÉTHODES DE COMBAT
# ==============================================================================

func _perform_attack() -> void:
	"""Exécute une attaque sur le joueur."""
	can_attack = false
	attack_started.emit()
	
	# Jouer l'animation d'attaque si disponible
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	
	# Infliger des dégâts au joueur
	if player_ref and player_ref.has_node("HealthComponent"):
		var player_health: HealthComponent = player_ref.get_node("HealthComponent")
		player_health.take_damage(attack_damage, self)
	
	attack_finished.emit()
	
	# Cooldown d'attaque
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


# ==============================================================================
# MÉTHODES DE DÉTECTION
# ==============================================================================

func _is_player_in_range(range_distance: float) -> bool:
	"""Vérifie si le joueur est dans le rayon donné, avec prise en compte de la furtivité."""
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		if not player_ref:
			return false
	
	var distance := global_position.distance_to(player_ref.global_position)
	
	# Calculer le rayon effectif de détection (modifié par StealthSystem)
	var effective_range := range_distance
	var stealth_system = player_ref.get_node_or_null("StealthSystem")
	
	if stealth_system:
		var visibility: float = stealth_system.get_visibility()
		effective_range *= visibility  # Rayon réduit si joueur caché
	
	# Jour/nuit affecte aussi la détection
	var day_night = get_node_or_null("/root/DayNightCycle")
	if day_night:
		effective_range *= day_night.get_visibility_multiplier()
	
	if distance <= effective_range:
		# Vérification de ligne de vue (angle de vision)
		if _has_line_of_sight():
			if current_state == State.PATROL:
				player_detected.emit()
				# Alerter le StealthSystem
				if stealth_system:
					stealth_system.on_detected(self)
			return true
	
	return false


func _has_line_of_sight() -> bool:
	"""Vérifie si le robot a une ligne de vue directe vers le joueur."""
	if not player_ref:
		return false
	
	var direction := (player_ref.global_position - global_position).normalized()
	var forward := -mesh.global_transform.basis.z if mesh else -global_transform.basis.z
	
	# Angle de vue (120° devant)
	var angle := rad_to_deg(acos(clamp(direction.dot(forward), -1.0, 1.0)))
	if angle > 60.0:  # En dehors du champ de vision
		return false
	
	# Raycast pour vérifier les obstacles
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return true  # Fallback: pas de vérification
	
	# Position des yeux (hauteur du capteur)
	var eye_height := Vector3(0, 1.5, 0)
	var from_pos := global_position + eye_height
	var to_pos := player_ref.global_position + Vector3(0, 1.0, 0)  # Milieu du joueur
	
	# Configurer le raycast
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1  # Layer "World" uniquement (obstacles)
	query.exclude = [self]  # S'exclure soi-même
	
	# Effectuer le raycast
	var result := space_state.intersect_ray(query)
	
	# Si le raycast touche quelque chose
	if not result.is_empty():
		var hit_collider = result.get("collider")
		# Vérifier si c'est le joueur ou un obstacle
		if hit_collider == player_ref:
			return true  # C'est le joueur, ligne de vue dégagée
		elif hit_collider and hit_collider.is_in_group("player"):
			return true  # C'est le joueur
		else:
			return false  # Obstacle bloque la vue
	
	# Aucun hit = ligne de vue dégagée
	return true


func _state_search(_delta: float) -> void:
	"""État SEARCH : Recherche le joueur après l'avoir perdu."""
	_search_timer -= _delta
	
	# Le joueur est-il de nouveau visible?
	if _is_player_in_range(detection_range * 0.8):  # Rayon réduit en recherche
		_change_state(State.CHASE)
		_suspicion_level = 100.0
		return
	
	# Temps de recherche écoulé
	if _search_timer <= 0:
		player_lost.emit()
		_suspicion_level = 0.0
		
		# Alerter le StealthSystem que l'ennemi a abandonné
		if player_ref:
			var stealth_system = player_ref.get_node_or_null("StealthSystem")
			if stealth_system:
				stealth_system.on_lost(self)
		
		_change_state(State.RETURN)
		return
	
	# Se déplacer vers la dernière position connue
	var dist_to_last := global_position.distance_to(_last_known_position)
	if dist_to_last < 2.0:
		# Tourner sur place pour "chercher"
		if mesh:
			mesh.rotation.y += _delta * 2.0
	else:
		_set_navigation_target(_last_known_position)
		_move_toward_target(patrol_speed * 0.7, _delta)


func _update_suspicion(delta: float) -> void:
	"""Met à jour le niveau de suspicion basé sur la visibilité du joueur."""
	if not player_ref:
		_suspicion_level = max(0, _suspicion_level - delta * 20)
		return
	
	var distance := global_position.distance_to(player_ref.global_position)
	if distance > detection_range:
		_suspicion_level = max(0, _suspicion_level - delta * 15)
		return
	
	var stealth_system = player_ref.get_node_or_null("StealthSystem")
	var visibility := 1.0
	if stealth_system:
		visibility = stealth_system.get_visibility()
	
	# Suspicion augmente plus vite si joueur visible
	_suspicion_level += delta * 30 * visibility * (1.0 - distance / detection_range)
	
	# Si suspicion atteint 100, passer en poursuite
	if _suspicion_level >= 100:
		_suspicion_level = 100
		if current_state == State.PATROL:
			player_detected.emit()
			_change_state(State.CHASE)


func enter_search_mode() -> void:
	"""Force le passage en mode recherche (appelé quand le joueur échappe)."""
	_last_known_position = player_ref.global_position if player_ref else global_position
	_search_timer = _search_duration
	_change_state(State.SEARCH)


func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	# Chercher par groupe
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
		return
	
	# Chercher par classe
	var root := get_tree().root
	player_ref = _find_node_of_class(root, "Player")


func _find_node_of_class(node: Node, class_name_str: String) -> Node3D:
	"""Recherche récursive d'un noeud par nom de classe."""
	if node.get_class() == class_name_str or node.name == "Player":
		return node as Node3D
	
	for child in node.get_children():
		var result := _find_node_of_class(child, class_name_str)
		if result:
			return result
	
	return null


# ==============================================================================
# GESTION DES ÉTATS
# ==============================================================================

func _change_state(new_state: State) -> void:
	"""Change l'état actuel et émet le signal."""
	if current_state == new_state:
		return
	
	current_state = new_state
	state_changed.emit(new_state)
	
	# Debug (optionnel)
	print("SecurityRobot: État changé vers ", State.keys()[new_state])


# ==============================================================================
# CALLBACKS
# ==============================================================================

func _on_died() -> void:
	"""Appelé quand le robot meurt."""
	# Désactiver la physique
	set_physics_process(false)
	
	# Jouer animation de mort si disponible
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
		await animation_player.animation_finished
	
	# Supprimer après un délai
	queue_free()


# ==============================================================================
# MÉTHODES PUBLIQUES
# ==============================================================================

func get_state_name() -> String:
	"""Retourne le nom de l'état actuel."""
	return State.keys()[current_state]


func force_state(new_state: State) -> void:
	"""Force un changement d'état (pour debug/scripting)."""
	_change_state(new_state)
