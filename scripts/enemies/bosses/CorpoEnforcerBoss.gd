# ==============================================================================
# CorpoEnforcerBoss.gd - Boss "ICE-9 ENFORCER" (Corpo Heights)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Mech de sécurité corpo. Combat clinique: tir de précision, charges rapides.
# Bascule en mode "lockdown" (AOE) seulement en phase finale.
# ==============================================================================

extends BossEnemy
class_name CorpoEnforcerBoss


func _ready() -> void:
	boss_name = "ICE-9 ENFORCER"
	boss_type = "boss_corpo"

	max_health = 450.0
	phase_2_threshold = 0.65
	phase_3_threshold = 0.25

	move_speed = 4.5
	charge_speed = 17.0

	melee_damage = 18.0
	ranged_damage = 22.0
	aoe_damage = 28.0
	aoe_radius = 5.0
	attack_cooldown = 1.6

	phase_attacks = {
		Phase.PHASE_1: [AttackType.RANGED, AttackType.RANGED, AttackType.MELEE],
		Phase.PHASE_2: [AttackType.RANGED, AttackType.MELEE, AttackType.CHARGE],
		Phase.PHASE_3: [AttackType.RANGED, AttackType.CHARGE, AttackType.AOE]
	}

	super._ready()
