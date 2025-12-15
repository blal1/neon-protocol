# ==============================================================================
# DamageCalculator.gd - Calcul de Dégâts
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Gère les stats, armures, types de dégâts, résistances.
# Séparé de TacticalCombatSystem pour modularité.
# ==============================================================================

extends RefCounted
class_name DamageCalculator

# ==============================================================================
# TYPES DE DÉGÂTS
# ==============================================================================

enum DamageType {
	PHYSICAL,       ## Dégâts physiques (balles, coups)
	ENERGY,         ## Dégâts énergétiques (laser, plasma)
	NEURAL,         ## Dégâts neuraux (hacking, EMP)
	TOXIC,          ## Dégâts toxiques (poison, acide)
	FIRE,           ## Dégâts de feu
	ELECTRIC,       ## Dégâts électriques
	EXPLOSIVE,      ## Dégâts explosifs
	TRUE            ## Dégâts vrais (ignorent armure)
}

enum BodyPart {
	HEAD,
	TORSO,
	ARMS,
	LEGS,
	NONE
}

# ==============================================================================
# MULTIPLICATEURS
# ==============================================================================

const BODY_PART_MULTIPLIERS: Dictionary = {
	BodyPart.HEAD: 2.5,
	BodyPart.TORSO: 1.0,
	BodyPart.ARMS: 0.7,
	BodyPart.LEGS: 0.6,
	BodyPart.NONE: 1.0
}

const CRITICAL_CHANCE_BASE: float = 0.05
const CRITICAL_MULTIPLIER: float = 1.5

# ==============================================================================
# CALCUL PRINCIPAL
# ==============================================================================

static func calculate_damage(
	base_damage: float,
	damage_type: DamageType,
	attacker_stats: Dictionary,
	target_stats: Dictionary,
	hit_info: Dictionary = {}
) -> Dictionary:
	"""
	Calcule les dégâts finaux.
	
	attacker_stats: {strength, weapon_bonus, skill_level, crit_chance}
	target_stats: {armor, resistances: {type: value}, health, shields}
	hit_info: {body_part, distance, is_backstab, is_stealth}
	"""
	
	var result := {
		"raw_damage": base_damage,
		"final_damage": 0.0,
		"is_critical": false,
		"is_backstab": false,
		"damage_type": DamageType.keys()[damage_type],
		"body_part": "",
		"absorbed_by_shield": 0.0,
		"absorbed_by_armor": 0.0,
		"overkill": 0.0
	}
	
	var damage := base_damage
	
	# 1. Bonus de stats attaquant
	damage = _apply_attacker_stats(damage, attacker_stats)
	
	# 2. Multiplicateur partie du corps
	var body_part: BodyPart = hit_info.get("body_part", BodyPart.NONE)
	damage *= BODY_PART_MULTIPLIERS.get(body_part, 1.0)
	result.body_part = BodyPart.keys()[body_part]
	
	# 3. Bonus backstab
	if hit_info.get("is_backstab", false):
		damage *= 1.5
		result.is_backstab = true
	
	# 4. Bonus stealth
	if hit_info.get("is_stealth", false):
		damage *= 2.0
	
	# 5. Critical hit
	var crit_chance: float = attacker_stats.get("crit_chance", CRITICAL_CHANCE_BASE)
	if randf() < crit_chance:
		damage *= CRITICAL_MULTIPLIER
		result.is_critical = true
	
	# 6. Distance falloff (pour armes à feu)
	var distance: float = hit_info.get("distance", 0.0)
	var optimal_range: float = attacker_stats.get("optimal_range", 20.0)
	if distance > optimal_range:
		var falloff := 1.0 - ((distance - optimal_range) / optimal_range) * 0.5
		damage *= maxf(0.3, falloff)
	
	# 7. Boucliers
	var shields: float = target_stats.get("shields", 0.0)
	if shields > 0 and damage_type != DamageType.NEURAL:
		var absorbed := minf(shields, damage)
		result.absorbed_by_shield = absorbed
		damage -= absorbed
	
	# 8. Armure
	if damage_type != DamageType.TRUE:
		var armor: float = target_stats.get("armor", 0.0)
		var armor_reduction := _calculate_armor_reduction(armor, damage_type)
		var absorbed := damage * armor_reduction
		result.absorbed_by_armor = absorbed
		damage -= absorbed
	
	# 9. Résistances élémentaires
	var resistances: Dictionary = target_stats.get("resistances", {})
	if resistances.has(damage_type):
		var resistance: float = resistances[damage_type]
		damage *= (1.0 - resistance)
	
	# 10. Minimum de dégâts
	damage = maxf(1.0, damage)
	
	result.final_damage = damage
	
	# Overkill
	var target_health: float = target_stats.get("health", 100.0)
	if damage > target_health:
		result.overkill = damage - target_health
	
	return result


static func _apply_attacker_stats(damage: float, stats: Dictionary) -> float:
	"""Applique les bonus de stats attaquant."""
	var result := damage
	
	# Force (mêlée)
	var strength: float = stats.get("strength", 0.0)
	result += strength * 0.5
	
	# Bonus d'arme
	var weapon_bonus: float = stats.get("weapon_bonus", 0.0)
	result += weapon_bonus
	
	# Skill level
	var skill_level: float = stats.get("skill_level", 1.0)
	result *= (1.0 + skill_level * 0.1)
	
	return result


static func _calculate_armor_reduction(armor: float, damage_type: DamageType) -> float:
	"""Calcule la réduction d'armure."""
	# Formule: reduction = armor / (armor + 100)
	# 0 armor = 0% reduction
	# 100 armor = 50% reduction
	# 200 armor = 66% reduction
	
	var base_reduction := armor / (armor + 100.0)
	
	# Ajustements par type
	match damage_type:
		DamageType.PHYSICAL:
			return base_reduction
		DamageType.ENERGY:
			return base_reduction * 0.8  # Moins efficace contre énergie
		DamageType.EXPLOSIVE:
			return base_reduction * 0.7  # Explosifs percent
		DamageType.ELECTRIC:
			return base_reduction * 0.5  # Électricité traverse
		DamageType.TOXIC:
			return base_reduction * 0.3  # Toxique presque ignore
		DamageType.NEURAL:
			return 0.0  # Armure inutile
		_:
			return base_reduction


# ==============================================================================
# CALCULS SPÉCIAUX
# ==============================================================================

static func calculate_dot_damage(
	base_damage_per_tick: float,
	damage_type: DamageType,
	target_resistances: Dictionary
) -> float:
	"""Calcule les dégâts over time."""
	var damage := base_damage_per_tick
	
	if target_resistances.has(damage_type):
		damage *= (1.0 - target_resistances[damage_type])
	
	return maxf(0.5, damage)


static func calculate_aoe_damage(
	center_damage: float,
	distance_from_center: float,
	max_radius: float,
	falloff_type: String = "linear"
) -> float:
	"""Calcule les dégâts de zone."""
	if distance_from_center >= max_radius:
		return 0.0
	
	var ratio := distance_from_center / max_radius
	
	match falloff_type:
		"linear":
			return center_damage * (1.0 - ratio)
		"quadratic":
			return center_damage * (1.0 - ratio * ratio)
		"constant":
			return center_damage
		_:
			return center_damage * (1.0 - ratio)


static func calculate_shield_regen(
	current_shields: float,
	max_shields: float,
	regen_rate: float,
	delta: float,
	time_since_damage: float,
	regen_delay: float = 3.0
) -> float:
	"""Calcule la régénération de bouclier."""
	if time_since_damage < regen_delay:
		return current_shields
	
	return minf(max_shields, current_shields + regen_rate * delta)


# ==============================================================================
# ANALYSE DE STATS
# ==============================================================================

static func calculate_effective_health(
	health: float,
	armor: float,
	shields: float = 0.0
) -> float:
	"""Calcule la vie effective (tenant compte de l'armure)."""
	var armor_multiplier := 1.0 + (armor / 100.0)
	return (health + shields) * armor_multiplier


static func compare_stats(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	"""Compare les stats pour estimer le résultat."""
	var attacker_power := attacker.get("damage", 10.0) * (1 + attacker.get("crit_chance", 0.05))
	var defender_ehp := calculate_effective_health(
		defender.get("health", 100.0),
		defender.get("armor", 0.0),
		defender.get("shields", 0.0)
	)
	
	var hits_to_kill := ceili(defender_ehp / attacker_power)
	
	return {
		"hits_to_kill": hits_to_kill,
		"attacker_advantage": attacker_power > (defender_ehp / 10),
		"estimated_damage_per_hit": attacker_power
	}
