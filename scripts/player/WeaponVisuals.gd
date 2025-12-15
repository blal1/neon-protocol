# ==============================================================================
# WeaponVisuals.gd - Modèles 3D d'armes
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les modèles visuels des armes et leurs animations
# ==============================================================================

extends Node3D
class_name WeaponVisuals

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal weapon_equipped(weapon_id: String)
signal weapon_unequipped(weapon_id: String)
signal attack_animation_started
signal attack_animation_finished

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum WeaponType { MELEE, RANGED, CYBER }

# ==============================================================================
# CLASSE DONNÉES ARME
# ==============================================================================
class WeaponData:
	var id: String
	var display_name: String
	var type: WeaponType
	var mesh: Mesh
	var material: Material
	var position_offset: Vector3
	var rotation_offset: Vector3
	var scale: Vector3 = Vector3.ONE
	var attack_anim_rotation: Vector3
	var attack_duration: float = 0.3

# ==============================================================================
# ARMES PRÉDÉFINIES
# ==============================================================================
var weapon_library: Dictionary = {}

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_weapon_id: String = ""
var _weapon_mesh: MeshInstance3D
var _weapon_light: OmniLight3D
var _is_animating: bool = false

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@export var hand_pivot: Node3D  ## Point d'attache de l'arme

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	_create_weapon_library()
	
	# Créer le mesh holder
	_weapon_mesh = MeshInstance3D.new()
	_weapon_mesh.name = "WeaponMesh"
	add_child(_weapon_mesh)
	
	# Lumière d'arme (pour les effets)
	_weapon_light = OmniLight3D.new()
	_weapon_light.light_energy = 0.0
	_weapon_light.omni_range = 2.0
	add_child(_weapon_light)


func _create_weapon_library() -> void:
	"""Crée la bibliothèque d'armes."""
	# =====================
	# KATANA CYBER
	# =====================
	var katana := WeaponData.new()
	katana.id = "katana"
	katana.display_name = "Cyber Katana"
	katana.type = WeaponType.MELEE
	
	var katana_mesh := BoxMesh.new()
	katana_mesh.size = Vector3(0.04, 0.04, 1.2)
	katana.mesh = katana_mesh
	
	var katana_mat := StandardMaterial3D.new()
	katana_mat.albedo_color = Color(0.2, 0.2, 0.25)
	katana_mat.metallic = 0.9
	katana_mat.roughness = 0.1
	katana_mat.emission_enabled = true
	katana_mat.emission = Color(0, 0.8, 1)
	katana_mat.emission_energy_multiplier = 1.5
	katana.material = katana_mat
	
	katana.position_offset = Vector3(0.3, 0, 0.3)
	katana.rotation_offset = Vector3(0, 0, deg_to_rad(-45))
	katana.attack_anim_rotation = Vector3(0, deg_to_rad(120), 0)
	katana.attack_duration = 0.25
	
	weapon_library["katana"] = katana
	
	# =====================
	# STUN BATON
	# =====================
	var baton := WeaponData.new()
	baton.id = "stun_baton"
	baton.display_name = "Stun Baton"
	baton.type = WeaponType.MELEE
	
	var baton_mesh := CylinderMesh.new()
	baton_mesh.top_radius = 0.03
	baton_mesh.bottom_radius = 0.04
	baton_mesh.height = 0.8
	baton.mesh = baton_mesh
	
	var baton_mat := StandardMaterial3D.new()
	baton_mat.albedo_color = Color(0.15, 0.15, 0.2)
	baton_mat.metallic = 0.7
	baton_mat.emission_enabled = true
	baton_mat.emission = Color(1, 0.8, 0)
	baton_mat.emission_energy_multiplier = 2.0
	baton.material = baton_mat
	
	baton.position_offset = Vector3(0.25, 0, 0.2)
	baton.rotation_offset = Vector3(deg_to_rad(-90), 0, 0)
	baton.attack_anim_rotation = Vector3(deg_to_rad(90), 0, 0)
	baton.attack_duration = 0.2
	
	weapon_library["stun_baton"] = baton
	
	# =====================
	# PISTOL
	# =====================
	var pistol := WeaponData.new()
	pistol.id = "pistol"
	pistol.display_name = "Cyber Pistol"
	pistol.type = WeaponType.RANGED
	
	# Corps du pistolet (composé)
	var pistol_mesh := BoxMesh.new()
	pistol_mesh.size = Vector3(0.08, 0.15, 0.25)
	pistol.mesh = pistol_mesh
	
	var pistol_mat := StandardMaterial3D.new()
	pistol_mat.albedo_color = Color(0.1, 0.1, 0.12)
	pistol_mat.metallic = 0.8
	pistol_mat.roughness = 0.3
	pistol_mat.emission_enabled = true
	pistol_mat.emission = Color(1, 0.2, 0.2)
	pistol_mat.emission_energy_multiplier = 0.5
	pistol.material = pistol_mat
	
	pistol.position_offset = Vector3(0.3, 0.1, 0.3)
	pistol.rotation_offset = Vector3(0, deg_to_rad(90), 0)
	pistol.attack_anim_rotation = Vector3(deg_to_rad(-15), 0, 0)
	pistol.attack_duration = 0.15
	
	weapon_library["pistol"] = pistol
	
	# =====================
	# PLASMA RIFLE
	# =====================
	var rifle := WeaponData.new()
	rifle.id = "plasma_rifle"
	rifle.display_name = "Plasma Rifle"
	rifle.type = WeaponType.RANGED
	
	var rifle_mesh := BoxMesh.new()
	rifle_mesh.size = Vector3(0.1, 0.12, 0.7)
	rifle.mesh = rifle_mesh
	
	var rifle_mat := StandardMaterial3D.new()
	rifle_mat.albedo_color = Color(0.15, 0.15, 0.18)
	rifle_mat.metallic = 0.85
	rifle_mat.emission_enabled = true
	rifle_mat.emission = Color(0.2, 1, 0.4)
	rifle_mat.emission_energy_multiplier = 1.0
	rifle.material = rifle_mat
	
	rifle.position_offset = Vector3(0.25, 0, 0.2)
	rifle.rotation_offset = Vector3(0, deg_to_rad(90), 0)
	rifle.scale = Vector3(1, 1, 1)
	rifle.attack_anim_rotation = Vector3(deg_to_rad(-10), 0, 0)
	rifle.attack_duration = 0.1
	
	weapon_library["plasma_rifle"] = rifle
	
	# =====================
	# CYBER FISTS
	# =====================
	var fists := WeaponData.new()
	fists.id = "cyber_fists"
	fists.display_name = "Cyber Fists"
	fists.type = WeaponType.CYBER
	
	var fists_mesh := BoxMesh.new()
	fists_mesh.size = Vector3(0.15, 0.1, 0.2)
	fists.mesh = fists_mesh
	
	var fists_mat := StandardMaterial3D.new()
	fists_mat.albedo_color = Color(0.3, 0.3, 0.35)
	fists_mat.metallic = 0.95
	fists_mat.emission_enabled = true
	fists_mat.emission = Color(1, 0.5, 0)
	fists_mat.emission_energy_multiplier = 1.5
	fists.material = fists_mat
	
	fists.position_offset = Vector3(0.25, 0, 0.15)
	fists.attack_anim_rotation = Vector3(0, 0, deg_to_rad(-30))
	fists.attack_duration = 0.15
	
	weapon_library["cyber_fists"] = fists


# ==============================================================================
# ÉQUIPEMENT
# ==============================================================================

func equip_weapon(weapon_id: String) -> bool:
	"""Équipe une arme."""
	if not weapon_library.has(weapon_id):
		push_warning("WeaponVisuals: Arme inconnue: " + weapon_id)
		return false
	
	var weapon_data: WeaponData = weapon_library[weapon_id]
	
	# Configurer le mesh
	_weapon_mesh.mesh = weapon_data.mesh
	_weapon_mesh.set_surface_override_material(0, weapon_data.material)
	
	# Position et rotation
	_weapon_mesh.position = weapon_data.position_offset
	_weapon_mesh.rotation = weapon_data.rotation_offset
	_weapon_mesh.scale = weapon_data.scale
	
	# Lumière selon le type
	match weapon_data.type:
		WeaponType.MELEE:
			_weapon_light.light_color = Color(0, 0.8, 1)
		WeaponType.RANGED:
			_weapon_light.light_color = Color(1, 0.3, 0.1)
		WeaponType.CYBER:
			_weapon_light.light_color = Color(1, 0.5, 0)
	
	_weapon_light.light_energy = 0.5
	
	current_weapon_id = weapon_id
	_weapon_mesh.visible = true
	
	weapon_equipped.emit(weapon_id)
	return true


func unequip_weapon() -> void:
	"""Retire l'arme."""
	if current_weapon_id.is_empty():
		return
	
	var old_id := current_weapon_id
	current_weapon_id = ""
	_weapon_mesh.visible = false
	_weapon_light.light_energy = 0.0
	
	weapon_unequipped.emit(old_id)


# ==============================================================================
# ANIMATIONS
# ==============================================================================

func play_attack_animation(combo_level: int = 0) -> void:
	"""Joue l'animation d'attaque."""
	if _is_animating or current_weapon_id.is_empty():
		return
	
	if not weapon_library.has(current_weapon_id):
		return
	
	_is_animating = true
	attack_animation_started.emit()
	
	var weapon_data: WeaponData = weapon_library[current_weapon_id]
	var original_rotation := _weapon_mesh.rotation
	
	# Direction alternée selon le combo
	var direction := 1.0 if combo_level % 2 == 0 else -1.0
	var target_rotation := original_rotation + weapon_data.attack_anim_rotation * direction
	
	# Animation
	var tween := create_tween()
	
	# Phase 1: Préparation rapide
	var prep_rotation := original_rotation - weapon_data.attack_anim_rotation * 0.3 * direction
	tween.tween_property(_weapon_mesh, "rotation", prep_rotation, weapon_data.attack_duration * 0.2)
	
	# Phase 2: Swing
	tween.tween_property(_weapon_mesh, "rotation", target_rotation, weapon_data.attack_duration * 0.3)
	
	# Flash de lumière
	tween.parallel().tween_property(_weapon_light, "light_energy", 3.0, weapon_data.attack_duration * 0.2)
	tween.tween_property(_weapon_light, "light_energy", 0.5, weapon_data.attack_duration * 0.3)
	
	# Phase 3: Retour
	tween.tween_property(_weapon_mesh, "rotation", original_rotation, weapon_data.attack_duration * 0.5)
	
	await tween.finished
	
	_is_animating = false
	attack_animation_finished.emit()


func play_fire_animation() -> void:
	"""Animation de tir (armes à distance)."""
	if _is_animating or current_weapon_id.is_empty():
		return
	
	_is_animating = true
	attack_animation_started.emit()
	
	var original_pos := _weapon_mesh.position
	var recoil_pos := original_pos + Vector3(0, 0, 0.1)
	
	var tween := create_tween()
	
	# Recul
	tween.tween_property(_weapon_mesh, "position", recoil_pos, 0.05)
	tween.tween_property(_weapon_mesh, "position", original_pos, 0.15)
	
	# Flash
	tween.parallel().tween_property(_weapon_light, "light_energy", 5.0, 0.02)
	tween.tween_property(_weapon_light, "light_energy", 0.5, 0.1)
	
	await tween.finished
	
	_is_animating = false
	attack_animation_finished.emit()


# ==============================================================================
# EFFETS SPÉCIAUX
# ==============================================================================

func show_trail_effect(color: Color = Color.CYAN) -> void:
	"""Affiche un trail effect pour les armes de mêlée."""
	# Créer un trail temporaire
	var trail := MeshInstance3D.new()
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(0.02, 0.02, 1.0)
	trail.mesh = trail_mesh
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.set_surface_override_material(0, mat)
	
	trail.global_transform = _weapon_mesh.global_transform
	get_tree().current_scene.add_child(trail)
	
	# Fade out
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(trail.queue_free)


func pulse_energy(color: Color = Color.CYAN, intensity: float = 2.0) -> void:
	"""Effet de pulsation d'énergie."""
	var tween := create_tween()
	tween.tween_property(_weapon_light, "light_energy", intensity, 0.1)
	tween.tween_property(_weapon_light, "light_energy", 0.5, 0.3)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_current_weapon_data() -> WeaponData:
	"""Retourne les données de l'arme actuelle."""
	if current_weapon_id.is_empty():
		return null
	return weapon_library.get(current_weapon_id)


func is_weapon_equipped() -> bool:
	"""Retourne si une arme est équipée."""
	return not current_weapon_id.is_empty()


func get_weapon_type() -> WeaponType:
	"""Retourne le type de l'arme actuelle."""
	var data := get_current_weapon_data()
	if data:
		return data.type
	return WeaponType.MELEE
