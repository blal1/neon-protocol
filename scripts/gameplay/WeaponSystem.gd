# ==============================================================================
# WeaponSystem.gd - Système d'armes variées
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les différentes armes du joueur (katana, pistolet, bâton électrique)
# ==============================================================================

extends Node
class_name WeaponSystem

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal weapon_equipped(weapon: Weapon)
signal weapon_unequipped(weapon: Weapon)
signal weapon_fired(weapon: Weapon)
signal weapon_reloaded(weapon: Weapon)
signal ammo_changed(current: int, max_ammo: int)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum WeaponType {
	MELEE,
	RANGED,
	ENERGY
}

enum DamageType {
	PHYSICAL,
	ELECTRIC,
	FIRE,
	EMP
}

# ==============================================================================
# CLASSES
# ==============================================================================

class Weapon:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var weapon_type: WeaponType = WeaponType.MELEE
	var damage_type: DamageType = DamageType.PHYSICAL
	
	# Stats
	var base_damage: float = 20.0
	var attack_speed: float = 1.0  # Attaques par seconde
	var range_distance: float = 2.0
	var knockback: float = 0.0
	
	# Munitions (pour RANGED)
	var uses_ammo: bool = false
	var current_ammo: int = 0
	var max_ammo: int = 0
	var reload_time: float = 2.0
	
	# Effets spéciaux
	var special_effects: Array[Dictionary] = []  # [{type: "stun", chance: 0.2, duration: 2.0}]
	
	# Visuel
	var mesh_path: String = ""
	var attack_animation: String = "attack"
	var icon_path: String = ""
	
	func get_dps() -> float:
		return base_damage * attack_speed
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"current_ammo": current_ammo
		}

# ==============================================================================
# VARIABLES
# ==============================================================================
var weapons: Dictionary = {}  # id -> Weapon
var equipped_weapon: Weapon = null
var _attack_cooldown: float = 0.0
var _is_reloading: bool = false

# Références
var player: Node3D = null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation du système d'armes."""
	_create_weapons()
	player = get_parent()


func _process(delta: float) -> void:
	"""Gestion du cooldown."""
	if _attack_cooldown > 0:
		_attack_cooldown -= delta


# ==============================================================================
# CRÉATION DES ARMES
# ==============================================================================

func _create_weapons() -> void:
	"""Crée toutes les armes du jeu."""
	
	# === KATANA ===
	var katana := Weapon.new()
	katana.id = "katana"
	katana.name = "Katana Nano-Lame"
	katana.description = "Lame moléculaire ultra-tranchante. Rapide et létal."
	katana.weapon_type = WeaponType.MELEE
	katana.damage_type = DamageType.PHYSICAL
	katana.base_damage = 35.0
	katana.attack_speed = 1.5
	katana.range_distance = 2.5
	katana.knockback = 2.0
	katana.special_effects = [
		{"type": "bleed", "chance": 0.3, "damage_per_sec": 5, "duration": 3.0}
	]
	weapons[katana.id] = katana
	
	# === BÂTON ÉLECTRIQUE ===
	var stun_baton := Weapon.new()
	stun_baton.id = "stun_baton"
	stun_baton.name = "Bâton Électro-choc"
	stun_baton.description = "Paralyse les ennemis avec des décharges électriques."
	stun_baton.weapon_type = WeaponType.MELEE
	stun_baton.damage_type = DamageType.ELECTRIC
	stun_baton.base_damage = 20.0
	stun_baton.attack_speed = 1.2
	stun_baton.range_distance = 2.0
	stun_baton.knockback = 1.0
	stun_baton.special_effects = [
		{"type": "stun", "chance": 0.4, "duration": 2.0},
		{"type": "emp", "chance": 0.2, "disable_duration": 5.0}
	]
	weapons[stun_baton.id] = stun_baton
	
	# === PISTOLET ===
	var pistol := Weapon.new()
	pistol.id = "pistol"
	pistol.name = "Pistol Smart-Link"
	pistol.description = "Pistolet avec assistance de visée cybernétique."
	pistol.weapon_type = WeaponType.RANGED
	pistol.damage_type = DamageType.PHYSICAL
	pistol.base_damage = 25.0
	pistol.attack_speed = 2.0
	pistol.range_distance = 15.0
	pistol.uses_ammo = true
	pistol.max_ammo = 12
	pistol.current_ammo = 12
	pistol.reload_time = 1.5
	weapons[pistol.id] = pistol
	
	# === FUSIL PLASMA ===
	var plasma_rifle := Weapon.new()
	plasma_rifle.id = "plasma_rifle"
	plasma_rifle.name = "Fusil à Plasma M7"
	plasma_rifle.description = "Arme lourde à énergie. Dégâts massifs mais lent."
	plasma_rifle.weapon_type = WeaponType.ENERGY
	plasma_rifle.damage_type = DamageType.FIRE
	plasma_rifle.base_damage = 60.0
	plasma_rifle.attack_speed = 0.5
	plasma_rifle.range_distance = 20.0
	plasma_rifle.uses_ammo = true
	plasma_rifle.max_ammo = 6
	plasma_rifle.current_ammo = 6
	plasma_rifle.reload_time = 3.0
	plasma_rifle.special_effects = [
		{"type": "burn", "chance": 0.5, "damage_per_sec": 10, "duration": 4.0}
	]
	weapons[plasma_rifle.id] = plasma_rifle
	
	# === POINGS CYBER ===
	var cyber_fists := Weapon.new()
	cyber_fists.id = "cyber_fists"
	cyber_fists.name = "Poings Cybernétiques"
	cyber_fists.description = "Vos propres poings augmentés. Toujours disponible."
	cyber_fists.weapon_type = WeaponType.MELEE
	cyber_fists.damage_type = DamageType.PHYSICAL
	cyber_fists.base_damage = 15.0
	cyber_fists.attack_speed = 2.0
	cyber_fists.range_distance = 1.5
	cyber_fists.knockback = 3.0
	weapons[cyber_fists.id] = cyber_fists
	
	# Équiper les poings par défaut
	equipped_weapon = cyber_fists


# ==============================================================================
# ÉQUIPEMENT
# ==============================================================================

func equip_weapon(weapon_id: String) -> bool:
	"""Équipe une arme."""
	if not weapons.has(weapon_id):
		return false
	
	var old_weapon := equipped_weapon
	equipped_weapon = weapons[weapon_id]
	
	if old_weapon:
		weapon_unequipped.emit(old_weapon)
	
	weapon_equipped.emit(equipped_weapon)
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Arme équipée: " + equipped_weapon.name)
	
	return true


func cycle_weapon(direction: int = 1) -> void:
	"""Passe à l'arme suivante/précédente."""
	var weapon_ids := weapons.keys()
	if weapon_ids.is_empty():
		return
	
	var current_index := weapon_ids.find(equipped_weapon.id) if equipped_weapon else 0
	current_index = (current_index + direction) % weapon_ids.size()
	equip_weapon(weapon_ids[current_index])


# ==============================================================================
# ATTAQUE
# ==============================================================================

func can_attack() -> bool:
	"""Vérifie si une attaque est possible."""
	if _attack_cooldown > 0 or _is_reloading:
		return false
	
	if equipped_weapon and equipped_weapon.uses_ammo:
		return equipped_weapon.current_ammo > 0
	
	return true


func attack(target: Node3D = null) -> Dictionary:
	"""
	Effectue une attaque avec l'arme équipée.
	@return: Dictionnaire avec les résultats de l'attaque
	"""
	if not can_attack() or not equipped_weapon:
		return {"success": false}
	
	_attack_cooldown = 1.0 / equipped_weapon.attack_speed
	
	# Consommer les munitions
	if equipped_weapon.uses_ammo:
		equipped_weapon.current_ammo -= 1
		ammo_changed.emit(equipped_weapon.current_ammo, equipped_weapon.max_ammo)
	
	weapon_fired.emit(equipped_weapon)
	
	# Calculer les dégâts
	var damage := _calculate_damage()
	var effects := _roll_effects()
	
	return {
		"success": true,
		"damage": damage,
		"damage_type": equipped_weapon.damage_type,
		"range": equipped_weapon.range_distance,
		"knockback": equipped_weapon.knockback,
		"effects": effects
	}


func _calculate_damage() -> float:
	"""Calcule les dégâts avec les bonus."""
	var damage := equipped_weapon.base_damage
	
	# Bonus du skill tree
	var skills = get_node_or_null("/root/SkillTreeManager")
	if skills:
		damage += skills.get_damage_bonus()
		
		# Critique
		var crit_chance := skills.get_crit_chance()
		if randf() < crit_chance:
			damage *= 2.0  # Dégâts doublés
	
	# Bonus d'équipement
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("get_total_damage_bonus"):
		damage += inv.get_total_damage_bonus()
	
	return damage


func _roll_effects() -> Array[Dictionary]:
	"""Détermine les effets spéciaux appliqués."""
	var applied_effects: Array[Dictionary] = []
	
	for effect in equipped_weapon.special_effects:
		if randf() < effect.get("chance", 0):
			applied_effects.append(effect.duplicate())
	
	return applied_effects


# ==============================================================================
# RECHARGEMENT
# ==============================================================================

func reload() -> void:
	"""Recharge l'arme actuelle."""
	if not equipped_weapon or not equipped_weapon.uses_ammo:
		return
	
	if equipped_weapon.current_ammo >= equipped_weapon.max_ammo:
		return
	
	if _is_reloading:
		return
	
	_is_reloading = true
	
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Rechargement")
	
	await get_tree().create_timer(equipped_weapon.reload_time).timeout
	
	equipped_weapon.current_ammo = equipped_weapon.max_ammo
	_is_reloading = false
	
	ammo_changed.emit(equipped_weapon.current_ammo, equipped_weapon.max_ammo)
	weapon_reloaded.emit(equipped_weapon)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func get_equipped_weapon() -> Weapon:
	"""Retourne l'arme équipée."""
	return equipped_weapon


func get_all_weapons() -> Array:
	"""Retourne toutes les armes."""
	return weapons.values()


func has_weapon(weapon_id: String) -> bool:
	"""Vérifie si une arme est possédée."""
	return weapons.has(weapon_id)


func get_current_ammo() -> int:
	"""Retourne les munitions actuelles."""
	if equipped_weapon and equipped_weapon.uses_ammo:
		return equipped_weapon.current_ammo
	return -1


func get_max_ammo() -> int:
	"""Retourne le chargeur max."""
	if equipped_weapon and equipped_weapon.uses_ammo:
		return equipped_weapon.max_ammo
	return -1
