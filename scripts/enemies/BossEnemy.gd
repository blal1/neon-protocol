# ==============================================================================
# BossEnemy.gd - Ennemi Boss
# Action-RPG Cyberpunk Low-Poly - Godot 4
# ==============================================================================
# Boss avec plusieurs phases et attaques spéciales
# ==============================================================================

extends CharacterBody3D
class_name BossEnemy

# ==============================================================================
# SIGNAUX
# ==============================================================================
signal phase_changed(phase: int)
signal attack_started(attack_name: String)
signal attack_ended(attack_name: String)
signal boss_defeated
signal health_changed(current: float, max: float)

# ==============================================================================
# ÉNUMÉRATIONS
# ==============================================================================
enum Phase { PHASE_1, PHASE_2, PHASE_3 }
enum State { IDLE, PURSUING, ATTACKING, CHARGING, STUNNED, DEFEATED }
enum AttackType { MELEE, RANGED, AOE, CHARGE }

# ==============================================================================
# VARIABLES EXPORTÉES
# ==============================================================================
@export_group("Statistiques")
@export var boss_name: String = "OVERLORD-X7"
@export var max_health: float = 500.0
@export var phase_2_threshold: float = 0.6  ## 60% HP
@export var phase_3_threshold: float = 0.3  ## 30% HP

@export_group("Mouvement")
@export var move_speed: float = 4.0
@export var charge_speed: float = 15.0
@export var rotation_speed: float = 2.0

@export_group("Combat")
@export var melee_damage: float = 25.0
@export var melee_range: float = 3.0
@export var ranged_damage: float = 15.0
@export var aoe_damage: float = 35.0
@export var aoe_radius: float = 6.0
@export var attack_cooldown: float = 2.0

# ==============================================================================
# VARIABLES D'ÉTAT
# ==============================================================================
var current_phase: Phase = Phase.PHASE_1
var current_state: State = State.IDLE
var current_health: float
var player_ref: Node3D = null
var can_attack: bool = true
var is_invulnerable: bool = false
var _stun_timer: float = 0.0

# Attaques par phase
var phase_attacks: Dictionary = {
	Phase.PHASE_1: [AttackType.MELEE, AttackType.RANGED],
	Phase.PHASE_2: [AttackType.MELEE, AttackType.RANGED, AttackType.CHARGE],
	Phase.PHASE_3: [AttackType.MELEE, AttackType.RANGED, AttackType.CHARGE, AttackType.AOE]
}

# ==============================================================================
# RÉFÉRENCES
# ==============================================================================
@onready var mesh_pivot: Node3D = $MeshPivot if has_node("MeshPivot") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D if has_node("NavigationAgent3D") else null

# ==============================================================================
# FONCTIONS GODOT
# ==============================================================================

func _ready() -> void:
	"""Initialisation."""
	add_to_group("enemy")
	add_to_group("boss")
	
	current_health = max_health
	
	# Trouver le joueur
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
	
	# Lancer l'intro
	play_intro()


var _intro_completed: bool = false

func play_intro() -> void:
	"""Joue l'animation d'introduction du boss."""
	_intro_completed = false
	is_invulnerable = true
	current_state = State.IDLE
	
	# Musique de boss
	var music = get_node_or_null("/root/MusicManager")
	if music and music.has_method("enter_boss"):
		music.enter_boss()
	
	# Créer les barres cinématiques
	var cinematic_overlay := _create_cinematic_bars()
	
	# Effet de zoom caméra
	var camera := get_viewport().get_camera_3d()
	var original_fov: float = 75.0
	if camera:
		original_fov = camera.fov
		var tween := create_tween()
		tween.tween_property(camera, "fov", 40.0, 0.5)  # Zoom in
	
	# Animation d'entrée du boss
	if mesh_pivot:
		mesh_pivot.scale = Vector3.ZERO
		var tween := create_tween()
		tween.tween_property(mesh_pivot, "scale", Vector3.ONE * 1.5, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(mesh_pivot, "scale", Vector3.ONE, 0.3)
	
	# Effet de lumière dramatique
	var intro_light := OmniLight3D.new()
	intro_light.light_color = Color(1, 0.2, 0.2)
	intro_light.light_energy = 10.0
	intro_light.omni_range = 15.0
	intro_light.global_position = global_position + Vector3(0, 5, 0)
	get_tree().current_scene.add_child(intro_light)
	
	# Particules d'aura
	_spawn_intro_particles()
	
	# TTS annonce dramatique
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Alerte! Boss détecté!")
	
	await get_tree().create_timer(1.0).timeout
	
	if tts:
		tts.speak(boss_name)
	
	await get_tree().create_timer(1.5).timeout
	
	# Restaurer la caméra
	if camera:
		var tween := create_tween()
		tween.tween_property(camera, "fov", original_fov, 0.5)
	
	# Fade out lumière
	var light_tween := create_tween()
	light_tween.tween_property(intro_light, "light_energy", 0.0, 1.0)
	light_tween.tween_callback(intro_light.queue_free)
	
	# Supprimer les barres cinématiques
	if cinematic_overlay:
		var bar_tween := create_tween()
		bar_tween.tween_property(cinematic_overlay, "modulate:a", 0.0, 0.5)
		bar_tween.tween_callback(cinematic_overlay.queue_free)
	
	# Fin de l'intro
	is_invulnerable = false
	_intro_completed = true
	current_state = State.PURSUING


func _create_cinematic_bars() -> CanvasLayer:
	"""Crée les barres noires cinématiques."""
	var layer := CanvasLayer.new()
	layer.layer = 50
	
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(container)
	
	var top_bar := ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 80)
	container.add_child(top_bar)
	
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color.BLACK
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.custom_minimum_size = Vector2(0, 80)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.add_child(bottom_bar)
	
	# Titre du boss
	var title := Label.new()
	title.text = boss_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	title.modulate.a = 0.0
	container.add_child(title)
	
	# Animation du titre
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(title, "modulate:a", 0.0, 0.5)
	
	get_tree().root.add_child(layer)
	return layer


func _spawn_intro_particles() -> void:
	"""Crée les particules d'intro."""
	# Particules d'énergie montante
	var particles := GPUParticles3D.new()
	particles.amount = 50
	particles.lifetime = 2.0
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.global_position = global_position
	
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 8.0
	material.gravity = Vector3.ZERO
	material.color = Color(1, 0.3, 0.1)
	particles.process_material = material
	
	# Mesh des particules
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	
	# Cleanup
	await get_tree().create_timer(3.0).timeout
	particles.queue_free()


func _physics_process(delta: float) -> void:
	"""Mise à jour physique."""
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PURSUING:
			_state_pursuing(delta)
		State.ATTACKING:
			pass  # Géré par les coroutines
		State.CHARGING:
			_state_charging(delta)
		State.STUNNED:
			_state_stunned(delta)
		State.DEFEATED:
			pass
	
	move_and_slide()


# ==============================================================================
# ÉTATS
# ==============================================================================

func _state_idle(delta: float) -> void:
	"""Attente."""
	if player_ref:
		current_state = State.PURSUING


func _state_pursuing(delta: float) -> void:
	"""Poursuite du joueur."""
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	var distance := global_position.distance_to(player_ref.global_position)
	
	# Navigation
	if navigation_agent:
		navigation_agent.target_position = player_ref.global_position
		
		if not navigation_agent.is_navigation_finished():
			var next_pos := navigation_agent.get_next_path_position()
			var direction := (next_pos - global_position).normalized()
			velocity = direction * move_speed
			_rotate_toward(direction, delta)
	else:
		var direction := (player_ref.global_position - global_position).normalized()
		direction.y = 0
		velocity = direction * move_speed
		_rotate_toward(direction, delta)
	
	# Attaque si à portée
	if can_attack:
		if distance <= melee_range:
			_start_attack(AttackType.MELEE)
		elif distance <= 10.0:
			var available := phase_attacks[current_phase]
			var attack_type: AttackType = available[randi() % available.size()]
			_start_attack(attack_type)


func _state_charging(delta: float) -> void:
	"""Charge vers le joueur."""
	# La charge est gérée dans _attack_charge()
	pass


func _state_stunned(delta: float) -> void:
	"""Étourdi."""
	velocity = Vector3.ZERO
	_stun_timer -= delta
	
	if _stun_timer <= 0:
		current_state = State.PURSUING


# ==============================================================================
# ATTAQUES
# ==============================================================================

func _start_attack(attack_type: AttackType) -> void:
	"""Démarre une attaque."""
	if not can_attack:
		return
	
	can_attack = false
	current_state = State.ATTACKING
	
	match attack_type:
		AttackType.MELEE:
			await _attack_melee()
		AttackType.RANGED:
			await _attack_ranged()
		AttackType.CHARGE:
			await _attack_charge()
		AttackType.AOE:
			await _attack_aoe()
	
	current_state = State.PURSUING
	
	# Cooldown (plus rapide en phases avancées)
	var cooldown := attack_cooldown * (1.0 - current_phase * 0.2)
	await get_tree().create_timer(cooldown).timeout
	can_attack = true


func _attack_melee() -> void:
	"""Attaque de mêlée."""
	attack_started.emit("melee")
	
	# Animation de frappe
	if mesh_pivot:
		var tween := create_tween()
		tween.tween_property(mesh_pivot, "rotation:y", mesh_pivot.rotation.y + PI/4, 0.15)
		tween.tween_property(mesh_pivot, "rotation:y", mesh_pivot.rotation.y - PI/2, 0.1)
		tween.tween_property(mesh_pivot, "rotation:y", mesh_pivot.rotation.y, 0.2)
	
	await get_tree().create_timer(0.25).timeout
	
	# Dégâts
	if player_ref and global_position.distance_to(player_ref.global_position) <= melee_range * 1.5:
		_deal_damage_to_player(melee_damage)
	
	attack_ended.emit("melee")


func _attack_ranged() -> void:
	"""Attaque à distance (projectiles)."""
	attack_started.emit("ranged")
	
	var projectile_count := 1 + current_phase
	
	for i in range(projectile_count):
		_spawn_projectile()
		await get_tree().create_timer(0.2).timeout
	
	attack_ended.emit("ranged")


func _attack_charge() -> void:
	"""Charge vers le joueur."""
	attack_started.emit("charge")
	current_state = State.CHARGING
	
	if not player_ref:
		return
	
	# Direction de charge
	var charge_direction := (player_ref.global_position - global_position).normalized()
	charge_direction.y = 0
	
	# Préparation
	is_invulnerable = true
	await get_tree().create_timer(0.5).timeout
	
	# Charge
	var charge_time := 0.0
	var max_charge_time := 1.5
	
	while charge_time < max_charge_time:
		velocity = charge_direction * charge_speed
		
		# Collision avec joueur
		if player_ref and global_position.distance_to(player_ref.global_position) < 2.0:
			_deal_damage_to_player(melee_damage * 1.5)
			break
		
		charge_time += get_physics_process_delta_time()
		await get_tree().process_frame
	
	velocity = Vector3.ZERO
	is_invulnerable = false
	
	# Stun après charge
	_stun(1.0)
	
	attack_ended.emit("charge")


func _attack_aoe() -> void:
	"""Attaque de zone."""
	attack_started.emit("aoe")
	
	# Préparation visuelle
	var warning := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = aoe_radius
	cylinder.bottom_radius = aoe_radius
	cylinder.height = 0.1
	warning.mesh = cylinder
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning.set_surface_override_material(0, mat)
	
	warning.global_position = global_position
	get_tree().current_scene.add_child(warning)
	
	# TTS avertissement
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("Attaque de zone!")
	
	await get_tree().create_timer(1.5).timeout
	
	# Explosion
	warning.queue_free()
	
	# Effet visuel
	var explosion := OmniLight3D.new()
	explosion.light_color = Color(1, 0.3, 0)
	explosion.light_energy = 8.0
	explosion.omni_range = aoe_radius
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	
	# Dégâts
	if player_ref and global_position.distance_to(player_ref.global_position) <= aoe_radius:
		_deal_damage_to_player(aoe_damage)
	
	# Fade explosion
	var tween := create_tween()
	tween.tween_property(explosion, "light_energy", 0.0, 0.5)
	tween.tween_callback(explosion.queue_free)
	
	attack_ended.emit("aoe")


func _spawn_projectile() -> void:
	"""Crée un projectile avec effets visuels améliorés."""
	var projectile := Area3D.new()
	projectile.name = "BossProjectile"
	projectile.global_position = global_position + Vector3(0, 2, 0)
	projectile.add_to_group("enemy_projectile")
	
	var direction := Vector3.FORWARD
	if player_ref:
		direction = (player_ref.global_position - projectile.global_position).normalized()
	
	# Mesh principal (sphère de plasma)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	sphere.radial_segments = 16
	mesh.mesh = sphere
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.1, 0.5)
	mat.emission_energy_multiplier = 5.0
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.rim_tint = 0.5
	mesh.set_surface_override_material(0, mat)
	projectile.add_child(mesh)
	
	# Lumière du projectile
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.2, 0.6)
	light.light_energy = 3.0
	light.omni_range = 4.0
	projectile.add_child(light)
	
	# Particules de traînée
	var trail := GPUParticles3D.new()
	trail.amount = 30
	trail.lifetime = 0.5
	trail.preprocess = 0.0
	
	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.direction = Vector3(0, 0, 0)
	trail_mat.spread = 0.0
	trail_mat.initial_velocity_min = 0.0
	trail_mat.initial_velocity_max = 0.0
	trail_mat.gravity = Vector3.ZERO
	trail_mat.scale_min = 0.3
	trail_mat.scale_max = 0.5
	trail_mat.color = Color(1, 0.4, 0.8, 0.8)
	trail.process_material = trail_mat
	
	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.1
	trail_mesh.height = 0.2
	trail.draw_pass_1 = trail_mesh
	projectile.add_child(trail)
	
	# Collision
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	collision.shape = shape
	projectile.add_child(collision)
	
	# Connecter la collision
	projectile.body_entered.connect(_on_projectile_hit.bind(projectile))
	
	# Stocker les données
	projectile.set_meta("direction", direction)
	projectile.set_meta("speed", 18.0)
	projectile.set_meta("damage", ranged_damage * (1.0 + current_phase * 0.2))
	
	get_tree().current_scene.add_child(projectile)
	
	# Animation de pulsation
	var pulse_tween := create_tween().set_loops()
	pulse_tween.tween_property(mesh, "scale", Vector3.ONE * 1.2, 0.15)
	pulse_tween.tween_property(mesh, "scale", Vector3.ONE, 0.15)
	
	# Mouvement avec tracking léger
	var target_pos := projectile.global_position + direction * 35
	var tween := create_tween()
	tween.tween_property(projectile, "global_position", target_pos, 2.0)
	tween.tween_callback(projectile.queue_free)


func _on_projectile_hit(body: Node3D, projectile: Area3D) -> void:
	"""Callback quand un projectile touche quelque chose."""
	if body.is_in_group("player"):
		var damage: float = projectile.get_meta("damage", ranged_damage)
		_deal_damage_to_player(damage)
		
		# Effet d'impact
		var impact := OmniLight3D.new()
		impact.light_color = Color(1, 0.2, 0.6)
		impact.light_energy = 8.0
		impact.omni_range = 3.0
		impact.global_position = projectile.global_position
		get_tree().current_scene.add_child(impact)
		
		var tween := create_tween()
		tween.tween_property(impact, "light_energy", 0.0, 0.3)
		tween.tween_callback(impact.queue_free)
		
		projectile.queue_free()


# ==============================================================================
# DÉGÂTS
# ==============================================================================

func take_damage(damage: float, source: Node = null) -> void:
	"""Reçoit des dégâts."""
	if is_invulnerable or current_state == State.DEFEATED:
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	
	# Vérifier les changements de phase
	var health_percent := current_health / max_health
	
	if current_phase == Phase.PHASE_1 and health_percent <= phase_2_threshold:
		_enter_phase(Phase.PHASE_2)
	elif current_phase == Phase.PHASE_2 and health_percent <= phase_3_threshold:
		_enter_phase(Phase.PHASE_3)
	
	# Mort
	if current_health <= 0:
		_defeat()


func _deal_damage_to_player(damage: float) -> void:
	"""Inflige des dégâts au joueur."""
	if not player_ref:
		return
	
	var health = player_ref.get_node_or_null("HealthComponent")
	if health:
		health.take_damage(damage, self)


# ==============================================================================
# PHASES
# ==============================================================================

func _enter_phase(phase: Phase) -> void:
	"""Entre dans une nouvelle phase."""
	current_phase = phase
	phase_changed.emit(phase)
	
	# Stun temporaire
	_stun(1.5)
	
	# Boost stats
	move_speed *= 1.2
	attack_cooldown *= 0.8
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		match phase:
			Phase.PHASE_2:
				tts.speak("%s entre en phase 2!" % boss_name)
			Phase.PHASE_3:
				tts.speak("%s est en rage! Phase finale!" % boss_name)


func _defeat() -> void:
	"""Boss vaincu."""
	current_state = State.DEFEATED
	velocity = Vector3.ZERO
	boss_defeated.emit()
	
	# Musique victoire
	var music = get_node_or_null("/root/MusicManager")
	if music:
		music.play_victory()
	
	# TTS
	var tts = get_node_or_null("/root/TTSManager")
	if tts:
		tts.speak("%s vaincu!" % boss_name)
	
	# Animation de mort
	if mesh_pivot:
		var tween := create_tween()
		tween.tween_property(mesh_pivot, "scale", Vector3.ZERO, 1.0)
		tween.tween_callback(queue_free)


# ==============================================================================
# UTILITAIRES
# ==============================================================================

func _stun(duration: float) -> void:
	"""Étourdit le boss."""
	current_state = State.STUNNED
	_stun_timer = duration


func _rotate_toward(direction: Vector3, delta: float) -> void:
	"""Rotation vers une direction."""
	if direction.length() < 0.1:
		return
	var target_angle := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)


func get_health_percent() -> float:
	"""Retourne le pourcentage de vie."""
	return current_health / max_health
