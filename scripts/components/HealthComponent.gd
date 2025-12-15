# ==============================================================================
# HealthComponent.gd - Composant de santé réutilisable
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Peut être attaché à n'importe quel Node3D (Joueur, Ennemi, etc.)
# Gère la santé, les dégâts et la mort
# Supporte la synchronisation multijoueur automatique
# ==============================================================================

extends Node
class_name HealthComponent

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal health_changed(current_health: float, max_health: float)
signal damage_taken(amount: float, source: Node)
signal healed(amount: float)
signal died

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var max_health: float = 100.0  ## Santé maximale
@export var start_at_max: bool = true  ## Commencer avec la santé max
@export var enable_network_sync: bool = true  ## Synchroniser en multijoueur

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_health: float = 100.0
var is_dead: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialise la santé au démarrage."""
	if start_at_max:
		current_health = max_health
	health_changed.emit(current_health, max_health)


# ==============================================================================
# MÉTHODES PUBLIQUES
# ==============================================================================

func take_damage(amount: float, source: Node = null, sync_network: bool = true) -> void:
	"""
	Inflige des dégâts au composant.
	@param amount: Quantité de dégâts à infliger
	@param source: Node source des dégâts (optionnel)
	@param sync_network: Si true, synchronise en multijoueur
	"""
	if is_dead:
		return
	
	current_health = max(0.0, current_health - amount)
	damage_taken.emit(amount, source)
	health_changed.emit(current_health, max_health)
	
	# Synchronisation multijoueur
	if sync_network and enable_network_sync:
		_sync_damage(amount, source)
	
	if current_health <= 0.0:
		_die()


func heal(amount: float, sync_network: bool = true) -> void:
	"""
	Soigne le composant.
	@param amount: Quantité de soins
	@param sync_network: Si true, synchronise en multijoueur
	"""
	if is_dead:
		return
	
	var old_health := current_health
	current_health = min(max_health, current_health + amount)
	
	var actual_heal := current_health - old_health
	if actual_heal > 0.0:
		healed.emit(actual_heal)
		health_changed.emit(current_health, max_health)
		
		# Synchronisation multijoueur
		if sync_network and enable_network_sync:
			_sync_heal(actual_heal)


func set_health(value: float) -> void:
	"""Définit directement la santé actuelle."""
	current_health = clamp(value, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0 and not is_dead:
		_die()


func reset() -> void:
	"""Réinitialise la santé à son maximum."""
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)


func get_health_percentage() -> float:
	"""Retourne le pourcentage de santé (0.0 à 1.0)."""
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


func is_full_health() -> bool:
	"""Retourne true si la santé est au maximum."""
	return current_health >= max_health


# ==============================================================================
# MÉTHODES PRIVÉES
# ==============================================================================

func _die() -> void:
	"""Gère la mort du propriétaire."""
	if is_dead:
		return
	
	is_dead = true
	died.emit()
	
	# Synchroniser la mort en multijoueur
	if enable_network_sync:
		_sync_death()


# ==============================================================================
# SYNCHRONISATION MULTIJOUEUR
# ==============================================================================

func _sync_damage(amount: float, _source: Node) -> void:
	"""Synchronise les dégâts en multijoueur."""
	var owner_node := get_parent()
	if not owner_node or not owner_node is Node3D:
		return
	
	# Vérifier si on est en multijoueur et qu'on a l'autorité
	if not multiplayer.has_multiplayer_peer():
		return
	
	if not owner_node.is_multiplayer_authority():
		return
	
	# Chercher le composant MultiplayerSync
	var sync = owner_node.get_node_or_null("MultiplayerSync")
	if sync and sync.has_method("request_damage_sync"):
		sync.request_damage_sync(amount)


func _sync_heal(amount: float) -> void:
	"""Synchronise les soins en multijoueur."""
	var owner_node := get_parent()
	if not owner_node or not owner_node is Node3D:
		return
	
	if not multiplayer.has_multiplayer_peer():
		return
	
	if not owner_node.is_multiplayer_authority():
		return
	
	var sync = owner_node.get_node_or_null("MultiplayerSync")
	if sync and sync.has_method("request_heal_sync"):
		sync.request_heal_sync(amount)


func _sync_death() -> void:
	"""Synchronise la mort en multijoueur."""
	var owner_node := get_parent()
	if not owner_node or not owner_node is Node3D:
		return
	
	if not multiplayer.has_multiplayer_peer():
		return
	
	if not owner_node.is_multiplayer_authority():
		return
	
	var sync = owner_node.get_node_or_null("MultiplayerSync")
	if sync and sync.has_method("request_death_sync"):
		sync.request_death_sync()
