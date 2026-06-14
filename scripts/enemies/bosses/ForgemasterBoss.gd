# ==============================================================================
# ForgemasterBoss.gd - Boss "FORGEMASTER-7" (Rust Belt)
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Mech industriel lourd. Brute en mêlée, charges destructrices.
# Entre en rage plus tôt mais frappe plus fort et résiste plus longtemps.
# ==============================================================================

extends BossEnemy
class_name ForgemasterBoss


func _ready() -> void:
	boss_name = "FORGEMASTER-7"
	boss_type = "boss_industrial"

	max_health = 650.0
	phase_2_threshold = 0.7
	phase_3_threshold = 0.35

	move_speed = 3.2
	charge_speed = 14.0

	melee_damage = 32.0
	ranged_damage = 12.0
	aoe_damage = 40.0
	aoe_radius = 7.0
	melee_range = 3.5
	attack_cooldown = 2.4

	phase_attacks = {
		Phase.PHASE_1: [AttackType.MELEE, AttackType.MELEE, AttackType.CHARGE],
		Phase.PHASE_2: [AttackType.MELEE, AttackType.CHARGE, AttackType.AOE],
		Phase.PHASE_3: [AttackType.CHARGE, AttackType.AOE, AttackType.MELEE]
	}

	super._ready()
