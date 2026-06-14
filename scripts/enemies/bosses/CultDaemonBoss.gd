# ==============================================================================
# CultDaemonBoss.gd - Boss "DAEMON.HOLLOW" (The Depths)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# IA-culte rituelle. Frêle mais bascule vite en phases de zone destructrices.
# Compense un faible melee par des AOE fréquentes et des charges erratiques.
# ==============================================================================

extends BossEnemy
class_name CultDaemonBoss


func _ready() -> void:
	boss_name = "DAEMON.HOLLOW"
	boss_type = "boss_cult"

	max_health = 380.0
	phase_2_threshold = 0.75
	phase_3_threshold = 0.4

	move_speed = 5.0
	charge_speed = 19.0

	melee_damage = 14.0
	ranged_damage = 18.0
	aoe_damage = 32.0
	aoe_radius = 8.0
	attack_cooldown = 1.4

	phase_attacks = {
		Phase.PHASE_1: [AttackType.RANGED, AttackType.AOE],
		Phase.PHASE_2: [AttackType.RANGED, AttackType.AOE, AttackType.CHARGE],
		Phase.PHASE_3: [AttackType.AOE, AttackType.AOE, AttackType.CHARGE, AttackType.RANGED]
	}

	super._ready()
