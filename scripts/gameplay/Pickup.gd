# ==============================================================================
# Pickup.gd - Système de ramassables
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Items ramassables : crédits, santé, munitions, etc.
# ==============================================================================

extends Area3D
class_name Pickup

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal picked_up(pickup_type: PickupType, value: float)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum PickupType {
	CREDITS,
	HEALTH,
	AMMO,
	ENERGY,
	EXPERIENCE,
	KEY,
	DATA_CHIP
}

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export var pickup_type: PickupType = PickupType.CREDITS
@export var value: float = 10.0
@export var auto_collect: bool = true
@export var collect_range: float = 1.5
@export var magnet_range: float = 5.0
@export var magnet_speed: float = 10.0

@export_group("Visuel")
@export var bob_amplitude: float = 0.2
@export var bob_speed: float = 2.0
@export var rotation_speed: float = 2.0

# ==============================================================================
# COULEURS PAR TYPE
# ==============================================================================
var type_colors: Dictionary = {
	PickupType.CREDITS: Color(1, 0.85, 0),
	PickupType.HEALTH: Color(0.2, 1, 0.4),
	PickupType.AMMO: Color(1, 0.5, 0.1),
	PickupType.ENERGY: Color(0, 0.8, 1),
	PickupType.EXPERIENCE: Color(0.8, 0.4, 1),
	PickupType.KEY: Color(1, 1, 0.5),
	PickupType.DATA_CHIP: Color(0.4, 1, 0.8)
}

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var _bob_time: float = 0.0
var _base_y: float = 0.0
var _is_being_collected: bool = false
var _target_player: Node3D = null

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
var _mesh: MeshInstance3D
var _light: OmniLight3D

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	add_to_group("pickup")
	_base_y = global_position.y
	
	# Créer le visuel
	_create_visual()
	
	# Connecter les signaux
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	"""Mise à jour."""
	if _is_being_collected:
		_move_toward_player(delta)
		return
	
	# Animation bob
	_bob_time += delta * bob_speed
	global_position.y = _base_y + sin(_bob_time) * bob_amplitude
	
	# Rotation
	if _mesh:
		_mesh.rotation.y += rotation_speed * delta
	
	# Effet magnétique
	if auto_collect:
		_check_magnet()


# ==============================================================================
# CRÉATION VISUELLE
# ==============================================================================

func _create_visual() -> void:
	"""Crée le mesh et la lumière."""
	var color: Color = type_colors.get(pickup_type, Color.WHITE)
	
	# Mesh selon le type
	_mesh = MeshInstance3D.new()
	
	match pickup_type:
		PickupType.CREDITS:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.15
			cylinder.bottom_radius = 0.15
			cylinder.height = 0.05
			_mesh.mesh = cylinder
		PickupType.HEALTH:
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 0.3, 0.1)
			_mesh.mesh = box
		PickupType.AMMO:
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.1
			capsule.height = 0.3
			_mesh.mesh = capsule
		PickupType.ENERGY, PickupType.EXPERIENCE:
			var sphere := SphereMesh.new()
			sphere.radius = 0.2
			_mesh.mesh = sphere
		PickupType.KEY, PickupType.DATA_CHIP:
			var prism := PrismMesh.new()
			prism.size = Vector3(0.25, 0.25, 0.1)
			_mesh.mesh = prism
		_:
			var sphere := SphereMesh.new()
			sphere.radius = 0.2
			_mesh.mesh = sphere
	
	# Material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.metallic = 0.8
	mat.roughness = 0.2
	_mesh.set_surface_override_material(0, mat)
	
	add_child(_mesh)
	
	# Lumière
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 1.0
	_light.omni_range = 2.0
	add_child(_light)
	
	# Collision
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = collect_range
	collision.shape = shape
	add_child(collision)


# ==============================================================================
# COLLECTION
# ==============================================================================

func _on_body_entered(body: Node3D) -> void:
	"""Appelé quand un corps entre dans la zone."""
	if _is_being_collected:
		return
	
	if body.is_in_group("player"):
		collect(body)


func _check_magnet() -> void:
	"""Vérifie l'effet magnétique."""
	if _is_being_collected:
		return
	
	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		var distance := global_position.distance_to(player.global_position)
		if distance <= magnet_range:
			_is_being_collected = true
			_target_player = player
			break


func _move_toward_player(delta: float) -> void:
	"""Se déplace vers le joueur."""
	if not _target_player or not is_instance_valid(_target_player):
		_is_being_collected = false
		return
	
	var direction := (_target_player.global_position - global_position).normalized()
	global_position += direction * magnet_speed * delta
	
	# Accélérer
	magnet_speed *= 1.05
	
	# Collecter si assez proche
	if global_position.distance_to(_target_player.global_position) < 0.5:
		collect(_target_player)


func collect(collector: Node3D) -> void:
	"""Collecte le pickup."""
	if _is_being_collected and _target_player != collector:
		return
	
	# Appliquer l'effet
	_apply_effect(collector)
	
	# Signal
	picked_up.emit(pickup_type, value)
	
	# Son UI
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_sound"):
		audio.play_ui_sound("pickup")
	
	# Notification toast
	_show_pickup_notification()
	
	# Stats
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		stats.increment("items_collected")
	
	# Animation de collection
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	if _light:
		tween.tween_property(_light, "light_energy", 5.0, 0.1)
	tween.chain().tween_callback(queue_free)


func _apply_effect(collector: Node3D) -> void:
	"""Applique l'effet du pickup."""
	match pickup_type:
		PickupType.CREDITS:
			var inventory = get_node_or_null("/root/InventoryManager")
			if inventory:
				inventory.add_credits(int(value))
		
		PickupType.HEALTH:
			var health = collector.get_node_or_null("HealthComponent")
			if health:
				health.heal(value)
		
		PickupType.AMMO:
			var weapon = collector.get_node_or_null("WeaponSystem")
			if weapon and weapon.has_method("add_ammo"):
				weapon.add_ammo(int(value))
		
		PickupType.ENERGY:
			# Pour le drone ou abilities
			if collector.has_method("add_energy"):
				collector.add_energy(value)
		
		PickupType.EXPERIENCE:
			var skill = get_node_or_null("/root/SkillTreeManager")
			if skill and skill.has_method("add_experience"):
				skill.add_experience(int(value))
		
		PickupType.KEY:
			var save = get_node_or_null("/root/SaveManager")
			if save:
				var keys: int = save.get_value("keys", 0)
				save.set_value("keys", keys + 1)
		
		PickupType.DATA_CHIP:
			var save = get_node_or_null("/root/SaveManager")
			if save:
				var chips: Array = save.get_value("data_chips", [])
				chips.append(name)
				save.set_value("data_chips", chips)


func _show_pickup_notification() -> void:
	"""Affiche une notification."""
	var toast = get_node_or_null("/root/ToastNotification")
	if not toast:
		return
	
	var text := ""
	match pickup_type:
		PickupType.CREDITS:
			text = "+%d ¥" % int(value)
		PickupType.HEALTH:
			text = "+%d HP" % int(value)
		PickupType.AMMO:
			text = "+%d Munitions" % int(value)
		PickupType.ENERGY:
			text = "+%d Énergie" % int(value)
		PickupType.EXPERIENCE:
			text = "+%d XP" % int(value)
		PickupType.KEY:
			text = "🔑 Clé obtenue"
		PickupType.DATA_CHIP:
			text = "💾 Data Chip obtenu"
	
	toast.show_item_acquired(text)


# ==============================================================================
# FACTORY METHODS
# ==============================================================================

static func create_credits(position: Vector3, amount: float = 10.0) -> Pickup:
	"""Crée un pickup de crédits."""
	var pickup := Pickup.new()
	pickup.pickup_type = PickupType.CREDITS
	pickup.value = amount
	pickup.global_position = position
	return pickup


static func create_health(position: Vector3, amount: float = 25.0) -> Pickup:
	"""Crée un pickup de santé."""
	var pickup := Pickup.new()
	pickup.pickup_type = PickupType.HEALTH
	pickup.value = amount
	pickup.global_position = position
	return pickup


static func create_ammo(position: Vector3, amount: float = 10.0) -> Pickup:
	"""Crée un pickup de munitions."""
	var pickup := Pickup.new()
	pickup.pickup_type = PickupType.AMMO
	pickup.value = amount
	pickup.global_position = position
	return pickup
