# ==============================================================================
# CombatManager.gd - Système de combat avec Auto-Targeting
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère le ciblage automatique et les attaques du joueur
# Détecte l'ennemi le plus proche dans un rayon de 5m
# ==============================================================================

extends Node
class_name CombatManager

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal attack_started
signal attack_hit(target: Node3D, damage: float)
signal attack_missed
signal target_acquired(target: Node3D)
signal target_lost
signal combo_started
signal combo_hit(combo_count: int, multiplier: float)
signal combo_ended(total_hits: int, total_damage: float)
signal combo_max_reached

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Auto-Targeting")
@export var auto_target_range: float = 5.0  ## Rayon de ciblage automatique (mètres)
@export var rotation_speed: float = 15.0  ## Vitesse de rotation vers cible

@export_group("Combat")
@export var attack_damage: float = 25.0  ## Dégâts par attaque
@export var attack_cooldown: float = 0.5  ## Temps entre les attaques
@export var attack_duration: float = 0.3  ## Durée de l'animation d'attaque

@export_group("Combo System")
@export var combo_enabled: bool = true  ## Activer le système de combo
@export var max_combo: int = 3  ## Nombre max de hits dans un combo
@export var combo_window: float = 0.8  ## Temps pour enchaîner (secondes)
@export var combo_damage_multipliers: Array[float] = [1.0, 1.3, 1.8]  ## Multiplicateur par hit

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
var player: Node3D = null
var player_mesh: Node3D = null
var current_target: Node3D = null

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var can_attack: bool = true
var is_attacking: bool = false

# ==============================================================================
# VARIABLES COMBO
# ==============================================================================
var _combo_count: int = 0
var _combo_timer: float = 0.0
var _combo_active: bool = false
var _combo_total_damage: float = 0.0
var _combo_input_buffered: bool = false

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du gestionnaire de combat."""
	# Obtenir la référence au joueur (parent)
	player = get_parent() as Node3D
	if player:
		player_mesh = player.get_node_or_null("MeshPivot")


func _process(delta: float) -> void:
	"""Mise à jour du ciblage et des combos."""
	# Rotation vers la cible pendant une attaque
	if is_attacking and current_target and is_instance_valid(current_target):
		_rotate_toward_target(current_target, delta)
	
	# Gestion du timer de combo
	if _combo_active:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_end_combo()


# ==============================================================================
# MÉTHODES PUBLIQUES - Combat
# ==============================================================================

func request_attack() -> void:
	"""
	Demande une attaque. Appelée par le bouton d'attaque UI.
	Auto-target l'ennemi le plus proche et attaque.
	"""
	if not can_attack or is_attacking:
		return
	
	# Trouver la cible la plus proche
	current_target = find_nearest_enemy()
	
	if current_target:
		target_acquired.emit(current_target)
		_perform_attack()
	else:
		# Attaque dans le vide
		attack_missed.emit()
		_perform_attack_animation_only()


func find_nearest_enemy() -> Node3D:
	"""
	Trouve l'ennemi le plus proche dans le rayon auto_target_range.
	@return: L'ennemi le plus proche ou null
	"""
	if not player:
		return null
	
	var nearest_enemy: Node3D = null
	var nearest_distance: float = auto_target_range
	
	# Chercher les ennemis par groupe
	var enemies := get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		if not enemy is Node3D:
			continue
		
		# Vérifier que l'ennemi est vivant
		var health_comp = enemy.get_node_or_null("HealthComponent")
		if health_comp and health_comp.is_dead:
			continue
		
		var distance: float = player.global_position.distance_to(enemy.global_position)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy


func get_all_enemies_in_range() -> Array[Node3D]:
	"""
	Retourne tous les ennemis dans le rayon de ciblage.
	@return: Array des ennemis à portée
	"""
	var enemies_in_range: Array[Node3D] = []
	
	if not player:
		return enemies_in_range
	
	var enemies := get_tree().get_nodes_in_group("enemy")
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		
		var distance: float = player.global_position.distance_to(enemy.global_position)
		
		if distance <= auto_target_range:
			enemies_in_range.append(enemy)
	
	return enemies_in_range


# ==============================================================================
# MÉTHODES PRIVÉES - Combat
# ==============================================================================

func _perform_attack() -> void:
	"""Exécute une attaque sur la cible actuelle avec système de combo."""
	can_attack = false
	is_attacking = true
	attack_started.emit()
	
	# Gestion du combo
	if combo_enabled:
		if not _combo_active:
			_combo_active = true
			_combo_count = 0
			_combo_total_damage = 0.0
			combo_started.emit()
		
		_combo_timer = combo_window
	
	# Rotation instantanée vers la cible
	if current_target and player_mesh:
		_instant_rotate_toward(current_target)
	
	# Attendre un court délai pour la "fenêtre de dégâts"
	await get_tree().create_timer(attack_duration * 0.5).timeout
	
	# Infliger les dégâts avec multiplicateur de combo
	if current_target and is_instance_valid(current_target):
		var combo_multiplier := 1.0
		if combo_enabled and _combo_count < combo_damage_multipliers.size():
			combo_multiplier = combo_damage_multipliers[_combo_count]
		
		_deal_damage_with_combo(current_target, combo_multiplier)
	
	# Incrémenter le combo
	if combo_enabled:
		_combo_count += 1
		if _combo_count >= max_combo:
			combo_max_reached.emit()
			_end_combo()
	
	# Fin de l'animation
	await get_tree().create_timer(attack_duration * 0.5).timeout
	is_attacking = false
	
	# Cooldown réduit pendant un combo
	var actual_cooldown := attack_cooldown
	if combo_enabled and _combo_active and _combo_count < max_combo:
		actual_cooldown = attack_cooldown * 0.6  # 40% plus rapide pendant combo
	
	await get_tree().create_timer(actual_cooldown).timeout
	can_attack = true
	
	# Perdre la cible après l'attaque (sauf si combo actif)
	if current_target and not _combo_active:
		target_lost.emit()
		current_target = null


func _perform_attack_animation_only() -> void:
	"""Joue l'animation d'attaque sans infliger de dégâts."""
	can_attack = false
	is_attacking = true
	attack_started.emit()
	
	await get_tree().create_timer(attack_duration).timeout
	is_attacking = false
	
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _deal_damage(target: Node3D) -> void:
	"""Inflige des dégâts à la cible."""
	var health_component = target.get_node_or_null("HealthComponent")
	
	if health_component and health_component is HealthComponent:
		health_component.take_damage(attack_damage, player)
		attack_hit.emit(target, attack_damage)
	else:
		# Méthode alternative si pas de HealthComponent
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)
			attack_hit.emit(target, attack_damage)


# ==============================================================================
# MÉTHODES PRIVÉES - Rotation
# ==============================================================================

func _rotate_toward_target(target: Node3D, delta: float) -> void:
	"""Rotation lissée vers la cible."""
	if not player_mesh or not target:
		return
	
	var direction := (target.global_position - player.global_position)
	direction.y = 0.0
	
	if direction.length() < 0.1:
		return
	
	var target_angle := atan2(direction.x, direction.z)
	player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, target_angle, rotation_speed * delta)


func _instant_rotate_toward(target: Node3D) -> void:
	"""Rotation instantanée vers la cible."""
	if not player_mesh or not target:
		return
	
	var direction := (target.global_position - player.global_position)
	direction.y = 0.0
	
	if direction.length() < 0.1:
		return
	
	var target_angle := atan2(direction.x, direction.z)
	player_mesh.rotation.y = target_angle


# ==============================================================================
# MÉTHODES PUBLIQUES - Utilitaires
# ==============================================================================

func has_target() -> bool:
	"""Retourne true si une cible est acquise."""
	return current_target != null and is_instance_valid(current_target)


func get_current_target() -> Node3D:
	"""Retourne la cible actuelle."""
	return current_target


func force_target(target: Node3D) -> void:
	"""Force une cible spécifique (pour scripting)."""
	current_target = target
	if target:
		target_acquired.emit(target)


# ==============================================================================
# MÉTHODES PRIVÉES - Combo
# ==============================================================================

func _deal_damage_with_combo(target: Node3D, multiplier: float) -> void:
	"""Inflige des dégâts avec multiplicateur de combo."""
	var final_damage := attack_damage * multiplier
	
	# Bonus de dégâts depuis l'inventaire
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("get_total_damage_bonus"):
		final_damage += inv.get_total_damage_bonus()
	
	var health_component = target.get_node_or_null("HealthComponent")
	
	if health_component and health_component is HealthComponent:
		health_component.take_damage(final_damage, player)
		attack_hit.emit(target, final_damage)
		_combo_total_damage += final_damage
		combo_hit.emit(_combo_count + 1, multiplier)
	else:
		if target.has_method("take_damage"):
			target.take_damage(final_damage)
			attack_hit.emit(target, final_damage)
			_combo_total_damage += final_damage
			combo_hit.emit(_combo_count + 1, multiplier)


func _end_combo() -> void:
	"""Termine le combo actuel."""
	if not _combo_active:
		return
	
	_combo_active = false
	combo_ended.emit(_combo_count, _combo_total_damage)
	
	# Annoncer le combo via TTS si significatif
	if _combo_count >= 2:
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Combo " + str(_combo_count) + " hits !")
	
	_combo_count = 0
	_combo_total_damage = 0.0
	_combo_timer = 0.0


# ==============================================================================
# MÉTHODES PUBLIQUES - Combo
# ==============================================================================

func get_combo_count() -> int:
	"""Retourne le nombre de hits dans le combo actuel."""
	return _combo_count


func is_combo_active() -> bool:
	"""Retourne true si un combo est en cours."""
	return _combo_active


func get_combo_multiplier() -> float:
	"""Retourne le multiplicateur de dégâts actuel."""
	if _combo_count < combo_damage_multipliers.size():
		return combo_damage_multipliers[_combo_count]
	return combo_damage_multipliers[combo_damage_multipliers.size() - 1]


func reset_combo() -> void:
	"""Réinitialise le combo (appelé si le joueur prend des dégâts)."""
	if _combo_active:
		_end_combo()
