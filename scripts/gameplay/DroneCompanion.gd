# ==============================================================================
# DroneCompanion.gd - Compagnon IA Drone
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Drone assistant qui suit le joueur et peut effectuer diverses actions
# ==============================================================================

extends Node3D
class_name DroneCompanion

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal enemy_spotted(enemy: Node3D)
signal item_spotted(item: Node3D)
signal scanning_started
signal scanning_completed(results: Array)
signal ability_used(ability_name: String)
signal low_energy

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum DroneState {
	FOLLOW,      # Suit le joueur
	SCAN,        # Scanne les environs
	ATTACK,      # Mode offensif
	RETURN,      # Retourne au joueur
	IDLE,        # Inactif
	DISABLED     # Désactivé (EMP, etc.)
}

enum DroneType {
	RECON,       # Éclaireur (scan, détection)
	COMBAT,      # Combat (attaques légères)
	SUPPORT      # Support (soin, bouclier)
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Configuration")
@export var drone_type: DroneType = DroneType.RECON
@export var drone_name: String = "ARIA-7"

@export_group("Mouvement")
@export var follow_speed: float = 8.0
@export var follow_distance: float = 3.0
@export var hover_height: float = 2.0
@export var hover_amplitude: float = 0.2
@export var hover_frequency: float = 2.0

@export_group("Capacités")
@export var scan_range: float = 15.0
@export var scan_cooldown: float = 10.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 2.0
@export var heal_amount: float = 5.0

@export_group("Énergie")
@export var max_energy: float = 100.0
@export var energy_regen_rate: float = 2.0  # Par seconde
@export var scan_energy_cost: float = 20.0
@export var attack_energy_cost: float = 15.0

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_state: DroneState = DroneState.FOLLOW
var player: Node3D = null
var current_target: Node3D = null
var current_energy: float = 100.0
var _can_scan: bool = true
var _can_attack: bool = true
var _hover_time: float = 0.0
var _base_height: float = 0.0

# Résultats du scan
var _last_scan_enemies: Array = []
var _last_scan_items: Array = []

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var mesh: MeshInstance3D = $MeshPivot/Mesh if has_node("MeshPivot/Mesh") else null
@onready var scan_area: Area3D = $ScanArea if has_node("ScanArea") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du drone."""
	_find_player()
	_base_height = hover_height
	current_energy = max_energy
	
	# Créer les composants manquants
	if not scan_area:
		_create_scan_area()
	
	# S'ajouter au groupe des alliés
	add_to_group("ally")
	add_to_group("drone")


func _physics_process(delta: float) -> void:
	"""Mise à jour du drone."""
	# Régénération d'énergie
	_regenerate_energy(delta)
	
	# Mise à jour de l'effet de flottement
	_update_hover(delta)
	
	# Machine à états
	match current_state:
		DroneState.FOLLOW:
			_state_follow(delta)
		DroneState.SCAN:
			_state_scan(delta)
		DroneState.ATTACK:
			_state_attack(delta)
		DroneState.RETURN:
			_state_return(delta)
		DroneState.IDLE:
			pass
		DroneState.DISABLED:
			_state_disabled(delta)


# ==============================================================================
# MACHINE À ÉTATS
# ==============================================================================

func _state_follow(delta: float) -> void:
	"""Suit le joueur à distance."""
	if not player:
		_find_player()
		return
	
	var target_pos := player.global_position + Vector3(
		sin(Time.get_ticks_msec() * 0.001) * 1.5,
		hover_height,
		cos(Time.get_ticks_msec() * 0.001) * 1.5
	)
	
	var distance := global_position.distance_to(target_pos)
	
	if distance > follow_distance:
		var direction := (target_pos - global_position).normalized()
		global_position = global_position.lerp(target_pos, follow_speed * delta * 0.5)
	
	# Regarder vers la direction du mouvement
	_look_at_smooth(player.global_position, delta)


func _state_scan(_delta: float) -> void:
	"""État de scan (géré par la coroutine)."""
	pass


func _state_attack(delta: float) -> void:
	"""Mode attaque."""
	if not current_target or not is_instance_valid(current_target):
		_change_state(DroneState.FOLLOW)
		return
	
	# Se positionner autour de la cible
	var orbit_pos := current_target.global_position + Vector3(
		sin(Time.get_ticks_msec() * 0.002) * 4.0,
		hover_height + 1.0,
		cos(Time.get_ticks_msec() * 0.002) * 4.0
	)
	
	global_position = global_position.lerp(orbit_pos, follow_speed * delta * 0.3)
	_look_at_smooth(current_target.global_position, delta)
	
	# Attaquer si possible
	if _can_attack and current_energy >= attack_energy_cost:
		_perform_attack()


func _state_return(delta: float) -> void:
	"""Retourne rapidement au joueur."""
	if not player:
		_change_state(DroneState.IDLE)
		return
	
	var target_pos := player.global_position + Vector3(0, hover_height, 2)
	var distance := global_position.distance_to(target_pos)
	
	if distance < 2.0:
		_change_state(DroneState.FOLLOW)
		return
	
	global_position = global_position.lerp(target_pos, follow_speed * delta)


func _state_disabled(_delta: float) -> void:
	"""Drone désactivé (tombe lentement)."""
	global_position.y = lerp(global_position.y, 0.5, 0.02)


# ==============================================================================
# CAPACITÉS
# ==============================================================================

func activate_scan() -> void:
	"""Active le scan des environs."""
	if not _can_scan or current_energy < scan_energy_cost:
		return
	
	_can_scan = false
	current_energy -= scan_energy_cost
	_change_state(DroneState.SCAN)
	scanning_started.emit()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Scan en cours")
	
	# Animation de scan
	await _perform_scan_animation()
	
	# Collecter les résultats
	_last_scan_enemies.clear()
	_last_scan_items.clear()
	
	var bodies := get_tree().get_nodes_in_group("enemy")
	for body in bodies:
		if body is Node3D:
			var distance := global_position.distance_to(body.global_position)
			if distance <= scan_range:
				_last_scan_enemies.append(body)
				enemy_spotted.emit(body)
	
	var items := get_tree().get_nodes_in_group("pickup")
	for item in items:
		if item is Node3D:
			var distance := global_position.distance_to(item.global_position)
			if distance <= scan_range:
				_last_scan_items.append(item)
				item_spotted.emit(item)
	
	# Annoncer les résultats
	if tts:
		var msg := "%d ennemis et %d objets détectés" % [_last_scan_enemies.size(), _last_scan_items.size()]
		tts.speak(msg)
	
	scanning_completed.emit(_last_scan_enemies + _last_scan_items)
	
	_change_state(DroneState.FOLLOW)
	
	# Cooldown
	await get_tree().create_timer(scan_cooldown).timeout
	_can_scan = true


func _perform_scan_animation() -> void:
	"""Animation de scan."""
	if mesh:
		var original_scale := mesh.scale
		var tween := create_tween()
		tween.tween_property(mesh, "scale", original_scale * 1.5, 0.3)
		tween.tween_property(mesh, "scale", original_scale, 0.3)
		await tween.finished
	else:
		await get_tree().create_timer(0.6).timeout


func attack_target(target: Node3D) -> void:
	"""Ordonne au drone d'attaquer une cible."""
	if drone_type != DroneType.COMBAT:
		return
	
	current_target = target
	_change_state(DroneState.ATTACK)
	ability_used.emit("attack")


func _perform_attack() -> void:
	"""Effectue une attaque."""
	if not current_target or not is_instance_valid(current_target):
		return
	
	_can_attack = false
	current_energy -= attack_energy_cost
	
	# Infliger les dégâts
	var health = current_target.get_node_or_null("HealthComponent")
	if health:
		health.take_damage(attack_damage, self)
	
	# Cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	_can_attack = true


func heal_player() -> void:
	"""Soigne le joueur (mode support)."""
	if drone_type != DroneType.SUPPORT:
		return
	
	if not player:
		return
	
	var health = player.get_node_or_null("HealthComponent")
	if health and health.has_method("heal"):
		health.heal(heal_amount)
		ability_used.emit("heal")
		
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Soins appliqués")


func provide_shield() -> void:
	"""
	Fournit un bouclier temporaire au joueur.
	Le bouclier absorbe les dégâts pendant une durée limitée.
	"""
	if drone_type != DroneType.SUPPORT:
		return
	
	if not player:
		return
	
	# Vérifier l'énergie
	var shield_energy_cost := 30.0
	if current_energy < shield_energy_cost:
		var tts = get_node_or_null("/root/TTSManager")
		if tts:
			tts.speak("Énergie insuffisante pour le bouclier")
		return
	
	# Vérifier si bouclier déjà actif
	if player.has_meta("drone_shield_active") and player.get_meta("drone_shield_active"):
		return
	
	# Consommer l'énergie
	current_energy -= shield_energy_cost
	
	# Configurer le bouclier sur le joueur
	var shield_hp := 50.0
	var shield_duration := 8.0
	
	player.set_meta("drone_shield_active", true)
	player.set_meta("drone_shield_hp", shield_hp)
	player.set_meta("drone_shield_max", shield_hp)
	
	# Créer l'effet visuel du bouclier
	var shield_visual := _create_shield_visual()
	if shield_visual:
		player.add_child(shield_visual)
	
	ability_used.emit("shield")
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Bouclier activé")
	
	# Haptic
	var haptic = get_node_or_null("/root/HapticFeedback")
	if haptic:
		haptic.vibrate_light()
	
	# Timer pour désactivation automatique
	await get_tree().create_timer(shield_duration).timeout
	
	# Désactiver le bouclier
	_remove_shield(shield_visual)


func _create_shield_visual() -> Node3D:
	"""Crée l'effet visuel du bouclier (sphère transparente)."""
	var shield_container := Node3D.new()
	shield_container.name = "DroneShieldVisual"
	
	# Mesh sphérique pour le bouclier
	var shield_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 2.4
	sphere.radial_segments = 32
	sphere.rings = 16
	shield_mesh.mesh = sphere
	
	# Material transparent avec glow
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.8, 1.0, 0.2)  # Cyan transparent
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.8, 1.0)
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_FRONT  # Voir l'intérieur
	shield_mesh.set_surface_override_material(0, mat)
	
	shield_mesh.position = Vector3(0, 1.0, 0)  # Centré sur le joueur
	shield_container.add_child(shield_mesh)
	
	# Animation pulsante
	var tween := shield_container.create_tween()
	tween.set_loops()
	tween.tween_property(mat, "emission_energy_multiplier", 1.0, 0.5)
	tween.tween_property(mat, "emission_energy_multiplier", 0.3, 0.5)
	
	return shield_container


func _remove_shield(shield_visual: Node3D) -> void:
	"""Retire le bouclier du joueur."""
	if not player:
		return
	
	# Nettoyer les métadonnées
	player.set_meta("drone_shield_active", false)
	player.remove_meta("drone_shield_hp")
	player.remove_meta("drone_shield_max")
	
	# Supprimer le visuel avec fade
	if shield_visual and is_instance_valid(shield_visual):
		var tween := create_tween()
		tween.tween_property(shield_visual, "modulate:a", 0.0, 0.3)
		tween.tween_callback(shield_visual.queue_free)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Bouclier désactivé")


func get_shield_hp() -> float:
	"""Retourne les points de vie du bouclier actif."""
	if player and player.has_meta("drone_shield_hp"):
		return player.get_meta("drone_shield_hp")
	return 0.0


func damage_shield(amount: float) -> float:
	"""
	Applique des dégâts au bouclier.
	@return: Les dégâts restants après absorption
	"""
	if not player or not player.has_meta("drone_shield_active"):
		return amount
	
	if not player.get_meta("drone_shield_active"):
		return amount
	
	var shield_hp: float = player.get_meta("drone_shield_hp")
	var absorbed := min(amount, shield_hp)
	shield_hp -= absorbed
	
	player.set_meta("drone_shield_hp", shield_hp)
	
	# Si bouclier détruit
	if shield_hp <= 0:
		var shield_visual = player.get_node_or_null("DroneShieldVisual")
		_remove_shield(shield_visual)
		
		# Effet de destruction
		var haptic = get_node_or_null("/root/HapticFeedback")
		if haptic:
			haptic.vibrate_medium()
	
	return amount - absorbed


# ==============================================================================
# ÉNERGIE
# ==============================================================================

func _regenerate_energy(delta: float) -> void:
	"""Régénère l'énergie du drone."""
	if current_state == DroneState.DISABLED:
		return
	
	current_energy = min(current_energy + energy_regen_rate * delta, max_energy)
	
	if current_energy < max_energy * 0.2 and current_energy > 0:
		low_energy.emit()


func recharge(amount: float) -> void:
	"""Recharge le drone."""
	current_energy = min(current_energy + amount, max_energy)


func disable(duration: float) -> void:
	"""Désactive le drone temporairement (EMP)."""
	_change_state(DroneState.DISABLED)
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Drone désactivé")
	
	await get_tree().create_timer(duration).timeout
	
	if current_state == DroneState.DISABLED:
		_change_state(DroneState.FOLLOW)
		if tts:
			tts.speak("Drone réactivé")


# ==============================================================================
# MOUVEMENT
# ==============================================================================

func _update_hover(delta: float) -> void:
	"""Met à jour l'effet de flottement."""
	_hover_time += delta
	var hover_offset := sin(_hover_time * hover_frequency) * hover_amplitude
	
	# Appliquer uniquement si on suit le joueur
	if current_state == DroneState.FOLLOW:
		global_position.y += hover_offset * delta


func _look_at_smooth(target: Vector3, delta: float) -> void:
	"""Rotation lisse vers une cible."""
	var direction := (target - global_position)
	direction.y = 0
	
	if direction.length() < 0.1:
		return
	
	var target_angle := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 5.0 * delta)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _find_player() -> void:
	"""Trouve le joueur dans la scène."""
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]


func _change_state(new_state: DroneState) -> void:
	"""Change l'état du drone."""
	current_state = new_state


func _create_scan_area() -> void:
	"""Crée l'area de scan."""
	scan_area = Area3D.new()
	scan_area.name = "ScanArea"
	
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = scan_range
	collision.shape = sphere
	
	scan_area.add_child(collision)
	add_child(scan_area)


func get_energy_percent() -> float:
	"""Retourne le pourcentage d'énergie."""
	return current_energy / max_energy * 100.0


func get_state_name() -> String:
	"""Retourne le nom de l'état actuel."""
	return DroneState.keys()[current_state]


func recall() -> void:
	"""Rappelle le drone au joueur."""
	_change_state(DroneState.RETURN)
