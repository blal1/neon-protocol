# ==============================================================================
# MultiplayerSync.gd - Composant de synchronisation multijoueur
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# À attacher au joueur pour synchroniser position, rotation, et animations
# ==============================================================================

extends Node
class_name MultiplayerSync

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var sync_rate: float = 0.05  ## Intervalle de synchronisation (secondes)
@export var interpolation_speed: float = 15.0  ## Vitesse d'interpolation
@export var sync_position: bool = true
@export var sync_rotation: bool = true
@export var sync_velocity: bool = true
@export var sync_animation: bool = true

# ==============================================================================
# VARIABLES INTERNES
# ==============================================================================
var _target: Node3D = null
var _sync_timer: float = 0.0

# Données de synchronisation
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation: float = 0.0
var _target_velocity: Vector3 = Vector3.ZERO
var _current_animation: String = ""

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_target = get_parent() as Node3D
	
	if not _target:
		push_error("MultiplayerSync: Parent doit être un Node3D")
		return
	
	# Initialiser les valeurs
	_target_position = _target.global_position
	if _target.has_node("MeshPivot"):
		_target_rotation = _target.get_node("MeshPivot").rotation.y


func _physics_process(delta: float) -> void:
	"""Mise à jour de la synchronisation."""
	if not _target or not multiplayer.has_multiplayer_peer():
		return
	
	# Déterminer si on a l'autorité
	var is_authority := _target.is_multiplayer_authority()
	
	if is_authority:
		# On a l'autorité: envoyer nos données
		_sync_timer += delta
		if _sync_timer >= sync_rate:
			_sync_timer = 0.0
			_send_sync_data()
	else:
		# On n'a pas l'autorité: interpoler vers les données reçues
		_interpolate_to_target(delta)


# ==============================================================================
# ENVOI DES DONNÉES
# ==============================================================================

func _send_sync_data() -> void:
	"""Envoie les données de synchronisation."""
	var data := {}
	
	if sync_position:
		data["pos"] = _target.global_position
	
	if sync_rotation:
		var mesh = _target.get_node_or_null("MeshPivot")
		if mesh:
			data["rot"] = mesh.rotation.y
	
	if sync_velocity and _target is CharacterBody3D:
		data["vel"] = _target.velocity
	
	if sync_animation:
		var anim = _target.get_node_or_null("AnimationPlayer")
		if anim and anim.is_playing():
			data["anim"] = anim.current_animation
	
	_receive_sync_data.rpc(data)


@rpc("any_peer", "unreliable_ordered")
func _receive_sync_data(data: Dictionary) -> void:
	"""Reçoit les données de synchronisation."""
	if data.has("pos"):
		_target_position = data["pos"]
	
	if data.has("rot"):
		_target_rotation = data["rot"]
	
	if data.has("vel"):
		_target_velocity = data["vel"]
	
	if data.has("anim"):
		var new_anim: String = data["anim"]
		if new_anim != _current_animation:
			_current_animation = new_anim
			var anim = _target.get_node_or_null("AnimationPlayer")
			if anim and anim.has_animation(new_anim):
				anim.play(new_anim)


# ==============================================================================
# INTERPOLATION
# ==============================================================================

func _interpolate_to_target(delta: float) -> void:
	"""Interpole vers les données reçues."""
	if sync_position:
		_target.global_position = _target.global_position.lerp(
			_target_position, 
			interpolation_speed * delta
		)
	
	if sync_rotation:
		var mesh = _target.get_node_or_null("MeshPivot")
		if mesh:
			mesh.rotation.y = lerp_angle(
				mesh.rotation.y, 
				_target_rotation, 
				interpolation_speed * delta
			)


# ==============================================================================
# ÉVÉNEMENTS SYNCHRONISÉS - COMBAT
# ==============================================================================

@rpc("any_peer", "reliable")
func sync_attack(attack_type: String = "basic") -> void:
	"""Synchronise une attaque."""
	if _target.is_multiplayer_authority():
		return  # Ne pas rejouer pour l'autorité
	
	var combat = _target.get_node_or_null("CombatManager")
	if combat and combat.has_method("play_attack_animation"):
		combat.play_attack_animation(attack_type)
	else:
		# Fallback: jouer l'animation directement
		var anim = _target.get_node_or_null("AnimationPlayer")
		if anim and anim.has_animation("attack"):
			anim.play("attack")


func request_attack_sync(attack_type: String = "basic") -> void:
	"""Demande la synchronisation d'une attaque (appelé par le propriétaire)."""
	if _target.is_multiplayer_authority():
		sync_attack.rpc(attack_type)


@rpc("any_peer", "reliable")
func sync_damage(damage: float, from_peer: int, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	"""Synchronise les dégâts reçus."""
	# Ne pas réappliquer les dégâts si on est l'autorité (déjà appliqués)
	if _target.is_multiplayer_authority():
		return
	
	var health = _target.get_node_or_null("HealthComponent")
	if health:
		health.take_damage(damage, null)
	
	# Appliquer le knockback si applicable
	if knockback_dir != Vector3.ZERO and _target is CharacterBody3D:
		_target.velocity += knockback_dir * 5.0


func request_damage_sync(damage: float, knockback_dir: Vector3 = Vector3.ZERO) -> void:
	"""
	Demande la synchronisation de dégâts infligés.
	Appelé quand le joueur local inflige des dégâts à quelqu'un.
	@param damage: Montant des dégâts
	@param knockback_dir: Direction du recul
	"""
	if _target.is_multiplayer_authority():
		var my_peer_id := multiplayer.get_unique_id()
		sync_damage.rpc(damage, my_peer_id, knockback_dir)


@rpc("any_peer", "reliable")
func sync_heal(amount: float) -> void:
	"""Synchronise les soins reçus."""
	if _target.is_multiplayer_authority():
		return
	
	var health = _target.get_node_or_null("HealthComponent")
	if health:
		health.heal(amount)


func request_heal_sync(amount: float) -> void:
	"""Demande la synchronisation des soins."""
	if _target.is_multiplayer_authority():
		sync_heal.rpc(amount)


@rpc("any_peer", "reliable")
func sync_death() -> void:
	"""Synchronise la mort du joueur."""
	if _target.is_multiplayer_authority():
		return
	
	var health = _target.get_node_or_null("HealthComponent")
	if health:
		health.is_dead = true
		health.current_health = 0.0
		health.died.emit()


func request_death_sync() -> void:
	"""Demande la synchronisation de la mort."""
	if _target.is_multiplayer_authority():
		sync_death.rpc()


@rpc("any_peer", "reliable")
func sync_respawn(spawn_pos: Vector3) -> void:
	"""Synchronise le respawn du joueur."""
	_target.global_position = spawn_pos
	_target_position = spawn_pos
	
	var health = _target.get_node_or_null("HealthComponent")
	if health:
		health.reset()


func request_respawn_sync(spawn_pos: Vector3) -> void:
	"""Demande la synchronisation du respawn."""
	if _target.is_multiplayer_authority():
		sync_respawn.rpc(spawn_pos)


# ==============================================================================
# ÉVÉNEMENTS SYNCHRONISÉS - ABILITIES
# ==============================================================================

@rpc("any_peer", "reliable")
func sync_ability(ability_name: String, target_pos: Vector3 = Vector3.ZERO) -> void:
	"""Synchronise l'utilisation d'une capacité spéciale."""
	if _target.is_multiplayer_authority():
		return
	
	# Jouer les effets visuels/sonores de l'ability
	var combat = _target.get_node_or_null("CombatManager")
	if combat and combat.has_method("play_ability_effects"):
		combat.play_ability_effects(ability_name, target_pos)


func request_ability_sync(ability_name: String, target_pos: Vector3 = Vector3.ZERO) -> void:
	"""Demande la synchronisation d'une ability."""
	if _target.is_multiplayer_authority():
		sync_ability.rpc(ability_name, target_pos)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

static func get_sync_component(node: Node) -> MultiplayerSync:
	"""Récupère le composant MultiplayerSync d'un node."""
	return node.get_node_or_null("MultiplayerSync") as MultiplayerSync


func is_local_authority() -> bool:
	"""Retourne true si on a l'autorité sur ce node."""
	return _target and _target.is_multiplayer_authority()

